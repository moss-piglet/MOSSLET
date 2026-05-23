/**
 * DecryptProfileFields — browser-side profile field decryption (zero-knowledge).
 *
 * For non-public profiles, the server passes encrypted blobs and a sealed key
 * instead of decrypting server-side. This hook unseals the key and decrypts
 * the profile fields in the browser via WASM.
 *
 * Two viewing modes:
 *   - Own profile: sealed_profile_key = profile_key sealed to user's pubkey
 *   - Connection viewer: sealed_profile_key = conn_key sealed to viewer's pubkey
 *     (profile_key IS the conn_key for connection profiles)
 *
 * Data attributes on the hook element:
 *   data-sealed-profile-key        — base64 sealed profile key (or conn_key)
 *   data-encrypted-about           — base64 secretbox-encrypted about
 *   data-encrypted-alternate-email — base64 secretbox-encrypted alternate email
 *   data-encrypted-website-url     — base64 secretbox-encrypted website URL
 *   data-encrypted-website-label   — base64 secretbox-encrypted website label
 *   data-profile-id                — unique identifier for the profile
 *
 * Target elements (scoped to nearest parent with data-profile-scope or document):
 *   [data-decrypt-profile="about"]           — textContent set
 *   [data-decrypt-profile="alternate_email"] — textContent or href set
 *   [data-decrypt-profile="website_url"]     — textContent or href set
 *   [data-decrypt-profile="website_label"]   — textContent set
 */
import { unsealContextKey, decryptWithKey, getPublicKey, unwrapConnKey } from "../crypto/session";

const FIELDS = [
  { key: "about", attr: "encryptedAbout" },
  { key: "alternate_email", attr: "encryptedAlternateEmail" },
  { key: "website_url", attr: "encryptedWebsiteUrl" },
  { key: "website_label", attr: "encryptedWebsiteLabel" },
];

const DecryptProfileFields = {
  async mounted() {
    await this.decrypt();
  },

  async updated() {
    if (this._cache) {
      this._applyAll();
    } else {
      await this.decrypt();
    }
  },

  async decrypt() {
    const sealedKey = this.el.dataset.sealedProfileKey;
    if (!sealedKey) return;

    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this.decrypt(), { once: true });
      return;
    }

    try {
      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) return;

      const profileKey = unwrapConnKey(rawKey);
      const decrypted = {};

      for (const { key, attr } of FIELDS) {
        const encrypted = this.el.dataset[attr];
        if (encrypted) {
          const plaintext = await decryptWithKey(encrypted, profileKey);
          if (plaintext) decrypted[key] = plaintext;
        }
      }

      this._cache = decrypted;
      this._applyAll();
    } catch (e) {
      // Browser-side decryption failed — server-rendered fallback values are preserved.
    }
  },

  _applyAll() {
    if (!this._cache) return;

    const profileId = this.el.dataset.profileId;
    const scope = profileId
      ? document.querySelector(`[data-profile-scope="${profileId}"]`) || document
      : document;

    for (const [field, value] of Object.entries(this._cache)) {
      const targets = scope.querySelectorAll(`[data-decrypt-profile="${field}"]`);
      for (const target of targets) {
        if (target.tagName === "A") {
          target.textContent = value;
          if (field === "alternate_email") {
            target.href = `mailto:${value}`;
          } else if (field === "website_url") {
            target.href = value;
          }
        } else {
          target.textContent = value;
        }
        target.classList.remove("animate-pulse");
      }
    }
  },

  getDecrypted() {
    return this._cache || {};
  },
};

export default DecryptProfileFields;
