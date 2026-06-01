import { getUserKey, decryptWithKey, getPublicKey } from "../crypto/session";

const DecryptJournalBook = {
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

      const bookId = this.el.dataset.bookId;
      const encTitle = this.el.dataset.encryptedTitle;
      const encDescription = this.el.dataset.encryptedDescription;

      if (encTitle) {
        const title = await decryptWithKey(encTitle, userKey);
        if (title) {
          this._applyToTargets(
            `[data-decrypt-journal-book-title="${bookId}"]`,
            title
          );
        }
      }

      if (encDescription) {
        const description = await decryptWithKey(encDescription, userKey);
        if (description) {
          this._applyToTargets(
            `[data-decrypt-journal-book-description="${bookId}"]`,
            description
          );
        }
      }
    } catch (e) {
      console.error("DecryptJournalBook: decryption failed:", e);
    }
  },

  _applyToTargets(selector, text) {
    const targets = document.querySelectorAll(selector);
    for (const el of targets) {
      el.textContent = text;
    }
  },
};

export default DecryptJournalBook;
