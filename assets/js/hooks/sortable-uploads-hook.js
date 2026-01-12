import Sortable from "../../vendor/sortable.js";

const SortableUploadsHook = {
  mounted() {
    this.initSortable();
  },

  updated() {
    this.destroySortable();
    requestAnimationFrame(() => {
      this.initSortable();
    });
  },

  destroyed() {
    this.destroySortable();
  },

  destroySortable() {
    if (this.sortable) {
      try {
        this.sortable.destroy();
      } catch (e) {}
      this.sortable = null;
    }
  },

  initSortable() {
    const container = this.el.querySelector("[data-sortable-container]");
    if (!container) return;

    const items = container.querySelectorAll("[data-sortable-item]");
    if (items.length === 0) return;

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
