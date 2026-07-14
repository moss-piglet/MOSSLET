import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";

// DecryptNudge (EPIC #377, task #399)
//
// Renders the sender's name on a content-free "thinking of you" nudge card
// entirely client-side. The nudge row is pure metadata — no name is ever stored
// server-side. We reuse the recipient's OWN sealed connection data (the same ZK
// path as DecryptConnectionCard / DecryptInviterName): unseal the per-connection
// key, then decrypt the connection name blob locally. The server only ever sees
// opaque blobs.
const DecryptNudge = {
  async mounted() {
    if (!(await this._decrypt())) {
      this._onKeysReady = () => this._decrypt();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });
    }
  },

  async updated() {
    this._decrypted = false;
    await this._decrypt();
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  async _decrypt() {
    if (this._decrypted) return true;

    const sealedKey = this.el.dataset.sealedUconnKey;
    const encryptedName = this.el.dataset.encryptedConnName;
    if (!sealedKey || !encryptedName) return true;
    if (!getPublicKey()) return false;

    try {
      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) return true;

      const connKey = unwrapKey(rawKey);
      const name = await decryptWithKey(encryptedName, connKey);

      if (name) {
        const targetId = this.el.dataset.targetId;
        if (targetId) {
          const target = document.getElementById(targetId);
          if (target) target.textContent = name;
        }
      }

      this._decrypted = true;
      return true;
    } catch (e) {
      console.error("DecryptNudge: decryption failed:", e);
      return true;
    }
  },
};

export default DecryptNudge;
