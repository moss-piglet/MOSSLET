const SubmitOnEnter = {
  mounted() {
    this.isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent
    ) || (navigator.maxTouchPoints > 0 && window.innerWidth < 768);

    if (this.isMobile) return;

    this.handleKeydown = (e) => {
      if (e.key === "Enter" && !e.shiftKey && !e.ctrlKey && !e.altKey && !e.metaKey) {
        const value = this.el.value.trim();
        if (value) {
          e.preventDefault();
          const form = this.el.closest("form");
          if (form) {
            form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
          }
        }
      }
    };

    this.el.addEventListener("keydown", this.handleKeydown);
  },

  destroyed() {
    if (this.handleKeydown) {
      this.el.removeEventListener("keydown", this.handleKeydown);
    }
  }
};

export default SubmitOnEnter;
