const DisableContextMenu = {
  mounted() {
    this.boundHandleContextMenu = this.handleContextMenu.bind(this);
    this.updateContextMenuState();
  },

  updated() {
    this.updateContextMenuState();
  },

  updateContextMenuState() {
    const canDownloadAttr = this.el.dataset.canDownload;
    const canDownload = canDownloadAttr === "" || canDownloadAttr === "true";

    if (canDownload) {
      this.enableContextMenu();
    } else {
      this.disableContextMenu();
    }
  },

  enableContextMenu() {
    this.el.removeEventListener("contextmenu", this.boundHandleContextMenu);
    const childImages = this.el.querySelectorAll("img");
    childImages.forEach((img) => {
      img.removeEventListener("contextmenu", this.boundHandleContextMenu);
      img.draggable = true;
      img.classList.remove("select-none", "cursor-not-allowed");
    });
  },

  disableContextMenu() {
    this.el.removeEventListener("contextmenu", this.boundHandleContextMenu);
    this.el.addEventListener("contextmenu", this.boundHandleContextMenu);
    
    const childImages = this.el.querySelectorAll("img");
    childImages.forEach((img) => {
      img.removeEventListener("contextmenu", this.boundHandleContextMenu);
      img.addEventListener("contextmenu", this.boundHandleContextMenu);
      img.draggable = false;
      img.classList.add("select-none", "cursor-not-allowed");
    });
  },

  destroyed() {
    this.el.removeEventListener("contextmenu", this.boundHandleContextMenu);
    const childImages = this.el.querySelectorAll("img");
    childImages.forEach((img) => {
      img.removeEventListener("contextmenu", this.boundHandleContextMenu);
    });
    this.boundHandleContextMenu = null;
  },

  handleContextMenu(e) {
    e.preventDefault();
    e.stopPropagation();
    return false;
  },
};

export default DisableContextMenu;
