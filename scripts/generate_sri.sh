#!/bin/bash

# Script to generate SRI hashes for external resources
# Usage: ./scripts/generate_sri.sh

echo "Generating SRI hashes for external resources..."

echo ""
echo "Popper.js (versioned):"
echo -n "sha512-"
curl -s "https://unpkg.com/@popperjs/core@2.11.8/dist/umd/popper.min.js" | openssl dgst -sha512 -binary | openssl base64 -A
echo ""

echo ""
echo "Tippy.js (versioned):"
echo -n "sha512-"
curl -s "https://unpkg.com/tippy.js@6.3.7/dist/tippy-bundle.umd.min.js" | openssl dgst -sha512 -binary | openssl base64 -A
echo ""

echo ""
echo "Trix JS:"
echo -n "sha512-"
curl -s "https://unpkg.com/trix@2.1.13/dist/trix.umd.min.js" | openssl dgst -sha512 -binary | openssl base64 -A
echo ""

echo ""
echo "Trix CSS:"
echo -n "sha512-"
curl -s "https://unpkg.com/trix@2.1.13/dist/trix.css" | openssl dgst -sha512 -binary | openssl base64 -A
echo ""

echo ""
echo "Fathom Analytics:"
echo -n "sha512-"
curl -s "https://cdn.usefathom.com/script.js" | openssl dgst -sha512 -binary | openssl base64 -A
echo ""

echo ""
echo "Theme Toggle Script (inline):"
echo -n "sha512-"
echo -n '(() => {
        const setTheme = (theme) => {
          if (theme === "system") {
            localStorage.removeItem("phx:theme");
            document.documentElement.removeAttribute("data-theme");
          } else {
            localStorage.setItem("phx:theme", theme);
            document.documentElement.setAttribute("data-theme", theme);
          }
        };
        if (!document.documentElement.hasAttribute("data-theme")) {
          setTheme(localStorage.getItem("phx:theme") || "system");
        }
        window.addEventListener("storage", (e) => e.key === "phx:theme" && setTheme(e.newValue || "system"));
        
        window.addEventListener("phx:set-theme", (e) => setTheme(e.target.dataset.phxTheme));
      })();' | openssl dgst -sha512 -binary | openssl base64 -A
echo ""

echo ""
echo "Done! Update your head.html.heex template with these hashes if they've changed."