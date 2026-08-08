/**
 * Transparency-log anchoring + client-side verification (mosskeys).
 *
 * Complements the TOFU pin store (#293) and the signed per-user chain monitor
 * (#315) with the third-party anchor those two lack: the peer's public key
 * material is published to a PUBLIC, append-only transparency log (mosskeys),
 * so a server key-substitution can no longer be targeted silently at one
 * viewer — the substituted key would have to appear in the public log, visible
 * to the peer themselves and to every other monitor.
 *
 * WHAT THIS VERIFIES (all client-side, the mosslet server is never in the
 * read path — the browser fetches the log directly):
 *
 *   1. LABEL LOOKUP — `GET /api/:slug/log/label/:label` returns the peer's
 *      newest log leaf (their current key binding) plus an inclusion proof
 *      and the latest signed checkpoint.
 *   2. LEAF PARSE — the canonical `key-history/v1` leaf bytes are parsed and
 *      the bound encryption keys compared to the keys the mosslet server
 *      served. A difference means the public log disagrees with what we were
 *      served (rotation mid-publish, or substitution).
 *   3. LEAF HASH — `SHA-256(0x00 || leaf)` recomputed and compared.
 *   4. CHECKPOINT — the C2SP signed-note checkpoint is verified against the
 *      PINNED namespace Ed25519 verifier key (WebCrypto), and the note body
 *      is confirmed to match the served origin/size/root.
 *   5. WITNESS COSIGNATURES (additive) — every signature line on the same
 *      note is parsed, and lines whose name matches a PINNED witness vkey
 *      are verified: C2SP tlog-cosignature v1 Ed25519 (0x04) signatures via
 *      WebCrypto, and ML-DSA-44 (0x06) signatures via the vendored
 *      metamorphic-log WASM (the same `verifySignedNote` the mosskeys web
 *      client uses). Only cryptographically valid cosignatures are counted;
 *      invalid or unknown ones are ignored, never a downgrade.
 *   6. INCLUSION — the RFC 6962 audit path is walked from the leaf hash to
 *      the verified checkpoint root.
 *
 * The trust roots are the PINNED public keys below — the namespace checkpoint
 * key and the witness cosignature roster — public material shipped in the
 * bundle (the same model as CT log keys pinned in browsers), NOT served by
 * the mosslet server (which is the adversary in this threat model) and NOT
 * fetched at runtime from mosskeys either: the JSON `cosigners` array and
 * the `/api/witnesses` roster are reflection surfaces, useful for release-
 * time updates but never consulted for the verdict. If the checkpoint key
 * rotates, update the constant with the new public key (fetchable from the
 * public `/api/witness/logs` discovery feed, out-of-band verified); witness
 * roster updates follow the same release-time model (see below).
 *
 * HONEST LIMITS (keep copy accurate):
 *   - Anchoring proves PUBLIC COMMITMENT, not key authenticity: TOFU +
 *     out-of-band safety numbers remain the first-contact backstop, and the
 *     signed per-user chain proves rotation continuity.
 *   - The checkpoint note is verified against the pinned namespace key, and
 *     any pinned-witness cosignatures riding in that same note are verified
 *     too: a verified cosignature means an independent operator attested the
 *     SAME tree head we were served, so a split-view would have to fool (or
 *     compromise) both the log and that witness. Counting is strictly
 *     additive — unknown names, bad key ids, and failed signatures are
 *     excluded silently and never downgrade the verdict. What this file
 *     still does NOT do: cross-checkpoint equivocation detection (comparing
 *     heads over time, or against other observers' views) — that belongs to
 *     monitors and the witness network's consistency proofs, not to a
 *     single-point-in-time verifier.
 *
 * The module fetches only PUBLIC material and runs entirely client-side.
 */

import wasmInit, {
  verifySignedNote as _verifySignedNote,
} from "../../vendor/metamorphic-log/metamorphic_log.js";

// --- WASM initialization (metamorphic-log) -------------------------------

let _ready = null;
let _wasmSource = "/wasm/metamorphic_log_bg.wasm";

/**
 * Override where the metamorphic-log WASM binary is loaded from before first
 * use. Same contract as nacl.js's setWasmSource: in the browser the default
 * Phoenix static path ("/wasm/...") is correct and this never needs to be
 * called; non-browser environments (tests, SDK harnesses) call it with bytes
 * before the first verification.
 *
 * @param {string|URL|BufferSource|Response|WebAssembly.Module} input
 */
export function setWasmSource(input) {
  if (_ready)
    throw new Error(
      "setWasmSource must be called before the transparency log is verified",
    );
  _wasmSource = input;
}

async function ensureReady() {
  if (_ready) return _ready;
  _ready = wasmInit({ module_or_path: _wasmSource }).catch((e) => {
    _ready = null;
    throw e;
  });
  await _ready;
  return _ready;
}

// --- Pinned log parameters (PUBLIC material) --------------------------------
// Production mosslet namespace on mosskeys.com. To verify against a local or
// staging log in development, point these three at that deployment (the vkey
// is served by its public `/api/witness/logs` feed).
const LOG_BASE_URL = "https://mosskeys.com/api/mosslet";
const LOG_ORIGIN = "mosskeys.com/mosslet";
// Raw 32-byte Ed25519 public half of the namespace's checkpoint signing key
// (the classical line every `sign_dual` checkpoint carries). Base64.
const LOG_CHECKPOINT_ED25519_VK =
  "1Ltcg/D0+UxGBe5e/ADMMFIfQplIiIkSQDZaARCPxjc=";

