const MentionHighlight = {
  mounted() {
    const el = this.el;
    const contentEl = el.querySelector('[data-mention-content="true"]');
    
    if (contentEl) {
      this.contentEl = contentEl;
      requestAnimationFrame(() => this.startWaterAnimation());
    }
  },

  startWaterAnimation() {
    const turbulence = document.getElementById('water-turbulence');
    const displacement = document.getElementById('water-displacement');
    
    if (!turbulence || !displacement) {
      this.cleanup();
      return;
    }

    const duration = 3000;
    const startTime = performance.now();

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime;
      
      if (elapsed >= duration) {
        displacement.setAttribute('scale', '0');
        this.cleanup();
        return;
      }

      const progress = elapsed / duration;
      const time = elapsed / 1000;
      
      const freqX = 0.008 + Math.sin(time * 0.5) * 0.003;
      const freqY = 0.012 + Math.cos(time * 0.4) * 0.004;
      turbulence.setAttribute('baseFrequency', `${freqX} ${freqY}`);
      
      let scale;
      if (progress < 0.15) {
        scale = 10 * Math.sin((progress / 0.15) * Math.PI / 2);
      } else if (progress > 0.6) {
        const fadeProgress = (progress - 0.6) / 0.4;
        scale = 10 * Math.cos(fadeProgress * Math.PI / 2);
      } else {
        scale = 10;
      }
      displacement.setAttribute('scale', Math.max(0, scale).toString());

      this.animationFrame = requestAnimationFrame(animate);
    };

    this.animationFrame = requestAnimationFrame(animate);
  },

  cleanup() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
    const displacement = document.getElementById('water-displacement');
    if (displacement) {
      displacement.setAttribute('scale', '0');
    }
    if (this.contentEl) {
      this.contentEl.classList.remove('animate-mention-highlight');
      this.contentEl.removeAttribute('data-mention-content');
    }
    this.el.removeAttribute('data-new-mention');
    this.pushEvent("mark_mention_read", { message_id: this.el.id });
  },

  destroyed() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
    const displacement = document.getElementById('water-displacement');
    if (displacement) {
      displacement.setAttribute('scale', '0');
    }
  }
};

export default MentionHighlight;
