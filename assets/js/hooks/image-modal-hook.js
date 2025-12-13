const ImageModalHook = {
  mounted() {
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    this.boundNavButtonClick = new WeakMap();
    this.touchStartX = 0;
    this.touchEndX = 0;
    this.isNavigating = false;
    this.preloadedImages = new Set();
    this.navigationTimeout = null;

    window.addEventListener("keydown", this.boundHandleKeydown);
    this.setupTouchHandlers();
    this.preloadAdjacentImages();
    this.setupNavigationButtons();
  },

  updated() {
    this.preloadAdjacentImages();
    this.hideAllLoadingStates();
    this.setupNavigationButtons();
  },

  destroyed() {
    window.removeEventListener("keydown", this.boundHandleKeydown);
    this.removeTouchHandlers();
    this.removeNavigationButtonListeners();
    this.preloadedImages.clear();
    this.preloadedImages = null;
    this.isNavigating = false;
    this.boundHandleKeydown = null;
    this.boundNavButtonClick = null;
    if (this.navigationTimeout) {
      clearTimeout(this.navigationTimeout);
      this.navigationTimeout = null;
    }
  },

  isModalVisible() {
    const style = window.getComputedStyle(this.el);
    return style.display !== "none" && style.visibility !== "hidden";
  },

  handleKeydown(e) {
    if (!this.isModalVisible()) return;
    if (this.isNavigating) return;

    if (e.key === "ArrowLeft") {
      e.preventDefault();
      this.navigatePrev();
    } else if (e.key === "ArrowRight") {
      e.preventDefault();
      this.navigateNext();
    }
  },

  setupTouchHandlers() {
    this.boundTouchStart = this.handleTouchStart.bind(this);
    this.boundTouchEnd = this.handleTouchEnd.bind(this);

    this.el.addEventListener("touchstart", this.boundTouchStart, {
      passive: true,
    });
    this.el.addEventListener("touchend", this.boundTouchEnd, { passive: true });
  },

  removeTouchHandlers() {
    if (this.boundTouchStart) {
      this.el.removeEventListener("touchstart", this.boundTouchStart);
    }
    if (this.boundTouchEnd) {
      this.el.removeEventListener("touchend", this.boundTouchEnd);
    }
    this.boundTouchStart = null;
    this.boundTouchEnd = null;
  },

  handleTouchStart(e) {
    this.touchStartX = e.changedTouches[0].screenX;
  },

  handleTouchEnd(e) {
    this.touchEndX = e.changedTouches[0].screenX;
    this.handleSwipe();
  },

  handleSwipe() {
    const swipeThreshold = 50;
    const diff = this.touchStartX - this.touchEndX;

    if (this.isNavigating) return;

    if (diff > swipeThreshold) {
      this.navigateNext();
    } else if (diff < -swipeThreshold) {
      this.navigatePrev();
    }
  },

  setupNavigationButtons() {
    const navButtons = this.el.querySelectorAll(
      '[phx-click="next_timeline_image"], [phx-click="prev_timeline_image"], [phx-click="goto_timeline_image"]'
    );
    navButtons.forEach((btn) => {
      if (!this.boundNavButtonClick.has(btn)) {
        const handler = () => this.showLoadingState(btn);
        this.boundNavButtonClick.set(btn, handler);
        btn.addEventListener("click", handler);
      }
    });
  },

  removeNavigationButtonListeners() {
    const navButtons = this.el.querySelectorAll(
      '[phx-click="next_timeline_image"], [phx-click="prev_timeline_image"], [phx-click="goto_timeline_image"]'
    );
    navButtons.forEach((btn) => {
      const handler = this.boundNavButtonClick.get(btn);
      if (handler) {
        btn.removeEventListener("click", handler);
        this.boundNavButtonClick.delete(btn);
      }
    });
  },

  showLoadingState(button) {
    if (this.isNavigating) return;

    this.isNavigating = true;
    button.classList.add("pointer-events-none");

    const icon = button.querySelector(".nav-icon");
    const dot = button.querySelector(".nav-dot");
    const spinner = button.querySelector(".nav-spinner");

    if (icon) {
      icon.classList.add("hidden");
    }
    if (dot) {
      dot.classList.add("hidden");
    }
    if (spinner) {
      spinner.classList.remove("hidden");
    }

    if (this.navigationTimeout) {
      clearTimeout(this.navigationTimeout);
    }
    this.navigationTimeout = setTimeout(() => {
      this.hideAllLoadingStates();
      this.isNavigating = false;
    }, 2000);
  },

  hideAllLoadingStates() {
    const navButtons = this.el.querySelectorAll(
      '[phx-click="next_timeline_image"], [phx-click="prev_timeline_image"], [phx-click="goto_timeline_image"]'
    );
    navButtons.forEach((btn) => {
      btn.classList.remove("pointer-events-none");
      const icon = btn.querySelector(".nav-icon");
      const dot = btn.querySelector(".nav-dot");
      const spinner = btn.querySelector(".nav-spinner");

      if (icon) {
        icon.classList.remove("hidden");
      }
      if (dot) {
        dot.classList.remove("hidden");
      }
      if (spinner) {
        spinner.classList.add("hidden");
      }
    });
    this.isNavigating = false;
  },

  navigateNext() {
    const nextBtn = this.el.querySelector('[phx-click="next_timeline_image"]');
    if (nextBtn && !nextBtn.disabled) {
      this.showLoadingState(nextBtn);
      nextBtn.click();
    }
  },

  navigatePrev() {
    const prevBtn = this.el.querySelector('[phx-click="prev_timeline_image"]');
    if (prevBtn && !prevBtn.disabled) {
      this.showLoadingState(prevBtn);
      prevBtn.click();
    }
  },

  preloadAdjacentImages() {
    const currentIndex = parseInt(this.el.dataset.currentIndex || "0", 10);
    const imagesJson = this.el.dataset.images;

    if (!imagesJson || !this.preloadedImages) return;

    try {
      const images = JSON.parse(imagesJson);
      const indicesToPreload = [currentIndex - 1, currentIndex + 1];

      indicesToPreload.forEach((idx) => {
        if (idx >= 0 && idx < images.length && !this.preloadedImages.has(idx)) {
          const img = new Image();
          img.src = images[idx];
          this.preloadedImages.add(idx);
        }
      });
    } catch (e) {
      // JSON parse errors handled silently
    }
  },
};

export default ImageModalHook;
