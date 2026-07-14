/**
 * MoodPickerHook — vanilla-JS emoji mood picker.
 *
 * Replaces the previous Alpine `<template x-for>` implementation, which broke
 * inside a LiveView form: every server re-render (e.g. the journal auto-save)
 * made morphdom walk Alpine's loop-generated nodes and re-evaluate their
 * bindings outside the `x-for` scope, flooding the console with "Can't find
 * variable: mood/category" and interfering with the form.
 *
 * This hook owns its own DOM (the element carries `phx-update="ignore"`), so
 * LiveView never diffs it after mount. Selection writes the chosen mood id to
 * the hidden input and dispatches a bubbling `input` event — that is what
 * drives the form's `phx-change` (and therefore the encrypted auto-save).
 *
 * Mood data and class helpers live on `window` (see ../mood_picker.js):
 *   window.moodPickerFilterCategories(search)
 *   window.moodPickerGetButtonClasses(moodId, currentValue)
 *   window.moodPickerGetLabelClasses(moodId, currentValue)
 *   window.moodPickerEmoji(moodId) / window.moodPickerLabel(moodId)
 *
 * All rendering uses textContent (never innerHTML for user/data strings), so
 * there is no XSS surface.
 */
const TRIGGER_BASE =
  "inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-teal-500/50 dark:focus:ring-offset-slate-800";
const TRIGGER_SELECTED =
  "bg-slate-100/80 dark:bg-slate-800/80 text-slate-700 dark:text-slate-300";
const TRIGGER_EMPTY =
  "bg-slate-100/50 dark:bg-slate-800/50 text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700/50";

