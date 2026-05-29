/**
 * JournalBookFormHook — browser-side journal book title/description encryption (ZK write path).
 *
 * Intercepts the book form submit, encrypts title and description with the
 * user_key, and pushes a `save_book_zk` event with ciphertext. The server
 * stores only encrypted blobs — it never sees plaintext book metadata.
 *
 * Falls through to normal server-side form submit if:
 *   - Keys are not yet available (WASM not loaded, sessionStorage empty)
 *   - Encryption fails for any reason
 *
 * Data attributes on the form:
 *   data-sealed-user-key — sealed user_key (from user.user_key)
 */
import { encryptWithKey, getUserKey, getPublicKey } from "../crypto/session";

const JournalBookFormHook = {
  mounted() {
    this._userKey = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    if (!this._userKey) this._unsealKey();
  },

  async _unsealKey() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), {
        once: true,
      });
      return;
    }

    const sealedKey = this.el.dataset.sealedUserKey;
    if (!sealedKey) return;

    try {
      this._userKey = await getUserKey(sealedKey);
    } catch (e) {
      console.error("JournalBookFormHook: failed to unseal user key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._userKey) return;

    const titleInput = this.el.querySelector(
      'input[name="journal_book[title]"]',
    );
    const title = titleInput?.value?.trim();
    if (!title) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit().catch((err) => {
      console.error(
        "JournalBookFormHook: encryption failed, falling back:",
        err,
      );
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit() {
    const titleInput = this.el.querySelector(
      'input[name="journal_book[title]"]',
    );
    const descInput = this.el.querySelector(
      'textarea[name="journal_book[description]"]',
    );

    const title = titleInput?.value?.trim() || "";
    const description = descInput?.value?.trim() || "";

    const encryptedTitle = await encryptWithKey(title, this._userKey);
    const encryptedDescription = description
      ? await encryptWithKey(description, this._userKey)
      : null;

    const colorInput =
      this.el.querySelector('input[name="journal_book[cover_color]"]:checked');
    const coverColor = colorInput?.value || "emerald";

    this.pushEventTo(this.el, "save_book_zk", {
      encrypted_title: encryptedTitle,
      encrypted_description: encryptedDescription,
      cover_color: coverColor,
    });
  },
};

export default JournalBookFormHook;
