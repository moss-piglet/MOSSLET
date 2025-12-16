export default HoverGroupMessage = {
  mounted() {
    this.mouseEnterHandler = (e) => {
      const messageId = this.el.id.replace("messages-", "");
      const targetId = e.currentTarget.id.replace("messages-", "");
      if (messageId == targetId) {
        const showEl = document.getElementById(`message-${messageId}-buttons`);
        if (showEl) {
          liveSocket.execJS(showEl, this.el.getAttribute("data-toggle"));
        }
      }
    };

    this.mouseLeaveHandler = (e) => {
      const messageId = this.el.id.replace("messages-", "");
      const targetId = e.currentTarget.id.replace("messages-", "");
      if (messageId == targetId) {
        const showEl = document.getElementById(`message-${messageId}-buttons`);
        if (showEl) {
          liveSocket.execJS(showEl, this.el.getAttribute("data-toggle"));
        }
      }
    };

    this.el.addEventListener("mouseenter", this.mouseEnterHandler);
    this.el.addEventListener("mouseleave", this.mouseLeaveHandler);
  },

  destroyed() {
    this.el.removeEventListener("mouseenter", this.mouseEnterHandler);
    this.el.removeEventListener("mouseleave", this.mouseLeaveHandler);
  },
};
