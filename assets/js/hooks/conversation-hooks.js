import {
  decryptDmMessage,
  encryptDmMessage,
  decryptDmKey,
} from "../crypto/nacl";
import { renderMarkdown, extractFirstUrl } from "../utils/render-markdown";

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
      if (this._cachedPreviewHtml) {
        this._appendPreviewElement(this._cachedPreviewHtml);
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

      this.maybeLoadUrlPreview(plaintext);
    } catch (e) {
      console.error("Message decryption failed:", e);
      this.el.textContent = "[Decryption failed]";
    }
  },

  _isSenderBubble() {
    const bubble = this.el.closest('[class*="rounded-2xl"]');
    return bubble ? bubble.className.includes("from-teal") : false;
  },

  maybeLoadUrlPreview(plaintext) {
    const messageId = this.el.dataset.messageId;
    if (!messageId || this._previewLoaded) return;

    const url = extractFirstUrl(plaintext);
    if (!url) return;
    this._previewLoaded = true;

    const isSender = this._isSenderBubble();
    const loadingEl = document.createElement("div");
    loadingEl.className = "mt-3 url-preview-container";
    loadingEl.innerHTML = `
      <div class="overflow-hidden rounded-xl ${isSender ? "border border-white/20 bg-white/10" : "border border-slate-200/60 dark:border-slate-700/50 bg-slate-50/80 dark:bg-slate-900/40"} animate-pulse">
        <div class="h-[140px] ${isSender ? "bg-white/10" : "bg-slate-200/60 dark:bg-slate-700/30"}"></div>
        <div class="p-3 space-y-2">
          <div class="h-3 w-1/3 rounded-full ${isSender ? "bg-white/15" : "bg-slate-200/80 dark:bg-slate-700/40"}"></div>
          <div class="h-4 w-3/4 rounded-full ${isSender ? "bg-white/15" : "bg-slate-200/80 dark:bg-slate-700/40"}"></div>
          <div class="h-3 w-full rounded-full ${isSender ? "bg-white/15" : "bg-slate-200/80 dark:bg-slate-700/40"}"></div>
        </div>
      </div>
    `;
    this.el.appendChild(loadingEl);

    this.pushEvent(
      "fetch_url_preview",
      { url: url, message_id: messageId },
      (reply) => {
        if (reply.preview) {
          const previewHtml = this._buildPreviewCard(reply.preview, isSender);
          this._cachedPreviewHtml = previewHtml;
          this._cachedPreviewIsSender = isSender;
          loadingEl.innerHTML = previewHtml;
          loadingEl.classList.remove("animate-pulse");
        } else {
          loadingEl.remove();
        }
      },
    );
  },

  _buildPreviewCard(preview, isSender) {
    const title = this._escapeHtml(preview.title || "");
    const description = this._escapeHtml(preview.description || "");
    const siteName = this._escapeHtml(
      preview.site_name || this._extractDomain(preview.url) || "",
    );
    const url = this._escapeHtml(preview.url || "");
    const image = preview.image || "";

    const imageHtml = image
      ? `<div class="w-full overflow-hidden">
           <img src="${this._escapeHtml(image)}" alt="${title || "Preview"}" class="w-full max-h-[120px] object-cover group-hover/preview:scale-[1.03] transition-transform duration-500" onerror="this.parentElement.style.display='none'" />
         </div>`
      : "";

    const siteIconSvg = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="h-3.5 w-3.5 shrink-0 ${isSender ? "text-white/50" : "text-slate-400 dark:text-slate-500"}">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418" />
    </svg>`;

    const siteNameHtml = siteName
      ? `<div class="flex items-center gap-1.5">
           ${siteIconSvg}
           <span class="text-xs font-medium ${isSender ? "text-white/60" : "text-slate-500 dark:text-slate-400"} truncate uppercase tracking-wide">${siteName}</span>
         </div>`
      : "";

    const titleHtml = title
      ? `<p class="font-semibold text-[13px] leading-snug ${isSender ? "text-white group-hover/preview:text-white" : "text-slate-900 dark:text-slate-100 group-hover/preview:text-teal-600 dark:group-hover/preview:text-teal-400"} line-clamp-2 transition-colors">${title}</p>`
      : "";

    const descHtml = description
      ? `<p class="text-[11px] leading-relaxed ${isSender ? "text-white/70" : "text-slate-500 dark:text-slate-400"} line-clamp-1 mt-0.5">${description}</p>`
      : "";

    const cardBorder = isSender
      ? "border border-white/20"
      : "border border-slate-200/60 dark:border-slate-700/50";
    const cardBg = isSender
      ? "bg-white/10 hover:bg-white/15"
      : "bg-slate-50/80 dark:bg-slate-900/40 hover:bg-slate-100/80 dark:hover:bg-slate-800/60";
    const hoverBorder = isSender
      ? "hover:border-white/30"
      : "hover:border-teal-300 dark:hover:border-teal-600";

    return `<a href="${url}" target="_blank" rel="noopener noreferrer" class="block max-w-[280px] overflow-hidden rounded-lg ${cardBorder} ${cardBg} ${hoverBorder} transition-all duration-300 group/preview no-underline !no-underline">
      ${imageHtml}
      <div class="px-2.5 py-2 space-y-0.5">
        ${siteNameHtml}
        ${titleHtml}
        ${descHtml}
      </div>
    </a>`;
  },

  _extractDomain(url) {
    if (!url) return null;
    try {
      return new URL(url).hostname.replace(/^www\./, "");
    } catch {
      return null;
    }
  },

  _escapeHtml(str) {
    const div = document.createElement("div");
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  },

  _appendPreviewElement(previewHtml) {
    const existing = this.el.querySelector(".url-preview-container");
    if (existing) existing.remove();
    const container = document.createElement("div");
    container.className = "mt-3 url-preview-container";
    container.innerHTML = previewHtml;
    this.el.appendChild(container);
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
