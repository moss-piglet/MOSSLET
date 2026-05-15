/**
 * DecryptPost — browser-side post decryption hook.
 *
 * For non-public posts, the server passes the sealed post_key and encrypted
 * body as data attributes. This hook unseals the key using the user's
 * private keys (from sessionStorage, populated by SessionKeyDeriver) and
 * decrypts the body content in the browser.
 *
 * During the transition period the server also renders decrypted content as
 * the initial HTML inside [data-decrypt-target]. If browser-side decryption
 * fails, the server-rendered content is preserved — the hook never overwrites
 * good content with an error message.
 *
 * Public posts are decrypted server-side (sealed to the server keypair)
 * and don't use this hook.
 *
 * Data attributes:
 *   data-sealed-post-key  — base64 sealed post_key (envelope-encrypted to user)
 *   data-encrypted-body   — base64 secretbox-encrypted post body
 */
import { unsealContextKey, decryptWithKey, getPublicKey } from "../crypto/session";
import { renderMarkdown } from "../utils/render-markdown";

/**
 * Post keys are sealed as base64 strings on the server (the NIF seals a
 * 44-char base64-encoded key). The WASM unsealFromUser returns raw plaintext
 * bytes re-encoded as base64, producing a double-encoded result. We decode
 * one layer so decryptWithKey receives the original base64 key string.
 *
 * Conversation keys don't need this because they're sealed as raw 32-byte
 * values (the browser base64-decodes before sealing).
 */
function unwrapPostKey(unsealedB64) {
  try {
    return atob(unsealedB64);
  } catch {
    return unsealedB64;
  }
}

const DecryptPost = {
  async mounted() {
    await this.decrypt();
  },

  async updated() {
    if (this._cachedHtml) {
      this._renderCached();
    } else {
      await this.decrypt();
    }
  },

  async decrypt() {
    const sealedKey = this.el.dataset.sealedPostKey;
    const encryptedBody = this.el.dataset.encryptedBody;

    if (!sealedKey || !encryptedBody) return;
    if (!getPublicKey()) return;

    try {
      const rawPostKey = await unsealContextKey(sealedKey);
      if (!rawPostKey) return;

      const postKey = unwrapPostKey(rawPostKey);
      const plaintext = await decryptWithKey(encryptedBody, postKey);
      if (!plaintext) return;

      const html = renderMarkdown(plaintext);
      this._cachedHtml = html;
      this._renderContent(html);
    } catch (e) {
      // Browser-side decryption failed — server-rendered content is preserved.
    }
  },

  _renderContent(html) {
    const target = this.el.querySelector("[data-decrypt-target]");
    if (target) {
      target.innerHTML = html;
      target.classList.remove("animate-pulse");
    }
  },

  _renderCached() {
    this._renderContent(this._cachedHtml);
  },
};

export default DecryptPost;
