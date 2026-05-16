/**
 * SessionKeyDeriver — global key derivation hook for the authenticated layout.
 *
 * Mounted on `#session-key-deriver` in `Layouts.app`, this hook runs on every
 * authenticated page load. It reads the user's encrypted key material from
 * data attributes and derives the full key set:
 *
 *   user_key  → decrypts private_key (via secretbox)
 *   private_key → unseals context keys (conversation keys, post keys, etc.)
 *
 * Derived keys are stored in sessionStorage so every hook on every page can
 * access them without re-reading DOM attributes or re-deriving.
 *
 * Key resolution order (fast path first):
 *   1. sessionStorage (already derived this tab session)
 *   2. Persistent cache (IndexedDB-wrapped, survives browser restart)
 *   3. Temp key from LoginHook (browser-side Argon2id KDF on login)
 *   4. DOM data attributes (server-rendered user_key, transitional fallback)
 *
 * Storage keys:
 *   _mosslet_user_key       — decrypted user_key (base64)
 *   _mosslet_public_key     — X25519 public key (base64, not secret)
 *   _mosslet_private_key    — decrypted X25519 private key (base64)
 *   _mosslet_pq_private_key — decrypted PQ private key (base64), if available
 *   _mosslet_pq_public_key  — PQ public key (base64, not secret), if available
 */

import {
  decryptPrivateKey,
  decryptSecretboxToString,
} from "../crypto/nacl";
import { cacheKeys, getCachedKeys, clearKeyCache } from "../crypto/key_cache";
import { TEMP_USER_KEY } from "./login-hook";

// sessionStorage key names (namespaced to avoid collisions)
export const SK = {
  USER_KEY: "_mosslet_user_key",
  PUBLIC_KEY: "_mosslet_public_key",
  PRIVATE_KEY: "_mosslet_private_key",
  PQ_PUBLIC_KEY: "_mosslet_pq_public_key",
  PQ_PRIVATE_KEY: "_mosslet_pq_private_key",
};

/**
 * Validate that a trial decryption succeeds (keys aren't stale).
 * @param {string} encryptedPrivateKey - base64 encrypted private key from server
 * @param {string} userKey - base64 user_key to test
 * @returns {Promise<string|null>} decrypted private key or null
 */
async function tryDecrypt(encryptedPrivateKey, userKey) {
  try {
    return await decryptPrivateKey(encryptedPrivateKey, userKey);
  } catch {
    return null;
  }
}

const SessionKeyDeriver = {
  async mounted() {
    const el = this.el;

    // Read server-rendered data attributes
    const userKey = el.dataset.userKey;
    const publicKey = el.dataset.publicKey;
    const encryptedPrivateKey = el.dataset.encryptedPrivateKey;
    const pqPublicKey = el.dataset.pqPublicKey || null;
    const encryptedPqPrivateKey = el.dataset.encryptedPqPrivateKey || null;

    // Public keys are never secret — always store them
    if (publicKey) sessionStorage.setItem(SK.PUBLIC_KEY, publicKey);
    if (pqPublicKey) sessionStorage.setItem(SK.PQ_PUBLIC_KEY, pqPublicKey);

    // Guard: need at minimum the encrypted private key to derive anything
    if (!encryptedPrivateKey) return;

    // --- Fast path 1: sessionStorage (already derived this tab) ---
    const existingUserKey = sessionStorage.getItem(SK.USER_KEY);
    if (existingUserKey) {
      const pk = await tryDecrypt(encryptedPrivateKey, existingUserKey);
      if (pk) {
        window.dispatchEvent(new CustomEvent("mosslet:keys-ready"));
        return; // Keys are valid, nothing to do
      }
      // Stale keys (password changed?) — clear and re-derive
      this._clearSessionKeys();
    }

    // --- Fast path 2: persistent cache (browser restart survival) ---
    const cached = await getCachedKeys();
    if (cached?.userKey) {
      const pk = await tryDecrypt(encryptedPrivateKey, cached.userKey);
      if (pk) {
        this._storeKeys({
          userKey: cached.userKey,
          privateKey: pk,
          pqPrivateKey: cached.pqPrivateKey,
        });
        return;
      }
      // Cache stale — fall through to DOM derivation
    }

    // --- Source 3: temp key from LoginHook (browser-derived on login) ---
    const tempUserKey = sessionStorage.getItem(TEMP_USER_KEY);
    if (tempUserKey) {
      sessionStorage.removeItem(TEMP_USER_KEY);
      const pk = await tryDecrypt(encryptedPrivateKey, tempUserKey);
      if (pk) {
        const resolvedKey = tempUserKey;
        let pqPrivateKey = null;
        if (encryptedPqPrivateKey) {
          try {
            pqPrivateKey = await decryptSecretboxToString(encryptedPqPrivateKey, resolvedKey);
          } catch {
            // Non-fatal — PQ key may not be available yet
          }
        }
        this._storeKeys({ userKey: resolvedKey, privateKey: pk, pqPrivateKey });
        await cacheKeys({ userKey: resolvedKey, privateKey: pk, pqPrivateKey });
        return;
      }
      // Temp key didn't work (wrong password submitted to fake salt) — fall through
    }

    // --- Source 4: server-provided user_key from DOM data attribute (transitional) ---
    // The server still derives and passes the user_key during the transition period.
    // Once all clients support LoginHook, this fallback can be removed.
    if (!userKey) {
      // No user_key available — user needs to re-authenticate.
      // Don't redirect here; let individual features handle missing keys
      // gracefully (e.g. showing placeholder text for encrypted content).
      return;
    }

    // Decrypt private key with user_key
    const privateKey = await tryDecrypt(encryptedPrivateKey, userKey);
    if (!privateKey) {
      console.error("SessionKeyDeriver: failed to decrypt private key");
      return;
    }

    // Decrypt PQ private key if available
    let pqPrivateKey = null;
    if (encryptedPqPrivateKey) {
      try {
        pqPrivateKey = await decryptSecretboxToString(encryptedPqPrivateKey, userKey);
      } catch (e) {
        console.warn("SessionKeyDeriver: PQ private key decryption failed:", e);
      }
    }

    // Store derived keys
    this._storeKeys({ userKey, privateKey, pqPrivateKey });

    // Persist to encrypted cache for browser restart survival
    await cacheKeys({ userKey, privateKey, pqPrivateKey });
  },

  /**
   * Store all derived keys in sessionStorage.
   */
  _storeKeys({ userKey, privateKey, pqPrivateKey }) {
    sessionStorage.setItem(SK.USER_KEY, userKey);
    sessionStorage.setItem(SK.PRIVATE_KEY, privateKey);
    if (pqPrivateKey) {
      sessionStorage.setItem(SK.PQ_PRIVATE_KEY, pqPrivateKey);
    }
    window.dispatchEvent(new CustomEvent("mosslet:keys-ready"));
  },

  /**
   * Clear all session keys (used when keys are stale).
   */
  _clearSessionKeys() {
    Object.values(SK).forEach((key) => sessionStorage.removeItem(key));
  },

  /**
   * Clean up on element removal.
   *
   * We intentionally do NOT clear sessionStorage or the persistent key cache
   * here. On LiveView navigate, the old LV is destroyed and a new one mounts
   * — but the DecryptGroupMessage (and similar) hooks fire in between. If we
   * wiped keys here, those hooks would find empty sessionStorage and fail.
   *
   * Keys are cleared on explicit logout (via the logout controller/hook).
   */
  destroyed() {
    // no-op — keys persist across LiveView navigations
  },
};

export default SessionKeyDeriver;
