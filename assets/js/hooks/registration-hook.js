/**
 * RegistrationHook — browser-side key generation for new user registration.
 *
 * Intercepts the registration form submit to generate all cryptographic
 * key material in the browser via WASM before the form reaches the server.
 * The server receives only encrypted blobs and opaque ciphertext — it never
 * sees the raw user_key, user_attributes_key, conn_key, or private keys.
 *
 * What the browser generates:
 *   1. Salt (random 16 bytes)
 *   2. session_key = Argon2id(password, salt)
 *   3. user_key (random 32-byte symmetric key, encrypts private keys)
 *   4. user_attributes_key (random 32 bytes, encrypts personal data)
 *   5. conn_key (random 32 bytes, encrypts connection data)
 *   6. X25519 keypair (public + private)
 *   7. ML-KEM-768 hybrid PQ keypair (public + private)
 *
 * What the browser encrypts:
 *   - encrypted_private_key = secretbox(private_key, user_key)
 *   - encrypted_pq_private_key = secretbox(pq_private_key, user_key)
 *   - encrypted_user_attributes_key = sealForUser(user_attributes_key, public_key, pq_public_key)
 *   - encrypted_conn_key = sealForUser(conn_key, public_key, pq_public_key)
 *   - encrypted_email_user = secretbox(email, user_attributes_key)
 *   - encrypted_username_user = secretbox(username, user_attributes_key)
 *   - encrypted_email_conn = secretbox(email, conn_key)
 *   - encrypted_username_conn = secretbox(username, conn_key)
 *   - key_hash = salt + "$" + secretbox(user_key, session_key)
 *
 * What the server still sees (transiently):
 *   - Plaintext email (for confirmation email + HMAC blind index)
 *   - Plaintext username (for HMAC slug)
 *   - Password (for server-side Argon2 session auth hash)
 *
 * The server stores only encrypted blobs + public keys + HMAC hashes.
 *
 * If WASM fails to load or any crypto step errors, the form submits normally
 * and the server-side key generation path handles registration as before.
 * This is a progressive enhancement with graceful degradation.
 */

import {
  generateKey,
  generateKeyPair,
  generateSalt,
  generateHybridKeyPair,
  generateSigningKeyPair,
  deriveSessionKey,
  encryptSecretboxString,
  encryptPrivateKey,
  sealForUser,
  b64Decode,
} from "../crypto/nacl";

const TEMP_USER_KEY = "_mosslet_user_key_temp";

