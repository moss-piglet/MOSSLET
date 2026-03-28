import {
  encryptDmMessage,
  decryptDmMessage,
  decryptDmKey,
} from "../crypto/nacl";

import emojiData from "../../vendor/@emoji-mart/data";
import { Picker } from "../../vendor/emoji-mart";
import { fixEmojiPickerA11y } from "./emoji-picker-a11y";

function getComposerEl() {
  return document.querySelector("#conversation-composer");
}

async function getConversationKey() {
  const composerEl = getComposerEl();
  if (!composerEl) return null;

  const encryptedConvKey = composerEl.dataset.conversationKey;
  const sessionKey = composerEl.dataset.sessionKey;
  const encryptedPrivateKey = composerEl.dataset.encryptedPrivateKey;
  const userPublicKey = composerEl.dataset.userPublicKey;

  if (
    !sessionKey ||
    !encryptedPrivateKey ||
    !encryptedConvKey ||
    !userPublicKey
  ) {
    return null;
  }

  try {
    const { decryptPrivateKey } = await import("../crypto/nacl");
    const privateKey = await decryptPrivateKey(encryptedPrivateKey, sessionKey);
    return await decryptDmKey(encryptedConvKey, userPublicKey, privateKey);
  } catch (e) {
    console.error("Failed to decrypt conversation key for reactions:", e);
    return null;
  }
}

const QUICK_EMOJIS = ["❤️", "👍", "😂", "😮", "😢", "🙏"];

