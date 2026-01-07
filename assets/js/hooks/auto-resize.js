const AutoResize = {
  mounted() {
    this.resizeSmooth();
    this.el.addEventListener("input", () => this.handleInput());
  },

  handleInput() {
    const scrollY = window.scrollY;
    const caretAtEnd = this.isCaretAtEnd();
    
    this.resizeSmooth();
    
    if (caretAtEnd) {
      const bottomOfTextarea = this.el.getBoundingClientRect().bottom;
      const buffer = 180;
      const viewportBottom = window.innerHeight - buffer;
      
      if (bottomOfTextarea > viewportBottom) {
        window.scrollTo({
          top: scrollY + (bottomOfTextarea - viewportBottom),
          behavior: "instant",
        });
      }
    }
  },

  beforeUpdate() {
    this.prevScrollY = window.scrollY;
    this.wasAtEnd = this.isCaretAtEnd();
  },

  updated() {
    requestAnimationFrame(() => {
      this.resizeSmooth();
      
      if (this.wasAtEnd) {
        const bottomOfTextarea = this.el.getBoundingClientRect().bottom;
        const buffer = 180;
        const viewportBottom = window.innerHeight - buffer;
        
        if (bottomOfTextarea > viewportBottom) {
          window.scrollTo({
            top: window.scrollY + (bottomOfTextarea - viewportBottom),
            behavior: "instant",
          });
        }
      } else {
        window.scrollTo({
          top: this.prevScrollY,
          behavior: "instant",
        });
      }
    });
  },

  resizeSmooth() {
    const currentHeight = this.el.offsetHeight;
    const scrollHeight = this.el.scrollHeight;
    const minHeight = 400;
    const targetHeight = Math.max(scrollHeight, minHeight);
    
    if (targetHeight !== currentHeight) {
      this.el.style.height = targetHeight + "px";
    }
  },

  isCaretAtEnd() {
    const selection = this.el.selectionStart;
    const length = this.el.value.length;
    return selection !== null && selection >= length - 1;
  },
};

export default AutoResize;
