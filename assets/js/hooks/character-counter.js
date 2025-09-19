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
    
    // Show counter when textarea gets focus
    this.el.addEventListener('focus', () => {
      this.showCounter();
    });
    
    // Hide counter when textarea loses focus (but only if empty)
    this.el.addEventListener('blur', () => {
      if (this.el.value.length === 0) {
        this.hideCounter();
      }
    });
    
    this.el.addEventListener('input', () => {
      this.showCounter();
      this.updateCounter();
    });
  },
  
  updated() {
    this.updateCounter();
  },
  
  showCounter() {
    const counterId = `char-counter-${this.el.dataset.limit || '500'}`;
    const counterContainer = document.getElementById(counterId) || 
                             this.el.parentElement.querySelector('[id*="char-counter"]');
    
    if (counterContainer) {
      counterContainer.style.opacity = '1';
      counterContainer.style.transform = 'translateY(0)';
    }
  },
  
  hideCounter() {
    const counterId = `char-counter-${this.el.dataset.limit || '500'}`;
    const counterContainer = document.getElementById(counterId) || 
                             this.el.parentElement.querySelector('[id*="char-counter"]');
    
    if (counterContainer) {
      counterContainer.style.opacity = '0';
      counterContainer.style.transform = 'translateY(10px)';
    }
  },
  
  updateCounter() {
    const currentLength = this.el.value.length;
    const counterEl = this.el.parentElement.querySelector('.js-char-count');
    
    if (counterEl) {
      counterEl.textContent = currentLength;
      
      // Update color based on remaining characters
      const counterContainer = counterEl.closest('span');
      if (counterContainer) {
        // Remove existing color classes safely
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
    
    // Enable/disable post button based on content
    const composerContainer = this.el.closest('[class*="rounded-2xl"]');
    if (composerContainer) {
      const postButtons = composerContainer.querySelectorAll('button');
      const shareButton = Array.from(postButtons).find(btn => 
        btn.textContent.includes('Share thoughtfully')
      );
      
      if (shareButton) {
        const hasContent = currentLength > 0 && currentLength <= this.limit;
        shareButton.disabled = !hasContent;
        
        // Add visual feedback for enabled state
        if (hasContent) {
          shareButton.classList.remove('opacity-50');
        } else {
          shareButton.classList.add('opacity-50');
        }
      }
    }
  }
};