/**
 * WebAuthn PRF — device-bound wrapping factor for `user_key` (board #362/#365).
 *
 * See `docs/WEBAUTHN_PRF_DESIGN.md`. This module is the client "~10%" that
 * combines a password-derived key with a WebAuthn PRF output into ONE wrapping
 * key with auditable domain separation, plus the capability detection and
 * `navigator.credentials` glue needed to enroll a device and evaluate its PRF.
 *
 * Invariant I6: `prf_output`, `password`, and `user_key` NEVER leave the
 * browser. Only the opaque `wrapped_user_key` (and its public parameters:
 * `wrap_salt`, `prf_salt`, `credential_id`) are ever persisted.
 *
 * The combine is RFC 5869 HKDF-SHA512 (Extract-then-Expand, HMAC-SHA-2) over
 *   ikm  = password_key ‖ prf_output
 *   salt = wrap_salt      (Extract)
 *   info = WRAP_INFO      (Expand, domain separation)
 *   L    = 32             (XSalsa20-Poly1305 secretbox key, no truncation)
 * It reuses the same audited Rust crate (metamorphic-crypto) that powers both
 * the browser WASM and the server NIF, so there is no bespoke crypto here.
 */

import {
  hkdfSha512,
  encryptSecretboxString,
  decryptSecretboxToString,
  generateSalt,
  b64Encode,
  b64Decode,
} from "./nacl";

/**
 * Versioned domain-separation label for the wrap combine. Bumping this string
 * changes the derived wrapping key for every account, so it is a hard version
 * boundary — treat it as append-only.
 */
export const WRAP_INFO = "mosslet/user_key-wrap/v1";

const PRF_KEY_BYTES = 32;

// ---------------------------------------------------------------------------
// combineSecrets — RFC 5869 HKDF-SHA512 combine (Extract-then-Expand)
// ---------------------------------------------------------------------------

/**
 * Combine a password-derived key and a PRF output into a single 32-byte
 * secretbox wrapping key via RFC 5869 HKDF-SHA512, with domain separation.
 *
 * Deterministic: identical (passwordKey, prfOutput, wrapSalt) always yields the
 * identical wrapping key — this is what makes unlock reproducible across
 * sessions and synced-passkey copies within one ecosystem.
 *
 *   wrapping_key = HKDF-SHA512(
 *     salt = wrap_salt,                        # Extract
 *     ikm  = password_key ‖ prf_output,
 *     info = WRAP_INFO,                         # Expand (domain separation)
 *     L    = 32,
 *   )
 *
 * @param {string} passwordKeyB64 - base64 Argon2id(password, wrap_salt) output.
 * @param {string} prfOutputB64 - base64 WebAuthn PRF output (32 bytes).
 * @param {string} wrapSaltB64 - base64 per-wrap salt (also the KDF salt).
 * @returns {Promise<string>} base64 32-byte secretbox wrapping key.
 */
export async function combineSecrets(passwordKeyB64, prfOutputB64, wrapSaltB64) {
  if (!passwordKeyB64 || !prfOutputB64 || !wrapSaltB64) {
    throw new Error("combineSecrets: all of wrap_salt, password_key, prf_output are required");
  }

  const passwordKey = b64Decode(passwordKeyB64);
  const prfOutput = b64Decode(prfOutputB64);

  const ikm = new Uint8Array(passwordKey.length + prfOutput.length);
  ikm.set(passwordKey, 0);
  ikm.set(prfOutput, passwordKey.length);

  return hkdfSha512(wrapSaltB64, b64Encode(ikm), WRAP_INFO, PRF_KEY_BYTES);
}

// ---------------------------------------------------------------------------
// wrap / unwrap — secretbox of the user_key string under the wrapping key
// ---------------------------------------------------------------------------

/**
 * Wrap the user_key under a combined (password ‖ prf) wrapping key.
 *
 * Mirrors the legacy `key_hash` shape: the user_key is a base64 string and is
 * sealed with secretbox, so unwrap yields the identical string the rest of the
 * app already expects in sessionStorage.
 *
 * @param {string} userKeyB64 - the user_key (base64 string, as in sessionStorage).
 * @param {string} wrappingKeyB64 - base64 wrapping key from combineSecrets.
 * @returns {Promise<string>} base64 secretbox ciphertext (the opaque wrap).
 */
export async function wrapUserKey(userKeyB64, wrappingKeyB64) {
  return encryptSecretboxString(userKeyB64, wrappingKeyB64);
}

/**
 * Unwrap the user_key from an opaque `wrapped_user_key` blob.
 *
 * @param {string} wrappedUserKeyB64 - base64 secretbox ciphertext.
 * @param {string} wrappingKeyB64 - base64 wrapping key from combineSecrets.
 * @returns {Promise<string>} the recovered user_key (base64 string).
 */
