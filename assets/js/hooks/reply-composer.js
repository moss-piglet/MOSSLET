export default {
  mounted() {
    this.setupTextareaFocus();
    this.setupKeyboardShortcuts();
  },

  updated() {
    this.setupTextareaFocus();
  },

  destroyed() {
    if (this.keydownHandler) {
      document.removeEventListener("keydown", this.keydownHandler);
    }
  },

  setupKeyboardShortcuts() {
    this.keydownHandler = (e) => {
      if (e.key !== "c") return;

      const activeEl = document.activeElement;
      const tagName = activeEl?.tagName?.toUpperCase() || "";
      const isInput = ["INPUT", "TEXTAREA", "SELECT"].includes(tagName);
      const isEditable = activeEl?.isContentEditable;

      if (isInput || isEditable) return;

      this.pushEvent("open_composer_keyboard", {});
    };

    document.addEventListener("keydown", this.keydownHandler);
  },

  setupTextareaFocus() {
    const composers = document.querySelectorAll('[id^="reply-composer-"]:not(.hidden)');
    composers.forEach(composer => {
      const postId = composer.id.replace('reply-composer-', '');
      const textarea = document.getElementById(`reply-textarea-${postId}`);
      if (textarea && !composer._focusSetup) {
        composer._focusSetup = true;
        setTimeout(() => textarea.focus(), 100);
      }
    });
  }
};
