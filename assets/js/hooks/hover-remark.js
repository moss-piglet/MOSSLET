export default HoverRemark = {
  mounted() {
    const remarks = document.getElementsByClassName("remarks");
    this.el.addEventListener("mouseenter", (e) => {
      let remarkId = this.el.id.replace("remarks-", "");
      let targetId = e.currentTarget.id.replace("remarks-", "");
      if (remarkId == targetId) {
        showEl = document.getElementById(`remark-${remarkId}-buttons`);
        if (showEl) {
          liveSocket.execJS(showEl, this.el.getAttribute("data-toggle"));
        }
      }
    });

    this.el.addEventListener("mouseleave", (e) => {
      let remarkId = this.el.id.replace("remarks-", "");
      let targetId = e.currentTarget.id.replace("remarks-", "");
      if (remarkId == targetId) {
        showEl = document.getElementById(`remark-${remarkId}-buttons`);
        if (showEl) {
          liveSocket.execJS(showEl, this.el.getAttribute("data-toggle"));
        }
      }
    });
  },
};
