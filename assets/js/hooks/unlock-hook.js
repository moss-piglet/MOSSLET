/**
 * UnlockHook — pre-submit key derivation on the unlock session form.
 *
 * Same pattern as LoginHook but for the session unlock page. When a user's
 * session is restored via remember_me cookie but lacks the encryption key,
 * they're redirected to /auth/unlock to re-enter their password.
 *
 * The key_hash is provided as a data attribute on the form element
 * (it's not secret — it's salt$encrypted_user_key, only decryptable with
 * the correct password via Argon2id KDF).
 *
 * Flow:
 *   1. LiveView phx-submit fires "unlock" event
 *   2. Before LiveView processes, hook derives user_key from key_hash + password
 *   3. Stores user_key in sessionStorage as temp key
 *   4. LiveView sets trigger_submit=true → form POSTs to controller
 *   5. Controller verifies password, puts key in session, redirects
 *   6. SessionKeyDeriver picks up temp key on next authenticated page
 *
 * If WASM fails or derivation errors, the flow continues without browser keys.
 * Server-side unlock still works — browser crypto just won't be available
 * until next full login.
 */

import {
  deriveSessionKey,
  decryptSecretboxToString,
} from "../crypto/nacl";

import { cacheKeys } from "../crypto/key_cache";
import { decryptPrivateKey } from "../crypto/nacl";
import { combineSecrets, evaluatePrf, unwrapUserKey } from "../crypto/prf";

const TEMP_USER_KEY = "_mosslet_user_key_temp";

// Loop guard set by SessionKeyDeriver before redirecting a keyless session
// here. Reaching this page means the redirect succeeded, so we clear it: the
// guard is meant to prevent a redirect *loop*, not to permanently latch the
// user out of future unlock attempts if this round-trip fails or is abandoned.
const REDIRECT_FLAG = "_mosslet_unlock_redirect";

const UnlockHook = {
  mounted() {
    const form = this.el;

    sessionStorage.removeItem(REDIRECT_FLAG);

    form.addEventListener("submit", async (e) => {
      e.preventDefault();

      const passwordInput = form.querySelector('input[name="unlock[password]"]');
      const keyHash = form.dataset.keyHash;

      if (!passwordInput || !keyHash || !keyHash.includes("$")) {
        this.pushEvent("unlock", { unlock: { password: passwordInput?.value || "" } });
        return;
      }

      const password = passwordInput.value;
      if (!password) {
        this.pushEvent("unlock", { unlock: { password: "" } });
        return;
      }

      // Enrolled-account unlock (board #370): the account has NO key_hash
      // password-only door, so unlock via PRF (password AND enrolled device).
      // On success we hand the server the decrypted session-key string via a
      // hidden `unlock[user_key]` field; the controller trusts it only for
      // enrolled accounts. We NEVER fall back to a password-only door here.
      const prf = parsePrf(form.dataset.prf);
      if (prf.enrolled && prf.wraps.length > 0) {
        const userKey = await tryPrfUnlock(prf.wraps, password);
        if (userKey) {
          sessionStorage.setItem(TEMP_USER_KEY, userKey);
          setUserKeyField(form, userKey);
          // Trigger the form action POST; the hidden user_key field rides along
          // and the controller uses it (enrolled → key_hash retired).
          this.pushEvent("unlock", { unlock: { password } });
          return;
        }
        // PRF unavailable on this device — let the LiveView surface the retry;
        // do not attempt the (nonexistent) password door.
        this.pushEvent("unlock", { unlock: { password } });
        return;
      }

      try {
        const dollarIndex = keyHash.indexOf("$");
        const salt = keyHash.substring(0, dollarIndex);
        const encryptedUserKey = keyHash.substring(dollarIndex + 1);

        const sessionKey = await deriveSessionKey(password, salt);
        const userKey = await decryptSecretboxToString(encryptedUserKey, sessionKey);

        // Store for SessionKeyDeriver to pick up after redirect
        sessionStorage.setItem(TEMP_USER_KEY, userKey);

        // Also try to populate the persistent cache immediately so
        // future browser sessions don't require re-entry
        try {
          const encPk = form.dataset.encryptedPrivateKey;
          if (encPk) {
            const privateKey = await decryptPrivateKey(encPk, userKey);
            let pqPrivateKey = null;
            const encPqPk = form.dataset.encryptedPqPrivateKey;
            if (encPqPk) {
              pqPrivateKey = await decryptSecretboxToString(encPqPk, userKey);
            }
            await cacheKeys({ userKey, privateKey, pqPrivateKey });
          }
        } catch {
          // Non-fatal — SessionKeyDeriver will handle caching on next page
        }
      } catch {
        // Derivation failed (wrong password, WASM issue) — fall through
        sessionStorage.removeItem(TEMP_USER_KEY);
      }

      // Let LiveView handle the rest (trigger_submit → POST to controller)
      this.pushEvent("unlock", { unlock: { password } });
    });
  },
};

export default UnlockHook;

function parsePrf(raw) {
  if (!raw) return { enrolled: false, wraps: [] };
  try {
    const parsed = JSON.parse(raw);
    return {
      enrolled: !!parsed.enrolled,
      wraps: Array.isArray(parsed.wraps) ? parsed.wraps : [],
    };
  } catch {
    return { enrolled: false, wraps: [] };
  }
}

/**
 * Attempt to unlock user_key from one of the enrolled :prf wraps by evaluating
 * the device PRF and combining it with the password-derived key. Returns the
 * recovered user_key string, or null if no enrolled device can unlock here.
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

function setUserKeyField(form, userKey) {
  let input = form.querySelector('input[name="unlock[user_key]"]');
  if (!input) {
    input = document.createElement("input");
    input.type = "hidden";
    input.name = "unlock[user_key]";
    form.appendChild(input);
  }
  input.value = userKey;
}
