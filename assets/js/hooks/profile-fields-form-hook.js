/**
 * ProfileFieldsFormHook — browser-side profile field encryption (ZK write path).
 *
 * Intercepts name, username, and about form submits, encrypts the plaintext
 * value with both user_key and conn_key (dual-update pattern), and pushes
 * a ZK event with the ciphertext. The server stores only encrypted blobs.
 *
 * Attach to any form that submits user profile fields:
 *   phx-hook="ProfileFieldsFormHook"
 *   data-zk-event="update_name_zk"    (the event name to push)
 *   data-zk-field="name"              (the field name in the form)
 *
 * Optional: include non-encrypted form fields in the ZK payload:
 *   data-zk-extras="calm_notifications,email_notifications"
 *   Checkbox fields send true/false; text fields send their value.
 *
 * The hook reads the sealed user_key from #decrypt-user-fields and
 * the sealed conn_key from #session-key-deriver (both in app layout).
 */
import {
  encryptWithKey,
  getUserKey,
  getConnKey,
  getPublicKey,
  getSealedUserKey,
  getSealedConnKey,
} from "../crypto/session";

const ProfileFieldsFormHook = {
  mounted() {
    this._userKey = null;
    this._connKey = null;
    this._unsealKeys();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    if (!this._userKey || !this._connKey) this._unsealKeys();
  },

  async _unsealKeys() {
    if (!getPublicKey()) {
      window.addEventListener(
        "mosslet:keys-ready",
        () => this._unsealKeys(),
        { once: true },
      );
      return;
    }

    try {
      const sealedUserKey = getSealedUserKey();
      const sealedConnKey = getSealedConnKey();
      if (sealedUserKey) this._userKey = await getUserKey(sealedUserKey);
      if (sealedConnKey) this._connKey = await getConnKey(sealedConnKey);
    } catch (e) {
      console.error("ProfileFieldsFormHook: failed to unseal keys:", e);
    }
  },

  _onSubmit(e) {
    if (!this._userKey || !this._connKey) return;

    const zkEvent = this.el.dataset.zkEvent;
    const fieldName = this.el.dataset.zkField;
    if (!zkEvent || !fieldName) return;

    const input = this.el.querySelector(`[name="user[${fieldName}]"]`);
    const value = input?.value?.trim();
    if (!value) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndPush(zkEvent, fieldName, value).catch((err) => {
      console.error(
        "ProfileFieldsFormHook: encryption failed, falling back:",
        err,
      );
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  _collectExtras() {
    const raw = this.el.dataset.zkExtras;
    if (!raw) return {};
    const extras = {};
    for (const name of raw.split(",")) {
      const field = name.trim();
      if (!field) continue;
      const el = this.el.querySelector(`[name="user[${field}]"]`);
      if (!el) continue;
      extras[field] =
        el.type === "checkbox" ? el.checked : (el.value || "");
    }
    return extras;
  },

  async _encryptAndPush(eventName, fieldName, plaintext) {
    const [encUser, encConn] = await Promise.all([
      encryptWithKey(plaintext, this._userKey),
      encryptWithKey(plaintext, this._connKey),
    ]);

    const payload = {
      field: fieldName,
      encrypted_user: encUser,
      encrypted_conn: encConn,
      ...this._collectExtras(),
    };

    // Only username needs a blind-index pre-image (server uses it for
    // HMAC-SHA512 lookups and uniqueness). Other profile fields (name, about)
    // have no server-side search queries, so sending the plaintext would be
    // gratuitous ZK leakage.
    if (fieldName === "username") {
      payload.blind_index = plaintext.toLowerCase();
    }

    this.pushEvent(eventName, payload);
  },
};

export default ProfileFieldsFormHook;
