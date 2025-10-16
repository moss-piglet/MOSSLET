import data from "../../vendor/@emoji-mart/data";
import { Picker } from "../../vendor/emoji-mart";

const ComposerEmojiPicker = {
  mounted() {
    this.pickerInstance = null;
    this.isPickerVisible = false;

    this.handleClickOutside = (event) => {
      // Don't close if clicking inside the emoji picker itself
      if (
        this.pickerInstance &&
        !this.el.contains(event.target) &&
        !this.pickerContainer?.contains(event.target)
      ) {
        this.hidePicker();
      }
    };

    // Listen for theme changes
    this.handleThemeChange = (event) => {
      if (this.isPickerVisible && this.pickerInstance) {
        // Recreate picker with new theme and styling
        this.hidePicker();
        setTimeout(() => this.showPicker(), 100);
      }
    };

    this.el.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      this.togglePicker();
    });

    // Listen for theme changes
    document.addEventListener("phx:set-theme", this.handleThemeChange);
  },

  destroyed() {
    this.hidePicker();
    document.removeEventListener("click", this.handleClickOutside);
    document.removeEventListener("phx:set-theme", this.handleThemeChange);
  },

  togglePicker() {
    if (this.isPickerVisible) {
      this.hidePicker();
    } else {
      this.showPicker();
    }
  },

  showPicker() {
    if (this.pickerInstance) {
      this.hidePicker();
    }

    // Find the textarea
    const textarea = document.getElementById("new-timeline-composer-textarea");
    if (!textarea) return;

    // Create picker container - append to body to avoid overflow issues
    const pickerContainer = document.createElement("div");
    pickerContainer.className = "fixed z-[9999]";

    // Hide initially to prevent style flash
    pickerContainer.style.opacity = "0";
    pickerContainer.style.transform = "scale(0.95)";
    pickerContainer.style.transition =
      "opacity 200ms ease-out, transform 200ms ease-out";

    // Position picker relative to the button
    const buttonRect = this.el.getBoundingClientRect();
    const spaceBelow = window.innerHeight - buttonRect.bottom;
    const spaceAbove = buttonRect.top;

    // Position picker below button if there's space, otherwise above
    if (spaceBelow >= 450) {
      // Show below
      pickerContainer.style.top = `${buttonRect.bottom + 8}px`;
    } else {
      // Show above
      pickerContainer.style.top = `${buttonRect.top - 450 - 8}px`;
    }

    // Align with button horizontally, but stay within viewport
    let leftPos = buttonRect.left;
    if (leftPos + 352 > window.innerWidth) {
      leftPos = window.innerWidth - 352 - 16; // 352px picker width + 16px margin
    }
    pickerContainer.style.left = `${Math.max(16, leftPos)}px`;

    document.body.appendChild(pickerContainer);

    // Detect current theme manually since auto doesn't work reliably
    const documentTheme = document.documentElement.getAttribute("data-theme");
    const isDark =
      documentTheme === "dark" ||
      (documentTheme === "system" &&
        window.matchMedia("(prefers-color-scheme: dark)").matches);
    const theme = isDark ? "dark" : "light";

    // Create emoji picker with detected theme and custom liquid metal styling
    this.pickerInstance = new Picker({
      data: data,
      parent: pickerContainer,
      theme: theme,
      emojiButtonColors: ["oklch(69.6% 0.17 162.48)"], // Teal color from design system
      // Custom liquid metal styling
      custom: [
        {
          id: "liquid-metal-theme",
          name: "Liquid Metal",
          emojis: [],
        },
      ],
      onEmojiSelect: (emoji) => {
        this.insertEmoji(emoji, textarea);
        this.hidePicker();
      },
    });

    // Apply custom liquid metal styling immediately, then show picker
    setTimeout(() => {
      this.applyLiquidMetalStyling(theme);
      // Show picker with smooth animation after styles are applied
      setTimeout(() => {
        if (pickerContainer) {
          pickerContainer.style.opacity = "1";
          pickerContainer.style.transform = "scale(1)";
        }
      }, 50); // Small delay to ensure styles are applied
    }, 50); // Reduced delay to minimize flash

    this.pickerContainer = pickerContainer;
    this.isPickerVisible = true;

    // Add click outside listener
    setTimeout(() => {
      document.addEventListener("click", this.handleClickOutside);
    }, 100);
  },

  hidePicker() {
    if (this.pickerContainer) {
      this.pickerContainer.remove();
      this.pickerContainer = null;
    }
    this.pickerInstance = null;
    this.isPickerVisible = false;
    document.removeEventListener("click", this.handleClickOutside);
  },

  applyLiquidMetalStyling(theme) {
    if (!this.pickerInstance || !this.pickerContainer) return;

    const emojiMart = this.pickerContainer.querySelector("em-emoji-picker");
    if (!emojiMart) {
      // Retry if emoji-mart element isn't ready yet
      setTimeout(() => this.applyLiquidMetalStyling(theme), 20);
      return;
    }

    if (!emojiMart.shadowRoot) {
      // Wait for shadow root to be available
      setTimeout(() => this.applyLiquidMetalStyling(theme), 20);
      return;
    }

    // Create custom CSS for liquid metal styling - immediate application to prevent flash
    const liquidMetalCSS = `
      <style>
        /* Immediately hide default styling to prevent flash */
        * {
          transition: none !important;
        }
        
        :host {
          --border-radius: 16px !important;
          --font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif !important;
          border-radius: 16px !important;
          overflow: hidden !important;
          backdrop-filter: blur(16px) !important;
          ${
            theme === "dark"
              ? `
            --em-rgb-background: 30, 41, 59 !important;
            --em-rgb-input: 15, 23, 42 !important;
            --em-color-border: rgba(148, 163, 184, 0.2) !important;
            --em-color-border-over: rgba(148, 163, 184, 0.3) !important;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(148, 163, 184, 0.1) !important;
          `
              : `
            --em-rgb-background: 255, 255, 255 !important;
            --em-rgb-input: 248, 250, 252 !important;
            --em-color-border: rgba(148, 163, 184, 0.2) !important;
            --em-color-border-over: rgba(148, 163, 184, 0.3) !important;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(148, 163, 184, 0.1) !important;
          `
          }
        }
        
        #root {
          border-radius: 16px !important;
          ${
            theme === "dark"
              ? `
            background: rgba(30, 41, 59, 0.95) !important;
          `
              : `
            background: rgba(255, 255, 255, 0.95) !important;
          `
          }
        }
        
        /* Search input liquid metal styling */
        .search input {
          border-radius: 12px !important;
          border: 1px solid var(--em-color-border) !important;
          transition: all 200ms ease-out !important;
          ${
            theme === "dark"
              ? `
            background: rgba(15, 23, 42, 0.8) !important;
            color: rgb(226, 232, 240) !important;
          `
              : `
            background: rgba(248, 250, 252, 0.8) !important;
            color: rgb(30, 41, 59) !important;
          `
          }
        }
        
        .search input:focus {
          border-color: rgba(20, 184, 166, 0.5) !important;
          box-shadow: 0 0 0 3px rgba(20, 184, 166, 0.1) !important;
          outline: none !important;
        }
        
        /* Category buttons liquid metal styling */
        .nav button {
          border-radius: 10px !important;
          transition: all 200ms ease-out !important;
          position: relative !important;
          overflow: hidden !important;
        }
        
        .nav button:hover {
          ${
            theme === "dark"
              ? `
            background: rgba(20, 184, 166, 0.1) !important;
          `
              : `
            background: rgba(20, 184, 166, 0.05) !important;
          `
          }
          transform: translateY(-1px) !important;
        }
        
        .nav button[aria-selected="true"] {
          background: linear-gradient(135deg, rgba(20, 184, 166, 0.15), rgba(16, 185, 129, 0.15)) !important;
          ${
            theme === "dark"
              ? `
            color: rgb(94, 234, 212) !important;
          `
              : `
            color: rgb(13, 148, 136) !important;
          `
          }
        }
        
        /* Emoji button hover effects */
        .emoji button {
          border-radius: 8px !important;
          transition: all 150ms ease-out !important;
          position: relative !important;
        }
        
        .emoji button:hover {
          transform: scale(1.1) !important;
          ${
            theme === "dark"
              ? `
            background: rgba(20, 184, 166, 0.1) !important;
          `
              : `
            background: rgba(20, 184, 166, 0.05) !important;
          `
          }
          box-shadow: 0 4px 12px rgba(20, 184, 166, 0.15) !important;
        }
        
        /* Category header styling - matches liquid metal design */
        .sticky {
          ${
            theme === "dark"
              ? `
            background: rgba(30, 41, 59, 0.95) !important;
            color: rgb(148, 163, 184) !important;
            border-bottom: 1px solid rgba(148, 163, 184, 0.1) !important;
          `
              : `
            background: rgba(255, 255, 255, 0.95) !important;
            color: rgb(71, 85, 105) !important;
            border-bottom: 1px solid rgba(148, 163, 184, 0.1) !important;
          `
          }
          backdrop-filter: blur(8px) !important;
          font-weight: 600 !important;
          font-size: 13px !important;
          text-transform: uppercase !important;
          letter-spacing: 0.05em !important;
          padding: 8px 12px !important;
        }
        
        /* Main content area to ensure consistent background */
        .scroll {
          ${
            theme === "dark"
              ? `
            background: rgba(30, 41, 59, 0.95) !important;
          `
              : `
            background: rgba(255, 255, 255, 0.95) !important;
          `
          }
        }
        
        /* Category sections */
        .category {
          ${
            theme === "dark"
              ? `
            background: rgba(30, 41, 59, 0.95) !important;
          `
              : `
            background: rgba(255, 255, 255, 0.95) !important;
          `
          }
        }
        
        /* Scrollbar styling */
        ::-webkit-scrollbar {
          width: 8px !important;
        }
        
        ::-webkit-scrollbar-track {
          background: transparent !important;
        }
        
        ::-webkit-scrollbar-thumb {
          ${
            theme === "dark"
              ? `
            background: rgba(148, 163, 184, 0.3) !important;
          `
              : `
            background: rgba(148, 163, 184, 0.4) !important;
          `
          }
          border-radius: 4px !important;
        }
        
        ::-webkit-scrollbar-thumb:hover {
          background: rgba(20, 184, 166, 0.5) !important;
        }
        
        /* Re-enable transitions after initial styling */
        * {
          transition: all 150ms ease-out !important;
        }
      </style>
    `;

    // Insert custom CSS into shadow root as first child for immediate application
    const existingStyle = emojiMart.shadowRoot.querySelector(
      "#liquid-metal-style"
    );
    if (existingStyle) {
      existingStyle.remove();
    }

    const styleElement = document.createElement("div");
    styleElement.id = "liquid-metal-style";
    styleElement.innerHTML = liquidMetalCSS;

    // Insert at the beginning to ensure it loads first
    const firstChild = emojiMart.shadowRoot.firstChild;
    if (firstChild) {
      emojiMart.shadowRoot.insertBefore(styleElement, firstChild);
    } else {
      emojiMart.shadowRoot.appendChild(styleElement);
    }
  },

  insertEmoji(emoji, textarea) {
    const startPos = textarea.selectionStart;
    const endPos = textarea.selectionEnd;
    const textBefore = textarea.value.substring(0, startPos);
    const textAfter = textarea.value.substring(endPos);

    // Insert emoji at cursor position
    const newValue = textBefore + emoji.native + textAfter;
    textarea.value = newValue;

    // Update cursor position after emoji
    const newCursorPos = startPos + emoji.native.length;
    textarea.setSelectionRange(newCursorPos, newCursorPos);

    // Focus back to textarea
    textarea.focus();

    // Trigger input event to update character counter and form state
    textarea.dispatchEvent(new Event("input", { bubbles: true }));

    // Trigger change event for LiveView
    textarea.dispatchEvent(new Event("change", { bubbles: true }));
  },
};

export default ComposerEmojiPicker;
