#!/bin/bash
# Build script for Mosslet mobile apps
# Usage: ./scripts/build_mobile.sh {ios|android|all} [--release]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OTP_BUILD_DIR="${OTP_BUILD_DIR:-$HOME/otp_build}"

PLATFORM="${1:-all}"
BUILD_TYPE="${2:-debug}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_otp_build() {
    if [ ! -d "$OTP_BUILD_DIR" ]; then
        log_error "OTP build directory not found at $OTP_BUILD_DIR"
        log_info "Clone it first: git clone https://github.com/nickvander/otp_build $OTP_BUILD_DIR"
        exit 1
    fi
}

build_elixir_release() {
    log_info "Building Elixir release for mobile..."
    cd "$PROJECT_ROOT"
    
    export MIX_TARGET=host
    export MIX_ENV=prod
    
    mix deps.get
    mix compile
    mix assets.deploy
    mix release mobile --overwrite
    
    log_info "Release built at _build/native_prod/rel/mobile/"
}

build_ios() {
    log_info "Building for iOS..."
    
    check_otp_build
    
    if [ ! -d "$OTP_BUILD_DIR/build/ios/OTP.xcframework" ]; then
        log_warn "OTP framework not found, building..."
        cd "$OTP_BUILD_DIR"
        ./build_ios.sh
    fi
    
    build_elixir_release
    
    mkdir -p "$PROJECT_ROOT/native/ios/Frameworks"
    cp -R "$OTP_BUILD_DIR/build/ios/OTP.xcframework" "$PROJECT_ROOT/native/ios/Frameworks/"
    
    "$SCRIPT_DIR/package_ios.sh"
    
    log_info "iOS build complete!"
    log_info "Open native/ios/Mosslet.xcodeproj in Xcode to run"
}

build_android() {
    log_info "Building for Android..."
    
    check_otp_build
    
    if [ -z "$ANDROID_NDK_HOME" ] && [ -z "$ANDROID_NDK_ROOT" ]; then
        ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk"
        if [ -d "$ANDROID_NDK_HOME" ]; then
            NDK_VERSION=$(ls "$ANDROID_NDK_HOME" | sort -V | tail -1)
            export ANDROID_NDK_HOME="$ANDROID_NDK_HOME/$NDK_VERSION"
        fi
    fi
    
    if [ ! -d "${ANDROID_NDK_HOME:-$ANDROID_NDK_ROOT}" ]; then
        log_error "Android NDK not found. Install via Android Studio SDK Manager."
        exit 1
    fi
    
    if [ ! -d "$OTP_BUILD_DIR/build/android/jniLibs" ]; then
        log_warn "OTP Android libs not found, building..."
        cd "$OTP_BUILD_DIR"
        ./build_android.sh
    fi
    
    build_elixir_release
    
    mkdir -p "$PROJECT_ROOT/native/android/app/src/main/jniLibs"
    cp -R "$OTP_BUILD_DIR/build/android/jniLibs/"* "$PROJECT_ROOT/native/android/app/src/main/jniLibs/"
    
    "$SCRIPT_DIR/package_android.sh"
    
    cd "$PROJECT_ROOT/native/android"
    if [ "$BUILD_TYPE" == "--release" ]; then
        ./gradlew bundleRelease
        log_info "Release AAB: native/android/app/build/outputs/bundle/release/app-release.aab"
    else
        ./gradlew assembleDebug
        log_info "Debug APK: native/android/app/build/outputs/apk/debug/app-debug.apk"
    fi
    
    log_info "Android build complete!"
}

print_usage() {
    echo "Usage: $0 {ios|android|all} [--release]"
    echo ""
    echo "Options:"
    echo "  ios        Build iOS app"
    echo "  android    Build Android app"
    echo "  all        Build both platforms"
    echo "  --release  Build release version (default: debug)"
    echo ""
    echo "Environment variables:"
    echo "  OTP_BUILD_DIR    Path to otp_build repo (default: ~/otp_build)"
    echo "  ANDROID_NDK_HOME Path to Android NDK"
}

case $PLATFORM in
    ios)
        build_ios
        ;;
    android)
        build_android
        ;;
    all)
        build_ios
        build_android
        ;;
    -h|--help)
        print_usage
        ;;
    *)
        log_error "Unknown platform: $PLATFORM"
        print_usage
        exit 1
        ;;
esac
