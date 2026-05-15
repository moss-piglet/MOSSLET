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

const DecryptGroupMessage = {
  async mounted() {
    await this.decrypt();
  },

  async updated() {
    await this.decrypt();
  },

  async decrypt() {
    const sealedKey = this.el.dataset.sealedGroupKey;
    const encryptedContent = this.el.dataset.encryptedContent;

    if (!sealedKey || !encryptedContent) return;
    if (!getPublicKey()) return;

    try {
      const rawGroupKey = await unsealContextKey(sealedKey);
      if (!rawGroupKey) return;

      const groupKey = unwrapGroupKey(rawGroupKey);
      const plaintext = await decryptWithKey(encryptedContent, groupKey);
      if (!plaintext) return;

      const html = renderMarkdown(plaintext);
      this.el.innerHTML = html;
    } catch (e) {
      console.error("DecryptGroupMessage: decryption failed:", e);
    }
  },
};

export default DecryptGroupMessage;
