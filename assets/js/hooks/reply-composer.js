export default {
  mounted() {
    // Restore icon state on mount/update (after LiveView re-renders)
    this.restoreIconState();
  },

  updated() {
    // Restore icon state after LiveView updates (like after successful reply submission)
    this.restoreIconState();
  },

  restoreIconState() {
    const replyButtons = document.querySelectorAll('[id^="reply-button-"][data-composer-open]');
    
    replyButtons.forEach(button => {
      const isOpen = button.getAttribute('data-composer-open') === 'true';
      const icon = button.querySelector('[id^="reply-icon-"]');
      
      if (icon) {
        const classes = icon.className.split(' ');
        const filteredClasses = classes.filter(c => 
          !c.startsWith('hero-chat-bubble-oval-left')
        );
        const targetIconClass = isOpen ? 'hero-chat-bubble-oval-left-solid' : 'hero-chat-bubble-oval-left';
        filteredClasses.push(targetIconClass);
        icon.className = filteredClasses.join(' ');
      }
    });
  },

  initialize() {
    this.handleEvent("hide-reply-composer", ({ post_id }) => {
      const composer = document.getElementById(`reply-composer-${post_id}`);
      if (composer) {
        composer.classList.add("hidden");
        composer.style.display = "none";
      }
      
      const card = document.getElementById(`timeline-card-${post_id}`);
      if (card) {
        card.classList.remove("ring-2", "ring-emerald-300");
      }
      
      const button = document.getElementById(`reply-button-${post_id}`);
      const icon = button?.querySelector('[id^="reply-icon-"]');
      if (icon) {
        const classes = icon.className.split(' ');
        const filteredClasses = classes.filter(c => 
          !c.startsWith('hero-chat-bubble-oval-left')
        );
        filteredClasses.push('hero-chat-bubble-oval-left');
        icon.className = filteredClasses.join(' ');
      }
      
      if (button) {
        button.setAttribute("data-composer-open", "false");
      }
    });

    this.handleEvent("show-reply-composer", ({ post_id }) => {
      const composer = document.getElementById(`reply-composer-${post_id}`);
      if (composer) {
        composer.classList.remove("hidden");
        composer.style.display = "block";
        const textarea = composer.querySelector(`#reply-textarea-${post_id}`);
        if (textarea) {
          textarea.focus();
        }
      }
    });
  }
};