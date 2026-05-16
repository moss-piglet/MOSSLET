/**
 * AccountRecoveryHook — browser-side password reset via recovery key.
 *
 * Mounted on the account recovery page (unauthenticated). Flow:
 *
 *   1. User enters email + recovery key
 *   2. Hook converts human-readable key to secret via recoveryKeyToSecret()
 *   3. Hook POSTs to /api/auth/recovery-data { email, recovery_secret }
 *   4. Server verifies recovery_secret against stored Argon2 hash
 *   5. Server returns { encrypted_recovery_private_key, public_key,
 *      encrypted_user_key, key_hash }
 *   6. Hook decrypts private_key = decryptPrivateKeyWithRecovery(blob, secret)
 *   7. User enters new password
 *   8. Hook derives new session_key = Argon2id(password, new_salt)
 *   9. Hook re-encrypts: encrypted_user_key = secretbox(user_key, new_session_key)
 *      where user_key = decrypt_key_hash(old_key_hash) — wait, we don't have
 *      the old password. Instead, we rebuild key_hash from the user_key:
 *      - Parse user_key from old key_hash? No, we can't — need old password.
 *      - The user_key is unsealed from encrypted_user_key using the private key.
 *      Actually: we have private_key now. We unseal user_key from encrypted_user_key.
 *      Then we build new_key_hash = new_salt + "$" + secretbox(user_key, new_session_key).
 *      And new_encrypted_private_key = secretbox(private_key, user_key).
 *  10. Hook submits new key material to the server.
 *
 * This ensures the server never sees the raw private key or user_key.
 */

import {
  recoveryKeyToSecret,
  decryptPrivateKeyWithRecovery,
  deriveSessionKey,
  encryptSecretboxString,
  encryptPrivateKey,
  generateSalt,
  unsealFromUser,
} from "../crypto/nacl";
import { TEMP_USER_KEY } from "./login-hook";

const AccountRecoveryHook = {
  mounted() {
    const form = this.el;

    form.addEventListener("submit", async (e) => {
      e.preventDefault();

      const emailInput = form.querySelector('input[name="recovery[email]"]');
      const recoveryKeyInput = form.querySelector('input[name="recovery[recovery_key]"]');
      const passwordInput = form.querySelector('input[name="recovery[password]"]');
      const passwordConfirmInput = form.querySelector('input[name="recovery[password_confirmation]"]');

      if (!emailInput || !recoveryKeyInput || !passwordInput) {
        return;
      }

      const email = emailInput.value.trim();
      const recoveryKeyStr = recoveryKeyInput.value.trim();
      const password = passwordInput.value;
      const passwordConfirmation = passwordConfirmInput?.value || "";

      if (!email || !recoveryKeyStr || !password) {
        this.pushEvent("recovery_error", { error: "All fields are required." });
        return;
      }

      if (password !== passwordConfirmation) {
        this.pushEvent("recovery_error", { error: "Passwords do not match." });
        return;
      }

      if (password.length < 12) {
        this.pushEvent("recovery_error", { error: "Password must be at least 12 characters." });
        return;
      }

      try {
        this.pushEvent("recovery_status", { status: "Verifying recovery key..." });

        // Convert human-readable recovery key to raw secret
        const recoverySecret = await recoveryKeyToSecret(recoveryKeyStr);

        // Fetch encrypted recovery data from server
        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || "";
        const resp = await fetch("/api/auth/recovery-data", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-csrf-token": csrfToken,
          },
          body: JSON.stringify({ email, recovery_secret: recoverySecret }),
        });

        if (!resp.ok) {
          const body = await resp.json().catch(() => ({}));
          this.pushEvent("recovery_error", {
            error: body.error || "Invalid recovery key or email.",
          });
          return;
        }

        const data = await resp.json();

        this.pushEvent("recovery_status", { status: "Decrypting your keys..." });

        // Decrypt the private key using the recovery secret
        const privateKey = await decryptPrivateKeyWithRecovery(
          data.encrypted_recovery_private_key,
          recoverySecret,
        );

        // Unseal the user_key using the recovered private key
        const userKey = await unsealFromUser(
          data.encrypted_user_key,
          data.public_key,
          privateKey,
          data.pq_secret_key || null,
        );

        this.pushEvent("recovery_status", { status: "Re-encrypting with new password..." });

        // Derive new session key from new password
        const newSalt = await generateSalt();
        const newSessionKey = await deriveSessionKey(password, newSalt);

        // Build new key_hash = salt$secretbox(user_key, session_key)
        const newEncryptedUserKey = await encryptSecretboxString(userKey, newSessionKey);
        const newKeyHash = newSalt + "$" + newEncryptedUserKey;

        // Re-encrypt private key with user_key (same as original storage format)
        const newEncryptedPrivateKey = await encryptPrivateKey(privateKey, userKey);

        // Store user_key temporarily for SessionKeyDeriver to pick up after login
        sessionStorage.setItem(TEMP_USER_KEY, userKey);

        // Push the new key material to the server
        this.pushEvent("recovery_complete", {
          email,
          recovery_secret: recoverySecret,
          new_password: password,
          new_key_hash: newKeyHash,
          new_encrypted_private_key: newEncryptedPrivateKey,
        });
      } catch (err) {
        console.error("AccountRecoveryHook: recovery failed:", err);
        this.pushEvent("recovery_error", {
          error: "Recovery failed. Please check your recovery key and try again.",
        });
      }
    });
  },
};

export default AccountRecoveryHook;
