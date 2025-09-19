/**
 * Scroll Aware Position Hook
 * 
 * Changes element alignment from center to left when user scrolls,
 * and makes it more compact to avoid collision with mobile topbar.
 */
export default {
  mounted() {
    this.centerClass = this.el.dataset.centerClass || 'text-center';
    this.leftClass = this.el.dataset.leftClass || 'text-left';
    this.scrollThreshold = parseInt(this.el.dataset.scrollThreshold || 100);
    this.isScrolled = false;
    
    // Set initial state
    this.updatePosition();
    
    // Listen for scroll events
    this.handleScroll = () => {
      this.updatePosition();
    };
    
    window.addEventListener('scroll', this.handleScroll, { passive: true });
  },
  
  destroyed() {
    if (this.handleScroll) {
      window.removeEventListener('scroll', this.handleScroll);
    }
  },
  
  updatePosition() {
    const scrollY = window.scrollY;
    const shouldBeLeft = scrollY > this.scrollThreshold;
    
    if (shouldBeLeft !== this.isScrolled) {
      this.isScrolled = shouldBeLeft;
      
      // Remove both classes first
      this.el.classList.remove(this.centerClass, this.leftClass);
      
      // Add the appropriate class
      this.el.classList.add(shouldBeLeft ? this.leftClass : this.centerClass);
      
      // Find the button inside and make it compact when scrolled
      const button = this.el.querySelector('button');
      if (button) {
        if (shouldBeLeft) {
          // Compact mode for mobile topbar
          button.classList.add('px-2', 'py-1.5', 'text-xs');
          button.classList.remove('px-4', 'py-2.5', 'text-sm');
          
          // Hide arrow and text on mobile when scrolled
          const arrow = button.querySelector('.hero-arrow-up');
          const textSpan = button.querySelector('span[class*="font-medium"]');
          
          if (arrow) arrow.style.display = 'none';
          if (textSpan) {
            // Show just the number on mobile when scrolled
            textSpan.innerHTML = this.getCompactText();
          }
          
        } else {
          // Full mode
          button.classList.remove('px-2', 'py-1.5', 'text-xs');
          button.classList.add('px-4', 'py-2.5', 'text-sm');
          
          // Show arrow and full text
          const arrow = button.querySelector('.hero-arrow-up');
          const textSpan = button.querySelector('span[class*="font-medium"]');
          
          if (arrow) arrow.style.display = '';
          if (textSpan) {
            textSpan.innerHTML = this.getFullText();
          }
        }
      }
    }
  },
  
  getCompactText() {
    // Extract the number from the full text
    const button = this.el.querySelector('button');
    const fullText = button?.textContent || '';
    const match = fullText.match(/(\d+)/);
    return match ? match[1] : '•';
  },
  
  getFullText() {
    // Return the original full text based on count
    const button = this.el.querySelector('button');
    const compactText = button?.textContent?.trim() || '';
    const count = parseInt(compactText) || 1;
    return `${count} new post${count === 1 ? '' : 's'}`;
  }
};