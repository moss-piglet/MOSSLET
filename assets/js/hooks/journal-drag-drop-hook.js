const JournalDragDropHook = {
  mounted() {
    this.dragHandlers = new WeakMap();
    this.dropHandlers = new WeakMap();
    this.setupDragAndDrop();
  },

  updated() {
    this.cleanupHandlers();
    this.setupDragAndDrop();
  },

  destroyed() {
    this.cleanupHandlers();
    this.dragHandlers = null;
    this.dropHandlers = null;
  },

  cleanupHandlers() {
    const draggables = this.el.querySelectorAll("[data-draggable-entry]");
    const dropTargets = this.el.querySelectorAll("[data-drop-target-book]");

    draggables.forEach((draggable) => {
      const handlers = this.dragHandlers?.get(draggable);
      if (handlers) {
        draggable.removeEventListener("dragstart", handlers.dragstart);
        draggable.removeEventListener("dragend", handlers.dragend);
        draggable.removeEventListener("touchstart", handlers.touchstart, { passive: false });
        draggable.removeEventListener("touchmove", handlers.touchmove, { passive: false });
        draggable.removeEventListener("touchend", handlers.touchend);
        draggable.removeEventListener("touchcancel", handlers.touchcancel);
        draggable.removeAttribute("draggable");
      }
    });

    dropTargets.forEach((target) => {
      const handlers = this.dropHandlers?.get(target);
      if (handlers) {
        target.removeEventListener("dragover", handlers.dragover);
        target.removeEventListener("dragleave", handlers.dragleave);
        target.removeEventListener("drop", handlers.drop);
      }
    });
  },

  setupDragAndDrop() {
    const draggables = this.el.querySelectorAll("[data-draggable-entry]");
    const dropTargets = this.el.querySelectorAll("[data-drop-target-book]");

    if (draggables.length === 0 || dropTargets.length === 0) return;

    this.touchState = null;
    this.touchGhost = null;

    draggables.forEach((draggable) => {
      draggable.setAttribute("draggable", "true");

      const handlers = {
        dragstart: (e) => this.handleDragStart(e, draggable, dropTargets),
        dragend: (e) => this.handleDragEnd(e, draggable, dropTargets),
        touchstart: (e) => this.handleTouchStart(e, draggable, dropTargets),
        touchmove: (e) => this.handleTouchMove(e, draggable, dropTargets),
        touchend: (e) => this.handleTouchEnd(e, draggable, dropTargets),
        touchcancel: (e) => this.handleTouchCancel(e, draggable, dropTargets),
      };

      this.dragHandlers.set(draggable, handlers);

      draggable.addEventListener("dragstart", handlers.dragstart);
      draggable.addEventListener("dragend", handlers.dragend);
      draggable.addEventListener("touchstart", handlers.touchstart, { passive: false });
      draggable.addEventListener("touchmove", handlers.touchmove, { passive: false });
      draggable.addEventListener("touchend", handlers.touchend);
      draggable.addEventListener("touchcancel", handlers.touchcancel);
    });

    dropTargets.forEach((target) => {
      const handlers = {
        dragover: (e) => this.handleDragOver(e, target),
        dragleave: (e) => this.handleDragLeave(e, target),
        drop: (e) => this.handleDrop(e, target, dropTargets),
      };

      this.dropHandlers.set(target, handlers);

      target.addEventListener("dragover", handlers.dragover);
      target.addEventListener("dragleave", handlers.dragleave);
      target.addEventListener("drop", handlers.drop);
    });
  },

  handleDragStart(e, draggable, dropTargets) {
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
  },

  handleDragEnd(e, draggable, dropTargets) {
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
  },

  handleDragOver(e, target) {
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
    target.classList.add(
      "ring-4",
      "bg-emerald-50",
      "dark:bg-emerald-900/30"
    );
    target.classList.remove("ring-2");
  },

  handleDragLeave(e, target) {
    target.classList.remove(
      "ring-4",
      "bg-emerald-50",
      "dark:bg-emerald-900/30"
    );
    target.classList.add("ring-2");
  },

  handleDrop(e, target, dropTargets) {
    e.preventDefault();
    const entryId = e.dataTransfer.getData("text/plain");
    const bookId = target.dataset.dropTargetBook;

    if (entryId && bookId) {
      this.pushEvent("drop_entry_to_book", {
        entry_id: entryId,
        book_id: bookId,
      });
    }

    dropTargets.forEach((t) => {
      t.classList.remove(
        "ring-2",
        "ring-dashed",
        "ring-emerald-400",
        "dark:ring-emerald-500",
        "ring-4",
        "bg-emerald-50",
        "dark:bg-emerald-900/30"
      );
    });
  },

  handleTouchStart(e, draggable, dropTargets) {
    if (e.touches.length !== 1) return;

    const touch = e.touches[0];
    const rect = draggable.getBoundingClientRect();

    this.touchState = {
      entryId: draggable.dataset.draggableEntry,
      startX: touch.clientX,
      startY: touch.clientY,
      offsetX: touch.clientX - rect.left,
      offsetY: touch.clientY - rect.top,
      isDragging: false,
      longPressTimer: null,
      draggable: draggable,
    };

    this.touchState.longPressTimer = setTimeout(() => {
      if (this.touchState) {
        this.touchState.isDragging = true;
        this.startTouchDrag(draggable, dropTargets, touch);
      }
    }, 200);
  },

  handleTouchMove(e, draggable, dropTargets) {
    if (!this.touchState) return;

    const touch = e.touches[0];
    const deltaX = Math.abs(touch.clientX - this.touchState.startX);
    const deltaY = Math.abs(touch.clientY - this.touchState.startY);

    if (!this.touchState.isDragging && (deltaX > 10 || deltaY > 10)) {
      if (this.touchState.longPressTimer) {
        clearTimeout(this.touchState.longPressTimer);
        this.touchState.longPressTimer = null;
      }

      if (deltaY > deltaX) {
        this.touchState = null;
        return;
      }

      this.touchState.isDragging = true;
      this.startTouchDrag(draggable, dropTargets, touch);
    }

    if (this.touchState?.isDragging) {
      e.preventDefault();
      this.updateTouchDrag(touch, dropTargets);
    }
  },

  handleTouchEnd(e, draggable, dropTargets) {
    if (this.touchState?.longPressTimer) {
      clearTimeout(this.touchState.longPressTimer);
    }

    if (this.touchState?.isDragging) {
      const touch = e.changedTouches[0];
      const target = this.findDropTarget(touch.clientX, touch.clientY, dropTargets);

      if (target) {
        const bookId = target.dataset.dropTargetBook;
        if (this.touchState.entryId && bookId) {
          this.pushEvent("drop_entry_to_book", {
            entry_id: this.touchState.entryId,
            book_id: bookId,
          });
        }
      }

      this.endTouchDrag(draggable, dropTargets);
    }

    this.touchState = null;
  },

  handleTouchCancel(e, draggable, dropTargets) {
    if (this.touchState?.longPressTimer) {
      clearTimeout(this.touchState.longPressTimer);
    }

    if (this.touchState?.isDragging) {
      this.endTouchDrag(draggable, dropTargets);
    }

    this.touchState = null;
  },

  startTouchDrag(draggable, dropTargets, touch) {
    draggable.classList.add("opacity-50", "scale-95");

    this.touchGhost = draggable.cloneNode(true);
    this.touchGhost.style.position = "fixed";
    this.touchGhost.style.pointerEvents = "none";
    this.touchGhost.style.zIndex = "9999";
    this.touchGhost.style.width = draggable.offsetWidth + "px";
    this.touchGhost.style.opacity = "0.8";
    this.touchGhost.style.transform = "rotate(2deg) scale(1.02)";
    this.touchGhost.style.boxShadow = "0 10px 25px rgba(0,0,0,0.15)";
    this.touchGhost.classList.remove("opacity-50", "scale-95");

    document.body.appendChild(this.touchGhost);
    this.positionGhost(touch);

    dropTargets.forEach((target) => {
      target.classList.add(
        "ring-2",
        "ring-dashed",
        "ring-emerald-400",
        "dark:ring-emerald-500"
      );
    });
  },

  updateTouchDrag(touch, dropTargets) {
    this.positionGhost(touch);

    dropTargets.forEach((target) => {
      const rect = target.getBoundingClientRect();
      const isOver =
        touch.clientX >= rect.left &&
        touch.clientX <= rect.right &&
        touch.clientY >= rect.top &&
        touch.clientY <= rect.bottom;

      if (isOver) {
        target.classList.add("ring-4", "bg-emerald-50", "dark:bg-emerald-900/30");
        target.classList.remove("ring-2");
      } else {
        target.classList.remove("ring-4", "bg-emerald-50", "dark:bg-emerald-900/30");
        target.classList.add("ring-2");
      }
    });
  },

  positionGhost(touch) {
    if (this.touchGhost && this.touchState) {
      this.touchGhost.style.left = (touch.clientX - this.touchState.offsetX) + "px";
      this.touchGhost.style.top = (touch.clientY - this.touchState.offsetY) + "px";
    }
  },

  endTouchDrag(draggable, dropTargets) {
    draggable.classList.remove("opacity-50", "scale-95");

    if (this.touchGhost && this.touchGhost.parentNode) {
      this.touchGhost.parentNode.removeChild(this.touchGhost);
    }
    this.touchGhost = null;

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
  },

  findDropTarget(x, y, dropTargets) {
    for (const target of dropTargets) {
      const rect = target.getBoundingClientRect();
      if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
        return target;
      }
    }
    return null;
  },
};

export default JournalDragDropHook;
