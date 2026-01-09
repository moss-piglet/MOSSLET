const AutoResize = {
  mounted() {
    this.el.style.boxSizing = "border-box";
    this.offset = this.el.offsetHeight - this.el.clientHeight;
    this.isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    this.keyboardOpen = false;
    this.initialViewportHeight = window.visualViewport?.height || window.innerHeight;
    
    this.resize();
    
    this.handleInput = () => this.resize();
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
      if (this.isIOS) {
        this.keyboardOpen = true;
        requestAnimationFrame(() => this.resize());
      }
    };
    
    this.handleBlur = () => {
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
    
    if (this.isIOS && this.keyboardOpen) {
      el.style.height = "auto";
      const contentHeight = el.scrollHeight + this.offset;
      el.style.height = contentHeight + "px";
      return;
    }
    
    el.style.height = "auto";
    const contentHeight = el.scrollHeight + this.offset;
    const rect = el.getBoundingClientRect();
    const footerHeight = this.getFooterHeight();
    const visibleHeight = this.getVisibleHeight();
    const availableBottom = visibleHeight - footerHeight - 8;
    const maxHeight = availableBottom - rect.top;

    if (contentHeight > maxHeight && maxHeight > 100) {
      el.style.height = maxHeight + "px";
    } else {
      el.style.height = contentHeight + "px";
    }
  },
};

export default AutoResize;
