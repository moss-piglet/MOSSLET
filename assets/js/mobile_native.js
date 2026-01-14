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
};

window.MobileNative = MobileNative;

export default MobileNative;
