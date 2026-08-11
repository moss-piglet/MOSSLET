import {
  unsealContextKey,
  decryptWithKey,
  getCachedPostKey,
  getPublicKey,
  unwrapKey,
} from "../crypto/session";

// DecryptReplyAuthor — browser-side reply author name decryption (zero-knowledge).
//
// Used by the dashboard "New replies" card: each row carries only metadata plus
// the encrypted reply username and the viewer's sealed post key. The browser
// unseals the post_key (or reuses the cached one from DecryptPost) and decrypts
// the author name locally — the server never sees plaintext. Mirrors the
// DecryptNudge pattern, including the mosslet:keys-ready retry for sessions
// where the WASM keys are still loading.
//
// Data attributes:
//   data-post-id             — parent post UUID (for finding the cached post_key)
//   data-sealed-post-key     — base64 sealed post_key (fallback if not cached)
//   data-encrypted-username  — base64 secretbox-encrypted reply username
//   data-target-id           — DOM id of the span to populate with the name
const DecryptReplyAuthor = {
  async mounted() {
    if (!(await this._decrypt())) {
      this._onKeysReady = () => this._decrypt();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });
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

  async _decrypt() {
    if (this._decrypted) return true;

    const postId = this.el.dataset.postId;
    const encryptedUsername = this.el.dataset.encryptedUsername;
    if (!postId || !encryptedUsername) return true;
    if (!getPublicKey()) return false;

    try {
      let postKey = getCachedPostKey(postId);

      if (!postKey) {
        const sealedKey = this.el.dataset.sealedPostKey;
        if (!sealedKey) return true;
        const raw = await unsealContextKey(sealedKey);
        if (!raw) return true;
        postKey = unwrapKey(raw);
      }

      const username = await decryptWithKey(encryptedUsername, postKey);

      if (username) {
        const targetId = this.el.dataset.targetId;
        const target = targetId && document.getElementById(targetId);
        if (target) target.textContent = username;
      }

      this._decrypted = true;
      return true;
    } catch {
      // Fallback: server-rendered "Someone" placeholder is preserved.
      return true;
    }
  },
};

export default DecryptReplyAuthor;
