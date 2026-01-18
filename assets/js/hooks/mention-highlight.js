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
    const edgeTurbulence = document.getElementById('wave-edge-turbulence');
    
    if (!turbulence || !displacement) {
      this.cleanup();
      return;
    }

    const contentRect = this.contentEl.getBoundingClientRect();
    const contentWidth = contentRect.width;
    const contentHeight = contentRect.height;
    const contentDiagonal = Math.sqrt(contentWidth * contentWidth + contentHeight * contentHeight);
    
    const baseDuration = 3200;
    const sizeFactor = Math.max(contentDiagonal / 250, 0.8);
    const duration = baseDuration * sizeFactor;

    if (!this.contentEl.querySelector('.emerald-wave-edge')) {
      const waveEdge = document.createElement('div');
      waveEdge.className = 'emerald-wave-edge';
      waveEdge.style.setProperty('--content-width', `${contentWidth}px`);
      waveEdge.style.setProperty('--content-height', `${contentHeight}px`);
      this.contentEl.style.position = 'relative';
      this.contentEl.style.overflow = 'visible';
      this.contentEl.appendChild(waveEdge);
      this.waveEdge = waveEdge;
    }

    const startTime = performance.now();
    const maxDistortion = 22;

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime;
      
      if (elapsed >= duration) {
        displacement.setAttribute('scale', '0');
        this.cleanup();
        return;
      }

      const progress = elapsed / duration;
      const time = elapsed / 1000;
      
      const easeOutCubic = t => 1 - Math.pow(1 - t, 3);
      const easeInOutSine = t => -(Math.cos(Math.PI * t) - 1) / 2;
      
      const waveProgress = easeOutCubic(progress);
      const waveRadius = waveProgress * 100;
      const waveRadius2 = easeOutCubic(Math.max(0, progress - 0.08)) * 100;
      
      if (this.waveEdge) {
        this.waveEdge.style.setProperty('--wave-radius', `${waveRadius}%`);
        this.waveEdge.style.setProperty('--wave-radius-2', `${waveRadius2}%`);
        const fadeStart = 0.6;
        const fadeProgress = progress < fadeStart ? 0 : (progress - fadeStart) / (1 - fadeStart);
        this.waveEdge.style.opacity = `${1 - easeInOutSine(fadeProgress)}`;
      }
      
      if (edgeTurbulence) {
        const baseFreqX = 0.01 + Math.sin(time * 0.1) * 0.002;
        const baseFreqY = 0.012 + Math.cos(time * 0.08) * 0.002;
        edgeTurbulence.setAttribute('baseFrequency', `${baseFreqX} ${baseFreqY}`);
      }

      const waveLeading = waveRadius;
      const waveMid = (waveRadius + waveRadius2) / 2;
      
      let distortionIntensity;
      
      if (progress < 0.15) {
        distortionIntensity = easeInOutSine(progress / 0.15) * 0.8;
      } else if (progress < 0.5) {
        const settle = 0.8 + Math.sin((progress - 0.15) * 8) * 0.15 * (1 - (progress - 0.15) / 0.35);
        distortionIntensity = settle;
      } else if (progress < 0.75) {
        const gentleFade = 0.8 - easeInOutSine((progress - 0.5) / 0.25) * 0.4;
        const ripple = Math.sin((progress - 0.5) * 12) * 0.08 * (1 - (progress - 0.5) / 0.25);
        distortionIntensity = gentleFade + ripple;
      } else {
        distortionIntensity = 0.4 * (1 - easeInOutSine((progress - 0.75) / 0.25));
      }
      
      const freqBase = 0.004;
      const freqDrift = Math.sin(time * 0.2) * 0.001;
      turbulence.setAttribute('baseFrequency', `${freqBase + freqDrift} ${freqBase + freqDrift * 0.8}`);
      
      const scale = maxDistortion * distortionIntensity;
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
    if (this.waveEdge) {
      this.waveEdge.classList.add('fade-out');
      setTimeout(() => {
        if (this.waveEdge && this.waveEdge.parentNode) {
          this.waveEdge.parentNode.removeChild(this.waveEdge);
        }
        this.waveEdge = null;
      }, 600);
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
    if (this.waveEdge && this.waveEdge.parentNode) {
      this.waveEdge.parentNode.removeChild(this.waveEdge);
    }
  }
};

export default MentionHighlight;
