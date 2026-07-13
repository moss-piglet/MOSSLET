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
      const isForm = this.el.dataset.form === "true";

      let decryptedTitle = null;
      let decryptedDescription = null;

      if (encTitle) {
        decryptedTitle = await decryptWithKey(encTitle, userKey);
        if (decryptedTitle && !isForm) {
          this._applyToTargets(
            `[data-decrypt-journal-book-title="${bookId}"]`,
            decryptedTitle
          );
        }
      }

      if (encDescription) {
        decryptedDescription = await decryptWithKey(encDescription, userKey);
        if (decryptedDescription && !isForm) {
          this._applyToTargets(
            `[data-decrypt-journal-book-description="${bookId}"]`,
            decryptedDescription
          );
        }
      }

      if (isForm) {
        this._applyFormFields(bookId, decryptedTitle, decryptedDescription);
      }
    } catch (e) {
      console.error("DecryptJournalBook: decryption failed:", e);
    }
  },

  _applyFormFields(bookId, title, description) {
    if (title) {
      const titleInputs = document.querySelectorAll(
        `[data-decrypt-journal-book-form-title="${bookId}"]`
      );
      for (const el of titleInputs) {
        if (!el.dataset.decryptApplied) {
          el.value = title;
          el.dataset.decryptApplied = "1";
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }
      }
    }

    if (description) {
      const descInputs = document.querySelectorAll(
        `[data-decrypt-journal-book-form-description="${bookId}"]`
      );
      for (const el of descInputs) {
        if (!el.dataset.decryptApplied) {
          el.value = description;
          el.dataset.decryptApplied = "1";
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }
      }
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
