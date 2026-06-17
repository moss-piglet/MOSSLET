/**
 * OrgLogoUpload — browser-side ZK encryption for org brand-logo uploads (#228).
 *
 * Unlike the avatar `EncryptUpload` hook (which encrypts with the uploader's
 * personal conn_key), an org logo must be readable by EVERY org member, so it is
 * encrypted with the per-org `org_key` (#225) — the same symmetric key sealed to
 * each member in `Membership.key`. Any member can therefore decrypt and display
 * it (see OrgLogoDisplay).
 *
 * Flow:
 *   1. Server processes the image (resize/WebP) and pushes the final bytes via
 *      push_event("encrypt_org_logo", { blob_b64, upload_id }).
 *   2. This hook unseals the org_key from data-sealed-org-key, encrypts the bytes
 *      with it (secretbox), and pushes the opaque ciphertext back.
 *
 * Events:
 *   Server → Browser: "encrypt_org_logo"        { blob_b64, upload_id }
 *   Browser → Server: "encrypted_org_logo_ready" { encrypted_blob_b64, upload_id }
 *   Browser → Server: "encrypted_org_logo_failed" { upload_id, reason }
 *
 * Data attribute on the hook element:
 *   data-sealed-org-key — base64 org_key sealed for this member (Membership.key)
 */
import { encryptSecretbox } from "../crypto/nacl";
import { unsealContextKey, getPublicKey, unwrapKey } from "../crypto/session";

const KEY_WAIT_TIMEOUT_MS = 15_000;

const OrgLogoUpload = {
  mounted() {
    this._encrypting = false;
    this._orgKey = null;
    this._keysReadyHandler = null;

    this.handleEvent("encrypt_org_logo", (payload) => {
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

      const orgKey = await this._ensureOrgKey();
      if (!orgKey) {
        this._pushError(upload_id, "No org_key available");
        return;
      }

      const rawBytes = Uint8Array.from(atob(blob_b64), (c) => c.charCodeAt(0));
      const encryptedBlobB64 = await encryptSecretbox(rawBytes, orgKey);

      this.pushEvent("encrypted_org_logo_ready", {
        encrypted_blob_b64: encryptedBlobB64,
        upload_id,
      });
    } catch (e) {
      console.error("OrgLogoUpload failed:", e);
      this._pushError(upload_id, "Encryption failed");
    } finally {
      this._encrypting = false;
    }
  },

  async _ensureOrgKey() {
    if (this._orgKey) return this._orgKey;

    const sealed = this.el.dataset.sealedOrgKey;
    if (!sealed) return null;

    const raw = await unsealContextKey(sealed);
    if (raw) this._orgKey = unwrapKey(raw);
    return this._orgKey;
  },

  _pushError(upload_id, reason) {
    this.pushEvent("encrypted_org_logo_failed", { upload_id, reason });
  },

  _waitForKeys() {
    return new Promise((resolve, reject) => {
      if (getPublicKey()) {
        resolve();
        return;
      }

      const timer = setTimeout(() => {
        if (this._keysReadyHandler) {
          window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
          this._keysReadyHandler = null;
        }
        reject(new Error("Timed out waiting for crypto keys"));
      }, KEY_WAIT_TIMEOUT_MS);

      if (this._keysReadyHandler) {
        window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
      }

      this._keysReadyHandler = () => {
        clearTimeout(timer);
        this._keysReadyHandler = null;
        resolve();
      };

      window.addEventListener("mosslet:keys-ready", this._keysReadyHandler, {
        once: true,
      });
    });
  },
};

export default OrgLogoUpload;
