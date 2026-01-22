const BookScrollReader = {
  mounted() {
    this.container = this.el;
    this.container.__bookScrollReader = this;
    this.updatePageInfo = this.updatePageInfo.bind(this);
    this.handleScroll = this.handleScroll.bind(this);
    this.handleKeyboard = this.handleKeyboard.bind(this);
    this.handleResize = this.handleResize.bind(this);
    this.recalculatePages = this.recalculatePages.bind(this);
    this.scrollTimeout = null;
    this.recalcTimeout = null;
    this.lastWidth = window.innerWidth;
    this.isMobile = window.innerWidth < 768;
    this.totalContentPages = 0;
    this.pageElements = [];
    this.pageOffsets = [];
    
    this.container.addEventListener('scroll', this.handleScroll, { passive: true });
    window.addEventListener('keydown', this.handleKeyboard);
    window.addEventListener('resize', this.handleResize);
    
    const prevBtn = document.getElementById('book-prev-btn');
    const nextBtn = document.getElementById('book-next-btn');
    
    if (prevBtn) {
      prevBtn.addEventListener('click', (e) => {
        e.preventDefault();
        this.prevPage();
      });
    }
    
    if (nextBtn) {
      nextBtn.addEventListener('click', (e) => {
        e.preventDefault();
        this.nextPage();
      });
    }
    
    requestAnimationFrame(() => {
      this.recalculatePages();
      const initialPage = parseInt(this.el.dataset.initialPage, 10) || 0;
      this.scrollToPage(initialPage, false);
      this.updatePageInfo();
    });
  },

  updated() {
    requestAnimationFrame(() => {
      this.recalculatePages();
    });
  },

  destroyed() {
    this.container.removeEventListener('scroll', this.handleScroll);
    window.removeEventListener('keydown', this.handleKeyboard);
    window.removeEventListener('resize', this.handleResize);
    if (this.recalcTimeout) clearTimeout(this.recalcTimeout);
  },

  recalculatePages() {
    if (this.recalcTimeout) clearTimeout(this.recalcTimeout);
    
    this.recalcTimeout = setTimeout(() => {
      const allPages = this.container.querySelectorAll('.book-column-page, .book-column-page-full');
      this.pageElements = Array.from(allPages);
      
      this.pageOffsets = [];
      let currentOffset = 0;
      this.pageElements.forEach((page) => {
        this.pageOffsets.push(currentOffset);
        currentOffset += page.offsetWidth;
      });
      
      let contentPageNum = 0;
      this.pageElements.forEach((page, idx) => {
        const pageType = page.dataset.pageType;
        if (pageType === 'content') {
          contentPageNum++;
          const pageNumEl = page.querySelector('[data-page-num]');
          if (pageNumEl) {
            pageNumEl.textContent = contentPageNum;
          }
        }
      });
      
      this.totalContentPages = contentPageNum;
      this.updatePageInfo();
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
    
    if (wasMobile !== this.isMobile || Math.abs(window.innerWidth - this.lastWidth) > 50) {
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
    if (e.key === 'ArrowRight') {
      e.preventDefault();
      this.nextPage();
    } else if (e.key === 'ArrowLeft') {
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
      if (page && page.dataset.pageType === 'content') {
        contentPagesSeen++;
      }
    }
    
    const currentPage = this.pageElements[scrollIndex];
    if (currentPage) {
      if (currentPage.dataset.pageType === 'content') {
        return contentPagesSeen + 1;
      } else if (currentPage.dataset.pageType === 'end') {
        return this.totalContentPages + 1;
      } else if (currentPage.dataset.pageType === 'back-cover') {
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
        if (page && page.dataset.pageType === 'content') {
          contentPagesSeen++;
          if (contentPagesSeen === contentPage) {
            targetScrollIndex = i;
            break;
          }
        }
      }
    } else if (contentPage === this.totalContentPages + 1) {
      for (let i = 0; i < this.pageElements.length; i++) {
        if (this.pageElements[i]?.dataset.pageType === 'end') {
          targetScrollIndex = i;
          break;
        }
      }
    } else {
      for (let i = 0; i < this.pageElements.length; i++) {
        if (this.pageElements[i]?.dataset.pageType === 'back-cover') {
          targetScrollIndex = i;
          break;
        }
      }
    }
    
    const scrollPos = this.pageOffsets[targetScrollIndex] || 0;
    this.container.scrollTo({
      left: scrollPos,
      behavior: smooth ? 'smooth' : 'instant'
    });
  },

  nextPage() {
    const currentIndex = this.getCurrentScrollIndex();
    const maxIndex = this.pageElements.length - 1;
    
    if (currentIndex < maxIndex) {
      const scrollPos = this.pageOffsets[currentIndex + 1] || 0;
      this.container.scrollTo({
        left: scrollPos,
        behavior: 'smooth'
      });
    }
  },

  prevPage() {
    const currentIndex = this.getCurrentScrollIndex();
    
    if (currentIndex > 0) {
      const scrollPos = this.pageOffsets[currentIndex - 1] || 0;
      this.container.scrollTo({
        left: scrollPos,
        behavior: 'smooth'
      });
    }
  },

  updatePageInfo() {
    const currentPage = this.getCurrentContentPage();
    const total = this.totalContentPages;
    
    const indicator = document.getElementById('book-page-indicator');
    if (indicator) {
      if (currentPage === 0) {
        indicator.textContent = 'Front Cover';
      } else if (currentPage <= total) {
        indicator.textContent = `Page ${currentPage} of ${total}`;
      } else if (currentPage === total + 1) {
        indicator.textContent = 'The End';
      } else {
        indicator.textContent = 'Back Cover';
      }
    }
    
    this.pushEvent('page_scroll_update', {
      current_page: currentPage,
      total_pages: total + 2,
      is_mobile: this.isMobile
    });
  }
};

export default BookScrollReader;
