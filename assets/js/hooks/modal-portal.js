export default {
  mounted() {
    // Remove any existing modals with similar prefixes to prevent stacking
    // Extract the base prefix (e.g., "reply-modal" from "reply-modal-reply")
    const idParts = this.el.id.split('-');
    const modalPrefix = idParts.slice(0, 2).join('-'); // e.g., "reply-modal"
    
    // Find and remove stale modals with the same prefix but different IDs
    const existingModals = document.querySelectorAll(`[data-modal-type="liquid-modal"][id^="${modalPrefix}"]`);
    
    existingModals.forEach(modal => {
      if (modal !== this.el && modal.parentElement === document.body) {
        console.log(`Removing stale modal: ${modal.id}`);
        modal.remove();
      }
    });
    
    // Store original position for cleanup
    this.originalParent = this.el.parentElement;
    this.originalNextSibling = this.el.nextSibling;
    
    // Move to body to escape stacking context
    document.body.appendChild(this.el);
    
    console.log(`Modal ${this.el.id} moved to body level for proper viewport positioning`);
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
      console.log(`Cleaning up modal ${this.el.id} from body`);
      this.el.remove();
    }
  }
};