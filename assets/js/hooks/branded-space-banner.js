/**
 * BrandedSpaceBanner — client-only dismissal for the apex "switch to your
 * branded space" hint (Task #246).
 *
 * The banner is a soft, optional nudge shown on the apex to members of an org
 * whose custom subdomain is live. Dismissal is purely cosmetic and never needs
 * to reach the server, so we persist it in localStorage keyed by the org's
 * subdomain label. Once dismissed, the banner stays hidden for that org in this
 * browser (re-appears for a different branded org, or if localStorage clears).
 *
 * No secrets are involved — the subdomain label is public, non-sensitive data.
 */

const STORAGE_PREFIX = "_mosslet_branded_banner_dismissed:";

const BrandedSpaceBanner = {
  mounted() {
    const key = this.el.dataset.bannerKey;
    if (!key) return;

    const storageKey = STORAGE_PREFIX + key;

    if (this._isDismissed(storageKey)) {
      this.el.hidden = true;
      return;
    }

    const dismissBtn = this.el.querySelector("#branded-space-banner-dismiss");
    if (dismissBtn) {
      this._onDismiss = () => {
        this._setDismissed(storageKey);
        this.el.hidden = true;
      };
      dismissBtn.addEventListener("click", this._onDismiss);
    }
  },

  destroyed() {
    const dismissBtn = this.el.querySelector("#branded-space-banner-dismiss");
    if (dismissBtn && this._onDismiss) {
      dismissBtn.removeEventListener("click", this._onDismiss);
    }
  },

  _isDismissed(storageKey) {
    try {
      return localStorage.getItem(storageKey) === "1";
    } catch {
      return false;
    }
  },

  _setDismissed(storageKey) {
    try {
      localStorage.setItem(storageKey, "1");
    } catch {
      // Private mode / storage disabled — dismissal just won't persist.
    }
  },
};

export default BrandedSpaceBanner;
