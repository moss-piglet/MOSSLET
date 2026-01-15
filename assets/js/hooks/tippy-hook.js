const TippyHook = {
  mounted() {
    this.createTippy();
  },

  updated() {
    if (this.tippyInstance) {
      this.tippyInstance.destroy();
      this.tippyInstance = null;
    }
    this.createTippy();
  },

  destroyed() {
    if (this.tippyInstance) {
      this.tippyInstance.destroy();
      this.tippyInstance = null;
    }
  },

  createTippy() {
    this.tippyInstance = tippy(this.el, {
      touch: ["hold", 500],
      hideOnClick: true,
      trigger: "mouseenter focus",
      onTrigger(instance, event) {
        if (event.type === "touchstart") {
          instance.hide();
        }
      },
    });

    const disableOnMount = this.el.dataset.disableTippyOnMount === "true";
    if (disableOnMount) {
      this.tippyInstance.disable();
    }
  },
};

export default TippyHook;
