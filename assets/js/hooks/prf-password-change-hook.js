/**
 * PrfPasswordChangeHook — re-wrap `:prf` wraps on a password change (board #368).
 *
 * See `docs/WEBAUTHN_PRF_DESIGN.md` §10a. `user_key` is IMMUTABLE across a
 * password change — only its wraps change. For PRF-enrolled accounts there is
 * no `:password` door by design (OR→AND flip), so the server must NOT re-derive
 * a password-only `key_hash`. Instead the browser re-wraps EACH `:prf` wrap
 * under the NEW password, using an enrolled device present at change time (the
 * same combine as unlock), and pushes only OPAQUE blobs (invariant I6 —
 * password, prf_output, and user_key never leave the browser).
 *
 * For each existing `:prf` wrap {id, credential_id, prf_salt, wrap_salt}:
 *   1. prf_output      = evaluatePrf(credential_id, prf_salt)   (device ceremony)
 *   2. new_password_key = Argon2id(new_password, wrap_salt)      (WASM KDF)
 *   3. wrapping_key     = combineSecrets(new_password_key, prf_output, wrap_salt)
 *   4. wrapped_user_key = secretbox(user_key, wrapping_key)
 *
 * We reuse `wrap_salt` and `prf_salt` unchanged, so ONLY `wrapped_user_key`
 * changes — the login-unlock path keeps working with the new password + device.
 *
 * The LiveView drives this: after validating the current password it pushes a
 * `prf_rewrap` event with the wrap params; we reply with `prf_rewrap_ready`
 * (opaque blobs) or `prf_rewrap_error` (mutate nothing server-side).
 */

import { deriveSessionKey } from "../crypto/nacl";
import { combineSecrets, evaluatePrf, wrapUserKey } from "../crypto/prf";
import { SK } from "./session-key-deriver";

function getUserKey() {
  return sessionStorage.getItem(SK.USER_KEY);
}

function getNewPassword(form) {
  const input = form.querySelector('input[name="user[password]"]');
  return input ? input.value : "";
}

const PrfPasswordChangeHook = {
  mounted() {
    this.handleEvent("prf_rewrap", async (payload) => {
      await this.rewrap(payload);
    });
  },

  async rewrap({ wraps }) {
    const userKey = getUserKey();
    if (!userKey) {
      return this.pushEvent("prf_rewrap_error", {
        error:
          "Your session keys aren't available in this browser. Please refresh and unlock, then try again.",
      });
    }

    const newPassword = getNewPassword(this.el);
    if (!newPassword) {
      return this.pushEvent("prf_rewrap_error", {
        error: "Please enter your new password.",
      });
    }

    if (!Array.isArray(wraps) || wraps.length === 0) {
      return this.pushEvent("prf_rewrap_error", {
        error: "No enrolled devices to re-wrap. Your account is unchanged.",
      });
    }

    try {
      const rewraps = [];

      for (const wrap of wraps) {
        const prfOutput = await evaluatePrf({
          credentialIdB64: wrap.credential_id,
          prfSaltB64: wrap.prf_salt,
        });

        if (!prfOutput) {
          return this.pushEvent("prf_rewrap_error", {
            error:
              "Couldn't confirm your enrolled device. Password unchanged. If you don't have your device, reset your password with your recovery key instead.",
          });
        }

        const newPasswordKey = await deriveSessionKey(newPassword, wrap.wrap_salt);
        const wrappingKey = await combineSecrets(newPasswordKey, prfOutput, wrap.wrap_salt);
        const wrappedUserKey = await wrapUserKey(userKey, wrappingKey);

        rewraps.push({ id: wrap.id, wrapped_user_key: wrappedUserKey });
      }

      this.pushEvent("prf_rewrap_ready", { rewraps });
    } catch (err) {
      console.error("PrfPasswordChangeHook: rewrap failed:", err);
      this.pushEvent("prf_rewrap_error", {
        error: rewrapErrorMessage(err),
      });
    }
  },
};

function rewrapErrorMessage(err) {
  if (err && (err.name === "NotAllowedError" || err.name === "AbortError")) {
    return "Device confirmation was cancelled. Your password is unchanged.";
  }
  return "Couldn't re-secure your account for the new password. Your password is unchanged.";
}

export default PrfPasswordChangeHook;
