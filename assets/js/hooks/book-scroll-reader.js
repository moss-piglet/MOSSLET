const BookScrollReader = {
  mounted() {
    this.container = this.el;
    this.updatePageInfo = this.updatePageInfo.bind(this);
    this.handleScroll = this.handleScroll.bind(this);
    this.handleKeyboard = this.handleKeyboard.bind(this);
    this.handleResize = this.handleResize.bind(this);
    this.detectOverflow = this.detectOverflow.bind(this);
    this.scrollTimeout = null;
    this.overflowTimeout = null;
    this.lastWidth = window.innerWidth;
    this.isMobile = window.innerWidth < 768;
    this.totalContentPages = parseInt(this.el.dataset.totalContentPages, 10) || 0;
    this.overflowPages = {};
    
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
      const initialPage = parseInt(this.el.dataset.initialPage, 10) || 0;
      this.scrollToContentPage(initialPage, false);
      this.updatePageInfo();
      this.detectOverflow();
    });
  },

  updated() {
    requestAnimationFrame(() => {
      this.totalContentPages = parseInt(this.el.dataset.totalContentPages, 10) || 0;
      this.detectOverflow();
    });
  },

  destroyed() {
    this.container.removeEventListener('scroll', this.handleScroll);
    window.removeEventListener('keydown', this.handleKeyboard);
    window.removeEventListener('resize', this.handleResize);
    if (this.overflowTimeout) clearTimeout(this.overflowTimeout);
  },

  detectOverflow() {
    if (this.overflowTimeout) clearTimeout(this.overflowTimeout);
    
    this.overflowTimeout = setTimeout(() => {
      const contentContainers = this.container.querySelectorAll('[data-page-content]');
      const overflowData = {};
      
      contentContainers.forEach((container) => {
        const entryId = container.dataset.entryId;
        const pageIndex = parseInt(container.dataset.pageIndex, 10) || 0;
        if (!entryId) return;
        
        const columnContent = container.querySelector('[data-column-content]');
        if (!columnContent) return;
        
        const containerWidth = container.clientWidth;
        const scrollWidth = columnContent.scrollWidth;
        
        if (scrollWidth > containerWidth + 10) {
          const columnsNeeded = Math.ceil(scrollWidth / containerWidth);
          const key = `${entryId}-${pageIndex}`;
          overflowData[key] = {
            entry_id: entryId,
            page_index: pageIndex,
            columns_needed: columnsNeeded,
            scroll_width: scrollWidth,
            container_width: containerWidth
          };
        }
      });
      
      const hasOverflow = Object.keys(overflowData).length > 0;
      const overflowChanged = JSON.stringify(overflowData) !== JSON.stringify(this.overflowPages);
      
      if (hasOverflow && overflowChanged) {
        this.overflowPages = overflowData;
        this.pushEvent('content_overflow_detected', { overflow_data: overflowData });
      }
    }, 100);
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
    
    if (wasMobile !== this.isMobile) {
      const currentContentPage = this.getCurrentContentPage();
      
      requestAnimationFrame(() => {
        this.scrollToContentPage(currentContentPage, false);
        this.updatePageInfo();
      });
    }
    
    this.overflowPages = {};
    this.detectOverflow();
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

  getPageWidth() {
    return window.innerWidth;
  },

  getCurrentScrollIndex() {
    const scrollLeft = this.container.scrollLeft;
    const pageWidth = this.getPageWidth();
    return Math.round(scrollLeft / pageWidth);
  },

  getTotalScrollUnits() {
    const total = this.totalContentPages;
    const isOdd = total % 2 === 1;
    
    if (this.isMobile) {
      return total + 3;
    } else {
      const contentSpreads = Math.ceil(total / 2);
      if (isOdd) {
        return 1 + contentSpreads + 1;
      } else {
        return 1 + contentSpreads + 1 + 1;
      }
    }
  },

  getCurrentContentPage() {
    const scrollIndex = this.getCurrentScrollIndex();
    const total = this.totalContentPages;
    const isOdd = total % 2 === 1;
    
    if (this.isMobile) {
      if (scrollIndex === 0) return 0;
      if (scrollIndex <= total) return scrollIndex;
      if (scrollIndex === total + 1) return total + 1;
      return total + 2;
    } else {
      if (scrollIndex === 0) return 0;
      
      const lastContentSpreadIdx = Math.ceil(total / 2);
      
      if (isOdd) {
        if (scrollIndex <= lastContentSpreadIdx) {
          return (scrollIndex - 1) * 2 + 1;
        }
        if (scrollIndex === lastContentSpreadIdx + 1) return total + 2;
      } else {
        if (scrollIndex <= lastContentSpreadIdx) {
          return (scrollIndex - 1) * 2 + 1;
        }
        if (scrollIndex === lastContentSpreadIdx + 1) return total + 1;
        if (scrollIndex === lastContentSpreadIdx + 2) return total + 2;
      }
      
      return total + 2;
    }
  },

  scrollToContentPage(contentPage, smooth = true) {
    const total = this.totalContentPages;
    const isOdd = total % 2 === 1;
    const pageWidth = this.getPageWidth();
    let scrollIndex;
    
    if (this.isMobile) {
      if (contentPage === 0) {
        scrollIndex = 0;
      } else if (contentPage <= total) {
        scrollIndex = contentPage;
      } else if (contentPage === total + 1) {
        scrollIndex = total + 1;
      } else {
        scrollIndex = total + 2;
      }
    } else {
      if (contentPage === 0) {
        scrollIndex = 0;
      } else if (contentPage <= total) {
        scrollIndex = Math.ceil(contentPage / 2);
      } else if (contentPage === total + 1) {
        if (isOdd) {
          scrollIndex = Math.ceil(total / 2);
        } else {
          scrollIndex = Math.ceil(total / 2) + 1;
        }
      } else {
        if (isOdd) {
          scrollIndex = Math.ceil(total / 2) + 1;
        } else {
          scrollIndex = Math.ceil(total / 2) + 2;
        }
      }
    }
    
    this.container.scrollTo({
      left: scrollIndex * pageWidth,
      behavior: smooth ? 'smooth' : 'instant'
    });
  },

  nextPage() {
    const currentPage = this.getCurrentContentPage();
    const total = this.totalContentPages;
    const isOdd = total % 2 === 1;
    const maxPage = total + 2;
    
    let nextPage;
    if (this.isMobile) {
      nextPage = Math.min(currentPage + 1, maxPage);
    } else {
      if (currentPage === 0) {
        nextPage = 1;
      } else if (currentPage <= total) {
        if (isOdd && currentPage === total) {
          nextPage = total + 2;
        } else {
          nextPage = Math.min(currentPage + 2, total + 1);
          if (nextPage > total && !isOdd) nextPage = total + 1;
        }
      } else {
        nextPage = Math.min(currentPage + 1, maxPage);
      }
    }
    
    if (nextPage !== currentPage) {
      this.scrollToContentPage(nextPage);
    }
  },

  prevPage() {
    const currentPage = this.getCurrentContentPage();
    const total = this.totalContentPages;
    const isOdd = total % 2 === 1;
    
    let prevPage;
    if (this.isMobile) {
      prevPage = Math.max(currentPage - 1, 0);
    } else {
      if (currentPage === 0) {
        prevPage = 0;
      } else if (currentPage <= 2) {
        prevPage = 0;
      } else if (currentPage <= total) {
        prevPage = currentPage - 2;
        if (prevPage < 1) prevPage = 0;
      } else if (currentPage === total + 1) {
        if (isOdd) {
          prevPage = total;
        } else {
          prevPage = total - 1;
        }
      } else {
        prevPage = total + 1;
      }
    }
    
    if (prevPage !== currentPage) {
      this.scrollToContentPage(prevPage);
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
        if (this.isMobile) {
          indicator.textContent = `Page ${currentPage} of ${total}`;
        } else {
          const leftPage = Math.floor((currentPage - 1) / 2) * 2 + 1;
          const rightPage = Math.min(leftPage + 1, total);
          if (leftPage === rightPage || rightPage > total) {
            indicator.textContent = `Page ${leftPage} of ${total}`;
          } else {
            indicator.textContent = `Pages ${leftPage}-${rightPage} of ${total}`;
          }
        }
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