// Independent C2SP witness cosignature verifier keys, pinned at release time:
// witness name → the entry's full C2SP vkey string `<name>+<8-hex key id>+
// <base64(0x04 || Ed25519 public key)>`, copy-pasted verbatim from the
// approved roster at `GET https://mosskeys.com/api/witnesses` (also mirrored
// on the public `/witnesses` directory page — the `vkeys.ed25519` value),
// exactly like the ML-DSA-44 roster below. The 0x04 path parses the string
// and recomputes the key id itself (see _parseEd25519Vkey), so the pin stays
// a copy-paste of the public directory. Same trust model as
// LOG_CHECKPOINT_ED25519_VK — the roster is PUBLIC material shipped in the
// bundle and is NEVER fetched at runtime (mosskeys is inside the threat model
// for split-view; a served roster could name attacker keys).
//
// Update one-liner (prints this map's entries; verify out-of-band before
// merging):
//
//   node --input-type=module -e '
//     const { witnesses } = await (await fetch("https://mosskeys.com/api/witnesses")).json();
//     for (const w of witnesses) {
//       const v = w.vkeys?.ed25519;
//       if (!v) continue;
//       // `<name>+<8-hex key id>+<base64(0x04 || pubkey)>` — split on the
//       // first two "+" only: the base64 segment itself may contain "+".
//       const i = v.indexOf("+"), j = v.indexOf("+", i + 1);
//       const raw = Buffer.from(v.slice(j + 1), "base64");
//       if (raw.length !== 33 || raw[0] !== 0x04) continue;
//       console.log(`  ${JSON.stringify(w.name)}:\n    ${JSON.stringify(v)},`);
//     }'
//
// Wire format verified here (C2SP tlog-cosignature v1, Ed25519 type 0x04):
// each witness line on a checkpoint note is
// `— <name> <base64(keyID[4] || u64be timestamp || ed25519_sig[64])>` with
// keyID = SHA-256(name || 0x0A || 0x04 || pubkey)[0:4], and the signed
// message is `cosignature/v1\ntime <timestamp>\n<checkpoint body>`.
export const WITNESS_ED25519_VKEYS = {
  "witness.coretheorystudios.com/mosskeys":
    "witness.coretheorystudios.com/mosskeys+62258d4e+BJv7QdKWYaFjj2rXrn+WE/gyMUJ4gPLLhY4UBmhXWfXw",
  "witness.smoxy.io/mosskeys":
    "witness.smoxy.io/mosskeys+166ebeca+BGH3na/gZAJSrrZzeJ7uXkZaIkqcLvEtuAUyoOJisb+3",
};

