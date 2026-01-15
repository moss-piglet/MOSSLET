const MobileNative = {
  isNative() {
    return !!(window.MossletNative || window.AndroidBridge);
  },

  getPlatform() {
    if (window.MossletNative) {
      return window.MossletNative.getPlatform();
    }
    if (window.AndroidBridge) {
      return window.AndroidBridge.getPlatform();
    }
    return "web";
  },

  isIOS() {
    return this.getPlatform() === "ios";
  },

  isAndroid() {
    return this.getPlatform() === "android";
  },

  openURL(url) {
    if (window.MossletNative) {
      window.MossletNative.openURL(url);
    } else if (window.AndroidBridge) {
      window.AndroidBridge.postMessage(
        JSON.stringify({ action: "open_url", url }),
      );
    } else {
      window.open(url, "_blank");
    }
  },

  share(text, url = null) {
    const shareText = url ? `${text} ${url}` : text;

    if (window.MossletNative) {
      window.MossletNative.share(shareText);
    } else if (window.AndroidBridge) {
      window.AndroidBridge.postMessage(
        JSON.stringify({ action: "share", text: shareText }),
      );
    } else if (navigator.share) {
      navigator.share({ text: shareText, url: url || undefined });
    }
  },

  haptic(style = "medium") {
    if (window.MossletNative) {
      window.MossletNative.haptic(style);
    } else if (window.AndroidBridge) {
      window.AndroidBridge.postMessage(
        JSON.stringify({ action: "haptic", style }),
      );
    }
  },

  onReady(callback) {
    if (this.isNative()) {
      callback();
    } else {
      window.addEventListener("mosslet-native-ready", callback, { once: true });
    }
  },

  push: {
    _tokenCallback: null,
    _permissionCallback: null,

    requestPermission() {
      return new Promise((resolve) => {
        if (!MobileNative.isNative()) {
          resolve(false);
          return;
        }

        this._permissionCallback = resolve;

        window.addEventListener(
          "mosslet-push-permission",
          (e) => {
            resolve(e.detail.granted);
          },
          { once: true },
        );

        if (window.MossletNative && window.MossletNative.push) {
          window.MossletNative.push.requestPermission();
        } else if (window.AndroidBridge) {
          window.AndroidBridge.postMessage(
            JSON.stringify({ action: "push_request_permission" }),
          );
        }
      });
    },

    getPermissionStatus() {
      return new Promise((resolve) => {
        if (!MobileNative.isNative()) {
          resolve("unavailable");
          return;
        }

        window.addEventListener(
          "mosslet-push-permission-status",
          (e) => {
            resolve(e.detail.status);
          },
          { once: true },
        );

        if (window.MossletNative && window.MossletNative.push) {
          window.MossletNative.push.getPermissionStatus();
        } else if (window.AndroidBridge) {
          window.AndroidBridge.postMessage(
            JSON.stringify({ action: "push_get_permission_status" }),
          );
        }
      });
    },

    onTokenReceived(callback) {
      this._tokenCallback = callback;

      window.addEventListener("mosslet-push-token", (e) => {
        callback(e.detail.token);
      });
    },

    onTokenError(callback) {
      window.addEventListener("mosslet-push-token-error", (e) => {
        callback(e.detail.error);
      });
    },

    onNotificationReceived(callback) {
      window.addEventListener("mosslet-push-received", (e) => {
        callback(e.detail.data, e.detail.foreground);
      });
    },

    onNotificationTapped(callback) {
      window.addEventListener("mosslet-push-tapped", (e) => {
        callback(e.detail.data);
      });
    },
  },

  deepLink: {
    _callbacks: [],
    _pendingLink: null,

    onReceived(callback) {
      this._callbacks.push(callback);

      if (this._pendingLink) {
        callback(this._pendingLink.url, this._pendingLink.path);
        this._pendingLink = null;
      }
    },

    _handleLink(url, path) {
      if (this._callbacks.length > 0) {
        this._callbacks.forEach((cb) => cb(url, path));
      } else {
        this._pendingLink = { url, path };
      }
    },

    navigate(path) {
      if (window.liveSocket && window.liveSocket.main) {
        window.liveSocket.main.pushEvent("navigate", { path });
      } else {
        window.location.href = path;
      }
    },

    generateLink(route, options = {}) {
      const scheme = options.scheme || "https";
      const host = options.host || "mosslet.com";

      if (scheme === "custom") {
        return `mosslet:/${route}`;
      }
      return `${scheme}://${host}${route}`;
    },
  },
};

window.addEventListener("mosslet-deep-link", (e) => {
  MobileNative.deepLink._handleLink(e.detail.url, e.detail.path);
});

window.MobileNative = MobileNative;

export default MobileNative;
