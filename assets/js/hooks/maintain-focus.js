const MaintainFocus = {
  mounted() {
    this.focusedElementId = null;
    this.cursorPosition = null;

    this.handleFocusin = (e) => {
      this.focusedElementId = e.target.id;
      if (e.target.type === 'text' || e.target.type === 'email') {
        this.cursorPosition = e.target.selectionStart;
      }
    };

    this.handleFocusout = (e) => {
      setTimeout(() => {
        if (!this.el.contains(document.activeElement)) {
          this.focusedElementId = null;
          this.cursorPosition = null;
        }
      }, 10);
    };

    this.el.addEventListener('focusin', this.handleFocusin);
    this.el.addEventListener('focusout', this.handleFocusout);
  },

  updated() {
    this.restoreFocus();
  },

  destroyed() {
    if (this.handleFocusin) {
      this.el.removeEventListener('focusin', this.handleFocusin);
    }
    if (this.handleFocusout) {
      this.el.removeEventListener('focusout', this.handleFocusout);
    }
  },

  restoreFocus() {
    const activeElementId = this.focusedElementId;
    if (activeElementId) {
      const element = document.getElementById(activeElementId);
      if (element && element !== document.activeElement) {
        setTimeout(() => {
          element.focus();
          if ((element.type === 'text' || element.type === 'email') && this.cursorPosition !== undefined) {
            element.setSelectionRange(this.cursorPosition, this.cursorPosition);
          }
        }, 10);
      }
    }
  }
};

export default MaintainFocus;