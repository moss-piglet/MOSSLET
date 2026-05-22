import { encryptSecretbox } from "../crypto/nacl";
import { getSealedConnKey, unsealContextKey, getPublicKey } from "../crypto/session";

/**
 * Server-registered users have conn_key sealed as a 44-char base64 string,
 * so unsealFromUser returns those ASCII bytes re-encoded as base64 (~60 chars).
 * Browser-registered users seal raw 32 bytes → correct 44-char base64 directly.
 */
function unwrapConnKey(unsealedB64) {
  if (unsealedB64.length > 44) {
    try {
      return atob(unsealedB64);
    } catch {
      return unsealedB64;
    }
  }
  return unsealedB64;
}

/**
 * EncryptUpload hook — browser-side ZK encryption for image uploads.
 *
 * The server processes images (resize, crop, format conversion) and sends
 * the final bytes to the browser via push_event("encrypt_upload", ...).
 * The browser encrypts with the user's conn_key and pushes the encrypted
 * blob back via pushEvent("encrypted_upload_ready", ...).
 *
 * This eliminates server-side conn_key unsealing during the upload path.
 *
 * Events:
 *   Server → Browser: "encrypt_upload" { blob_b64, upload_id }
 *   Browser → Server: "encrypted_upload_ready" { encrypted_blob_b64, upload_id }
 *   Browser → Server: "encrypted_upload_failed" { upload_id, reason }
 */
const EncryptUpload = {
  mounted() {
    this._encrypting = false;
    this._keysReadyHandler = null;

    this.handleEvent("encrypt_upload", (payload) => {
      this._encryptBlob(payload);
    });
  },

  destroyed() {
    if (this._keysReadyHandler) {
      window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
      this._keysReadyHandler = null;
    }
  },

  async _encryptBlob({ blob_b64, upload_id }) {
    if (this._encrypting) return;
    this._encrypting = true;

    try {
      if (!getPublicKey()) {
        await this._waitForKeys();
      }

      const sealedConnKey = getSealedConnKey();
      if (!sealedConnKey) {
        this._pushError(upload_id, "No conn_key available");
        return;
      }

      const rawKey = await unsealContextKey(sealedConnKey);
      if (!rawKey) {
        this._pushError(upload_id, "Failed to unseal conn_key");
        return;
      }

      const connKey = unwrapConnKey(rawKey);

      const rawBytes = Uint8Array.from(atob(blob_b64), (c) => c.charCodeAt(0));

      const encryptedBlobB64 = await encryptSecretbox(rawBytes, connKey);

      this.pushEvent("encrypted_upload_ready", {
        encrypted_blob_b64: encryptedBlobB64,
        upload_id: upload_id,
      });
    } catch (e) {
      console.error("EncryptUpload failed:", e);
      this._pushError(upload_id, "Encryption failed");
    } finally {
      this._encrypting = false;
    }
  },

  _pushError(upload_id, reason) {
    this.pushEvent("encrypted_upload_failed", {
      upload_id: upload_id,
      reason: reason,
    });
  },

  _waitForKeys() {
    return new Promise((resolve) => {
      if (getPublicKey()) {
        resolve();
        return;
      }

      if (this._keysReadyHandler) {
        window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
      }

      this._keysReadyHandler = () => {
        this._keysReadyHandler = null;
        resolve();
      };

      window.addEventListener("mosslet:keys-ready", this._keysReadyHandler, { once: true });
    });
  },
};

export default EncryptUpload;
