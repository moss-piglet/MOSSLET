/**
 * BlockReasonFormHook — browser-side block reason encryption (ZK write path).
 *
 * Intercepts the block form submit, encrypts the optional reason with the
 * user_key, sets a hidden field with the ciphertext, then re-dispatches
 * the submit so the LiveComponent's existing handler forwards it to the
 * parent LiveView. The parent detects `encrypted_reason` in the params
 * and calls the ZK block path instead of the server-side encryption path.
 *
 * The reason is encrypted with user_key only (not conn_key) — block reasons
 * are personal to the blocker.
 */
import {
  encryptWithKey,
  getUserKey,
  getPublicKey,
  getSealedUserKey,
} from "../crypto/session";

const BlockReasonFormHook = {
  mounted() {
    this._userKey = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    if (!this._userKey) this._unsealKey();
  },

  async _unsealKey() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), {
        once: true,
      });
      return;
    }

    try {
      const sealedUserKey = getSealedUserKey();
      if (sealedUserKey) this._userKey = await getUserKey(sealedUserKey);
    } catch (e) {
      console.error("BlockReasonFormHook: failed to unseal user key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._userKey) return;

    const reasonInput = this.el.querySelector('input[name="block[reason]"]');
    const reason = reasonInput?.value?.trim();
    if (!reason) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(reason, reasonInput).catch((err) => {
      console.error("BlockReasonFormHook: encryption failed, falling back:", err);
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit(reason, reasonInput) {
    const encryptedReason = await encryptWithKey(reason, this._userKey);

    let hiddenField = this.el.querySelector(
      'input[name="block[encrypted_reason]"]',
    );
    if (!hiddenField) {
      hiddenField = document.createElement("input");
      hiddenField.type = "hidden";
      hiddenField.name = "block[encrypted_reason]";
      this.el.appendChild(hiddenField);
    }
    hiddenField.value = encryptedReason;

    reasonInput.value = "";

    this.el.dispatchEvent(
      new Event("submit", { bubbles: true, cancelable: true }),
    );
  },
};

export default BlockReasonFormHook;
