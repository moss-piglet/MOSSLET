const BookReaderSwipe = {
  mounted() {
    this.touchStartX = 0;
    this.touchEndX = 0;
    this.minSwipeDistance = 80;
    this.mdBreakpoint = 768;
    this.wasMobile = window.innerWidth < this.mdBreakpoint;

    this.isMobile = () => window.innerWidth < this.mdBreakpoint;

    this.handleTouchStart = (e) => {
      this.touchStartX = e.changedTouches[0].screenX;
    };

    this.handleTouchEnd = (e) => {
      this.touchEndX = e.changedTouches[0].screenX;
      this.handleSwipe();
    };

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

    this.handleResize = () => {
      const isMobileNow = this.isMobile();
      if (this.wasMobile !== isMobileNow) {
        this.pushEvent("viewport_changed", { 
          from_mobile: this.wasMobile, 
          to_mobile: isMobileNow 
        });
        this.wasMobile = isMobileNow;
      }
    };

    this.el.addEventListener("swipe-left", () => {
      this.pushEvent("swipe_navigate", { direction: "next", is_mobile: this.isMobile() });
    });

    this.el.addEventListener("swipe-right", () => {
      this.pushEvent("swipe_navigate", { direction: "prev", is_mobile: this.isMobile() });
    });

    window.addEventListener("keydown", this.handleKeydown);
    window.addEventListener("resize", this.handleResize);
  },

  destroyed() {
    this.el.removeEventListener("swipe-left", () => {});
    this.el.removeEventListener("swipe-right", () => {});
    window.removeEventListener("keydown", this.handleKeydown);
    window.removeEventListener("resize", this.handleResize);
  },
};

export default BookReaderSwipe;
