const CSSBookBackCoverClick = {
  mounted() {
    this.handleClick = this.handleClick.bind(this);
    this.handleTouch = this.handleTouch.bind(this);
    
    this.el.addEventListener('click', this.handleClick);
    this.el.addEventListener('touchend', this.handleTouch);
  },

  destroyed() {
    this.el.removeEventListener('click', this.handleClick);
    this.el.removeEventListener('touchend', this.handleTouch);
  },

  handleClick(e) {
    e.preventDefault();
    this.scrollToPreviousPage();
  },

  handleTouch(e) {
    e.preventDefault();
    this.scrollToPreviousPage();
  },

  scrollToPreviousPage() {
    const container = document.getElementById('book-scroll-container');
    if (container) {
      const pageWidth = window.innerWidth;
      const totalPages = Math.ceil(container.scrollWidth / pageWidth);
      container.scrollTo({
        left: (totalPages - 2) * pageWidth,
        behavior: 'smooth'
      });
    }
  }
};

export default CSSBookBackCoverClick;
