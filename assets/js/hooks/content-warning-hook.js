// Content Warning Toggle Hook
export const ContentWarningHook = {
  mounted() {
    const postId = this.el.dataset.postId;
    this.postId = postId;
    
    // Set up click handler for this specific button
    this.el.addEventListener('click', (e) => {
      e.preventDefault();
      this.toggleContentWarning();
    });
  },

  toggleContentWarning() {
    const warningContainer = document.getElementById(`content-warning-${this.postId}`);
    const contentContainer = document.getElementById(`post-content-${this.postId}`);
    const toggleButton = this.el; // The button itself is the hook element
    const toggleText = toggleButton.querySelector('.toggle-text');

    if (warningContainer && contentContainer && toggleButton && toggleText) {
      const isContentVisible = !contentContainer.classList.contains('hidden');
      
      if (isContentVisible) {
        // Hide content
        contentContainer.classList.add('hidden');
        contentContainer.classList.add('content-warning-hidden');
        toggleText.textContent = 'Show content';
        toggleButton.classList.remove('bg-teal-200/50', 'dark:bg-teal-700/30');
        toggleButton.classList.add('bg-teal-100/50', 'dark:bg-teal-800/30');
      } else {
        // Show content
        contentContainer.classList.remove('hidden');
        contentContainer.classList.remove('content-warning-hidden');
        toggleText.textContent = 'Hide content';
        toggleButton.classList.remove('bg-teal-100/50', 'dark:bg-teal-800/30');
        toggleButton.classList.add('bg-teal-200/50', 'dark:bg-teal-700/30');
      }
    }
  }
};