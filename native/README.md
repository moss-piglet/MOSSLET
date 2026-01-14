# Mosslet Native Mobile Apps

This directory contains the native iOS and Android wrapper projects for the Mosslet app.

## Overview

Both platforms use a similar architecture:
- Embed the Erlang/OTP runtime compiled for the target platform
- Run Phoenix/LiveView locally on the device
- Render the UI in a native WebView
- Bridge native capabilities (haptics, sharing, keychain) to JavaScript

## Directory Structure

```
native/
├── ios/                    # iOS Xcode project
│   ├── Mosslet.xcodeproj/
│   └── Mosslet/           # Swift source files
├── android/               # Android Studio project
│   ├── app/              # Android app module
│   └── gradle/           # Gradle wrapper
└── README.md             # This file
```

## Platform Comparison

| Feature | iOS | Android |
|---------|-----|---------|
| Min Version | iOS 15.0 | Android 7.0 (API 24) |
| WebView | WKWebView | WebView |
| JS Bridge | `webkit.messageHandlers` | `@JavascriptInterface` |
| Secure Storage | Keychain | Android Keystore |
| Build Tool | Xcode | Gradle |

## JavaScript Bridge API

Both platforms expose a unified API to JavaScript:

```javascript
// Unified API (use this)
if (window.MossletNative) {
    // iOS
    MossletNative.isNative()        // true
    MossletNative.getPlatform()     // 'ios'
    MossletNative.openURL(url)
    MossletNative.share(text)
    MossletNative.haptic(style)
} else if (window.AndroidBridge) {
    // Android
    AndroidBridge.isNative()        // true
    AndroidBridge.getPlatform()     // 'android'
    AndroidBridge.postMessage(JSON.stringify({ action: 'open_url', url }))
    AndroidBridge.postMessage(JSON.stringify({ action: 'share', text }))
    AndroidBridge.postMessage(JSON.stringify({ action: 'haptic', style }))
}
```

## Building Releases

### Prerequisites

1. Install elixir-desktop build tools
2. Download pre-compiled Erlang for target platforms

### iOS

```bash
# Build Erlang release
MIX_TARGET=native MIX_ENV=prod mix release --path native/ios/Mosslet/rel

# Open in Xcode and build
open native/ios/Mosslet.xcodeproj
```

### Android

```bash
# Build Erlang release
MIX_TARGET=native MIX_ENV=prod mix release --path native/android/app/src/main/jniLibs

# Build APK
cd native/android && ./gradlew assembleRelease
```

## CSS Safe Area Support

Both platforms inject CSS custom properties for safe area insets:

```css
/* Use in your stylesheets */
.header {
    padding-top: var(--safe-area-top, 0);
}

.footer {
    padding-bottom: var(--safe-area-bottom, 0);
}

/* Or use env() for WebKit support */
.container {
    padding: env(safe-area-inset-top) env(safe-area-inset-right)
             env(safe-area-inset-bottom) env(safe-area-inset-left);
}
```

## Testing

### iOS Simulator

1. Open Xcode project
2. Select iOS Simulator device
3. Build and Run (⌘R)

### Android Emulator

1. Open Android Studio
2. Create AVD (Android Virtual Device)
3. Run on selected device

### Device Testing

Both platforms require provisioning:
- iOS: Apple Developer account + provisioning profile
- Android: Enable USB debugging on device

## Zero-Knowledge Architecture

When running as native apps, all encryption happens on-device:

```
User Data → Enacl Encrypt (ON DEVICE) → API → Server (sees only encrypted blob)
```

The server never has access to the user's private key or unencrypted data.
See `docs/ELIXIR_DESKTOP_ROADMAP.md` for full architecture details.
