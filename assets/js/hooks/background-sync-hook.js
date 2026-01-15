import MobileNative from "../mobile_native";

const BackgroundSyncHook = {
  mounted() {
    this._cleanups = [];

    const lifecycleCleanup = MobileNative.lifecycle.onStateChange(
      (newState, oldState) => {
        if (this.el.isConnected) {
          this.pushEvent("app_state_changed", { state: newState, previous: oldState });
        }

        if (newState === "active" && oldState !== "active") {
          if (this.el.isConnected) {
            this.pushEvent("app_became_active", {});
          }
        }
      },
    );
    this._cleanups.push(lifecycleCleanup);

    const networkCleanup = MobileNative.network.onStatusChange(
      (newStatus, oldStatus) => {
        if (this.el.isConnected) {
          this.pushEvent("network_status_changed", {
            status: newStatus,
            previous: oldStatus,
          });
        }

        if (newStatus === "online" && oldStatus === "offline") {
          if (this.el.isConnected) {
            this.pushEvent("network_reconnected", {});
          }
        }
      },
    );
    this._cleanups.push(networkCleanup);

    const syncCleanup = MobileNative.sync.onBackgroundSync(() => {
      if (this.el.isConnected) {
        this.pushEvent("background_sync_triggered", {});
      }
    });
    this._cleanups.push(syncCleanup);

    this.handleEvent("request_sync", () => {
      MobileNative.sync.requestSync();
    });

    this.handleEvent("get_app_state", () => {
      if (this.el.isConnected) {
        this.pushEvent("app_state_response", {
          state: MobileNative.lifecycle.getState(),
          network: MobileNative.network.getStatus(),
        });
      }
    });
  },

  destroyed() {
    if (this._cleanups) {
      this._cleanups.forEach((cleanup) => cleanup());
      this._cleanups = null;
    }
  },
};

export default BackgroundSyncHook;
