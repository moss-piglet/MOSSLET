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

    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "characterData" || mutation.type === "childList") {
          if (document.activeElement === this.el && this.savedSelectionStart !== undefined) {
            this.el.selectionStart = this.savedSelectionStart;
            this.el.selectionEnd = this.savedSelectionEnd;
          }
        }
      }
    });
    this.observer.observe(this.el, { characterData: true, childList: true, subtree: true });

    this.handleSelectionChange = () => {
      if (document.activeElement === this.el) {
        this.savedSelectionStart = this.el.selectionStart;
        this.savedSelectionEnd = this.el.selectionEnd;
        this.savedScrollTop = window.scrollY;
      }
    };
    document.addEventListener("selectionchange", this.handleSelectionChange);
    
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
    document.removeEventListener("selectionchange", this.handleSelectionChange);
    if (this.observer) {
      this.observer.disconnect();
    }
    
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

  measureContentHeight() {
    const el = this.el;
    const clone = el.cloneNode(true);
    clone.style.position = "absolute";
    clone.style.visibility = "hidden";
    clone.style.height = "auto";
    clone.style.width = el.offsetWidth + "px";
    clone.style.overflow = "hidden";
    document.body.appendChild(clone);
    const height = clone.scrollHeight + this.offset;
    document.body.removeChild(clone);
    return height;
  },

  resize() {
    const el = this.el;
    const savedScrollY = window.scrollY;
    const savedSelStart = el.selectionStart;
    const savedSelEnd = el.selectionEnd;
    
    if (this.isIOS) {
      const currentHeight = el.offsetHeight;
      const currentScrollHeight = el.scrollHeight;
      
      if (currentScrollHeight > currentHeight) {
        el.style.height = (currentScrollHeight + this.offset) + "px";
      } else if (this.lastHeight !== null && currentScrollHeight < this.lastHeight - 20) {
        const newHeight = this.measureContentHeight();
        el.style.height = newHeight + "px";
      }
      
      this.lastHeight = el.scrollHeight;
    } else {
      const currentScrollHeight = el.scrollHeight;
      const currentSetHeight = parseFloat(el.style.height) || el.offsetHeight;
      
      if (currentScrollHeight + this.offset > currentSetHeight) {
        el.style.height = (currentScrollHeight + this.offset) + "px";
      } else {
        const newHeight = this.measureContentHeight();
        if (Math.abs(newHeight - currentSetHeight) > 1) {
          el.style.height = newHeight + "px";
        }
      }
      el.style.overflowY = "hidden";
    }
    
    if (document.activeElement === el) {
      el.selectionStart = savedSelStart;
      el.selectionEnd = savedSelEnd;
      if (window.scrollY !== savedScrollY) {
        window.scrollTo({ top: savedScrollY, behavior: "instant" });
      }
    }
  },

  getCursorCoordinates() {
    const el = this.el;
    if (el.selectionStart === undefined) return null;

    const mirror = document.createElement("div");
    const style = getComputedStyle(el);
    
    mirror.style.position = "absolute";
    mirror.style.visibility = "hidden";
    mirror.style.whiteSpace = "pre-wrap";
    mirror.style.wordWrap = "break-word";
    mirror.style.width = style.width;
    mirror.style.font = style.font;
    mirror.style.fontSize = style.fontSize;
    mirror.style.fontFamily = style.fontFamily;
    mirror.style.lineHeight = style.lineHeight;
    mirror.style.padding = style.padding;
    mirror.style.border = style.border;
    mirror.style.boxSizing = style.boxSizing;
    mirror.style.letterSpacing = style.letterSpacing;
    
    const textBeforeCursor = el.value.substring(0, el.selectionStart);
    mirror.textContent = textBeforeCursor;
    
    const marker = document.createElement("span");
    marker.textContent = "|";
    mirror.appendChild(marker);
    
    document.body.appendChild(mirror);
    
    const markerRect = marker.getBoundingClientRect();
    const mirrorRect = mirror.getBoundingClientRect();
    
    const cursorY = markerRect.top - mirrorRect.top;
    
    document.body.removeChild(mirror);
    
    return cursorY;
  },

  scrollCursorIntoView() {
    const el = this.el;
    if (el.selectionStart === undefined) return;
    
    const cursorY = this.getCursorCoordinates();
    if (cursorY === null) return;
    
    const style = getComputedStyle(el);
    const lineHeight = parseFloat(style.lineHeight) || 28;
    const rect = el.getBoundingClientRect();
    const cursorScreenY = rect.top + cursorY;
    
    const footerHeight = this.getFooterHeight();
    const visibleHeight = this.getVisibleHeight();
    const bottomThreshold = visibleHeight - footerHeight - lineHeight * 2;
    
    if (cursorScreenY > bottomThreshold) {
      const scrollAmount = cursorScreenY - bottomThreshold + lineHeight;
      window.scrollBy({ top: scrollAmount, behavior: "instant" });
    }
    
    const finalRect = el.getBoundingClientRect();
    this.lastCursorScreenY = finalRect.top + cursorY;
  },

  initCursorPosition() {
    const el = this.el;
    if (el.selectionStart === undefined) return;
    
    const cursorY = this.getCursorCoordinates();
    if (cursorY === null) return;
    
    const rect = el.getBoundingClientRect();
    this.lastCursorScreenY = rect.top + cursorY;
  },
};

export default AutoResize;
