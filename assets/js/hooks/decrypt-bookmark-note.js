/**
 * DecryptBookmarkNote — browser-side bookmark note decryption hook.
 *
 * Uses the cached post_key (populated by DecryptPost) to decrypt the
 * bookmark notes blob. If the post_key isn't cached yet, waits for the
 * DecryptPost hook to fire first.
 *
 * Data attributes:
 *   data-post-id         — post UUID (used to look up the cached post_key)
 *   data-encrypted-notes — base64 secretbox-encrypted bookmark notes
 */
import { getCachedPostKey, decryptWithKey } from "../crypto/session";

const DecryptBookmarkNote = {
  async mounted() {
    this._retries = 0;
    await this._decrypt();
  },

  async updated() {
    await this._decrypt();
  },

  async _decrypt() {
    const postId = this.el.dataset.postId;
    const encryptedNotes = this.el.dataset.encryptedNotes;
    if (!postId || !encryptedNotes) return;

    const postKey = getCachedPostKey(postId);
    if (!postKey) {
      if (this._retries < 20) {
        this._retries++;
        this._timer = setTimeout(() => this._decrypt(), 150);
      }
      return;
    }

    try {
      const plaintext = await decryptWithKey(encryptedNotes, postKey);
      if (plaintext) {
        const target = this.el.querySelector("[data-decrypt-notes-target]");
        if (target) {
          target.textContent = plaintext;
          this.el.classList.remove("hidden");
        }
      }
    } catch {
      // Decryption failed — keep hidden
    }
  },

  destroyed() {
    if (this._timer) clearTimeout(this._timer);
  },
};

export default DecryptBookmarkNote;
