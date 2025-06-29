// Requires window.initScheme() and window.toggleScheme() functions defined (see `_head.html.heex`)
const ColorSchemeHook = {
  mounted() {
    this.init();
  },
  updated() {
    this.init();
  },
  init() {
    initScheme();
    this.el.addEventListener("click", window.toggleScheme);
  },
};

export default ColorSchemeHook;
