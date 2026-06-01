import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";

const DecryptInviterName = {
  async mounted() {
    if (!await this._decrypt()) {
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
    const encryptedUsername = this.el.dataset.encryptedConnUsername;
    if (!sealedKey || !encryptedUsername) return true;
    if (!getPublicKey()) return false;

    try {
      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) return true;

      const connKey = unwrapKey(rawKey);
      const username = await decryptWithKey(encryptedUsername, connKey);

      if (username) {
        const targetId = this.el.dataset.targetId;
        if (targetId) {
          const target = document.getElementById(targetId);
          if (target) target.textContent = "@" + username;
        }
      }

      this._decrypted = true;
      return true;
    } catch (e) {
      console.error("DecryptInviterName: decryption failed:", e);
      return true;
    }
  },
};

export default DecryptInviterName;
