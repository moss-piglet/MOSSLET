const BookReaderSwipe = {
  mounted() {
    this.touchStartX = 0;
    this.touchEndX = 0;
    this.minSwipeDistance = 80;
    this.mdBreakpoint = 768;

    this.isMobile = () => window.innerWidth < this.mdBreakpoint;

    this.handleSwipe = () => {
      const diff = this.touchStartX - this.touchEndX;
      if (Math.abs(diff) > this.minSwipeDistance) {
        const direction = diff > 0 ? "next" : "prev";
        this.pushEvent("swipe_navigate", { direction, is_mobile: this.isMobile() });
      }
    };

    this.handleKeydown = (e) => {
      if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
        this.pushEvent("keyboard_nav", { key: e.key, width: window.innerWidth });
      }
    };

    this.handleSwipeLeft = () => {
      this.pushEvent("swipe_navigate", { direction: "next", is_mobile: this.isMobile() });
    };

    this.handleSwipeRight = () => {
      this.pushEvent("swipe_navigate", { direction: "prev", is_mobile: this.isMobile() });
    };

    this.el.addEventListener("swipe-left", this.handleSwipeLeft);
    this.el.addEventListener("swipe-right", this.handleSwipeRight);
    window.addEventListener("keydown", this.handleKeydown);
  },

  destroyed() {
    this.el.removeEventListener("swipe-left", this.handleSwipeLeft);
    this.el.removeEventListener("swipe-right", this.handleSwipeRight);
    window.removeEventListener("keydown", this.handleKeydown);
  },
};

export default BookReaderSwipe;
