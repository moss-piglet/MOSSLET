import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";

const DecryptGroupMetadata = {
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

  _scopeEl() {
    const scopeId = this.el.dataset.scopeId;
    if (scopeId) {
      return this.el.closest(`[data-hook-scope="${scopeId}"]`) || document;
    }
    return document;
  },

  async _decrypt() {
    if (this._decrypted) return true;

    const sealedKey = this.el.dataset.sealedGroupKey;
    if (!sealedKey) return true;
    if (!getPublicKey()) return false;

    try {
      const rawGroupKey = await unsealContextKey(sealedKey);
      if (!rawGroupKey) return true;

      const groupKey = unwrapKey(rawGroupKey);
      const scope = this._scopeEl();

      const encryptedName = this.el.dataset.encryptedName;
      const encryptedMoniker = this.el.dataset.encryptedMoniker;
      const encryptedDescription = this.el.dataset.encryptedDescription;
      const encryptedAvatarImg = this.el.dataset.encryptedAvatarImg;

      if (encryptedName) {
        const name = await decryptWithKey(encryptedName, groupKey);
        if (name) {
          scope.querySelectorAll("[data-decrypt-group-name]").forEach(el => {
            el.textContent = name;
          });
        }
      }

      if (encryptedMoniker) {
        const moniker = await decryptWithKey(encryptedMoniker, groupKey);
        if (moniker) {
          scope.querySelectorAll("[data-decrypt-group-moniker]").forEach(el => {
            el.textContent = moniker;
          });
        }
      }

      if (encryptedDescription) {
        const description = await decryptWithKey(encryptedDescription, groupKey);
        if (description) {
          scope.querySelectorAll("[data-decrypt-group-description]").forEach(el => {
            el.textContent = description;
          });
        }
      }

      if (encryptedAvatarImg) {
        const avatarImg = await decryptWithKey(encryptedAvatarImg, groupKey);
        if (avatarImg) {
          scope.querySelectorAll("[data-decrypt-group-avatar-img]").forEach(el => {
            if (el.tagName === "IMG") {
              el.src = avatarImg;
            } else {
              el.textContent = avatarImg;
            }
          });
        }
      }

      this._decrypted = true;
      return true;
    } catch (e) {
      console.error("DecryptGroupMetadata: decryption failed:", e);
      return true;
    }
  },
};

export default DecryptGroupMetadata;