const RegistrationHook = {
  mounted() {
    const form = this.el;

    // The user-initiated submit MUST always be intercepted so that (a) the
    // browser generates ZK key material before anything reaches the server and
    // (b) the user is created via the "save" event BEFORE the native auto-login
    // POST fires. The auto-login POST itself is driven by the server setting
    // `phx-trigger-action`, which submits via HTMLFormElement.submit() and does
    // NOT dispatch a "submit" event — so it bypasses this listener cleanly.
    //
    // We listen in the CAPTURE phase and guard with a re-entrancy flag so a
    // stray/native submission can never race ahead of the encrypt+save step and
    // POST plaintext credentials to the session controller (which would create
    // no user and bounce the user to a misleading "invalid email or password").
    this.submitting = false;

    form.addEventListener(
      "submit",
      async (e) => {
        // Always stop the native submission of the user-clicked form.
        e.preventDefault();
        e.stopPropagation();

        if (this.submitting) return;
        this.submitting = true;

        const finish = () => {
          this.submitting = false;
        };

        const emailInput = form.querySelector('input[name="user[email]"]');
        const usernameInput = form.querySelector('input[name="user[username]"]');
        const passwordInput = form.querySelector('input[name="user[password]"]');

        // Required inputs missing/empty: do NOT silently native-submit plaintext.
        // Hand the (unencrypted) params to the LiveView "save" handler, which
        // re-validates and surfaces field errors to the user. The server never
        // creates a user from an invalid changeset, and no auto-login fires
        // because `trigger_submit` stays false.
        if (
          !emailInput ||
          !usernameInput ||
          !passwordInput ||
          !emailInput.value.trim() ||
          !usernameInput.value.trim() ||
          !passwordInput.value
        ) {
          this.pushEvent("save", { user: serializeUserFields(form) });
          finish();
          return;
        }

        const email = emailInput.value.trim();
        const username = usernameInput.value.trim();
        const password = passwordInput.value;

        try {
        // 1. Generate random symmetric keys
        const userKey = await generateKey();
        const userAttributesKey = await generateKey();
        const connKey = await generateKey();

        // 2. Derive session key from password + random salt
        const salt = await generateSalt();
        const sessionKey = await deriveSessionKey(password, salt);

        // 3. Build key_hash = salt$encrypted_user_key
        const encryptedUserKey = await encryptSecretboxString(userKey, sessionKey);
        const keyHash = salt + "$" + encryptedUserKey;

        // 4. Generate keypairs
        const keypair = await generateKeyPair();
        const pqKeypair = await generateHybridKeyPair();

        // 5. Encrypt private keys with user_key
        const encryptedPrivateKeyBlob = await encryptPrivateKey(keypair.privateKey, userKey);
        const encryptedPqPrivateKeyBlob = await encryptPrivateKey(pqKeypair.secretKey, userKey);

        // 5b. Generate the hybrid PQ SIGNING keypair (ML-DSA-87 + Ed25519, Cat-5)
        // for the signed key history (#290 step 4 / #315). The signing secret is
        // sealed under user_key exactly like the encryption private keys; the
        // genesis leaf itself is built later in the progressive/login path
        // (SessionKeyDeriver), so new + existing users share ONE genesis code
        // path. Best-effort: a signing-keygen failure must never block signup.
        let signingPublicKey = null;
        let encryptedSigningPrivateKeyBlob = null;
        try {
          const signingKeypair = await generateSigningKeyPair("cat5");
          signingPublicKey = signingKeypair.publicKey;
          encryptedSigningPrivateKeyBlob = await encryptSecretboxString(
            signingKeypair.secretKey,
            userKey,
          );
        } catch (sigErr) {
          console.warn("RegistrationHook: signing keypair generation failed (non-fatal):", sigErr);
        }

        // 6. Seal user_attributes_key and conn_key to the user's public key (hybrid PQ)
        const encryptedUserAttributesKey = await sealForUser(
          b64Decode(userAttributesKey),
          keypair.publicKey,
          pqKeypair.publicKey,
        );
        const encryptedConnKey = await sealForUser(
          b64Decode(connKey),
          keypair.publicKey,
          pqKeypair.publicKey,
        );

        // 7. Encrypt email and username with user_attributes_key (for User record)
        const encryptedEmailUser = await encryptSecretboxString(email, userAttributesKey);
        const encryptedUsernameUser = await encryptSecretboxString(username, userAttributesKey);

        // 8. Encrypt email and username with conn_key (for Connection record)
        const encryptedEmailConn = await encryptSecretboxString(email, connKey);
        const encryptedUsernameConn = await encryptSecretboxString(username, connKey);

        // 9. Store user_key in sessionStorage for SessionKeyDeriver to pick up
        sessionStorage.setItem(TEMP_USER_KEY, userKey);

        // 10. Inject encrypted blobs into hidden form fields
        setHidden(form, "user[zk_key_hash]", keyHash);
        setHidden(form, "user[zk_public_key]", keypair.publicKey);
        setHidden(form, "user[zk_encrypted_private_key]", encryptedPrivateKeyBlob);
        setHidden(form, "user[zk_pq_public_key]", pqKeypair.publicKey);
        setHidden(form, "user[zk_encrypted_pq_private_key]", encryptedPqPrivateKeyBlob);
        setHidden(form, "user[zk_encrypted_user_key]", encryptedUserAttributesKey);
        setHidden(form, "user[zk_encrypted_conn_key]", encryptedConnKey);
        setHidden(form, "user[zk_encrypted_email]", encryptedEmailUser);
        setHidden(form, "user[zk_encrypted_username]", encryptedUsernameUser);
        setHidden(form, "user[zk_c_encrypted_email]", encryptedEmailConn);
        setHidden(form, "user[zk_c_encrypted_username]", encryptedUsernameConn);

        // Hybrid PQ signing keypair (#315) — server passthrough is already wired
        // in User.extract_zk_params/1 + maybe_put_signing_keys/2.
        if (signingPublicKey && encryptedSigningPrivateKeyBlob) {
          setHidden(form, "user[zk_signing_public_key]", signingPublicKey);
          setHidden(
            form,
            "user[zk_encrypted_signing_private_key]",
            encryptedSigningPrivateKeyBlob,
          );
        }
      } catch (err) {
        // WASM not loaded or crypto failure — fall through to server-side path.
        // Clear any partial temp key to avoid confusion.
        console.warn("RegistrationHook: browser-side key generation failed, falling back to server:", err);
        sessionStorage.removeItem(TEMP_USER_KEY);
      }

      // Push the registration to the LiveView with the (now-injected) ZK fields.
      // We drive the "save" event from here — rather than relying on phx-submit —
      // so the server always receives the encrypted blobs. The server's "save"
      // handler creates the user and sets trigger_submit, which fires
      // phx-trigger-action to natively POST the form to /auth/sign_in.
        this.pushEvent("save", { user: serializeUserFields(form) });
        finish();
      },
      true,
    );
  },
};

// Serialize all `user[...]` inputs in the form into a flat map of field => value.
function serializeUserFields(form) {
  const data = {};
  const inputs = form.querySelectorAll('input[name^="user["], textarea[name^="user["]');
  inputs.forEach((input) => {
    const match = input.name.match(/^user\[([^\]]+)\]$/);
    if (!match) return;
    const field = match[1];
    if (input.type === "checkbox") {
      data[field] = input.checked;
    } else {
      data[field] = input.value;
    }
  });
  return data;
}

/**
 * Set (or create) a hidden input inside the form.
 */
function setHidden(form, name, value) {
  let input = form.querySelector(`input[name="${name}"]`);
  if (!input) {
    input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    form.appendChild(input);
  }
  input.value = value;
}

export default RegistrationHook;
