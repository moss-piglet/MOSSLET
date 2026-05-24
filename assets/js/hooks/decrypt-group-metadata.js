import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";

const DecryptGroupMetadata = {
  async mounted() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this.decrypt(), { once: true });
      return;
    }
    await this.decrypt();
  },

  async decrypt() {
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
          const targets = document.querySelectorAll("[data-decrypt-group-name]");
          for (const el of targets) {
            el.textContent = name;
          }
        }
      }

      if (encryptedMoniker) {
        const moniker = await decryptWithKey(encryptedMoniker, groupKey);
        if (moniker) {
          const targets = document.querySelectorAll("[data-decrypt-group-moniker]");
          for (const el of targets) {
            el.textContent = moniker;
          }
        }
      }
    } catch (e) {
      console.error("DecryptGroupMetadata: decryption failed:", e);
    }
  },
};

export default DecryptGroupMetadata;
