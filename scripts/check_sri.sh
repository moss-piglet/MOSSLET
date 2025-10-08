#!/bin/bash

# Automated SRI check script
# Usage: ./scripts/check_sri.sh

set -e

echo "🔍 Checking if SRI hashes need updating..."

# Extract current hashes from the template file
TEMPLATE_FILE="lib/mosslet_web/components/layouts/head.html.heex"

# Extract hashes using grep and sed
CURRENT_POPPER=$(grep -A 5 "@popperjs/core@2.11.8" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')
CURRENT_TIPPY=$(grep -A 5 "tippy.js@6.3.7" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')
CURRENT_TRIX_JS=$(grep -A 5 "trix@2.1.13/dist/trix.umd.min.js" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')
CURRENT_TRIX_CSS=$(grep -A 5 "trix@2.1.13/dist/trix.css" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')
CURRENT_FATHOM=$(grep -A 5 "cdn.usefathom.com" "$TEMPLATE_FILE" | grep "integrity=" | sed 's/.*sha512-\([^"]*\).*/\1/')

# Validate that we extracted hashes (basic check)
if [[ -z "$CURRENT_POPPER" || -z "$CURRENT_TIPPY" || -z "$CURRENT_TRIX_JS" || -z "$CURRENT_TRIX_CSS" || -z "$CURRENT_FATHOM" ]]; then
    echo "❌ Failed to extract current hashes from template file"
    echo "   Make sure $TEMPLATE_FILE exists and contains the expected script tags"
    exit 1
fi

# Generate new hashes from remote sources
NEW_POPPER=$(curl -s "https://unpkg.com/@popperjs/core@2.11.8/dist/umd/popper.min.js" | openssl dgst -sha512 -binary | openssl base64 -A)
NEW_TIPPY=$(curl -s "https://unpkg.com/tippy.js@6.3.7/dist/tippy-bundle.umd.min.js" | openssl dgst -sha512 -binary | openssl base64 -A)
NEW_TRIX_JS=$(curl -s "https://unpkg.com/trix@2.1.13/dist/trix.umd.min.js" | openssl dgst -sha512 -binary | openssl base64 -A)
NEW_TRIX_CSS=$(curl -s "https://unpkg.com/trix@2.1.13/dist/trix.css" | openssl dgst -sha512 -binary | openssl base64 -A)
NEW_FATHOM=$(curl -s "https://cdn.usefathom.com/script.js" | openssl dgst -sha512 -binary | openssl base64 -A)

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

if [ "$CURRENT_FATHOM" != "$NEW_FATHOM" ]; then
    echo "❗ Fathom Analytics hash changed!"
    echo "   Old: $CURRENT_FATHOM"
    echo "   New: $NEW_FATHOM"
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