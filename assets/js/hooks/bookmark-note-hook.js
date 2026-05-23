/**
 * BookmarkNoteHook — enhances the bookmark button with optional notes input.
 *
 * When the user clicks to bookmark (non-bookmarked state), shows a small
 * dropdown form for adding notes. Notes are encrypted browser-side with
 * the cached post_key for non-public posts (ZK write path).
 *
 * Data attributes:
 *   data-post-id      — post UUID
 *   data-bookmarked   — "true"/"false"
 *   data-is-public    — "true"/"false" (public posts use server-side encryption)
 */
import { getCachedPostKey } from "../crypto/session";
import { encryptSecretboxString } from "../crypto/nacl";

const BookmarkNoteHook = {
  mounted() {
    this._dropdown = null;
    this._saving = false;
    this._clickHandler = (e) => this._handleClick(e);
    this.el.addEventListener("click", this._clickHandler);
  },

  updated() {
    if (this._dropdown && this.el.dataset.bookmarked === "true") {
      this._closeDropdown();
    }
  },

  destroyed() {
    this._closeDropdown();
    this.el.removeEventListener("click", this._clickHandler);
  },

  _handleClick(e) {
    if (this._saving) return;

    const bookmarked = this.el.dataset.bookmarked === "true";
    if (bookmarked) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    if (this._dropdown) {
      this._closeDropdown();
      return;
    }

    this._showDropdown();
  },

  _showDropdown() {
    const postId = this.el.dataset.postId;

    const container = document.createElement("div");
    container.id = `bookmark-notes-dropdown-${postId}`;
    container.className =
      "absolute right-0 z-50 w-72 p-3 rounded-xl " +
      "bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 " +
      "shadow-lg shadow-slate-900/10 dark:shadow-slate-900/30 " +
      "animate-in fade-in-0 slide-in-from-bottom-2 duration-200";

    container.addEventListener("mousedown", (ev) => ev.stopPropagation());
    container.addEventListener("click", (ev) => ev.stopPropagation());

    const textarea = document.createElement("textarea");
    textarea.id = `bookmark-notes-input-${postId}`;
    textarea.placeholder = "Add a note (optional)...";
    textarea.maxLength = 10000;
    textarea.rows = 3;
    textarea.className =
      "w-full px-3 py-2 text-sm rounded-lg resize-none " +
      "bg-slate-50 dark:bg-slate-900/50 " +
      "border border-slate-200 dark:border-slate-700 " +
      "text-slate-700 dark:text-slate-300 " +
      "placeholder-slate-400 dark:placeholder-slate-500 " +
      "focus:ring-2 focus:ring-amber-500/50 focus:border-amber-400 " +
      "focus:outline-none transition-colors";

    const btnRow = document.createElement("div");
    btnRow.className = "flex items-center justify-between gap-2 mt-2";

    const saveBtn = document.createElement("button");
    saveBtn.type = "button";
    saveBtn.textContent = "Save bookmark";
    saveBtn.className =
      "flex-1 px-3 py-1.5 text-xs font-medium rounded-lg " +
      "bg-amber-500 hover:bg-amber-600 text-white " +
      "transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-amber-500/50";

    const skipBtn = document.createElement("button");
    skipBtn.type = "button";
    skipBtn.textContent = "No note";
    skipBtn.className =
      "px-3 py-1.5 text-xs font-medium rounded-lg " +
      "text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700 " +
      "transition-colors duration-200 focus:outline-none";

    btnRow.appendChild(skipBtn);
    btnRow.appendChild(saveBtn);
    container.appendChild(textarea);
    container.appendChild(btnRow);

    const wrapper = this.el.parentElement;
    if (wrapper) {
      wrapper.style.position = "relative";
    }

    const rect = this.el.getBoundingClientRect();
    const wrapperRect = wrapper ? wrapper.getBoundingClientRect() : rect;
    container.style.bottom = `${wrapperRect.bottom - rect.top + 8}px`;
    container.style.right = "0";

    if (wrapper) {
      wrapper.appendChild(container);
    } else {
      this.el.parentElement.appendChild(container);
    }

    this._dropdown = container;
    textarea.focus();

    saveBtn.addEventListener("click", () => this._save(postId, textarea));
    skipBtn.addEventListener("click", () => this._skip(postId));

    this._outsideHandler = (ev) => {
      if (
        !container.contains(ev.target) &&
        !this.el.contains(ev.target)
      ) {
        this._closeDropdown();
      }
    };
    requestAnimationFrame(() => {
      document.addEventListener("mousedown", this._outsideHandler);
    });
  },

  async _save(postId, textarea) {
    if (this._saving) return;
    this._saving = true;

    const notes = textarea.value.trim();

    if (!notes) {
      this._skip(postId);
      return;
    }

    const isPublic = this.el.dataset.isPublic === "true";
    let encrypted = notes;

    if (!isPublic) {
      const postKey = getCachedPostKey(postId);
      if (postKey) {
        try {
          encrypted = await encryptSecretboxString(notes, postKey);
        } catch {
          this.pushEvent("bookmark_post", { id: postId });
          this._closeDropdown();
          this._saving = false;
          return;
        }
      }
    }

    this.pushEvent("bookmark_post_with_notes", {
      id: postId,
      encrypted_notes: encrypted,
    });
    this._closeDropdown();
    this._saving = false;
  },

  _skip(postId) {
    if (this._saving) return;
    this._saving = true;

    this._closeDropdown();
    this.pushEvent("bookmark_post", { id: postId });
    this._saving = false;
  },

  _closeDropdown() {
    if (this._outsideHandler) {
      document.removeEventListener("mousedown", this._outsideHandler);
      this._outsideHandler = null;
    }
    if (this._dropdown) {
      this._dropdown.remove();
      this._dropdown = null;
    }
  },
};

export default BookmarkNoteHook;
