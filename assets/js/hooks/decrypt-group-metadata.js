import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";

const DecryptGroupMetadata = {
  async mounted() {
    this._decrypted = false;

    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._decrypt(), { once: true });
      return;
    }

    await this._decrypt();
  },

  async updated() {
    this._decrypted = false;
    await this._decrypt();
  },

  async _decrypt() {
    if (this._decrypted) return;

    const sealedKey = this.el.dataset.sealedGroupKey;
    if (!sealedKey) return;

    try {
      const rawGroupKey = await unsealContextKey(sealedKey);
      if (!rawGroupKey) return;

      const groupKey = unwrapKey(rawGroupKey);

      const encryptedName = this.el.dataset.encryptedName;
      const encryptedMoniker = this.el.dataset.encryptedMoniker;

      if (encryptedName) {
        const name = await decryptWithKey(encryptedName, groupKey);
        if (name) {
          document.querySelectorAll("[data-decrypt-group-name]").forEach(el => {
            el.textContent = name;
          });
          this._decrypted = true;
        }
      }

      if (encryptedMoniker) {
        const moniker = await decryptWithKey(encryptedMoniker, groupKey);
        if (moniker) {
          document.querySelectorAll("[data-decrypt-group-moniker]").forEach(el => {
            el.textContent = moniker;
          });
        }
      }
    } catch (e) {
      console.error("DecryptGroupMetadata: decryption failed:", e);
    }
  },
};

export default DecryptGroupMetadata;