// ML-DSA-44 (0x06) witness cosignature verifier keys, pinned at release time:
// witness name → the entry's full C2SP vkey string `<name>+<8-hex key id>+
// <base64(0x06 || ML-DSA-44 public key)>`, consumed verbatim by the vendored
// metamorphic-log WASM (`verifySignedNote` parses and recomputes the key id
// itself — we never hand-decode the key). Same public/never-fetched trust
// model as the Ed25519 roster above.
//
// Wire format verified via the WASM (C2SP tlog-cosignature v1, ML-DSA-44 type
// 0x06): each witness line is `— <name> <base64(keyID[4] || u64be timestamp
// || ml_dsa_44_signature[2420])>` with keyID =
// SHA-256(name || 0x0A || 0x06 || pubkey)[0:4], and the signed message is the
// domain-separated `subtree/v1\n\0` blob (the classical 0x04 message and the
// 0x06 message are different — both are handled by the same `verifySignedNote`
// call on a line-isolated mini-note).
export const WITNESS_MLDSA44_VKEYS = {
  "witness.coretheorystudios.com/mosskeys":
    "witness.coretheorystudios.com/mosskeys+d44dd49a+Br9D34th39PD77N8mz++Ocz5+47+8as9xh7abVHZYUUwzpGi+e+FyANO1G6gUaMDo9TTbYbsTTK33XbI7MbTkwVh30ptq1GGqLiGnEC9/0KEvTrewnfVfAI2GaHnI1SWKXLJE3JZE1cpWrXTlTecGSwYR/gG5L0cCqmLxCkmowdRLYfAvqfF5taQoFnsid/dJ3cP8q8JBmhc64Fd5tIMNxu0YUp+IYnqzt5RICJ3JcI5XR5Dqh++RS2+UInB5xhMOvaaMeXxfUZRvAPYP10EtXDoFkeUvXXKqZN09dkgISyNw4ZaKmLunYaBiTB0uCTKOMQW3tHLbERTnX7LhW+djNWMV8v+pUa0vaowX1+SPTU5lvTWTAq4AlA41iHxcVzDF5glL8pdFv2YQHR/IQ8rZCgb19XTID34m9k8Qrgj964QMpekLj3V/QCwWZZ3kuoGrfgeMp5ASDetikKfpkOt3mk5lCPE+Y1adqfzc9/KAmNU5+r1eAyxY+ADbTgRf5UEmtvFdp0Ym7By5kEJKNdgp9lA2/etdgf+rW0ru8Uz41zXaCCSg872t5mm2aV1by0TPBX65LadtvryldoI6ou2dnH+gxeuQXdadOcC9/yqm7rae6LCpDXc9sBlIH0JDVmX98kF+ZqpG6s2w6h5Tjl6iI0l/uIHcgIhLWyo6ZWg/hikSovf41KxiBsV5x+4m06Ym24r48YMn06KxAU1LCgfGHW1jalUZc+WsJZ2BLTzwK1JQjeAM0USRib95fjUD5Scx79ro66ElFV+qDpror0Yz9PYbQ3RtZcyuG60dwvpxrO1HWZDvsJUkiImpsG1jhXRZDAIOlK5p//XQ+uwfl/VYrTpGkIQjEK08Q0DhnqEqQvXYHx0MK4Tr0CkatFL+kNPNQNGL0QL819Fp9LkJTeuvUVICpb++YnOIqV/W42ZuMDYKyePkLjT1zfUh9n4LZF/Mu49L9UB2eJirGG3zlPufY8kteFu1cZzupK4KIFuQLZJ27UBE2zf2E58cP8aSYRMFS1Qtzs4SISHag5lmSc+N/szeIVQ+VPvnViH4+pZU42PGWnrdE4NvgOP+pXpVIg1cWCh663XXMO3W/gryp7zMQsBGUYRvLhXj0L35NYsabigOqbyPzbRaukDtVaM4qF35pXt9lZRjj2QJ4u4MbS+0hbwWwpXF9pRr0X3Ap/ZcdcMGEH9rZkVbQjK2k480Np6Ps49+eR4mjrWEQn4UCN4jyNbv0Bng9O9amCeWV/WlTl/yJQkEemc267yp/so/NW0YeSAIDzRX9fN8kW0EhIhAQjmFjDjaBInJ0VKm6WxJhGowezYMkaU1PVHCzT9TJ/7DmKYUhZspImqetg4rsZUh5J6zisCmQVsG+RBR86vJ5Ry28bg2OCa0t9nhhxOp/0pXUzjNHAin/R1vDaamBgeM9cKtjv2HKxN35oVuff7SweWWI0FlydOU2IH47xxsH+K8vlMTjEajjrCEWuXodxSa/2aP/3AS4HrMf3KvEgwxg+jtyDnJzR4lzft2F2VZPfcWkGgjg8UoZ03r1M23CeuzT3tfJgKr7DlTsZOMBATCImlFOgJ9AXeJvdwNfSR1Jl1To+flnlRrfFyBtsPPo6NlXM1IGu6Qf26Yy4c17Jvto/YPf/VMFuFwpooxw0dNHRxxscLLfCyxbNnYvdqQ0qb9q0bcc8z8aDCqkF7anGb4+K9UTkbm9+iv2uCG9IFwqF7VR+NCOTfcpMAX1GpXOqKyjI=",
  "witness.smoxy.io/mosskeys":
    "witness.smoxy.io/mosskeys+da74ae6c+BhWXxZ2C9dKPvKKOgfwRFb9S/LNP8kVW1vItQ7hFRpLN1WPE9v9kuvR2fs9GOThfaNbGE/1bJ5yuTqkDJjc/DjPghn+TBws+z+UgV8CaRtYIek+7uvxUOH0RGOeGTXr2YKw2vHpffXOcwK5jz/59wfQo3XJltRg4HgyZrFD+MFXqVBdi5I3ZXl7wFqncfPxuLl94y7xWxPUygm23F0GXNCmF7YxYhx4t7K3CDlG61SV8Bo6U3O81Zrx999u3xXPcx4nMem4l/N7W0pE0ukwZO6zOm5ZCMy3a/X7bj2FxTXpOusHZa53w6nd2vNDRmkbO7WYMdTSGVr6KA1TFHoz8MtFUHU1/JxlVqnxYGaVTWh/zkOT11Cr5PxfXxmbqbm4jvUEKDPxXqcZ0WJntknn2t4ne+a8ZNvgc+bv8+NAFrzc2l9MwVdj1yCFUg6l7CYvesDIhxozNw7ge7H9fakBPNzUaBYaycotcZpe1GNFTO9aae+Fto1tB2+RZAm0Ephj1SRZrerd/i5ae6bx++yH/nMrwUYsalllyZTJw5A7jjnKSduwlaaneAN3Mhk+0coARE64ZOcCEUByZY8fUHdUBV3Yie6tmoch+T08J9H6BrgJQ3G7U2hDZshh/DtvAFoQS/M5Ge4ntBckMEfoYPJ0UbGg2nJQZmOu0RkeXcfSXdwqQ1BZZpB40hupFVJh8qRGSOh3E7JqQ6ylL5K5JI/+VFmY336Kfy5U3saYT6jCfkmykUw+oFYYmy9BkPqs/XJ43sHjqXG6+Cnb5kCEamdqNMD4KiGtqLQNFPD3W7DKlOfty1ZcOzWxd+Vyv9yYSdLbblMxlboE+f9G1sY+RsNF7ujH75Pnq9WUFjSwN3ewBgAmOf6EdPo7wK6pSt58z9QAoQIhElfxH4FExVbWovS6/PTZoVg1A0F4s+4S97/Q93qfSC3cqbIsdeaJutux+1fmMzU8ggYUsJy41b4ZGa//TGMsjucdpRSc3kffNqWNIqUH4T5dislRfFP7UuCrVPnvhlH/ZGrvGa1ArEl8SXyOdAGBf3gJXN2fpsyzbBpQRMae8R36ZdmViIgAeHiOSfwEluszkkfHBv407Q10p4Rb5lwFdouYrtqD2x4KO+QvZjL+fBFCUpj7yVuFs09tYVvw62UR2d++7kJ04SHL1vX59lPc+24ZUgUvr0rsvt77CxtOUr6VnrqlQrK93GsU2rPNEyRjmNPRwm6AkJb4C6oSs1yTym1D5vsQpabeovi5lJ0QwigM9c6UnWYpIF2UrvSl5wAbjPZ7DXbsLLyDw8IdRhWWRHSVJjqegHa7+Kiv0XX9lyjvqE0hI5owhN+nVH+fJSF6/2vieOxwhSXf9chU4+32B0VFuvbleuXOwsrMWKUcOlMz1Pf5nlsS9BpgKHf3RM5HqKPvG0dX8vQ6+GWzkpiCFI8HCow519thISwBz7GIQGTmuJsDs8niFpyjp6c0BMBl5BwjnSNnRm8bb3xvMmsBqQRc8rotcyeFotF0iAdn96aA9I8rbKyqUQOwSeH2FGEHnEMmAV1C/zdtbTmh6SL9jq32HK92GmKvXEkTrBbIJSM32km+2ZjzF04rrpPC7pVgrXIPd/3xjMw5v4MzWKKuXJ+yE6vv2i1GOO6SXg6LlDAupV8ukTzClNBwEC7hWqoQmxBvpcFWIogfc0v8jjhaBAVygaf6EP+9Rm2w3t4xXUCeUiiwJyEsbqpy5zjdpxykfqnKUPcwbHtsq6jDmfd0=",
};

