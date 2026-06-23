/**
 * Mosslet key fingerprints & safety numbers (Phase 0 — interim key authenticity).
 *
 * Lets a user verify a recipient's hybrid public key out-of-band instead of
 * blindly trusting the server-supplied key. Built entirely on the vendored
 * metamorphic-crypto WASM (domain-separated SHA3-512) — the SAME audited Rust
 * crate as the server-side NIF (MetamorphicCrypto.Hash), so browser and server
 * (and any future SDK) compute byte-for-byte identical values.
 *
 * ============================================================================
 * CANONICALIZATION SPEC  (mosslet/key-fingerprint/v1)
 * ============================================================================
 *
 * A "key fingerprint" is a domain-separated SHA3-512 over the recipient's
 * hybrid public key material (classical X25519 + post-quantum ML-KEM).
 *
 * Inputs (both base64, exactly as stored/distributed by the server):
 *   - publicKey    : X25519 public key   -> 32 raw bytes
 *   - pqPublicKey  : ML-KEM public key   -> 1216 (Cat-3/ML-KEM-768)
 *                                           or 1600 (Cat-5/ML-KEM-1024) raw bytes
 *
 * CANONICAL BYTES (length-prefixed; self-describing across both PQ sizes,
 * with no boundary ambiguity between the two components):
 *
 *     canonical =
 *         u32_be(byteLength(x25519_raw)) || x25519_raw
 *       || u32_be(byteLength(mlkem_raw)) || mlkem_raw
 *
 *   - All length prefixes are big-endian unsigned 32-bit integers.
 *   - Component order is FIXED: X25519 first, ML-KEM second.
 *   - The PQ security level (Cat-3 vs Cat-5) is captured implicitly by the
 *     ML-KEM length prefix; it is NOT encoded separately.
 *
 * FINGERPRINT:
 *
 *     fingerprint = sha3_512WithContext(
 *       "mosslet/key-fingerprint/v1",   // versioned UTF-8 context label
 *       base64(canonical)
 *     )
 *
 *   sha3_512WithContext internally frames the input as
 *       SHA3-512( u64_be(byteLength(context)) || utf8(context) || data )
 *   so the full preimage is:
 *       u64_be(len(label)) || label || canonical
 *
 *   The result is a 64-byte digest, returned base64-encoded.
 *
 * ============================================================================
 * SAFETY NUMBER  (Signal-style, order-independent)
 * ============================================================================
 *
 * For out-of-band comparison, two parties A and B must independently arrive at
 * the SAME number regardless of who is "A". Each party computes BOTH
 * fingerprints (their own + the peer's), then:
 *
 *   1. Per fingerprint: take the first 30 bytes of its 64-byte digest, split
 *      into six 5-byte (40-bit) big-endian chunks; each chunk mod 100000,
 *      zero-padded to 5 digits => a 30-digit string.
 *   2. Sort the two 30-digit strings ascending (lexicographically) so order
 *      doesn't matter, concatenate => 60 digits.
 *   3. Format as 12 groups of 5 digits separated by spaces for display.
 *
 * This mirrors Signal's numeric-fingerprint construction (5-byte chunks mod
 * 100000) and order-independence (sort before concatenation).
 *
 * Reproduced byte-for-byte by test/mosslet/crypto/key_fingerprint_test.exs,
 * which locks KAT vectors via the server-side metamorphic_crypto NIF.
 */

import { b64Encode, b64Decode, sha3_512WithContext } from "./nacl.js";

export const FINGERPRINT_CONTEXT = "mosslet/key-fingerprint/v1";

// Number of leading digest bytes consumed by the safety number, in 5-byte chunks.
const SAFETY_BYTES = 30;
const CHUNK = 5;
const MODULUS = 100000; // 5 decimal digits per chunk
const DISPLAY_GROUP = 5; // digits per displayed group

