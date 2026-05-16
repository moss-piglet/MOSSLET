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
  parseSaltFromKeyHash as _parseSaltFromKeyHash,
  sealForUserWithLevel as _sealForUserWithLevel,
} from "../../vendor/metamorphic-crypto/metamorphic_crypto.js";

// --- WASM initialization ---

let _ready = null;

async function ensureReady() {
  if (_ready) return _ready;
  _ready = wasmInit("/wasm/metamorphic_crypto_bg.wasm");
  await _ready;
  return _ready;
}

// --- Base64 helpers ---

function b64Encode(uint8Array) {
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

// --- Hybrid PQ KEM (ML-KEM-768 + X25519, default Cat-3) ---

export async function sealForUser(plaintextBytes, publicKeyBase64, pqPublicKeyBase64) {
  await ensureReady();
  const ptB64 = b64Encode(plaintextBytes);
  return _sealForUser(ptB64, publicKeyBase64, pqPublicKeyBase64 || null);
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

export async function generateHybridKeyPair() {
  await ensureReady();
  const kp = _generateHybridKeyPair();
  return { publicKey: kp.publicKey, secretKey: kp.secretKey };
}

export async function isHybridCiphertext(ciphertextBase64) {
  await ensureReady();
  return _isHybridCiphertext(ciphertextBase64);
}

// --- Hybrid PQ KEM Cat-5 (ML-KEM-1024 + X25519, opt-in) ---

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
 *
 * @returns {Promise<{publicKey: string, secretKey: string}>} base64 keypair
 */
export async function generateHybridKeyPair1024() {
  await ensureReady();
  const kp = _generateHybridKeyPair1024();
  return { publicKey: kp.publicKey, secretKey: kp.secretKey };
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

// --- Utility ---

export async function parseSaltFromKeyHash(keyHash) {
  await ensureReady();
  return _parseSaltFromKeyHash(keyHash);
}

export { b64Encode, b64Decode };
