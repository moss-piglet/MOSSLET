#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/_build/desktop"
VERSION=$(grep '@version' "$PROJECT_ROOT/mix.exs" | head -1 | sed 's/.*"\(.*\)".*/\1/')

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

detect_platform() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

PLATFORM="${1:-$(detect_platform)}"
BUILD_TYPE="${2:-release}"

log_info "Building MOSSLET Desktop v$VERSION for $PLATFORM ($BUILD_TYPE)"

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v mix &> /dev/null; then
        log_error "Elixir/Mix not found. Please install Elixir."
        exit 1
    fi
    
    if [ "$PLATFORM" = "macos" ]; then
        if ! command -v create-dmg &> /dev/null; then
            log_warn "create-dmg not found. Install with: brew install create-dmg"
            log_warn "Will skip DMG creation."
        fi
    fi
    
    if [ "$PLATFORM" = "linux" ]; then
        if ! command -v appimagetool &> /dev/null; then
            log_warn "appimagetool not found. Download from https://appimage.github.io/"
            log_warn "Will skip AppImage creation."
        fi
    fi
}

build_release() {
    log_info "Building Elixir release..."
    
    cd "$PROJECT_ROOT"
    
    export MOSSLET_NATIVE=true
    export MIX_ENV=prod
    
    mix deps.get --only prod
    mix assets.deploy
    mix release desktop --overwrite
    
    log_info "Release built successfully"
}

package_macos() {
    log_info "Packaging for macOS..."
    
    local RELEASE_DIR="$PROJECT_ROOT/_build/prod/rel/desktop"
    local APP_DIR="$BUILD_DIR/Mosslet.app"
    local CONTENTS_DIR="$APP_DIR/Contents"
    local MACOS_DIR="$CONTENTS_DIR/MacOS"
    local RESOURCES_DIR="$CONTENTS_DIR/Resources"
    
    rm -rf "$BUILD_DIR"
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
    
    cp -R "$RELEASE_DIR/"* "$RESOURCES_DIR/"
    
    cat > "$MACOS_DIR/Mosslet" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/../Resources"
export RELEASE_ROOT="$RESOURCES_DIR"
export MOSSLET_NATIVE=true
export MOSSLET_DESKTOP=true
exec "$RESOURCES_DIR/bin/desktop" start
EOF
    chmod +x "$MACOS_DIR/Mosslet"
    
    cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Mosslet</string>
    <key>CFBundleIdentifier</key>
    <string>com.mosslet.desktop</string>
    <key>CFBundleName</key>
    <string>MOSSLET</string>
    <key>CFBundleDisplayName</key>
    <string>MOSSLET</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.mosslet.desktop</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>mosslet</string>
            </array>
        </dict>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

    if [ -f "$PROJECT_ROOT/priv/static/images/icon.icns" ]; then
        cp "$PROJECT_ROOT/priv/static/images/icon.icns" "$RESOURCES_DIR/AppIcon.icns"
    fi
    
    log_info "App bundle created: $APP_DIR"
    
    if command -v create-dmg &> /dev/null; then
        log_info "Creating DMG installer..."
        local DMG_PATH="$BUILD_DIR/Mosslet-$VERSION-macos.dmg"
        rm -f "$DMG_PATH"
        create-dmg \
            --volname "MOSSLET $VERSION" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "Mosslet.app" 150 190 \
            --app-drop-link 450 185 \
            "$DMG_PATH" \
            "$APP_DIR"
        log_info "DMG created: $DMG_PATH"
    fi
    
    log_info "Creating ZIP archive..."
    cd "$BUILD_DIR"
    zip -r "Mosslet-$VERSION-macos.zip" "Mosslet.app"
    log_info "ZIP created: $BUILD_DIR/Mosslet-$VERSION-macos.zip"
}

package_linux() {
    log_info "Packaging for Linux..."
    
    local RELEASE_DIR="$PROJECT_ROOT/_build/prod/rel/desktop"
    local APPDIR="$BUILD_DIR/Mosslet.AppDir"
    
    rm -rf "$BUILD_DIR"
    mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps"
    
    cp -R "$RELEASE_DIR/"* "$APPDIR/usr/lib/"
    
    cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export RELEASE_ROOT="$HERE/usr/lib"
export MOSSLET_NATIVE=true
export MOSSLET_DESKTOP=true
exec "$HERE/usr/lib/bin/desktop" start "$@"
EOF
    chmod +x "$APPDIR/AppRun"
    
    cat > "$APPDIR/mosslet.desktop" << EOF
[Desktop Entry]
Type=Application
Name=MOSSLET
Comment=Your private social network
Exec=mosslet
Icon=mosslet
Categories=Network;Chat;
Terminal=false
StartupWMClass=MOSSLET
EOF
    cp "$APPDIR/mosslet.desktop" "$APPDIR/usr/share/applications/"
    
    if [ -f "$PROJECT_ROOT/priv/static/images/icon.png" ]; then
        cp "$PROJECT_ROOT/priv/static/images/icon.png" "$APPDIR/mosslet.png"
        cp "$PROJECT_ROOT/priv/static/images/icon.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/mosslet.png"
    fi
    
    log_info "AppDir created: $APPDIR"
    
    if command -v appimagetool &> /dev/null; then
        log_info "Creating AppImage..."
        local ARCH=$(uname -m)
        ARCH=$ARCH appimagetool "$APPDIR" "$BUILD_DIR/Mosslet-$VERSION-$ARCH.AppImage"
        log_info "AppImage created: $BUILD_DIR/Mosslet-$VERSION-$ARCH.AppImage"
    fi
    
    log_info "Creating tarball..."
    cd "$BUILD_DIR"
    tar -czvf "Mosslet-$VERSION-linux-$(uname -m).tar.gz" -C "$APPDIR" .
    log_info "Tarball created: $BUILD_DIR/Mosslet-$VERSION-linux-$(uname -m).tar.gz"
}

package_windows() {
    log_info "Packaging for Windows..."
    
    local RELEASE_DIR="$PROJECT_ROOT/_build/prod/rel/desktop"
    local WIN_DIR="$BUILD_DIR/Mosslet"
    
    rm -rf "$BUILD_DIR"
    mkdir -p "$WIN_DIR"
    
    cp -R "$RELEASE_DIR/"* "$WIN_DIR/"
    
    cat > "$WIN_DIR/Mosslet.bat" << 'EOF'
@echo off
set RELEASE_ROOT=%~dp0
set MOSSLET_NATIVE=true
set MOSSLET_DESKTOP=true
"%RELEASE_ROOT%bin\desktop.bat" start
EOF

    log_info "Windows package created: $WIN_DIR"
    
    log_info "Creating ZIP archive..."
    cd "$BUILD_DIR"
    zip -r "Mosslet-$VERSION-windows.zip" "Mosslet"
    log_info "ZIP created: $BUILD_DIR/Mosslet-$VERSION-windows.zip"
    
    log_info "Note: For EXE installer, use NSIS or Inno Setup with the files in $WIN_DIR"
}

main() {
    check_dependencies
    build_release
    
    case "$PLATFORM" in
        macos)   package_macos ;;
        linux)   package_linux ;;
        windows) package_windows ;;
        *)
            log_error "Unknown platform: $PLATFORM"
            exit 1
            ;;
    esac
    
    log_info "Build complete! Artifacts in: $BUILD_DIR"
    ls -la "$BUILD_DIR"
}

main
