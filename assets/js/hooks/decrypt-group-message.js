/**
 * DecryptGroupMessage — browser-side group message decryption (zero-knowledge).
 *
 * For non-public groups, the server passes the sealed group_key and encrypted
 * message content as data attributes. This hook unseals the key and decrypts
 * the content in the browser. The server never sees plaintext message content.
 *
 * Also decrypts the sender's moniker and group avatar_img (filename) so the
 * server never handles those metadata fields for non-public groups.
 *
 * Public groups are decrypted server-side and don't use this hook.
 *
 * Data attributes:
 *   data-sealed-group-key       — base64 sealed group_key (envelope-encrypted to user)
 *   data-encrypted-content      — secretbox-encrypted message content
 *   data-encrypted-moniker      — secretbox-encrypted sender moniker (group_key)
 *   data-encrypted-avatar-img   — secretbox-encrypted sender avatar filename (group_key)
 *   data-current-user-group-id  — the current user's user_group_id (for self-mention styling)
 *   data-is-own-message         — "true" if the message is from the current user
 */
import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey, escapeHtml } from "../crypto/session";
import { renderMarkdown } from "../utils/render-markdown";
import MentionPicker from "./mention-picker";

const MENTION_TOKEN_RE = /@\[([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\]/gi;

function resolveMentions(text, currentUserGroupId, isOwnMessage) {
  const members = MentionPicker._sharedMembers || [];
  if (!members.length) return text;

  return text.replace(MENTION_TOKEN_RE, (_match, userGroupId) => {
    const member = members.find((m) => m.user_group_id === userGroupId);
    if (!member) return "@unknown";

    const displayName = member.is_connected ? member.username : member.moniker;
    const isSelf = userGroupId === currentUserGroupId;
    const role = member.role || "member";

    const textClass = mentionTextClass(role, isOwnMessage);

    if (isSelf) {
      return `<span class="mention-self ${textClass} font-semibold underline decoration-2 underline-offset-2"><span class="opacity-60">@</span>${escapeHtml(displayName)}</span>`;
    }
    return `<span class="mention ${textClass} font-medium"><span class="opacity-50">@</span>${escapeHtml(displayName)}</span>`;
  });
}

function mentionTextClass(role, isOwnMessage) {
  if (isOwnMessage) {
    switch (role) {
      case "owner": return "text-pink-200";
      case "admin": return "text-orange-200";
      case "moderator": return "text-sky-200";
      default: return "text-teal-200";
    }
  }
  switch (role) {
    case "owner": return "text-amber-600 dark:text-amber-400";
    case "admin": return "text-purple-600 dark:text-purple-400";
    case "moderator": return "text-blue-600 dark:text-blue-400";
    default: return "text-teal-600 dark:text-teal-400";
  }
}

const FAILED_MARKUP =
  '<span class="text-red-400 dark:text-red-500 text-sm italic">[Decryption failed]</span>';

const MAX_WAIT_MS = 8000;

const DecryptGroupMessage = {
  async mounted() {
    if (!await this.decrypt()) {
      this._onKeysReady = () => this.decrypt();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });

      this._timeout = setTimeout(() => {
        window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
        if (!this._decrypted) this.el.innerHTML = FAILED_MARKUP;
      }, MAX_WAIT_MS);
    }

    this._onMembersReady = () => this._reResolveMentions();
    window.addEventListener("mosslet:members-ready", this._onMembersReady);
  },

  async updated() {
    await this.decrypt();
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
    if (this._onMembersReady) {
      window.removeEventListener("mosslet:members-ready", this._onMembersReady);
    }
    if (this._timeout) clearTimeout(this._timeout);
  },

  async decrypt() {
    const sealedKey = this.el.dataset.sealedGroupKey;
    const encryptedContent = this.el.dataset.encryptedContent;

    if (!sealedKey || !encryptedContent) {
      this.el.innerHTML = FAILED_MARKUP;
      return true;
    }
    if (!getPublicKey()) return false;

    try {
      const rawGroupKey = await unsealContextKey(sealedKey);
      if (!rawGroupKey) {
        this.el.innerHTML = FAILED_MARKUP;
        return true;
      }

      const groupKey = unwrapKey(rawGroupKey);
      const plaintext = await decryptWithKey(encryptedContent, groupKey);
      if (!plaintext) {
        this.el.innerHTML = FAILED_MARKUP;
        return true;
      }

      const currentUserGroupId = this.el.dataset.currentUserGroupId || "";
      const isOwnMessage = this.el.dataset.isOwnMessage === "true";

      this._plaintext = plaintext;
      this._currentUserGroupId = currentUserGroupId;
      this._isOwnMessage = isOwnMessage;

      const withMentions = resolveMentions(plaintext, currentUserGroupId, isOwnMessage);
      const html = renderMarkdown(withMentions);
      this.el.innerHTML = html;
      this._decrypted = true;
      if (this._timeout) clearTimeout(this._timeout);

      this._decryptMetadata(groupKey);

      return true;
    } catch (e) {
      console.error("DecryptGroupMessage: decryption failed:", e);
      this.el.innerHTML = FAILED_MARKUP;
      return true;
    }
  },

  async _decryptMetadata(groupKey) {
    const hookId = this.el.id;
    const messageId = hookId.replace("decrypt-msg-", "");
    const messageEl = document.getElementById(messageId);
    if (!messageEl) return;

    const encryptedMoniker = this.el.dataset.encryptedMoniker;
    if (encryptedMoniker) {
      try {
        const moniker = await decryptWithKey(encryptedMoniker, groupKey);
        if (moniker) {
          const target = messageEl.querySelector(`[data-decrypt-moniker-target="${messageId}"]`);
          if (target) target.textContent = moniker;
        }
      } catch (_e) { /* leave placeholder */ }
    }

    const encryptedAvatarImg = this.el.dataset.encryptedAvatarImg;
    if (encryptedAvatarImg) {
      try {
        const avatarImg = await decryptWithKey(encryptedAvatarImg, groupKey);
        if (avatarImg && avatarImg !== "") {
          const avatarEl = document.getElementById(`chat-avatar-${messageId}`);
          if (avatarEl) avatarEl.src = `/images/groups/${avatarImg}`;
        }
      } catch (_e) { /* leave default avatar */ }
    }
  },

  _reResolveMentions() {
    if (!this._decrypted || !this._plaintext) return;
    if (!MENTION_TOKEN_RE.test(this._plaintext)) return;
    MENTION_TOKEN_RE.lastIndex = 0;

    const members = MentionPicker._sharedMembers || [];
    if (!members.length) return;

    const withMentions = resolveMentions(
      this._plaintext,
      this._currentUserGroupId,
      this._isOwnMessage
    );
    const html = renderMarkdown(withMentions);
    this.el.innerHTML = html;
  },
};

export default DecryptGroupMessage;
