const ScrollableTabs = {
  mounted() {
    this.scrollToActiveTab();
    
    this.el.addEventListener("click", (e) => {
      const button = e.target.closest("button[phx-click='switch_tab']");
      if (button) {
        setTimeout(() => this.centerTab(button), 50);
      }
    });
  },

  updated() {
    this.scrollToActiveTab();
  },

  scrollToActiveTab() {
    const activeButton = this.el.querySelector("button[data-active='true']");
    if (activeButton) {
      this.centerTab(activeButton);
    }
  },

  centerTab(button) {
    const container = this.el;
    const containerWidth = container.offsetWidth;
    const buttonLeft = button.offsetLeft;
    const buttonWidth = button.offsetWidth;
    
    const scrollPosition = buttonLeft - (containerWidth / 2) + (buttonWidth / 2);
    
    container.scrollTo({
      left: Math.max(0, scrollPosition),
      behavior: "smooth"
    });
  }
};

export default ScrollableTabs;
