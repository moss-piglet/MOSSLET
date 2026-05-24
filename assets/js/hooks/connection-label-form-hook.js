/**
 * ConnectionLabelFormHook — browser-side connection label encryption (ZK write path).
 *
 * Intercepts the edit connection label form submit, unseals the per-connection
 * key (uconn.key) from a data attribute, encrypts the label with that key,
 * and pushes a ZK event. The server stores only ciphertext.
 *
 * Data attributes on the form:
 *   data-sealed-uconn-key — base64 sealed per-connection key
 *
 * The per-connection key is specific to each user_connection record (sealed to
 * the user's public key), so it must be passed explicitly when the modal opens.
 */
import { unsealContextKey, getPublicKey, unwrapKey, encryptWithKey } from "../crypto/session";

const ConnectionLabelFormHook = {
  mounted() {
    this._uconnKey = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    const sealedKey = this.el.dataset.sealedUconnKey;
    if (sealedKey && !this._uconnKey) this._unsealKey();
  },

  async _unsealKey() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), {
        once: true,
      });
      return;
    }

    const sealedKey = this.el.dataset.sealedUconnKey;
    if (!sealedKey) return;

    try {
      const raw = await unsealContextKey(sealedKey);
      if (raw) this._uconnKey = unwrapKey(raw);
    } catch (e) {
      console.error("ConnectionLabelFormHook: failed to unseal uconn key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._uconnKey) return;

    const labelInput = this.el.querySelector('input[name="connection[label]"]');
    const label = labelInput?.value?.trim();
    if (!label) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(label).catch((err) => {
      console.error("ConnectionLabelFormHook: encryption failed, falling back:", err);
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit(label) {
    const encryptedLabel = await encryptWithKey(label, this._uconnKey);

    const colorInput = this.el.querySelector('input[name="connection[color]"]:checked');
    const color = colorInput?.value || "emerald";

    this.pushEvent("save_edit_connection_zk", {
      encrypted_label: encryptedLabel,
      label_hash: label.toLowerCase(),
      color: color,
    });
  },
};

export default ConnectionLabelFormHook;
