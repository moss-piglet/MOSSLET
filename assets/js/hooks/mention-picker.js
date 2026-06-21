import { unsealContextKey, decryptWithKey, getPublicKey, unwrapConnKey, unwrapKey } from "../crypto/session";
import { decryptSecretbox } from "../crypto/session";
import { orgInitialsDataUrl, decryptOrgAvatarUrl } from "./org-avatar";

// Cache the unwrapped group key, but key the cache on the *sealed* key so we
// never reuse one circle's group key to decrypt another circle's members after
// a live-navigation (module statics persist across navigations). Reusing a
// stale key silently fails every member decrypt → empty/broken picker until a
// hard refresh wiped the static. Keying on the sealed key fixes that.
let _cachedGroupKeyForMentions = null;
let _cachedSealedKeyForMentions = null;

function normalizeVariant(value) {
  if (value === "family" || value === "business") return value;
  return "personal";
}

// Dropdown "selected option" gradient per surface. Written as literal class
// strings so Tailwind's source scanner keeps them in the build.
const DROPDOWN_SELECTED_CLASSES = {
  personal: [
    "bg-gradient-to-r",
    "from-teal-50",
    "to-emerald-50",
    "dark:from-teal-900/30",
    "dark:to-emerald-900/30",
  ],
  family: [
    "bg-gradient-to-r",
    "from-rose-50",
    "to-pink-50",
    "dark:from-rose-900/30",
    "dark:to-pink-900/30",
  ],
  business: [
    "bg-gradient-to-r",
    "from-indigo-50",
    "to-sky-50",
    "dark:from-indigo-900/30",
    "dark:to-sky-900/30",
  ],
};

const DROPDOWN_UNSELECTED_CLASSES = [
  "hover:bg-slate-50",
  "dark:hover:bg-slate-700/50",
];

async function getGroupKey(sealedKey) {
  if (_cachedGroupKeyForMentions && _cachedSealedKeyForMentions === sealedKey) {
    return _cachedGroupKeyForMentions;
  }
  const raw = await unsealContextKey(sealedKey);
  if (raw) {
    _cachedGroupKeyForMentions = unwrapKey(raw);
    _cachedSealedKeyForMentions = sealedKey;
  }
  return _cachedGroupKeyForMentions;
}

// The org_key (shared per org, sealed per member) lets us decrypt an org-mate's
// org display name. Cached per sealed key for the same cross-circle-safety
// reason as the group key above.
let _cachedOrgKeyForMentions = null;
let _cachedSealedOrgKeyForMentions = null;

async function getOrgKey(sealedOrgKey) {
  if (!sealedOrgKey) return null;
  if (_cachedOrgKeyForMentions && _cachedSealedOrgKeyForMentions === sealedOrgKey) {
    return _cachedOrgKeyForMentions;
  }
  const raw = await unsealContextKey(sealedOrgKey);
  if (raw) {
    _cachedOrgKeyForMentions = unwrapKey(raw);
    _cachedSealedOrgKeyForMentions = sealedOrgKey;
  }
  return _cachedOrgKeyForMentions;
}

window.addEventListener("mosslet:logout", () => {
  _cachedGroupKeyForMentions = null;
  _cachedSealedKeyForMentions = null;
  _cachedOrgKeyForMentions = null;
  _cachedSealedOrgKeyForMentions = null;
});

