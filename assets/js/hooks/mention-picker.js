const MentionPicker = {
  mounted() {
    this.textarea = this.el;
    this.dropdown = null;
    this.members = [];
    this.filteredMembers = [];
    this.selectedIndex = 0;
    this.mentionStart = -1;
    this.isOpen = false;
    this.mentionMap = {};

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
    this.handleFormSubmit = this.handleFormSubmit.bind(this);

    this.textarea.addEventListener("input", this.handleInput);
    this.textarea.addEventListener("keydown", this.handleKeyDown);
    this.textarea.addEventListener("trigger-mention", this.handleTriggerMention);
    document.addEventListener("click", this.handleClickOutside);

    this.form = this.textarea.closest("form");
    if (this.form) {
      this.form.addEventListener("submit", this.handleFormSubmit);
    }

    this.handleEvent("set_members", ({ members }) => {
      this.members = members || [];
    });
  },

  destroyed() {
    this.textarea.removeEventListener("input", this.handleInput);
    this.textarea.removeEventListener("keydown", this.handleKeyDown);
    this.textarea.removeEventListener("trigger-mention", this.handleTriggerMention);
    document.removeEventListener("click", this.handleClickOutside);
    if (this.form) {
      this.form.removeEventListener("submit", this.handleFormSubmit);
    }
    this.hideDropdown();
  },

  handleFormSubmit(e) {
    const convertedContent = this.convertMentionsToTokens(this.textarea.value);
    this.textarea.value = convertedContent;
    this.mentionMap = {};
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
          const convertedContent = this.convertMentionsToTokens(value);

          const formData = new FormData(form);
          const params = {};
          for (const [key, val] of formData.entries()) {
            const keys = key.match(/[^\[\]]+/g);
            if (keys.length === 1) {
              params[keys[0]] = val;
            } else {
              let obj = params;
              for (let i = 0; i < keys.length - 1; i++) {
                obj[keys[i]] = obj[keys[i]] || {};
                obj = obj[keys[i]];
              }
              obj[keys[keys.length - 1]] = val;
            }
          }

          if (params.group_message && params.group_message.content !== undefined) {
            params.group_message.content = convertedContent;
          }

          this.textarea.value = "";
          this.mentionMap = {};
          this.textarea.dispatchEvent(new Event("input", { bubbles: true }));

          const target = form.getAttribute("phx-target");
          if (target) {
            this.pushEventTo(target, "save", params);
          } else {
            this.pushEvent("save", params);
          }
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
            (m.name && m.name.toLowerCase().includes(query))
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
                ? "bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/30 dark:to-emerald-900/30"
                : "hover:bg-slate-50 dark:hover:bg-slate-700/50"
            }"
        >
          <div class="relative flex-shrink-0">
            <img 
              src="${member.avatar_src}" 
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
              member.name
                ? `
              <div class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                ${this.escapeHtml(member.name)}
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

    this.dropdown.querySelectorAll(".mention-option").forEach((btn, index) => {
      const isSelected = index === this.selectedIndex;
      btn.setAttribute("aria-selected", isSelected);

      if (isSelected) {
        btn.classList.add(
          "bg-gradient-to-r",
          "from-teal-50",
          "to-emerald-50",
          "dark:from-teal-900/30",
          "dark:to-emerald-900/30"
        );
        btn.classList.remove("hover:bg-slate-50", "dark:hover:bg-slate-700/50");
        btn.scrollIntoView({ block: "nearest" });
      } else {
        btn.classList.remove(
          "bg-gradient-to-r",
          "from-teal-50",
          "to-emerald-50",
          "dark:from-teal-900/30",
          "dark:to-emerald-900/30"
        );
        btn.classList.add("hover:bg-slate-50", "dark:hover:bg-slate-700/50");
      }
    });
  },

  selectMember(member) {
    if (!member || this.mentionStart < 0) return;

    const { value, selectionStart } = this.textarea;
    const beforeMention = value.substring(0, this.mentionStart);
    const afterCursor = value.substring(selectionStart);

    const displayName = member.name || member.moniker;
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
};

export default MentionPicker;
