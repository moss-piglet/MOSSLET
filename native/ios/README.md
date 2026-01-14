# Mosslet iOS App

Native iOS wrapper for the Mosslet Phoenix/LiveView application using elixir-desktop.

## Prerequisites

- Xcode 15.0+
- iOS 15.0+ deployment target
- Erlang/OTP compiled for iOS (via elixir-desktop toolchain)

## Project Structure

```
native/ios/
├── Mosslet.xcodeproj/     # Xcode project
└── Mosslet/
    ├── AppDelegate.swift       # App lifecycle management
    ├── MainViewController.swift # WebView container
    ├── LoadingViewController.swift # Launch screen
    ├── JsonBridge.swift        # JS ↔ Native communication
    ├── Bridge.swift            # Erlang runtime bridge
    ├── Keychain.swift          # Secure storage wrapper
    ├── Assets.xcassets/        # App icons, colors
    ├── Base.lproj/
    │   └── LaunchScreen.storyboard
    ├── Info.plist
    └── Mosslet.entitlements
```

## Building

### Development

1. Open `Mosslet.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build the Erlang release for iOS:
   ```bash
   # From project root
   MIX_TARGET=native MIX_ENV=prod mix release --path native/ios/Mosslet/rel
   ```
4. Run on simulator or device

### Production

1. Configure signing certificates in Xcode
2. Build release:
   ```bash
   MIX_TARGET=native MIX_ENV=prod mix release --path native/ios/Mosslet/rel
   ```
3. Archive and upload to App Store Connect

## Architecture

### Erlang Runtime

The app embeds a full Erlang runtime compiled for iOS ARM64. On launch:

1. `AppDelegate` shows `LoadingViewController`
2. `Bridge.startErlang()` initializes the runtime in a background thread
3. Phoenix starts on a local port
4. `MainViewController` loads the app via WKWebView

### WebView Integration

- WKWebView renders the Phoenix LiveView UI
- `JsonBridge` enables JS ↔ Swift communication
- Safe area insets are passed to CSS variables for proper layout
- External links open in Safari

### Native Features

The `MossletNative` JavaScript API provides:

```javascript
// Check if running in native app
MossletNative.isNative()  // true

// Get platform
MossletNative.getPlatform()  // 'ios'

// Open external URL
MossletNative.openURL('https://example.com')

// Share content
MossletNative.share('Check out Mosslet!')

// Haptic feedback
MossletNative.haptic('medium')
```

### Keychain Storage

The `Keychain` class wraps iOS Keychain Services for secure storage:

- Authentication tokens
- Encryption keys
- User credentials

Data is stored with `kSecAttrAccessibleAfterFirstUnlock` for background access.

## App Lifecycle Events

The app notifies Elixir of lifecycle changes:

- `app_will_resign_active` - User switching apps
- `app_did_enter_background` - App backgrounded
- `app_will_enter_foreground` - App returning
- `app_did_become_active` - App active again
- `app_will_terminate` - App terminating

## Configuration

### Bundle Identifier

Default: `com.mosslet.app`

Update in:
- `Mosslet.xcodeproj` → Target → General → Bundle Identifier
- `Mosslet.entitlements` → keychain-access-groups

### App Icons

Add icons to `Assets.xcassets/AppIcon.appiconset/`:
- 1024x1024 App Store icon (required)

### App Logo

Add `AppLogo` image to `Assets.xcassets` for launch screen.

## Debugging

### Enable WebView Inspector

WebView inspection is enabled for debug builds (iOS 16.4+):

1. Open Safari on Mac
2. Enable Develop menu: Safari → Preferences → Advanced → Show Develop menu
3. Run app on simulator/device
4. Safari → Develop → [Device] → localhost

### Console Logs

Erlang/Elixir logs are visible in Xcode console when running from Xcode.

## Security

- Local networking only (NSAllowsLocalNetworking)
- Desktop auth token for WebView requests
- Keychain storage for sensitive data
- App Transport Security enabled for external requests
