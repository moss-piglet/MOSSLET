export default {
  mounted() {
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