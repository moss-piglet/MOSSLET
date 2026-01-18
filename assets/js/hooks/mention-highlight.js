const MentionHighlight = {
  mounted() {
    const el = this.el;
    const contentEl = el.querySelector('[data-mention-content="true"]');
    
    if (contentEl) {
      this.contentEl = contentEl;
      this.contentEl.classList.remove('animate-mention-highlight');
      this.originalBorderRadius = getComputedStyle(contentEl).borderRadius;
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
    
    displacement.setAttribute('scale', '0');

    const contentRect = this.contentEl.getBoundingClientRect();
    const contentWidth = contentRect.width;
    
    const washDuration = 1200 * Math.max(contentWidth / 250, 0.8);
    const settleDuration = 400;
    const recedeDuration = 1400 * Math.max(contentWidth / 250, 0.8);
    const residueDuration = 900;
    const totalDuration = washDuration + settleDuration + recedeDuration + residueDuration;

    if (!this.contentEl.querySelector('.emerald-wave-edge')) {
      const waveEdge = document.createElement('div');
      waveEdge.className = 'emerald-wave-edge';
      
      const residue = document.createElement('div');
      residue.className = 'emerald-wave-residue';
      waveEdge.appendChild(residue);
      this.residue = residue;
      
      const ripple1 = document.createElement('div');
      ripple1.className = 'emerald-wave-ripple emerald-wave-ripple-1';
      waveEdge.appendChild(ripple1);
      
      const ripple2 = document.createElement('div');
      ripple2.className = 'emerald-wave-ripple emerald-wave-ripple-2';
      waveEdge.appendChild(ripple2);
      
      this.contentEl.appendChild(waveEdge);
      this.waveEdge = waveEdge;
    }

    const startTime = performance.now();
    const maxDistortion = 14;
    let distortionActive = false;
    const baseRadius = 12;

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime;
      
      if (elapsed >= totalDuration) {
        displacement.setAttribute('scale', '0');
        this.contentEl.classList.remove('animate-mention-highlight');
        this.contentEl.style.borderRadius = '';
        this.cleanup();
        return;
      }

      const time = elapsed / 1000;
      
      const easeOutQuad = t => 1 - (1 - t) * (1 - t);
      const easeOutCubic = t => 1 - Math.pow(1 - t, 3);
      const easeInOutSine = t => -(Math.cos(Math.PI * t) - 1) / 2;
      
      let leadingEdge, trailingEdge, residueOpacity = 0;
      
      const waveEndTime = washDuration + settleDuration + recedeDuration;
      
      if (elapsed < washDuration) {
        const washProgress = elapsed / washDuration;
        leadingEdge = easeOutCubic(washProgress) * 100;
        trailingEdge = 0;
        residueOpacity = easeOutQuad(washProgress) * 0.5;
      } else if (elapsed < washDuration + settleDuration) {
        const settleProgress = (elapsed - washDuration) / settleDuration;
        leadingEdge = 100;
        trailingEdge = easeOutQuad(settleProgress) * 5;
        residueOpacity = 0.5;
      } else if (elapsed < waveEndTime) {
        const recedeProgress = (elapsed - washDuration - settleDuration) / recedeDuration;
        leadingEdge = 100;
        trailingEdge = 5 + easeInOutSine(recedeProgress) * 95;
        residueOpacity = 0.5 * (1 - recedeProgress * 0.4);
      } else {
        leadingEdge = 100;
        trailingEdge = 100;
        const residueProgress = (elapsed - waveEndTime) / residueDuration;
        residueOpacity = 0.3 * (1 - easeOutQuad(residueProgress));
      }
      
      const ripple1Pos = Math.max(0, trailingEdge - 10 + Math.sin(time * 1.8) * 3);
      const ripple2Pos = Math.max(0, trailingEdge - 18 + Math.sin(time * 1.5 + 1.5) * 3);
      
      const waveY = Math.sin(time * 0.7) * 5 + Math.sin(time * 1.2) * 2;
      const waveY2 = Math.sin(time * 0.9 + 0.5) * 3;
      
      if (this.waveEdge) {
        this.waveEdge.style.setProperty('--leading-edge', `${leadingEdge}%`);
        this.waveEdge.style.setProperty('--trailing-edge', `${trailingEdge}%`);
        this.waveEdge.style.setProperty('--wave-y', `${waveY}px`);
        this.waveEdge.style.setProperty('--wave-y2', `${waveY2}px`);
        this.waveEdge.style.setProperty('--ripple-1', `${ripple1Pos}%`);
        this.waveEdge.style.setProperty('--ripple-2', `${ripple2Pos}%`);
        this.waveEdge.style.setProperty('--residue-opacity', residueOpacity);
      }
      
      if (edgeTurbulence) {
        const baseFreqX = 0.015 + Math.sin(time * 0.7) * 0.008;
        const baseFreqY = 0.025 + Math.cos(time * 0.5) * 0.01;
        edgeTurbulence.setAttribute('baseFrequency', `${baseFreqX} ${baseFreqY}`);
      }

      const waveVisible = trailingEdge < 100;
      const waveWidth = leadingEdge - trailingEdge;
      const waveCoverage = Math.min(1, waveWidth / 40);
      
      if (leadingEdge > 0 && !distortionActive) {
        distortionActive = true;
        this.contentEl.classList.add('animate-mention-highlight');
      }
      
      const borderIntensity = waveCoverage * (trailingEdge < 100 ? 1 : Math.max(0, 1 - (elapsed - waveEndTime) / residueDuration));
      
      const w1 = Math.sin(time * 0.8) * 5 + Math.sin(time * 1.3) * 2.5;
      const w2 = Math.sin(time * 0.65 + 0.7) * 4.5 + Math.cos(time * 1.1) * 2;
      const w3 = Math.sin(time * 0.9 + 1.2) * 4 + Math.sin(time * 1.4) * 2.5;
      const w4 = Math.cos(time * 0.75 + 0.4) * 5 + Math.sin(time * 1.2) * 2;
      
      const r1 = baseRadius + w1 * borderIntensity;
      const r2 = baseRadius + w2 * borderIntensity;
      const r3 = baseRadius + w3 * borderIntensity;
      const r4 = baseRadius + w4 * borderIntensity;
      
      this.contentEl.style.borderRadius = `${r1}px ${r2}px ${r3}px ${r4}px`;
      
      const breathe = 1 + Math.sin(time * 0.5) * 0.08 + Math.sin(time * 0.8) * 0.04;
      
      let distortionIntensity = 0;
      
      if (distortionActive) {
        if (trailingEdge >= 100) {
          const residueProgress = (elapsed - waveEndTime) / residueDuration;
          distortionIntensity = Math.max(0, 0.15 * (1 - easeOutQuad(residueProgress)));
        } else if (leadingEdge < 30) {
          distortionIntensity = easeOutQuad(leadingEdge / 30) * waveCoverage * 0.8;
        } else if (trailingEdge < 70) {
          distortionIntensity = waveCoverage * breathe * 0.75;
        } else {
          const trailProgress = (trailingEdge - 70) / 30;
          distortionIntensity = Math.max(0.15, (1 - easeOutQuad(trailProgress) * 0.85)) * waveCoverage * 0.75;
        }
      }
      
      if (elapsed >= totalDuration - 100 && distortionActive) {
        this.contentEl.classList.remove('animate-mention-highlight');
        this.contentEl.style.borderRadius = '';
        distortionActive = false;
      }
      
      const freqBase = 0.002 + Math.sin(time * 0.3) * 0.0006;
      turbulence.setAttribute('baseFrequency', `${freqBase} ${freqBase * 1.2}`);
      
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
      this.waveEdge.remove();
      this.waveEdge = null;
    }
    if (this.contentEl) {
      this.contentEl.classList.remove('animate-mention-highlight');
      this.contentEl.style.borderRadius = '';
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
