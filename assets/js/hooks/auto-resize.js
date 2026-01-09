const AutoResize = {
  mounted() {
    this.el.style.boxSizing = "border-box";
    this.offset = this.el.offsetHeight - this.el.clientHeight;
    this.isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    this.keyboardOpen = false;
    this.initialViewportHeight = window.visualViewport?.height || window.innerHeight;
    this.lastHeight = null;
    this.resizeScheduled = false;
    this.lastCursorScreenY = null;
    
    this.resize();
    
    this.handleInput = () => {
      if (!this.resizeScheduled) {
        this.resizeScheduled = true;
        requestAnimationFrame(() => {
          this.resizeScheduled = false;
          this.resize();
          this.scrollCursorIntoView();
        });
      }
    };
    this.el.addEventListener("input", this.handleInput);
    
    if (this.isIOS && window.visualViewport) {
      this.handleViewportResize = () => {
        const currentHeight = window.visualViewport.height;
        const heightDiff = this.initialViewportHeight - currentHeight;
        this.keyboardOpen = heightDiff > 100;
        this.resize();
      };
      
      window.visualViewport.addEventListener("resize", this.handleViewportResize);
    }
    
    this.handleFocus = () => {
      this.initCursorPosition();
      if (this.isIOS) {
        this.keyboardOpen = true;
        requestAnimationFrame(() => this.resize());
      }
    };
    
    this.handleBlur = () => {
      this.lastCursorScreenY = null;
      if (this.isIOS) {
        this.keyboardOpen = false;
        this.resize();
      }
    };
    
    this.el.addEventListener("focus", this.handleFocus);
    this.el.addEventListener("blur", this.handleBlur);
  },

  destroyed() {
    this.el.removeEventListener("input", this.handleInput);
    this.el.removeEventListener("focus", this.handleFocus);
    this.el.removeEventListener("blur", this.handleBlur);
    
    if (this.isIOS && window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.handleViewportResize);
    }
  },

  getFooterHeight() {
    const footer = document.querySelector("footer.fixed.bottom-0");
    return footer ? footer.offsetHeight : 0;
  },
  
  getVisibleHeight() {
    if (this.isIOS && window.visualViewport) {
      return window.visualViewport.height;
    }
    return window.innerHeight;
  },

  resize() {
    const el = this.el;
    
    if (this.isIOS) {
      const currentHeight = el.offsetHeight;
      const currentScrollHeight = el.scrollHeight;
      
      if (currentScrollHeight > currentHeight) {
        el.style.height = (currentScrollHeight + this.offset) + "px";
      } else if (this.lastHeight !== null && currentScrollHeight < this.lastHeight - 20) {
        el.style.height = "auto";
        el.style.height = (el.scrollHeight + this.offset) + "px";
      }
      
      this.lastHeight = el.scrollHeight;
      return;
    }
    
    el.style.height = "auto";
    const contentHeight = el.scrollHeight + this.offset;
    const rect = el.getBoundingClientRect();
    const footerHeight = this.getFooterHeight();
    const visibleHeight = this.getVisibleHeight();
    const availableBottom = visibleHeight - footerHeight - 8;
    const maxHeight = availableBottom - rect.top;

    el.style.height = contentHeight + "px";
    el.style.overflowY = "hidden";
  },

  scrollCursorIntoView() {
    const el = this.el;
    if (el.selectionStart === undefined) return;
    
    const text = el.value.substring(0, el.selectionStart);
    const lines = text.split("\n").length;
    const style = getComputedStyle(el);
    const lineHeight = parseFloat(style.lineHeight) || 28;
    const paddingTop = parseFloat(style.paddingTop) || 0;
    
    const cursorY = paddingTop + (lines * lineHeight);
    const rect = el.getBoundingClientRect();
    const cursorScreenY = rect.top + cursorY - el.scrollTop;
    
    if (this.lastCursorScreenY !== undefined && this.lastCursorScreenY !== null) {
      const drift = cursorScreenY - this.lastCursorScreenY;
      if (Math.abs(drift) > 2) {
        window.scrollBy({ top: drift, behavior: "instant" });
      }
    }
    
    const newRect = el.getBoundingClientRect();
    this.lastCursorScreenY = newRect.top + cursorY - el.scrollTop;
  },

  initCursorPosition() {
    const el = this.el;
    if (el.selectionStart === undefined) return;
    
    const text = el.value.substring(0, el.selectionStart);
    const lines = text.split("\n").length;
    const style = getComputedStyle(el);
    const lineHeight = parseFloat(style.lineHeight) || 28;
    const paddingTop = parseFloat(style.paddingTop) || 0;
    
    const cursorY = paddingTop + (lines * lineHeight);
    const rect = el.getBoundingClientRect();
    this.lastCursorScreenY = rect.top + cursorY - el.scrollTop;
  },
};

export default AutoResize;
