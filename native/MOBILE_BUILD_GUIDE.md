# Mobile App Build Guide

This guide covers building the Mosslet mobile apps for iOS and Android using elixir-desktop.

## Overview

The mobile apps embed a full Erlang/Elixir runtime that runs Phoenix locally. The native wrapper (Swift/Kotlin) provides:

1. WebView container for the Phoenix UI
2. Native bridge for platform features (push, deep links, etc.)
3. Secure storage via OS keychain/keystore

```
┌─────────────────────────────────────┐
│          Native App Shell           │
│  (Swift/Kotlin + System WebView)    │
├─────────────────────────────────────┤
│          Erlang/OTP Runtime         │
│  (Cross-compiled for ARM64/x86)     │
├─────────────────────────────────────┤
│       Phoenix + LiveView App        │
│     (Compiled BEAM bytecode)        │
└─────────────────────────────────────┘
```

## Prerequisites

### All Platforms

- Elixir 1.19+
- Erlang/OTP 28+
- Node.js 18+ (for assets)
- Git

### iOS

- macOS 14+ (Sonoma or later)
- Xcode 15.0+
- Apple Developer Account (for device testing and App Store)
- CocoaPods: `brew install cocoapods`

### Android

- Android Studio Hedgehog (2023.1.1) or later
- JDK 17
- Android SDK 34
- Android NDK r26+ (install via SDK Manager)

## Quick Start

```bash
# Clone the OTP builder (do this once)
git clone https://github.com/nickvander/otp_build ~/otp_build

# Build OTP for your target platform
cd ~/otp_build
./build_ios.sh      # For iOS
./build_android.sh  # For Android

# Back to mosslet, create the release
cd /path/to/mosslet
./scripts/build_mobile.sh ios      # Build for iOS
./scripts/build_mobile.sh android  # Build for Android
```

## Detailed Build Process

### Step 1: Cross-Compile Erlang/OTP

The Erlang runtime must be compiled for each target architecture.

#### iOS Targets

| Architecture | Target          | Use Case           |
|--------------|-----------------|-------------------|
| arm64        | ios-arm64       | iPhone/iPad device |
| arm64        | ios-simulator-arm64 | M1/M2 Mac simulator |
| x86_64       | ios-simulator-x86_64 | Intel Mac simulator |

```bash
cd ~/otp_build

# Build all iOS targets (creates universal framework)
./build_ios.sh

# Output: ~/otp_build/build/ios/OTP.xcframework
```

#### Android Targets

| Architecture  | ABI           | Use Case              |
|---------------|---------------|----------------------|
| arm64-v8a     | aarch64       | Modern phones (95%+)  |
| armeabi-v7a   | arm           | Older 32-bit phones   |
| x86_64        | x86_64        | Emulator              |

```bash
cd ~/otp_build

# Set NDK path (adjust for your installation)
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/26.1.10909125

# Build all Android targets
./build_android.sh

# Output: ~/otp_build/build/android/jniLibs/
```

### Step 2: Build Phoenix Release

Create a minimal release for mobile:

```bash
# From mosslet project root
MIX_TARGET=native MIX_ENV=prod mix do deps.get, compile

# Build assets
mix assets.deploy

# Create release
MIX_TARGET=native MIX_ENV=prod mix release mobile --overwrite
```

The release will be created in `_build/native_prod/rel/mobile/`.

### Step 3: Package for iOS

```bash
# Copy OTP framework to iOS project
cp -R ~/otp_build/build/ios/OTP.xcframework native/ios/Frameworks/

# Copy BEAM release to iOS bundle
./scripts/package_ios.sh

# Open in Xcode and build
open native/ios/Mosslet.xcodeproj
```

### Step 4: Package for Android

```bash
# Copy OTP libraries to Android project
cp -R ~/otp_build/build/android/jniLibs/* native/android/app/src/main/jniLibs/

# Copy BEAM release to Android assets
./scripts/package_android.sh

# Build with Gradle
cd native/android
./gradlew assembleDebug   # For testing
./gradlew bundleRelease   # For Play Store
```

## Build Scripts

### Main Build Script: `scripts/build_mobile.sh`

