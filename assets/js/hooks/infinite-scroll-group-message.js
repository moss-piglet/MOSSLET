export default InfiniteScrollGroupMessage = {
  loadMore(entries) {
    const target = entries[0];
    if (target.isIntersecting) {
      this.pushEvent("load_more", {});
    }
  },
  mounted() {
    const scrollContainer = document.getElementById("messages-container");
    this.observer = new IntersectionObserver(
      (entries) => this.loadMore(entries),
      {
        root: scrollContainer,
        rootMargin: "400px",
        threshold: 0.1,
      }
    );
    this.observer.observe(this.el);
  },
  destroyed() {
    this.observer.unobserve(this.el);
  },
};
