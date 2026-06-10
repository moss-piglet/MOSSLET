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
