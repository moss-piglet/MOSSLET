/**
 * ExtractedEntryFormHook — browser-side encryption for digitized journal entries (ZK write path).
 *
 * Intercepts the extracted entry form submit, encrypts title and body with
 * user_key, and pushes `save_extracted_entry_zk` event. The server stores
 * only encrypted blobs — plaintext never travels as form params.
 *
 * Data attributes on the form:
 *   data-sealed-user-key — sealed user_key (from user.user_key)
 */
import { encryptWithKey, getUserKey, getPublicKey } from "../crypto/session";

const ExtractedEntryFormHook = {
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
      console.error("ExtractedEntryFormHook: failed to unseal user key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._userKey) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit().catch((err) => {
      console.error(
        "ExtractedEntryFormHook: encryption failed, falling back:",
        err,
      );
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit() {
    const titleInput = this.el.querySelector('input[name="extracted[title]"]');
    const bodyTextarea = this.el.querySelector(
      'textarea[name="extracted[body]"]',
    );
    const dateInput = this.el.querySelector('input[name="extracted[entry_date]"]');
    const bookSelect = this.el.querySelector('select[name="extracted[book_id]"]');

    const title = titleInput?.value?.trim() || "";
    const body = bodyTextarea?.value?.trim() || "";

    const [encTitle, encBody] = await Promise.all([
      title ? encryptWithKey(title, this._userKey) : null,
      body ? encryptWithKey(body, this._userKey) : null,
    ]);

    const wordCount = body
      .split(/\s+/)
      .filter((w) => w.length > 0).length;

    this.pushEvent("save_extracted_entry_zk", {
      encrypted_title: encTitle,
      encrypted_body: encBody,
      word_count: wordCount,
      entry_date: dateInput?.value || "",
      book_id: bookSelect?.value || "",
    });
  },
};

export default ExtractedEntryFormHook;
