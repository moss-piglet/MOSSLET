import Sortable from "sortablejs";

const SortableUploadsHook = {
  mounted() {
    this.initSortable();
  },

  updated() {
    if (this.sortable) {
      this.sortable.destroy();
    }
    this.initSortable();
  },

  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  },

  initSortable() {
    const container = this.el.querySelector("[data-sortable-container]");
    if (!container) return;

    this.sortable = new Sortable(container, {
      animation: 150,
      ghostClass: "opacity-40",
      dragClass: "rotate-2",
      handle: "[data-sortable-item]",
      draggable: "[data-sortable-item]",
      onEnd: (evt) => {
        const items = container.querySelectorAll("[data-sortable-item]");
        const order = Array.from(items).map((item) => item.dataset.ref);
        this.pushEvent("reorder_uploads", { order });
      },
    });
  },
};

export default SortableUploadsHook;
