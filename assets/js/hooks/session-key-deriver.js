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
 *
 * If no key source is available, individual features handle missing keys
 * gracefully (e.g. showing placeholder text for encrypted content).
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
  encryptSecretboxString,
  generateSigningKeyPair,
} from "../crypto/nacl";
import { buildGenesisEntry } from "../crypto/key_history";
import { cacheKeys, getCachedKeys, clearKeyCache } from "../crypto/key_cache";
import { TEMP_USER_KEY } from "./login-hook";

// sessionStorage key names (namespaced to avoid collisions)
export const SK = {
  USER_KEY: "_mosslet_user_key",
  PUBLIC_KEY: "_mosslet_public_key",
  PRIVATE_KEY: "_mosslet_private_key",
  PQ_PUBLIC_KEY: "_mosslet_pq_public_key",
  PQ_PRIVATE_KEY: "_mosslet_pq_private_key",
  SIGNING_PUBLIC_KEY: "_mosslet_signing_public_key",
  SIGNING_PRIVATE_KEY: "_mosslet_signing_private_key",
};

// Per-session guard so the genesis leaf is pushed at most once per tab session.
// Cross-session re-push is a harmless no-op (server append is idempotent on
// (user_id, seq)), but this avoids the needless round-trip on every navigation.
const KH_GENESIS_FLAG = "_mosslet_kh_genesis_pushed";

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
        void this._ensureSigningKeys(existingUserKey);
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
      // Cache stale — fall through
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

    // No key source available — redirect to unlock page for re-authentication.
    // The unlock page derives the session_key via Argon2id KDF in WASM,
    // stores it in sessionStorage, and redirects back to the app.
    //
    // Loop guard: a tight `/app -> /auth/unlock -> /app` loop can occur if the
    // server session already holds the key (so the unlock page bounces back)
    // but the browser never receives a usable temp/cached key. We suppress a
    // re-redirect only within a short time window, rather than latching the
    // flag for the whole tab session. A permanent latch would silently strand
    // the user on a page where nothing decrypts, with no way to reach unlock.
    const REDIRECT_FLAG = "_mosslet_unlock_redirect";
    const REDIRECT_WINDOW_MS = 5000;

    if (!window.location.pathname.startsWith("/auth/")) {
      const lastRedirectAt = parseInt(sessionStorage.getItem(REDIRECT_FLAG) || "0", 10);
      const withinWindow = Number.isFinite(lastRedirectAt) &&
        Date.now() - lastRedirectAt < REDIRECT_WINDOW_MS;

      if (!withinWindow) {
        sessionStorage.setItem(REDIRECT_FLAG, String(Date.now()));
        window.location.href = "/auth/unlock";
      }
    }
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
    sessionStorage.removeItem("_mosslet_unlock_redirect");
    window.dispatchEvent(new CustomEvent("mosslet:keys-ready"));
    void this._ensureSigningKeys(userKey);
  },

  /**
   * Signed key history (#290 step 4 / #315): ensure the user has a hybrid PQ
   * signing keypair available in-browser, then ensure their genesis leaf (seq 0)
   * is recorded server-side.
   *
   *   - Existing keys (registration or a prior login generated them): decrypt the
   *     signing secret under user_key and cache it in sessionStorage.
   *   - No keys yet (legacy user): generate a Cat-5 signing keypair in-browser,
   *     seal the secret under user_key, and push `store_signing_keys`. This is
   *     the CLIENT-side progressive generation — signing MUST happen in the
   *     browser, so it cannot mirror the server-side PQ keygen (#11).
   *
   * Either way, builds + pushes the genesis leaf once per session. Fully
   * best-effort: any failure (WASM unavailable, missing enc keys) is logged and
   * never blocks login/registration or any other feature.
   */
  async _ensureSigningKeys(userKey) {
    if (!userKey) return;
    const el = this.el;
    const encX25519 = el.dataset.publicKey;
    const encPq = el.dataset.pqPublicKey || null;
    // The genesis leaf pins BOTH encryption public keys; without them we cannot
    // build a byte-reproducible leaf, so defer (a later load with PQ keys will).
    if (!encX25519 || !encPq) return;

    let signingPublicKey = el.dataset.signingPublicKey || null;
    const encryptedSigningPrivateKey = el.dataset.encryptedSigningPrivateKey || null;
    let signingSecret = null;

    try {
      if (signingPublicKey && encryptedSigningPrivateKey) {
        signingSecret = await decryptSecretboxToString(encryptedSigningPrivateKey, userKey);
      } else {
        const kp = await generateSigningKeyPair("cat5");
        signingPublicKey = kp.publicKey;
        signingSecret = kp.secretKey;
        const sealed = await encryptSecretboxString(signingSecret, userKey);
        this.pushEvent("store_signing_keys", {
          signing_public_key: signingPublicKey,
          encrypted_signing_private_key: sealed,
        });
      }
    } catch (e) {
      console.warn("SessionKeyDeriver: signing key setup failed (non-fatal):", e);
      return;
    }

    if (!signingPublicKey || !signingSecret) return;

    sessionStorage.setItem(SK.SIGNING_PUBLIC_KEY, signingPublicKey);
    sessionStorage.setItem(SK.SIGNING_PRIVATE_KEY, signingSecret);

    await this._ensureGenesis({ signingPublicKey, signingSecret, encX25519, encPq });
  },

  async _ensureGenesis({ signingPublicKey, signingSecret, encX25519, encPq }) {
    if (sessionStorage.getItem(KH_GENESIS_FLAG) === signingPublicKey) return;
    try {
      const genesis = await buildGenesisEntry({
        encX25519,
        encPq,
        signingPublicKey,
        signingSecretKey: signingSecret,
      });
      this.pushEvent("append_key_history", {
        seq: 0,
        entry: JSON.stringify(genesis),
        signing_public_key: signingPublicKey,
      });
      sessionStorage.setItem(KH_GENESIS_FLAG, signingPublicKey);
    } catch (e) {
      console.warn("SessionKeyDeriver: genesis build/push failed (non-fatal):", e);
    }
  },

  /**
   * Clear all session keys and persistent cache (used when keys are stale).
   */
  _clearSessionKeys() {
    Object.values(SK).forEach((key) => sessionStorage.removeItem(key));
    clearKeyCache();
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
