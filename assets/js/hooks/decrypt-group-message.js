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

const MENTION_PILL_BASE =
  "mention inline-flex items-baseline rounded-md px-1.5 py-0.5 font-medium leading-tight transition-colors";

// Surface-tailored pill themes — kept in lockstep with the server renderer in
// MossletWeb.GroupLive.GroupMessages.mention_pill_theme/2.
const MENTION_PILL_THEME = {
  family: {
    normal: "bg-rose-100/70 text-rose-700 dark:bg-rose-500/15 dark:text-rose-300",
    self: "bg-rose-200/80 text-rose-800 ring-1 ring-rose-400/50 font-semibold dark:bg-rose-500/25 dark:text-rose-200 dark:ring-rose-400/40",
  },
  business: {
    normal: "bg-indigo-100/70 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-300",
    self: "bg-indigo-200/80 text-indigo-800 ring-1 ring-indigo-400/50 font-semibold dark:bg-indigo-500/25 dark:text-indigo-200 dark:ring-indigo-400/40",
  },
  personal: {
    normal: "bg-teal-100/70 text-teal-700 dark:bg-teal-500/15 dark:text-teal-300",
    self: "bg-teal-200/80 text-teal-800 ring-1 ring-teal-400/50 font-semibold dark:bg-teal-500/25 dark:text-teal-200 dark:ring-teal-400/40",
  },
};

function mentionPillClass(variant, isOwnMessage, isSelf) {
  if (isOwnMessage) {
    const base = `${MENTION_PILL_BASE} bg-white/20 text-white`;
    return isSelf ? `${base} ring-1 ring-white/40 font-semibold` : base;
  }
  const theme = MENTION_PILL_THEME[variant] || MENTION_PILL_THEME.personal;
  return `${MENTION_PILL_BASE} ${isSelf ? theme.self : theme.normal}`;
}

function resolveMentions(text, currentUserGroupId, isOwnMessage, variant) {
  const members = MentionPicker._sharedMembers || [];
  if (!members.length) return text;

  return text.replace(MENTION_TOKEN_RE, (_match, userGroupId) => {
    const member = members.find((m) => m.user_group_id === userGroupId);
    const isSelf = userGroupId === currentUserGroupId;
    const cls = mentionPillClass(variant, isOwnMessage, isSelf);

    if (!member) {
      return `<span class="${cls}"><span class="opacity-60">@</span>unknown</span>`;
    }

    const displayName = member.is_connected ? member.username : member.moniker;
    return `<span class="${cls}"><span class="opacity-60">@</span>${escapeHtml(displayName)}</span>`;
  });
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
      const mentionVariant = this.el.dataset.mentionVariant || "personal";

      this._plaintext = plaintext;
      this._currentUserGroupId = currentUserGroupId;
      this._isOwnMessage = isOwnMessage;
      this._mentionVariant = mentionVariant;

      const withMentions = resolveMentions(plaintext, currentUserGroupId, isOwnMessage, mentionVariant);
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
      this._isOwnMessage,
      this._mentionVariant
    );
    const html = renderMarkdown(withMentions);
    this.el.innerHTML = html;
  },
};

export default DecryptGroupMessage;
