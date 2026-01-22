const BookPageFitHook = {
  mounted() {
    this.measureCharsPerPage = this.measureCharsPerPage.bind(this);
    this.handleResize = this.handleResize.bind(this);
    this.resizeTimeout = null;
    this.hasMeasured = false;
    this.lastWidth = window.innerWidth;
    this.wasMobile = window.innerWidth < 768;
    this.lastMobileChars = null;
    this.lastDesktopChars = null;

    requestAnimationFrame(() => {
      this.measureCharsPerPage();
    });

    window.addEventListener("resize", this.handleResize);
  },

  updated() {
    if (!this.hasMeasured) {
      requestAnimationFrame(() => {
        this.measureCharsPerPage();
      });
    }
  },

  destroyed() {
    window.removeEventListener("resize", this.handleResize);
    if (this.resizeTimeout) clearTimeout(this.resizeTimeout);
  },

  handleResize() {
    if (this.resizeTimeout) {
      clearTimeout(this.resizeTimeout);
    }

    this.resizeTimeout = setTimeout(() => {
      const currentWidth = window.innerWidth;
      const isMobileNow = currentWidth < 768;
      const viewportTypeChanged = this.wasMobile !== isMobileNow;
      const widthChanged = Math.abs(currentWidth - this.lastWidth) > 100;

      if (viewportTypeChanged || widthChanged) {
        this.lastWidth = currentWidth;

        if (viewportTypeChanged) {
          const fromMobile = this.wasMobile;
          this.wasMobile = isMobileNow;
          this.hasMeasured = false;
          this.measureCharsPerPage(() => {
            this.pushEvent("viewport_changed", {
              from_mobile: fromMobile,
              to_mobile: isMobileNow,
              mobile_chars: this.lastMobileChars,
              desktop_chars: this.lastDesktopChars,
            });
          });
        } else {
          this.hasMeasured = false;
          this.measureCharsPerPage();
        }
      }
    }, 150);
  },

  measureCharsPerPage(callback) {
    if (this.hasMeasured) {
      if (callback) callback();
      return;
    }

    const measureRef = document.getElementById("measurement-reference");
    if (!measureRef) {
      if (callback) callback();
      return;
    }

    const contentArea = measureRef.querySelector("[data-measurement-content]");
    if (!contentArea) {
      if (callback) callback();
      return;
    }

    const rect = contentArea.getBoundingClientRect();
    const availableHeight = rect.height;
    if (availableHeight <= 0) {
      if (callback) callback();
      return;
    }

    const isMobile = window.innerWidth < 768;
    const computedStyle = window.getComputedStyle(contentArea);
    const lineHeight = parseFloat(computedStyle.lineHeight) || 28;
    const fontSize = parseFloat(computedStyle.fontSize) || 18;
    const charsPerLine = Math.floor(rect.width / (fontSize * 0.55));
    const linesPerPage = Math.floor(availableHeight / lineHeight);
    const estimatedChars = Math.floor(charsPerLine * linesPerPage * 0.85);

    const finalChars = Math.max(400, Math.min(3000, estimatedChars));

    this.hasMeasured = true;

    if (isMobile) {
      this.lastMobileChars = finalChars;
    } else {
      this.lastDesktopChars = finalChars;
    }

    this.pushEvent("update_chars_per_page", {
      mobile_chars_per_page: isMobile
        ? finalChars
        : this.lastMobileChars || 1200,
      desktop_chars_per_page: isMobile
        ? this.lastDesktopChars || 1800
        : finalChars,
    });

    if (callback) callback();
  },
};

export default BookPageFitHook;
