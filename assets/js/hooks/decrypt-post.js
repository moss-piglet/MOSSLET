/**
 * DecryptPost — browser-side post decryption hook (zero-knowledge).
 *
 * For non-public posts, the server passes the sealed post_key and encrypted
 * field blobs as data attributes. This hook unseals the key using the user's
 * private keys (from sessionStorage, populated by SessionKeyDeriver) and
 * decrypts all post fields in the browser. The server never sees plaintext
 * content for non-public posts.
 *
 * Public posts are decrypted server-side (sealed to the server keypair)
 * and don't use this hook.
 *
 * Data attributes (on this element):
 *   data-post-id                           — post UUID (for targeting external elements)
 *   data-sealed-post-key                   — base64 sealed post_key
 *   data-encrypted-body                    — base64 secretbox-encrypted post body
 *   data-encrypted-username                — base64 secretbox-encrypted username
 *   data-encrypted-content-warning         — base64 secretbox-encrypted CW text (optional)
 *   data-encrypted-content-warning-category — base64 secretbox-encrypted CW category (optional)
 *   data-encrypted-url-preview             — JSON object with encrypted string values (optional)
 *
 * External DOM targets (outside this element, matched by data-* + post ID):
 *   [data-decrypt-handle-target="{postId}"]       — username/handle span
 *   [data-decrypt-cw-text-target="{postId}"]      — content warning text
 *   [data-decrypt-cw-category-target="{postId}"]  — content warning category badge
 *   [data-decrypt-url-preview-target="{postId}"]  — URL preview container
 */
import { unsealContextKey, decryptWithKey, getPublicKey, cachePostKey } from "../crypto/session";
import { renderMarkdown } from "../utils/render-markdown";

/**
 * Post keys are sealed as base64 strings on the server (the NIF seals a
 * 44-char base64-encoded key). The WASM unsealFromUser returns raw plaintext
 * bytes re-encoded as base64, producing a double-encoded result. We decode
 * one layer so decryptWithKey receives the original base64 key string.
 */
