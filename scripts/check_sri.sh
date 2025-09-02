#!/bin/bash

# Automated SRI check script
# Usage: ./scripts/check_sri.sh

set -e

echo "🔍 Checking if SRI hashes need updating..."

# Current hashes from your template
CURRENT_POPPER="TPh2Oxlg1zp+kz3nFA0C5vVC6leG/6mm1z9+mA81MI5eaUVqasPLO8Cuk4gMF4gUfP5etR73rgU/8PNMsSesoQ=="
CURRENT_TIPPY="gbruucq/Opx9jlHfqqZeAg2LNK3Y4BbpXHKDhRC88/tARL/izPOE4Zt2w6X9Sn1UeWaGbL38zW7nkL2jdn5JIw=="
CURRENT_TRIX_JS="2n5wEfDzQHss3krOoRqiF4Ogxc4Ktpa6y10JryWQMaUnZqbM8vUEAe6UDd0A21M7ad6ApLunCoT6s1sFmoriAg=="
CURRENT_TRIX_CSS="gO3Vi20RkuOMtPkY1eGHl9GA8upW48FIwrCYRabko2Sr8Zk7F5P6WVd3iPvSX3qo0F0ICfYdXYLPO6wQTk18FA=="
CURRENT_FATHOM="mwTWQRQd3HI0KKuUD9u+aVQRhZlOlv5ZbjGPDG3544cbqBM9j9SegCOCwxu/z2Gm7vio4OCDhHWg0WNawqfrJg=="

# Generate new hashes
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