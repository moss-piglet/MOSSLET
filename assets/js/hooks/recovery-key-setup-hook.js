/**
 * RecoveryKeySetupHook — browser-side recovery key generation.
 *
 * Mounted on the recovery key setup form in Settings. When the user clicks
 * "Generate Recovery Key", this hook:
 *
 *   1. Reads the already-decrypted private key from sessionStorage
 *      (populated by SessionKeyDeriver on every authenticated page)
 *   2. Calls WASM generateRecoveryKey() to produce:
 *      - recoveryKey: human-readable base32 string (shown once to user)
 *      - recoverySecretBase64: raw 32-byte secret as base64
 *   3. Calls WASM encryptPrivateKeyForRecovery(privateKey, recoverySecret)
 *      to produce an encrypted blob of the private key
 *   4. Pushes { recovery_secret, encrypted_recovery_private_key } to the
 *      server via LiveView pushEvent
 *   5. Server hashes recovery_secret with Argon2, stores hash + encrypted blob
 *   6. Displays the recovery key to the user (shown once, never stored)
 *
 * The recovery secret travels over the authenticated LiveView WebSocket
 * (TLS-encrypted). It is never stored client-side.
 */

import {
  generateRecoveryKey,
  encryptPrivateKeyForRecovery,
} from "../crypto/nacl";
import { getPrivateKey } from "../crypto/session";

const RecoveryKeySetupHook = {
  mounted() {
    this.handleEvent("generate_recovery_key", async () => {
      const privateKey = getPrivateKey();
      if (!privateKey) {
        this.pushEvent("recovery_key_error", {
          error: "Session keys not available. Please refresh the page and try again.",
        });
        return;
      }

      try {
        // Generate a human-readable recovery key + raw secret
        const { recoveryKey, recoverySecretBase64 } = await generateRecoveryKey();

        // Encrypt the private key with the recovery secret
        const encryptedRecoveryPrivateKey = await encryptPrivateKeyForRecovery(
          privateKey,
          recoverySecretBase64,
        );

        // Send the recovery secret + encrypted blob to the server
        // The server will Argon2-hash the secret and store the hash + blob.
        // The raw recovery secret is NOT stored anywhere after this.
        this.pushEvent("recovery_key_generated", {
          recovery_secret: recoverySecretBase64,
          encrypted_recovery_private_key: encryptedRecoveryPrivateKey,
          recovery_key_display: recoveryKey,
        });
      } catch (err) {
        console.error("RecoveryKeySetupHook: key generation failed:", err);
        this.pushEvent("recovery_key_error", {
          error: "Failed to generate recovery key. Please try again.",
        });
      }
    });
  },
};

export default RecoveryKeySetupHook;
