import MobileNative from "../mobile_native";

const PushNotificationHook = {
  mounted() {
    if (!MobileNative.isNative()) {
      return;
    }

    this._boundHandlers = {
      token: (e) => {
        this.pushEvent("push_token_received", {
          token: e.detail.token,
          platform: MobileNative.getPlatform(),
        });
      },
      tokenError: (e) => {
        console.error("Push token error:", e.detail.error);
      },
      received: (e) => {
        this.pushEvent("push_notification_received", {
          data: e.detail.data,
          foreground: e.detail.foreground,
        });
      },
      tapped: (e) => {
        this.pushEvent("push_notification_tapped", { data: e.detail.data });
      },
    };

    window.addEventListener("mosslet-push-token", this._boundHandlers.token);
    window.addEventListener(
      "mosslet-push-token-error",
      this._boundHandlers.tokenError,
    );
    window.addEventListener(
      "mosslet-push-received",
      this._boundHandlers.received,
    );
    window.addEventListener("mosslet-push-tapped", this._boundHandlers.tapped);

    this.handleEvent("request_push_permission", () => {
      MobileNative.push.requestPermission().then((granted) => {
        if (this.el.isConnected) {
          this.pushEvent("push_permission_result", { granted: granted });
        }
      });
    });

    this.handleEvent("check_push_permission", () => {
      MobileNative.push.getPermissionStatus().then((status) => {
        if (this.el.isConnected) {
          this.pushEvent("push_permission_status", { status: status });
        }
      });
    });
  },

  destroyed() {
    if (this._boundHandlers) {
      window.removeEventListener(
        "mosslet-push-token",
        this._boundHandlers.token,
      );
      window.removeEventListener(
        "mosslet-push-token-error",
        this._boundHandlers.tokenError,
      );
      window.removeEventListener(
        "mosslet-push-received",
        this._boundHandlers.received,
      );
      window.removeEventListener(
        "mosslet-push-tapped",
        this._boundHandlers.tapped,
      );
      this._boundHandlers = null;
    }
  },
};

export default PushNotificationHook;
