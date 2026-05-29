/**
 * Shared session key helpers for crypto operations.
 *
 * Keys are read from sessionStorage (populated by SessionKeyDeriver on every
 * authenticated page). Encrypted key blobs (public data, not secrets) may also
 * be read from DOM data attributes on #session-key-deriver or #conversation-composer.
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
import { clearKeyCache } from "./key_cache";

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
 * Uses sessionStorage (populated by SessionKeyDeriver on every authenticated page).
 * Falls back to #session-key-deriver DOM element for the encrypted private key blob
 * when it is not yet in sessionStorage.
 *
 * @returns {{ sessionKey: string, encryptedPrivateKey: string } | null}
 */
export function getSessionKeys() {
  const userKey = sessionStorage.getItem(SK.USER_KEY);
  if (!userKey) return null;

  // The encrypted private key is always read from DOM (it's the encrypted blob,
  // not a secret — the session-key-deriver element or conversation composer has it).
  const deriverEl = document.querySelector("#session-key-deriver");
  const composerEl = getComposerEl();
  const encryptedPrivateKey =
    deriverEl?.dataset?.encryptedPrivateKey ||
    composerEl?.dataset?.encryptedPrivateKey;

  if (!encryptedPrivateKey) return null;

  return { sessionKey: userKey, encryptedPrivateKey };
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

    try {
      return await unsealFromUser(sealedKey, userPublicKey, privateKey, pqPrivateKey);
    } catch {
      // If the PQ key is corrupt/wrong size, retry without it — the WASM
      // unseal auto-detects v1 (legacy) ciphertext and can succeed without PQ.
      // This handles users whose PQ key migration was incomplete.
      if (pqPrivateKey) {
        return await unsealFromUser(sealedKey, userPublicKey, privateKey, null);
      }
      throw new Error("unseal failed");
    }
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

// ---------------------------------------------------------------------------
// User key cache — allows any hook that needs the unsealed user_key to share
// it across the page lifetime. Cleared on logout.
// ---------------------------------------------------------------------------

let _cachedUserKey = null;

/**
 * Unseals the user_key from its sealed form and unwraps any double-base64.
 *
 * Server-sealed user_keys: the NIF seals the 44-char base64 key string as-is.
 * unsealFromUser returns those 44 ASCII bytes re-encoded as base64 (~60 chars).
 * We detect this by length > 44 and atob() once to recover the original key.
 *
 * Browser-sealed user_keys: the WASM decodes the base64 input before sealing.
 * unsealFromUser returns the 32 raw bytes as base64 (exactly 44 chars).
 * This is already the correct key format — no unwrapping needed.
 *
 * @param {string} sealedUserKey - base64-encoded sealed user_key
 * @returns {Promise<string|null>} unwrapped user_key, or null on failure
 */
export async function getUserKey(sealedUserKey) {
  if (_cachedUserKey) return _cachedUserKey;

  const raw = await unsealContextKey(sealedUserKey);
  if (!raw) return null;

  _cachedUserKey = unwrapKey(raw);
  return _cachedUserKey;
}

/**
 * Returns the sealed user_key (user attributes key) from the DOM.
 * Available on #decrypt-user-fields (app layout) or journal entry decrypt elements.
 * @returns {string|null}
 */
export function getSealedUserKey() {
  const el = document.querySelector("#decrypt-user-fields");
  return el?.dataset?.sealedUserKey || null;
}

let _cachedConnKey = null;

/**
 * Unseals the conn_key from its sealed form and unwraps any double-base64.
 * The conn_key is sealed to the user's keypair, available on #session-key-deriver.
 *
 * @param {string} [sealedConnKey] - optional sealed conn_key; reads from DOM if omitted
 * @returns {Promise<string|null>} unwrapped conn_key, or null on failure
 */
export async function getConnKey(sealedConnKey) {
  if (_cachedConnKey) return _cachedConnKey;

  const sealed = sealedConnKey || getSealedConnKey();
  if (!sealed) return null;

  const raw = await unsealContextKey(sealed);
  if (!raw) return null;

  _cachedConnKey = unwrapKey(raw);
  return _cachedConnKey;
}

// Clear all in-memory key caches, sessionStorage keys, and persistent cache on logout
window.addEventListener("mosslet:logout", () => {
  _postKeyCache.clear();
  _cachedUserKey = null;
  _cachedConnKey = null;
  Object.values(SK).forEach((key) => sessionStorage.removeItem(key));
  sessionStorage.removeItem("_mosslet_unlock_redirect");
  sessionStorage.removeItem("_mosslet_user_key_temp");
  clearKeyCache();
});