const MentionPicker = {
  _sharedMembers: [],

  safeUrl(src) {
    if (!src) return "";
    if (src.startsWith("data:image/")) return src;
    try {
      const url = new URL(src, window.location.origin);
      if (url.protocol === "http:" || url.protocol === "https:") {
        return url.href;
      }
      return "";
    } catch {
      return "";
    }
  },

  mounted() {
    this.textarea = this.el;
    this.dropdown = null;
    this.members = [];
    this.filteredMembers = [];
    this.selectedIndex = 0;
    this.mentionStart = -1;
    this.isOpen = false;
    this.mentionMap = {};

    this.form = this.textarea.closest("form");
    // Surface variant (family | business | personal) — drives tailored theming
    // while the mention mechanics stay single-sourced here.
    this.variant = normalizeVariant(this.form?.dataset?.mentionVariant);

    this.isMobile =
      /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
        navigator.userAgent
      ) ||
      (navigator.maxTouchPoints > 0 && window.innerWidth < 768);

    this.handleInput = this.handleInput.bind(this);
    this.handleKeyDown = this.handleKeyDown.bind(this);
    this.handleClickOutside = this.handleClickOutside.bind(this);
    this.handleScroll = this.handleScroll.bind(this);
    this.handleTriggerMention = this.handleTriggerMention.bind(this);
    this.handleSubmitCapture = this.handleSubmitCapture.bind(this);

    this.textarea.addEventListener("input", this.handleInput);
    this.textarea.addEventListener("keydown", this.handleKeyDown);
    this.textarea.addEventListener("trigger-mention", this.handleTriggerMention);
    document.addEventListener("click", this.handleClickOutside);

    // Convert visible @display-name mentions into @[user_group_id] tokens in the
    // capturing phase, BEFORE any other submit handler runs (the ZK encryption
    // hook on the form and LiveView's own form serialization). Capturing at the
    // document means we always run first regardless of hook mount order — this
    // is what makes mentions persist on every submit path (button, Enter, mobile).
    document.addEventListener("submit", this.handleSubmitCapture, true);

    // Members are embedded as a JSON data attribute on the form (ciphertext-only
    // for private circles — ZK-safe). We read them here in mounted() and again in
    // updated(), mirroring the DecryptGroupMetadata pattern. This is race-free:
    // unlike push_event("set_members"), LiveView does NOT buffer pushed events for
    // a hook that hasn't registered its handler yet, so on connected mount /
    // live-navigation the member list was being silently dropped (empty picker
    // until a hard refresh re-ordered things).
    this._loadMembers();
  },

  updated() {
    // A DOM patch (e.g. phx-change) may carry an updated member payload, or a
    // late key arrival may now let us decrypt one we previously couldn't.
    this._loadMembers();
  },

  async _loadMembers() {
    const json = this.form?.dataset?.members || "[]";

    // Skip redundant re-decryption on every keystroke if nothing changed and we
    // already have members. If we're still empty (keys weren't ready), retry.
    if (json === this._lastMembersJson && this.members.length > 0) return;
    this._lastMembersJson = json;

    let raw;
    try {
      raw = JSON.parse(json);
    } catch (e) {
      console.error("MentionPicker: failed to parse members payload:", e);
      raw = [];
    }

    await this._processMembers(raw);
  },

  async _processMembers(raw) {
    raw = raw || [];
    const needsDecrypt = raw.some((m) => m.browser_decrypt);

    if (!needsDecrypt) {
      this._publishMembers(raw);
      return;
    }

    const decrypted = await this._tryDecryptMembers(raw);
    if (decrypted) {
      this._publishMembers(decrypted);
      return;
    }

    // Keys not ready yet — retry once they arrive, re-reading the latest payload.
    if (!this._onMembersKeysReady) {
      this._onMembersKeysReady = () => {
        this._onMembersKeysReady = null;
        // Force a fresh attempt even if the payload string is unchanged.
        this._lastMembersJson = null;
        this._loadMembers();
      };
      window.addEventListener("mosslet:keys-ready", this._onMembersKeysReady, {
        once: true,
      });
    }
  },

  async _tryDecryptMembers(raw) {
    const sealedKey = this.form?.dataset?.sealedGroupKey;
    if (!sealedKey || !getPublicKey()) return null;

    const groupKey = await getGroupKey(sealedKey);
    if (!groupKey) return null;

    // org_key is optional — present only for org-backed (Family/Business)
    // circles. When absent, org display names simply aren't shown.
    const orgKey = await getOrgKey(this.form?.dataset?.sealedOrgKey);

    return Promise.all(raw.map((m) => this._decryptMember(m, groupKey, orgKey)));
  },

  _publishMembers(members) {
    this.members = members;
    MentionPicker._sharedMembers = members;
    window.dispatchEvent(new CustomEvent("mosslet:members-ready"));
  },

  destroyed() {
    this.textarea.removeEventListener("input", this.handleInput);
    this.textarea.removeEventListener("keydown", this.handleKeyDown);
    this.textarea.removeEventListener("trigger-mention", this.handleTriggerMention);
    document.removeEventListener("click", this.handleClickOutside);
    document.removeEventListener("submit", this.handleSubmitCapture, true);
    window.removeEventListener("scroll", this.handleScroll, true);
    if (this._onMembersKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onMembersKeysReady);
      this._onMembersKeysReady = null;
    }
    if (this.dropdown && this.dropdown.parentNode) {
      this.dropdown.parentNode.removeChild(this.dropdown);
      this.dropdown = null;
    }
    this.isOpen = false;
  },

  handleSubmitCapture(e) {
    if (e.target !== this.form) return;
    this.applyMentionTokens();
  },

  // Replace every visible "@display-name" with its "@[user_group_id]" token so
  // the downstream consumer (ZK encryption hook or LiveView) sees only tokens.
  // Idempotent: once converted the map is cleared, so re-entrant submits are no-ops.
  applyMentionTokens() {
    if (!this.textarea) return;
    const converted = this.convertMentionsToTokens(this.textarea.value);
    if (converted !== this.textarea.value) {
      this.textarea.value = converted;
    }
    this.mentionMap = {};
    this.hideDropdown();
  },

  handleTriggerMention() {
    const { value, selectionStart } = this.textarea;
    const beforeCursor = value.substring(0, selectionStart);
    const afterCursor = value.substring(selectionStart);

    const newValue = beforeCursor + "@" + afterCursor;
    this.textarea.value = newValue;
    this.textarea.setSelectionRange(selectionStart + 1, selectionStart + 1);
    this.textarea.focus();

    this.textarea.dispatchEvent(new Event("input", { bubbles: true }));
  },

  handleInput(e) {
    const { value, selectionStart } = this.textarea;
    const textBeforeCursor = value.substring(0, selectionStart);
    const atMatch = textBeforeCursor.match(/@(\w*)$/);

    if (atMatch) {
      this.mentionStart = selectionStart - atMatch[0].length;
      const query = atMatch[1].toLowerCase();
      this.filterMembers(query);

      if (this.filteredMembers.length > 0) {
        this.showDropdown();
      } else {
        this.hideDropdown();
      }
    } else {
      this.hideDropdown();
    }
  },

  handleKeyDown(e) {
    if (this.isOpen) {
      switch (e.key) {
        case "ArrowDown":
          e.preventDefault();
          e.stopPropagation();
          this.selectedIndex = Math.min(
            this.selectedIndex + 1,
            this.filteredMembers.length - 1
          );
          this.updateSelection();
          return;
        case "ArrowUp":
          e.preventDefault();
          e.stopPropagation();
          this.selectedIndex = Math.max(this.selectedIndex - 1, 0);
          this.updateSelection();
          return;
        case "Enter":
        case "Tab":
          if (this.filteredMembers.length > 0) {
            e.preventDefault();
            e.stopPropagation();
            this.selectMember(this.filteredMembers[this.selectedIndex]);
          }
          return;
        case "Escape":
          e.preventDefault();
          this.hideDropdown();
          return;
      }
    }

    if (this.isMobile) return;

    if (e.key === "Enter" && !e.shiftKey && !e.ctrlKey && !e.altKey && !e.metaKey) {
      const value = this.textarea.value.trim();
      if (value) {
        e.preventDefault();
        const form = this.textarea.closest("form");
        if (form) {
          // Token conversion happens in the document-capture submit handler.
          form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
        }
      }
    }
  },

  handleClickOutside(e) {
    if (
      this.dropdown &&
      !this.dropdown.contains(e.target) &&
      e.target !== this.textarea
    ) {
      this.hideDropdown();
    }
  },

  handleScroll() {
    if (this.isOpen) {
      this.positionDropdown();
    }
  },

  filterMembers(query) {
    if (!query) {
      this.filteredMembers = this.members.slice(0, 8);
    } else {
      this.filteredMembers = this.members
        .filter(
          (m) =>
            (m.moniker && m.moniker.toLowerCase().includes(query)) ||
            (m.username && m.username.toLowerCase().includes(query))
        )
        .slice(0, 8);
    }
    this.selectedIndex = 0;
  },

  showDropdown() {
    if (!this.dropdown) {
      this.createDropdown();
    }
    this.renderMembers();
    this.positionDropdown();
    this.dropdown.classList.remove("hidden");
    this.isOpen = true;

    window.addEventListener("scroll", this.handleScroll, true);
  },

  hideDropdown() {
    if (this.dropdown) {
      this.dropdown.classList.add("hidden");
    }
    this.isOpen = false;
    this.mentionStart = -1;
    window.removeEventListener("scroll", this.handleScroll, true);
  },

  createDropdown() {
    this.dropdown = document.createElement("div");
    this.dropdown.id = "mention-picker-dropdown";
    this.dropdown.className = `
      absolute z-[9999] hidden
      w-72 max-h-64 overflow-y-auto
      bg-white/95 dark:bg-slate-800/95 backdrop-blur-xl
      border border-slate-200/60 dark:border-slate-700/60
      rounded-xl shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30
      py-1.5
    `;
    this.dropdown.setAttribute("role", "listbox");
    this.dropdown.setAttribute("aria-label", "Mention suggestions");

    document.body.appendChild(this.dropdown);
  },

  positionDropdown() {
    if (!this.dropdown) return;

    const rect = this.textarea.getBoundingClientRect();
    const caretCoords = this.getCaretCoordinates();

    let top = rect.top + caretCoords.top - this.textarea.scrollTop - 8;
    let left = rect.left + caretCoords.left;

    const dropdownHeight = Math.min(this.filteredMembers.length * 52 + 12, 260);

    if (top - dropdownHeight < 10) {
      top = rect.top + caretCoords.top - this.textarea.scrollTop + 24;
      this.dropdown.style.transform = "translateY(0)";
    } else {
      top = top - dropdownHeight;
      this.dropdown.style.transform = "translateY(0)";
    }

    if (left + 288 > window.innerWidth) {
      left = window.innerWidth - 288 - 16;
    }

    this.dropdown.style.position = "fixed";
    this.dropdown.style.top = `${top}px`;
    this.dropdown.style.left = `${Math.max(16, left)}px`;
  },

  getCaretCoordinates() {
    const { selectionStart, value } = this.textarea;
    const textBeforeCursor = value.substring(0, selectionStart);
    const lines = textBeforeCursor.split("\n");
    const currentLine = lines.length - 1;
    const currentColumn = lines[lines.length - 1].length;

    const lineHeight = parseInt(
      window.getComputedStyle(this.textarea).lineHeight
    );
    const fontSize = parseInt(window.getComputedStyle(this.textarea).fontSize);

    return {
      top: currentLine * (lineHeight || fontSize * 1.5) + 16,
      left: Math.min(currentColumn * (fontSize * 0.55), 200),
    };
  },

  renderMembers() {
    if (!this.dropdown) return;

    if (this.filteredMembers.length === 0) {
      this.dropdown.innerHTML = `
        <div class="px-4 py-3 text-sm text-slate-500 dark:text-slate-400 text-center">
          No members found
        </div>
      `;
      return;
    }

    this.dropdown.innerHTML = this.filteredMembers
      .map(
        (member, index) => `
        <button
          type="button"
          role="option"
          aria-selected="${index === this.selectedIndex}"
          data-index="${index}"
          data-user-group-id="${member.user_group_id}"
          class="mention-option w-full px-3 py-2.5 flex items-center gap-3 text-left transition-all duration-150
            ${
              index === this.selectedIndex
                ? DROPDOWN_SELECTED_CLASSES[this.variant].join(" ")
                : DROPDOWN_UNSELECTED_CLASSES.join(" ")
            }"
        >
          <div class="relative flex-shrink-0">
            <img 
              src="${this.safeUrl(member.avatar_src) || '/images/logo.svg'}" 
              alt="" 
              class="w-9 h-9 rounded-full object-cover ring-2 ring-offset-1 ring-offset-white dark:ring-offset-slate-800 ${this.getRoleRingColor(member.role)}"
            />
            ${
              member.role !== "member"
                ? `
              <div class="absolute -bottom-0.5 -right-0.5 w-4 h-4 rounded-full ${this.getRoleBadgeColor(member.role)} flex items-center justify-center">
                <svg class="w-2.5 h-2.5 text-white" fill="currentColor" viewBox="0 0 20 20">
                  ${this.getRoleIcon(member.role)}
                </svg>
              </div>
            `
                : ""
            }
          </div>
          <div class="flex-1 min-w-0">
            ${
              (member.username || member.org_display_name)
                ? `
              <div class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                ${this.escapeHtml(member.username || member.org_display_name)}
              </div>
            `
                : ""
            }
            <div class="flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
              <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M6.625 2.655A9 9 0 0119 11a1 1 0 11-2 0 7 7 0 00-9.625-6.492 1 1 0 11-.75-1.853zM4.662 4.959A1 1 0 014.75 6.37 6.97 6.97 0 003 11a1 1 0 11-2 0 8.97 8.97 0 012.25-5.953 1 1 0 011.412-.088z" clip-rule="evenodd"/>
                <path fill-rule="evenodd" d="M5 11a5 5 0 1110 0 1 1 0 11-2 0 3 3 0 10-6 0c0 1.677-.345 3.276-.968 4.729a1 1 0 11-1.838-.789A9.964 9.964 0 005 11z" clip-rule="evenodd"/>
              </svg>
              <span class="truncate">${this.escapeHtml(member.moniker)}</span>
            </div>
          </div>
        </button>
      `
      )
      .join("");

    this.dropdown.querySelectorAll(".mention-option").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        const index = parseInt(btn.dataset.index);
        this.selectMember(this.filteredMembers[index]);
      });
    });
  },

  updateSelection() {
    if (!this.dropdown) return;

    const selectedClasses = DROPDOWN_SELECTED_CLASSES[this.variant];

    this.dropdown.querySelectorAll(".mention-option").forEach((btn, index) => {
      const isSelected = index === this.selectedIndex;
      btn.setAttribute("aria-selected", isSelected);

      if (isSelected) {
        btn.classList.add(...selectedClasses);
        btn.classList.remove(...DROPDOWN_UNSELECTED_CLASSES);
        btn.scrollIntoView({ block: "nearest" });
      } else {
        btn.classList.remove(...selectedClasses);
        btn.classList.add(...DROPDOWN_UNSELECTED_CLASSES);
      }
    });
  },

  selectMember(member) {
    if (!member || this.mentionStart < 0) return;

    const { value, selectionStart } = this.textarea;
    const beforeMention = value.substring(0, this.mentionStart);
    const afterCursor = value.substring(selectionStart);

    const displayName = member.is_connected ? member.username : member.moniker;
    const displayText = `@${displayName} `;
    this.mentionMap[displayName] = member.user_group_id;

    const newValue = beforeMention + displayText + afterCursor;
    this.textarea.value = newValue;

    const newCursorPos = this.mentionStart + displayText.length;
    this.textarea.setSelectionRange(newCursorPos, newCursorPos);
    this.textarea.focus();

    this.textarea.dispatchEvent(new Event("input", { bubbles: true }));

    this.hideDropdown();
  },

  convertMentionsToTokens(text) {
    let result = text;
    for (const [moniker, id] of Object.entries(this.mentionMap)) {
      const escapedMoniker = moniker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const pattern = new RegExp(`@${escapedMoniker}(?=\\s|$)`, 'g');
      result = result.replace(pattern, `@[${id}]`);
    }
    return result;
  },

  getRoleRingColor(role) {
    switch (role) {
      case "owner":
        return "ring-amber-400 dark:ring-amber-500";
      case "admin":
        return "ring-purple-400 dark:ring-purple-500";
      case "moderator":
        return "ring-blue-400 dark:ring-blue-500";
      default:
        return "ring-slate-300 dark:ring-slate-600";
    }
  },

  getRoleBadgeColor(role) {
    switch (role) {
      case "owner":
        return "bg-gradient-to-br from-amber-400 to-amber-500";
      case "admin":
        return "bg-gradient-to-br from-purple-400 to-purple-500";
      case "moderator":
        return "bg-gradient-to-br from-blue-400 to-blue-500";
      default:
        return "bg-slate-400";
    }
  },

  getRoleIcon(role) {
    switch (role) {
      case "owner":
        return '<path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>';
      case "admin":
        return '<path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>';
      case "moderator":
        return '<path fill-rule="evenodd" d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z" clip-rule="evenodd"/>';
      default:
        return "";
    }
  },

  escapeHtml(text) {
    if (!text) return "";
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  },

  async _decryptMember(member, groupKey, orgKey) {
    if (!member.browser_decrypt) return member;

    const result = { ...member };

    try {
      if (member.encrypted_moniker) {
        result.moniker = await decryptWithKey(member.encrypted_moniker, groupKey) || "member";
      }

      if (member.encrypted_username && member.sealed_conn_key) {
        const rawConnKey = await unsealContextKey(member.sealed_conn_key);
        if (rawConnKey) {
          const connKey = unwrapConnKey(rawConnKey);
          const username = await decryptWithKey(member.encrypted_username, connKey);
          if (username) result.username = username;
        }
      }

      // Org-scoped display name (ZK): recognizable persona for org-mates the
      // viewer isn't personally connected to. Decrypted with the shared org_key.
      if (member.encrypted_org_display_name && orgKey && !member.is_self) {
        const orgName = await decryptWithKey(member.encrypted_org_display_name, orgKey);
        if (orgName) result.org_display_name = orgName;
      }

      if (member.encrypted_avatar_img && !member.is_self) {
        const avatarImg = await decryptWithKey(member.encrypted_avatar_img, groupKey);
        if (avatarImg && avatarImg !== "") {
          result.avatar_src = `/images/groups/${avatarImg}`;
        }
      }

      if (member.encrypted_avatar && !member.is_self) {
        const avatarDataUrl = await this._decryptConnectionAvatar(member.encrypted_avatar);
        if (avatarDataUrl) {
          result.avatar_src = avatarDataUrl;
        }
      }

      // Org-scoped display AVATAR (Task #277): for a non-connected org-mate,
      // prefer their org avatar (or initials from their org name) over the
      // generic circle avatar — persona separation, never the personal avatar.
      // Connected members already showed their personal avatar above and carry
      // no org-avatar ciphertext, so this only affects org-only relationships.
      if (orgKey && !member.is_self && (member.encrypted_org_avatar || result.org_display_name)) {
        const orgAvatarUrl = await decryptOrgAvatarUrl(member.encrypted_org_avatar, orgKey);
        const url = orgAvatarUrl || orgInitialsDataUrl(result.org_display_name);
        if (url) result.avatar_src = url;
      }

      // Family guardian safety override (Task #284): if the VIEWER is an active
      // guardian of this member (server-authoritative — the member carries their
      // conn_key sealed for this guardian), show the member's PERSONAL avatar so
      // a minor can't hide behind a misleading org avatar. Takes precedence over
      // the org avatar/initials above.
      if (member.guardian_avatar_blob && member.guardian_sealed_key && !member.is_self) {
        const personalUrl = await this._decryptConnectionAvatar({
          encrypted_blob_b64: member.guardian_avatar_blob,
          sealed_key: member.guardian_sealed_key,
        });
        if (personalUrl) result.avatar_src = personalUrl;
      }

      if (!result.avatar_src && !member.is_self) {
        result.avatar_src = "/images/groups/default.png";
      }
    } catch (e) {
      console.error("MentionPicker: failed to decrypt member:", e);
      result.moniker = result.moniker || "member";
    }

    return result;
  },

  async _decryptConnectionAvatar(encryptedData) {
    if (!encryptedData?.encrypted_blob_b64 || !encryptedData?.sealed_key) return null;

    try {
      const rawKey = await unsealContextKey(encryptedData.sealed_key);
      if (!rawKey) return null;

      const connKey = unwrapConnKey(rawKey);

      const rawBytes = await decryptSecretbox(encryptedData.encrypted_blob_b64, connKey);
      let imageBase64;
      if (rawBytes) {
        let binary = "";
        for (let i = 0; i < rawBytes.length; i++) {
          binary += String.fromCharCode(rawBytes[i]);
        }
        imageBase64 = btoa(binary);
      } else {
        imageBase64 = await decryptWithKey(encryptedData.encrypted_blob_b64, connKey);
        if (!imageBase64) return null;
      }

      return `data:image/webp;base64,${imageBase64}`;
    } catch (e) {
      console.error("MentionPicker: failed to decrypt connection avatar:", e);
      return null;
    }
  },
};

export default MentionPicker;
