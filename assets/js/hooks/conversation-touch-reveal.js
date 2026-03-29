const ConversationTouchReveal = {
  mounted() {
    this.isTouchDevice =
      "ontouchstart" in window || navigator.maxTouchPoints > 0;

    if (!this.isTouchDevice) return;

    this.activeEl = null;

    this.handleTouch = (e) => {
      const msgEl = e.target.closest("[data-msg-touch]");

      if (msgEl && msgEl !== this.activeEl) {
        if (this.activeEl) this.activeEl.classList.remove("touch-hover");
        msgEl.classList.add("touch-hover");
        this.activeEl = msgEl;
      } else if (msgEl && msgEl === this.activeEl) {
        const isActionButton =
          e.target.closest("[data-react-trigger]") ||
          e.target.closest('[phx-click="confirm_delete_message"]');
        if (!isActionButton) {
          msgEl.classList.remove("touch-hover");
          this.activeEl = null;
        }
      } else {
        if (this.activeEl) {
          this.activeEl.classList.remove("touch-hover");
          this.activeEl = null;
        }
      }
    };

    this.el.addEventListener("touchstart", this.handleTouch, {
      passive: true,
    });
  },

  destroyed() {
    if (this.isTouchDevice && this.handleTouch) {
      this.el.removeEventListener("touchstart", this.handleTouch);
    }
  },
};

export default ConversationTouchReveal;