export const LOG_STATUS = {
  ANCHORED: "anchored", // all proofs verify; log key == served key
  PENDING_CHECKPOINT: "pending_checkpoint", // in the log, not yet under a signed checkpoint
  NOT_PUBLISHED: "not_published", // peer has no entry in the log (404)
  KEY_MISMATCH: "key_mismatch", // log head key != served key (rotation mid-publish OR substitution)
  PROOF_INVALID: "proof_invalid", // bundle failed cryptographic verification
  UNAVAILABLE: "unavailable", // network/CORS/unsupported crypto — no verdict
};

// Fired on every completed check so any surface (connection-card badge,
// verification modal) can live-update. detail: {peerUserId, status, index,
// size, witnesses, witnessNames}.
export const PEER_LOG_STATUS_EVENT = "mosslet:peer-log-status";

const CACHE_TTL_MS = 60_000;
const MAX_IN_FLIGHT = 4;

const _cache = new Map(); // peerUserId -> {ts, result}
const _inFlight = new Map(); // peerUserId -> Promise
let _active = 0;
const _queue = [];

/**
 * Check whether a peer's served key is anchored in the public transparency
 * log, verifying the served bundle cryptographically end-to-end.
 *
 * @param {Object} args
 * @param {string} args.peerUserId - the log label (the peer's user id)
 * @param {string} args.peerPublicKey - served X25519 public key (base64)
 * @param {string} args.peerPqPublicKey - served ML-KEM public key (base64)
 * @returns {Promise<{status: string, index?: number, size?: number, checkpointVerified?: boolean, witnesses?: number, witnessNames?: string[]}>}
 *
 * On ANCHORED, `witnesses` is the count of pinned-witness cosignatures that
 * verified on the checkpoint note (0 when the witness network is empty) and
 * `witnessNames` carries those witnesses' names (public roster identities).
 */
export async function checkPeerKeyAnchor({
  peerUserId,
  peerPublicKey,
  peerPqPublicKey,
}) {
  if (!peerUserId || !peerPublicKey || !peerPqPublicKey) {
    return { status: LOG_STATUS.UNAVAILABLE };
  }

  const cacheKey = `${peerUserId}|${peerPublicKey}|${peerPqPublicKey}`;
  const cached = _cache.get(cacheKey);
  if (cached && Date.now() - cached.ts < CACHE_TTL_MS) return cached.result;

  if (_inFlight.has(cacheKey)) return _inFlight.get(cacheKey);

  const promise = _enqueue(() =>
    _fetchAndVerify({ peerUserId, peerPublicKey, peerPqPublicKey }),
  ).then((result) => {
    _inFlight.delete(cacheKey);
    _cache.set(cacheKey, { ts: Date.now(), result });
    _dispatch(peerUserId, result);
    return result;
  });

  _inFlight.set(cacheKey, promise);
  return promise;
}

// ---------------------------------------------------------------------------
// Fetch + verify pipeline
// ---------------------------------------------------------------------------

async function _fetchAndVerify({ peerUserId, peerPublicKey, peerPqPublicKey }) {
  let bundle;
  try {
    const resp = await fetch(
      `${LOG_BASE_URL}/log/label/${encodeURIComponent(peerUserId)}`,
      { headers: { accept: "application/json" } },
    );
    if (resp.status === 404) return { status: LOG_STATUS.NOT_PUBLISHED };
    if (!resp.ok) return { status: LOG_STATUS.UNAVAILABLE };
    bundle = await resp.json();
  } catch {
    return { status: LOG_STATUS.UNAVAILABLE };
  }

  try {
    return await _verifyBundle(bundle, { peerPublicKey, peerPqPublicKey });
  } catch (e) {
    console.error("transparency_log: bundle verification failed:", e);
    return { status: LOG_STATUS.PROOF_INVALID };
  }
}

