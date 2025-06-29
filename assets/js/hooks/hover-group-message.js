export default HoverGroupMessage = {
  mounted() {
    const messages = document.getElementsByClassName("messages");
    this.el.addEventListener("mouseenter", (e) => {
      let messageId = this.el.id.replace("messages-", "");
      let targetId = e.currentTarget.id.replace("messages-", "");
      if (messageId == targetId) {
        showEl = document.getElementById(`message-${messageId}-buttons`);
        if (showEl) {
          liveSocket.execJS(showEl, this.el.getAttribute("data-toggle"));
        }
      }
    });

    this.el.addEventListener("mouseleave", (e) => {
      let messageId = this.el.id.replace("messages-", "");
      let targetId = e.currentTarget.id.replace("messages-", "");
      if (messageId == targetId) {
        showEl = document.getElementById(`message-${messageId}-buttons`);
        if (showEl) {
          liveSocket.execJS(showEl, this.el.getAttribute("data-toggle"));
        }
      }
    });
  },
};
