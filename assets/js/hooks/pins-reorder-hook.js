import Sortable from "../../vendor/sortable.js";

/**
 * PinsReorderHook — drag-to-reorder for a dashboard pin strip (#229d).
 *
 * Mirrors SortableBooksHook. The hook element wraps one scope's pins and carries
 * `data-pin-scope` ("personal" | "org_shared"); each pin chip carries
 * `data-pin-id`. On drop it pushes "reorder_pins" with the scope + the new id
 * order so the server can persist `position` (server re-checks authority — I1).
 */
const PinsReorderHook = {
  mounted() {
    this.initSortable();
  },

  updated() {
    this.destroySortable();
    requestAnimationFrame(() => this.initSortable());
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

    const items = container.querySelectorAll("[data-pin-id]");
    if (items.length <= 1) return;

    const scope = container.dataset.pinScope || "personal";

    this.sortable = new Sortable(container, {
      animation: 200,
      ghostClass: "opacity-40",
      dragClass: "scale-105",
      draggable: "[data-pin-id]",
      onEnd: () => {
        const order = Array.from(
          container.querySelectorAll("[data-pin-id]"),
        ).map((item) => item.dataset.pinId);
        this.pushEvent("reorder_pins", { scope, order });
      },
    });
  },
};

export default PinsReorderHook;
