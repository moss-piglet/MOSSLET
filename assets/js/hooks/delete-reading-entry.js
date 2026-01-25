const DeleteReadingEntry = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();

      const entryId = this.el.dataset.entryId;
      const confirmMessage = this.el.dataset.confirmMessage || "Are you sure you want to delete this entry?";

      if (confirm(confirmMessage)) {
        this.pushEvent("delete_reading_entry", { id: entryId });
      }
    });

    this.handleEvent("entry_deleted", ({ entry_id }) => {
      const wrapper = document.getElementById(`entry-flow-${entry_id}`);
      if (wrapper) {
        wrapper.style.transition = "opacity 0.3s ease-out, transform 0.3s ease-out";
        wrapper.style.opacity = "0";
        wrapper.style.transform = "translateX(-20px)";
        setTimeout(() => {
          wrapper.remove();
        }, 300);
      }
    });
  },
};

export default DeleteReadingEntry;
