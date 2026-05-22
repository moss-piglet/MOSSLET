/**
 * DecryptReply — browser-side reply decryption hook (zero-knowledge).
 *
 * Replies use the parent post's post_key (shared via DecryptPost →
 * cachePostKey). This hook unseals the post_key from a data attribute
 * (fallback if not yet cached) and decrypts the reply body, username,
 * and images in the browser.
 *
 * Data attributes:
 *   data-post-id        — parent post UUID (for finding cached post_key)
 *   data-sealed-post-key — base64 sealed post_key (fallback if not cached)
 *   data-encrypted-body — base64 secretbox-encrypted reply body
 *   data-encrypted-username — base64 secretbox-encrypted reply username
 */
import { unsealContextKey, decryptWithKey, getCachedPostKey } from "../crypto/session";
import { renderMarkdown } from "../utils/render-markdown";

/**
 * Post keys are sealed as base64 strings on the server (the NIF seals a
 * 44-char base64-encoded key). The WASM unsealFromUser returns raw plaintext
 * bytes re-encoded as base64, producing a double-encoded result. We decode
 * one layer so decryptWithKey receives the original base64 key string.
 * Same logic as DecryptPost's unwrapPostKey.
 */
function unwrapPostKey(unsealedB64) {
  try {
    return atob(unsealedB64);
  } catch {
    return unsealedB64;
  }
}

const DecryptReply = {
  mounted() {
    this._decrypt();
  },

  updated() {
    this._decrypt();
  },

  async _decrypt() {
    const postId = this.el.dataset.postId;
    const encryptedBody = this.el.dataset.encryptedBody;
    const encryptedUsername = this.el.dataset.encryptedUsername;

    if (!postId || !encryptedBody) return;

    try {
      let postKey = getCachedPostKey(postId);

      if (!postKey) {
        const sealedKey = this.el.dataset.sealedPostKey;
        if (!sealedKey) return;
        const raw = await unsealContextKey(sealedKey);
        if (!raw) return;
        postKey = unwrapPostKey(raw);
      }

      const body = await decryptWithKey(encryptedBody, postKey);

      const bodyTarget = this.el.querySelector("[data-decrypt-reply-body]");
      if (body && bodyTarget) {
        bodyTarget.innerHTML = renderMarkdown(body);
      }

      const username = await decryptWithKey(encryptedUsername, postKey);

      const handleTarget = this.el.querySelector("[data-decrypt-reply-handle]");
      if (username && handleTarget) {
        handleTarget.textContent = "@" + username;
      }
    } catch (e) {
      // Fallback: server-rendered content preserved
    }
  },
};

export default DecryptReply;
