import MobileNative from "../mobile_native";

const DeepLinkHook = {
  mounted() {
    this._handleDeepLink = (url, path) => {
      this.pushEvent("deep_link_received", { url, path });
    };

    MobileNative.deepLink.onReceived(this._handleDeepLink);

    this.handleEvent("navigate_to", ({ path }) => {
      MobileNative.deepLink.navigate(path);
    });
  },

  destroyed() {
    const idx = MobileNative.deepLink._callbacks.indexOf(this._handleDeepLink);
    if (idx > -1) {
      MobileNative.deepLink._callbacks.splice(idx, 1);
    }
  },
};

export default DeepLinkHook;
