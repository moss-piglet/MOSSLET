import sodiumWrappers from "../../vendor/libsodium-wrappers-sumo/libsodium-wrappers.js";

let _sodium = null;

async function getSodium() {
  if (_sodium) return _sodium;
  await sodiumWrappers.ready;
  _sodium = sodiumWrappers;
  return _sodium;
}

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

export async function deriveSessionKey(password, saltBase64) {
  const sodium = await getSodium();
  const salt = b64Decode(saltBase64);
  const key = sodium.crypto_pwhash(
    sodium.crypto_secretbox_KEYBYTES,
    password,
    salt,
    sodium.crypto_pwhash_OPSLIMIT_INTERACTIVE,
    sodium.crypto_pwhash_MEMLIMIT_INTERACTIVE,
    sodium.crypto_pwhash_ALG_DEFAULT
  );
  return b64Encode(key);
}

export async function decryptSecretbox(ciphertextBase64, keyBase64) {
  const sodium = await getSodium();
  const combined = b64Decode(ciphertextBase64);
  const key = b64Decode(keyBase64);
  const nonceSize = sodium.crypto_secretbox_NONCEBYTES;
  const nonce = combined.slice(0, nonceSize);
  const ciphertext = combined.slice(nonceSize);
  const plaintext = sodium.crypto_secretbox_open_easy(ciphertext, nonce, key);
  return plaintext;
}

export async function decryptSecretboxToString(ciphertextBase64, keyBase64) {
  const plaintext = await decryptSecretbox(ciphertextBase64, keyBase64);
  const sodium = await getSodium();
  return sodium.to_string(plaintext);
}

export async function encryptSecretbox(plaintextBytes, keyBase64) {
  const sodium = await getSodium();
  const key = b64Decode(keyBase64);
  const nonce = sodium.randombytes_buf(sodium.crypto_secretbox_NONCEBYTES);
  const ciphertext = sodium.crypto_secretbox_easy(plaintextBytes, nonce, key);
  const combined = new Uint8Array(nonce.length + ciphertext.length);
  combined.set(nonce);
  combined.set(ciphertext, nonce.length);
  return b64Encode(combined);
}

export async function encryptSecretboxString(plaintext, keyBase64) {
  const sodium = await getSodium();
  return encryptSecretbox(sodium.from_string(plaintext), keyBase64);
}

export async function decryptPrivateKey(
  encryptedPrivateKeyBase64,
  sessionKeyBase64
) {
  return decryptSecretboxToString(encryptedPrivateKeyBase64, sessionKeyBase64);
}

export async function boxSealOpen(
  ciphertextBase64,
  publicKeyBase64,
  privateKeyBase64
) {
  const sodium = await getSodium();
  const ciphertext = b64Decode(ciphertextBase64);
  const publicKey = b64Decode(publicKeyBase64);
  const privateKey = b64Decode(privateKeyBase64);
  const plaintext = sodium.crypto_box_seal_open(
    ciphertext,
    publicKey,
    privateKey
  );
  return b64Encode(plaintext);
}

export async function boxSeal(plaintextBytes, publicKeyBase64) {
  const sodium = await getSodium();
  const publicKey = b64Decode(publicKeyBase64);
  const ciphertext = sodium.crypto_box_seal(plaintextBytes, publicKey);
  return b64Encode(ciphertext);
}

export async function boxSealString(plaintext, publicKeyBase64) {
  const sodium = await getSodium();
  return boxSeal(sodium.from_string(plaintext), publicKeyBase64);
}

export async function generateKey() {
  const sodium = await getSodium();
  const key = sodium.randombytes_buf(sodium.crypto_secretbox_KEYBYTES);
  return b64Encode(key);
}

export async function decryptDmKey(
  encryptedDmKeyBase64,
  publicKeyBase64,
  privateKeyBase64
) {
  return boxSealOpen(encryptedDmKeyBase64, publicKeyBase64, privateKeyBase64);
}

export async function encryptDmMessage(plaintext, dmKeyBase64) {
  return encryptSecretboxString(plaintext, dmKeyBase64);
}

export async function decryptDmMessage(ciphertextBase64, dmKeyBase64) {
  return decryptSecretboxToString(ciphertextBase64, dmKeyBase64);
}

export async function encryptDmKeyForUser(
  dmKeyBase64,
  recipientPublicKeyBase64
) {
  const sodium = await getSodium();
  const dmKeyBytes = b64Decode(dmKeyBase64);
  return boxSeal(dmKeyBytes, recipientPublicKeyBase64);
}

export async function parseSaltFromKeyHash(keyHash) {
  const parts = keyHash.split("$");
  if (parts.length !== 2) throw new Error("Invalid key_hash format");
  return parts[0];
}

export { getSodium, b64Encode, b64Decode };
