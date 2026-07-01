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
 * Best-effort check that this browser can even attempt a WebAuthn ceremony with
 * a platform authenticator. Actual PRF support can only be confirmed after a
 * ceremony (via `getClientExtensionResults().prf`), so callers must always
 * treat PRF as a progressive enhancement and handle a `null` PRF result.
 *
 * @returns {Promise<boolean>}
 */
export async function isWebAuthnAvailable() {
  if (typeof window === "undefined") return false;
  if (!window.PublicKeyCredential) return false;
  if (typeof navigator === "undefined" || !navigator.credentials) return false;

  try {
    if (typeof PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable === "function") {
      return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    }
  } catch {
    return false;
  }
  // No platform-authenticator probe available; allow an attempt anyway.
  return true;
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
 * The effective relying-party id. Passkeys are scoped to this. Using the bare
 * host (no scheme/port) keeps a credential usable across the site.
 */
function defaultRpId() {
  return window.location.hostname;
}

/**
 * Create a new platform-authenticator credential with the PRF extension
 * enabled. We do NOT use this credential for server authentication (no
 * attestation ceremony) — it exists purely to hold a device-bound PRF. The
 * returned `credentialId` is opaque and later used to select this credential
 * in `evaluatePrf`.
 *
 * @param {object} opts
 * @param {string} opts.userId - a stable per-user id (e.g. the user uuid).
 * @param {string} opts.userName - display name (e.g. the account email).
 * @param {string} [opts.rpId] - relying-party id; defaults to the host.
 * @param {string} [opts.rpName] - relying-party display name.
 * @returns {Promise<{credentialIdB64: string, prfEnabled: boolean}>}
 */
export async function createPrfCredential({ userId, userName, rpId, rpName }) {
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
      residentKey: "preferred",
      requireResidentKey: false,
      userVerification: "required",
    },
    timeout: 60000,
    attestation: "none",
    extensions: { prf: {} },
  };

  const cred = await navigator.credentials.create({ publicKey });
  if (!cred) throw new Error("credential creation returned null");

  const ext = cred.getClientExtensionResults?.() || {};
  const prfEnabled = !!(ext.prf && ext.prf.enabled);

  return {
    credentialIdB64: b64Encode(new Uint8Array(cred.rawId)),
    prfEnabled,
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
