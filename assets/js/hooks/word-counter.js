const BLUESKY_MAX_GRAPHEMES = 300;

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
      this.updateBlueskyIndicator();
    };

    this.el.addEventListener("focus", this.focusHandler);
    this.el.addEventListener("blur", this.blurHandler);
    this.el.addEventListener("input", this.inputHandler);
  },

  updated() {
    this.updateCounter();
    this.updateBlueskyIndicator();
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

  isBlueskySync() {
    const syncIndicator = document.getElementById("bluesky-sync-indicator");
    return syncIndicator && !syncIndicator.closest("[style*='display: none']");
  },

  getGraphemeCount() {
    const text = this.el.value || "";
    const segmenter = self.Intl?.Segmenter
      ? new Intl.Segmenter(undefined, { granularity: "grapheme" })
      : null;

    if (segmenter) {
      return [...segmenter.segment(text)].length;
    }
    return [...text].length;
  },

  updateBlueskyIndicator() {
    if (!this.isBlueskySync()) {
      this.hideBlueskyNotice();
      return;
    }

    const graphemes = this.getGraphemeCount();

    if (graphemes === 0) {
      this.hideBlueskyNotice();
      return;
    }

    const remaining = BLUESKY_MAX_GRAPHEMES - graphemes;
    const notice = this.getOrCreateBlueskyNotice();

    if (!notice) return;

    if (remaining < 0) {
      const over = Math.abs(remaining);
      notice.innerHTML = `<span class="inline-flex items-center gap-1 text-xs text-sky-600 dark:text-sky-400"><svg class="h-3 w-3 flex-shrink-0" viewBox="0 0 568 501" fill="currentColor"><path d="M123.121 33.6637C188.241 82.5526 258.281 181.681 284 234.873C309.719 181.681 379.759 82.5526 444.879 33.6637C491.866 -1.61183 568 -28.9064 568 57.9464C568 75.2916 558.055 203.659 552.222 224.501C531.947 296.954 458.067 315.434 392.347 304.249C507.222 323.8 536.444 388.56 473.333 453.32C353.473 576.312 301.061 422.461 287.631 383.36C286.267 378.309 284.737 377.78 284 377.78C283.263 377.78 281.733 378.309 280.369 383.36C266.939 422.461 214.527 576.312 94.6667 453.32C31.5556 388.56 60.7778 323.8 175.653 304.249C109.933 315.434 36.0533 296.954 15.7778 224.501C9.94445 203.659 0 75.2916 0 57.9464C0 -28.9064 76.1345 -1.61183 123.121 33.6637Z"/></svg>+${over} over \u2014 will truncate with link</span>`;
      notice.classList.remove("hidden");
    } else if (remaining <= 50) {
      notice.innerHTML = `<span class="inline-flex items-center gap-1 text-xs text-amber-600 dark:text-amber-400"><svg class="h-3 w-3 flex-shrink-0" viewBox="0 0 568 501" fill="currentColor"><path d="M123.121 33.6637C188.241 82.5526 258.281 181.681 284 234.873C309.719 181.681 379.759 82.5526 444.879 33.6637C491.866 -1.61183 568 -28.9064 568 57.9464C568 75.2916 558.055 203.659 552.222 224.501C531.947 296.954 458.067 315.434 392.347 304.249C507.222 323.8 536.444 388.56 473.333 453.32C353.473 576.312 301.061 422.461 287.631 383.36C286.267 378.309 284.737 377.78 284 377.78C283.263 377.78 281.733 378.309 280.369 383.36C266.939 422.461 214.527 576.312 94.6667 453.32C31.5556 388.56 60.7778 323.8 175.653 304.249C109.933 315.434 36.0533 296.954 15.7778 224.501C9.94445 203.659 0 75.2916 0 57.9464C0 -28.9064 76.1345 -1.61183 123.121 33.6637Z"/></svg>${remaining} chars left for Bluesky</span>`;
      notice.classList.remove("hidden");
    } else {
      this.hideBlueskyNotice();
    }
  },

  getOrCreateBlueskyNotice() {
    const composerContainer = this.el.closest('[class*="rounded-2xl"]');
    if (!composerContainer) return null;

    let notice = composerContainer.querySelector("#bluesky-char-notice");
    if (!notice) {
      notice = document.createElement("div");
      notice.id = "bluesky-char-notice";
      notice.className = "hidden px-4 pb-2 transition-all duration-200";

      const counterArea = this.findCounterContainer();
      if (counterArea) {
        counterArea.parentElement.insertAdjacentElement("afterend", notice);
      } else {
        const textareaWrapper = this.el.closest(".relative");
        if (textareaWrapper) {
          textareaWrapper.insertAdjacentElement("afterend", notice);
        }
      }
    }
    return notice;
  },

  hideBlueskyNotice() {
    const composerContainer = this.el.closest('[class*="rounded-2xl"]');
    if (!composerContainer) return;

    const notice = composerContainer.querySelector("#bluesky-char-notice");
    if (notice) {
      notice.classList.add("hidden");
    }
  },
};
