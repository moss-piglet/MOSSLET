# Mobile Build Guide

This guide covers building Mosslet native apps for iOS and Android using elixir-desktop.

## Overview

Building native apps requires:
1. **Cross-compiled Erlang/OTP** for each target platform (iOS ARM64, Android ARM64/ARM32/x86_64)
2. **Mix release** of the Mosslet application
3. **Native wrapper apps** (Xcode for iOS, Android Studio for Android)

## Quick Start

For local development builds:

```bash
# iOS Simulator (macOS only)
./scripts/build_ios.sh simulator

# iOS Device (macOS only, requires Apple Developer account)
./scripts/build_ios.sh device

# Android Emulator
./scripts/build_android.sh emulator

# Android Device
./scripts/build_android.sh device
```

For production releases, use GitHub Actions (see CI/CD section below).

---

## Prerequisites

### All Platforms
- Elixir 1.17+ / Erlang/OTP 27+
- Node.js 20+ (for asset compilation)
- Git

### iOS (macOS only)
- macOS 14+ (Sonoma)
- Xcode 15.4+
- Xcode Command Line Tools: `xcode-select --install`
- Apple Developer account (for device builds and distribution)
- CocoaPods: `brew install cocoapods`

### Android
- Android Studio Hedgehog (2023.1.1)+
- Android SDK 34 (API Level 34)
- Android NDK r26+ (install via SDK Manager)
- JDK 17

---

## Step 1: Build Erlang/OTP for Mobile

We use pre-built OTP binaries from elixir-desktop releases when available, or build from source.

### Option A: Use Pre-built OTP (Recommended)

```bash
# Download pre-built OTP for your targets
./scripts/download_otp.sh

# This downloads and extracts:
# - native/otp/ios/OTP.xcframework (iOS universal)
# - native/otp/android/arm64-v8a/*.so
# - native/otp/android/armeabi-v7a/*.so
# - native/otp/android/x86_64/*.so
```

### Option B: Build OTP from Source

If you need a custom OTP version or the pre-built isn't available:

```bash
# Clone OTP build tools
git clone https://github.com/nickvander/otp_build.git
cd otp_build

# Build for iOS (requires macOS + Xcode)
./build_ios.sh

# Build for Android (requires NDK)
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/26.1.10909125
./build_android.sh
```

---

## Step 2: Create Mix Release

### Configure Release

The release configuration is in `mix.exs`:

```elixir
def project do
  [
    # ... existing config
    releases: releases()
  ]
end

defp releases do
  [
    mosslet_ios: [
      include_executables_for: [],
      steps: [:assemble],
      strip_beams: true,
      rel_templates_path: "rel/ios"
    ],
    mosslet_android: [
      include_executables_for: [],
      steps: [:assemble],
      strip_beams: true,
      rel_templates_path: "rel/android"
    ]
  ]
end
```

### Build Release

```bash
# For iOS
MIX_TARGET=native MIX_ENV=prod mix assets.deploy
MIX_TARGET=native MIX_ENV=prod mix release mosslet_ios

# For Android
MIX_TARGET=native MIX_ENV=prod mix assets.deploy
MIX_TARGET=native MIX_ENV=prod mix release mosslet_android
```

---

## Step 3: Build iOS App

### Directory Structure

```
native/ios/
├── Mosslet.xcodeproj/
├── Mosslet/
│   ├── *.swift           # Swift source files
│   ├── Assets.xcassets/  # App icons and images
│   ├── Info.plist
│   └── Mosslet.entitlements
├── OTP.xcframework/      # Erlang runtime (added by build script)
└── rel/                  # Mix release output (added by build script)
```

### Build Steps

1. **Copy OTP framework and release:**
   ```bash
   # Copy OTP framework
   cp -r native/otp/ios/OTP.xcframework native/ios/
   
   # Copy release
   cp -r _build/native_prod/rel/mosslet_ios native/ios/rel
   ```

2. **Open in Xcode:**
   ```bash
   open native/ios/Mosslet.xcodeproj
   ```

3. **Configure signing:**
   - Select the Mosslet target
   - Go to "Signing & Capabilities"
   - Select your team and configure bundle identifier

4. **Build and run:**
   - Select target device/simulator
   - Press Cmd+R to build and run

### Automated iOS Build

```bash
# Development (simulator)
./scripts/build_ios.sh simulator

# Development (device)
./scripts/build_ios.sh device

# Release (App Store)
./scripts/build_ios.sh release
```

---

## Step 4: Build Android App

### Directory Structure

