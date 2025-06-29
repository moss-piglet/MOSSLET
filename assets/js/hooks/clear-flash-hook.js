/*
 * This is a simple hook to ensure that if the Flash
 * component dispatches a "clear-flash" event that it will
 * be correctly handled when used as part of a live view.
 *
 * The Flash component uses AlpineJS to define behavior
 * such as when the progress bar is shown and when to hide the
 * flash. Whenever the flash is hidden the
 * "clear-flash" element is dispatched.
 */
const ClearFlashHook = {
  animationClasses: ["transition-opacity", "duration-300", "ease-out"],

  mounted() {
    if (this.el.dataset.isStatic !== "true") {
      this.setup();
    }
  },

  updated() {
    const { el } = this;
    const progressBar = el.querySelector(".progress");
    el.classList.remove("hidden");

    if (progressBar) {
      const timerLength = el.dataset.timerLength;
      const remainingTime = timerLength - this.time - 100;

      progressBar.style.transitionDuration = "0ms";
      progressBar.style.width = `${(this.time / timerLength) * 100}%`;
      progressBar.style.transitionDuration = `${remainingTime}ms`;

      setTimeout(() => {
        progressBar.style.width = "100%";
      }, 100);
    }
  },

  destroyed() {
    this.stop();
  },

  setup() {
    const { el } = this;
    const progressBar = el.querySelector(".progress");
    const { timerLength } = el.dataset;

    // Bind the stop() function to the ClearFlashHook object
    this.stop = this.stop.bind(this);

    el.addEventListener("click", this.stop);
    el.addEventListener("clear-flash", this.stop);

    if (progressBar) {
      // Set progress bar width to 100% after 100ms
      setTimeout(() => {
        progressBar.style.width = "100%";
        progressBar.style.transitionDuration = `${timerLength}ms`;
      }, 100);

      this.timer = setTimeout(this.stop, timerLength);

      this.time = 0;
      this.interval = setInterval(() => {
        this.time += 100;
        if (this.time >= timerLength) {
          clearInterval(this.interval);
        }
      }, 100);
    }
  },

  stop() {
    const { el } = this;
    const flashType = el.dataset.type;

    el.removeEventListener("click", this.stop);
    el.removeEventListener("clear-flash", this.stop);

    clearTimeout(this.timer);
    clearInterval(this.interval);

    // Fade out el using Tailwind classes
    el.classList.add(...this.animationClasses);
    el.classList.add("opacity-0");

    // Remove el from the DOM after 300ms
    setTimeout(() => {
      el.remove();
    }, 300);
  },
};

export default ClearFlashHook;
