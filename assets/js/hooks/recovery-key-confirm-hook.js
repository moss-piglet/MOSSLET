/**
 * RecoveryKeyConfirmHook — authenticated "prove you still hold your recovery key"
 * step (board #364).
 *
 * Mounted on the confirm form shown when a user is routed from Device Unlock to
 * confirm their EXISTING recovery key before enrolling a device. It:
 *
 *   1. Reads the typed human-readable recovery key.
 *   2. Converts it to the raw secret via recoveryKeyToSecret() (client-side).
 *   3. Pushes { recovery_secret } to the LiveView, which Argon2-verifies it
 *      against the stored hash (I6: the server only ever verifies the secret,
 *      exactly like the existing recovery flow — it never persists it).
 *
 * On success the LiveView mints a short-lived confirmation token and navigates
 * on to device-unlock enrollment.
 */

import { recoveryKeyToSecret } from "../crypto/nacl";

const RecoveryKeyConfirmHook = {
  mounted() {
    this.el.addEventListener("submit", async (e) => {
      e.preventDefault();

      const input = this.el.querySelector('input[name="recovery_key"]');
      const recoveryKeyStr = input ? input.value.trim() : "";

      if (!recoveryKeyStr) {
        this.pushEvent("recovery_confirm_error", {
          error: "Please enter your recovery key.",
        });
        return;
      }

      try {
        const recoverySecret = await recoveryKeyToSecret(recoveryKeyStr);
        this.pushEvent("verify_recovery_secret", { recovery_secret: recoverySecret });
      } catch (err) {
        console.error("RecoveryKeyConfirmHook: conversion failed:", err);
        this.pushEvent("recovery_confirm_error", {
          error: "Could not read that recovery key. Please check it and try again.",
        });
      }
    });
  },
};

export default RecoveryKeyConfirmHook;
