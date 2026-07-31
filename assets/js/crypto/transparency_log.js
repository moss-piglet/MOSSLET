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
 *   5. INCLUSION — the RFC 6962 audit path is walked from the leaf hash to
 *      the verified checkpoint root.
 *
 * The trust root is the PINNED namespace checkpoint public key below — public
 * material shipped in the bundle (the same model as CT log keys pinned in
 * browsers), NOT served by the mosslet server (which is the adversary in this
 * threat model). If the checkpoint key rotates, update the constant with the
 * new public key (fetchable from the public `/api/witness/logs` discovery
 * feed, out-of-band verified).
 *
 * HONEST LIMITS (keep copy accurate):
 *   - Anchoring proves PUBLIC COMMITMENT, not key authenticity: TOFU +
 *     out-of-band safety numbers remain the first-contact backstop, and the
 *     signed per-user chain proves rotation continuity.
 *   - A checkpoint sig is verified against a single pinned key; split-view
 *     (equivocation) detection belongs to the witness network, not this file.
 *
 * The module fetches only PUBLIC material and runs entirely client-side.
 */

// --- Pinned log parameters (PUBLIC material) --------------------------------
// Production mosslet namespace on mosskeys.com. To verify against a local or
// staging log in development, point these three at that deployment (the vkey
// is served by its public `/api/witness/logs` feed).
const LOG_BASE_URL = "https://mosskeys.com/api/mosslet";
const LOG_ORIGIN = "mosskeys.com/mosslet";
// Raw 32-byte Ed25519 public half of the namespace's checkpoint signing key
// (the classical line every `sign_dual` checkpoint carries). Base64.
const LOG_CHECKPOINT_ED25519_VK = "1Ltcg/D0+UxGBe5e/ADMMFIfQplIiIkSQDZaARCPxjc=";

export const LOG_STATUS = {
  ANCHORED: "anchored", // all proofs verify; log key == served key
  PENDING_CHECKPOINT: "pending_checkpoint", // in the log, not yet under a signed checkpoint
  NOT_PUBLISHED: "not_published", // peer has no entry in the log (404)
  KEY_MISMATCH: "key_mismatch", // log head key != served key (rotation mid-publish OR substitution)
  PROOF_INVALID: "proof_invalid", // bundle failed cryptographic verification
  UNAVAILABLE: "unavailable", // network/CORS/unsupported crypto — no verdict
};

// Fired on every completed check so any surface (connection-card badge,
// verification modal) can live-update. detail: {peerUserId, status, index, size}.
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
 * @returns {Promise<{status: string, index?: number, size?: number, checkpointVerified?: boolean}>}
 */
export async function checkPeerKeyAnchor({ peerUserId, peerPublicKey, peerPqPublicKey }) {
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

  return {
    status: LOG_STATUS.ANCHORED,
    index,
    size: checkpoint.size,
    checkpointVerified: true,
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
    const seq = view.getUint32(off, false) * 0x100000000 + view.getUint32(off + 4, false);
    off += 8;
    const ts = view.getUint32(off, false) * 0x100000000 + view.getUint32(off + 4, false);
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
 *
 * @returns {Promise<{ok: boolean, origin?: string, size?: number, root?: string, unsupported?: boolean}>}
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
    key = await crypto.subtle.importKey("raw", pubBytes, { name: "Ed25519" }, false, ["verify"]);
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
      if (ok) return { ok: true, origin, size, root };
    } catch {
      return { ok: false, unsupported: true };
    }
  }

  return { ok: false };
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
export async function verifyInclusionProof(leafHash, leafIndex, treeSize, path, expectedRoot) {
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
