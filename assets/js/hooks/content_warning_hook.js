// Content Warning Toggle Hook
export const ContentWarningHook = {
  mounted() {
    this.handleEvent("toggle_content_warning", ({ postId }) => {
      this.toggleContentWarning(postId);
    });
  },

  toggleContentWarning(postId) {
    const warningContainer = document.getElementById(`content-warning-${postId}`);
    const contentContainer = document.getElementById(`post-content-${postId}`);
    const toggleButton = warningContainer?.querySelector('button');
    const toggleText = toggleButton?.querySelector('.toggle-text');

    if (warningContainer && contentContainer && toggleButton && toggleText) {
      const isContentVisible = !contentContainer.classList.contains('hidden');
      
      if (isContentVisible) {
        // Hide content
        contentContainer.classList.add('hidden');
        contentContainer.classList.add('content-warning-hidden');
        toggleText.textContent = 'Show content';
        toggleButton.classList.remove('bg-amber-200/50', 'dark:bg-amber-700/30');
        toggleButton.classList.add('bg-amber-100/50', 'dark:bg-amber-800/30');
      } else {
        // Show content
        contentContainer.classList.remove('hidden');
        contentContainer.classList.remove('content-warning-hidden');
        toggleText.textContent = 'Hide content';
        toggleButton.classList.remove('bg-amber-100/50', 'dark:bg-amber-800/30');
        toggleButton.classList.add('bg-amber-200/50', 'dark:bg-amber-700/30');
      }
    }
  }
};

// Auto-setup for posts with content warnings
document.addEventListener('DOMContentLoaded', () => {
  const contentWarningButtons = document.querySelectorAll('[phx-click="toggle_content_warning"]');
  
  contentWarningButtons.forEach(button => {
    button.addEventListener('click', (e) => {
      e.preventDefault();
      const postId = button.getAttribute('phx-value-post-id');
      if (postId) {
        ContentWarningHook.toggleContentWarning(postId);
      }
    });
  });
});