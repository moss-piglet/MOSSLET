/**
 * RecoveryUnlockHook — new-device bootstrap unlock via recovery key (board #366).
 *
 * Mounted on the recovery-unlock form on /auth/unlock. An enrolled account on a
 * device with no local passkey can't unlock via PRF, and has NO password-only
 * door (retired on enroll, board #370). This hook lets such a device recover
 * `user_key` from the 256-bit recovery key — the always-present ZK fallback
 * (design §8) — then hands the decrypted session-key string to the unlock
 * controller so the session can be filled. The controller then routes the user
 * to Device Unlock settings to enroll THIS device (write an additional :prf
 * wrap of the same user_key).
 *
 * Invariant I6: `user_key`, the private key, and the recovery secret are all
 * derived/used IN THE BROWSER. The recovery secret is Argon2-verified server-side
 * (exactly the existing recovery model — never stored) purely to mint the
 * short-lived recovery-confirmation token that gates enrollment. `user_key`
 * reaches the server only as the hidden form field that fills the encrypted
 * session cookie — never a brute-forceable at-rest blob.
 */

import {
  recoveryKeyToSecret,
  decryptPrivateKeyWithRecovery,
  unsealFromUser,
} from "../crypto/nacl";

const TEMP_USER_KEY = "_mosslet_user_key_temp";

const RecoveryUnlockHook = {
  mounted() {
    const form = this.el;

    form.addEventListener("submit", async (e) => {
      // Only intercept the user-initiated submit; the phx-trigger-action POST
      // (which carries the recovered user_key) must proceed untouched.
      if (form.dataset.recoveryReady === "1") return;

      e.preventDefault();

      const keyInput = form.querySelector('input[name="recovery_key"]');
      const recoveryKeyStr = keyInput ? keyInput.value.trim() : "";

      if (!recoveryKeyStr) {
        this.pushEvent("recovery_unlock_error", {
          error: "Please enter your recovery key.",
        });
        return;
      }

      let recoverySecret;
      try {
        recoverySecret = await recoveryKeyToSecret(recoveryKeyStr);
      } catch {
        this.pushEvent("recovery_unlock_error", {
          error: "Could not read that recovery key. Please check it and try again.",
        });
        return;
      }

      // Server Argon2-verifies the secret (never stores it) and, on success,
      // mints the recovery-confirmation token rendered into unlock[rc].
      this.pushEvent("recovery_unlock_verify", { recovery_secret: recoverySecret }, (reply) => {
        if (!reply || !reply.ok) return;
        this.completeUnlock(form, keyInput, recoverySecret).catch((err) => {
          console.error("RecoveryUnlockHook: unlock failed:", err);
          this.pushEvent("recovery_unlock_error", {
            error: "Recovery unlock failed. Please try again.",
          });
        });
      });
    });
  },

  async completeUnlock(form, keyInput, recoverySecret) {
    const encRecoveryPrivKey = form.dataset.encryptedRecoveryPrivateKey;
    const publicKey = form.dataset.publicKey;
    const encUserKey = form.dataset.encryptedUserKey;

    if (!encRecoveryPrivKey || !publicKey || !encUserKey) {
      this.pushEvent("recovery_unlock_error", {
        error: "Recovery data unavailable. Please refresh and try again.",
      });
      return;
    }

    const privateKey = await decryptPrivateKeyWithRecovery(encRecoveryPrivKey, recoverySecret);
    const userKey = await unsealFromUser(encUserKey, publicKey, privateKey, null);

    if (!userKey) {
      this.pushEvent("recovery_unlock_error", {
        error: "Could not recover your keys with that recovery key.",
      });
      return;
    }

    // Hand user_key to the controller via the hidden field + temp session key
    // (picked up by SessionKeyDeriver after redirect). Never sent to the LiveView.
    if (keyInput) keyInput.value = "";
    const userKeyField = form.querySelector('input[name="unlock[user_key]"]');
    if (userKeyField) userKeyField.value = userKey;
    sessionStorage.setItem(TEMP_USER_KEY, userKey);

    // Let phx-trigger-action fire the real POST (guard flag above).
    form.dataset.recoveryReady = "1";
    this.pushEvent("recovery_unlock_ready", {});
  },
};

export default RecoveryUnlockHook;
