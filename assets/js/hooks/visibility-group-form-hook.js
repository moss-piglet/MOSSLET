/**
 * VisibilityGroupFormHook — browser-side encryption for visibility group creation/edit (ZK write path).
 *
 * Intercepts the visibility group form submit, encrypts name and description
 * with the user's user_key, and pushes a "save_visibility_group_zk" event.
 * The server stores only ciphertext — plaintext name/description never arrive.
 *
 * The conn_key is the same symmetric key used for all connection-shared data.
 * It's cached by `getConnKey()` from the `#session-key-deriver[data-sealed-conn-key]` attr.
 *
 * Falls through to normal server-side form submit if:
 *   - Keys are not yet available (WASM not loaded, sessionStorage empty)
 *   - Encryption fails for any reason
 */
import {
  getUserKey,
  getSealedUserKey,
  encryptWithKey,
} from "../crypto/session";

const VisibilityGroupFormHook = {
  mounted() {
    this._userKey = null;
    this._resolveKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    if (!this._userKey) this._resolveKey();
  },

  async _resolveKey() {
    try {
      const sealed = getSealedUserKey();
      if (sealed) {
        this._userKey = await getUserKey(sealed);
      }
    } catch (e) {
      console.error("VisibilityGroupFormHook: failed to get user_key:", e);
    }

    if (!this._userKey) {
      window.addEventListener("mosslet:keys-ready", () => this._resolveKey(), {
        once: true,
      });
    }
  },

  _onSubmit(e) {
    if (!this._userKey) return;

    const nameInput = this.el.querySelector(
      'input[name="visibility_group[name]"]',
    );
    const name = nameInput?.value?.trim();
    if (!name) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(name).catch((err) => {
      console.error(
        "VisibilityGroupFormHook: encryption failed, falling back:",
        err,
      );
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit(name) {
    const encryptedName = await encryptWithKey(name, this._userKey);

    const descInput = this.el.querySelector(
      'textarea[name="visibility_group[description]"]',
    );
    const description = descInput?.value?.trim() || "";
    const encryptedDescription = description
      ? await encryptWithKey(description, this._userKey)
      : "";

    const idInput = this.el.querySelector(
      'input[name="visibility_group[id]"]',
    );
    const groupId = idInput?.value || null;

    const colorInputs = this.el.querySelectorAll(
      'input[name="visibility_group[color]"]',
    );
    let color = "purple";
    for (const input of colorInputs) {
      if (input.checked) {
        color = input.value;
        break;
      }
    }

    const connectionIdInputs = this.el.querySelectorAll(
      'input[name="visibility_group[connection_ids][]"]:checked',
    );
    const connectionIds = Array.from(connectionIdInputs).map((i) => i.value);

    this.pushEventTo(this.el, "save_visibility_group_zk", {
      id: groupId,
      encrypted_name: encryptedName,
      encrypted_description: encryptedDescription,
      color: color,
      connection_ids: connectionIds,
    });
  },
};

export default VisibilityGroupFormHook;