```bash
#!/bin/bash
set -e

PLATFORM=$1
OTP_BUILD_DIR="${OTP_BUILD_DIR:-$HOME/otp_build}"

case $PLATFORM in
  ios)
    echo "Building for iOS..."
    ./scripts/build_ios.sh
    ;;
  android)
    echo "Building for Android..."
    ./scripts/build_android.sh
    ;;
  all)
    echo "Building for all platforms..."
    ./scripts/build_ios.sh
    ./scripts/build_android.sh
    ;;
  *)
    echo "Usage: $0 {ios|android|all}"
    exit 1
    ;;
esac
```

## Release Configuration

Add to `mix.exs`:

```elixir
def project do
  [
    # ... existing config
    releases: releases()
  ]
end

defp releases do
  [
    mobile: [
      include_executables_for: [],
      applications: [
        runtime_tools: :permanent,
        mosslet: :permanent
      ],
      steps: [:assemble, &copy_native_libs/1],
      strip_beams: [keep: ["Docs", "Dbgi"]],
      cookie: System.get_env("RELEASE_COOKIE") || :crypto.strong_rand_bytes(32) |> Base.encode64()
    ]
  ]
end

defp copy_native_libs(release) do
  # Copy NIFs and native extensions
  release
end
```

## Environment Configuration

### Runtime Config for Mobile

In `config/runtime.exs`:

```elixir
if config_env() == :prod and System.get_env("MOSSLET_MOBILE") do
  # Mobile-specific runtime config
  config :mosslet,
    sync_api_url: System.get_env("API_URL", "https://mosslet.com/api")
  
  config :mosslet, MossletWeb.Endpoint,
    http: [port: 4000],
    server: true,
    secret_key_base: System.get_env("SECRET_KEY_BASE")
end
```

## Signing & Distribution

### iOS Code Signing

1. Create App ID in Apple Developer Portal
2. Create provisioning profiles (Development + Distribution)
3. Configure in Xcode:
   - Select team
   - Enable automatic signing for development
   - Use manual signing for distribution

### Android Signing

1. Generate release keystore:
   ```bash
   keytool -genkey -v -keystore mosslet-release.keystore \
     -alias mosslet -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Configure in `app/build.gradle`:
   ```gradle
   signingConfigs {
       release {
           storeFile file("mosslet-release.keystore")
           storePassword System.getenv("KEYSTORE_PASSWORD")
           keyAlias "mosslet"
           keyPassword System.getenv("KEY_PASSWORD")
       }
   }
   ```

## CI/CD

See `.github/workflows/mobile-build.yml` for automated builds.

### Required Secrets

| Secret | Description |
|--------|-------------|
| `APPLE_CERTIFICATE_BASE64` | P12 certificate for iOS signing |
| `APPLE_CERTIFICATE_PASSWORD` | Password for P12 |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64 encoded .mobileprovision |
| `KEYSTORE_BASE64` | Base64 encoded Android keystore |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play service account |

## Troubleshooting

### iOS: "OTP.xcframework not found"

Ensure you've built OTP and copied the framework:
```bash
ls native/ios/Frameworks/OTP.xcframework
```

### Android: "Failed to find liberlang.so"

Check that JNI libraries are in the correct location:
```bash
ls native/android/app/src/main/jniLibs/arm64-v8a/
```

### Elixir: "Cannot start runtime"

1. Check that the release was built for the correct target
2. Verify ERTS version matches the cross-compiled OTP
3. Check logs for specific error messages

### Memory Issues

Mobile devices have limited memory. Consider:
- Reducing Erlang process limits
- Using streams for large data
- Implementing aggressive cache eviction

## Testing

### iOS Simulator

```bash
# Build and run on simulator
cd native/ios
xcodebuild -scheme Mosslet -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Android Emulator

```bash
# Create emulator (once)
avdmanager create avd -n mosslet_test -k "system-images;android-34;google_apis;arm64-v8a"

# Start emulator
emulator -avd mosslet_test &

# Install and run
cd native/android
./gradlew installDebug
adb shell am start -n com.mosslet.app/.MainActivity
```

## Resources

- [elixir-desktop documentation](https://github.com/elixir-desktop/desktop)
- [otp_build scripts](https://github.com/nickvander/otp_build)
- [Erlang cross-compilation guide](https://www.erlang.org/doc/installation_guide/install.html#cross-compiling)
- [Phoenix releases documentation](https://hexdocs.pm/phoenix/releases.html)
