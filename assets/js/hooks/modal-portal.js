export default {
  mounted() {
    // Only remove exact duplicate modals, not prefix-based matches
    // This prevents interference during LiveView re-renders
    const modalId = this.el.id;

    // Find and remove only exact duplicate modals (same ID)
    const existingModals = document.querySelectorAll(
      `[data-modal-type="liquid-modal"][id="${modalId}"]`
    );

    existingModals.forEach((modal) => {
      if (modal !== this.el && modal.parentElement === document.body) {
        modal.remove();
      }
    });

    // Store original position for cleanup
    this.originalParent = this.el.parentElement;
    this.originalNextSibling = this.el.nextSibling;

    // Move to body to escape stacking context
    document.body.appendChild(this.el);
  },

  beforeDestroy() {
    // Move back to original position when destroyed
    if (this.originalParent && this.el.parentElement === document.body) {
      if (this.originalNextSibling && this.originalNextSibling.parentElement) {
        this.originalParent.insertBefore(this.el, this.originalNextSibling);
      } else {
        this.originalParent.appendChild(this.el);
      }
    }
  },

  destroyed() {
    // Ensure modal is removed from body if it still exists
    if (this.el && this.el.parentElement === document.body) {
      this.el.remove();
    }
  },
};
