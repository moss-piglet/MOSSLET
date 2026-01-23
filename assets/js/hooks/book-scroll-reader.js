const BookScrollReader = {
  mounted() {
    this.container = this.el;
    this.container.__bookScrollReader = this;
    this.updatePageInfo = this.updatePageInfo.bind(this);
    this.handleScroll = this.handleScroll.bind(this);
    this.handleKeyboard = this.handleKeyboard.bind(this);
    this.handleResize = this.handleResize.bind(this);
    this.recalculatePages = this.recalculatePages.bind(this);
    this.animateBookClose = this.animateBookClose.bind(this);
    this.smoothScrollTo = this.smoothScrollTo.bind(this);
    this.scrollTimeout = null;
    this.recalcTimeout = null;
    this.scrollAnimationId = null;
    this.lastWidth = window.innerWidth;
    this.isMobile = window.innerWidth < 768;
    this.totalContentPages = 0;
    this.pageElements = [];
    this.pageOffsets = [];
    this.isNavigatingAway = false;
    this.lastPushedPage = null;
    this.pendingNavigation = null;
    this.isAnimatingScroll = false;
    this.isSettling = false;

    this.container.classList.add("no-scroll-snap");

    this.container.addEventListener("scroll", this.handleScroll, {
      passive: true,
    });
    window.addEventListener("keydown", this.handleKeyboard);
    window.addEventListener("resize", this.handleResize);

    this.handleLinkClick = (e) => {
      const link = e.target.closest("a[href]");
      if (
        link &&
        !link.closest("#book-prev-btn") &&
        !link.closest("#book-next-btn")
      ) {
        const currentPage = this.getCurrentContentPage();
        const backCoverPage = this.totalContentPages + 2;

        if (currentPage < backCoverPage && this.pageElements.length > 0) {
          e.preventDefault();
          e.stopPropagation();
          this.isNavigatingAway = true;
          this.pendingNavigation = link;
          this.animateBookClose();
        } else {
          this.isNavigatingAway = true;
          this.container.classList.add("no-scroll-snap");
        }
      }
    };
    document.addEventListener("click", this.handleLinkClick, true);

    this.handlePageLoadingStart = () => {
      this.isNavigatingAway = true;
      this.container.classList.add("no-scroll-snap");
    };
    window.addEventListener(
      "phx:page-loading-start",
      this.handlePageLoadingStart
    );

    const prevBtn = document.getElementById("book-prev-btn");
    const nextBtn = document.getElementById("book-next-btn");

    if (prevBtn) {
      prevBtn.addEventListener("click", (e) => {
        e.preventDefault();
        this.prevPage();
      });
    }

    if (nextBtn) {
      nextBtn.addEventListener("click", (e) => {
        e.preventDefault();
        this.nextPage();
      });
    }

    requestAnimationFrame(() => {
      this.recalculatePages(() => {
        const initialPage = parseInt(this.el.dataset.initialPage, 10) || 0;
        this.lastPushedPage = initialPage;

        if (initialPage === 0) {
          this.scrollToPage(0, false);
          requestAnimationFrame(() => {
            requestAnimationFrame(() => {
              this.container.classList.remove("opacity-0");
              this.container.classList.remove("no-scroll-snap");
              this.updatePageInfo();
            });
          });
        } else {
          this.scrollToPage(0, false);

          requestAnimationFrame(() => {
            this.container.classList.remove("opacity-0");

            setTimeout(() => {
              const scrollPos =
                this.pageOffsets[
                  this.getScrollIndexForContentPage(initialPage)
                ] || 0;
              const distance = Math.abs(scrollPos - this.container.scrollLeft);
              const containerWidth = this.container.clientWidth;
              const baseDuration = 400;
              const maxDuration = 1200;
              const minDuration = 300;
              const duration = Math.min(
                maxDuration,
                Math.max(
                  minDuration,
                  baseDuration + (distance / containerWidth) * 200
                )
              );
              this.smoothScrollTo(scrollPos, duration, () => {
                this.container.classList.remove("no-scroll-snap");
                this.updatePageInfo();
              });
            }, 400);
          });
        }
      });
    });
  },

  updated() {
    this.isSettling = true;
    requestAnimationFrame(() => {
      this.recalculatePages(() => {
        setTimeout(() => {
          this.isSettling = false;
        }, 200);
      });
    });
  },

  destroyed() {
    this.isNavigatingAway = true;
    this.container.removeEventListener("scroll", this.handleScroll);
    window.removeEventListener("keydown", this.handleKeyboard);
    window.removeEventListener("resize", this.handleResize);
    window.removeEventListener(
      "phx:page-loading-start",
      this.handlePageLoadingStart
    );
    document.removeEventListener("click", this.handleLinkClick, true);
    if (this.scrollTimeout) clearTimeout(this.scrollTimeout);
    if (this.recalcTimeout) clearTimeout(this.recalcTimeout);
    if (this.scrollAnimationId) cancelAnimationFrame(this.scrollAnimationId);
  },

  recalculatePages(callback) {
    if (this.recalcTimeout) clearTimeout(this.recalcTimeout);

    this.recalcTimeout = setTimeout(() => {
      const contentBlankPage = this.container.querySelector(
        ".book-content-blank-page"
      );

      const allPages = this.container.querySelectorAll(
        ".book-column-page, .book-column-page-full, .book-end-page, .book-content-blank-page"
      );
      this.pageElements = Array.from(allPages);

      let contentPageNum = 0;
      let contentPageIndex = 0;
      this.pageElements.forEach((page, idx) => {
        const pageType = page.dataset.pageType;
        if (pageType === "content") {
          contentPageNum++;
          const pageNumEl = page.querySelector("[data-page-num]");
          if (pageNumEl) {
            pageNumEl.textContent = contentPageNum;
          }
          if (contentPageIndex % 2 === 0) {
            page.dataset.spreadStart = "true";
          } else {
            delete page.dataset.spreadStart;
          }
          contentPageIndex++;
        }
      });

      this.totalContentPages = contentPageNum;

      if (contentBlankPage) {
        const needsContentBlank = contentPageNum % 2 === 1;
        contentBlankPage.dataset.visible = needsContentBlank.toString();
      }

      this.pageOffsets = [];
      let currentOffset = 0;
      this.pageElements.forEach((page) => {
        this.pageOffsets.push(currentOffset);
        currentOffset += page.offsetWidth;
      });

      if (callback) {
        callback();
      } else {
        this.updatePageInfo();
      }
    }, 50);
  },

  handleScroll() {
    if (this.scrollTimeout) clearTimeout(this.scrollTimeout);
    this.scrollTimeout = setTimeout(() => {
      this.updatePageInfo();
    }, 50);
  },

  handleResize() {
    const wasMobile = this.isMobile;
    this.isMobile = window.innerWidth < 768;

    if (
      wasMobile !== this.isMobile ||
      Math.abs(window.innerWidth - this.lastWidth) > 50
    ) {
      this.lastWidth = window.innerWidth;
      const currentPage = this.getCurrentContentPage();

      requestAnimationFrame(() => {
        this.recalculatePages();
        setTimeout(() => {
          this.scrollToPage(currentPage, false);
          this.updatePageInfo();
        }, 100);
      });
    }
  },

  handleKeyboard(e) {
    if (e.key === "ArrowRight") {
      e.preventDefault();
      this.nextPage();
    } else if (e.key === "ArrowLeft") {
      e.preventDefault();
      this.prevPage();
    }
  },

  getCurrentScrollIndex() {
    const scrollLeft = this.container.scrollLeft;
    const threshold = 50;

    for (let i = this.pageOffsets.length - 1; i >= 0; i--) {
      if (scrollLeft >= this.pageOffsets[i] - threshold) {
        return i;
      }
    }
    return 0;
  },

  getCurrentContentPage() {
    const scrollIndex = this.getCurrentScrollIndex();

    if (scrollIndex === 0) return 0;

    let contentPagesSeen = 0;
    for (let i = 0; i < scrollIndex && i < this.pageElements.length; i++) {
      const page = this.pageElements[i];
      if (page && page.dataset.pageType === "content") {
        contentPagesSeen++;
      }
    }

    const currentPage = this.pageElements[scrollIndex];
    if (currentPage) {
      if (currentPage.dataset.pageType === "content") {
        return contentPagesSeen + 1;
      } else if (currentPage.dataset.pageType === "end") {
        return this.totalContentPages + 1;
      } else if (currentPage.dataset.pageType === "back-cover") {
        return this.totalContentPages + 2;
      }
    }

    return contentPagesSeen;
  },

  scrollToPage(contentPage, smooth = true) {
    let targetScrollIndex = 0;

    if (contentPage === 0) {
      targetScrollIndex = 0;
    } else if (contentPage <= this.totalContentPages) {
      let contentPagesSeen = 0;
      for (let i = 0; i < this.pageElements.length; i++) {
        const page = this.pageElements[i];
        if (page && page.dataset.pageType === "content") {
          contentPagesSeen++;
          if (contentPagesSeen === contentPage) {
            targetScrollIndex = i;
            break;
          }
        }
      }
    } else if (contentPage === this.totalContentPages + 1) {
      for (let i = 0; i < this.pageElements.length; i++) {
        if (this.pageElements[i]?.dataset.pageType === "end") {
          targetScrollIndex = i;
          break;
        }
      }
    } else {
      for (let i = 0; i < this.pageElements.length; i++) {
        if (this.pageElements[i]?.dataset.pageType === "back-cover") {
          targetScrollIndex = i;
          break;
        }
      }
    }

    const scrollPos = this.pageOffsets[targetScrollIndex] || 0;
    if (smooth) {
      this.container.scrollTo({
        left: scrollPos,
        behavior: "smooth",
      });
    } else {
      this.container.scrollLeft = scrollPos;
    }
  },

  nextPage() {
    const currentIndex = this.getCurrentScrollIndex();
    const maxIndex = this.pageElements.length - 1;

    if (currentIndex >= maxIndex) return;

    if (this.isMobile) {
      const scrollPos = this.pageOffsets[currentIndex + 1] || 0;
      this.container.scrollTo({
        left: scrollPos,
        behavior: "smooth",
      });
    } else {
      let nextSpreadIndex = this.findNextSpreadStart(currentIndex);
      if (nextSpreadIndex !== null && nextSpreadIndex <= maxIndex) {
        const scrollPos = this.pageOffsets[nextSpreadIndex] || 0;
        this.container.scrollTo({
          left: scrollPos,
          behavior: "smooth",
        });
      }
    }
  },

  smoothScrollTo(targetX, duration, callback) {
    if (this.scrollAnimationId) {
      cancelAnimationFrame(this.scrollAnimationId);
    }

    this.container.style.setProperty("scroll-behavior", "auto", "important");

    const startX = this.container.scrollLeft;
    const distance = targetX - startX;
    const startTime = performance.now();

    const easeOutExpo = (t) => {
      return t === 1 ? 1 : 1 - Math.pow(2, -10 * t);
    };

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const eased = easeOutExpo(progress);

      this.container.scrollLeft = startX + distance * eased;

      if (progress < 1) {
        this.scrollAnimationId = requestAnimationFrame(animate);
      } else {
        this.scrollAnimationId = null;
        this.container.style.removeProperty("scroll-behavior");
        if (callback) {
          callback();
        }
      }
    };

    this.scrollAnimationId = requestAnimationFrame(animate);
  },

  getScrollIndexForContentPage(contentPage) {
    if (contentPage === 0) return 0;

    if (contentPage <= this.totalContentPages) {
      let contentPagesSeen = 0;
      for (let i = 0; i < this.pageElements.length; i++) {
        const page = this.pageElements[i];
        if (page && page.dataset.pageType === "content") {
          contentPagesSeen++;
          if (contentPagesSeen === contentPage) {
            return i;
          }
        }
      }
    } else if (contentPage === this.totalContentPages + 1) {
      for (let i = 0; i < this.pageElements.length; i++) {
        if (this.pageElements[i]?.dataset.pageType === "end") {
          return i;
        }
      }
    } else {
      for (let i = 0; i < this.pageElements.length; i++) {
        if (this.pageElements[i]?.dataset.pageType === "back-cover") {
          return i;
        }
      }
    }
    return 0;
  },

  prevPage() {
    const currentIndex = this.getCurrentScrollIndex();

    if (currentIndex <= 0) return;

    if (this.isMobile) {
      const scrollPos = this.pageOffsets[currentIndex - 1] || 0;
      this.container.scrollTo({
        left: scrollPos,
        behavior: "smooth",
      });
    } else {
      let prevSpreadIndex = this.findPrevSpreadStart(currentIndex);
      if (prevSpreadIndex !== null && prevSpreadIndex >= 0) {
        const scrollPos = this.pageOffsets[prevSpreadIndex] || 0;
        this.container.scrollTo({
          left: scrollPos,
          behavior: "smooth",
        });
      }
    }
  },

  findNextSpreadStart(currentIndex) {
    for (let i = currentIndex + 1; i < this.pageElements.length; i++) {
      const page = this.pageElements[i];
      if (
        page.classList.contains("book-column-page-full") ||
        page.classList.contains("book-end-page")
      ) {
        return i;
      }
      if (page.dataset.spreadStart === "true") {
        return i;
      }
      if (page.dataset.pageType === "content-blank") {
        continue;
      }
    }
    const backIndex = this.pageElements.findIndex(
      (p) => p.dataset.pageType === "back-cover"
    );
    if (backIndex > currentIndex) return backIndex;
    return null;
  },

  findPrevSpreadStart(currentIndex) {
    for (let i = currentIndex - 1; i >= 0; i--) {
      const page = this.pageElements[i];
      if (
        page.classList.contains("book-column-page-full") ||
        page.classList.contains("book-end-page")
      ) {
        return i;
      }
      if (page.dataset.pageType === "content-blank") {
        continue;
      }
      if (page.dataset.spreadStart === "true") {
        return i;
      }
    }
    return 0;
  },

  animateBookClose() {
    this.isAnimatingScroll = true;
    this.container.classList.add("no-scroll-snap");
    this.container.style.setProperty("scroll-snap-type", "none", "important");
    this.container.style.setProperty("scroll-behavior", "auto", "important");

    this.pageElements.forEach((el) => {
      el.style.setProperty("scroll-snap-align", "none", "important");
      el.style.setProperty("scroll-snap-stop", "normal", "important");
    });

    const indicator = document.getElementById("book-page-indicator");
    if (indicator) {
      indicator.textContent = "Closing...";
    }

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        const maxScroll =
          this.container.scrollWidth - this.container.clientWidth;
        const distance = Math.abs(maxScroll - this.container.scrollLeft);
        const containerWidth = this.container.clientWidth;
        const baseDuration = 400;
        const maxDuration = 1200;
        const minDuration = 300;
        const duration = Math.min(
          maxDuration,
          Math.max(
            minDuration,
            baseDuration + (distance / containerWidth) * 200
          )
        );
        this.smoothScrollTo(maxScroll, duration, () => {
          if (this.pendingNavigation) {
            const link = this.pendingNavigation;
            this.pendingNavigation = null;

            if (
              link.dataset.phxLink === "redirect" ||
              link.dataset.phxLink === "patch"
            ) {
              link.click();
            } else if (link.href) {
              window.location.href = link.href;
            }
          }
        });
      });
    });
  },

  updatePageInfo() {
    if (this.isNavigatingAway || this.isSettling) return;

    const currentPage = this.getCurrentContentPage();
    const total = this.totalContentPages;
    const backCover = total + 2;

    const indicator = document.getElementById("book-page-indicator");
    if (indicator) {
      if (currentPage === 0) {
        indicator.textContent = "Front Cover";
      } else if (currentPage <= total) {
        indicator.textContent = `Page ${currentPage} of ${total}`;
      } else if (currentPage === total + 1) {
        indicator.textContent = "The End";
      } else {
        indicator.textContent = "Close";
      }
      indicator.classList.remove("opacity-0");
    }

    const prevBtn = document.getElementById("book-prev-btn");
    const prevLabel = document.getElementById("book-prev-label");
    if (prevBtn) {
      if (currentPage === 0) {
        prevBtn.classList.add("invisible");
      } else {
        prevBtn.classList.remove("opacity-0", "invisible");
        if (prevLabel) {
          if (currentPage === 1) {
            prevLabel.textContent = "Cover";
          } else if (currentPage <= total) {
            prevLabel.textContent = `Page ${currentPage - 1}`;
          } else if (currentPage === total + 1) {
            prevLabel.textContent = `Page ${total}`;
          } else {
            prevLabel.textContent = "The End";
          }
        }
      }
    }

    const nextBtn = document.getElementById("book-next-btn");
    const nextLabel = document.getElementById("book-next-label");
    if (nextBtn) {
      if (currentPage >= backCover) {
        nextBtn.classList.add("invisible");
      } else {
        nextBtn.classList.remove("opacity-0", "invisible");
        if (nextLabel) {
          if (currentPage === 0) {
            nextLabel.textContent = "Page 1";
          } else if (currentPage < total) {
            nextLabel.textContent = `Page ${currentPage + 1}`;
          } else if (currentPage === total) {
            nextLabel.textContent = "The End";
          } else {
            nextLabel.textContent = "Close";
          }
        }
      }
    }

    if (this.lastPushedPage === currentPage) return;
    this.lastPushedPage = currentPage;

    this.pushEvent("page_scroll_update", {
      current_page: currentPage,
      total_pages: total + 2,
      is_mobile: this.isMobile,
    });
  },
};

export default BookScrollReader;
