export const CtrlEnterSubmits = {
  CtrlEnterSubmits: {
    mounted() {
      this.handleKeydown = (e) => {
        if (e.ctrlKey && e.key === 'Enter') {
          let form = e.target.closest('form');
          form.dispatchEvent(new Event('submit', {bubbles: true}));
          e.stopPropagation();
          e.preventDefault();
        }
      };
      this.el.addEventListener("keydown", this.handleKeydown);
    },

    destroyed() {
      if (this.handleKeydown) {
        this.el.removeEventListener("keydown", this.handleKeydown);
      }
    }
  }
}