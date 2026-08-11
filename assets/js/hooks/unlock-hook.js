/**
 * UnlockHook — pre-submit key derivation on the unlock session form.
 *
 * Same pattern as LoginHook but for the session unlock page. When a user's
 * session is restored via remember_me cookie but lacks the encryption key,
 * they're redirected to /auth/unlock to re-enter their password.
 *
 * The key_hash is provided as a data attribute on the form element
 * (it's not secret — it's salt$encrypted_user_key, only decryptable with
 * the correct password via Argon2id KDF).
 *
 * Flow:
 *   1. User submits the unlock form (button click)
 *   2. The hook intercepts (preventDefault) and derives/unwraps user_key from
 *      key_hash + password (non-enrolled) or KDF(password‖prf) (enrolled)
 *   3. Stores user_key in sessionStorage as temp key
 *   4. Fills the hidden `unlock[user_key]` field (enrolled) and submits the
 *      form NATIVELY to the controller (like LoginHook)
 *   5. Controller fills the session key and redirects
 *   6. SessionKeyDeriver picks up the temp key on next authenticated page
 *
 * The form intentionally has NO `phx-submit`: a LiveView `phx-submit` fires
 * regardless of the hook's `preventDefault`, which raced the async PRF ceremony
 * and POSTed an empty `user_key` (false "Invalid password" for enrolled users).
 * The hook owns submission end-to-end instead.
 *
 * If WASM fails or derivation errors, the flow continues without browser keys.
 * Server-side unlock still works — browser crypto just won't be available
 * until next full login.
 */

import {
  deriveSessionKey,
  decryptSecretboxToString,
} from "../crypto/nacl";

import { cacheKeys } from "../crypto/key_cache";
import { decryptPrivateKey } from "../crypto/nacl";
import { combineSecrets, evaluatePrf, unwrapUserKey } from "../crypto/prf";

const TEMP_USER_KEY = "_mosslet_user_key_temp";

// Loop guard set by SessionKeyDeriver before redirecting a keyless session
// here. Reaching this page means the redirect succeeded, so we clear it: the
// guard is meant to prevent a redirect *loop*, not to permanently latch the
// user out of future unlock attempts if this round-trip fails or is abandoned.
const REDIRECT_FLAG = "_mosslet_unlock_redirect";

const UnlockHook = {
  mounted() {
    const form = this.el;

    sessionStorage.removeItem(REDIRECT_FLAG);

    // iOS PWA keyboard fix: opening the virtual keyboard shrinks the VISUAL
    // viewport but not the layout viewport (100dvh is unchanged), so a card
    // that exactly fits the screen leaves the page with no scroll range and
    // the submit button gets trapped under the keyboard. Mirroring the visual
    // viewport height into --unlock-vh (consumed by the page container's
    // min-h) shrinks the container while the keyboard is open, the card
    // overflows, and the button can be scrolled into view.
    this._onViewportResize = () => {
      const height = window.visualViewport
        ? window.visualViewport.height
        : window.innerHeight;
      document.documentElement.style.setProperty(
        "--unlock-vh",
        `${Math.round(height)}px`,
      );
    };
    this._onViewportResize();
    if (window.visualViewport) {
      window.visualViewport.addEventListener("resize", this._onViewportResize);
    } else {
      window.addEventListener("resize", this._onViewportResize);
    }

    form.addEventListener("submit", async (e) => {
      e.preventDefault();

      const passwordInput = form.querySelector('input[name="unlock[password]"]');
      const password = passwordInput ? passwordInput.value : "";

      // Enrolled-account unlock (board #370) MUST be checked FIRST: enrolled
      // accounts have NO `key_hash` password-only door (it's retired on enroll),
      // so the `data-key-hash` attr is empty. Checking the key_hash guard first
      // would short-circuit and POST the bare password — a false "Invalid
      // password". Unlock via PRF instead (password AND enrolled device). On
      // success we hand the server the decrypted session-key string via a hidden
      // `unlock[user_key]` field; the controller trusts it only for enrolled
      // accounts. We NEVER fall back to a password-only door here.
      const prf = parsePrf(form.dataset.prf);
      if (prf.enrolled && prf.wraps.length > 0) {
        if (!password) {
          // Empty password — let the required field / server surface the error.
          form.submit();
          return;
        }

        const restoreButton = setSubmitBusy(form, "Confirming with your device…");
        const result = await tryPrfUnlock(prf.wraps, password);
        if (result) {
          sessionStorage.setItem(TEMP_USER_KEY, result.userKey);
          setUserKeyField(form, result.userKey);
          setWrapIdField(form, result.wrapId);
          // Submit the form DIRECTLY (native submit, like LoginHook). A native
          // submit POSTs immediately with the hidden fields intact; the
          // controller trusts unlock[user_key] only for enrolled accounts.
          form.submit();
          return;
        }
        restoreButton();
        // PRF unlock didn't succeed on this device. This is either a wrong
        // password OR a device whose passkey isn't enrolled / can't produce the
        // PRF (a different ecosystem, a not-yet-enrolled phone, or 1Password
        // declining). There is NO password-only door for enrolled accounts, so
        // posting the password would only yield a misleading "Invalid password".
        // Surface honest guidance instead and reveal the recovery-key unlock.
        this.pushEvent("prf_unlock_unavailable", {});
        return;
      }

      // Non-enrolled password path: requires a usable `key_hash`
      // (salt$encrypted_user_key). Without it, submit natively and let the
      // controller verify the password server-side.
      const keyHash = form.dataset.keyHash;
      if (!passwordInput || !password || !keyHash || !keyHash.includes("$")) {
        form.submit();
        return;
      }

      try {
        const dollarIndex = keyHash.indexOf("$");
        const salt = keyHash.substring(0, dollarIndex);
        const encryptedUserKey = keyHash.substring(dollarIndex + 1);

        const sessionKey = await deriveSessionKey(password, salt);
        const userKey = await decryptSecretboxToString(encryptedUserKey, sessionKey);

        // Store for SessionKeyDeriver to pick up after redirect
        sessionStorage.setItem(TEMP_USER_KEY, userKey);

        // Also try to populate the persistent cache immediately so
        // future browser sessions don't require re-entry
        try {
          const encPk = form.dataset.encryptedPrivateKey;
          if (encPk) {
            const privateKey = await decryptPrivateKey(encPk, userKey);
            let pqPrivateKey = null;
            const encPqPk = form.dataset.encryptedPqPrivateKey;
            if (encPqPk) {
              pqPrivateKey = await decryptSecretboxToString(encPqPk, userKey);
            }
            await cacheKeys({ userKey, privateKey, pqPrivateKey });
          }
        } catch {
          // Non-fatal — SessionKeyDeriver will handle caching on next page
        }
      } catch {
        // Derivation failed (wrong password, WASM issue) — fall through
        sessionStorage.removeItem(TEMP_USER_KEY);
      }

      // Let the server verify the password and fill the session (native submit,
      // like LoginHook). The derived user_key is already in sessionStorage for
      // SessionKeyDeriver to pick up after the redirect.
      form.submit();
    });
  },

  destroyed() {
    if (window.visualViewport) {
      window.visualViewport.removeEventListener(
        "resize",
        this._onViewportResize,
      );
    } else {
      window.removeEventListener("resize", this._onViewportResize);
    }
    document.documentElement.style.removeProperty("--unlock-vh");
  },
};

