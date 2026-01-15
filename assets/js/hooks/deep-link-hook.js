import MobileNative from "../mobile_native";

const ALLOWED_PATH_PREFIXES = [
  "/app/",
  "/profile/",
  "/invite/",
  "/post/",
  "/group/",
  "/users/settings/",
];

function isValidPath(path) {
  if (typeof path !== "string") return false;
  if (!path.startsWith("/")) return false;
  if (path.includes("..")) return false;
  if (path.includes("//")) return false;
  if (/%[0-9a-f]{2}/i.test(path) && path.includes("%2f")) return false;

  if (path === "/" || path === "/app") return true;

  return ALLOWED_PATH_PREFIXES.some((prefix) => path.startsWith(prefix));
}

const DeepLinkHook = {
  mounted() {
    this._handleDeepLink = (url, path) => {
      if (!isValidPath(path)) {
        console.warn("DeepLinkHook: blocked invalid path", path);
        return;
      }
      this.pushEvent("deep_link_received", { url, path });
    };

    this._unsubscribe = MobileNative.deepLink.onReceived(this._handleDeepLink);

    this.handleEvent("navigate_to", ({ path }) => {
      if (!isValidPath(path)) {
        console.warn("DeepLinkHook: blocked invalid navigate_to path", path);
        return;
      }
      MobileNative.deepLink.navigate(path);
    });
  },

  destroyed() {
    if (this._unsubscribe) {
      this._unsubscribe();
    }
  },
};

export default DeepLinkHook;
