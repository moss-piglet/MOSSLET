#!/bin/bash

# Script to generate SRI hashes for external, VERSION-PINNED resources.
# Usage: ./scripts/generate_sri.sh
#
# NOTE: Fathom (cdn.usefathom.com/script.js) is intentionally NOT included.
# It is a rolling, unversioned endpoint that Fathom updates without notice, so
# pinning it with SRI would break unpredictably. Only immutable, version-pinned
# URLs belong here.

set -euo pipefail

# Fetch a URL and emit its base64 sha512. Fails loudly (non-empty body required)
# so a network/DNS failure can never silently produce the empty-string hash
# (z4PhNX...SfaPg==) and poison the template.
sri() {
  local url="$1"
  local body
  body="$(curl -fsSL "$url")" || { echo "ERROR: failed to fetch $url" >&2; exit 1; }
  if [ -z "$body" ]; then
    echo "ERROR: empty body from $url" >&2
    exit 1
  fi
  printf 'sha512-%s\n' "$(printf '%s' "$body" | openssl dgst -sha512 -binary | openssl base64 -A)"
}

echo "Generating SRI hashes for external resources..."

echo ""
echo "Popper.js (versioned):"
sri "https://unpkg.com/@popperjs/core@2.11.8/dist/umd/popper.min.js"

echo ""
echo "Tippy.js (versioned):"
sri "https://unpkg.com/tippy.js@6.3.7/dist/tippy-bundle.umd.min.js"

echo ""
echo "Trix JS:"
sri "https://unpkg.com/trix@2.1.13/dist/trix.umd.min.js"

echo ""
echo "Trix CSS:"
sri "https://unpkg.com/trix@2.1.13/dist/trix.css"

echo ""
echo "Done! Update your head.html.heex template with these hashes if they've changed."
