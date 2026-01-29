#!/bin/bash
# Upload desktop release artifacts to Tigris storage
#
# Usage:
#   ./scripts/upload_release.sh           # Upload version from mix.exs
#   ./scripts/upload_release.sh 0.17.0    # Upload specific version
#
# Prerequisites:
#   1. Create the Tigris bucket (one-time):
#      fly storage create --name mosslet-releases --public
#
#   2. Set local environment variables in .envrc:
#      export RELEASES_BUCKET="mosslet-releases"
#      (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_HOST should already be set)
#
#   3. Set production secrets:
#      fly secrets set RELEASES_BUCKET=mosslet-releases

set -e

VERSION=${1:-$(grep 'version:' mix.exs | head -1 | sed 's/.*"\(.*\)".*/\1/')}
BUILD_DIR="_build/desktop"

echo "🚀 MOSSLET Release Upload"
echo "   Version: $VERSION"
echo ""

if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build directory not found: $BUILD_DIR"
    echo "   Run ./scripts/build_desktop.sh first"
    exit 1
fi

# Check for required env vars
if [ -z "$RELEASES_BUCKET" ]; then
    echo "❌ RELEASES_BUCKET environment variable not set"
    echo "   Add to .envrc: export RELEASES_BUCKET=\"mosslet-releases\""
    exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "❌ AWS_ACCESS_KEY_ID environment variable not set"
    exit 1
fi

# Run the Mix task
mix release.upload --version "$VERSION" --dir "$BUILD_DIR"

echo ""
echo "✅ Release upload complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Test downloads at https://$RELEASES_BUCKET.fly.storage.tigris.dev/v$VERSION/"
echo "   2. Update @version in lib/mosslet_web/live/public_live/download.ex if needed"
echo "   3. Deploy: fly deploy"
