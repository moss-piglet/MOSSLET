/**
 * Mosslet Crypto — WASM-backed implementation.
 *
 * Drop-in replacement for the original nacl.js (libsodium-wrappers-sumo).
 * All functions have the same signatures and return the same base64 strings.
 *
 * The WASM module (metamorphic-crypto, Rust) provides NaCl-compatible
 * primitives plus hybrid PQ key encapsulation (ML-KEM-768/1024 + X25519).
 * The same Rust crate compiles to the server-side NIF (MetamorphicCrypto Hex),
 * guaranteeing wire-format compatibility between browser and server.
 */

import wasmInit, {
  deriveSessionKey as _deriveSessionKey,
  encryptSecretboxString as _encryptSecretboxString,
  decryptSecretboxToString as _decryptSecretboxToString,
  encryptSecretbox as _encryptSecretbox,
  decryptSecretbox as _decryptSecretbox,
  boxSeal as _boxSeal,
  boxSealOpen as _boxSealOpen,
  sealForUser as _sealForUser,
  unsealFromUser as _unsealFromUser,
  generateKey as _generateKey,
  generateKeyPair as _generateKeyPair,
  generateSalt as _generateSalt,
  generateHybridKeyPair as _generateHybridKeyPair,
  generateHybridKeyPair1024 as _generateHybridKeyPair1024,
  isHybridCiphertext as _isHybridCiphertext,
  encryptPrivateKey as _encryptPrivateKey,
  decryptPrivateKey as _decryptPrivateKey,
  encryptPrivateKeyForRecovery as _encryptPrivateKeyForRecovery,
  decryptPrivateKeyWithRecovery as _decryptPrivateKeyWithRecovery,
  generateRecoveryKey as _generateRecoveryKey,
  recoveryKeyToSecret as _recoveryKeyToSecret,
  parseSaltFromKeyHash as _parseSaltFromKeyHash,
  sealForUserWithLevel as _sealForUserWithLevel,
  sha3_512 as _sha3_512,
  sha3_512WithContext as _sha3_512WithContext,
  sha3_256 as _sha3_256,
  sha256 as _sha256,
  sha512 as _sha512,
  generateSigningKeyPair as _generateSigningKeyPair,
  deriveSigningPublicKey as _deriveSigningPublicKey,
  sign as _sign,
  verify as _verify,
} from "../../vendor/metamorphic-crypto/metamorphic_crypto.js";

// --- WASM initialization ---

let _ready = null;
let _wasmSource = "/wasm/metamorphic_crypto_bg.wasm";

/**
 * Override where the WASM binary is loaded from before first use.
 *
 * In the browser the default Phoenix static path ("/wasm/...") is correct and
 * this never needs to be called. It exists so non-browser environments (e.g. a
 * future SDK harness) can initialize from explicit bytes/URL via the same glue.
 *
 * @param {string|URL|BufferSource|Response|WebAssembly.Module} input
 */