export async function unwrapUserKey(wrappedUserKeyB64, wrappingKeyB64) {
  return decryptSecretboxToString(wrappedUserKeyB64, wrappingKeyB64);
}

// ---------------------------------------------------------------------------
// Capability detection
// ---------------------------------------------------------------------------

/**
 * Best-effort check that this browser can even attempt a WebAuthn ceremony.
 * This intentionally does NOT require a platform authenticator — cross-platform
 * providers (1Password and other passkey managers, a phone via hybrid, or a
 * security key) are valid too. Actual PRF support can only be confirmed after a
 * ceremony (via `getClientExtensionResults().prf`), so callers must always
 * treat PRF as a progressive enhancement and handle a `null` PRF result.
 *
 * @returns {Promise<boolean>}
 */
export async function isWebAuthnAvailable() {
  if (typeof window === "undefined") return false;
  if (!window.PublicKeyCredential) return false;
  if (typeof navigator === "undefined" || !navigator.credentials) return false;
  return true;
}

/**
 * Proactive capability report for the settings UI. Unlike `isWebAuthnAvailable`
 * (a single boolean used at ceremony time), this returns a structured status so
 * the page can message honestly *before* the user clicks — "why can't I enable
 * this here?" — without ever promising PRF (which can only be confirmed after a
 * ceremony; callers still handle a null PRF result as a fallback).
 *
 * @returns {Promise<{status: "available"|"unavailable", reason: string|null}>}
 *   reason ∈ "no_webauthn" | "cross_platform_only" | null.
 */
export async function detectPrfCapability() {
  if (
    typeof window === "undefined" ||
    !window.PublicKeyCredential ||
    typeof navigator === "undefined" ||
    !navigator.credentials
  ) {
    return { status: "unavailable", reason: "no_webauthn" };
  }

  // A missing PLATFORM authenticator (Touch ID / Face ID / Windows Hello) is NOT
  // a blocker: cross-platform passkey providers — 1Password and other managers,
  // a phone via hybrid transport, or a security key — can still create a
  // PRF-capable credential. So we only hard-block when WebAuthn is entirely
  // absent; otherwise we allow the attempt, optionally with an advisory hint.
  try {
    if (typeof PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable === "function") {
      const platform = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
      return platform
        ? { status: "available", reason: null }
        : { status: "available", reason: "cross_platform_only" };
    }
  } catch {
    // Probe threw — WebAuthn is present, so still allow an attempt.
    return { status: "available", reason: "cross_platform_only" };
  }

  // WebAuthn present but no platform-authenticator probe — allow an attempt.
  return { status: "available", reason: null };
}

// ---------------------------------------------------------------------------
// WebAuthn ceremony glue
// ---------------------------------------------------------------------------

function randomBytes(n) {
  const b = new Uint8Array(n);
  crypto.getRandomValues(b);
  return b;
}

/**
 * The effective relying-party id. Passkeys are scoped to this.
 *
 * We use the app's registrable BASE domain (from the server-rendered
 * `<meta name="webauthn-rp-id">`, e.g. `mosslet.com` in prod / `localhost` in
 * dev) rather than the bare request host. A credential's rpId must be equal to,
 * or a registrable parent of, the current origin's host — the base domain holds
 * for the apex AND every branded org subdomain (`acme.mosslet.com`), so a
 * passkey enrolled once works everywhere in the app. Falling back to the bare
 * hostname keeps this safe if the meta tag is ever absent. Any accidental
 * `:port` is stripped (rpId is a domain, never host:port).
 */
function defaultRpId() {
  const meta = document.querySelector('meta[name="webauthn-rp-id"]');
  const configured = meta && meta.content ? meta.content.trim() : "";
  const host = configured || window.location.hostname;
  return host.split(":")[0];
}

