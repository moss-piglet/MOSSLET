/**
 * DecryptAnnouncement — browser-side announcement decryption (ZK read path, #229c).
 *
 * Decrypts an announcement's title/body in place using the tier's shared key.
 * Two tiers, selected by `data-key-tier`:
 *   "org"   — unseals the per-org `org_key` from `data-sealed-org-key`.
 *   "group" — unseals the circle `group_key` from `data-sealed-group-key`.
 *
 * Mirrors DecryptGroupMetadata (group_key) / OrgMembers (org_key).
 *
 * Element data attributes:
 *   data-encrypted-title — ciphertext, or "" when no title
 *   data-encrypted-body  — ciphertext
 * Targets filled (scoped to this element's subtree):
 *   [data-decrypt-announcement-title]
 *   [data-decrypt-announcement-body]
 */
import {
  unsealContextKey,
  decryptWithKey,
  getPublicKey,
  unwrapKey,
} from "../crypto/session";

const DecryptAnnouncement = {
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

  _sealedKey() {
    return this.el.dataset.keyTier === "org"
      ? this.el.dataset.sealedOrgKey
      : this.el.dataset.sealedGroupKey;
  },

  async _decrypt() {
    if (this._decrypted) return true;

    const sealedKey = this._sealedKey();
    if (!sealedKey) return true;
    if (!getPublicKey()) return false;

    try {
      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) return true;

      const key = unwrapKey(rawKey);

      const encryptedTitle = this.el.dataset.encryptedTitle;
      const encryptedBody = this.el.dataset.encryptedBody;

      if (encryptedTitle) {
        const title = await decryptWithKey(encryptedTitle, key);
        if (title) {
          this.el
            .querySelectorAll("[data-decrypt-announcement-title]")
            .forEach((el) => {
              el.textContent = title;
            });
        }
      }

      if (encryptedBody) {
        const body = await decryptWithKey(encryptedBody, key);
        if (body) {
          this.el
            .querySelectorAll("[data-decrypt-announcement-body]")
            .forEach((el) => {
              el.textContent = body;
            });
        }
      }

      this._decrypted = true;
      return true;
    } catch (e) {
      console.error("DecryptAnnouncement: decryption failed:", e);
      return true;
    }
  },
};

export default DecryptAnnouncement;