function unwrapPostKey(unsealedB64) {
  try {
    return atob(unsealedB64);
  } catch {
    return unsealedB64;
  }
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

function formatCwCategory(raw) {
  if (!raw) return "";
  return raw
    .split("_")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

const DecryptPost = {
  async mounted() {
    this._cached = null;
    this._cachedAttrs = null;
    this._keysReadyHandler = null;
    await this._decrypt();
  },

  async updated() {
    const currentAttrs = this._attrFingerprint();
    if (this._cached && this._cachedAttrs === currentAttrs) {
      this._applyCached();
    } else {
      this._cached = null;
      this._cachedAttrs = null;
      await this._decrypt();
    }
  },

  destroyed() {
    this._cached = null;
    this._cachedAttrs = null;
    if (this._keysReadyHandler) {
      window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
      this._keysReadyHandler = null;
    }
  },

  _attrFingerprint() {
    return (this.el.dataset.sealedPostKey || "") + "|" + (this.el.dataset.encryptedBody || "");
  },

  async _decrypt() {
    const sealedKey = this.el.dataset.sealedPostKey;
    const encryptedBody = this.el.dataset.encryptedBody;

    if (!sealedKey || !encryptedBody) return;

    if (!getPublicKey()) {
      if (this._keysReadyHandler) {
        window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
      }
      this._keysReadyHandler = () => {
        this._keysReadyHandler = null;
        this._decrypt();
      };
      window.addEventListener("mosslet:keys-ready", this._keysReadyHandler, { once: true });
      return;
    }

    try {
      const rawPostKey = await unsealContextKey(sealedKey);
      if (!rawPostKey) return;

      const postKey = unwrapPostKey(rawPostKey);

      // Cache the unsealed key so other hooks (TrixContentPostHook for images)
      // can decrypt without re-unsealing.
      const postId = this.el.dataset.postId;
      if (postId) cachePostKey(postId, postKey);
      const results = {};

      const bodyPlain = await decryptWithKey(encryptedBody, postKey);
      results.body = bodyPlain;

      const encUsername = this.el.dataset.encryptedUsername;
      if (encUsername) {
        results.username = await decryptWithKey(encUsername, postKey);
      }

      const encCw = this.el.dataset.encryptedContentWarning;
      if (encCw) {
        results.contentWarning = await decryptWithKey(encCw, postKey);
      }

      const encCwCat = this.el.dataset.encryptedContentWarningCategory;
      if (encCwCat) {
        results.contentWarningCategory = await decryptWithKey(encCwCat, postKey);
      }

      const encUrlPreview = this.el.dataset.encryptedUrlPreview;
      if (encUrlPreview) {
        try {
          const previewMap = JSON.parse(encUrlPreview);
          const decrypted = {};
          for (const [k, v] of Object.entries(previewMap)) {
            if (typeof v === "string" && v !== "") {
              decrypted[k] = await decryptWithKey(v, postKey);
            } else {
              decrypted[k] = v;
            }
          }
          results.urlPreview = decrypted;
        } catch {
          // JSON parse or decrypt failure — skip url preview
        }
      }

      this._cached = results;
      this._cachedAttrs = this._attrFingerprint();
      this._apply(results);
    } catch (e) {
      // Browser-side decryption failed — server-rendered content is preserved.
    }
  },

  _apply(results) {
    this._applyBody(results.body);
    this._applyUsername(results.username);
    this._applyContentWarning(results.contentWarning, results.contentWarningCategory);
    this._applyUrlPreview(results.urlPreview);
  },

  _applyCached() {
    if (this._cached) this._apply(this._cached);
  },

  _applyBody(plaintext) {
    if (!plaintext) return;
    const target = this.el.querySelector("[data-decrypt-target]");
    if (target) {
      target.innerHTML = renderMarkdown(plaintext);
      target.classList.remove("animate-pulse");
    }
  },

  _applyUsername(username) {
    if (!username) return;
    const postId = this.el.dataset.postId;
    if (!postId) return;

    const handleEl = document.querySelector(`[data-decrypt-handle-target="${postId}"]`);
    if (handleEl) {
      handleEl.textContent = "@" + username;
    }
  },

  _applyContentWarning(text, category) {
    const postId = this.el.dataset.postId;
    if (!postId) return;

    if (text) {
      const cwTextEl = document.querySelector(`[data-decrypt-cw-text-target="${postId}"]`);
      if (cwTextEl) {
        cwTextEl.textContent = text;
      }
    }

    if (category) {
      const cwCatEl = document.querySelector(`[data-decrypt-cw-category-target="${postId}"]`);
      if (cwCatEl) {
        cwCatEl.textContent = formatCwCategory(category);
      }
    }
  },

  _applyUrlPreview(preview) {
    if (!preview || !preview.url) return;
    const postId = this.el.dataset.postId;
    if (!postId) return;

    const container = document.querySelector(`[data-decrypt-url-preview-target="${postId}"]`);
    if (!container) return;

    const title = preview.title || "";
    const description = preview.description || "";
    const siteName = preview.site_name || "External Link";
    const image = preview.image || "";

    let imageHtml = "";
    if (image) {
      imageHtml = `
        <div class="w-20 h-14 shrink-0 overflow-hidden rounded-lg">
          <img src="${escapeHtml(image)}" alt="${escapeHtml(title || "Preview image")}"
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
        </div>`;
    }

    container.innerHTML = `
      <a href="${escapeHtml(preview.url)}" target="_blank" rel="noopener noreferrer"
        class="flex gap-3 p-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white/95 dark:bg-slate-800/95 hover:border-emerald-400 dark:hover:border-emerald-500 transition-all duration-200 group">
        ${imageHtml}
        <div class="flex-1 min-w-0 py-0.5">
          <div class="flex items-center gap-1.5 mb-0.5">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 text-slate-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 4 4 0 005.656 0l3-3a4 4 0 00-5.656-5.656l-1.5 1.5a1 1 0 101.414 1.414l1.5-1.5zm-5 5a2 2 0 012.828 0 1 1 0 101.414-1.414 4 4 0 00-5.656 0l-3 3a4 4 0 105.656 5.656l1.5-1.5a1 1 0 10-1.414-1.414l-1.5 1.5a2 2 0 11-2.828-2.828l3-3z" clip-rule="evenodd"/>
            </svg>
            <span class="text-xs text-slate-500 dark:text-slate-400 truncate">${escapeHtml(siteName)}</span>
          </div>
          ${title ? `<p class="font-medium text-sm text-slate-900 dark:text-slate-100 line-clamp-1 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">${escapeHtml(title)}</p>` : ""}
          ${description ? `<p class="text-xs text-slate-600 dark:text-slate-400 line-clamp-2 mt-0.5">${escapeHtml(description)}</p>` : ""}
        </div>
      </a>`;
    container.classList.remove("hidden");
  },
};

export default DecryptPost;
