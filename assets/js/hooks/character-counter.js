/**
 * Character Counter Hook for Timeline Composer
 * 
 * Provides real-time character counting with smooth color transitions
 * as users approach the character limit. Enhanced for mockup mode.
 */
export default {
  mounted() {
    this.limit = parseInt(this.el.dataset.limit || 500);
    this.updateCounter();
    
    this.el.addEventListener('focus', () => {
      if (this.el.value.length > 0) {
        this.showCounter();
      }
    });
    
    this.el.addEventListener('blur', () => {
      if (this.el.value.length === 0) {
        this.hideCounter();
      }
    });
    
    this.el.addEventListener('input', () => {
      if (this.el.value.length > 0) {
        this.showCounter();
      } else {
        this.hideCounter();
      }
      this.updateCounter();
    });
  },
  
  updated() {
    this.updateCounter();
  },
  
  findCounterContainer() {
    return this.el.closest('.relative')?.querySelector('[id*="char-counter"]') ||
           this.el.parentElement.querySelector('[id*="char-counter"]');
  },
  
  showCounter() {
    const counterContainer = this.findCounterContainer();
    
    if (counterContainer) {
      counterContainer.classList.remove('char-counter-hidden');
    }
  },
  
  hideCounter() {
    const counterContainer = this.findCounterContainer();
    
    if (counterContainer) {
      counterContainer.classList.add('char-counter-hidden');
    }
  },
  
  updateCounter() {
    const currentLength = this.el.value.length;
    const counterEl = this.el.parentElement.querySelector('.js-char-count') ||
                      this.el.closest('.relative')?.querySelector('.js-char-count');
    
    if (counterEl) {
      counterEl.textContent = currentLength;
      
      const counterContainer = counterEl.closest('span');
      if (counterContainer) {
        counterContainer.classList.remove('text-slate-500', 'text-amber-500', 'text-rose-500');
        
        const remaining = this.limit - currentLength;
        
        if (remaining < 50) {
          counterContainer.classList.add('text-rose-500');
        } else if (remaining < 100) {
          counterContainer.classList.add('text-amber-500');
        } else {
          counterContainer.classList.add('text-slate-500');
        }
      }
    }
    
    const composerContainer = this.el.closest('[class*="rounded-2xl"]');
    if (composerContainer) {
      const postButtons = composerContainer.querySelectorAll('button');
      const shareButton = Array.from(postButtons).find(btn => 
        btn.textContent.includes('Share thoughtfully')
      );
      
      if (shareButton) {
        const hasContent = currentLength > 0 && currentLength <= this.limit;
        shareButton.disabled = !hasContent;
        
        if (hasContent) {
          shareButton.classList.remove('opacity-50');
        } else {
          shareButton.classList.add('opacity-50');
        }
      }
    }
  }
};