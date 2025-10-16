/*
 * Hook for managing context menu state based on download permissions
 * Used for photo protection in image modals with real-time permission updates
 */
const DisableContextMenu = {
  mounted() {
    // Set initial state based on data attribute
    this.updateContextMenuState();
  },

  updated() {
    // Called when LiveView updates this element - check for permission changes
    this.updateContextMenuState();
  },

  updateContextMenuState() {
    // Check the data-can-download attribute that LiveView updates
    // LiveView/Phoenix serializes true as an empty string, false as "false"
    const canDownloadAttr = this.el.dataset.canDownload;
    const canDownload = canDownloadAttr === "" || canDownloadAttr === "true";

    if (canDownload) {
      this.enableContextMenu();
    } else {
      this.disableContextMenu();
    }
  },

  enableContextMenu() {
    // Remove context menu restrictions
    this.el.removeEventListener("contextmenu", this.handleContextMenu);
    const childImages = this.el.querySelectorAll("img");
    childImages.forEach((img) => {
      img.removeEventListener("contextmenu", this.handleContextMenu);
      img.draggable = true;
      img.classList.remove("select-none", "cursor-not-allowed");
    });
  },

  disableContextMenu() {
    // Add context menu restrictions
    this.el.addEventListener("contextmenu", this.handleContextMenu);
    const childImages = this.el.querySelectorAll("img");
    childImages.forEach((img) => {
      img.addEventListener("contextmenu", this.handleContextMenu);
      img.draggable = false;
      img.classList.add("select-none", "cursor-not-allowed");
    });
  },

  destroyed() {
    // Clean up event listeners
    this.el.removeEventListener("contextmenu", this.handleContextMenu);
    const childImages = this.el.querySelectorAll("img");
    childImages.forEach((img) => {
      img.removeEventListener("contextmenu", this.handleContextMenu);
    });
  },

  handleContextMenu(e) {
    e.preventDefault();
    e.stopPropagation();
    return false;
  },
};

export default DisableContextMenu;
