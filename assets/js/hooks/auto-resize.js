const AutoResize = {
  mounted() {
    this.el.style.boxSizing = "border-box";
    this.offset = this.el.offsetHeight - this.el.clientHeight;
    this.resize();
    this.el.addEventListener("input", () => this.resize());
  },

  getFooterHeight() {
    const footer = document.querySelector("footer.fixed.bottom-0");
    return footer ? footer.offsetHeight : 0;
  },

  resize() {
    const el = this.el;
    el.style.height = "auto";
    const contentHeight = el.scrollHeight + this.offset;
    const rect = el.getBoundingClientRect();
    const footerHeight = this.getFooterHeight();
    const availableBottom = window.innerHeight - footerHeight - 8;
    const maxHeight = availableBottom - rect.top;

    if (contentHeight > maxHeight && maxHeight > 100) {
      el.style.height = maxHeight + "px";
    } else {
      el.style.height = contentHeight + "px";
    }
  },
};

export default AutoResize;
