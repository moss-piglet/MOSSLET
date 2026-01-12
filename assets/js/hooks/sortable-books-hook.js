import Sortable from "../../vendor/sortable.js";

const SortableBooksHook = {
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
    const container = this.el;
    if (!container) return;

    const items = container.querySelectorAll("[data-book-id]");
    if (items.length <= 1) return;

    this.sortable = new Sortable(container, {
      animation: 200,
      ghostClass: "opacity-40",
      dragClass: "scale-105",
      draggable: "[data-book-id]",
      onEnd: () => {
        const items = container.querySelectorAll("[data-book-id]");
        const order = Array.from(items).map((item) => item.dataset.bookId);
        this.pushEvent("reorder_books", { order });
      },
    });
  },
};

export default SortableBooksHook;