async function _verifyBundle(bundle, { peerPublicKey, peerPqPublicKey }) {
  const index = bundle.index;
  const leafBytes = b64DecodeBytes(bundle.leaf || "");
  if (!Number.isSafeInteger(index) || leafBytes.length === 0) {
    return { status: LOG_STATUS.PROOF_INVALID };
  }

  // 1. Parse the leaf and compare the bound keys to the served keys.
  const leaf = parseLeaf(leafBytes);
  if (!leaf) return { status: LOG_STATUS.PROOF_INVALID };

  if (leaf.encX25519 !== peerPublicKey || leaf.encPq !== peerPqPublicKey) {
    return { status: LOG_STATUS.KEY_MISMATCH, index };
  }

  // 2. Recompute the RFC 6962 leaf hash.
  const leafHash = await _rfc6962LeafHash(leafBytes);
  if (b64EncodeBytes(leafHash) !== bundle.leaf_hash) {
    return { status: LOG_STATUS.PROOF_INVALID };
  }

  // 3. Without a signed checkpoint, the leaf is publicly posted but not yet
  //    anchored — the next checkpoint run covers it.
  const checkpoint = bundle.checkpoint;
  const proof = bundle.inclusion_proof;
  if (!checkpoint || !checkpoint.note || !proof) {
    return { status: LOG_STATUS.PENDING_CHECKPOINT, index };
  }

  // 4. Verify the checkpoint note against the pinned namespace key, and the
  //    served checkpoint fields against the signed body.
  const noteResult = await verifyCheckpointNote(checkpoint.note);
  if (!noteResult.ok) {
    if (noteResult.unsupported) {
      // Browser lacks WebCrypto Ed25519 — cannot complete the proof chain.
      // Degrade honestly: report the leaf as posted but unanchored.
      return { status: LOG_STATUS.PENDING_CHECKPOINT, index };
    }
    return { status: LOG_STATUS.PROOF_INVALID, index };
  }

  if (
    noteResult.origin !== LOG_ORIGIN ||
    noteResult.origin !== checkpoint.origin ||
    noteResult.size !== checkpoint.size ||
    noteResult.root !== checkpoint.root
  ) {
    return { status: LOG_STATUS.PROOF_INVALID, index };
  }

  // 5. Verify the RFC 6962 inclusion proof up to the verified checkpoint root.
  if (
    proof.index !== index ||
    proof.size !== checkpoint.size ||
    proof.leaf_hash !== bundle.leaf_hash ||
    !Array.isArray(proof.proof)
  ) {
    return { status: LOG_STATUS.PROOF_INVALID, index };
  }

  const included = await verifyInclusionProof(
    leafHash,
    index,
    checkpoint.size,
    proof.proof.map(b64DecodeBytes),
    b64DecodeBytes(checkpoint.root),
  );
  if (!included) return { status: LOG_STATUS.PROOF_INVALID, index };

  const witnessNames = noteResult.witnesses || [];
  return {
    status: LOG_STATUS.ANCHORED,
    index,
    size: checkpoint.size,
    checkpointVerified: true,
    witnesses: witnessNames.length,
    witnessNames,
  };
}

// ---------------------------------------------------------------------------
// Leaf parsing — canonical `key-history/v1` layout (brand-independent):
//   u32_be(1) || u64_be(seq) || u64_be(ts_ms)
//   || lp(enc_x25519) || lp(enc_pq) || lp(signing_pub) || lp(prev_entry_hash)
//   where lp(x) = u32_be(byteLength(x)) || x
// ---------------------------------------------------------------------------

/**
 * Parse canonical key-history leaf bytes into their public fields (base64).
 * Returns null on any malformed input.
 */
