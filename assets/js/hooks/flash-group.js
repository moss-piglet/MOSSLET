// Flash Group Hook - Manages stacking and positioning of multiple flash messages
export default {
  mounted() {
    this.repositionFlashes();
    this.observeFlashChanges();
  },

  updated() {
    this.repositionFlashes();
  },

  repositionFlashes() {
    // With flexbox layout, we don't need to manually position each flash
    // The flex-col-reverse class handles stacking from bottom up automatically
    const flashes = this.el.querySelectorAll('[phx-hook="LiquidFlash"]');
    console.log(`Found ${flashes.length} flash messages`);
  },

  observeFlashChanges() {
    // Watch for flash additions/removals
    this.observer = new MutationObserver((mutations) => {
      let shouldReposition = false;

      mutations.forEach((mutation) => {
        if (mutation.type === "childList") {
          // Check if any flash elements were added or removed
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
        // Small delay to allow DOM to settle
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
