const PostExpandHook = {
  mounted() {
    this.expanded = false;
    this.el._postExpandHook = this;

    requestAnimationFrame(() => {
      this.checkOverflow();
    });

    this.resizeObserver = new ResizeObserver(() => {
      if (!this.expanded) {
        this.checkOverflow();
      }
    });
    this.resizeObserver.observe(this.el);
  },

  updated() {
    if (!this.expanded) {
      requestAnimationFrame(() => {
        this.checkOverflow();
      });
    }
  },

  destroyed() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    delete this.el._postExpandHook;
  },

  checkOverflow() {
    const content = this.el.querySelector("[data-post-content]");
    const toggle = this.el.querySelector("[data-post-toggle]");
    const gradient = this.el.querySelector("[data-post-gradient]");

    if (!content || !toggle) return;

    const maxHeightStyle = getComputedStyle(content).maxHeight;
    const maxHeight = parseFloat(maxHeightStyle) || Infinity;
    const isOverflowing = content.scrollHeight > maxHeight;

    if (isOverflowing) {
      toggle.style.display = "inline-flex";
      if (gradient) gradient.classList.remove("hidden");
    } else {
      toggle.style.display = "none";
      if (gradient) gradient.classList.add("hidden");
    }
  },
};

window.addEventListener("click", (e) => {
  const toggle = e.target.closest("[data-post-toggle]");
  if (!toggle) return;

  const article = toggle.closest("article");
  if (!article) return;

  const hook = article._postExpandHook;
  if (!hook) return;

  e.preventDefault();

  const content = article.querySelector("[data-post-content]");
  const gradient = article.querySelector("[data-post-gradient]");
  const expandText = toggle.querySelector("[data-expand-text]");
  const collapseText = toggle.querySelector("[data-collapse-text]");

  if (!content) return;

  hook.expanded = !hook.expanded;

  if (hook.expanded) {
    content.style.maxHeight = content.scrollHeight + "px";
    content.classList.add("expanded");
    if (gradient) gradient.classList.add("hidden");
    if (expandText) expandText.classList.add("hidden");
    if (collapseText) collapseText.classList.remove("hidden");
  } else {
    content.style.maxHeight = "";
    content.classList.remove("expanded");
    if (gradient) gradient.classList.remove("hidden");
    if (expandText) expandText.classList.remove("hidden");
    if (collapseText) collapseText.classList.add("hidden");
  }
});

export default PostExpandHook;
