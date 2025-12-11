export default {
  mounted() {
    this.setupTextareaFocus();
  },

  updated() {
    this.setupTextareaFocus();
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
