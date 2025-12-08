const ClipboardHook = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      const content = this.el.dataset.content;
      if (content) {
        navigator.clipboard.writeText(content).then(() => {
          this.pushEvent("clipboard_copied", {});
        });
      }
    });
  },
};

export default ClipboardHook;