/**
 * Create a new platform-authenticator credential with the PRF extension
 * enabled. We do NOT use this credential for server authentication (no
 * attestation ceremony) — it exists purely to hold a device-bound PRF. The
 * returned `credentialId` is opaque and later used to select this credential
 * in `evaluatePrf`.
 *
 * When `prfSaltB64` is supplied we ALSO request a PRF evaluation at creation
 * time (`extensions.prf.eval.first`). Authenticators that support create-time
 * PRF (Chrome/Edge, Safari 18+, most synced-passkey providers, 1Password)
 * return the PRF output directly from `create()`, so the caller can skip the
 * separate "obtain" `get()` — saving one biometric prompt during enrollment.
 * When unsupported, `prfOutputB64` is `null` and the caller falls back to a
 * follow-up `get()` via `evaluatePrf`. This is purely a UX optimization; it
 * never changes the stored wrap (the PRF output is deterministic per salt).
 *
 * @param {object} opts
 * @param {string} opts.userId - a stable per-user id (e.g. the user uuid).
 * @param {string} opts.userName - display name (e.g. the account email).
 * @param {string} [opts.prfSaltB64] - base64 per-credential PRF eval salt; when
 *   present, PRF is evaluated at creation time (progressive — may return null).
 * @param {string} [opts.rpId] - relying-party id; defaults to the host.
 * @param {string} [opts.rpName] - relying-party display name.
 * @returns {Promise<{credentialIdB64: string, prfEnabled: boolean, prfOutputB64: string|null}>}
 */
export async function createPrfCredential({ userId, userName, prfSaltB64, rpId, rpName }) {
  const prfExt = prfSaltB64
    ? { prf: { eval: { first: b64Decode(prfSaltB64) } } }
    : { prf: {} };

  const publicKey = {
    challenge: randomBytes(32),
    rp: { id: rpId || defaultRpId(), name: rpName || "Mosslet" },
    user: {
      id: new TextEncoder().encode(userId),
      name: userName,
      displayName: userName,
    },
    pubKeyCredParams: [
      { type: "public-key", alg: -7 }, // ES256
      { type: "public-key", alg: -257 }, // RS256
    ],
    authenticatorSelection: {
      // No `authenticatorAttachment` → both platform authenticators (Touch ID,
      // Face ID, Windows Hello) AND cross-platform providers (1Password, phones
      // via hybrid, security keys) are eligible.
      //
      // `residentKey: "required"` requests a DISCOVERABLE passkey. This matters
      // for provider choice on macOS/iOS: with "preferred", Safari shortcuts
      // straight to iCloud Keychain and never surfaces third-party passkey
      // managers; with "required" the system sheet offers ALL installed
      // providers (1Password, etc.). Discoverable is also what a passkey is
      // supposed to be, and it enables cross-device/hybrid use later. Our unlock
      // path always passes `allowCredentials`, so discoverability is orthogonal
      // to how we evaluate the PRF.
      residentKey: "required",
      requireResidentKey: true,
      userVerification: "required",
    },
    timeout: 60000,
    attestation: "none",
    extensions: prfExt,
  };

  const cred = await navigator.credentials.create({ publicKey });
  if (!cred) throw new Error("credential creation returned null");

  const ext = cred.getClientExtensionResults?.() || {};
  const prfEnabled = !!(ext.prf && ext.prf.enabled);

  // Create-time PRF output, when the authenticator supports it. Shape mirrors
  // the get()-time result (`ext.prf.results.first` is an ArrayBuffer).
  const createTimeFirst = ext.prf && ext.prf.results && ext.prf.results.first;
  const prfOutputB64 = createTimeFirst
    ? b64Encode(new Uint8Array(createTimeFirst))
    : null;

  return {
    credentialIdB64: b64Encode(new Uint8Array(cred.rawId)),
    prfEnabled,
    prfOutputB64,
  };
}

/**
 * Evaluate the PRF for an enrolled credential, returning the raw PRF output.
 *
 * @param {object} opts
 * @param {string} opts.credentialIdB64 - base64 credential id from enrollment.
 * @param {string} opts.prfSaltB64 - base64 per-credential PRF eval salt.
 * @param {string} [opts.rpId] - relying-party id; defaults to the host.
 * @returns {Promise<string|null>} base64 PRF output (32 bytes), or null if the
 *   authenticator did not return a PRF result (PRF unsupported → fall back).
 */
export async function evaluatePrf({ credentialIdB64, prfSaltB64, rpId }) {
  const publicKey = {
    challenge: randomBytes(32),
    rpId: rpId || defaultRpId(),
    allowCredentials: [
      { type: "public-key", id: b64Decode(credentialIdB64) },
    ],
    userVerification: "required",
    timeout: 60000,
    extensions: { prf: { eval: { first: b64Decode(prfSaltB64) } } },
  };

  const assertion = await navigator.credentials.get({ publicKey });
  if (!assertion) return null;

  const ext = assertion.getClientExtensionResults?.() || {};
  const first = ext.prf && ext.prf.results && ext.prf.results.first;
  if (!first) return null;

  return b64Encode(new Uint8Array(first));
}

/**
 * Generate a fresh base64 salt (reuses the WASM CSPRNG). Used for both the
 * per-wrap KDF salt and the per-credential PRF eval salt.
 * @returns {Promise<string>} base64 salt.
 */
export async function freshSalt() {
  return generateSalt();
}
