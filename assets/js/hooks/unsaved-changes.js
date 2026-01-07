const UnsavedChanges = {
  mounted() {
    this.handleBeforeUnload = (e) => {
      if (this.el.dataset.hasUnsaved === "true") {
        e.preventDefault();
        e.returnValue = "";
        return "";
      }
    };

    window.addEventListener("beforeunload", this.handleBeforeUnload);
  },

  updated() {
    // Data attribute is updated by LiveView
  },

  destroyed() {
    window.removeEventListener("beforeunload", this.handleBeforeUnload);
  },
};

export default UnsavedChanges;
