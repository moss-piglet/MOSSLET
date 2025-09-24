export default {
  mounted() {
    // Add event listener for hiding the nested reply composer
    this.handleEvent("hide-nested-reply-composer", ({ reply_id }) => {
      // Explicitly close the nested composer (don't toggle, actually close it)
      
      // 1. Hide the nested composer using explicit style
      const composer = document.getElementById(`nested-composer-${reply_id}`);
      if (composer) {
        composer.classList.add("hidden");
        composer.style.display = "none"; // Force hide with inline style
      }
      
      // 2. Reset the reply button state to closed
      const button = document.getElementById(`reply-button-${reply_id}`);
      if (button) {
        // Remove active styling
        button.classList.remove("text-emerald-600", "dark:text-emerald-400");
        // Set composer to closed state
        button.setAttribute("data-composer-open", "false");
      }
      
      // 3. Clear any form content in the nested composer
      const textarea = composer?.querySelector(`#nested-reply-textarea-${reply_id}`);
      if (textarea) {
        textarea.value = "";
        // Trigger any character counter updates
        textarea.dispatchEvent(new Event('input', { bubbles: true }));
      }
    });

    // Add event listener for showing the nested reply composer 
    this.handleEvent("show-nested-reply-composer", ({ reply_id }) => {
      const composer = document.getElementById(`nested-composer-${reply_id}`);
      if (composer) {
        composer.classList.remove("hidden");
        composer.style.display = "block"; // Force show with inline style
        // Focus the textarea
        const textarea = composer.querySelector(`#nested-reply-textarea-${reply_id}`);
        if (textarea) {
          textarea.focus();
        }
      }
    });
  }
};