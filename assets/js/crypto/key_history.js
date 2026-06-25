/**
 * Signed key history (EPIC #291 / #290 step 4 — board #315).
 *
 * Upgrades the interim TOFU key-pinning (#293-296, #302) into a signed,
 * append-only, hash-chained key history so a client can cryptographically
 * distinguish a LEGITIMATE key rotation from a server key-SUBSTITUTION attack
 * (the §7 threat in #290 — the server is the sole, unverified distributor of
 * recipient public keys).
 *
 * ===========================================================================
 * WHAT THIS DOES — AND ITS HONEST LIMITS (keep copy accurate, per #290)
 * ===========================================================================
 * After first-contact pin (still TOFU's job), EVERY subsequent key entry is
 * signed by the PREVIOUS signing key and chained by prev_entry_hash. So
 * post-pin key continuity is cryptographically verifiable and the client
 * self-monitors its own view of a peer's chain (the MONITOR role, #290
 * decision B; wires into the #296 key-change-alert UI).
 *
 * It does NOT:
 *   - solve first-contact substitution (still TOFU — safety numbers / QR remain
 *     the backstop), nor
 *   - solve server equivocation / split-view (that is the later
 *     metamorphic-log + independent-witness job, #299+).
 *
 * Do not overclaim. "hybrid PQ signatures, NCC-audited primitives, pure-Rust" —
 * never "FIPS validated".
 *
 * ===========================================================================
 * CANONICAL LEAF FORMAT  (mosslet/key-history/v1)
 * ===========================================================================
 * A single FIXED, byte-reproducible serialization, hashed with
 * sha3_512WithContext under a versioned context and signed with the hybrid PQ
 * composite signature (ML-DSA-87 + Ed25519, Cat-5, strict-AND). Built to be
 * absorbed UNCHANGED as a metamorphic-log leaf later (#299/#316) — never
 * reformat to scale; scale by adding tiles/witnesses, not by changing bytes.
 *
 * Canonical bytes (all length prefixes are big-endian u32; integers big-endian):
 *
 *   canonical(entry) =
 *       u32_be(VERSION = 1)
 *    || u64_be(seq)                 // monotonic, genesis = 0
 *    || u64_be(ts_ms)               // unix epoch milliseconds (UTC)
 *    || lp(enc_x25519_raw)          // recipient X25519 encryption pubkey
 *    || lp(enc_pq_raw)              // recipient ML-KEM encryption pubkey
 *    || lp(signing_pub_raw)         // the hybrid signing pubkey THIS entry pins
 *    || lp(prev_entry_hash_raw)     // 0-length for the genesis entry
 *
 *   where lp(x) = u32_be(byteLength(x)) || x
 *
 * entry_hash = sha3_512WithContext("mosslet/key-history/v1", base64(canonical))
 *              (64-byte digest, base64) — this is what the NEXT entry chains to.
 *
 * signature  = sign(canonical, signerSecretKey, "mosslet/key-history/v1")
 *   - genesis (seq 0): SELF-signed by its own signing secret. Trust in the
 *     genesis signing key comes from TOFU/safety-number, NOT from this sig.
 *   - rotation (seq N>0): signed by the PREVIOUS entry's signing secret, so the
 *     holder of the prior (already-pinned/verified) key authorizes the new key.
 *     This is the cryptographic continuity TOFU alone cannot provide.
 *
 * The stored record is plain public material (no secrets) so it can be served
 * to connections for monitoring and later become a transparency-log leaf:
 *
 *   {
 *     v: 1, seq, ts,                 // ts = unix ms (number)
 *     enc_x25519, enc_pq, sign_pub,  // base64 public keys
 *     prev_hash,                     // base64 (or "" for genesis)
 *     entry_hash,                    // base64 sha3-512 of canonical
 *     sig                            // base64 composite signature
 *   }
 *
 * Reproduced byte-for-byte by the server-side NIF + KAT test
 * (test/mosslet/crypto/key_history_test.exs), the byte-reproducibility lock.
 */

import {
  b64Encode,
  b64Decode,
  sha3_512WithContext,
  sign,
  verify,
} from "./nacl.js";

export const KEY_HISTORY_CONTEXT = "mosslet/key-history/v1";
export const KEY_HISTORY_VERSION = 1;

