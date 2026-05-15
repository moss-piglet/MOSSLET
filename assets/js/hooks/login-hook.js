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

const TEMP_USER_KEY = "_mosslet_user_key_temp";

const LoginHook = {
  mounted() {
    const form = this.el;

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

        const { key_hash: keyHash } = await resp.json();

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
