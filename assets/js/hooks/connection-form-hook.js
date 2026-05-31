/**
 * ConnectionFormHook — browser-side label encryption for new connection creation (ZK write path).
 *
 * Intercepts the new connection form submit, encrypts the label with the user's
 * conn_key (from the SessionKeyDeriver cache), and pushes a "save_new_connection_zk"
 * event. The server stores only ciphertext — the plaintext label never arrives.
 *
 * The conn_key is the same symmetric key used for all connection-shared data.
 * It's sealed to the user's public key on `#session-key-deriver[data-sealed-conn-key]`
 * and cached by `getConnKey()` in session.js.
 *
 * Falls through to normal server-side form submit if:
 *   - Keys are not yet available (WASM not loaded, sessionStorage empty)
 *   - Encryption fails for any reason
 */
import { getConnKey, encryptWithKey } from "../crypto/session";

const ConnectionFormHook = {
  mounted() {
    this._connKey = null;
    this._resolveKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    if (!this._connKey) this._resolveKey();
  },

  async _resolveKey() {
    try {
      this._connKey = await getConnKey();
    } catch (e) {
      console.error("ConnectionFormHook: failed to get conn_key:", e);
    }

    if (!this._connKey) {
      window.addEventListener("mosslet:keys-ready", () => this._resolveKey(), {
        once: true,
      });
    }
  },

  _onSubmit(e) {
    if (!this._connKey) return;

    const labelInput = this.el.querySelector(
      'input[name="user_connection[temp_label]"]',
    );
    const label = labelInput?.value?.trim();
    if (!label) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(label).catch((err) => {
      console.error(
        "ConnectionFormHook: encryption failed, falling back:",
        err,
      );
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit(label) {
    const encryptedLabel = await encryptWithKey(label, this._connKey);

    const colorInput =
      this.el.querySelector('select[name="user_connection[color]"]') ||
      this.el.querySelector('input[name="user_connection[color]"]:checked');
    const color = colorInput?.value || "emerald";

    const selectorInput = this.el.querySelector(
      'select[name="user_connection[selector]"]',
    );
    const selector = selectorInput?.value || "";

    const emailInput = this.el.querySelector(
      'input[name="user_connection[email]"]',
    );
    const usernameInput = this.el.querySelector(
      'input[name="user_connection[username]"]',
    );

    this.pushEventTo(this.el, "save_new_connection_zk", {
      encrypted_label: encryptedLabel,
      label_blind_index: label.toLowerCase(),
      color: color,
      selector: selector,
      email: emailInput?.value?.trim() || "",
      username: usernameInput?.value?.trim() || "",
    });
  },
};

export default ConnectionFormHook;
