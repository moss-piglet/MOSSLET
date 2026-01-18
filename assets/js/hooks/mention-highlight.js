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

    if (!this.contentEl.querySelector('.emerald-wave-edge')) {
      const waveEdge = document.createElement('div');
      waveEdge.className = 'emerald-wave-edge';
      this.contentEl.style.position = 'relative';
      this.contentEl.style.overflow = 'visible';
      this.contentEl.appendChild(waveEdge);
      this.waveEdge = waveEdge;
    }

    const duration = 3500;
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
      
      const easeOutSine = t => Math.sin((t * Math.PI) / 2);
      const waveProgress = easeOutSine(progress);
      const waveRadius = waveProgress * 85;
      const waveRadius2 = easeOutSine(Math.max(0, progress - 0.12)) * 85;
      
      if (this.waveEdge) {
        this.waveEdge.style.setProperty('--wave-radius', `${waveRadius}%`);
        this.waveEdge.style.setProperty('--wave-radius-2', `${waveRadius2}%`);
        const fadeStart = 0.55;
        this.waveEdge.style.opacity = progress < fadeStart ? '1' : `${1 - (progress - fadeStart) / (1 - fadeStart)}`;
      }
      
      if (edgeTurbulence) {
        const baseFreqX = 0.02 + Math.sin(time * 0.3) * 0.005;
        const baseFreqY = 0.025 + Math.cos(time * 0.25) * 0.006;
        edgeTurbulence.setAttribute('baseFrequency', `${baseFreqX} ${baseFreqY}`);
      }

      const distortionLag = 0.08;
      const laggedProgress = Math.max(0, progress - distortionLag);
      
      const distortionPeak = 0.4;
      const distortionEnd = 0.9;
      
      let distortionIntensity;
      if (laggedProgress < distortionPeak) {
        const t = laggedProgress / distortionPeak;
        distortionIntensity = Math.sin(t * Math.PI / 2);
      } else if (laggedProgress < distortionEnd) {
        const t = (laggedProgress - distortionPeak) / (distortionEnd - distortionPeak);
        distortionIntensity = Math.cos(t * Math.PI / 2);
      } else {
        distortionIntensity = 0;
      }
      
      const freqX = 0.003 + Math.sin(time * 0.6) * 0.001;
      const freqY = 0.004 + Math.cos(time * 0.5) * 0.0012;
      turbulence.setAttribute('baseFrequency', `${freqX} ${freqY}`);
      
      const scale = 12 * distortionIntensity;
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
