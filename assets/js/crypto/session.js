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
} from "./nacl";
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
  if (!encryptedConvKey) return null;

  try {
    // Fast path: use pre-derived keys from sessionStorage
    let privateKey = getPrivateKey();
    let pqPrivateKey = getPqPrivateKey();
    const userPublicKey = getPublicKey();

    if (!userPublicKey) return null;

    // If private key not in sessionStorage, derive it from the user_key
    if (!privateKey) {
      const keys = getSessionKeys();
      if (!keys) return null;
      privateKey = await decryptPrivateKey(keys.encryptedPrivateKey, keys.sessionKey);

      // Also decrypt PQ private key if available
      if (!pqPrivateKey) {
        const encryptedPqSk = getEncryptedPqPrivateKey();
        if (encryptedPqSk) {
          pqPrivateKey = await decryptSecretboxToString(encryptedPqSk, keys.sessionKey);
        }
      }
    }

    return await unsealFromUser(encryptedConvKey, userPublicKey, privateKey, pqPrivateKey);
  } catch (e) {
    console.error("Failed to decrypt conversation key:", e);
    return null;
  }
}
