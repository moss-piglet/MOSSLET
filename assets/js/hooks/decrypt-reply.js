/**
 * DecryptReply — browser-side reply decryption hook (zero-knowledge).
 *
 * Replies use the parent post's post_key (shared via DecryptPost →
 * cachePostKey). This hook unseals the post_key from a data attribute
 * (fallback if not yet cached) and decrypts the reply body, username,
 * and favs_list in the browser.
 *
 * Data attributes:
 *   data-post-id             — parent post UUID (for finding cached post_key)
 *   data-sealed-post-key     — base64 sealed post_key (fallback if not cached)
 *   data-encrypted-body      — base64 secretbox-encrypted reply body
 *   data-encrypted-username  — base64 secretbox-encrypted reply username
 *   data-encrypted-favs-list — JSON array of secretbox-encrypted user IDs
 *   data-current-user-id     — current user UUID (for fav membership check)
 *   data-reply-id            — reply UUID (for targeting fav button DOM)
 */
import { unsealContextKey, decryptWithKey, getCachedPostKey, unwrapKey, decryptList } from "../crypto/session";
import { encryptSecretboxString } from "../crypto/nacl";
import { renderMarkdown } from "../utils/render-markdown";

const DecryptReply = {
  mounted() {
    this._decrypt();
  },

  updated() {
    this._decrypt();
  },

  destroyed() {
    this._removeZkFavHandler();
  },

  async _decrypt() {
    const postId = this.el.dataset.postId;
    const encryptedBody = this.el.dataset.encryptedBody;
    const encryptedUsername = this.el.dataset.encryptedUsername;

    if (!postId || !encryptedBody) return;

    try {
      let postKey = getCachedPostKey(postId);

      if (!postKey) {
        const sealedKey = this.el.dataset.sealedPostKey;
        if (!sealedKey) return;
        const raw = await unsealContextKey(sealedKey);
        if (!raw) return;
        postKey = unwrapKey(raw);
      }

      const body = await decryptWithKey(encryptedBody, postKey);

      const bodyTarget = this.el.querySelector("[data-decrypt-reply-body]");
      if (body && bodyTarget) {
        bodyTarget.innerHTML = renderMarkdown(body);
      }

      const username = await decryptWithKey(encryptedUsername, postKey);

      const handleTarget = this.el.querySelector("[data-decrypt-reply-handle]");
      if (username && handleTarget) {
        handleTarget.textContent = "@" + username;
      }

      this._applyFavState(postKey);
    } catch {
      // Fallback: server-rendered content preserved
    }
  },

  _applyFavState(postKey) {
    const replyId = this.el.dataset.replyId;
    const currentUserId = this.el.dataset.currentUserId;
    const encFavsJson = this.el.dataset.encryptedFavsList;
    if (!replyId || !currentUserId || !encFavsJson) return;

    decryptList(encFavsJson, postKey).then((favsList) => {
      if (!favsList) return;

      const isLiked = favsList.includes(currentUserId);

      const solidButton = document.getElementById(
        `hero-heart-solid-reply-button-${replyId}`
      );
      const outlineButton = document.getElementById(
        `hero-heart-reply-button-${replyId}`
      );
      const button = solidButton || outlineButton;
      if (!button) return;

      const iconEl = button.querySelector("[id^='hero-heart']");

      if (isLiked) {
        button.id = `hero-heart-solid-reply-button-${replyId}`;
        button.setAttribute("data-tippy-content", "Remove love");
        button.classList.remove(
          "text-slate-500", "dark:text-slate-400",
          "hover:text-rose-600", "dark:hover:text-rose-400"
        );
        button.classList.add(
          "text-rose-600", "dark:text-rose-400",
          "bg-rose-50/50", "dark:bg-rose-900/20"
        );
        if (iconEl) {
          iconEl.id = `hero-heart-solid-reply-icon-${replyId}`;
          iconEl.classList.remove("hero-heart");
          iconEl.classList.add("hero-heart-solid");
        }
      }

      if (!button.dataset.zkFavReady) {
        button.removeAttribute("phx-click");
        button.dataset.zkFavReady = "true";
        this._removeZkFavHandler();
        this._favHandler = (e) => {
          e.preventDefault();
          e.stopImmediatePropagation();
          this._handleZkReplyFavClick(button, replyId, currentUserId);
        };
        this._favButton = button;
        button.addEventListener("click", this._favHandler);
      }
    });
  },

  async _handleZkReplyFavClick(button, replyId, currentUserId) {
    const postId = this.el.dataset.postId;
    const postKey = getCachedPostKey(postId);
    if (!postKey) return;

    const encFavsJson = this.el.dataset.encryptedFavsList;
    if (!encFavsJson) return;

    try {
      const items = JSON.parse(encFavsJson);
      const decrypted = [];
      for (const item of items) {
        if (typeof item === "string" && item !== "") {
          const plain = await decryptWithKey(item, postKey);
          if (plain) decrypted.push(plain);
        }
      }

      const isCurrentlyLiked = decrypted.includes(currentUserId);

      let newFavs;
      if (isCurrentlyLiked) {
        newFavs = decrypted.filter((id) => id !== currentUserId);
      } else {
        newFavs = [currentUserId, ...decrypted];
      }

      const encrypted = await Promise.all(
        newFavs.map((id) => encryptSecretboxString(id, postKey))
      );

      this.el.dataset.encryptedFavsList = JSON.stringify(encrypted);

      this.pushEvent("toggle_reply_fav_zk", {
        id: replyId,
        encrypted_favs_list: JSON.stringify(encrypted),
        is_liked: (!isCurrentlyLiked).toString(),
      });
    } catch (e) {
      console.error("DecryptReply: ZK fav toggle failed:", e);
    }
  },

  _removeZkFavHandler() {
    if (this._favHandler && this._favButton) {
      this._favButton.removeEventListener("click", this._favHandler);
      this._favHandler = null;
      this._favButton = null;
    }
  },
};

export default DecryptReply;
