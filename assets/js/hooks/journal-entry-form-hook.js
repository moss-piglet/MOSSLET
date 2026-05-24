/**
 * JournalEntryFormHook — browser-side journal entry encryption (ZK write path).
 *
 * Intercepts the journal form submit, encrypts title/body/mood with the
 * user_key, and pushes a `save_zk` event with ciphertext. The server
 * receives only encrypted blobs — it never sees plaintext journal content.
 *
 * Also handles auto-save: when the user types, the hook starts a 3-second
 * debounce timer. On fire, it encrypts current form content and pushes
 * `auto_save_zk` to the server. This replaces the server-side auto-save
 * that would have sent plaintext.
 *
 * Data attributes on the form:
 *   data-sealed-user-key — sealed user_key (from user.user_key)
 */
import { encryptWithKey, getUserKey, getPublicKey } from "../crypto/session";

const AUTO_SAVE_DELAY_MS = 3000;

const JournalEntryFormHook = {
  mounted() {
    this._userKey = null;
    this._autoSaveTimer = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
    this.el.addEventListener("input", () => this._scheduleAutoSave());
  },

  destroyed() {
    this._clearAutoSave();
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
      console.error("JournalEntryFormHook: failed to unseal user key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._userKey) return;

    e.preventDefault();
    e.stopImmediatePropagation();
    this._clearAutoSave();

    this._encryptAndPush("save_zk").catch((err) => {
      console.error(
        "JournalEntryFormHook: encryption failed, falling back:",
        err,
      );
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  _scheduleAutoSave() {
    if (!this._userKey) return;
    this._clearAutoSave();
    this._autoSaveTimer = setTimeout(() => {
      this._encryptAndPush("auto_save_zk").catch((err) => {
        console.error("JournalEntryFormHook: auto-save encryption failed:", err);
      });
    }, AUTO_SAVE_DELAY_MS);
  },

  _clearAutoSave() {
    if (this._autoSaveTimer) {
      clearTimeout(this._autoSaveTimer);
      this._autoSaveTimer = null;
    }
  },

  async _encryptAndPush(eventName) {
    const title =
      this.el.querySelector('input[name="journal_entry[title]"]')?.value || "";
    const body =
      this.el.querySelector('textarea[name="journal_entry[body]"]')?.value ||
      "";
    const mood =
      this.el.querySelector('input[name="journal_entry[mood]"]')?.value || "";

    const [encTitle, encBody, encMood] = await Promise.all([
      title.trim() ? encryptWithKey(title, this._userKey) : null,
      body.trim() ? encryptWithKey(body, this._userKey) : null,
      mood.trim() ? encryptWithKey(mood, this._userKey) : null,
    ]);

    const wordCount = body
      .trim()
      .split(/\s+/)
      .filter((w) => w.length > 0).length;

    this.pushEvent(eventName, {
      encrypted_title: encTitle,
      encrypted_body: encBody,
      encrypted_mood: encMood,
      word_count: wordCount,
      title_hash: title.trim() ? title.toLowerCase() : null,
    });
  },
};

export default JournalEntryFormHook;
