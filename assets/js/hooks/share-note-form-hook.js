/**
 * ShareNoteFormHook — encrypts the share note with the cached post_key
 * before the form data reaches the server.
 *
 * For non-public posts, the DecryptPost hook has already cached the post_key
 * in session.js. This hook reads it via getCachedPostKey(postId), encrypts the
 * note with encryptSecretboxString(), and injects a hidden field with the
 * ciphertext. The server receives only encrypted data — the plaintext note
 * never leaves the browser.
 *
 * For public posts (or when no cached post_key is available), falls through
 * to the normal form submit with plaintext — the server encrypts it
 * (public posts need server-readable content anyway).
 *
 * Data attributes:
 *   data-post-id — the post being shared
 */
import { getCachedPostKey } from "../crypto/session";
import { encryptSecretboxString } from "../crypto/nacl";

const ShareNoteFormHook = {
  mounted() {
    this._encrypting = false;
    this.el.addEventListener("submit", (e) => this._handleSubmit(e));
  },

  async _handleSubmit(e) {
    if (this._encrypting) return;

    const postId = this.el.dataset.postId;
    if (!postId) return;

    const postKey = getCachedPostKey(postId);
    if (!postKey) return;

    const textarea = this.el.querySelector("textarea[name='share[share_note]']");
    const note = textarea ? textarea.value.trim() : "";
    if (!note) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    try {
      this._encrypting = true;
      const encrypted = await encryptSecretboxString(note, postKey);

      let hiddenField = this.el.querySelector("input[name='share[encrypted_share_note]']");
      if (!hiddenField) {
        hiddenField = document.createElement("input");
        hiddenField.type = "hidden";
        hiddenField.name = "share[encrypted_share_note]";
        this.el.appendChild(hiddenField);
      }
      hiddenField.value = encrypted;

      textarea.value = "";

      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    } catch (err) {
      console.error("ShareNoteFormHook: encryption failed, falling through:", err);
    } finally {
      this._encrypting = false;
    }
  },
};

export default ShareNoteFormHook;
