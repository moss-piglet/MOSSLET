# Desktop App Build Guide

This guide covers building and distributing MOSSLET desktop apps for macOS, Windows, and Linux.

## Overview

MOSSLET desktop apps use [elixir-desktop](https://github.com/elixir-desktop/desktop) which embeds Phoenix/LiveView into a native window using wxWidgets. The app runs a local Phoenix server and displays it in a native WebView.

## Prerequisites

### All Platforms

- Elixir 1.17+ and Erlang/OTP 27+
- Node.js 18+ (for asset compilation)
- Git

### macOS

```bash
# Install Homebrew dependencies
brew install wxwidgets
brew install create-dmg  # Optional: for DMG creation

# Ensure Erlang was compiled with wxWidgets support
# If using asdf:
export KERL_CONFIGURE_OPTIONS="--with-wx"
asdf install erlang 27.0
```

### Linux

```bash
# Ubuntu/Debian
sudo apt-get install libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev

# Fedora
sudo dnf install wxGTK3-devel

# For AppImage creation
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool
```

### Windows

- Visual Studio 2022 with C++ workload
- wxWidgets 3.2+ (compiled or from vcpkg)
- [Inno Setup](https://jrsoftware.org/isinfo.php) (optional: for EXE installer)

## Quick Build

```bash
# Build for current platform
./scripts/build_desktop.sh

# Build for specific platform
./scripts/build_desktop.sh macos
./scripts/build_desktop.sh linux
./scripts/build_desktop.sh windows
```

## Output

After building, artifacts are in `_build/desktop/`:

| Platform | Artifacts |
|----------|-----------|
| macOS | `Mosslet.app`, `Mosslet-X.X.X-macos.dmg`, `Mosslet-X.X.X-macos.zip` |
| Linux | `Mosslet.AppDir/`, `Mosslet-X.X.X-x86_64.AppImage`, `Mosslet-X.X.X-linux-x86_64.tar.gz` |
| Windows | `Mosslet/`, `Mosslet-X.X.X-windows.zip` |

## Manual Build Steps

### 1. Set Environment

```bash
export MOSSLET_NATIVE=true
export MIX_ENV=prod
```

### 2. Build Assets

```bash
mix deps.get --only prod
mix assets.deploy
```

### 3. Create Release

```bash
mix release desktop --overwrite
```

The release is created at `_build/prod/rel/desktop/`.

### 4. Package (Platform-Specific)

See `scripts/build_desktop.sh` for packaging details per platform.

## Code Signing & Notarization

### macOS

1. **Developer ID Certificate**: Obtain from Apple Developer Program ($99/year)

2. **Code Sign**:
```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  _build/desktop/Mosslet.app
```

3. **Notarize**:
```bash
xcrun notarytool submit _build/desktop/Mosslet-X.X.X-macos.zip \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait

xcrun stapler staple _build/desktop/Mosslet.app
```

### Windows

1. **EV Code Signing Certificate**: Purchase from a CA (~$300-500/year)

2. **Sign with SignTool**:
```cmd
signtool sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 ^
  /a _build\desktop\Mosslet\bin\desktop.bat
```

## CI/CD

See `.github/workflows/desktop-build.yml` for automated builds.

### Required Secrets

| Secret | Platform | Purpose |
|--------|----------|---------|
| `APPLE_CERTIFICATE` | macOS | Base64-encoded .p12 certificate |
| `APPLE_CERTIFICATE_PASSWORD` | macOS | Certificate password |
| `APPLE_ID` | macOS | Apple ID email |
| `APPLE_TEAM_ID` | macOS | Developer Team ID |
| `APPLE_APP_PASSWORD` | macOS | App-specific password |
| `WINDOWS_CERTIFICATE` | Windows | Base64-encoded .pfx certificate |
| `WINDOWS_CERTIFICATE_PASSWORD` | Windows | Certificate password |

## Troubleshooting

### wxWidgets Not Found

If you see `wx` module errors, ensure Erlang was compiled with wxWidgets:

```bash
# Check wx support
erl -eval 'wx:demo()' -s init stop
```

If it fails, recompile Erlang with wx support.

### macOS Gatekeeper Issues

If users see "app is damaged" errors, ensure the app is properly notarized and the quarantine attribute is handled:

```bash
xattr -d com.apple.quarantine /Applications/Mosslet.app
```

### Linux AppImage Won't Start

Ensure FUSE is available:

```bash
sudo apt install fuse libfuse2
```

Or extract and run directly:

```bash
./Mosslet-X.X.X-x86_64.AppImage --appimage-extract
./squashfs-root/AppRun
```

## Distribution

### Direct Downloads

Host the artifacts on your website or CDN:
- `https://mosslet.com/downloads/Mosslet-X.X.X-macos.dmg`
- `https://mosslet.com/downloads/Mosslet-X.X.X-windows.zip`
- `https://mosslet.com/downloads/Mosslet-X.X.X-x86_64.AppImage`

### Auto-Updates

For auto-updates, consider:
- **macOS**: [Sparkle](https://sparkle-project.org/)
- **Windows**: Built-in update mechanism or [WinSparkle](https://winsparkle.org/)
- **Linux**: AppImage delta updates or Flatpak

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  MOSSLET Desktop                     │
├─────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────────────────────┐ │
│  │ wxWidgets   │    │     Phoenix LiveView        │ │
│  │ Native      │◄──►│     (localhost:4000)        │ │
│  │ Window      │    │                             │ │
│  └─────────────┘    └─────────────────────────────┘ │
│         │                        │                  │
│         ▼                        ▼                  │
│  ┌─────────────┐    ┌─────────────────────────────┐ │
│  │ Desktop.    │    │     API Client              │ │
│  │ Menu/Window │    │     (to mosslet.com)        │ │
│  └─────────────┘    └─────────────────────────────┘ │
│                              │                      │
│                              ▼                      │
│                     ┌─────────────────┐             │
│                     │  SQLite Cache   │             │
│                     │  (offline data) │             │
│                     └─────────────────┘             │
└─────────────────────────────────────────────────────┘
                           │
                           ▼ HTTPS
                  ┌─────────────────┐
                  │   mosslet.com   │
                  │   (Fly.io)      │
                  └─────────────────┘
```

The desktop app:
1. Starts an embedded Phoenix server on localhost
2. Opens a native window with an embedded WebView
3. Syncs data via API to the cloud server
4. Caches encrypted data locally in SQLite for offline use
5. All encryption happens on-device (zero-knowledge)