```
native/android/
├── app/
│   ├── src/main/
│   │   ├── java/com/mosslet/app/  # Kotlin source
│   │   ├── jniLibs/               # OTP native libs (added by build)
│   │   │   ├── arm64-v8a/
│   │   │   ├── armeabi-v7a/
│   │   │   └── x86_64/
│   │   ├── assets/rel/            # Mix release (added by build)
│   │   └── res/
│   └── build.gradle
├── build.gradle
└── settings.gradle
```

### Build Steps

1. **Copy OTP libraries and release:**
   ```bash
   # Copy OTP native libraries
   cp -r native/otp/android/* native/android/app/src/main/jniLibs/
   
   # Copy release
   mkdir -p native/android/app/src/main/assets
   cp -r _build/native_prod/rel/mosslet_android native/android/app/src/main/assets/rel
   ```

2. **Open in Android Studio:**
   ```bash
   # Open the native/android directory
   studio native/android
   ```

3. **Build and run:**
   - Select target device/emulator
   - Press the Run button

### Automated Android Build

```bash
# Development (emulator)
./scripts/build_android.sh emulator

# Development (device)
./scripts/build_android.sh device

# Release (Play Store)
./scripts/build_android.sh release
```

---

## CI/CD Pipeline

### GitHub Actions Workflow

The `.github/workflows/mobile-builds.yml` workflow automates:

1. **Build OTP** (cached for subsequent runs)
2. **Build Mix release** for each platform
3. **Build iOS app** (macOS runner)
4. **Build Android app** (Linux runner)
5. **Upload to TestFlight/Play Store** (on tagged releases)

### Triggering Builds

- **Pull requests:** Build and test (no upload)
- **Push to main:** Build and upload to internal testing tracks
- **Version tags (v*.*.*):** Build and upload to production tracks

### Required Secrets

Configure these in GitHub repository settings:

**iOS:**
- `APPLE_TEAM_ID` - Your Apple Developer Team ID
- `APPLE_CERTIFICATE_BASE64` - Distribution certificate (p12, base64 encoded)
- `APPLE_CERTIFICATE_PASSWORD` - Certificate password
- `APPLE_PROVISIONING_PROFILE_BASE64` - App Store provisioning profile (base64)
- `APP_STORE_CONNECT_API_KEY_ID` - API Key ID
- `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID
- `APP_STORE_CONNECT_API_KEY_BASE64` - API Key (p8, base64 encoded)

**Android:**
- `ANDROID_KEYSTORE_BASE64` - Release keystore (base64 encoded)
- `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- `ANDROID_KEY_ALIAS` - Key alias
- `ANDROID_KEY_PASSWORD` - Key password
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` - Play Console service account JSON

---

## Troubleshooting

### iOS

**"OTP.xcframework not found"**
```bash
./scripts/download_otp.sh
# or rebuild: ./scripts/build_otp.sh ios
```

**Signing issues**
- Ensure your Apple Developer account is active
- Check bundle identifier matches provisioning profile
- Revoke and recreate certificates if expired

**Runtime crash on launch**
- Check Xcode console for Erlang errors
- Verify OTP framework architecture matches device (arm64 for device, arm64+x86_64 for simulator)

### Android

**"UnsatisfiedLinkError: dlopen failed"**
- Verify JNI libraries are in correct ABI folders
- Check Android NDK version matches build

**Gradle sync failed**
- Update Android Studio and Gradle plugin
- Clear caches: `./gradlew clean`

**App crashes on launch**
- Check logcat for native crash: `adb logcat | grep -i "art\|mosslet\|erlang"`
- Verify release was built for correct architecture

### General

**Mix release fails**
- Ensure `MIX_TARGET=native` is set
- Check all native deps compile for target

**Assets not loading**
- Rebuild assets: `mix assets.deploy`
- Check release includes `priv/static`

---

## App Store Submission Checklist

### iOS (App Store Connect)

- [ ] App icons (1024x1024 required)
- [ ] Screenshots for all device sizes
- [ ] App description and keywords
- [ ] Privacy policy URL
- [ ] App category selection
- [ ] Age rating questionnaire
- [ ] Export compliance (encryption)
- [ ] TestFlight beta testing completed

### Android (Google Play Console)

- [ ] App icons (512x512 required)
- [ ] Feature graphic (1024x500)
- [ ] Screenshots for phone and tablet
- [ ] Short and full descriptions
- [ ] Privacy policy URL
- [ ] Content rating questionnaire
- [ ] Target audience and content
- [ ] Data safety section
- [ ] Internal testing completed

---

## Version Management

App versions are managed in:

- `mix.exs` - `@version "x.y.z"` (source of truth)
- `native/ios/Mosslet.xcodeproj` - CFBundleShortVersionString
- `native/android/app/build.gradle` - versionName

The build scripts automatically sync versions from `mix.exs`.

Build numbers are auto-incremented by CI:
- iOS: CFBundleVersion
- Android: versionCode
