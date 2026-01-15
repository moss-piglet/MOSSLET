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
    _tokenListeners: [],
    _tokenErrorListeners: [],
    _notificationListeners: [],
    _tappedListeners: [],

    requestPermission() {
      return new Promise((resolve) => {
        if (!MobileNative.isNative()) {
          resolve(false);
          return;
        }

        const handler = (e) => {
          resolve(e.detail.granted);
        };

        window.addEventListener("mosslet-push-permission", handler, {
          once: true,
        });

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

        const handler = (e) => {
          resolve(e.detail.status);
        };

        window.addEventListener("mosslet-push-permission-status", handler, {
          once: true,
        });

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
      const handler = (e) => callback(e.detail.token);
      this._tokenListeners.push({ callback, handler });
      window.addEventListener("mosslet-push-token", handler);
      return () => {
        window.removeEventListener("mosslet-push-token", handler);
        this._tokenListeners = this._tokenListeners.filter(
          (l) => l.callback !== callback,
        );
      };
    },

    onTokenError(callback) {
      const handler = (e) => callback(e.detail.error);
      this._tokenErrorListeners.push({ callback, handler });
      window.addEventListener("mosslet-push-token-error", handler);
      return () => {
        window.removeEventListener("mosslet-push-token-error", handler);
        this._tokenErrorListeners = this._tokenErrorListeners.filter(
          (l) => l.callback !== callback,
        );
      };
    },

    onNotificationReceived(callback) {
      const handler = (e) => callback(e.detail.data, e.detail.foreground);
      this._notificationListeners.push({ callback, handler });
      window.addEventListener("mosslet-push-received", handler);
      return () => {
        window.removeEventListener("mosslet-push-received", handler);
        this._notificationListeners = this._notificationListeners.filter(
          (l) => l.callback !== callback,
        );
      };
    },

    onNotificationTapped(callback) {
      const handler = (e) => callback(e.detail.data);
      this._tappedListeners.push({ callback, handler });
      window.addEventListener("mosslet-push-tapped", handler);
      return () => {
        window.removeEventListener("mosslet-push-tapped", handler);
        this._tappedListeners = this._tappedListeners.filter(
          (l) => l.callback !== callback,
        );
      };
    },

    cleanup() {
      this._tokenListeners.forEach(({ handler }) => {
        window.removeEventListener("mosslet-push-token", handler);
      });
      this._tokenErrorListeners.forEach(({ handler }) => {
        window.removeEventListener("mosslet-push-token-error", handler);
      });
      this._notificationListeners.forEach(({ handler }) => {
        window.removeEventListener("mosslet-push-received", handler);
      });
      this._tappedListeners.forEach(({ handler }) => {
        window.removeEventListener("mosslet-push-tapped", handler);
      });
      this._tokenListeners = [];
      this._tokenErrorListeners = [];
      this._notificationListeners = [];
      this._tappedListeners = [];
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

      return () => {
        const idx = this._callbacks.indexOf(callback);
        if (idx > -1) {
          this._callbacks.splice(idx, 1);
        }
      };
    },

    _handleLink(url, path) {
      if (this._callbacks.length > 0) {
        this._callbacks.forEach((cb) => cb(url, path));
      } else {
        this._pendingLink = { url, path };
      }
    },

    _isValidPath(path) {
      if (typeof path !== "string") return false;
      if (!path.startsWith("/")) return false;
      if (path.includes("..")) return false;
      if (path.includes("//")) return false;

      return true;
    },

    navigate(path) {
      if (!this._isValidPath(path)) {
        console.warn("MobileNative.deepLink.navigate: blocked invalid path", path);
        return;
      }

      if (window.liveSocket && window.liveSocket.main) {
        window.liveSocket.main.pushEvent("navigate", { path });
      } else {
        window.location.pathname = path;
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
