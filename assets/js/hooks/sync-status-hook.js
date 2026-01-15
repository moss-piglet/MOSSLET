const SyncStatusHook = {
  mounted() {
    this.handleEvent("sync_status", ({ online, syncing, pending_count }) => {
      this.updateIndicator(online, syncing, pending_count);
    });

    window.addEventListener("online", () => this.pushEvent("network_online"));
    window.addEventListener("offline", () => this.pushEvent("network_offline"));
  },

  updateIndicator(online, syncing, pendingCount) {
    const el = this.el;
    const statusDot = el.querySelector("[data-status-dot]");
    const statusText = el.querySelector("[data-status-text]");
    const pendingBadge = el.querySelector("[data-pending-badge]");

    if (!online) {
      el.classList.remove("hidden");
      if (statusDot) {
        statusDot.classList.remove("bg-emerald-500", "bg-amber-500", "animate-pulse");
        statusDot.classList.add("bg-red-500");
      }
      if (statusText) statusText.textContent = "Offline";
    } else if (syncing) {
      el.classList.remove("hidden");
      if (statusDot) {
        statusDot.classList.remove("bg-emerald-500", "bg-red-500");
        statusDot.classList.add("bg-amber-500", "animate-pulse");
      }
      if (statusText) statusText.textContent = "Syncing...";
    } else if (pendingCount > 0) {
      el.classList.remove("hidden");
      if (statusDot) {
        statusDot.classList.remove("bg-red-500", "animate-pulse");
        statusDot.classList.add("bg-amber-500");
      }
      if (statusText) statusText.textContent = `${pendingCount} pending`;
    } else {
      el.classList.add("hidden");
    }

    if (pendingBadge) {
      if (pendingCount > 0) {
        pendingBadge.textContent = pendingCount;
        pendingBadge.classList.remove("hidden");
      } else {
        pendingBadge.classList.add("hidden");
      }
    }
  },

  destroyed() {
    window.removeEventListener("online", () => this.pushEvent("network_online"));
    window.removeEventListener("offline", () => this.pushEvent("network_offline"));
  },
};

export default SyncStatusHook;
