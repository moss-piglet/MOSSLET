// Problem: When a live_patch link is clicked on a page with
// vertical scroll it doesn't scroll to the top. This fixes that

const ScrollTopHook = {
  mounted() {
    // Add this to any link that is a push_patch
    // <.link phx-hook="ScrollTopHook" link_type="live_patch" ... />
    this.el.addEventListener("click", () => {
      window.scrollTo(0, 0);
    });

    // Use this on the server if need be:
    // push_event(socket, "scroll_to_top", %{})
    this.handleEvent("scroll_to_top", () => {
      window.scrollTo(0, 0);
    });
  },
};

export default ScrollTopHook;
