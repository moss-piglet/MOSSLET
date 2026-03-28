import {
  encryptDmMessage,
  decryptDmMessage,
  decryptDmKey,
} from "../crypto/nacl";

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

  if (!sessionKey || !encryptedPrivateKey || !encryptedConvKey || !userPublicKey) {
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

    const reactBtn = this.el.querySelector("[data-react-trigger]");
    if (!reactBtn) return;

    const bar = document.createElement("div");
    bar.className = "quick-react-bar";

    const isDark = document.documentElement.getAttribute("data-theme") === "dark" ||
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
      background: isDark ? "rgba(30, 41, 59, 0.95)" : "rgba(255, 255, 255, 0.97)",
      border: isDark ? "1px solid rgba(148, 163, 184, 0.2)" : "1px solid rgba(148, 163, 184, 0.25)",
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
        btn.style.background = isDark ? "rgba(20, 184, 166, 0.15)" : "rgba(20, 184, 166, 0.1)";
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
