const KeywordFilterInput = {
  mounted() {
    // Listen for clear-input events from the server
    this.handleEvent("clear-input", ({id}) => {
      if (id === this.el.id) {
        this.el.value = "";
        this.el.focus();
      }
    });
  }
};

export default KeywordFilterInput;