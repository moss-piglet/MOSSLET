import data from "../../vendor/@emoji-mart/data";
import { Picker } from "../../vendor/emoji-mart";

const ReplyEmojiPicker = {
  mounted() {
    this.pickerInstance = null;
    this.isPickerVisible = false;
    this.targetTextareaId = this.el.dataset.targetTextarea;

    if (!this.el.hasAttribute("aria-label")) {
      this.el.setAttribute("aria-label", "Open emoji picker");
    }
    this.el.setAttribute("aria-haspopup", "dialog");
    this.el.setAttribute("aria-expanded", "false");

    this.handleClickOutside = (event) => {
      if (
        this.pickerInstance &&
        !this.el.contains(event.target) &&
        !this.pickerContainer?.contains(event.target)
      ) {
        this.hidePicker();
      }
    };

    this.handleKeyDown = (event) => {
      if (event.key === "Escape" && this.isPickerVisible) {
        this.hidePicker();
      }
    };

    this.handleThemeChange = (event) => {
      if (this.isPickerVisible && this.pickerInstance) {
        this.hidePicker();
        setTimeout(() => this.showPicker(), 100);
      }
    };

    this.el.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      this.togglePicker();
    });

    document.addEventListener("keydown", this.handleKeyDown);
    document.addEventListener("phx:set-theme", this.handleThemeChange);
  },

  destroyed() {
    this.hidePicker();
    document.removeEventListener("click", this.handleClickOutside);
    document.removeEventListener("keydown", this.handleKeyDown);
    document.removeEventListener("phx:set-theme", this.handleThemeChange);
  },

  togglePicker() {
    if (this.isPickerVisible) {
      this.hidePicker();
    } else {
      this.showPicker();
    }
  },

  showPicker() {
    if (this.pickerInstance) {
      this.hidePicker();
    }

    const textarea = document.getElementById(this.targetTextareaId);
    if (!textarea) return;

    this.el.setAttribute("aria-expanded", "true");

    const pickerContainer = document.createElement("div");
    pickerContainer.className = "fixed z-[9999]";
    pickerContainer.setAttribute("role", "dialog");
    pickerContainer.setAttribute("aria-label", "Emoji picker");
    pickerContainer.style.opacity = "0";
    pickerContainer.style.transform = "scale(0.95)";
    pickerContainer.style.transition =
      "opacity 200ms ease-out, transform 200ms ease-out";

    const buttonRect = this.el.getBoundingClientRect();
    const spaceBelow = window.innerHeight - buttonRect.bottom;

    if (spaceBelow >= 450) {
      pickerContainer.style.top = `${buttonRect.bottom + 8}px`;
    } else {
      pickerContainer.style.top = `${buttonRect.top - 450 - 8}px`;
    }

    let leftPos = buttonRect.left;
    if (leftPos + 352 > window.innerWidth) {
      leftPos = window.innerWidth - 352 - 16;
    }
    pickerContainer.style.left = `${Math.max(16, leftPos)}px`;

    document.body.appendChild(pickerContainer);

    const documentTheme = document.documentElement.getAttribute("data-theme");
    const isDark =
      documentTheme === "dark" ||
      (documentTheme === "system" &&
        window.matchMedia("(prefers-color-scheme: dark)").matches);
    const theme = isDark ? "dark" : "light";

    this.pickerInstance = new Picker({
      data: data,
      parent: pickerContainer,
      theme: theme,
      emojiButtonColors: ["oklch(69.6% 0.17 162.48)"],
      onEmojiSelect: (emoji) => {
        this.insertEmoji(emoji, textarea);
        this.hidePicker();
      },
    });

    setTimeout(() => {
      this.applyLiquidMetalStyling(theme);
      this.fixA11yIssues();
      setTimeout(() => {
        if (pickerContainer) {
          pickerContainer.style.opacity = "1";
          pickerContainer.style.transform = "scale(1)";
          this.focusPickerSearch();
        }
      }, 50);
    }, 50);

    this.pickerContainer = pickerContainer;
    this.isPickerVisible = true;

    setTimeout(() => {
      document.addEventListener("click", this.handleClickOutside);
    }, 100);
  },

  hidePicker() {
    if (this.pickerContainer) {
      this.pickerContainer.remove();
      this.pickerContainer = null;
    }
    this.pickerInstance = null;
    this.isPickerVisible = false;
    this.el.setAttribute("aria-expanded", "false");
    document.removeEventListener("click", this.handleClickOutside);
    this.el.focus();
  },

  focusPickerSearch() {
    if (!this.pickerContainer) return;
    const emojiMart = this.pickerContainer.querySelector("em-emoji-picker");
    if (!emojiMart?.shadowRoot) {
      setTimeout(() => this.focusPickerSearch(), 50);
      return;
    }
    const searchInput = emojiMart.shadowRoot.querySelector(".search input");
    if (searchInput) {
      searchInput.focus();
    }
  },

  fixA11yIssues() {
    if (!this.pickerContainer) return;
    const emojiMart = this.pickerContainer.querySelector("em-emoji-picker");
    if (!emojiMart?.shadowRoot) {
      setTimeout(() => this.fixA11yIssues(), 50);
      return;
    }
    const scrollRegion = emojiMart.shadowRoot.querySelector(".scroll");
    if (scrollRegion && !scrollRegion.hasAttribute("tabindex")) {
      scrollRegion.setAttribute("tabindex", "0");
    }
    const nav = emojiMart.shadowRoot.querySelector("nav");
    if (nav) {
      nav.setAttribute("role", "tablist");
      nav.querySelectorAll("button").forEach((btn) => {
        btn.setAttribute("role", "tab");
        if (!btn.hasAttribute("aria-selected")) {
          btn.setAttribute("aria-selected", "false");
        }
      });
    }
    emojiMart.shadowRoot.querySelectorAll("button[aria-posinset]").forEach((btn) => {
      btn.removeAttribute("aria-posinset");
      btn.removeAttribute("aria-setsize");
    });
  },

  applyLiquidMetalStyling(theme) {
    if (!this.pickerInstance || !this.pickerContainer) return;

    const emojiMart = this.pickerContainer.querySelector("em-emoji-picker");
    if (!emojiMart || !emojiMart.shadowRoot) {
      setTimeout(() => this.applyLiquidMetalStyling(theme), 20);
      return;
    }

    const liquidMetalCSS = `
      <style>
        * { transition: none !important; }
        
        :host {
          --border-radius: 16px !important;
          --font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif !important;
          border-radius: 16px !important;
          overflow: hidden !important;
          backdrop-filter: blur(16px) !important;
          ${
            theme === "dark"
              ? `
            --em-rgb-background: 30, 41, 59 !important;
            --em-rgb-input: 15, 23, 42 !important;
            --em-color-border: rgba(148, 163, 184, 0.2) !important;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(148, 163, 184, 0.1) !important;
          `
              : `
            --em-rgb-background: 255, 255, 255 !important;
            --em-rgb-input: 248, 250, 252 !important;
            --em-color-border: rgba(148, 163, 184, 0.2) !important;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(148, 163, 184, 0.1) !important;
          `
          }
        }
        
        #root {
          border-radius: 16px !important;
          ${theme === "dark" ? "background: rgba(30, 41, 59, 0.95) !important;" : "background: rgba(255, 255, 255, 0.95) !important;"}
        }
        
        .search input {
          border-radius: 12px !important;
          border: 1px solid var(--em-color-border) !important;
          ${
            theme === "dark"
              ? "background: rgba(15, 23, 42, 0.8) !important; color: rgb(226, 232, 240) !important;"
              : "background: rgba(248, 250, 252, 0.8) !important; color: rgb(30, 41, 59) !important;"
          }
        }
        
        .search input:focus {
          border-color: rgba(20, 184, 166, 0.5) !important;
          box-shadow: 0 0 0 3px rgba(20, 184, 166, 0.1) !important;
          outline: none !important;
        }
        
        .nav button {
          border-radius: 10px !important;
          transition: all 200ms ease-out !important;
        }
        
        .nav button:hover {
          ${theme === "dark" ? "background: rgba(20, 184, 166, 0.1) !important;" : "background: rgba(20, 184, 166, 0.05) !important;"}
          transform: translateY(-1px) !important;
        }
        
        .nav button[aria-selected="true"] {
          background: linear-gradient(135deg, rgba(20, 184, 166, 0.15), rgba(16, 185, 129, 0.15)) !important;
          ${theme === "dark" ? "color: rgb(94, 234, 212) !important;" : "color: rgb(13, 148, 136) !important;"}
        }
        
        .emoji button {
          border-radius: 8px !important;
          transition: all 150ms ease-out !important;
        }
        
        .emoji button:hover {
          transform: scale(1.1) !important;
          ${theme === "dark" ? "background: rgba(20, 184, 166, 0.1) !important;" : "background: rgba(20, 184, 166, 0.05) !important;"}
          box-shadow: 0 4px 12px rgba(20, 184, 166, 0.15) !important;
        }
        
        .sticky {
          ${
            theme === "dark"
              ? "background: rgba(30, 41, 59, 0.95) !important; color: rgb(148, 163, 184) !important;"
              : "background: rgba(255, 255, 255, 0.95) !important; color: rgb(71, 85, 105) !important;"
          }
          backdrop-filter: blur(8px) !important;
          font-weight: 600 !important;
          font-size: 13px !important;
          text-transform: uppercase !important;
          letter-spacing: 0.05em !important;
          padding: 8px 12px !important;
        }
        
        .scroll, .category {
          ${theme === "dark" ? "background: rgba(30, 41, 59, 0.95) !important;" : "background: rgba(255, 255, 255, 0.95) !important;"}
        }
        
        ::-webkit-scrollbar { width: 8px !important; }
        ::-webkit-scrollbar-track { background: transparent !important; }
        ::-webkit-scrollbar-thumb {
          ${theme === "dark" ? "background: rgba(148, 163, 184, 0.3) !important;" : "background: rgba(148, 163, 184, 0.4) !important;"}
          border-radius: 4px !important;
        }
        ::-webkit-scrollbar-thumb:hover { background: rgba(20, 184, 166, 0.5) !important; }
        
        * { transition: all 150ms ease-out !important; }
      </style>
    `;

    const existingStyle = emojiMart.shadowRoot.querySelector("#liquid-metal-style");
    if (existingStyle) existingStyle.remove();

    const styleElement = document.createElement("div");
    styleElement.id = "liquid-metal-style";
    styleElement.innerHTML = liquidMetalCSS;

    const firstChild = emojiMart.shadowRoot.firstChild;
    if (firstChild) {
      emojiMart.shadowRoot.insertBefore(styleElement, firstChild);
    } else {
      emojiMart.shadowRoot.appendChild(styleElement);
    }
  },

  insertEmoji(emoji, textarea) {
    const startPos = textarea.selectionStart;
    const endPos = textarea.selectionEnd;
    const textBefore = textarea.value.substring(0, startPos);
    const textAfter = textarea.value.substring(endPos);

    const newValue = textBefore + emoji.native + textAfter;
    textarea.value = newValue;

    const newCursorPos = startPos + emoji.native.length;
    textarea.setSelectionRange(newCursorPos, newCursorPos);

    textarea.focus();
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
    textarea.dispatchEvent(new Event("change", { bubbles: true }));
  },
};

export default ReplyEmojiPicker;
