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
    // Find all reply buttons and restore their icon state based on composer open status
    const replyButtons = document.querySelectorAll('[id^="reply-button-"][data-composer-open]');
    
    replyButtons.forEach(button => {
      const isOpen = button.getAttribute('data-composer-open') === 'true';
      const iconOutline = button.querySelector('.reply-icon-outline');
      const iconFilled = button.querySelector('.reply-icon-filled');
      
      if (iconOutline && iconFilled) {
        if (isOpen) {
          // Composer is open - show filled icon, hide outline
          iconOutline.classList.add('hidden');
          iconFilled.classList.remove('hidden');
        } else {
          // Composer is closed - show outline icon, hide filled
          iconOutline.classList.remove('hidden');
          iconFilled.classList.add('hidden');
        }
      }
    });
  },

  initialize() {
    // Add event listener for hiding the reply composer
    this.handleEvent("hide-reply-composer", ({ post_id }) => {
      // Explicitly close the composer (don't toggle, actually close it)
      
      // 1. Hide the composer using explicit style
      const composer = document.getElementById(`reply-composer-${post_id}`);
      if (composer) {
        composer.classList.add("hidden");
        composer.style.display = "none"; // Force hide with inline style
      }
      
      // 2. Remove ring from card (close state)
      const card = document.getElementById(`timeline-card-${post_id}`);
      if (card) {
        card.classList.remove("ring-2", "ring-emerald-300");
      }
      
      // 3. Hide any filled icons (close state)
      const button = document.getElementById(`reply-button-${post_id}`);
      if (button) {
        const iconFilled = button.querySelector(".reply-icon-filled");
        if (iconFilled) {
          iconFilled.classList.add("hidden");
        }
      }
      
      // 4. Set composer to closed state
      if (button) {
        button.setAttribute("data-composer-open", "false");
      }
    });

    // Add event listener for showing the reply composer 
    this.handleEvent("show-reply-composer", ({ post_id }) => {
      const composer = document.getElementById(`reply-composer-${post_id}`);
      if (composer) {
        composer.classList.remove("hidden");
        composer.style.display = "block"; // Force show with inline style
        // Focus the textarea
        const textarea = composer.querySelector(`#reply-textarea-${post_id}`);
        if (textarea) {
          textarea.focus();
        }
      }
    });
  }
};