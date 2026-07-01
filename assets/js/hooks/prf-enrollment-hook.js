/**
 * PrfEnrollmentHook — browser-side WebAuthn PRF enroll / un-enroll (board #365).
 *
 * Mounted on the "Device unlock" settings card. It performs the client "~10%"
 * of the PRF flow and pushes only OPAQUE blobs to the server (invariant I6 —
 * password, prf_output, and user_key never leave the browser):
 *
 *   ENROLL (OR → AND flip):
 *     1. Read the current user_key from sessionStorage (SessionKeyDeriver).
 *     2. Read the just-entered password from the confirm input.
 *     3. Generate fresh wrap_salt + prf_salt.
 *     4. Create a platform-authenticator credential with the PRF extension.
 *     5. Evaluate the PRF (get) → prf_output.
 *     6. password_key = Argon2id(password, wrap_salt);
 *        wrapping_key = combineSecrets(password_key, prf_output, wrap_salt).
 *     7. wrapped_user_key = secretbox(user_key, wrapping_key).
 *     8. VERIFY-BEFORE-DELETE (anti-brick, design §8): do a SECOND PRF get()
 *        with the SAME prf_salt, re-derive the wrapping key, and assert
 *        unwrap(wrapped_user_key) === user_key. This proves the credential
 *        DETERMINISTICALLY reproduces the PRF across ceremonies (the real
 *        unlock path) BEFORE we ask the server to delete the password door.
 *     9. Only on a proven round-trip: pushEvent("prf_enrolled", { opaque blobs })
 *        — server inserts the :prf wrap and deletes the :password wrap. If the
 *        proof fails, pushEvent("prf_error") and mutate NOTHING server-side.
 *
 *   UN-ENROLL (AND → OR restore, no bricking):
 *     Re-materialize a password-only wrap on-device and push it so the server
 *     can restore the plain password door when removing the last device.
 *
 * Everything is a progressive enhancement: capability gaps, user cancellation,
 * or a missing PRF result surface a friendly error and change nothing.
 */

import { deriveSessionKey, encryptSecretboxString } from "../crypto/nacl";
import {
  isWebAuthnAvailable,
  createPrfCredential,
  evaluatePrf,
  combineSecrets,
  wrapUserKey,
  unwrapUserKey,
  freshSalt,
} from "../crypto/prf";
import { SK } from "./session-key-deriver";

function getUserKey() {
  return sessionStorage.getItem(SK.USER_KEY);
}

function getPasswordInput(el) {
  return el.querySelector('input[name="prf_password"]');
}

