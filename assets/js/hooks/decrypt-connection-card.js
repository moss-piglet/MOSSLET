import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";

const DecryptConnectionCard = {
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
    if (!sealedKey) return true;
    if (!getPublicKey()) return false;

    try {
      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) return true;

      const connKey = unwrapKey(rawKey);

      const encryptedName = this.el.dataset.encryptedConnName;
      const encryptedUsername = this.el.dataset.encryptedConnUsername;
      const encryptedConnLabel = this.el.dataset.encryptedConnLabel;

      if (encryptedName) {
        const name = await decryptWithKey(encryptedName, connKey);
        if (name) {
          document.querySelectorAll("[data-decrypt-conn-name]").forEach(el => {
            el.textContent = name;
          });
        }
      }

      if (encryptedUsername) {
        const username = await decryptWithKey(encryptedUsername, connKey);
        if (username) {
          document.querySelectorAll("[data-decrypt-conn-username]").forEach(el => {
            el.textContent = username;
          });
        }
      }

      if (encryptedConnLabel) {
        const label = await decryptWithKey(encryptedConnLabel, connKey);
        if (label) {
          document.querySelectorAll("[data-decrypt-conn-label]").forEach(el => {
            el.textContent = label;
          });
        }
      }

      const encryptedArrivalName = this.el.dataset.encryptedArrivalName;
      const encryptedArrivalEmail = this.el.dataset.encryptedArrivalEmail;
      const encryptedArrivalLabel = this.el.dataset.encryptedArrivalLabel;

      if (encryptedArrivalName) {
        const name = await decryptWithKey(encryptedArrivalName, connKey);
        if (name) {
          document.querySelectorAll("[data-decrypt-arrival-name]").forEach(el => {
            el.textContent = name;
          });
        }
      }

      if (encryptedArrivalEmail) {
        const email = await decryptWithKey(encryptedArrivalEmail, connKey);
        if (email) {
          document.querySelectorAll("[data-decrypt-arrival-email]").forEach(el => {
            el.textContent = email;
          });
        }
      }

      if (encryptedArrivalLabel) {
        const label = await decryptWithKey(encryptedArrivalLabel, connKey);
        if (label) {
          document.querySelectorAll("[data-decrypt-arrival-label]").forEach(el => {
            el.textContent = label;
          });
        }
      }

      this._decrypted = true;
      return true;
    } catch (e) {
      console.error("DecryptConnectionCard: decryption failed:", e);
      return true;
    }
  },
};

export default DecryptConnectionCard;
