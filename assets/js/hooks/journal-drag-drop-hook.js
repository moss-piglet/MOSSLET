const JournalDragDropHook = {
  mounted() {
    this.setupDragAndDrop();
  },

  updated() {
    this.setupDragAndDrop();
  },

  setupDragAndDrop() {
    const draggables = this.el.querySelectorAll("[data-draggable-entry]");
    const dropTargets = this.el.querySelectorAll("[data-drop-target-book]");

    draggables.forEach((draggable) => {
      draggable.setAttribute("draggable", "true");

      draggable.ondragstart = (e) => {
        e.dataTransfer.setData("text/plain", draggable.dataset.draggableEntry);
        e.dataTransfer.effectAllowed = "move";
        draggable.classList.add("opacity-50", "scale-95");

        dropTargets.forEach((target) => {
          target.classList.add(
            "ring-2",
            "ring-dashed",
            "ring-emerald-400",
            "dark:ring-emerald-500"
          );
        });
      };

      draggable.ondragend = (e) => {
        draggable.classList.remove("opacity-50", "scale-95");

        dropTargets.forEach((target) => {
          target.classList.remove(
            "ring-2",
            "ring-dashed",
            "ring-emerald-400",
            "dark:ring-emerald-500",
            "ring-4",
            "bg-emerald-50",
            "dark:bg-emerald-900/30"
          );
        });
      };
    });

    dropTargets.forEach((target) => {
      target.ondragover = (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = "move";
        target.classList.add(
          "ring-4",
          "bg-emerald-50",
          "dark:bg-emerald-900/30"
        );
        target.classList.remove("ring-2");
      };

      target.ondragleave = (e) => {
        target.classList.remove(
          "ring-4",
          "bg-emerald-50",
          "dark:bg-emerald-900/30"
        );
        target.classList.add("ring-2");
      };

      target.ondrop = (e) => {
        e.preventDefault();
        const entryId = e.dataTransfer.getData("text/plain");
        const bookId = target.dataset.dropTargetBook;

        if (entryId && bookId) {
          this.pushEvent("drop_entry_to_book", {
            entry_id: entryId,
            book_id: bookId,
          });
        }

        target.classList.remove(
          "ring-2",
          "ring-dashed",
          "ring-emerald-400",
          "dark:ring-emerald-500",
          "ring-4",
          "bg-emerald-50",
          "dark:bg-emerald-900/30"
        );
      };
    });
  },
};

export default JournalDragDropHook;