export default UnlockHook;

function parsePrf(raw) {
  if (!raw) return { enrolled: false, wraps: [] };
  try {
    const parsed = JSON.parse(raw);
    return {
      enrolled: !!parsed.enrolled,
      wraps: Array.isArray(parsed.wraps) ? parsed.wraps : [],
    };
  } catch {
    return { enrolled: false, wraps: [] };
  }
}

/**
 * Attempt to unlock user_key from one of the enrolled :prf wraps by evaluating
 * the device PRF and combining it with the password-derived key. Returns
 * `{ userKey, wrapId }` for the wrap that unlocked, or null if no enrolled
 * device can unlock here.
 */
async function tryPrfUnlock(wraps, password) {
  for (const wrap of wraps) {
    try {
      const prfOutput = await evaluatePrf({
        credentialIdB64: wrap.credential_id,
        prfSaltB64: wrap.prf_salt,
      });
      if (!prfOutput) continue;

      const passwordKey = await deriveSessionKey(password, wrap.wrap_salt);
      const wrappingKey = await combineSecrets(passwordKey, prfOutput, wrap.wrap_salt);
      const userKey = await unwrapUserKey(wrap.wrapped_user_key, wrappingKey);
      if (userKey) return { userKey, wrapId: wrap.id || "" };
    } catch {
      // Wrong device / wrong password / cancelled — try the next wrap.
    }
  }
  return null;
}

function setUserKeyField(form, userKey) {
  let input = form.querySelector('input[name="unlock[user_key]"]');
  if (!input) {
    input = document.createElement("input");
    input.type = "hidden";
    input.name = "unlock[user_key]";
    form.appendChild(input);
  }
  input.value = userKey;
}

function setWrapIdField(form, wrapId) {
  if (!wrapId) return;
  let input = form.querySelector('input[name="unlock[wrap_id]"]');
  if (!input) {
    input = document.createElement("input");
    input.type = "hidden";
    input.name = "unlock[wrap_id]";
    form.appendChild(input);
  }
  input.value = wrapId;
}

/**
 * Put the submit button into a busy state while the device PRF ceremony runs,
 * so the user understands a Face ID / Touch ID / security-key prompt is coming
 * (and can't double-submit). Returns a function that restores the original
 * label/enabled state (call it if the ceremony fails and we stay on the page).
 */
function setSubmitBusy(form, label) {
  const button = form.querySelector('button[type="submit"]');
  if (!button) return () => {};

  const originalHtml = button.innerHTML;
  const wasDisabled = button.disabled;
  button.disabled = true;
  button.setAttribute("aria-busy", "true");
  button.textContent = label;

  return () => {
    button.disabled = wasDisabled;
    button.removeAttribute("aria-busy");
    button.innerHTML = originalHtml;
  };
}