const MoodPickerHook = {
  mounted() {
    this.input = this.el.querySelector('input[type="hidden"]');
    this.trigger = this.el.querySelector("[data-mp-trigger]");
    this.dropdown = this.el.querySelector("[data-mp-dropdown]");
    this.search = this.el.querySelector("[data-mp-search]");
    this.searchClear = this.el.querySelector("[data-mp-search-clear]");
    this.list = this.el.querySelector("[data-mp-list]");
    this.empty = this.el.querySelector("[data-mp-empty]");
    this.clearWrap = this.el.querySelector("[data-mp-clear-wrap]");
    this.clearBtn = this.el.querySelector("[data-mp-clear]");
    this.emojiEl = this.el.querySelector("[data-mp-emoji]");
    this.labelEl = this.el.querySelector("[data-mp-label]");
    this.chevron = this.el.querySelector("[data-mp-chevron]");

    this.value = this.input ? this.input.value : this.el.dataset.value || "";
    this.open = false;

    this._bind();
    this._renderTrigger();
    this._renderList();
  },

  destroyed() {
    this._unbind();
  },

  _bind() {
    this._onTrigger = () => (this.open ? this._close() : this._open());
    this.trigger.addEventListener("click", this._onTrigger);

    this._onSearch = () => {
      this._renderList();
      this._syncSearchClear();
    };
    this.search.addEventListener("input", this._onSearch);

    this._onSearchClear = () => {
      this.search.value = "";
      this._renderList();
      this._syncSearchClear();
      this.search.focus();
    };
    this.searchClear.addEventListener("click", this._onSearchClear);

    this._onListClick = (e) => {
      const btn = e.target.closest("[data-mp-id]");
      if (btn) this._select(btn.dataset.mpId);
    };
    this.list.addEventListener("click", this._onListClick);

    this._onClear = () => this._select("");
    this.clearBtn.addEventListener("click", this._onClear);

    // Keep in sync when something external writes the hidden input — notably
    // the DecryptJournalEntry hook restoring a saved mood on the edit form.
    this._onInputChange = () => {
      if (this.input.value !== this.value) {
        this.value = this.input.value;
        this._renderTrigger();
        this._renderList();
      }
    };
    this.input.addEventListener("input", this._onInputChange);

    this._onDocClick = (e) => {
      if (this.open && !this.el.contains(e.target)) this._close();
    };
    document.addEventListener("click", this._onDocClick, true);

    this._onEsc = (e) => {
      if (e.key === "Escape" && this.open) this._close();
    };
    document.addEventListener("keydown", this._onEsc);
  },

  _unbind() {
    this.trigger?.removeEventListener("click", this._onTrigger);
    this.search?.removeEventListener("input", this._onSearch);
    this.searchClear?.removeEventListener("click", this._onSearchClear);
    this.list?.removeEventListener("click", this._onListClick);
    this.clearBtn?.removeEventListener("click", this._onClear);
    this.input?.removeEventListener("input", this._onInputChange);
    document.removeEventListener("click", this._onDocClick, true);
    document.removeEventListener("keydown", this._onEsc);
  },

  _open() {
    this.open = true;
    this.dropdown.classList.remove("hidden");
    this.chevron?.classList.add("rotate-180");
    this._renderList();
    requestAnimationFrame(() => this.search.focus());
  },

  _close() {
    this.open = false;
    this.dropdown.classList.add("hidden");
    this.chevron?.classList.remove("rotate-180");
    this.search.value = "";
    this._syncSearchClear();
  },

  _select(id) {
    this.value = id;
    if (this.input) {
      this.input.value = id;
      // Bubbling input event drives the form's phx-change → encrypted autosave.
      this.input.dispatchEvent(new Event("input", { bubbles: true }));
    }
    this._renderTrigger();
    this._renderList();
    this._close();
  },

  _syncSearchClear() {
    if (!this.searchClear) return;
    this.searchClear.classList.toggle("hidden", this.search.value.length === 0);
  },

  _renderTrigger() {
    const has = !!this.value;
    this.trigger.className =
      TRIGGER_BASE + " " + (has ? TRIGGER_SELECTED : TRIGGER_EMPTY);

    if (this.emojiEl) {
      this.emojiEl.textContent = has ? window.moodPickerEmoji(this.value) : "😊";
      this.emojiEl.classList.toggle("opacity-60", !has);
    }
    if (this.labelEl) {
      this.labelEl.textContent = has
        ? window.moodPickerLabel(this.value)
        : "How are you feeling?";
    }
    if (this.clearWrap) this.clearWrap.classList.toggle("hidden", !has);
    this.trigger.setAttribute(
      "aria-label",
      has ? `Change mood: ${window.moodPickerLabel(this.value)}` : "Select mood"
    );
  },

  _renderList() {
    const cats = window.moodPickerFilterCategories(this.search.value);
    this.list.replaceChildren();

    const noResults = cats.length === 0 && this.search.value.trim().length > 0;
    this.empty?.classList.toggle("hidden", !noResults);
    this.list.classList.toggle("hidden", noResults);
    if (noResults) return;

    const frag = document.createDocumentFragment();

    for (const cat of cats) {
      const section = document.createElement("div");
      section.className = "space-y-2";

      const heading = document.createElement("div");
      heading.className =
        "text-[11px] font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400 px-1";
      heading.textContent = cat.name;
      section.appendChild(heading);

      const grid = document.createElement("div");
      grid.className = "flex flex-wrap gap-1.5 sm:gap-2";

      for (const mood of cat.moods) {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.dataset.mpId = mood.id;
        btn.title = mood.label;
        btn.className = window.moodPickerGetButtonClasses(mood.id, this.value);

        const emoji = document.createElement("span");
        emoji.className = "text-lg sm:text-xl leading-none flex-shrink-0";
        emoji.textContent = mood.emoji;
        btn.appendChild(emoji);

        const label = document.createElement("span");
        label.className = window.moodPickerGetLabelClasses(mood.id, this.value);
        label.textContent = mood.label;
        btn.appendChild(label);

        grid.appendChild(btn);
      }

      section.appendChild(grid);
      frag.appendChild(section);
    }

    // Space sections apart without relying on a wrapper the loop can't see.
    const wrapper = document.createElement("div");
    wrapper.className = "space-y-3 sm:space-y-4";
    wrapper.appendChild(frag);
    this.list.appendChild(wrapper);
  },
};

export default MoodPickerHook;
