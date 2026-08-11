// ScrollToReply — deep-link affordance for the post show page.
//
// Placed on the replies stream container. When the page is opened with a
// `?reply=<id>` param (e.g. from the dashboard "New replies" card), the
// container carries data-target-reply-id; the hook scrolls the matching reply
// card into view and gives it a brief highlight ring so the reader can spot it
// immediately. No-op when the reply isn't on the current page of the stream
// (e.g. an older reply behind pagination) — the thread is still right there.
//
// It manages no DOM of its own (only transient classes), so it composes with
// phx-update="stream" on the same element.
const ScrollToReply = {
  mounted() {
    this._scrollToTarget();
  },

  updated() {
    this._scrollToTarget();
  },

  _scrollToTarget() {
    const replyId = this.el.dataset.targetReplyId;
    if (!replyId || this._scrolledTo === replyId) return;

    const target = document.getElementById(`reply-${replyId}`);
    if (!target) return;

    this._scrolledTo = replyId;

    requestAnimationFrame(() => {
      target.scrollIntoView({ behavior: "smooth", block: "center" });

      const card = target.closest('[id^="replies-"]') || target;
      card.classList.add(
        "ring-2",
        "ring-emerald-300",
        "dark:ring-emerald-400",
        "transition-shadow",
        "duration-500"
      );

      setTimeout(() => {
        card.classList.remove(
          "ring-2",
          "ring-emerald-300",
          "dark:ring-emerald-400",
          "transition-shadow",
          "duration-500"
        );
      }, 2600);
    });
  },
};

export default ScrollToReply;
