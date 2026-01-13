export default {
  mounted() {
    this.limit = parseInt(this.el.dataset.limit || 500);
    this.updateCounter();

    this.focusHandler = () => {
      if (this.getWordCount() > 0) {
        this.showCounter();
      }
    };

    this.blurHandler = () => {
      if (this.getWordCount() === 0) {
        this.hideCounter();
      }
    };

    this.inputHandler = () => {
      if (this.getWordCount() > 0) {
        this.showCounter();
      } else {
        this.hideCounter();
      }
      this.updateCounter();
    };

    this.el.addEventListener("focus", this.focusHandler);
    this.el.addEventListener("blur", this.blurHandler);
    this.el.addEventListener("input", this.inputHandler);
  },

  updated() {
    this.updateCounter();
  },

  destroyed() {
    this.el.removeEventListener("focus", this.focusHandler);
    this.el.removeEventListener("blur", this.blurHandler);
    this.el.removeEventListener("input", this.inputHandler);
  },

  getWordCount() {
    const text = this.el.value || "";
    const words = text.trim().split(/\s+/).filter((word) => word.length > 0);
    return words.length;
  },

  findCounterContainer() {
    return (
      this.el.closest(".relative")?.querySelector('[id*="word-counter"]') ||
      this.el.parentElement.querySelector('[id*="word-counter"]')
    );
  },

  showCounter() {
    const counterContainer = this.findCounterContainer();

    if (counterContainer) {
      counterContainer.classList.remove("word-counter-hidden");
    }
  },

  hideCounter() {
    const counterContainer = this.findCounterContainer();

    if (counterContainer) {
      counterContainer.classList.add("word-counter-hidden");
    }
  },

  updateCounter() {
    const currentWordCount = this.getWordCount();
    const counterEl =
      this.el.parentElement.querySelector(".js-word-count") ||
      this.el.closest(".relative")?.querySelector(".js-word-count");

    if (counterEl) {
      counterEl.textContent = currentWordCount;

      const counterContainer = counterEl.closest("span");
      if (counterContainer) {
        counterContainer.classList.remove(
          "text-slate-500",
          "text-amber-500",
          "text-rose-500"
        );

        const remaining = this.limit - currentWordCount;

        if (remaining < 50) {
          counterContainer.classList.add("text-rose-500");
        } else if (remaining < 100) {
          counterContainer.classList.add("text-amber-500");
        } else {
          counterContainer.classList.add("text-slate-500");
        }
      }
    }

    const composerContainer = this.el.closest('[class*="rounded-2xl"]');
    if (composerContainer) {
      const postButtons = composerContainer.querySelectorAll("button");
      const shareButton = Array.from(postButtons).find((btn) =>
        btn.textContent.includes("Share thoughtfully")
      );

      if (shareButton) {
        const hasContent =
          currentWordCount > 0 && currentWordCount <= this.limit;
        shareButton.disabled = !hasContent;

        if (hasContent) {
          shareButton.classList.remove("opacity-50");
        } else {
          shareButton.classList.add("opacity-50");
        }
      }
    }
  },
};
