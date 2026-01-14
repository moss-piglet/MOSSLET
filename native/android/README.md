# Mosslet Android App

Native Android wrapper for the Mosslet Phoenix/LiveView application using elixir-desktop.

## Prerequisites

- Android Studio Hedgehog (2023.1.1) or later
- JDK 17
- Android SDK 34 (API 34)
- Erlang/OTP compiled for Android (via elixir-desktop toolchain)

## Project Structure

```
native/android/
├── app/
│   ├── src/main/
│   │   ├── java/com/mosslet/app/
│   │   │   ├── MossletApplication.kt  # Application class
│   │   │   ├── MainActivity.kt        # WebView activity
│   │   │   ├── Bridge.kt              # Erlang runtime bridge
│   │   │   ├── JsonBridge.kt          # JS ↔ Native communication
│   │   │   └── SecureStorage.kt       # Keystore-backed storage
│   │   ├── res/
│   │   │   ├── layout/                # XML layouts
│   │   │   ├── values/                # Strings, colors, themes
│   │   │   ├── drawable/              # Vector graphics
│   │   │   └── mipmap-*/              # App icons
│   │   └── AndroidManifest.xml
│   ├── build.gradle
│   └── proguard-rules.pro
├── build.gradle
├── settings.gradle
└── gradle.properties
```

## Building

### Development

1. Open the `native/android` directory in Android Studio
2. Build the Erlang release for Android:
   ```bash
   # From project root
   MIX_TARGET=native MIX_ENV=prod mix release --path native/android/app/src/main/jniLibs
   ```
3. Run on emulator or connected device

### Production

1. Configure signing in `app/build.gradle`:
   ```gradle
   signingConfigs {
       release {
           storeFile file("keystore.jks")
           storePassword System.getenv("KEYSTORE_PASSWORD")
           keyAlias "mosslet"
           keyPassword System.getenv("KEY_PASSWORD")
       }
   }
   ```
2. Build release APK/Bundle:
   ```bash
   ./gradlew assembleRelease
   # or for Play Store
   ./gradlew bundleRelease
   ```

## Architecture

### Erlang Runtime

The app embeds a full Erlang runtime compiled for Android ARM64/ARM32. On launch:

1. `MossletApplication` initializes
2. `MainActivity` shows loading view
3. `Bridge.startErlang()` initializes the runtime
4. Phoenix starts on a local port
5. WebView loads the app

### WebView Integration

- WebView renders the Phoenix LiveView UI
- `JsonBridge` enables JS ↔ Kotlin communication via `@JavascriptInterface`
- System bar insets are passed to CSS variables
- External links open in default browser

### Native Features

The `AndroidBridge` JavaScript API provides:

```javascript
// Check if running in native app
AndroidBridge.isNative()  // true

// Get platform
AndroidBridge.getPlatform()  // 'android'

// Send message to native
AndroidBridge.postMessage(JSON.stringify({
    action: 'open_url',
    url: 'https://example.com'
}))

// Available actions:
// - open_url: Open URL in browser
// - share: Share text content
// - haptic: Trigger haptic feedback (light/medium/heavy)
```

### Secure Storage

The `SecureStorage` object uses Android Keystore for encryption:

- AES-256-GCM encryption
- Keys stored in hardware-backed Keystore
- Data stored in SharedPreferences (encrypted)

## App Lifecycle Events

The app notifies Elixir of lifecycle changes:

- `app_resumed` - Activity resumed
- `app_paused` - Activity paused
- `app_destroyed` - Activity destroyed
- `memory_warning` - System memory low
- `shutdown` - App terminating

## Configuration

### App Icons

Generate icons using Android Studio's Image Asset Studio:
1. Right-click `res` → New → Image Asset
2. Select your 1024x1024 source image
3. Generate all required sizes

### Deep Links

The app is configured for the `mosslet://` scheme. Add web links:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="mosslet.com" />
</intent-filter>
```

## Debugging

### Chrome DevTools

1. Enable USB debugging on device
2. Open `chrome://inspect` in Chrome
3. Select your WebView under the device

### Logcat

View Erlang/Elixir logs:
```bash
adb logcat -s MossletApp MossletBridge
```

## Security

- `android:usesCleartextTraffic="true"` only for localhost
- WebView JavaScript interface restricted to app code
- Keystore-backed encryption for sensitive data
- ProGuard enabled for release builds
- Backup excludes secure preferences
