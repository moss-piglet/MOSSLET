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
    this._isTyping = false;
    this._typingTimeout = null;
    this._bindElements();
  },

  _unbindElements() {
    if (this.form && this._submitHandler) {
      this.form.removeEventListener("submit", this._submitHandler);
    }
    if (this.textarea && this._keydownHandler) {
      this.textarea.removeEventListener("keydown", this._keydownHandler);
    }
    if (this.textarea && this._inputHandler) {
      this.textarea.removeEventListener("input", this._inputHandler);
    }
  },

  _sendTyping(typing) {
    if (typing !== this._isTyping) {
      this._isTyping = typing;
      this.pushEvent("typing", { typing });
    }
  },

  _handleTypingInput() {
    this._sendTyping(true);
    clearTimeout(this._typingTimeout);
    this._typingTimeout = setTimeout(() => {
      this._sendTyping(false);
    }, 2000);
  },

  _hasPhotoAttached() {
    const preview = document.querySelector("#conversation-photo-preview");
    return preview?.dataset?.photoReady === "true";
  },

  _bindElements() {
    this._unbindElements();

    this.form = this.el.querySelector("#message-form");
    this.textarea = this.el.querySelector("#message-input");

    if (!this.form || !this.textarea) return;

    this._submitHandler = async (e) => {
      e.preventDefault();

      const plaintext = this.textarea.value.trim();
      const hasPhoto = this._hasPhotoAttached();

      if (!plaintext && !hasPhoto) return;

      const messageText = plaintext || "📷";

      const convKeyEncrypted = this.el.dataset.conversationKey;
      const userPublicKey = this.el.dataset.userPublicKey;

      try {
        const convKey = await getConversationKey(
          convKeyEncrypted,
          userPublicKey,
        );
        if (!convKey) {
          console.error("Could not decrypt conversation key");
          return;
        }

        const encryptedContent = await encryptDmMessage(messageText, convKey);

        this.textarea.value = "";
        this._savedValue = "";
        this.textarea.style.height = "auto";
        this.textarea.dispatchEvent(new Event("input", { bubbles: true }));

        clearTimeout(this._typingTimeout);
        this._sendTyping(false);

        this.pushEvent("send_message", { encrypted_content: encryptedContent });
      } catch (err) {
        console.error("Encryption failed:", err);
      }
    };

    this._keydownHandler = (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        this.form.dispatchEvent(
          new Event("submit", { bubbles: true, cancelable: true }),
        );
      }
    };

    this.form.addEventListener("submit", this._submitHandler);
    this.textarea.addEventListener("keydown", this._keydownHandler);

    this._inputHandler = () => {
      if (this.textarea.value.trim().length > 0) {
        this._handleTypingInput();
      } else {
        clearTimeout(this._typingTimeout);
        this._sendTyping(false);
      }
    };
    this.textarea.addEventListener("input", this._inputHandler);
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

  destroyed() {
    this._unbindElements();
    clearTimeout(this._typingTimeout);
    this._sendTyping(false);
  },
};

const DecryptMessage = {
  async mounted() {
    await this.decrypt();
  },

  async updated() {
    if (this._cachedHtml) {
      this.el.innerHTML = this._cachedHtml;
      if (this._cachedImageDataUrl) {
        this._appendImageElement(this._cachedImageDataUrl);
      }
    } else {
      await this.decrypt();
    }
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
      const html = renderMarkdown(plaintext);
      this._cachedHtml = html;
      this.el.innerHTML = html;

      if (this.el.dataset.hasImage === "true") {
        this.loadImage();
      }
    } catch (e) {
      console.error("Message decryption failed:", e);
      this.el.textContent = "[Decryption failed]";
    }
  },

  _openLightbox(dataUrl) {
    const lightbox = document.querySelector("#conversation-image-lightbox");
    if (lightbox && lightbox._lightboxHook) {
      lightbox._lightboxHook.open(dataUrl);
    }
  },

  _appendImageElement(dataUrl) {
    const imgContainer = document.createElement("div");
    imgContainer.className = "mt-2 rounded-lg overflow-hidden";
    imgContainer.innerHTML = `
      <div class="inline-block rounded-xl bg-white dark:bg-slate-700 p-1 shadow-sm">
        <img
          src="${dataUrl}"
          alt="Encrypted image"
          class="max-w-[280px] max-h-[280px] w-auto h-auto rounded-xl cursor-pointer hover:opacity-90 transition-opacity block object-contain"
          loading="lazy"
        />
      </div>
    `;
    imgContainer.querySelector("img").addEventListener("click", () => {
      this._openLightbox(dataUrl);
    });
    this.el.appendChild(imgContainer);
  },

  loadImage() {
    const messageId = this.el.dataset.messageId;
    if (!messageId || this._imageLoaded) return;
    this._imageLoaded = true;

    const imgContainer = document.createElement("div");
    imgContainer.className = "mt-2 rounded-lg overflow-hidden";
    imgContainer.innerHTML = `
      <div class="h-40 w-40 bg-slate-200/50 dark:bg-slate-700/50 rounded-xl flex items-center justify-center">
        <div class="flex flex-col items-center gap-1.5">
          <div class="w-5 h-5 rounded-full border-2 border-emerald-500/30 border-t-emerald-500 animate-spin"></div>
          <span class="text-xs text-slate-400">Loading image...</span>
        </div>
      </div>
    `;
    this.el.appendChild(imgContainer);

    this.pushEvent(
      "decrypt_message_image",
      { message_id: messageId },
      (reply) => {
        if (reply.image_data_url) {
          this._cachedImageDataUrl = reply.image_data_url;
          imgContainer.innerHTML = `
          <div class="inline-block rounded-xl bg-white dark:bg-slate-700 p-1 shadow-sm">
            <img
              src="${reply.image_data_url}"
              alt="Encrypted image"
              class="max-w-[280px] max-h-[280px] w-auto h-auto rounded-xl cursor-pointer hover:opacity-90 transition-opacity block object-contain"
              loading="lazy"
            />
          </div>
        `;
          imgContainer.querySelector("img").addEventListener("click", () => {
            this._openLightbox(reply.image_data_url);
          });
        } else {
          imgContainer.innerHTML = `
          <div class="text-xs text-slate-400 italic py-1">
            Image unavailable
          </div>
        `;
        }
      },
    );
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