function u32be(n) {
  return Uint8Array.of((n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff);
}

/**
 * Build the canonical, length-prefixed byte layout for a recipient's hybrid
 * public key material. See the CANONICALIZATION SPEC above.
 *
 * @param {string} publicKeyBase64 - X25519 public key (base64, 32 raw bytes)
 * @param {string} pqPublicKeyBase64 - ML-KEM public key (base64, 1216 or 1600 raw bytes)
 * @returns {Uint8Array} canonical bytes
 */
export function canonicalKeyBytes(publicKeyBase64, pqPublicKeyBase64) {
  if (!publicKeyBase64 || !pqPublicKeyBase64) {
    throw new Error("canonicalKeyBytes: both X25519 and ML-KEM public keys are required");
  }
  const x = b64Decode(publicKeyBase64);
  const pq = b64Decode(pqPublicKeyBase64);

  const out = new Uint8Array(4 + x.length + 4 + pq.length);
  let off = 0;
  out.set(u32be(x.length), off); off += 4;
  out.set(x, off); off += x.length;
  out.set(u32be(pq.length), off); off += 4;
  out.set(pq, off);
  return out;
}

/**
 * Compute the canonical key fingerprint over a recipient's hybrid public key.
 *
 * @param {string} publicKey - X25519 public key (base64)
 * @param {string} pqPublicKey - ML-KEM public key (base64)
 * @returns {Promise<string>} base64-encoded 64-byte SHA3-512 digest
 */
export async function computeFingerprint(publicKey, pqPublicKey) {
  const canonical = canonicalKeyBytes(publicKey, pqPublicKey);
  return sha3_512WithContext(FINGERPRINT_CONTEXT, b64Encode(canonical));
}

/**
 * Derive the 30-digit numeric fingerprint from a fingerprint digest.
 * @param {string} fingerprintBase64 - base64 64-byte digest from computeFingerprint
 * @returns {string} 30-digit string
 */
function numericFingerprint(fingerprintBase64) {
  const digest = b64Decode(fingerprintBase64);
  if (digest.length < SAFETY_BYTES) {
    throw new Error("numericFingerprint: digest too short");
  }
  let out = "";
  for (let i = 0; i < SAFETY_BYTES; i += CHUNK) {
    let value = 0;
    for (let j = 0; j < CHUNK; j++) {
      // 40-bit big-endian accumulation; stays within Number.MAX_SAFE_INTEGER.
      value = value * 256 + digest[i + j];
    }
    out += String(value % MODULUS).padStart(CHUNK, "0");
  }
  return out;
}

function groupDigits(digits, size) {
  const groups = [];
  for (let i = 0; i < digits.length; i += size) {
    groups.push(digits.slice(i, i + size));
  }
  return groups.join(" ");
}

/**
 * Compute the order-independent safety number for two fingerprints.
 *
 * Both parties pass the SAME pair of fingerprints (their own + the peer's) in
 * either order and receive the identical 60-digit number (12 groups of 5).
 *
 * @param {string} aFp - a fingerprint digest (base64) from computeFingerprint
 * @param {string} bFp - the other fingerprint digest (base64)
 * @returns {string} 60-digit safety number, formatted as 12 groups of 5
 */
export function safetyNumber(aFp, bFp) {
  const a = numericFingerprint(aFp);
  const b = numericFingerprint(bFp);
  const [lo, hi] = a <= b ? [a, b] : [b, a];
  return groupDigits(lo + hi, DISPLAY_GROUP);
}

/**
 * Render a single fingerprint digest as grouped uppercase hex for at-a-glance
 * per-key display (32 groups of 4 hex chars for a 64-byte digest).
 *
 * @param {string} fingerprintBase64 - base64 64-byte digest from computeFingerprint
 * @returns {string} grouped uppercase hex
 */
export function displayFingerprint(fingerprintBase64) {
  const digest = b64Decode(fingerprintBase64);
  let hex = "";
  for (let i = 0; i < digest.length; i++) {
    hex += digest[i].toString(16).padStart(2, "0");
  }
  return groupDigits(hex.toUpperCase(), 4);
}
