import { DateTime } from "../../vendor/luxon";

export const LocalTimeTooltip = {
  mounted() {
    this.tooltip = null;
    this.setupTooltip();
  },

  setupTooltip() {
    this.handleMouseEnter = (e) => {
      this.showTooltip(e);
    };

    this.handleMouseLeave = () => {
      this.hideTooltip();
    };

    this.el.addEventListener('mouseenter', this.handleMouseEnter);
    this.el.addEventListener('mouseleave', this.handleMouseLeave);
  },

  showTooltip(e) {
    const timestamp = this.el.dataset.timestamp;
    if (!timestamp) return;

    const dt = DateTime.fromISO(timestamp, { zone: "UTC" }).toLocal().setLocale('en');
    const fullTime = dt.toLocaleString(DateTime.DATETIME_FULL);

    this.tooltip = document.createElement('div');
    this.tooltip.className = 'fixed z-50 px-2 py-1 text-xs text-white bg-gray-900 rounded shadow-lg whitespace-nowrap pointer-events-none';
    this.tooltip.textContent = fullTime;
    
    document.body.appendChild(this.tooltip);
    
    this.positionTooltip();
  },

  positionTooltip() {
    if (!this.tooltip) return;
    
    const rect = this.el.getBoundingClientRect();
    const tooltipRect = this.tooltip.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    
    let left = rect.left + (rect.width / 2) - (tooltipRect.width / 2);
    let top = rect.top - tooltipRect.height - 8;
    
    if (left < 8) {
      left = 8;
    } else if (left + tooltipRect.width > viewportWidth - 8) {
      left = viewportWidth - tooltipRect.width - 8;
    }
    
    if (top < 8) {
      top = rect.bottom + 8;
    }
    
    if (top + tooltipRect.height > viewportHeight - 8) {
      top = Math.max(8, viewportHeight - tooltipRect.height - 8);
    }
    
    this.tooltip.style.left = `${left}px`;
    this.tooltip.style.top = `${top}px`;
  },

  hideTooltip() {
    if (this.tooltip) {
      this.tooltip.remove();
      this.tooltip = null;
    }
  },

  destroyed() {
    this.hideTooltip();
    if (this.handleMouseEnter) {
      this.el.removeEventListener('mouseenter', this.handleMouseEnter);
    }
    if (this.handleMouseLeave) {
      this.el.removeEventListener('mouseleave', this.handleMouseLeave);
    }
  }
};