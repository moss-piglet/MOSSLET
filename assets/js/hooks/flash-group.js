// Flash Group Hook - Simple stacking support for multiple flash messages
export default {
  mounted() {
    this.repositionFlashes();
    this.observeFlashChanges();
  },

  updated() {
    this.repositionFlashes();
  },

  repositionFlashes() {
    // Simple stacking - let flexbox handle the layout
    const flashes = this.el.querySelectorAll('[phx-hook="LiquidFlash"]');
    console.log(`Found ${flashes.length} flash messages`);
    
    // Add stagger animation to new flashes
    flashes.forEach((flash, index) => {
      if (!flash.dataset.positioned) {
        flash.style.animationDelay = `${index * 100}ms`;
        flash.dataset.positioned = 'true';
      }
    });
  },

  observeFlashChanges() {
    // Watch for flash additions/removals
    this.observer = new MutationObserver((mutations) => {
      let shouldReposition = false;

      mutations.forEach((mutation) => {
        if (mutation.type === "childList") {
          const addedFlashes = Array.from(mutation.addedNodes).some(
            (node) =>
              node.nodeType === 1 &&
              node.getAttribute("phx-hook") === "LiquidFlash"
          );
          const removedFlashes = Array.from(mutation.removedNodes).some(
            (node) =>
              node.nodeType === 1 &&
              node.getAttribute("phx-hook") === "LiquidFlash"
          );

          if (addedFlashes || removedFlashes) {
            shouldReposition = true;
          }
        }
      });

      if (shouldReposition) {
        setTimeout(() => this.repositionFlashes(), 100);
      }
    });

    this.observer.observe(this.el, {
      childList: true,
      subtree: true,
    });
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  },
};
