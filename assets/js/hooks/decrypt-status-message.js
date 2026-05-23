/**
 * DecryptStatusMessage — browser-side status message decryption (zero-knowledge).
 *
 * For connection status messages, the server passes the encrypted blob and the
 * viewer's sealed copy of the conn_key. This hook unseals the key and decrypts
 * the status message in the browser via WASM.
 *
 * Data attributes on the hook element:
 *   data-encrypted-status-message — base64 secretbox-encrypted status message
 *   data-sealed-key               — base64 sealed conn_key (viewer's copy)
 *   data-target-id                — ID of the parent status card to find
 *                                   [data-status-message-content] targets
 *
 * Writes decrypted plaintext to [data-status-message-content] elements within
 * the target status card.
 */
import { unsealContextKey, decryptWithKey, getPublicKey, unwrapConnKey } from "../crypto/session";

const DecryptStatusMessage = {
  async mounted() {
    await this.decrypt();
  },

  async updated() {
    await this.decrypt();
  },

  async decrypt() {
    const encrypted = this.el.dataset.encryptedStatusMessage;
    const sealedKey = this.el.dataset.sealedKey;
    if (!encrypted || !sealedKey) return;

    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this.decrypt(), { once: true });
      return;
    }

    try {
      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) return;

      const connKey = unwrapConnKey(rawKey);
      const plaintext = await decryptWithKey(encrypted, connKey);
      if (!plaintext) return;

      const targetId = this.el.dataset.targetId;
      const card = targetId ? document.getElementById(targetId) : this.el.parentElement;
      if (!card) return;

      const targets = card.querySelectorAll('[data-status-message-content="true"]');
      for (const target of targets) {
        target.textContent = plaintext;
        target.classList.remove("animate-pulse");
        target.className = "text-sm text-slate-600 dark:text-slate-300 leading-relaxed";
      }
    } catch (e) {
      // Browser-side decryption failed — server-rendered fallback preserved.
    }
  },
};

export default DecryptStatusMessage;
