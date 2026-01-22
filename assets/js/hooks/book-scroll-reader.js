const BookScrollReader = {
  mounted() {
    this.container = this.el;
    this.updatePageInfo = this.updatePageInfo.bind(this);
    this.handleScroll = this.handleScroll.bind(this);
    this.handleKeyboard = this.handleKeyboard.bind(this);
    this.scrollTimeout = null;
    this.isMobile = window.innerWidth < 768;
    
    this.container.addEventListener('scroll', this.handleScroll, { passive: true });
    window.addEventListener('keydown', this.handleKeyboard);
    window.addEventListener('resize', () => {
      this.isMobile = window.innerWidth < 768;
      this.updatePageInfo();
    });
    
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
      if (initialPage > 0) {
        this.scrollToPage(initialPage, false);
      }
      this.updatePageInfo();
    });
  },

  destroyed() {
    this.container.removeEventListener('scroll', this.handleScroll);
    window.removeEventListener('keydown', this.handleKeyboard);
  },

  handleScroll() {
    if (this.scrollTimeout) clearTimeout(this.scrollTimeout);
    this.scrollTimeout = setTimeout(() => {
      this.updatePageInfo();
    }, 50);
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

  getCurrentPage() {
    const scrollLeft = this.container.scrollLeft;
    const pageWidth = this.getPageWidth();
    return Math.round(scrollLeft / pageWidth);
  },

  getTotalPages() {
    const scrollWidth = this.container.scrollWidth;
    const pageWidth = this.getPageWidth();
    return Math.ceil(scrollWidth / pageWidth);
  },

  nextPage() {
    const currentPage = this.getCurrentPage();
    const totalPages = this.getTotalPages();
    if (currentPage < totalPages - 1) {
      this.scrollToPage(currentPage + 1);
    }
  },

  prevPage() {
    const currentPage = this.getCurrentPage();
    if (currentPage > 0) {
      this.scrollToPage(currentPage - 1);
    }
  },

  scrollToPage(page, smooth = true) {
    const pageWidth = this.getPageWidth();
    this.container.scrollTo({
      left: page * pageWidth,
      behavior: smooth ? 'smooth' : 'instant'
    });
  },

  updatePageInfo() {
    const currentPage = this.getCurrentPage();
    const totalPages = this.getTotalPages();
    
    this.pushEvent('page_scroll_update', {
      current_page: currentPage,
      total_pages: totalPages,
      is_mobile: this.isMobile
    });
  }
};

export default BookScrollReader;