export function setWasmSource(input) {
  if (_ready) throw new Error("setWasmSource must be called before crypto is initialized");
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

// --- Base64 helpers ---

export function b64Encode(uint8Array) {
  let binary = "";
  for (let i = 0; i < uint8Array.length; i++) {
    binary += String.fromCharCode(uint8Array[i]);
  }
  return btoa(binary);
}

function b64Decode(base64String) {
  const binary = atob(base64String);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// --- Symmetric encryption (XSalsa20-Poly1305 secretbox) ---

export async function encryptSecretboxString(plaintext, keyBase64) {
  await ensureReady();
  return _encryptSecretboxString(plaintext, keyBase64);
}

export async function decryptSecretboxToString(ciphertextBase64, keyBase64) {
  await ensureReady();
  return _decryptSecretboxToString(ciphertextBase64, keyBase64);
}

export async function encryptSecretbox(plaintextBytes, keyBase64) {
  await ensureReady();
  const ptB64 = b64Encode(plaintextBytes);
  return _encryptSecretbox(ptB64, keyBase64);
}

export async function decryptSecretbox(ciphertextBase64, keyBase64) {
  await ensureReady();
  const ptB64 = _decryptSecretbox(ciphertextBase64, keyBase64);
  return b64Decode(ptB64);
}

// --- Key derivation (Argon2id) ---

export async function deriveSessionKey(password, saltBase64) {
  await ensureReady();
  return _deriveSessionKey(password, saltBase64);
}

// --- Private key management ---

export async function decryptPrivateKey(encryptedPrivateKeyBase64, sessionKeyBase64) {
  await ensureReady();
  return _decryptPrivateKey(encryptedPrivateKeyBase64, sessionKeyBase64);
}

// --- Asymmetric encryption (X25519 box_seal, legacy) ---

export async function boxSealOpen(ciphertextBase64, publicKeyBase64, privateKeyBase64) {
  await ensureReady();
  return _boxSealOpen(ciphertextBase64, publicKeyBase64, privateKeyBase64);
}

export async function boxSeal(plaintextBytes, publicKeyBase64) {
  await ensureReady();
  const ptB64 = b64Encode(plaintextBytes);
  return _boxSeal(ptB64, publicKeyBase64);
}

// --- Key generation ---

export async function generateKey() {
  await ensureReady();
  return _generateKey();
}

// --- Hybrid PQ KEM (ML-KEM + X25519) ---

/**
 * Detect the PQ security level from a base64-encoded public key.
 * Cat-3 (ML-KEM-768) keys are 1216 bytes raw; Cat-5 (ML-KEM-1024) are 1600 bytes.
 *
 * @param {string} pqPublicKeyBase64 - PQ public key (base64)
 * @returns {"cat3"|"cat5"} detected security level
 */
export function detectPqLevel(pqPublicKeyBase64) {
  if (!pqPublicKeyBase64) return "cat5";
  const raw = b64Decode(pqPublicKeyBase64);
  return raw.length === 1216 ? "cat3" : "cat5";
}

/**
 * Seal plaintext to a user's keys with auto-detected PQ level.
 *
 * When a PQ public key is provided, the security level is detected
 * from the key size (1216 bytes → Cat-3, 1600 bytes → Cat-5).
 * This ensures correct KEM selection regardless of the recipient's key version.
 *
 * @param {Uint8Array} plaintextBytes - raw plaintext bytes
 * @param {string} publicKeyBase64 - X25519 public key (base64)
 * @param {string|null} pqPublicKeyBase64 - PQ public key (base64), or null for legacy
 * @returns {Promise<string>} base64 ciphertext
 */
export async function sealForUser(plaintextBytes, publicKeyBase64, pqPublicKeyBase64) {
  await ensureReady();
  const ptB64 = b64Encode(plaintextBytes);
  if (pqPublicKeyBase64) {
    const level = detectPqLevel(pqPublicKeyBase64);
    return _sealForUserWithLevel(ptB64, publicKeyBase64, pqPublicKeyBase64, level);
  }
  return _sealForUser(ptB64, publicKeyBase64, null);
}

export async function unsealFromUser(
  ciphertextBase64,
  publicKeyBase64,
  privateKeyBase64,
  pqSecretKeyBase64,
) {
  await ensureReady();
  return _unsealFromUser(
    ciphertextBase64,
    publicKeyBase64,
    privateKeyBase64,
    pqSecretKeyBase64 || null,
  );
}

/**
 * Generate a ML-KEM-1024 + X25519 hybrid keypair (Cat-5, default).
 *
 * @returns {Promise<{publicKey: string, secretKey: string}>} base64 keypair
 */
export async function generateHybridKeyPair() {
  await ensureReady();
  const kp = _generateHybridKeyPair1024();
  return { publicKey: kp.publicKey, secretKey: kp.secretKey };
}

export async function isHybridCiphertext(ciphertextBase64) {
  await ensureReady();
  return _isHybridCiphertext(ciphertextBase64);
}

// --- Legacy Cat-3 keypair generation (for compatibility) ---

/**
 * Generate a ML-KEM-768 + X25519 hybrid keypair (Cat-3, legacy).
 * Use generateHybridKeyPair() for the default Cat-5 keypair.
 *
 * @returns {Promise<{publicKey: string, secretKey: string}>} base64 keypair
 */
export async function generateHybridKeyPair768() {
  await ensureReady();
  const kp = _generateHybridKeyPair();
  return { publicKey: kp.publicKey, secretKey: kp.secretKey };
}

// --- Explicit level seal (when caller wants to override auto-detection) ---

/**
 * Seal plaintext to a user's keys at a specific security level.
 *
 * @param {Uint8Array} plaintextBytes - raw plaintext bytes
 * @param {string} publicKeyBase64 - X25519 public key (base64)
 * @param {string|null} pqPublicKeyBase64 - PQ public key (base64), or null for legacy
 * @param {"cat3"|"cat5"} level - security level ("cat3" = ML-KEM-768, "cat5" = ML-KEM-1024)
 * @returns {Promise<string>} base64 ciphertext
 */
export async function sealForUserWithLevel(
  plaintextBytes,
  publicKeyBase64,
  pqPublicKeyBase64,
  level,
) {
  await ensureReady();
  const ptB64 = b64Encode(plaintextBytes);
  return _sealForUserWithLevel(
    ptB64,
    publicKeyBase64,
    pqPublicKeyBase64 || null,
    level,
  );
}

/**
 * Generate a ML-KEM-1024 + X25519 hybrid keypair (Cat-5, NIST Category 5).
 * Alias for generateHybridKeyPair() — both generate Cat-5 keypairs.
 *
 * @returns {Promise<{publicKey: string, secretKey: string}>} base64 keypair
 */
export async function generateHybridKeyPair1024() {
  return generateHybridKeyPair();
}

// --- Conversation helpers (preserved API for existing hooks) ---

export async function decryptDmKey(encryptedDmKeyBase64, publicKeyBase64, privateKeyBase64) {
  return boxSealOpen(encryptedDmKeyBase64, publicKeyBase64, privateKeyBase64);
}

export async function encryptDmMessage(plaintext, dmKeyBase64) {
  return encryptSecretboxString(plaintext, dmKeyBase64);
}

export async function decryptDmMessage(ciphertextBase64, dmKeyBase64) {
  return decryptSecretboxToString(ciphertextBase64, dmKeyBase64);
}

export async function encryptDmKeyForUser(dmKeyBase64, recipientPublicKeyBase64) {
  await ensureReady();
  return _boxSeal(dmKeyBase64, recipientPublicKeyBase64);
}

// --- Key pair generation ---

export async function generateKeyPair() {
  await ensureReady();
  const kp = _generateKeyPair();
  return { publicKey: kp.publicKey, privateKey: kp.privateKey };
}

export async function generateSalt() {
  await ensureReady();
  return _generateSalt();
}

export async function encryptPrivateKey(privateKeyBase64, sessionKeyBase64) {
  await ensureReady();
  return _encryptPrivateKey(privateKeyBase64, sessionKeyBase64);
}

// --- Recovery key ---

export async function generateRecoveryKey() {
  await ensureReady();
  return _generateRecoveryKey();
}

export async function encryptPrivateKeyForRecovery(privateKeyBase64, recoverySecretBase64) {
  await ensureReady();
  return _encryptPrivateKeyForRecovery(privateKeyBase64, recoverySecretBase64);
}

export async function decryptPrivateKeyWithRecovery(ciphertextBase64, recoverySecretBase64) {
  await ensureReady();
  return _decryptPrivateKeyWithRecovery(ciphertextBase64, recoverySecretBase64);
}

export async function recoveryKeyToSecret(recoveryKey) {
  await ensureReady();
  return _recoveryKeyToSecret(recoveryKey);
}

// --- Utility ---

export async function parseSaltFromKeyHash(keyHash) {
  await ensureReady();
  return _parseSaltFromKeyHash(keyHash);
}

// --- Hashing (metamorphic-crypto SHA3 / SHA2) ---
//
// These are thin wrappers over the same audited Rust crate that powers the
// server-side NIF (MetamorphicCrypto.Hash), guaranteeing byte-for-byte parity
// between browser and server. All take and return base64 strings; SHA3-512 is
// the project default (Cat-5 posture, consistent with the Keccak seal combiner).

/**
 * SHA3-512 digest of base64-encoded data. Returns the 64-byte digest as base64.
 * @param {string} dataBase64
 * @returns {Promise<string>} base64 digest
 */
export async function sha3_512(dataBase64) {
  await ensureReady();
  return _sha3_512(dataBase64);
}

/**
 * Domain-separated SHA3-512 — the primitive for key fingerprints / safety
 * numbers / key-transparency entries. Wire format:
 *   SHA3-512( u64_be(byteLength(context)) || utf8(context) || data )
 *
 * @param {string} context - versioned UTF-8 label, e.g. "mosslet/key-fingerprint/v1"
 * @param {string} dataBase64 - base64-encoded payload
 * @returns {Promise<string>} base64 digest (64 bytes)
 */
export async function sha3_512WithContext(context, dataBase64) {
  await ensureReady();
  return _sha3_512WithContext(context, dataBase64);
}

/**
 * SHA3-256 digest of base64-encoded data. Returns the 32-byte digest as base64.
 * @param {string} dataBase64
 * @returns {Promise<string>} base64 digest
 */
export async function sha3_256(dataBase64) {
  await ensureReady();
  return _sha3_256(dataBase64);
}

/**
 * SHA-256 (SHA-2) digest of base64-encoded data. Returns 32-byte digest as base64.
 * @param {string} dataBase64
 * @returns {Promise<string>} base64 digest
 */
export async function sha256(dataBase64) {
  await ensureReady();
  return _sha256(dataBase64);
}

/**
 * SHA-512 (SHA-2) digest of base64-encoded data. Returns 64-byte digest as base64.
 * @param {string} dataBase64
 * @returns {Promise<string>} base64 digest
 */
export async function sha512(dataBase64) {
  await ensureReady();
  return _sha512(dataBase64);
}

// --- Hybrid PQ signatures (ML-DSA + Ed25519 composite, strict-AND) ---
//
// Thin wrappers over the same audited Rust crate that powers the server-side
// NIF (MetamorphicCrypto.Sign), guaranteeing byte-for-byte parity between
// browser and server. The composite signature requires BOTH the Ed25519 and
// ML-DSA components to verify (strict AND) — a server cannot strip the PQ half.
//
// Mosslet stays Cat-5 hybrid by default; the CNSA-2.0 suite axis exists in the
// WASM (generateSigningKeyPairSuite) but is intentionally NOT surfaced here —
// we do not switch postures in this layer. sign/verify/deriveSigningPublicKey
// auto-detect the suite from the key/signature version tag.
//
// This is the foundation for a signed key history (board #290 step 4): the
// piece that lets a client distinguish legitimate key rotation from a server
// key-substitution attack — something TOFU pinning alone cannot do.

/**
 * Default domain-separation context for Mosslet signatures.
 * Versioned so the meaning of a signature is unambiguous and future-proof.
 */
export const DEFAULT_SIGN_CONTEXT = "metamorphic/sign/v1";

/**
 * Generate a hybrid PQ signing keypair (ML-DSA + Ed25519 composite).
 *
 * @param {"cat2"|"cat3"|"cat5"} [level="cat5"] - ML-DSA level (Mosslet defaults
 *   to Cat-5 / ML-DSA-87 to match its Cat-5 hybrid KEM posture).
 * @returns {Promise<{publicKey: string, secretKey: string}>} base64 keypair
 */
export async function generateSigningKeyPair(level = "cat5") {
  await ensureReady();
  const kp = _generateSigningKeyPair(level);
  return { publicKey: kp.publicKey, secretKey: kp.secretKey };
}

/**
 * Re-derive the base64 public key from a base64 hybrid signing secret key.
 *
 * @param {string} secretKeyBase64 - base64 hybrid signing secret key
 * @returns {Promise<string>} base64 public key
 */
export async function deriveSigningPublicKey(secretKeyBase64) {
  await ensureReady();
  return _deriveSigningPublicKey(secretKeyBase64);
}

/**
 * Sign raw-binary message bytes under a domain-separation context.
 *
 * @param {Uint8Array} messageBytes - raw message bytes
 * @param {string} secretKeyBase64 - base64 hybrid signing secret key
 * @param {string} [context=DEFAULT_SIGN_CONTEXT] - versioned UTF-8 domain separator
 * @returns {Promise<string>} base64 composite signature
 */
export async function sign(messageBytes, secretKeyBase64, context = DEFAULT_SIGN_CONTEXT) {
  await ensureReady();
  const msgB64 = b64Encode(messageBytes);
  return _sign(msgB64, context, secretKeyBase64);
}

/**
 * Verify a composite signature over raw-binary message bytes. Returns true only
 * if BOTH the Ed25519 and ML-DSA components verify (strict AND).
 *
 * @param {Uint8Array} messageBytes - raw message bytes
 * @param {string} signatureBase64 - base64 composite signature
 * @param {string} publicKeyBase64 - base64 hybrid signing public key
 * @param {string} [context=DEFAULT_SIGN_CONTEXT] - versioned UTF-8 domain separator
 * @returns {Promise<boolean>} true if the signature is valid
 */
export async function verify(
  messageBytes,
  signatureBase64,
  publicKeyBase64,
  context = DEFAULT_SIGN_CONTEXT,
) {
  await ensureReady();
  const msgB64 = b64Encode(messageBytes);
  return _verify(msgB64, context, signatureBase64, publicKeyBase64);
}

// --- Utility ---

export { b64Decode };
