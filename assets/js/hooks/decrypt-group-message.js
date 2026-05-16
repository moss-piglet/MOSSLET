/**
 * DecryptGroupMessage — browser-side group message decryption (zero-knowledge).
 *
 * For non-public groups, the server passes the sealed group_key and encrypted
 * message content as data attributes. This hook unseals the key and decrypts
 * the content in the browser. The server never sees plaintext message content.
 *
 * Public groups are decrypted server-side and don't use this hook.
 *
 * Data attributes:
 *   data-sealed-group-key   — base64 sealed group_key (envelope-encrypted to user)
 *   data-encrypted-content  — secretbox-encrypted message content
 */
import { unsealContextKey, decryptWithKey, getPublicKey } from "../crypto/session";
import { renderMarkdown } from "../utils/render-markdown";

/**
 * Group keys follow the same double-encoding pattern as post keys:
 * the NIF seals a base64-encoded symmetric key, and unsealFromUser
 * returns the plaintext re-encoded as base64. Decode one layer.
 */
function unwrapGroupKey(unsealedB64) {
  try {
    return atob(unsealedB64);
  } catch {
    return unsealedB64;
  }
}

const FAILED_MARKUP =
  '<span class="text-red-400 dark:text-red-500 text-sm italic">[Decryption failed]</span>';

const MAX_WAIT_MS = 8000;

const DecryptGroupMessage = {
  async mounted() {
    if (!await this.decrypt()) {
      this._onKeysReady = () => this.decrypt();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });

      this._timeout = setTimeout(() => {
        window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
        if (!this._decrypted) this.el.innerHTML = FAILED_MARKUP;
      }, MAX_WAIT_MS);
    }
  },

  async updated() {
    await this.decrypt();
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
    if (this._timeout) clearTimeout(this._timeout);
  },

  async decrypt() {
    const sealedKey = this.el.dataset.sealedGroupKey;
    const encryptedContent = this.el.dataset.encryptedContent;

    if (!sealedKey || !encryptedContent) {
      this.el.innerHTML = FAILED_MARKUP;
      return true;
    }
    if (!getPublicKey()) return false;

    try {
      const rawGroupKey = await unsealContextKey(sealedKey);
      if (!rawGroupKey) {
        this.el.innerHTML = FAILED_MARKUP;
        return true;
      }

      const groupKey = unwrapGroupKey(rawGroupKey);
      const plaintext = await decryptWithKey(encryptedContent, groupKey);
      if (!plaintext) {
        this.el.innerHTML = FAILED_MARKUP;
        return true;
      }

      const html = renderMarkdown(plaintext);
      this.el.innerHTML = html;
      this._decrypted = true;
      if (this._timeout) clearTimeout(this._timeout);
      return true;
    } catch (e) {
      console.error("DecryptGroupMessage: decryption failed:", e);
      this.el.innerHTML = FAILED_MARKUP;
      return true;
    }
  },
};

export default DecryptGroupMessage;
