const MaintainFocus = {
  mounted() {
    this.restoreFocus = () => {
      const activeElementId = this.focusedElementId;
      if (activeElementId) {
        const element = document.getElementById(activeElementId);
        if (element && element !== document.activeElement) {
          setTimeout(() => {
            element.focus();
            // Restore cursor position for text inputs
            if (element.type === 'text' || element.type === 'email' && this.cursorPosition !== undefined) {
              element.setSelectionRange(this.cursorPosition, this.cursorPosition);
            }
          }, 10);
        }
      }
    };

    this.handleElementEvents(['phx:update'], () => {
      this.restoreFocus();
    });

    // Store focused element before updates
    this.el.addEventListener('focusin', (e) => {
      this.focusedElementId = e.target.id;
      if (e.target.type === 'text' || e.target.type === 'email') {
        this.cursorPosition = e.target.selectionStart;
      }
    });

    // Clear focus tracking when element loses focus naturally
    this.el.addEventListener('focusout', (e) => {
      // Only clear if the new focus is outside our container
      setTimeout(() => {
        if (!this.el.contains(document.activeElement)) {
          this.focusedElementId = null;
          this.cursorPosition = null;
        }
      }, 10);
    });
  },

  updated() {
    this.restoreFocus();
  }
};

export default MaintainFocus;