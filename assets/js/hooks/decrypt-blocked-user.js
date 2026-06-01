/**
 * DecryptBlockedUser — browser-side decryption of blocked user card fields.
 *
 * Each blocked user card has two decryption contexts:
 *   1. Connection name + username: encrypted with conn_key, sealed as uconn.key
 *   2. Block reason: encrypted with user_key (personal to the blocker)
 *
 * Data attributes on the hook element:
 *   data-sealed-uconn-key          — base64 sealed conn_key (from user_connection.key)
 *   data-encrypted-conn-name       — base64 secretbox-encrypted connection name
 *   data-encrypted-conn-username   — base64 secretbox-encrypted connection username
 *   data-encrypted-reason          — base64 secretbox-encrypted block reason
 *
 * Target elements (scoped within this.el):
 *   [data-decrypt-blocked="conn_name"]     — textContent set
 *   [data-decrypt-blocked="conn_username"] — textContent set
 *   [data-decrypt-blocked="reason"]        — textContent set
 */
import {
  unsealContextKey,
  decryptWithKey,
  getPublicKey,
  unwrapKey,
  getUserKey,
  getSealedUserKey,
} from "../crypto/session";

const DecryptBlockedUser = {
  async mounted() {
    if (!(await this._decrypt())) {
      this._onKeysReady = () => this._decrypt();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, {
        once: true,
      });
    }
  },

  async updated() {
    if (this._cache) {
      this._applyAll();
    } else {
      this._decrypted = false;
      await this._decrypt();
    }
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  async _decrypt() {
    if (this._decrypted) return true;
    if (!getPublicKey()) return false;

    try {
      this._cache = {};
      await this._decryptConnFields();
      await this._decryptReason();
      this._applyAll();
      this._decrypted = true;
      return true;
    } catch (e) {
      console.error("DecryptBlockedUser: decryption failed:", e);
      return true;
    }
  },

  async _decryptConnFields() {
    const sealedKey = this.el.dataset.sealedUconnKey;
    if (!sealedKey) return;

    const rawKey = await unsealContextKey(sealedKey);
    if (!rawKey) return;

    const connKey = unwrapKey(rawKey);

    const encName = this.el.dataset.encryptedConnName;
    if (encName) {
      const name = await decryptWithKey(encName, connKey);
      if (name) this._cache.conn_name = name;
    }

    const encUsername = this.el.dataset.encryptedConnUsername;
    if (encUsername) {
      const username = await decryptWithKey(encUsername, connKey);
      if (username) this._cache.conn_username = username;
    }
  },

  async _decryptReason() {
    const encReason = this.el.dataset.encryptedReason;
    if (!encReason) return;

    const sealedUserKey = getSealedUserKey();
    if (!sealedUserKey) return;

    const userKey = await getUserKey(sealedUserKey);
    if (!userKey) return;

    const reason = await decryptWithKey(encReason, userKey);
    if (reason) this._cache.reason = reason;
  },

  _applyAll() {
    if (!this._cache) return;
    for (const [field, value] of Object.entries(this._cache)) {
      const targets = this.el.querySelectorAll(
        `[data-decrypt-blocked="${field}"]`,
      );
      for (const target of targets) {
        target.textContent = value;
        target.classList.remove("animate-pulse");
      }
    }
  },
};

export default DecryptBlockedUser;
