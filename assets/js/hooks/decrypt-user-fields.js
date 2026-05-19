/**
 * DecryptUserFields — browser-side user profile field decryption (zero-knowledge).
 *
 * The server passes the sealed user_key (user_attributes_key) and encrypted
 * profile fields as data attributes on the #decrypt-user-fields element in
 * the authenticated layout. This hook unseals the user_key using the user's
 * private keys (from sessionStorage, populated by SessionKeyDeriver) and
 * decrypts each field in the browser via WASM. The server need not perform
 * the secretbox decryption for display — true ZK for web users.
 *
 * Data attributes on the hook element:
 *   data-sealed-user-key          — base64 sealed user_attributes_key
 *   data-encrypted-email          — base64 secretbox-encrypted email
 *   data-encrypted-username       — base64 secretbox-encrypted username
 *   data-encrypted-name           — base64 secretbox-encrypted name
 *   data-encrypted-avatar-url     — base64 secretbox-encrypted avatar URL
 *   data-encrypted-status-message — base64 secretbox-encrypted status message
 *
 * Target elements (found globally in the document):
 *   [data-decrypt-field="email"]          — textContent or input.value set
 *   [data-decrypt-field="username"]       — textContent or input.value set
 *   [data-decrypt-field="name"]           — textContent or input.value set
 *   [data-decrypt-field="avatar_url"]     — textContent or input.value set
 *   [data-decrypt-field="status_message"] — textContent or input.value set
 *
 * Dispatches `mosslet:user-decrypted` CustomEvent on window with the
 * decrypted fields map as `detail` once complete.
 */
import { unsealContextKey, decryptWithKey, getPublicKey } from "../crypto/session";

const FIELDS = ["email", "username", "name", "avatar_url", "status_message"];

/**
 * User keys are sealed as base64 strings on the server (the NIF seals a
 * 44-char base64-encoded key). The WASM unsealFromUser returns raw plaintext
 * bytes re-encoded as base64, producing a double-encoded result. We decode
 * one layer so decryptWithKey receives the original base64 key string.
 *
 * Same unwrap as DecryptPost's unwrapPostKey.
 */
function unwrapUserKey(unsealedB64) {
  try {
    return atob(unsealedB64);
  } catch {
    return unsealedB64;
  }
}

function dataAttrName(field) {
  return "encrypted" + field.split("_").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join("");
}

const DecryptUserFields = {
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
    const sealedKey = this.el.dataset.sealedUserKey;
    if (!sealedKey) return;

    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this.decrypt(), { once: true });
      return;
    }

    try {
      const rawUserKey = await unsealContextKey(sealedKey);
      if (!rawUserKey) return;

      const userKey = unwrapUserKey(rawUserKey);
      const decrypted = {};

      for (const field of FIELDS) {
        const attr = dataAttrName(field);
        const encrypted = this.el.dataset[attr];
        if (encrypted) {
          const plaintext = await decryptWithKey(encrypted, userKey);
          if (plaintext) decrypted[field] = plaintext;
        }
      }

      this._cache = decrypted;
      this._applyAll();
      window.dispatchEvent(new CustomEvent("mosslet:user-decrypted", { detail: decrypted }));
    } catch (e) {
      // Browser-side decryption failed — server-rendered fallback values are preserved.
    }
  },

  _applyAll() {
    if (!this._cache) return;

    for (const [field, value] of Object.entries(this._cache)) {
      const containers = document.querySelectorAll(`[data-decrypt-field="${field}"]`);
      for (const container of containers) {
        const el = container.matches("input, textarea, select")
          ? container
          : container.querySelector("input, textarea, select") || container;

        if (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.tagName === "SELECT") {
          if (!el.dataset.decryptApplied) {
            el.value = value;
            el.dataset.decryptApplied = "1";
          }
        } else {
          el.textContent = value;
        }
        container.classList.remove("animate-pulse");
      }
    }
  },

  getDecrypted() {
    return this._cache || {};
  },
};

export default DecryptUserFields;
