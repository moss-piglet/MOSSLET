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

    // Add scroll handling for modal content
    this.setupModalScrolling();
  },

  setupModalScrolling() {
    const modalContainer = this.el.querySelector('[id$="-container"]');
    const modalContent = this.el.querySelector('[id$="-content"]');
    
    if (modalContainer && modalContent) {
      // Ensure modal container has proper max-height and allows internal scrolling
      modalContainer.style.maxHeight = '95vh';
      modalContainer.style.display = 'flex';
      modalContainer.style.flexDirection = 'column';
      modalContainer.style.overflow = 'hidden';
      
      // Ensure content area is scrollable and respects container height
      modalContent.style.overflowY = 'auto';
      modalContent.style.overflowX = 'hidden';
      modalContent.style.flex = '1 1 auto';
      modalContent.style.minHeight = '0';
      modalContent.style.maxHeight = 'calc(95vh - 120px)'; // Account for header/padding
    }

    // Prevent body scroll when modal is open
    if (!this.el.classList.contains('hidden')) {
      document.body.style.overflow = 'hidden';
    }
  },

  beforeDestroy() {
    // Restore body scroll
    document.body.style.overflow = '';
    
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
    // Restore body scroll
    document.body.style.overflow = '';
    
    // Ensure modal is removed from body if it still exists
    if (this.el && this.el.parentElement === document.body) {
      this.el.remove();
    }
  },
};
