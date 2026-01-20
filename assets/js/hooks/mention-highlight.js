const MentionHighlight = {
  mounted() {
    const el = this.el;
    const contentEl = el.querySelector('[data-mention-content="true"]');
    
    if (contentEl) {
      this.contentEl = contentEl;
      requestAnimationFrame(() => this.startHighlightAnimation());
    }
  },

  startHighlightAnimation() {
    if (!this.contentEl.querySelector('.mention-glow')) {
      const glow = document.createElement('div');
      glow.className = 'mention-glow';
      this.contentEl.appendChild(glow);
      this.glowEl = glow;

      const indicator = document.createElement('div');
      indicator.className = 'mention-indicator';
      this.contentEl.appendChild(indicator);
      this.indicatorEl = indicator;
    }

    this.contentEl.classList.add('mention-highlight-active');

    const totalDuration = 3500;
    const startTime = performance.now();

    const easeOutCubic = t => 1 - Math.pow(1 - t, 3);
    const easeInOutSine = t => -(Math.cos(Math.PI * t) - 1) / 2;

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime;
      
      if (elapsed >= totalDuration) {
        this.cleanup();
        return;
      }

      const progress = elapsed / totalDuration;
      
      let glowOpacity, indicatorOpacity, pulseScale;
      
      if (progress < 0.15) {
        const fadeIn = easeOutCubic(progress / 0.15);
        glowOpacity = fadeIn * 0.6;
        indicatorOpacity = fadeIn;
        pulseScale = 1;
      } else if (progress < 0.75) {
        const holdProgress = (progress - 0.15) / 0.6;
        const pulse = Math.sin(holdProgress * Math.PI * 4) * 0.15;
        glowOpacity = 0.5 + pulse * 0.2;
        indicatorOpacity = 1;
        pulseScale = 1 + pulse * 0.03;
      } else {
        const fadeOut = 1 - easeInOutSine((progress - 0.75) / 0.25);
        glowOpacity = 0.5 * fadeOut;
        indicatorOpacity = fadeOut;
        pulseScale = 1;
      }

      if (this.glowEl) {
        this.glowEl.style.opacity = glowOpacity;
      }
      if (this.indicatorEl) {
        this.indicatorEl.style.opacity = indicatorOpacity;
        this.indicatorEl.style.transform = `scale(${pulseScale})`;
      }

      this.animationFrame = requestAnimationFrame(animate);
    };

    this.animationFrame = requestAnimationFrame(animate);
  },

  cleanup() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
    if (this.glowEl) {
      this.glowEl.remove();
      this.glowEl = null;
    }
    if (this.indicatorEl) {
      this.indicatorEl.remove();
      this.indicatorEl = null;
    }
    if (this.contentEl) {
      this.contentEl.classList.remove('mention-highlight-active');
      this.contentEl.removeAttribute('data-mention-content');
    }
    this.el.removeAttribute('data-new-mention');
    this.pushEvent("mark_mention_read", { message_id: this.el.id });
  },

  destroyed() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    }
    if (this.glowEl && this.glowEl.parentNode) {
      this.glowEl.parentNode.removeChild(this.glowEl);
      this.glowEl = null;
    }
    if (this.indicatorEl && this.indicatorEl.parentNode) {
      this.indicatorEl.parentNode.removeChild(this.indicatorEl);
      this.indicatorEl = null;
    }
    if (this.contentEl) {
      this.contentEl.classList.remove('mention-highlight-active');
    }
  }
};

export default MentionHighlight;
