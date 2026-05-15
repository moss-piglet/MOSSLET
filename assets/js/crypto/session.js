/**
 * Shared session key helpers for conversation crypto.
 *
 * Centralises the DOM queries for encryption keys that were previously
 * duplicated across conversation-hooks.js and message-reactions.js.
 *
 * All keys are read from data attributes on the #conversation-composer element,
 * which the ConversationLive.Show view renders for authenticated users.
 */

import { decryptPrivateKey, unsealFromUser, decryptSecretboxToString } from "./nacl";

const COMPOSER_SELECTOR = "#conversation-composer";

function getComposerEl() {
  return document.querySelector(COMPOSER_SELECTOR);
}

/**
 * Reads the core session keys from the composer element's data attributes.
 * Returns null if the composer or required keys are missing.
 */
export function getSessionKeys() {
  const el = getComposerEl();
  if (!el) return null;

  const sessionKey = el.dataset.sessionKey;
  const encryptedPrivateKey = el.dataset.encryptedPrivateKey;
  if (!sessionKey || !encryptedPrivateKey) return null;

  return { sessionKey, encryptedPrivateKey };
}

/**
 * Reads the user's X25519 public key from the composer element.
 */
export function getPublicKey() {
  const el = getComposerEl();
  return el?.dataset?.userPublicKey || null;
}

/**
 * Reads the user's hybrid PQ public key from the composer element.
 * Returns null if the user hasn't migrated to PQ keys yet.
 */
export function getPqPublicKey() {
  const el = getComposerEl();
  return el?.dataset?.pqPublicKey || null;
}

/**
 * Reads the user's encrypted PQ private key from the composer element.
 * Returns null if the user hasn't migrated to PQ keys yet.
 */
export function getEncryptedPqPrivateKey() {
  const el = getComposerEl();
  return el?.dataset?.encryptedPqPrivateKey || null;
}

/**
 * Decrypts the conversation key from its sealed form using the current user's keys.
 *
 * Uses unsealFromUser which auto-detects legacy (v1, X25519 box_seal) vs
 * hybrid (v2, ML-KEM-768+X25519) ciphertext format.
 *
 * @param {string} encryptedConvKey - base64-encoded sealed conversation key
 * @returns {Promise<string|null>} base64-encoded conversation key, or null on failure
 */
export async function getConversationKey(encryptedConvKey) {
  const keys = getSessionKeys();
  const userPublicKey = getPublicKey();

  if (!keys || !userPublicKey || !encryptedConvKey) return null;

  try {
    const privateKey = await decryptPrivateKey(keys.encryptedPrivateKey, keys.sessionKey);

    // Decrypt PQ private key if available (for hybrid unseal)
    const encryptedPqSk = getEncryptedPqPrivateKey();
    let pqPrivateKey = null;
    if (encryptedPqSk) {
      pqPrivateKey = await decryptSecretboxToString(encryptedPqSk, keys.sessionKey);
    }

    return await unsealFromUser(encryptedConvKey, userPublicKey, privateKey, pqPrivateKey);
  } catch (e) {
    console.error("Failed to decrypt conversation key:", e);
    return null;
  }
}
