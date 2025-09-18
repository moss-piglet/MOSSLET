// Liquid Flash Hook - Handles liquid metal flash animations and interactions
export default {
  mounted() {
    this.setupFlashAnimation();
    this.setupClickToExpand();
    this.setupCloseButton();
  },

  updated() {
    // Don't reset animations if this element is being dismissed
    if (this.el.getAttribute('data-dismissing') === 'true') {
      return;
    }
    
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

    // Auto-dismiss after 12 seconds unless it's an error
    const kind = this.el.querySelector('[data-kind]')?.dataset.kind || 'info';
    if (kind !== 'error') {
      this.autoHideTimer = setTimeout(() => {
        this.hideFlash();
      }, 12000);
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
    // Clear any existing timers to prevent conflicts
    if (this.autoHideTimer) {
      clearTimeout(this.autoHideTimer);
      this.autoHideTimer = null;
    }
    
    // Mark this element as being dismissed and tell LiveView to ignore it
    this.el.setAttribute('data-dismissing', 'true');
    this.el.setAttribute('phx-update', 'ignore');
    
    // Remove any existing CSS classes that might interfere and force our styles
    this.el.style.cssText = `
      transition: transform 500ms cubic-bezier(0.7, 0, 0.84, 0), opacity 500ms cubic-bezier(0.7, 0, 0.84, 0) !important;
      transform: translateX(100%) !important;
      opacity: 0 !important;
      animation: none !important;
      pointer-events: none !important;
    `;
    
    // Wait for animation to FULLY complete before clearing LiveView state
    setTimeout(() => {
      // Clear the flash from Phoenix state using LiveView's built-in event system
      const kind = this.el.dataset.kind;
      if (kind && this.liveSocket) {
        // Send clear_flash event directly to LiveView
        this.liveSocket.execJS(this.el, `[["push",{"event":"lv:clear-flash","value":{"kind":"${kind}"}}]]`);
      }
      
      // Give a small additional delay to ensure LiveView processes the clear before DOM removal
      setTimeout(() => {
        // Remove element from DOM
        if (this.el.parentNode) {
          this.el.remove();
        }
      }, 50); // Small buffer to ensure LiveView state is cleared
      
    }, 600); // Wait for 500ms animation plus buffer
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