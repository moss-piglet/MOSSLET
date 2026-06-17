#!/bin/bash

# Automated SRI check script
# Usage: ./scripts/check_sri.sh
#
# Verifies the SRI hashes pinned in head.html.heex still match the remote,
# VERSION-PINNED resources. Fathom is intentionally excluded (rolling endpoint,
# not pinned with SRI).

set -euo pipefail

echo "🔍 Checking if SRI hashes need updating..."

# Extract current hashes from the template file
TEMPLATE_FILE="lib/mosslet_web/components/layouts/head.html.heex"

# Fetch a URL and emit its base64 sha512. Fails loudly (non-empty body required)
# so a network/DNS failure can never silently produce the empty-string hash and
# report a false "changed".
remote_hash() {
  local url="$1"
  local body
  body="$(curl -fsSL "$url")" || { echo "❌ Failed to fetch $url" >&2; exit 1; }
  if [ -z "$body" ]; then
    echo "❌ Empty body from $url" >&2
    exit 1
  fi
  printf '%s' "$body" | openssl dgst -sha512 -binary | openssl base64 -A
}

# Extract hashes using grep and sed
CURRENT_POPPER=$(grep -A 5 "@popperjs/core@2.11.8" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')
CURRENT_TIPPY=$(grep -A 5 "tippy.js@6.3.7" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')
CURRENT_TRIX_JS=$(grep -A 5 "trix@2.1.13/dist/trix.umd.min.js" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')
CURRENT_TRIX_CSS=$(grep -A 5 "trix@2.1.13/dist/trix.css" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')

# Validate that we extracted hashes (basic check)
if [[ -z "$CURRENT_POPPER" || -z "$CURRENT_TIPPY" || -z "$CURRENT_TRIX_JS" || -z "$CURRENT_TRIX_CSS" ]]; then
    echo "❌ Failed to extract current hashes from template file"
    echo "   Make sure $TEMPLATE_FILE exists and contains the expected script tags"
    exit 1
fi

# Generate new hashes from remote sources
NEW_POPPER=$(remote_hash "https://unpkg.com/@popperjs/core@2.11.8/dist/umd/popper.min.js")
NEW_TIPPY=$(remote_hash "https://unpkg.com/tippy.js@6.3.7/dist/tippy-bundle.umd.min.js")
NEW_TRIX_JS=$(remote_hash "https://unpkg.com/trix@2.1.13/dist/trix.umd.min.js")
NEW_TRIX_CSS=$(remote_hash "https://unpkg.com/trix@2.1.13/dist/trix.css")

changes_needed=false

# Check each hash
if [ "$CURRENT_POPPER" != "$NEW_POPPER" ]; then
    echo "❗ Popper.js hash changed!"
    echo "   Old: $CURRENT_POPPER"
    echo "   New: $NEW_POPPER"
    changes_needed=true
fi

if [ "$CURRENT_TIPPY" != "$NEW_TIPPY" ]; then
    echo "❗ Tippy.js hash changed!"
    echo "   Old: $CURRENT_TIPPY" 
    echo "   New: $NEW_TIPPY"
    changes_needed=true
fi

if [ "$CURRENT_TRIX_JS" != "$NEW_TRIX_JS" ]; then
    echo "❗ Trix JS hash changed!"
    echo "   Old: $CURRENT_TRIX_JS"
    echo "   New: $NEW_TRIX_JS"
    changes_needed=true
fi

if [ "$CURRENT_TRIX_CSS" != "$NEW_TRIX_CSS" ]; then
    echo "❗ Trix CSS hash changed!"
    echo "   Old: $CURRENT_TRIX_CSS"
    echo "   New: $NEW_TRIX_CSS"
    changes_needed=true
fi

if [ "$changes_needed" = true ]; then
    echo ""
    echo "🚨 SRI hashes need updating! Run ./scripts/generate_sri.sh"
    echo "   Then update lib/mosslet_web/components/layouts/head.html.heex"
    exit 1
else
    echo "✅ All SRI hashes are current!"
    exit 0
fi