const MessageReactions = {
  mounted() {
    this._decryptReactions();
    this._setupQuickReactBar();
  },

  updated() {
    this._decryptReactions();
    this._setupQuickReactBar();
  },

  destroyed() {
    this._closeQuickReactBar();
    this._closeFullPicker();
  },

  _setupQuickReactBar() {
    const reactBtn = this.el.querySelector("[data-react-trigger]");
    if (!reactBtn) return;

    if (reactBtn._bound) return;
    reactBtn._bound = true;

    reactBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      this._toggleQuickReactBar();
    });
  },

  _toggleQuickReactBar() {
    const existing = this.el.querySelector(".quick-react-bar");
    if (existing) {
      this._closeQuickReactBar();
      return;
    }

    this._closeFullPicker();

    const reactBtn = this.el.querySelector("[data-react-trigger]");
    if (!reactBtn) return;

    const bar = document.createElement("div");
    bar.className = "quick-react-bar";

    const isDark =
      document.documentElement.getAttribute("data-theme") === "dark" ||
      (document.documentElement.getAttribute("data-theme") === "system" &&
        window.matchMedia("(prefers-color-scheme: dark)").matches);

    Object.assign(bar.style, {
      position: "absolute",
      bottom: "100%",
      left: "0",
      marginBottom: "6px",
      display: "flex",
      alignItems: "center",
      gap: "2px",
      padding: "4px 6px",
      borderRadius: "12px",
      background: isDark
        ? "rgba(30, 41, 59, 0.95)"
        : "rgba(255, 255, 255, 0.97)",
      border: isDark
        ? "1px solid rgba(148, 163, 184, 0.2)"
        : "1px solid rgba(148, 163, 184, 0.25)",
      boxShadow: isDark
        ? "0 8px 24px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(148, 163, 184, 0.05)"
        : "0 8px 24px rgba(0, 0, 0, 0.12), 0 0 0 1px rgba(148, 163, 184, 0.08)",
      backdropFilter: "blur(16px)",
      zIndex: "50",
      opacity: "0",
      transform: "scale(0.9) translateY(4px)",
      transition: "opacity 150ms ease-out, transform 150ms ease-out",
    });

    QUICK_EMOJIS.forEach((emoji) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.textContent = emoji;
      btn.setAttribute("aria-label", `React with ${emoji}`);
      Object.assign(btn.style, {
        fontSize: "18px",
        width: "32px",
        height: "32px",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        borderRadius: "8px",
        border: "none",
        background: "transparent",
        cursor: "pointer",
        transition: "transform 120ms ease-out, background 120ms ease-out",
        lineHeight: "1",
        padding: "0",
      });
      btn.addEventListener("mouseenter", () => {
        btn.style.transform = "scale(1.25)";
        btn.style.background = isDark
          ? "rgba(20, 184, 166, 0.15)"
          : "rgba(20, 184, 166, 0.1)";
      });
      btn.addEventListener("mouseleave", () => {
        btn.style.transform = "scale(1)";
        btn.style.background = "transparent";
      });
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        this._sendReaction(emoji);
        this._closeQuickReactBar();
      });
      bar.appendChild(btn);
    });

    const plusBtn = document.createElement("button");
    plusBtn.type = "button";
    plusBtn.setAttribute("aria-label", "More emoji reactions");
    plusBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" style="width:16px;height:16px;"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>`;
    Object.assign(plusBtn.style, {
      width: "32px",
      height: "32px",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      borderRadius: "8px",
      border: isDark
        ? "1px solid rgba(148, 163, 184, 0.2)"
        : "1px solid rgba(148, 163, 184, 0.25)",
      background: "transparent",
      cursor: "pointer",
      transition:
        "transform 120ms ease-out, background 120ms ease-out, color 120ms ease-out",
      lineHeight: "1",
      padding: "0",
      color: isDark ? "rgba(148, 163, 184, 0.7)" : "rgba(100, 116, 139, 0.7)",
      marginLeft: "2px",
    });
    plusBtn.addEventListener("mouseenter", () => {
      plusBtn.style.transform = "scale(1.1)";
      plusBtn.style.background = isDark
        ? "rgba(20, 184, 166, 0.15)"
        : "rgba(20, 184, 166, 0.1)";
      plusBtn.style.color = isDark ? "rgb(94, 234, 212)" : "rgb(13, 148, 136)";
      plusBtn.style.borderColor = isDark
        ? "rgba(20, 184, 166, 0.3)"
        : "rgba(20, 184, 166, 0.3)";
    });
    plusBtn.addEventListener("mouseleave", () => {
      plusBtn.style.transform = "scale(1)";
      plusBtn.style.background = "transparent";
      plusBtn.style.color = isDark
        ? "rgba(148, 163, 184, 0.7)"
        : "rgba(100, 116, 139, 0.7)";
      plusBtn.style.borderColor = isDark
        ? "rgba(148, 163, 184, 0.2)"
        : "rgba(148, 163, 184, 0.25)";
    });
    plusBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      this._closeQuickReactBar();
      this._openFullPicker();
    });
    bar.appendChild(plusBtn);

    const reactArea = this.el.querySelector("[data-react-area]");
    if (reactArea) {
      reactArea.style.position = "relative";
      reactArea.appendChild(bar);
    }

    requestAnimationFrame(() => {
      bar.style.opacity = "1";
      bar.style.transform = "scale(1) translateY(0)";
    });

    this._outsideClickHandler = (e) => {
      if (!bar.contains(e.target) && !reactBtn.contains(e.target)) {
        this._closeQuickReactBar();
      }
    };
    setTimeout(() => {
      document.addEventListener("click", this._outsideClickHandler);
    }, 50);
  },

  _closeQuickReactBar() {
    const bar = this.el.querySelector(".quick-react-bar");
    if (bar) {
      bar.style.opacity = "0";
      bar.style.transform = "scale(0.9) translateY(4px)";
      setTimeout(() => bar.remove(), 150);
    }
    if (this._outsideClickHandler) {
      document.removeEventListener("click", this._outsideClickHandler);
      this._outsideClickHandler = null;
    }
  },

  _openFullPicker() {
    if (this._fullPickerContainer) {
      this._closeFullPicker();
      return;
    }

    const reactArea = this.el.querySelector("[data-react-area]");
    if (!reactArea) return;

    const isDark =
      document.documentElement.getAttribute("data-theme") === "dark" ||
      (document.documentElement.getAttribute("data-theme") === "system" &&
        window.matchMedia("(prefers-color-scheme: dark)").matches);
    const theme = isDark ? "dark" : "light";

    const pickerContainer = document.createElement("div");
    pickerContainer.className = "reaction-emoji-picker fixed z-[9999]";
    pickerContainer.setAttribute("role", "dialog");
    pickerContainer.setAttribute("aria-label", "Emoji reaction picker");

    pickerContainer.style.opacity = "0";
    pickerContainer.style.transform = "scale(0.95)";
    pickerContainer.style.transition =
      "opacity 200ms ease-out, transform 200ms ease-out";

    const areaRect = reactArea.getBoundingClientRect();
    const spaceBelow = window.innerHeight - areaRect.bottom;

    if (spaceBelow >= 450) {
      pickerContainer.style.top = `${areaRect.bottom + 8}px`;
    } else {
      pickerContainer.style.top = `${areaRect.top - 450 - 8}px`;
    }

    let leftPos = areaRect.left - 160;
    if (leftPos + 352 > window.innerWidth) {
      leftPos = window.innerWidth - 352 - 16;
    }
    pickerContainer.style.left = `${Math.max(16, leftPos)}px`;

    document.body.appendChild(pickerContainer);

    this._fullPickerInstance = new Picker({
      data: emojiData,
      parent: pickerContainer,
      theme: theme,
      emojiButtonColors: ["oklch(69.6% 0.17 162.48)"],
      onEmojiSelect: (emoji) => {
        this._sendReaction(emoji.native);
        this._closeFullPicker();
      },
    });

    setTimeout(() => {
      this._applyPickerStyling(pickerContainer, theme);
      fixEmojiPickerA11y(pickerContainer);
      setTimeout(() => {
        if (pickerContainer) {
          pickerContainer.style.opacity = "1";
          pickerContainer.style.transform = "scale(1)";
          this._focusPickerSearch(pickerContainer);
        }
      }, 50);
    }, 50);

    this._fullPickerContainer = pickerContainer;

    this._fullPickerOutsideHandler = (e) => {
      if (!pickerContainer.contains(e.target)) {
        this._closeFullPicker();
      }
    };
    this._fullPickerKeyHandler = (e) => {
      if (e.key === "Escape") {
        this._closeFullPicker();
      }
    };
    setTimeout(() => {
      document.addEventListener("click", this._fullPickerOutsideHandler);
      document.addEventListener("keydown", this._fullPickerKeyHandler);
    }, 100);
  },

  _closeFullPicker() {
    if (this._fullPickerContainer) {
      this._fullPickerContainer.remove();
      this._fullPickerContainer = null;
    }
    this._fullPickerInstance = null;
    if (this._fullPickerOutsideHandler) {
      document.removeEventListener("click", this._fullPickerOutsideHandler);
      this._fullPickerOutsideHandler = null;
    }
    if (this._fullPickerKeyHandler) {
      document.removeEventListener("keydown", this._fullPickerKeyHandler);
      this._fullPickerKeyHandler = null;
    }
  },

  _focusPickerSearch(container) {
    if (!container) return;
    const emojiMart = container.querySelector("em-emoji-picker");
    if (!emojiMart?.shadowRoot) {
      setTimeout(() => this._focusPickerSearch(container), 50);
      return;
    }
    const searchInput = emojiMart.shadowRoot.querySelector(".search input");
    if (searchInput) {
      searchInput.focus();
    }
  },

  _applyPickerStyling(container, theme) {
    if (!container) return;
    const emojiMart = container.querySelector("em-emoji-picker");
    if (!emojiMart?.shadowRoot) {
      setTimeout(() => this._applyPickerStyling(container, theme), 20);
      return;
    }

    const isDark = theme === "dark";
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
            isDark
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
          ${
            isDark
              ? `background: rgba(30, 41, 59, 0.95) !important; --color-c: rgb(148, 163, 184) !important;`
              : `background: rgba(255, 255, 255, 0.95) !important;`
          }
        }
        .search input {
          border-radius: 12px !important;
          border: 1px solid var(--em-color-border) !important;
          transition: all 200ms ease-out !important;
          ${
            isDark
              ? `
            background: rgba(15, 23, 42, 0.8) !important;
            color: rgb(226, 232, 240) !important;
          `
              : `
            background: rgba(248, 250, 252, 0.8) !important;
            color: rgb(30, 41, 59) !important;
          `
          }
        }
        .search input:focus {
          border-color: rgba(20, 184, 166, 0.5) !important;
          box-shadow: 0 0 0 3px rgba(20, 184, 166, 0.1) !important;
          outline: none !important;
        }
        .nav button { border-radius: 10px !important; transition: all 200ms ease-out !important; }
        .nav button:hover {
          ${
            isDark
              ? `background: rgba(20, 184, 166, 0.1) !important;`
              : `background: rgba(20, 184, 166, 0.05) !important;`
          }
          transform: translateY(-1px) !important;
        }
        .nav button[aria-selected="true"] {
          background: linear-gradient(135deg, rgba(20, 184, 166, 0.15), rgba(16, 185, 129, 0.15)) !important;
          ${
            isDark
              ? `color: rgb(94, 234, 212) !important;`
              : `color: rgb(13, 148, 136) !important;`
          }
        }
        .emoji button {
          border-radius: 8px !important;
          transition: all 150ms ease-out !important;
        }
        .emoji button:hover {
          transform: scale(1.1) !important;
          ${
            isDark
              ? `background: rgba(20, 184, 166, 0.1) !important;`
              : `background: rgba(20, 184, 166, 0.05) !important;`
          }
          box-shadow: 0 4px 12px rgba(20, 184, 166, 0.15) !important;
        }
        .sticky {
          ${
            isDark
              ? `
            background: rgba(30, 41, 59, 0.95) !important;
            color: rgb(148, 163, 184) !important;
          `
              : `
            background: rgba(255, 255, 255, 0.95) !important;
            color: rgb(71, 85, 105) !important;
          `
          }
          border-bottom: 1px solid rgba(148, 163, 184, 0.1) !important;
          backdrop-filter: blur(8px) !important;
          font-weight: 600 !important;
          font-size: 13px !important;
          text-transform: uppercase !important;
          letter-spacing: 0.05em !important;
          padding: 8px 12px !important;
        }
        .scroll, .category {
          ${
            isDark
              ? `background: rgba(30, 41, 59, 0.95) !important;`
              : `background: rgba(255, 255, 255, 0.95) !important;`
          }
        }
        ::-webkit-scrollbar { width: 8px !important; }
        ::-webkit-scrollbar-track { background: transparent !important; }
        ::-webkit-scrollbar-thumb {
          ${
            isDark
              ? `background: rgba(148, 163, 184, 0.3) !important;`
              : `background: rgba(148, 163, 184, 0.4) !important;`
          }
          border-radius: 4px !important;
        }
        ::-webkit-scrollbar-thumb:hover { background: rgba(20, 184, 166, 0.5) !important; }
        * { transition: all 150ms ease-out !important; }
      </style>
    `;

    const existing = emojiMart.shadowRoot.querySelector(
      "#liquid-metal-reaction-style"
    );
    if (existing) existing.remove();

    const styleEl = document.createElement("div");
    styleEl.id = "liquid-metal-reaction-style";
    styleEl.innerHTML = liquidMetalCSS;

    const firstChild = emojiMart.shadowRoot.firstChild;
    if (firstChild) {
      emojiMart.shadowRoot.insertBefore(styleEl, firstChild);
    } else {
      emojiMart.shadowRoot.appendChild(styleEl);
    }
  },

  async _sendReaction(emoji) {
    try {
      const convKey = await getConversationKey();
      if (!convKey) {
        console.error("Could not get conversation key for reaction");
        return;
      }

      const encryptedEmoji = await encryptDmMessage(emoji, convKey);
      const messageId = this.el.dataset.messageId;

      this.pushEvent("toggle_reaction", {
        message_id: messageId,
        encrypted_emoji: encryptedEmoji,
      });
    } catch (err) {
      console.error("Reaction encryption failed:", err);
    }
  },

  async _decryptReactions() {
    const reactionElements = this.el.querySelectorAll("[data-encrypted-emoji]");
    if (reactionElements.length === 0) return;

    const convKey = await getConversationKey();
    if (!convKey) return;

    for (const el of reactionElements) {
      const encryptedEmoji = el.dataset.encryptedEmoji;
      if (!encryptedEmoji || el.dataset.decrypted === "true") continue;

      try {
        const emoji = await decryptDmMessage(encryptedEmoji, convKey);
        el.textContent = emoji;
        el.dataset.decrypted = "true";
      } catch (e) {
        el.textContent = "🔒";
      }
    }
  },
};

export default MessageReactions;