export const CHAIN_STATUS = {
  VALID: "valid", // chain verifies from pinned root to head
  INVALID: "invalid", // a signature / hash / sequence check failed
  ROOT_MISMATCH: "root_mismatch", // genesis signing key != pinned root
  EMPTY: "empty", // no entries supplied
};

// --- byte helpers ----------------------------------------------------------

function u32be(n) {
  return Uint8Array.of((n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff);
}

// 64-bit big-endian. seq/ts stay well within Number.MAX_SAFE_INTEGER, so we
// split into high/low 32-bit halves without BigInt for portability.
function u64be(n) {
  const hi = Math.floor(n / 0x100000000);
  const lo = n >>> 0;
  return Uint8Array.of(
    (hi >>> 24) & 0xff, (hi >>> 16) & 0xff, (hi >>> 8) & 0xff, hi & 0xff,
    (lo >>> 24) & 0xff, (lo >>> 16) & 0xff, (lo >>> 8) & 0xff, lo & 0xff,
  );
}

function lengthPrefixed(bytes) {
  const out = new Uint8Array(4 + bytes.length);
  out.set(u32be(bytes.length), 0);
  out.set(bytes, 4);
  return out;
}

function concatBytes(parts) {
  let total = 0;
  for (const p of parts) total += p.length;
  const out = new Uint8Array(total);
  let off = 0;
  for (const p of parts) {
    out.set(p, off);
    off += p.length;
  }
  return out;
}

/**
 * Build the canonical, byte-reproducible serialization for a key-history entry.
 * See the CANONICAL LEAF FORMAT spec above. Pure function of the entry fields.
 *
 * @param {Object} fields
 * @param {number} fields.seq - monotonic sequence (genesis = 0)
 * @param {number} fields.ts - unix epoch milliseconds
 * @param {string} fields.enc_x25519 - X25519 encryption pubkey (base64)
 * @param {string} fields.enc_pq - ML-KEM encryption pubkey (base64)
 * @param {string} fields.sign_pub - hybrid signing pubkey this entry pins (base64)
 * @param {string} fields.prev_hash - prev entry_hash (base64), or "" for genesis
 * @returns {Uint8Array} canonical bytes
 */
export function canonicalEntryBytes({ seq, ts, enc_x25519, enc_pq, sign_pub, prev_hash }) {
  if (!enc_x25519 || !enc_pq || !sign_pub) {
    throw new Error("canonicalEntryBytes: encryption + signing public keys are required");
  }
  if (!Number.isSafeInteger(seq) || seq < 0) {
    throw new Error("canonicalEntryBytes: seq must be a non-negative safe integer");
  }
  if (!Number.isSafeInteger(ts) || ts < 0) {
    throw new Error("canonicalEntryBytes: ts must be a non-negative safe integer");
  }
  const prevRaw = prev_hash ? b64Decode(prev_hash) : new Uint8Array(0);
  return concatBytes([
    u32be(KEY_HISTORY_VERSION),
    u64be(seq),
    u64be(ts),
    lengthPrefixed(b64Decode(enc_x25519)),
    lengthPrefixed(b64Decode(enc_pq)),
    lengthPrefixed(b64Decode(sign_pub)),
    lengthPrefixed(prevRaw),
  ]);
}

/**
 * Compute the entry_hash (base64 sha3-512 over the context-framed canonical
 * bytes) for a set of entry fields.
 * @param {Object} fields - same shape as canonicalEntryBytes
 * @returns {Promise<string>} base64 64-byte digest
 */
export async function entryHash(fields) {
  const canonical = canonicalEntryBytes(fields);
  return sha3_512WithContext(KEY_HISTORY_CONTEXT, b64Encode(canonical));
}

/**
 * Build a GENESIS entry (seq 0). Self-signed by its own signing secret; the
 * resulting signing public key is what peers TOFU-pin as the chain root.
 *
 * @param {Object} args
 * @param {string} args.encX25519 - X25519 encryption pubkey (base64)
 * @param {string} args.encPq - ML-KEM encryption pubkey (base64)
 * @param {string} args.signingPublicKey - hybrid signing pubkey (base64)
 * @param {string} args.signingSecretKey - hybrid signing secret key (base64)
 * @param {number} [args.ts=Date.now()] - unix epoch ms
 * @returns {Promise<Object>} the public entry record
 */
export async function buildGenesisEntry({
  encX25519,
  encPq,
  signingPublicKey,
  signingSecretKey,
  ts = Date.now(),
}) {
  const fields = {
    seq: 0,
    ts,
    enc_x25519: encX25519,
    enc_pq: encPq,
    sign_pub: signingPublicKey,
    prev_hash: "",
  };
  const canonical = canonicalEntryBytes(fields);
  const hash = await sha3_512WithContext(KEY_HISTORY_CONTEXT, b64Encode(canonical));
  const sig = await sign(canonical, signingSecretKey, KEY_HISTORY_CONTEXT);
  return {
    v: KEY_HISTORY_VERSION,
    seq: 0,
    ts,
    enc_x25519: encX25519,
    enc_pq: encPq,
    sign_pub: signingPublicKey,
    prev_hash: "",
    entry_hash: hash,
    sig,
  };
}

/**
 * Build a ROTATION entry (seq = prev.seq + 1). Signed by the PREVIOUS signing
 * secret key (chain-of-trust handoff): the holder of the already-pinned prior
 * key authorizes the new key material. Chains via prev_hash = prev.entry_hash.
 *
 * @param {Object} args
 * @param {Object} args.prevEntry - the previous (head) entry record
 * @param {string} args.encX25519 - NEW X25519 encryption pubkey (base64)
 * @param {string} args.encPq - NEW ML-KEM encryption pubkey (base64)
 * @param {string} args.signingPublicKey - NEW hybrid signing pubkey (base64)
 * @param {string} args.prevSigningSecretKey - PREVIOUS signing secret (base64) — signs this entry
 * @param {number} [args.ts=Date.now()] - unix epoch ms
 * @returns {Promise<Object>} the public entry record
 */
export async function buildRotationEntry({
  prevEntry,
  encX25519,
  encPq,
  signingPublicKey,
  prevSigningSecretKey,
  ts = Date.now(),
}) {
  if (!prevEntry || !prevEntry.entry_hash || !Number.isSafeInteger(prevEntry.seq)) {
    throw new Error("buildRotationEntry: a valid previous entry is required");
  }
  const seq = prevEntry.seq + 1;
  const fields = {
    seq,
    ts,
    enc_x25519: encX25519,
    enc_pq: encPq,
    sign_pub: signingPublicKey,
    prev_hash: prevEntry.entry_hash,
  };
  const canonical = canonicalEntryBytes(fields);
  const hash = await sha3_512WithContext(KEY_HISTORY_CONTEXT, b64Encode(canonical));
  const sig = await sign(canonical, prevSigningSecretKey, KEY_HISTORY_CONTEXT);
  return {
    v: KEY_HISTORY_VERSION,
    seq,
    ts,
    enc_x25519: encX25519,
    enc_pq: encPq,
    sign_pub: signingPublicKey,
    prev_hash: prevEntry.entry_hash,
    entry_hash: hash,
    sig,
  };
}

/**
 * Verify a single entry's self-consistency (entry_hash recomputes) and its
 * signature against an EXPLICIT signer public key.
 *
 *   - For a genesis entry, signerPublicKey is the entry's own sign_pub.
 *   - For a rotation entry, signerPublicKey is the PREVIOUS entry's sign_pub.
 *
 * @param {Object} entry - public entry record
 * @param {string} signerPublicKey - hybrid signing pubkey expected to have signed it (base64)
 * @returns {Promise<boolean>}
 */
export async function verifyEntry(entry, signerPublicKey) {
  if (!entry || !signerPublicKey || typeof entry.sig !== "string") return false;
  let canonical;
  try {
    canonical = canonicalEntryBytes(entry);
  } catch {
    return false;
  }
  // entry_hash must match the canonical bytes (tamper / reformat detection).
  let expectedHash;
  try {
    expectedHash = await sha3_512WithContext(KEY_HISTORY_CONTEXT, b64Encode(canonical));
  } catch {
    return false;
  }
  if (entry.entry_hash !== expectedHash) return false;
  try {
    return await verify(canonical, entry.sig, signerPublicKey, KEY_HISTORY_CONTEXT);
  } catch {
    return false;
  }
}

/**
 * Chain-validate a FULL key history against a pinned root signing public key.
 *
 * Walks from genesis to head, enforcing:
 *   1. entries[0].seq === 0 and its sign_pub === pinnedRootSigningPub (the TOFU
 *      anchor) — otherwise ROOT_MISMATCH (the server served a different chain).
 *   2. genesis self-signature verifies.
 *   3. each entry[i] (i>0): seq === i, prev_hash === entries[i-1].entry_hash,
 *      and its signature verifies under entries[i-1].sign_pub.
 *
 * A VALID result means the head's key material is a cryptographically continuous
 * rotation from the pinned root → legitimate. Any failure → INVALID/ROOT_MISMATCH,
 * which the monitor surfaces as the existing key-change alert (#296) instead of
 * silently trusting a substituted key.
 *
 * @param {Object[]} entries - ordered (by seq) public entry records
 * @param {string} pinnedRootSigningPub - the signing pubkey pinned at first contact (base64)
 * @returns {Promise<{status: string, valid: boolean, headEntry: Object|null, headSigningPub: string|null, reason: string|null}>}
 */
export async function verifyChain(entries, pinnedRootSigningPub) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return { status: CHAIN_STATUS.EMPTY, valid: false, headEntry: null, headSigningPub: null, reason: "no entries" };
  }

  const genesis = entries[0];
  if (genesis.seq !== 0) {
    return fail(CHAIN_STATUS.INVALID, "first entry is not genesis (seq 0)");
  }
  if (pinnedRootSigningPub && genesis.sign_pub !== pinnedRootSigningPub) {
    return { status: CHAIN_STATUS.ROOT_MISMATCH, valid: false, headEntry: null, headSigningPub: null, reason: "genesis signing key does not match pinned root" };
  }
  if (!(await verifyEntry(genesis, genesis.sign_pub))) {
    return fail(CHAIN_STATUS.INVALID, "genesis self-signature invalid");
  }

  for (let i = 1; i < entries.length; i++) {
    const prev = entries[i - 1];
    const cur = entries[i];
    if (cur.seq !== i) {
      return fail(CHAIN_STATUS.INVALID, `seq gap/reorder at index ${i}`);
    }
    if (!cur.prev_hash || cur.prev_hash !== prev.entry_hash) {
      return fail(CHAIN_STATUS.INVALID, `broken hash chain at index ${i}`);
    }
    // Each rotation is authorized by the PREVIOUS signing key.
    if (!(await verifyEntry(cur, prev.sign_pub))) {
      return fail(CHAIN_STATUS.INVALID, `signature invalid at index ${i}`);
    }
  }

  const head = entries[entries.length - 1];
  return {
    status: CHAIN_STATUS.VALID,
    valid: true,
    headEntry: head,
    headSigningPub: head.sign_pub,
    reason: null,
  };

  function fail(status, reason) {
    return { status, valid: false, headEntry: null, headSigningPub: null, reason };
  }
}

