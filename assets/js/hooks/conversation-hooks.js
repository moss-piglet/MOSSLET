import {
  decryptDmMessage,
  encryptDmMessage,
  decryptDmKey,
} from "../crypto/nacl";
import { renderMarkdown } from "../utils/render-markdown";

function getComposerEl() {
  return document.querySelector("#conversation-composer");
}

async function getConversationKey(encryptedConvKey, userPublicKey) {
  const composerEl = getComposerEl();
  const sessionKey = composerEl?.dataset?.sessionKey;
  const encryptedPrivateKey = composerEl?.dataset?.encryptedPrivateKey;

  if (!sessionKey || !encryptedPrivateKey || !encryptedConvKey) {
    return null;
  }

  try {
    const { decryptPrivateKey } = await import("../crypto/nacl");
    const privateKey = await decryptPrivateKey(encryptedPrivateKey, sessionKey);
    return await decryptDmKey(encryptedConvKey, userPublicKey, privateKey);
  } catch (e) {
    console.error("Failed to decrypt conversation key:", e);
    return null;
  }
}

const ConversationComposer = {
  mounted() {
    this._savedValue = "";
    this._savedSelectionStart = 0;
    this._savedSelectionEnd = 0;
    this._bindElements();
  },

  _unbindElements() {
    if (this.form && this._submitHandler) {
      this.form.removeEventListener("submit", this._submitHandler);
    }
    if (this.textarea && this._keydownHandler) {
      this.textarea.removeEventListener("keydown", this._keydownHandler);
    }
  },

  _bindElements() {
    this._unbindElements();

    this.form = this.el.querySelector("#message-form");
    this.textarea = this.el.querySelector("#message-input");

    if (!this.form || !this.textarea) return;

    this._submitHandler = async (e) => {
      e.preventDefault();

      const plaintext = this.textarea.value.trim();
      if (!plaintext) return;

      const convKeyEncrypted = this.el.dataset.conversationKey;
      const userPublicKey = this.el.dataset.userPublicKey;

      try {
        const convKey = await getConversationKey(
          convKeyEncrypted,
          userPublicKey
        );
        if (!convKey) {
          console.error("Could not decrypt conversation key");
          return;
        }

        const encryptedContent = await encryptDmMessage(plaintext, convKey);

        this.textarea.value = "";
        this._savedValue = "";
        this.textarea.style.height = "auto";
        this.textarea.dispatchEvent(new Event("input", { bubbles: true }));

        this.pushEvent("send_message", { encrypted_content: encryptedContent });
      } catch (err) {
        console.error("Encryption failed:", err);
      }
    };

    this._keydownHandler = (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        this.form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
      }
    };

    this.form.addEventListener("submit", this._submitHandler);
    this.textarea.addEventListener("keydown", this._keydownHandler);
  },

  beforeUpdate() {
    this.textarea = this.el.querySelector("#message-input");
    if (this.textarea) {
      this._savedValue = this.textarea.value;
      this._savedSelectionStart = this.textarea.selectionStart;
      this._savedSelectionEnd = this.textarea.selectionEnd;
    }
  },

  updated() {
    this._bindElements();

    if (this.textarea && this._savedValue) {
      this.textarea.value = this._savedValue;
      this.textarea.selectionStart = this._savedSelectionStart;
      this.textarea.selectionEnd = this._savedSelectionEnd;
    }
  },
};

const DecryptMessage = {
  async mounted() {
    await this.decrypt();
  },

  async updated() {
    await this.decrypt();
  },

  async decrypt() {
    const encryptedContent = this.el.dataset.encryptedContent;
    const convKeyEncrypted = this.el.dataset.conversationKey;

    if (!encryptedContent || !convKeyEncrypted) {
      this.el.textContent = "[Unable to decrypt]";
      return;
    }

    const composerEl = getComposerEl();
    const userPublicKey = composerEl?.dataset?.userPublicKey;

    if (!userPublicKey) {
      this.el.textContent = "[Encryption key unavailable]";
      return;
    }

    try {
      const convKey = await getConversationKey(convKeyEncrypted, userPublicKey);
      if (!convKey) {
        this.el.textContent = "[Key decryption failed]";
        return;
      }

      const plaintext = await decryptDmMessage(encryptedContent, convKey);
      this.el.innerHTML = renderMarkdown(plaintext);
    } catch (e) {
      console.error("Message decryption failed:", e);
      this.el.textContent = "[Decryption failed]";
    }
  },
};

const ConversationScroll = {
  mounted() {
    this.scrollToBottom();

    this.handleEvent("new-message", () => {
      requestAnimationFrame(() => this.scrollToBottom());
    });
  },

  updated() {
    if (this.isNearBottom()) {
      this.scrollToBottom();
    }
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },

  isNearBottom() {
    const threshold = 150;
    return (
      this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight <
      threshold
    );
  },
};

export { ConversationComposer, DecryptMessage, ConversationScroll };
