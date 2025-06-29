// import tippy from 'tippy.js'

const TippyHook = {
  mounted() {
    this.run("mounted", this.el);
  },
  
  updated() {
    this.run("updated", this.el);
  },

  destroyed() {
    this.run("destroyed", this.el);
  },

  run(lifecycleMethod, el) {
    const tippyInstance = tippy(el);
    const disableOnMount = el.dataset.disableTippyOnMount === "true";

    if (lifecycleMethod === "mounted" && disableOnMount) {
      tippyInstance.disable();
    } else if (lifecycleMethod === "destroyed") {
      tippyInstance.destroy()
    }
  },
};

export default TippyHook;