const PrfEnrollmentHook = {
  mounted() {
    this.handleEvent("prf_enroll", async (payload) => {
      await this.enroll(payload);
    });

    this.handleEvent("prf_unenroll", async (payload) => {
      await this.unenroll(payload);
    });
  },

  async enroll({ user_id, user_name }) {
    const userKey = getUserKey();
    if (!userKey) {
      return this.pushEvent("prf_error", {
        error: "Session keys not available. Please refresh the page and try again.",
      });
    }

    const passwordInput = getPasswordInput(this.el);
    const password = passwordInput ? passwordInput.value : "";
    if (!password) {
      return this.pushEvent("prf_error", {
        error: "Please enter your password to confirm enrollment.",
      });
    }

    if (!(await isWebAuthnAvailable())) {
      return this.pushEvent("prf_error", {
        error: "This device or browser does not support a platform passkey.",
      });
    }

    try {
      const wrapSalt = await freshSalt();
      const prfSalt = await freshSalt();

      const { credentialIdB64, prfEnabled } = await createPrfCredential({
        userId: user_id,
        userName: user_name,
      });

      const prfOutput = await evaluatePrf({
        credentialIdB64,
        prfSaltB64: prfSalt,
      });

      if (!prfOutput) {
        return this.pushEvent("prf_error", {
          error:
            "Your authenticator does not support the PRF extension, so device unlock can't be enabled here. Your account is unchanged.",
        });
      }

      const passwordKey = await deriveSessionKey(password, wrapSalt);
      const wrappingKey = await combineSecrets(passwordKey, prfOutput, wrapSalt);
      const wrappedUserKey = await wrapUserKey(userKey, wrappingKey);

      // Verify-before-delete (anti-brick, design §8): prove the credential
      // deterministically reproduces the PRF across a SECOND ceremony — the
      // real unlock path — and that the freshly-written wrap actually recovers
      // user_key, BEFORE the server deletes the password door. The server
      // cannot check this (I6: it holds no keys), so the proof MUST be here.
      const prfOutput2 = await evaluatePrf({
        credentialIdB64,
        prfSaltB64: prfSalt,
      });

      if (!prfOutput2) {
        if (passwordInput) passwordInput.value = "";
        return this.pushEvent("prf_error", {
          error:
            "Could not confirm this device reproduces its passkey. Your account is unchanged.",
        });
      }

      const wrappingKey2 = await combineSecrets(passwordKey, prfOutput2, wrapSalt);
      const recoveredUserKey = await unwrapUserKey(wrappedUserKey, wrappingKey2);

      if (recoveredUserKey !== userKey) {
        if (passwordInput) passwordInput.value = "";
        return this.pushEvent("prf_error", {
          error:
            "This device did not reproduce its passkey consistently, so device unlock can't be enabled here. Your account is unchanged.",
        });
      }

      if (passwordInput) passwordInput.value = "";

      this.pushEvent("prf_enrolled", {
        wrapped_user_key: wrappedUserKey,
        wrap_salt: wrapSalt,
        credential_id: credentialIdB64,
        prf_salt: prfSalt,
        ecosystem_hint: detectEcosystemHint(),
        prf_enabled: prfEnabled,
      });
    } catch (err) {
      if (passwordInput) passwordInput.value = "";
      console.error("PrfEnrollmentHook: enroll failed:", err);
      this.pushEvent("prf_error", {
        error: enrollErrorMessage(err),
      });
    }
  },

  async unenroll({ wrap_id, last_device }) {
    // Removing a non-last device needs no password wrap — server keeps the
    // account enrolled. Only the last device must re-materialize the password
    // door so the user is never bricked.
    if (!last_device) {
      return this.pushEvent("prf_unenrolled", { wrap_id });
    }

    const userKey = getUserKey();
    if (!userKey) {
      return this.pushEvent("prf_error", {
        error: "Session keys not available. Please refresh the page and try again.",
      });
    }

    const passwordInput = getPasswordInput(this.el);
    const password = passwordInput ? passwordInput.value : "";
    if (!password) {
      return this.pushEvent("prf_error", {
        error: "Please enter your password to remove this device.",
      });
    }

    try {
      const wrapSalt = await freshSalt();
      const passwordKey = await deriveSessionKey(password, wrapSalt);
      const wrappedUserKey = await encryptSecretboxString(userKey, passwordKey);

      if (passwordInput) passwordInput.value = "";

      this.pushEvent("prf_unenrolled", {
        wrap_id,
        wrapped_user_key: wrappedUserKey,
        wrap_salt: wrapSalt,
      });
    } catch (err) {
      if (passwordInput) passwordInput.value = "";
      console.error("PrfEnrollmentHook: unenroll failed:", err);
      this.pushEvent("prf_error", {
        error: "Failed to remove the device. Please try again.",
      });
    }
  },
};

/** Best-effort, non-authoritative ecosystem hint from the user agent. */
function detectEcosystemHint() {
  const ua = (navigator.userAgent || "").toLowerCase();
  if (/iphone|ipad|macintosh|mac os/.test(ua)) return "apple";
  if (/android/.test(ua)) return "google";
  return "cross-platform";
}

function enrollErrorMessage(err) {
  if (err && (err.name === "NotAllowedError" || err.name === "AbortError")) {
    return "Enrollment was cancelled. Your account is unchanged.";
  }
  return "Could not enroll this device. Your account is unchanged.";
}

export default PrfEnrollmentHook;