/**
 * Convenience: do the served encryption keys match the validated head entry?
 * The monitor uses this after verifyChain to confirm the chain actually leads
 * to the key the server is serving RIGHT NOW (not just any valid chain).
 *
 * @param {Object} headEntry - the VALID head entry from verifyChain
 * @param {string} servedX25519 - X25519 encryption pubkey the server served (base64)
 * @param {string} servedPq - ML-KEM encryption pubkey the server served (base64)
 * @returns {boolean}
 */
export function headMatchesServedKeys(headEntry, servedX25519, servedPq) {
  if (!headEntry) return false;
  return headEntry.enc_x25519 === servedX25519 && headEntry.enc_pq === servedPq;
}

/**
 * Parse a serialized history (JSON array string or already-an-array) into an
 * ordered array of entry records, sorted ascending by seq. Returns [] on any
 * malformed input — a malformed history is treated as "no verifiable chain".
 *
 * @param {string|Object[]|null} serialized
 * @returns {Object[]}
 */
export function parseHistory(serialized) {
  if (!serialized) return [];
  let arr = serialized;
  if (typeof serialized === "string") {
    try {
      arr = JSON.parse(serialized);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(arr)) return [];
  return arr
    .filter((e) => e && Number.isSafeInteger(e.seq))
    .sort((a, b) => a.seq - b.seq);
}

export { b64Encode, b64Decode };
