const TouchHoverHook = {
  mounted() {
    this.isTouchDevice = "ontouchstart" in window || navigator.maxTouchPoints > 0;

    if (this.isTouchDevice) {
      this.handleTouchStart = (e) => {
        const allHovered = document.querySelectorAll(".touch-hover");
        allHovered.forEach((el) => {
          if (el !== this.el) {
            el.classList.remove("touch-hover");
          }
        });

        this.el.classList.toggle("touch-hover");
      };

      this.handleClickOutside = (e) => {
        if (!this.el.contains(e.target)) {
          this.el.classList.remove("touch-hover");
        }
      };

      this.el.addEventListener("touchstart", this.handleTouchStart, {
        passive: true,
      });
      document.addEventListener("touchstart", this.handleClickOutside, {
        passive: true,
      });
    }
  },

  destroyed() {
    if (this.isTouchDevice) {
      this.el.removeEventListener("touchstart", this.handleTouchStart);
      document.removeEventListener("touchstart", this.handleClickOutside);
    }
  },
};

export default TouchHoverHook;
