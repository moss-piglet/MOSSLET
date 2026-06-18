/**
 * OrgFileSearch — client-side filename search for the org-dash "Files across
 * your circles" overview (#229a).
 *
 * Filenames are zero-knowledge: the server only ever holds ciphertext, and the
 * plaintext name exists ONLY in the browser after the DecryptSharedFileName
 * hook fills each row's `[data-shared-filename]` element. Searching by name
 * therefore MUST happen here, in the browser — never server-side.
 *
 * This hook lives on the overview <section>. It reads the search box, hides
 * non-matching file rows (and any circle group with no visible rows), keeps a
 * live count, and shows an empty state. Sorting is handled server-side (it only
 * uses server-visible metadata: upload time + byte size).
 *
 * Markup it expects within `this.el`:
 *   [data-file-search]        — the search <input>
 *   [data-file-search-clear]  — the clear button (shown only when query present)
 *   [data-file-count]         — span filled with the result count
 *   [data-file-empty]         — empty-state container (toggled hidden)
 *   [data-file-empty-query]   — span filled with the current query text
 *   [data-file-group]         — each circle block wrapper
 *   [data-file-tier]          — each classification tier wrapper (#229b)
 *   [data-file-row]           — each file <li>
 *   [data-shared-filename]    — (within a row) the decrypted filename text
 */
const OrgFileSearch = {
  mounted() {
    this._input = this.el.querySelector("[data-file-search]");
    this._clear = this.el.querySelector("[data-file-search-clear]");
    this._count = this.el.querySelector("[data-file-count]");
    this._empty = this.el.querySelector("[data-file-empty]");
    this._emptyQuery = this.el.querySelector("[data-file-empty-query]");

    this._onInput = () => this._apply();
    if (this._input) this._input.addEventListener("input", this._onInput);

    this._onClear = () => {
      if (this._input) this._input.value = "";
      this._apply();
      this._input?.focus();
    };
    if (this._clear) this._clear.addEventListener("click", this._onClear);

    // Filenames decrypt asynchronously and rows can be re-rendered on realtime
    // file updates. Re-apply whenever the subtree changes (debounced via rAF).
    this._observer = new MutationObserver(() => this._scheduleApply());
    this._observe();

    this._apply();
  },

  updated() {
    this._apply();
  },

  destroyed() {
    if (this._observer) this._observer.disconnect();
    if (this._input && this._onInput) {
      this._input.removeEventListener("input", this._onInput);
    }
    if (this._clear && this._onClear) {
      this._clear.removeEventListener("click", this._onClear);
    }
  },

  _observe() {
    if (!this._observer) return;
    this._observer.observe(this.el, {
      subtree: true,
      childList: true,
      characterData: true,
    });
  },

  _scheduleApply() {
    if (this._raf) return;
    this._raf = requestAnimationFrame(() => {
      this._raf = null;
      this._apply();
    });
  },

  _apply() {
    // Pause observation so our own DOM writes don't retrigger the observer.
    if (this._observer) this._observer.disconnect();

    const query = (this._input?.value || "").trim().toLowerCase();
    const rows = this.el.querySelectorAll("[data-file-row]");
    const total = rows.length;
    let visible = 0;

    rows.forEach((row) => {
      const nameEl = row.querySelector("[data-shared-filename]");
      const name = (nameEl?.textContent || "").toLowerCase();
      const match = query === "" || name.includes(query);
      if (row.hidden === match) row.hidden = !match;
      if (match) visible += 1;
    });

    this.el.querySelectorAll("[data-file-group]").forEach((group) => {
      const anyVisible = group.querySelector("[data-file-row]:not([hidden])");
      const hide = !anyVisible;
      if (group.hidden !== hide) group.hidden = hide;
    });

    // Hide a whole tier (#229b: "Departments & Teams" / "Community circles"),
    // heading included, when none of its circle groups have a visible row.
    this.el.querySelectorAll("[data-file-tier]").forEach((tier) => {
      const anyVisible = tier.querySelector("[data-file-group]:not([hidden])");
      const hide = !anyVisible;
      if (tier.hidden !== hide) tier.hidden = hide;
    });

    if (this._clear) this._clear.hidden = query === "";

    if (this._count) {
      this._count.textContent =
        query === ""
          ? `${total} file${total === 1 ? "" : "s"}`
          : `Showing ${visible} of ${total} file${total === 1 ? "" : "s"}`;
    }

    if (this._empty) {
      this._empty.hidden = !(total > 0 && visible === 0);
      if (this._emptyQuery && this._input) {
        this._emptyQuery.textContent = this._input.value.trim();
      }
    }

    this._observe();
  },
};

export default OrgFileSearch;
