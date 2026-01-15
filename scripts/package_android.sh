#!/bin/bash
# Package Elixir release for Android
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RELEASE_DIR="$PROJECT_ROOT/_build/native_prod/rel/mobile"
ANDROID_APP_DIR="$PROJECT_ROOT/native/android/app"
ANDROID_ASSETS_DIR="$ANDROID_APP_DIR/src/main/assets"
ANDROID_REL_DIR="$ANDROID_ASSETS_DIR/rel"

echo "Packaging Elixir release for Android..."

if [ ! -d "$RELEASE_DIR" ]; then
    echo "Error: Release not found at $RELEASE_DIR"
    echo "Run 'MIX_TARGET=native MIX_ENV=prod mix release mobile' first"
    exit 1
fi

rm -rf "$ANDROID_REL_DIR"
mkdir -p "$ANDROID_REL_DIR"

cp -R "$RELEASE_DIR/lib" "$ANDROID_REL_DIR/"
cp -R "$RELEASE_DIR/releases" "$ANDROID_REL_DIR/"

mkdir -p "$ANDROID_REL_DIR/priv/static"
if [ -d "$PROJECT_ROOT/priv/static" ]; then
    cp -R "$PROJECT_ROOT/priv/static/"* "$ANDROID_REL_DIR/priv/static/"
fi

cat > "$ANDROID_REL_DIR/vm.args" << 'EOF'
-mode embedded
-sname mosslet
+Bd
+sbwt none
+sbwtdcpu none
+sbwtdio none
-kernel inet_dist_use_interface {127,0,0,1}
-kernel prevent_overlapping_partitions false
EOF

echo "Android release packaged at: $ANDROID_REL_DIR"
echo ""
echo "Contents:"
du -sh "$ANDROID_REL_DIR"/*

echo ""
echo "Checking JNI libraries..."
for ABI in arm64-v8a armeabi-v7a x86_64; do
    JNI_DIR="$ANDROID_APP_DIR/src/main/jniLibs/$ABI"
    if [ -d "$JNI_DIR" ]; then
        echo "  $ABI: $(ls "$JNI_DIR" | wc -l) libraries"
    else
        echo "  $ABI: NOT FOUND"
    fi
done