export function parseLeaf(bytes) {
  try {
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    let off = 0;

    const version = view.getUint32(off, false);
    off += 4;
    if (version !== 1) return null;

    // u64 seq/ts are read as two u32 halves (values stay < 2^53).
    const seq =
      view.getUint32(off, false) * 0x100000000 + view.getUint32(off + 4, false);
    off += 8;
    const ts =
      view.getUint32(off, false) * 0x100000000 + view.getUint32(off + 4, false);
    off += 8;

    const readLp = () => {
      const len = view.getUint32(off, false);
      off += 4;
      if (off + len > bytes.length) throw new Error("lp overrun");
      const slice = bytes.subarray(off, off + len);
      off += len;
      return slice;
    };

    const encX25519 = b64EncodeBytes(readLp());
    const encPq = b64EncodeBytes(readLp());
    const signingPub = b64EncodeBytes(readLp());
    const prevHashRaw = readLp();

    if (off !== bytes.length) return null;

    return {
      seq,
      ts,
      encX25519,
      encPq,
      signingPub,
      prevHash: prevHashRaw.length ? b64EncodeBytes(prevHashRaw) : null,
    };
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Checkpoint note verification (C2SP signed-note + tlog-checkpoint)
// ---------------------------------------------------------------------------

/**
 * Verify a C2SP signed-note checkpoint against the PINNED namespace Ed25519
 * public key, and parse the committed {origin, size, root} from its body.
 *
 * Wire details (locked against the `metamorphic_log` NIF):
 *   - The signed message is the note text up to the first signature line
 *     EXCLUDING the blank separator line — sliced verbatim, never reassembled.
 *   - Signature lines are `— <name> <base64(keyID || signature)>`, where
 *     keyID is the first 4 bytes of SHA-256(name || 0x0a || 0x01 || pubkey32)
 *     (C2SP signed-note). The line matching the PINNED key's ID is selected —
 *     a dual note also carries a (much larger) hybrid line under the same name,
 *     which is ignored here.
 *   - Witness cosignature lines (any name present in WITNESS_ED25519_VKEYS or
 *     WITNESS_MLDSA44_VKEYS) are additionally verified — Ed25519 (0x04) via
 *     WebCrypto and ML-DSA-44 (0x06) via the vendored metamorphic-log WASM —
 *     see _verifyWitnessCosignatures. The verified witness names ride back on
 *     `witnesses`; they never affect `ok`.
 *
 * @returns {Promise<{ok: boolean, origin?: string, size?: number, root?: string, unsupported?: boolean, witnesses?: string[]}>}
 */
export async function verifyCheckpointNote(noteText) {
  if (typeof noteText !== "string" || !noteText) return { ok: false };

  const sigStart = noteText.search(/^— /m);
  if (sigStart < 0) return { ok: false };

  // The blank separator line before the signatures is NOT signed.
  let message = noteText.slice(0, sigStart);
  if (message.endsWith("\n\n")) message = message.slice(0, -1);

  const sigLines = noteText
    .slice(sigStart)
    .split("\n")
    .filter((l) => l.startsWith("— "));

  // Parse the checkpoint body: origin \n size \n root \n (extensions ignored).
  const bodyLines = message.replace(/\n+$/, "").split("\n");
  if (bodyLines.length < 3) return { ok: false };
  const origin = bodyLines[0];
  const size = Number.parseInt(bodyLines[1], 10);
  const root = bodyLines[2];
  if (!origin || !Number.isSafeInteger(size) || !root) return { ok: false };

  const pubBytes = b64DecodeBytes(LOG_CHECKPOINT_ED25519_VK);

  // The pinned key's C2SP key ID selects its signature line.
  const kidInput = new Uint8Array(LOG_ORIGIN.length + 2 + pubBytes.length);
  kidInput.set(new TextEncoder().encode(LOG_ORIGIN), 0);
  kidInput[LOG_ORIGIN.length] = 0x0a;
  kidInput[LOG_ORIGIN.length + 1] = 0x01;
  kidInput.set(pubBytes, LOG_ORIGIN.length + 2);
  const pinnedKid = (await _sha256(kidInput)).subarray(0, 4);

  let key;
  try {
    key = await crypto.subtle.importKey(
      "raw",
      pubBytes,
      { name: "Ed25519" },
      false,
      ["verify"],
    );
  } catch {
    return { ok: false, unsupported: true };
  }

  const messageBytes = new TextEncoder().encode(message);

  for (const line of sigLines) {
    const parsed = _parseSigLine(line);
    if (!parsed) continue;
    const [name, sigBytes] = parsed;
    if (name !== LOG_ORIGIN || sigBytes.length !== 68) continue;
    if (!_bytesEqual(sigBytes.subarray(0, 4), pinnedKid)) continue;
    try {
      const ok = await crypto.subtle.verify(
        { name: "Ed25519" },
        key,
        sigBytes.subarray(4),
        messageBytes,
      );
      if (ok) {
        // The note is authentic. Additively verify any pinned-witness
        // cosignatures riding on the same note (never affects `ok`).
        const witnesses = await _verifyWitnessCosignatures(sigLines, message);
        return { ok: true, origin, size, root, witnesses };
      }
    } catch {
      return { ok: false, unsupported: true };
    }
  }

  return { ok: false };
}

// ---------------------------------------------------------------------------
// Witness cosignature verification (C2SP tlog-cosignature v1: Ed25519 0x04 +
// ML-DSA-44 0x06)
// ---------------------------------------------------------------------------

// Byte length of a 0x04 cosignature line's decoded blob:
// keyID[4] || timestamp[8] || ed25519 signature[64].
const COSIG_V1_ED25519_BLOB_LEN = 4 + 8 + 64;
// Byte length of a 0x06 cosignature line's decoded blob:
// keyID[4] || timestamp[8] || ml_dsa_44 signature[2420].
const COSIG_V1_MLDSA44_BLOB_LEN = 4 + 8 + 2420;

/**
 * Verify the witness cosignature lines of an already-authentic checkpoint
 * note against the PINNED witness roster, returning the sorted names of the
 * unique witnesses whose cosignature cryptographically verified.
 *
 * Two cosignature flavors are understood, both C2SP tlog-cosignature v1:
 *
 *   - 0x04 (Ed25519): `— <name> <base64(keyID[4] || u64be timestamp ||
 *     sig[64])>`, message `cosignature/v1\ntime <timestamp>\n<checkpoint
 *     body>`, verified with WebCrypto against WITNESS_ED25519_VKEYS.
 *   - 0x06 (ML-DSA-44): `— <name> <base64(keyID[4] || u64be timestamp ||
 *     ml_dsa_44_signature[2420])>`, message `subtree/v1\n\0` domain-separated
 *     blob, verified with the vendored metamorphic-log WASM
 *     (`verifySignedNote`) against WITNESS_MLDSA44_VKEYS.
 *
 * Lines are verified one at a time against a mini-note
 * (`<checkpoint body>\n\n<line>\n`) so the WASM's strict behavior — it throws
 * if a known key's line fails — stays contained to that one line and can never
 * take down the note's own verdict or another witness.
 *
 * Strictly additive by contract: unknown names, wrong-length blobs, key-id
 * mismatches, failed signatures, and WASM-load failures are all excluded with
 * at most a console.debug — a cosignature can only ever ADD confidence, never
 * downgrade the note's own verdict. Each witness counts at most once
 * (duplicate lines don't inflate, and a witness that verifies on either
 * flavor counts once).
 */
async function _verifyWitnessCosignatures(sigLines, message) {
  const edRoster = Object.keys(WITNESS_ED25519_VKEYS);
  const mldsaRoster = Object.keys(WITNESS_MLDSA44_VKEYS);
  if (edRoster.length === 0 && mldsaRoster.length === 0) return [];

  const verified = new Set();

  // Load the metamorphic-log WASM once (lazily, only when a 0x06 candidate
  // actually appears) — a load failure only disables 0x06 cosignatures, never
  // the rest of the verdict.
  let wasmReady = false;
  let wasmError = null;
  const ensureMldsa = async () => {
    if (wasmReady || wasmError) return;
    try {
      await ensureReady();
      wasmReady = true;
    } catch (e) {
      wasmError = e;
      console.debug(
        "transparency_log: metamorphic-log WASM unavailable, ML-DSA-44 cosignatures will not be verified:",
        e,
      );
    }
  };

  for (const line of sigLines) {
    const parsed = _parseSigLine(line);
    if (!parsed) continue;
    const [name, blob] = parsed;
    if (verified.has(name)) continue;

    const pinnedEd =
      edRoster.length > 0 &&
      Object.prototype.hasOwnProperty.call(WITNESS_ED25519_VKEYS, name);
    const pinnedMldsa =
      mldsaRoster.length > 0 &&
      Object.prototype.hasOwnProperty.call(WITNESS_MLDSA44_VKEYS, name);
    if (!pinnedEd && !pinnedMldsa) continue;

    const blobLen = blob.length;
    let attempted = false;

    // --- 0x04 (Ed25519, WebCrypto) ---
    if (pinnedEd && blobLen === COSIG_V1_ED25519_BLOB_LEN) {
      attempted = true;
      const vkey = _parseEd25519Vkey(WITNESS_ED25519_VKEYS[name]);
      if (!vkey || vkey.name !== name) {
        console.debug(
          `transparency_log: malformed pinned Ed25519 vkey for ${name}`,
        );
      } else {
        const { pubBytes, keyIdBytes } = vkey;

        // The line's declared key id must match the pinned key's 0x04 id.
        const nameBytes = new TextEncoder().encode(name);
        const kidInput = new Uint8Array(nameBytes.length + 2 + pubBytes.length);
        kidInput.set(nameBytes, 0);
        kidInput[nameBytes.length] = 0x0a;
        kidInput[nameBytes.length + 1] = 0x04;
        kidInput.set(pubBytes, nameBytes.length + 2);
        const expectedKid = (await _sha256(kidInput)).subarray(0, 4);
        if (!_bytesEqual(keyIdBytes, expectedKid)) {
          // The pinned string itself is inconsistent — its embedded key id
          // doesn't recompute from its own key, so never trust it.
          console.debug(
            `transparency_log: pinned Ed25519 vkey key-id mismatch for ${name}`,
          );
        } else if (!_bytesEqual(blob.subarray(0, 4), expectedKid)) {
          console.debug(
            `transparency_log: cosignature key-id mismatch from ${name}`,
          );
        } else {
          const view = new DataView(
            blob.buffer,
            blob.byteOffset,
            blob.byteLength,
          );
          const timestamp =
            view.getUint32(4, false) * 0x100000000 + view.getUint32(8, false);
          const cosigned = new TextEncoder().encode(
            `cosignature/v1\ntime ${timestamp}\n${message}`,
          );

          try {
            const key = await crypto.subtle.importKey(
              "raw",
              pubBytes,
              { name: "Ed25519" },
              false,
              ["verify"],
            );
            const ok = await crypto.subtle.verify(
              { name: "Ed25519" },
              key,
              blob.subarray(12),
              cosigned,
            );
            if (ok) {
              verified.add(name);
            } else {
              console.debug(
                `transparency_log: cosignature failed verification from ${name}`,
              );
            }
          } catch (e) {
            console.debug(
              `transparency_log: cosignature verify error from ${name}:`,
              e,
            );
          }
        }
      }
    }

    // --- 0x06 (ML-DSA-44, vendored metamorphic-log WASM) ---
    if (pinnedMldsa && blobLen === COSIG_V1_MLDSA44_BLOB_LEN) {
      attempted = true;
      await ensureMldsa();
      if (wasmReady) {
        // Isolate this one line: `<checkpoint body>\n\n<line>\n`. The 0x06
        // cosigned message is built from the canonical body (origin/size/root
        // without its trailing newline — unlike the 0x04 `cosignature/v1`
        // message, which includes it), so the mini-note's body must not end
        // with a newline. verifySignedNote throws (e.g. InvalidSignature for a
        // forged known-key line, NoTrustedSignature on a key-id mismatch) —
        // catch and treat as "not verified".
        try {
          const bodyText = message.endsWith("\n")
            ? message.slice(0, -1)
            : message;
          const miniNote = `${bodyText}\n\n${line}\n`;
          const count = _verifySignedNote(miniNote, [
            WITNESS_MLDSA44_VKEYS[name],
          ]);
          if (count >= 1) {
            verified.add(name);
          } else {
            console.debug(
              `transparency_log: ML-DSA-44 cosignature failed verification from ${name}`,
            );
          }
        } catch (e) {
          console.debug(
            `transparency_log: ML-DSA-44 cosignature verify error from ${name}:`,
            e,
          );
        }
      }
    }

    if (!attempted) {
      console.debug(
        `transparency_log: ignoring malformed cosignature line from ${name}`,
      );
    }
  }

  return [...verified].sort();
}

/**
 * Parse a pinned C2SP Ed25519 (0x04) verifier-key string
 * (`<name>+<8-hex key id>+<base64(0x04 || pubkey)>`) into its parts.
 * Splits on the FIRST two "+" only — the base64 tail may itself contain
 * "+" (the reference note.NewVerifier does the same). Returns
 * `{ name, keyIdBytes, pubBytes }`, where pubBytes is the raw 32-byte
 * Ed25519 public key WebCrypto wants, or null on any malformed input.
 */
function _parseEd25519Vkey(vkey) {
  if (typeof vkey !== "string") return null;
  const i = vkey.indexOf("+");
  const j = i < 0 ? -1 : vkey.indexOf("+", i + 1);
  if (i <= 0 || j < 0) return null;
  const keyIdHex = vkey.slice(i + 1, j);
  if (!/^[0-9a-f]{8}$/.test(keyIdHex)) return null;
  let raw;
  try {
    raw = b64DecodeBytes(vkey.slice(j + 1));
  } catch {
    return null;
  }
  if (raw.length !== 33 || raw[0] !== 0x04) return null;
  const keyIdBytes = new Uint8Array(4);
  for (let k = 0; k < 4; k++) {
    keyIdBytes[k] = Number.parseInt(keyIdHex.slice(k * 2, k * 2 + 2), 16);
  }
  return { name: vkey.slice(0, i), keyIdBytes, pubBytes: raw.subarray(1) };
}

function _parseSigLine(line) {
  const rest = line.slice(2); // strip "— "
  const sp = rest.indexOf(" ");
  if (sp <= 0) return null;
  try {
    return [rest.slice(0, sp), b64DecodeBytes(rest.slice(sp + 1))];
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// RFC 6962 Merkle proofs
// ---------------------------------------------------------------------------

async function _rfc6962LeafHash(leafBytes) {
  const framed = new Uint8Array(1 + leafBytes.length);
  framed[0] = 0x00;
  framed.set(leafBytes, 1);
  return _sha256(framed);
}

function _nodeHash(left, right) {
  const framed = new Uint8Array(1 + left.length + right.length);
  framed[0] = 0x01;
  framed.set(left, 1);
  framed.set(right, 1 + left.length);
  return _sha256(framed);
}

/**
 * Walk an RFC 6962 §2.1.1 audit path from `leafHash` and compare the computed
 * root to `expectedRoot`.
 *
 * @param {Uint8Array} leafHash
 * @param {number} leafIndex
 * @param {number} treeSize
 * @param {Uint8Array[]} path - sibling hashes, bottom-up
 * @param {Uint8Array} expectedRoot
 * @returns {Promise<boolean>}
 */
export async function verifyInclusionProof(
  leafHash,
  leafIndex,
  treeSize,
  path,
  expectedRoot,
) {
  if (
    !(leafHash instanceof Uint8Array) ||
    !(expectedRoot instanceof Uint8Array) ||
    !Number.isSafeInteger(leafIndex) ||
    !Number.isSafeInteger(treeSize) ||
    leafIndex < 0 ||
    treeSize <= 0 ||
    leafIndex >= treeSize
  ) {
    return false;
  }

  let r = leafHash;
  let fn = leafIndex;
  let sn = treeSize - 1;

  for (const p of path) {
    if (!(p instanceof Uint8Array) || p.length !== 32) return false;
    if ((fn & 1) === 1 || fn === sn) {
      r = await _nodeHash(p, r);
      // fn was even and equal to sn: climb past the promoted (unpaired) nodes.
      while ((fn & 1) === 0 && fn !== 0) {
        fn >>>= 1;
        sn >>>= 1;
      }
    } else {
      r = await _nodeHash(r, p);
    }
    fn >>>= 1;
    sn >>>= 1;
  }

  return fn === 0 && _bytesEqual(r, expectedRoot);
}

// ---------------------------------------------------------------------------
// Small helpers (self-contained: WebCrypto + atob/btoa only)
// ---------------------------------------------------------------------------

async function _sha256(bytes) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

function _bytesEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

function b64EncodeBytes(uint8Array) {
  let binary = "";
  for (let i = 0; i < uint8Array.length; i++) {
    binary += String.fromCharCode(uint8Array[i]);
  }
  return btoa(binary);
}

function b64DecodeBytes(base64String) {
  const binary = atob(base64String);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// Tiny concurrency pool so a page of connection cards doesn't fire N fetches
// at once; upstream is CDN-cacheable public data, so 4 is plenty.
function _enqueue(task) {
  return new Promise((resolve, reject) => {
    _queue.push({ task, resolve, reject });
    _pump();
  });
}

function _pump() {
  while (_active < MAX_IN_FLIGHT && _queue.length) {
    const { task, resolve, reject } = _queue.shift();
    _active++;
    task()
      .then(resolve, reject)
      .finally(() => {
        _active--;
        _pump();
      });
  }
}

function _dispatch(peerUserId, result) {
  try {
    window.dispatchEvent(
      new CustomEvent(PEER_LOG_STATUS_EVENT, {
        detail: {
          peerUserId,
          status: result.status,
          index: result.index ?? null,
          size: result.size ?? null,
          witnesses: result.witnesses ?? 0,
          witnessNames: result.witnessNames ?? [],
        },
      }),
    );
  } catch {
    // best-effort: a failed dispatch must never break the caller
  }
}

// Test-only introspection (never secret material).
export function _debugCache() {
  return _cache;
}
