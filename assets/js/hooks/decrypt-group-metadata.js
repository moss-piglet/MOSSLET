import { unsealContextKey, decryptWithKey, getPublicKey } from "../crypto/session";

function unwrapGroupKey(unsealedB64) {
  if (unsealedB64.length > 44) {
    try {
      return atob(unsealedB64);
    } catch {
      return unsealedB64;
    }
  }
  return unsealedB64;
}

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

      const groupKey = unwrapGroupKey(rawGroupKey);

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
