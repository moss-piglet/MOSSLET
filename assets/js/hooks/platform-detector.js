const PlatformDetector = {
  mounted() {
    const platform = this.detectPlatform();
    this.pushEvent("platform_detected", { platform });
    
    const platformName = document.getElementById("detected-platform-name");
    if (platformName) {
      platformName.textContent = this.getPlatformDisplayName(platform);
    }
  },

  detectPlatform() {
    const userAgent = navigator.userAgent.toLowerCase();
    const platform = navigator.platform?.toLowerCase() || "";
    
    if (userAgent.includes("iphone") || userAgent.includes("ipad")) {
      return "ios";
    }
    
    if (userAgent.includes("android")) {
      return "android";
    }
    
    if (platform.includes("mac") || userAgent.includes("macintosh")) {
      return "macos";
    }
    
    if (platform.includes("win") || userAgent.includes("windows")) {
      return "windows";
    }
    
    if (platform.includes("linux") || userAgent.includes("linux")) {
      return "linux";
    }
    
    return "unknown";
  },

  getPlatformDisplayName(platform) {
    const names = {
      macos: "macOS",
      windows: "Windows",
      linux: "Linux",
      ios: "iOS",
      android: "Android"
    };
    return names[platform] || "your device";
  }
};

export default PlatformDetector;
