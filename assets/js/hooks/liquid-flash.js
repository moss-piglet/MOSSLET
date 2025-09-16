// Liquid Flash Hook - Handles liquid metal flash animations and interactions
export default {
  mounted() {
    this.setupFlashAnimation();
    this.setupClickToExpand();
    this.setupCloseButton();
  },

  updated() {
    this.setupFlashAnimation();
    this.setupCloseButton();
  },

  setupFlashAnimation() {
    // Add entrance animation
    this.el.style.transform = 'translateX(100%)';
    this.el.style.opacity = '0';
    
    // Trigger animation after a small delay
    requestAnimationFrame(() => {
      this.el.style.transition = 'all 300ms ease-out';
      this.el.style.transform = 'translateX(0)';
      this.el.style.opacity = '1';
    });

    // Auto-dismiss after 8 seconds unless it's an error
    const kind = this.el.querySelector('[data-kind]')?.dataset.kind || 'info';
    if (kind !== 'error') {
      this.autoHideTimer = setTimeout(() => {
        this.hideFlash();
      }, 8000);
    }
  },

  setupCloseButton() {
    // Find and setup close button
    const closeButton = this.el.querySelector('button[data-flash-close="true"]');
    if (closeButton) {
      // Remove any existing listeners
      if (this.closeHandler) {
        closeButton.removeEventListener('click', this.closeHandler);
      }
      
      // Add new click handler
      this.closeHandler = (e) => {
        e.stopPropagation();
        this.hideFlash();
      };
      
      closeButton.addEventListener('click', this.closeHandler);
    }
  },

  setupClickToExpand() {
    // Handle click to expand (but not close button clicks)
    this.handleClick = (e) => {
      // Don't expand if clicking the close button
      if (e.target.closest('button[data-flash-close="true"]')) {
        return;
      }

      const isExpanded = this.el.dataset.expanded === 'true';
      
      if (!isExpanded) {
        // Expand the flash
        this.el.dataset.expanded = 'true';
        this.el.style.transform = 'scale(1.05)';
        this.el.style.zIndex = '60';
        
        // Auto-collapse after 3 seconds
        setTimeout(() => {
          if (this.el) {
            this.el.dataset.expanded = 'false';
            this.el.style.transform = 'scale(1)';
            this.el.style.zIndex = '50';
          }
        }, 3000);
      }
    };

    // Handle flash expand event
    this.handleFlashExpand = (e) => {
      if (e.detail.id === this.el.id) {
        this.handleClick(e);
      }
    };

    this.el.addEventListener('click', this.handleClick);
    window.addEventListener('flash-expand', this.handleFlashExpand);
  },

  hideFlash() {
    // Add fly-out animation
    this.el.style.transition = 'all 500ms ease-out';
    this.el.style.transform = 'translateX(100%)';
    this.el.style.opacity = '0';
    
    // Remove element after animation
    setTimeout(() => {
      if (this.el.parentNode) {
        this.el.remove();
      }
    }, 500);
  },

  destroyed() {
    if (this.autoHideTimer) {
      clearTimeout(this.autoHideTimer);
    }
    
    if (this.handleClick) {
      this.el.removeEventListener('click', this.handleClick);
    }
    
    if (this.handleFlashExpand) {
      window.removeEventListener('flash-expand', this.handleFlashExpand);
    }
    
    if (this.closeHandler) {
      const closeButton = this.el.querySelector('button[data-flash-close="true"]');
      if (closeButton) {
        closeButton.removeEventListener('click', this.closeHandler);
      }
    }
  }
};