/**
 * StatusFormHook — browser-side status message encryption (ZK write path).
 *
 * Intercepts the status form submit, encrypts the status_message with both
 * user_key (for the users table) and conn_key (for the connections table),
 * then pushes an `update_status_zk` event. The server stores only ciphertext.
 *
 * Only the status_message is encrypted — the status enum (calm, active, etc.)
 * and auto_status boolean remain plaintext (they are not sensitive).
 *
 * Falls back to normal form submit if encryption keys are unavailable.
 */
import {
  encryptWithKey,
  getUserKey,
  getConnKey,
  getPublicKey,
  getSealedUserKey,
  getSealedConnKey,
} from "../crypto/session";

const StatusFormHook = {
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
      window.addEventListener("mosslet:keys-ready", () => this._unsealKeys(), {
        once: true,
      });
      return;
    }

    const sealedUserKey = getSealedUserKey();
    const sealedConnKey = getSealedConnKey();

    try {
      if (sealedUserKey) this._userKey = await getUserKey(sealedUserKey);
      if (sealedConnKey) this._connKey = await getConnKey(sealedConnKey);
    } catch (e) {
      console.error("StatusFormHook: failed to unseal keys:", e);
    }
  },

  _onSubmit(e) {
    if (!this._userKey || !this._connKey) return;

    const statusMessage = this._getStatusMessage();
    if (statusMessage === null) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(statusMessage).catch((err) => {
      console.error("StatusFormHook: encryption failed, falling back:", err);
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  _getStatusMessage() {
    const input = this.el.querySelector(
      'input[name="user[status_message]"], input[name="status[status_message]"]',
    );
    if (!input) return null;
    return input.value;
  },

  async _encryptAndSubmit(statusMessage) {
    const status =
      this.el.querySelector(
        'input[name="user[status]"], input[name="status[status]"]',
      )?.value || "offline";
    const autoStatus =
      this.el.querySelector(
        'input[name="user[auto_status]"], input[name="status[auto_status]"]',
      )?.checked || false;

    let encUserMessage = null;
    let encConnMessage = null;

    if (statusMessage && statusMessage.trim() !== "") {
      [encUserMessage, encConnMessage] = await Promise.all([
        encryptWithKey(statusMessage, this._userKey),
        encryptWithKey(statusMessage, this._connKey),
      ]);
    }

    this.pushEvent("update_status_zk", {
      status: status,
      auto_status: autoStatus,
      encrypted_status_message: encUserMessage,
      c_encrypted_status_message: encConnMessage,
    });
  },
};

export default StatusFormHook;
