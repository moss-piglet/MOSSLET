import { DateTime } from "../../vendor/luxon";

export const LocalTimeTooltip = {
  mounted() {
    this.tooltip = null;
    this.setupTooltip();
  },

  setupTooltip() {
    this.el.addEventListener('mouseenter', (e) => {
      this.showTooltip(e);
    });

    this.el.addEventListener('mouseleave', () => {
      this.hideTooltip();
    });
  },

  showTooltip(e) {
    const timestamp = this.el.dataset.timestamp;
    if (!timestamp) return;

    // Parse as UTC timestamp and convert to local time (same as LocalTimeFull hook)
    const dt = DateTime.fromISO(timestamp, { zone: "UTC" }).toLocal().setLocale('en');
    const fullTime = dt.toLocaleString(DateTime.DATETIME_FULL);

    this.tooltip = document.createElement('div');
    this.tooltip.className = 'fixed z-50 px-2 py-1 text-xs text-white bg-gray-900 rounded shadow-lg whitespace-nowrap pointer-events-none';
    this.tooltip.textContent = fullTime;
    
    // Append to body to avoid overflow issues
    document.body.appendChild(this.tooltip);
    
    // Position the tooltip
    this.positionTooltip();
  },

  positionTooltip() {
    if (!this.tooltip) return;
    
    const rect = this.el.getBoundingClientRect();
    const tooltipRect = this.tooltip.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    
    // Calculate preferred position (above the element, centered)
    let left = rect.left + (rect.width / 2) - (tooltipRect.width / 2);
    let top = rect.top - tooltipRect.height - 8;
    
    // Adjust horizontal position if it would overflow
    if (left < 8) {
      left = 8; // 8px margin from left edge
    } else if (left + tooltipRect.width > viewportWidth - 8) {
      left = viewportWidth - tooltipRect.width - 8; // 8px margin from right edge
    }
    
    // If tooltip would go above viewport, show it below the element instead
    if (top < 8) {
      top = rect.bottom + 8;
    }
    
    // Final check: if tooltip would go below viewport, position it above but within bounds
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
  }
};