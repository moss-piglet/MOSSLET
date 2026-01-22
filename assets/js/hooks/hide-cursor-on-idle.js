const HideCursorOnIdle = {
  mounted() {
    this.timeout = null;
    this.idleDelay = parseInt(this.el.dataset.idleDelay, 10) || 2500;
    this.cursorHidden = false;
    
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseLeave = this.handleMouseLeave.bind(this);
    this.hideCursor = this.hideCursor.bind(this);
    this.showCursor = this.showCursor.bind(this);
    
    this.el.addEventListener('mousemove', this.handleMouseMove);
    this.el.addEventListener('mouseleave', this.handleMouseLeave);
    
    this.startIdleTimer();
  },

  destroyed() {
    this.clearIdleTimer();
    this.el.removeEventListener('mousemove', this.handleMouseMove);
    this.el.removeEventListener('mouseleave', this.handleMouseLeave);
    this.showCursor();
  },

  handleMouseMove() {
    this.showCursor();
    this.startIdleTimer();
  },

  handleMouseLeave() {
    this.clearIdleTimer();
    this.showCursor();
  },

  startIdleTimer() {
    this.clearIdleTimer();
    this.timeout = setTimeout(this.hideCursor, this.idleDelay);
  },

  clearIdleTimer() {
    if (this.timeout) {
      clearTimeout(this.timeout);
      this.timeout = null;
    }
  },

  hideCursor() {
    if (!this.cursorHidden) {
      this.cursorHidden = true;
      this.el.style.cursor = 'none';
      this.el.querySelectorAll('*').forEach(el => {
        el.dataset.originalCursor = el.style.cursor;
        el.style.cursor = 'none';
      });
    }
  },

  showCursor() {
    if (this.cursorHidden) {
      this.cursorHidden = false;
      this.el.style.cursor = '';
      this.el.querySelectorAll('*').forEach(el => {
        if (el.dataset.originalCursor !== undefined) {
          el.style.cursor = el.dataset.originalCursor;
          delete el.dataset.originalCursor;
        } else {
          el.style.cursor = '';
        }
      });
    }
  }
};

export default HideCursorOnIdle;
