const CSSBookCoverClick = {
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
    this.scrollToNextPage();
  },

  handleTouch(e) {
    e.preventDefault();
    this.scrollToNextPage();
  },

  scrollToNextPage() {
    const container = document.getElementById('book-scroll-container');
    if (container) {
      const pageWidth = window.innerWidth;
      container.scrollTo({
        left: pageWidth,
        behavior: 'smooth'
      });
    }
  }
};

export default CSSBookCoverClick;
