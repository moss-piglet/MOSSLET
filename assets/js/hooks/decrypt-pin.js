/**
 * DecryptPin — browser-side link-pin decryption (ZK read path, #229d).
 *
 * Decrypts a link pin's label + URL in place with the appropriate key. Two
 * scopes, selected by `data-pin-scope`:
 *   "personal"   — decrypts with the viewer's `user_key` (read from the DOM via
 *                  getSealedUserKey() — mirrors DecryptBlockedUser's reason path).
 *   "org_shared" — decrypts with the per-org `org_key`, unsealed from
 *                  `data-sealed-org-key` (mirrors DecryptAnnouncement org tier).
 *
 * Element data attributes:
 *   data-encrypted-label — ciphertext
 *   data-encrypted-url   — ciphertext
 * Targets filled (scoped to this element's subtree):
 *   [data-decrypt-pin-label] — textContent set
 *   [data-decrypt-pin-url]   — href set (an <a>) when the URL is http(s)
 */
import {
  unsealContextKey,
  decryptWithKey,
  getPublicKey,
  unwrapKey,
  getUserKey,
  getSealedUserKey,
} from "../crypto/session";

const DecryptPin = {
  async mounted() {
    if (!(await this._decrypt())) {
      this._onKeysReady = () => this._decrypt();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, {
        once: true,
      });
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

  async _key() {
    if (this.el.dataset.pinScope === "org_shared") {
      const sealed = this.el.dataset.sealedOrgKey;
      if (!sealed) return null;
      const raw = await unsealContextKey(sealed);
      return raw ? unwrapKey(raw) : null;
    }

    const sealedUserKey = getSealedUserKey();
    if (!sealedUserKey) return null;
    return await getUserKey(sealedUserKey);
  },

  async _decrypt() {
    if (this._decrypted) return true;
    if (!getPublicKey()) return false;

    try {
      const key = await this._key();
      if (!key) return true;

      const encryptedLabel = this.el.dataset.encryptedLabel;
      const encryptedUrl = this.el.dataset.encryptedUrl;

      if (encryptedLabel) {
        const label = await decryptWithKey(encryptedLabel, key);
        if (label) {
          this.el
            .querySelectorAll("[data-decrypt-pin-label]")
            .forEach((el) => {
              el.textContent = label;
            });
        }
      }

      if (encryptedUrl) {
        const url = await decryptWithKey(encryptedUrl, key);
        if (url && /^https?:\/\//i.test(url)) {
          this.el.querySelectorAll("[data-decrypt-pin-url]").forEach((el) => {
            el.setAttribute("href", url);
          });
        }
      }

      this._decrypted = true;
      return true;
    } catch (e) {
      console.error("DecryptPin: decryption failed:", e);
      return true;
    }
  },
};

export default DecryptPin;
