const ImageErrorHook = {
  mounted() {
    this.attachErrorHandler();
  },

  updated() {
    this.attachErrorHandler();
  },

  attachErrorHandler() {
    const img = this.el.tagName === "IMG" ? this.el : this.el.querySelector("img");
    if (!img) return;

    img.addEventListener("error", () => {
      const parent = img.parentElement;
      if (parent) {
        parent.style.display = "none";
      }
    }, { once: true });
  },
};

export default ImageErrorHook;
