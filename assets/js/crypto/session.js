/**
 * Shared session key helpers for crypto operations.
 *
 * Key resolution order:
 *   1. sessionStorage (populated by SessionKeyDeriver on every authenticated page)
 *   2. DOM data attributes on #conversation-composer (legacy, conversation page only)
 *
 * The sessionStorage path is the standard path going forward. The DOM fallback
 * ensures existing conversation hooks continue working during the transition.
 */

import {
  decryptPrivateKey,
  unsealFromUser,
  decryptSecretboxToString,
  decryptSecretbox,
  encryptSecretboxString,
  b64Encode,
} from "./nacl";

export { decryptSecretbox, b64Encode };
import { SK } from "../hooks/session-key-deriver";

const COMPOSER_SELECTOR = "#conversation-composer";

function getComposerEl() {
  return document.querySelector(COMPOSER_SELECTOR);
}

// ---------------------------------------------------------------------------
// Core key accessors — sessionStorage-first, DOM fallback
// ---------------------------------------------------------------------------

/**
 * Returns the user_key (decrypted symmetric key) and encrypted private key.
 *
 * Prefers sessionStorage (populated by SessionKeyDeriver), falls back to
 * the conversation composer DOM for backward compatibility.
 *
 * @returns {{ sessionKey: string, encryptedPrivateKey: string } | null}
 */
export function getSessionKeys() {
  // Fast path: sessionStorage (available on all authenticated pages)
  const userKey = sessionStorage.getItem(SK.USER_KEY);
  if (userKey) {
    // For the encrypted private key, check sessionStorage first (if already decrypted,
    // we don't need it). But callers use this to decrypt the private key, so we need
    // the encrypted form. Read from the deriver element or composer.
    const deriverEl = document.querySelector("#session-key-deriver");
    const composerEl = getComposerEl();
    const encryptedPrivateKey =
      deriverEl?.dataset?.encryptedPrivateKey ||
      composerEl?.dataset?.encryptedPrivateKey;

    if (encryptedPrivateKey) {
      return { sessionKey: userKey, encryptedPrivateKey };
    }
  }

  // Legacy fallback: read from conversation composer DOM
  const el = getComposerEl();
  if (!el) return null;

  const sessionKey = el.dataset.sessionKey;
  const encryptedPrivateKey = el.dataset.encryptedPrivateKey;
  if (!sessionKey || !encryptedPrivateKey) return null;

  return { sessionKey, encryptedPrivateKey };
}

/**
 * Returns the user's X25519 public key.
 * @returns {string | null}
 */
export function getPublicKey() {
  return (
    sessionStorage.getItem(SK.PUBLIC_KEY) ||
    getComposerEl()?.dataset?.userPublicKey ||
    null
  );
}

/**
 * Returns the user's hybrid PQ public key, or null if not migrated.
 * @returns {string | null}
 */
export function getPqPublicKey() {
  return (
    sessionStorage.getItem(SK.PQ_PUBLIC_KEY) ||
    getComposerEl()?.dataset?.pqPublicKey ||
    null
  );
}

/**
 * Returns the user's encrypted PQ private key, or null if not migrated.
 * @returns {string | null}
 */
export function getEncryptedPqPrivateKey() {
  const deriverEl = document.querySelector("#session-key-deriver");
  return (
    deriverEl?.dataset?.encryptedPqPrivateKey ||
    getComposerEl()?.dataset?.encryptedPqPrivateKey ||
    null
  );
}

/**
 * Returns the user's sealed conn_key (connection key) from the DOM.
 * The conn_key is sealed to the user's keypair and can be unsealed
 * via unsealContextKey().
 * @returns {string | null}
 */
export function getSealedConnKey() {
  const deriverEl = document.querySelector("#session-key-deriver");
  return deriverEl?.dataset?.connKey || null;
}

/**
 * Returns the already-decrypted private key from sessionStorage, or null.
 *
 * This is the fast path — if SessionKeyDeriver has run, the private key
 * is already decrypted and cached.
 *
 * @returns {string | null}
 */
export function getPrivateKey() {
  return sessionStorage.getItem(SK.PRIVATE_KEY) || null;
}

/**
 * Returns the already-decrypted PQ private key from sessionStorage, or null.
 * @returns {string | null}
 */
export function getPqPrivateKey() {
  return sessionStorage.getItem(SK.PQ_PRIVATE_KEY) || null;
}

// ---------------------------------------------------------------------------
// Context key helpers
// ---------------------------------------------------------------------------

/**
 * Decrypts a conversation key from its sealed form using the current user's keys.
 *
 * Uses unsealFromUser which auto-detects legacy (v1, X25519 box_seal) vs
 * hybrid (v2, ML-KEM-768+X25519) ciphertext format.
 *
 * @param {string} encryptedConvKey - base64-encoded sealed conversation key
 * @returns {Promise<string|null>} base64-encoded conversation key, or null on failure
 */
export async function getConversationKey(encryptedConvKey) {
  return unsealContextKey(encryptedConvKey);
}

// ---------------------------------------------------------------------------
// General-purpose context key helpers
// ---------------------------------------------------------------------------

/**
 * Unseals any context key (post_key, conversation_key, group_key, etc.)
 * from its sealed form using the current user's keys.
 *
 * Uses unsealFromUser which auto-detects legacy (v1, X25519 box_seal) vs
 * hybrid (v2, ML-KEM-768+X25519) ciphertext format.
 *
 * @param {string} sealedKey - base64-encoded sealed context key
 * @returns {Promise<string|null>} base64-encoded raw key, or null on failure
 */
