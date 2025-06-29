export default ScrollDown = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight;
  },

  updated() {
    // console.log(this.el.dataset.scrolledToTop);
    if (this.el.dataset.scrolledToTop == "false") {
      // console.log(this.el.scrollHeight)
      this.el.scrollTop = this.el.scrollHeight;
    }
  },
};
