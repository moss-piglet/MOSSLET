/**
 * LoginHook — pre-submit key derivation on the login form.
 *
 * Intercepts the login form submission to derive the user's encryption keys
 * in the browser via WASM Argon2id KDF *before* the password reaches the
 * server. The derived user_key is stored in sessionStorage as a temp key
 * that SessionKeyDeriver picks up after the redirect.
 *
 * Flow:
 *   1. User submits login form
 *   2. Hook intercepts, calls POST /api/auth/salt with the email
 *   3. Server returns key_hash (salt$encrypted_user_key) — timing-normalized
 *   4. Hook parses salt from key_hash
 *   5. Hook derives session_key = Argon2id(password, salt) via WASM
 *   6. Hook decrypts user_key from the encrypted portion of key_hash
 *   7. Stores user_key in sessionStorage as temp key
 *   8. Submits the original form for server-side password verification
 *   9. After redirect, SessionKeyDeriver picks up the temp key
 *
 * If any step fails (network error, wrong password, WASM not loaded),
 * the form submits normally and the server-side derivation path is used
 * as fallback. This is a progressive enhancement.
 */

import {
  deriveSessionKey,
  decryptSecretboxToString,
} from "../crypto/nacl";
import { combineSecrets, evaluatePrf, unwrapUserKey } from "../crypto/prf";
import { clearKeyCache } from "../crypto/key_cache";

const TEMP_USER_KEY = "_mosslet_user_key_temp";

const LoginHook = {
  mounted() {
    const form = this.el;

    // Forced-disconnect / orphaned-session hardening (Task #246).
    //
    // Reaching the sign-in page means there is NO authenticated session
    // (authenticated users are redirected away by :redirect_if_user_is_authenticated).
    // So any ZK key material still sitting in this origin's storage is orphaned —
    // e.g. after a server-side "sign out everywhere", account suspension, or
    // deletion, whose next request funnels the user here. Wipe it now.
    //
    // This is the deploy-safe alternative to wiping on a raw socket disconnect
    // (which fires on every deploy/network blip and would force needless
    // re-unlocks). It runs BEFORE the pre-submit KDF below writes a fresh temp
    // key, so it never clobbers an in-progress login. It never touches
    // /auth/unlock (which must preserve keys for an existing session).
    window.dispatchEvent(new CustomEvent("mosslet:logout"));

    form.addEventListener("submit", async (e) => {
      e.preventDefault();

      const emailInput = form.querySelector('input[name="user[email]"]');
      const passwordInput = form.querySelector('input[name="user[password]"]');

      if (!emailInput || !passwordInput) {
        form.submit();
        return;
      }

      const email = emailInput.value.trim();
      const password = passwordInput.value;

      if (!email || !password) {
        form.submit();
        return;
      }

      try {
        // Deterministic wipe ordering (Task #250): explicitly await teardown of
        // any persistent key cache for this origin BEFORE we derive and store
        // the fresh temp key. The mount-time `mosslet:logout` dispatch above
        // already kicks off a best-effort wipe, but awaiting here guarantees the
        // old IndexedDB-backed cache is gone before the new login's keys land,
        // so a slow `deleteDatabase` can never settle after — and clobber —
        // the next session's cached keys. `clearKeyCache()` never rejects and
        // is non-hanging (safety timeout), so this stays progressive-enhancement.
        await clearKeyCache();

        // Fetch the key_hash from the server (timing-normalized)
        const resp = await fetch("/api/auth/salt", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-csrf-token": document.querySelector('meta[name="csrf-token"]')?.content || "",
          },
          body: JSON.stringify({ email }),
        });

        if (!resp.ok) {
          // Server error — fall through to normal submit
          form.submit();
          return;
        }

        const data = await resp.json();
        const keyHash = data.key_hash;
        const prf = data.prf || { enrolled: false, wraps: [] };

        // Enrolled-account unlock branch (password AND enrolled device).
        // The account has NO password-only door (key_hash is retired on enroll,
        // board #370), so we NEVER fall back to the password path here. We only
        // unlock via PRF; if that isn't possible on this device the user is still
        // signed in (server verifies the password) but the session stays locked
        // and /auth/unlock offers PRF or recovery.
        if (prf.enrolled && Array.isArray(prf.wraps) && prf.wraps.length > 0) {
          const userKey = await tryPrfUnlock(prf.wraps, password);
          if (userKey) {
            // The decrypted user_key IS the server session-key string; hand it
            // to the server so it can fill the session cookie (no key_hash to
            // derive from). I6: it only lands in the encrypted session, never a
            // brute-forceable at-rest blob.
            sessionStorage.setItem(TEMP_USER_KEY, userKey);
            setUserKeyField(form, userKey);
          }
          form.submit();
          return;
        }

        if (!keyHash || !keyHash.includes("$")) {
          form.submit();
          return;
        }

        // Parse salt and encrypted user_key from key_hash
        const dollarIndex = keyHash.indexOf("$");
        const salt = keyHash.substring(0, dollarIndex);
        const encryptedUserKey = keyHash.substring(dollarIndex + 1);

        // Derive session_key from password + salt via WASM Argon2id
        const sessionKey = await deriveSessionKey(password, salt);

        // Decrypt the user_key with the derived session_key
        const userKey = await decryptSecretboxToString(encryptedUserKey, sessionKey);

        // Store the derived user_key as a temp key for SessionKeyDeriver
        sessionStorage.setItem(TEMP_USER_KEY, userKey);
      } catch {
        // Any failure (wrong password produces decryption error for fakes,
        // WASM not loaded, network error) — silently fall through.
        // The server-side derivation path handles this.
        sessionStorage.removeItem(TEMP_USER_KEY);
      }

      // Submit the form normally for server-side password verification
      form.submit();
    });
  },
};

export default LoginHook;
export { TEMP_USER_KEY };

/**
 * Attach the browser-derived user_key to the login form so the server can fill
 * the encrypted session cookie for PRF-enrolled accounts (which have no
 * key_hash to derive from). Uses a hidden `user[user_key]` input; only ever
 * called on the enrolled PRF-unlock path, so non-enrolled submissions are
 * byte-for-byte unchanged.
 *
 * @param {HTMLFormElement} form
 * @param {string} userKey
 */
function setUserKeyField(form, userKey) {
  let input = form.querySelector('input[name="user[user_key]"]');
  if (!input) {
    input = document.createElement("input");
    input.type = "hidden";
    input.name = "user[user_key]";
    form.appendChild(input);
  }
  input.value = userKey;
}

/**
 * Attempt to unlock user_key from one of the enrolled :prf wraps by evaluating
 * the device PRF and combining it with the password-derived key. Returns the
 * recovered user_key string, or null if no enrolled device can unlock here
 * (caller then falls through to the password path).
 *
 * @param {Array<{credential_id: string, prf_salt: string, wrap_salt: string, wrapped_user_key: string}>} wraps
 * @param {string} password
 * @returns {Promise<string|null>}
 */
async function tryPrfUnlock(wraps, password) {
  for (const wrap of wraps) {
    try {
      const prfOutput = await evaluatePrf({
        credentialIdB64: wrap.credential_id,
        prfSaltB64: wrap.prf_salt,
      });
      if (!prfOutput) continue;

      const passwordKey = await deriveSessionKey(password, wrap.wrap_salt);
      const wrappingKey = await combineSecrets(passwordKey, prfOutput, wrap.wrap_salt);
      const userKey = await unwrapUserKey(wrap.wrapped_user_key, wrappingKey);
      if (userKey) return userKey;
    } catch {
      // Wrong device / wrong password / cancelled — try the next wrap.
    }
  }
  return null;
}
