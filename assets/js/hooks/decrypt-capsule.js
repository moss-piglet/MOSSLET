/**
 * DecryptCapsule — browser-side time-capsule decryption (ZK read path).
 *
 * Unseals the user_key and decrypts the letter's title/body ciphertext,
 * then writes the plaintext into DOM targets. The server never sees the
 * decrypted words. Used both for reading a delivered letter and for
 * previewing titles in the mailbox list.
 *
 * Data attributes on the hook element:
 *   data-sealed-user-key   — sealed user_key
 *   data-capsule-id        — capsule id (scopes the target selectors)
 *   data-encrypted-title   — ciphertext (optional)
 *   data-encrypted-body    — ciphertext (optional; delivered capsules only)
 *
 * Targets (anywhere in the document, scoped by capsule id):
 *   [data-decrypt-capsule-title="<id>"]      — textContent
 *   [data-decrypt-capsule-body-prose="<id>"] — innerHTML (markdown)
 *   [data-decrypt-capsule-body="<id>"]       — textContent
 */
import { getUserKey, decryptWithKey, getPublicKey } from "../crypto/session";
import { renderMarkdown } from "../utils/render-markdown";

const DecryptCapsule = {
  async mounted() {
    this._boundDecrypt = () => this.decrypt();

    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._init(), {
        once: true,
      });
      return;
    }
    await this._init();
  },

  async _init() {
    await this.decrypt();
    document.addEventListener("phx:update", this._boundDecrypt);
  },

  destroyed() {
    document.removeEventListener("phx:update", this._boundDecrypt);
  },

  async decrypt() {
    const sealedKey = this.el.dataset.sealedUserKey;
    if (!sealedKey) return;

    try {
      const userKey = await getUserKey(sealedKey);
      if (!userKey) return;

      const capsuleId = this.el.dataset.capsuleId;
      const encTitle = this.el.dataset.encryptedTitle;
      const encBody = this.el.dataset.encryptedBody;

      if (encTitle) {
        const title = await decryptWithKey(encTitle, userKey);
        if (title) {
          this._applyText(
            `[data-decrypt-capsule-title="${capsuleId}"]`,
            title,
          );
        }
      }

      if (encBody) {
        const body = await decryptWithKey(encBody, userKey);
        if (body) this._applyBody(capsuleId, body);
      }
    } catch (e) {
      console.error("DecryptCapsule: decryption failed:", e);
    }
  },

  _applyText(selector, text) {
    for (const el of document.querySelectorAll(selector)) {
      if (el.classList.contains("privacy-placeholder")) continue;
      el.textContent = text;
    }
  },

  _applyBody(capsuleId, body) {
    for (const el of document.querySelectorAll(
      `[data-decrypt-capsule-body-prose="${capsuleId}"]`,
    )) {
      if (el.classList.contains("privacy-placeholder")) continue;
      el.innerHTML = renderMarkdown(body);
    }

    for (const el of document.querySelectorAll(
      `[data-decrypt-capsule-body="${capsuleId}"]`,
    )) {
      if (el.classList.contains("privacy-placeholder")) continue;
      el.textContent = body;
    }
  },
};

export default DecryptCapsule;