export async function unsealContextKey(sealedKey) {
  if (!sealedKey) return null;

  try {
    let privateKey = getPrivateKey();
    let pqPrivateKey = getPqPrivateKey();
    const userPublicKey = getPublicKey();

    if (!userPublicKey) return null;

    if (!privateKey) {
      const keys = getSessionKeys();
      if (!keys) return null;
      privateKey = await decryptPrivateKey(keys.encryptedPrivateKey, keys.sessionKey);

      if (!pqPrivateKey) {
        const encryptedPqSk = getEncryptedPqPrivateKey();
        if (encryptedPqSk) {
          pqPrivateKey = await decryptSecretboxToString(encryptedPqSk, keys.sessionKey);
        }
      }
    }

    return await unsealFromUser(sealedKey, userPublicKey, privateKey, pqPrivateKey);
  } catch (e) {
    console.error("Failed to unseal context key:", e);
    return null;
  }
}

/**
 * Decrypts a secretbox-encrypted payload using an already-unsealed raw key.
 *
 * @param {string} ciphertext - base64-encoded secretbox ciphertext
 * @param {string} rawKey - base64-encoded symmetric key
 * @returns {Promise<string|null>} plaintext string, or null on failure
 */
export async function decryptWithKey(ciphertext, rawKey) {
  if (!ciphertext || !rawKey) return null;
  try {
    return await decryptSecretboxToString(ciphertext, rawKey);
  } catch (e) {
    console.error("Failed to decrypt payload:", e);
    return null;
  }
}

/**
 * Encrypts a plaintext string using a symmetric key (secretbox).
 *
 * @param {string} plaintext - the string to encrypt
 * @param {string} rawKey - base64-encoded symmetric key
 * @returns {Promise<string|null>} base64-encoded ciphertext, or null on failure
 */
export async function encryptWithKey(plaintext, rawKey) {
  if (plaintext == null || !rawKey) return null;
  try {
    return await encryptSecretboxString(plaintext, rawKey);
  } catch (e) {
    console.error("Failed to encrypt payload:", e);
    return null;
  }
}

/**
 * Unwraps a context key that may be double-base64-encoded.
 *
 * Server-registered users had their context keys sealed as base64 strings,
 * so unsealFromUser returns those ASCII bytes re-encoded as base64 (~60 chars,
 * double-encoded). Browser-registered users seal raw 32 bytes, so unseal
 * returns the correct 44-char base64 key directly.
 *
 * Detect double-encoding by length: 44 chars = correct base64 of 32 bytes;
 * longer = double-encoded, needs one atob() unwrap.
 *
 * Works for any context key type: post_key, group_key, conn_key, user_key, etc.
 *
 * @param {string} unsealedB64 - base64-encoded key, possibly double-encoded
 * @returns {string} base64-encoded 32-byte key
 */
export function unwrapKey(unsealedB64) {
  if (unsealedB64.length > 44) {
    try {
      return atob(unsealedB64);
    } catch {
      return unsealedB64;
    }
  }
  return unsealedB64;
}

export { unwrapKey as unwrapConnKey };

/**
 * Decrypt a JSON-encoded list of individually-encrypted items.
 * Returns an array of plaintext strings.
 *
 * @param {string} jsonStr - JSON array of base64 secretbox ciphertexts
 * @param {string} key - base64-encoded symmetric key
 * @returns {Promise<string[]|null>}
 */
export async function decryptList(jsonStr, key) {
  if (!jsonStr) return null;
  try {
    const items = JSON.parse(jsonStr);
    if (!Array.isArray(items) || items.length === 0) return [];
    const results = [];
    for (const item of items) {
      if (typeof item === "string" && item !== "") {
        const plain = await decryptWithKey(item, key);
        if (plain != null) results.push(plain);
      }
    }
    return results;
  } catch {
    return null;
  }
}

/**
 * Escapes HTML special characters in a string to prevent XSS when
 * inserting decrypted user content into the DOM via innerHTML.
 *
 * @param {string} str
 * @returns {string}
 */
export function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// ---------------------------------------------------------------------------
// Post key cache — allows DecryptPost to share the unsealed post_key with
// other hooks (e.g. TrixContentPostHook for image decryption).
// Keys are stored per post ID and cleared on page navigation.
// ---------------------------------------------------------------------------

const _postKeyCache = new Map();
const POST_KEY_CACHE_MAX = 200;

/**
 * Stores a decrypted post_key for a given post ID.
 * Evicts the oldest entry when the cache exceeds POST_KEY_CACHE_MAX.
 * @param {string} postId
 * @param {string} postKey - base64-encoded raw post_key
 */
export function cachePostKey(postId, postKey) {
  if (_postKeyCache.has(postId)) {
    _postKeyCache.delete(postId);
  } else if (_postKeyCache.size >= POST_KEY_CACHE_MAX) {
    const oldest = _postKeyCache.keys().next().value;
    _postKeyCache.delete(oldest);
  }
  _postKeyCache.set(postId, postKey);
}

/**
 * Retrieves a cached post_key, or null if not yet decrypted.
 * @param {string} postId
 * @returns {string|null}
 */
export function getCachedPostKey(postId) {
  return _postKeyCache.get(postId) || null;
}

// Clear all in-memory key caches on logout
window.addEventListener("mosslet:logout", () => {
  _postKeyCache.clear();
});
