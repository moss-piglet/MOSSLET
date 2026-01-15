#!/bin/bash
# Package Elixir release for iOS
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RELEASE_DIR="$PROJECT_ROOT/_build/native_prod/rel/mobile"
IOS_APP_DIR="$PROJECT_ROOT/native/ios/Mosslet"
IOS_REL_DIR="$IOS_APP_DIR/rel"

echo "Packaging Elixir release for iOS..."

if [ ! -d "$RELEASE_DIR" ]; then
    echo "Error: Release not found at $RELEASE_DIR"
    echo "Run 'MIX_TARGET=native MIX_ENV=prod mix release mobile' first"
    exit 1
fi

rm -rf "$IOS_REL_DIR"
mkdir -p "$IOS_REL_DIR"

cp -R "$RELEASE_DIR/lib" "$IOS_REL_DIR/"
cp -R "$RELEASE_DIR/releases" "$IOS_REL_DIR/"

if [ -d "$RELEASE_DIR/erts-"* ]; then
    cp -R "$RELEASE_DIR/erts-"* "$IOS_REL_DIR/"
fi

mkdir -p "$IOS_REL_DIR/priv/static"
if [ -d "$PROJECT_ROOT/priv/static" ]; then
    cp -R "$PROJECT_ROOT/priv/static/"* "$IOS_REL_DIR/priv/static/"
fi

cat > "$IOS_REL_DIR/vm.args" << 'EOF'
-mode embedded
-sname mosslet
+Bd
+sbwt none
+sbwtdcpu none
+sbwtdio none
-kernel inet_dist_use_interface {127,0,0,1}
-kernel prevent_overlapping_partitions false
EOF

echo "iOS release packaged at: $IOS_REL_DIR"
echo ""
echo "Contents:"
du -sh "$IOS_REL_DIR"/*
