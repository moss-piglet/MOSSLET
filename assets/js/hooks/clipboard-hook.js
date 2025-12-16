const ClipboardHook = {
  mounted() {
    this.clickHandler = (e) => {
      e.preventDefault();
      const content = this.el.dataset.content;
      if (content) {
        navigator.clipboard.writeText(content).then(() => {
          this.pushEvent("clipboard_copied", {});
        });
      }
    };
    this.el.addEventListener("click", this.clickHandler);
  },

  destroyed() {
    this.el.removeEventListener("click", this.clickHandler);
  },
};

export default ClipboardHook;
