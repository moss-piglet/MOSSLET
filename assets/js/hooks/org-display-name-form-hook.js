/**
 * OrgDisplayNameFormHook — browser-side org display-name encryption (ZK write path, #225).
 *
 * The member sets their org-facing persona (e.g. "Mark — Engineering"). The hook
 * unseals the per-org `org_key` from the member's own `Membership.key`, encrypts
 * the typed name with it (secretbox), and pushes "save_org_display_name". The
 * server stores only ciphertext — it never sees the plaintext name.
 *
 * Validation (length/characters/expletives) is intentionally client-side: the
 * server only ever holds ciphertext, exactly like every other ZK name field.
 *
 * Data attributes on the form:
 *   data-sealed-org-key — base64 org_key sealed for this member (Membership.key)
 *
 * Input:  input[name="org_display_name[name]"]
 */
import {
  unsealContextKey,
  getPublicKey,
  unwrapKey,
  encryptWithKey,
} from "../crypto/session";

const MAX_LEN = 160;
const NAME_RE = /^[\p{L}\p{M}' \u2014\u2013.,&()-]+$/u;

const OrgDisplayNameFormHook = {
  mounted() {
    this._orgKey = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    if (!this._orgKey) this._unsealKey();
  },

  async _unsealKey() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), {
        once: true,
      });
      return;
    }

    const sealed = this.el.dataset.sealedOrgKey;
    if (!sealed) return;

    try {
      const raw = await unsealContextKey(sealed);
      if (raw) this._orgKey = unwrapKey(raw);
    } catch (e) {
      console.error("OrgDisplayNameFormHook: failed to unseal org key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._orgKey) return;

    const input = this.el.querySelector('input[name="org_display_name[name]"]');
    const name = input?.value?.trim();

    e.preventDefault();
    e.stopImmediatePropagation();

    if (!name || name.length > MAX_LEN || !NAME_RE.test(name)) {
      this._push("org_display_name_invalid", {});
      return;
    }

    this._encryptAndSubmit(name).catch((err) => {
      console.error("OrgDisplayNameFormHook: encryption failed:", err);
      this._push("org_display_name_invalid", {});
    });
  },

  async _encryptAndSubmit(name) {
    const encryptedName = await encryptWithKey(name, this._orgKey);
    if (!encryptedName) {
      this._push("org_display_name_invalid", {});
      return;
    }
    this._push("save_org_display_name", { encrypted_display_name: encryptedName });
  },

  _push(event, payload) {
    const target = this.el.getAttribute("phx-target");
    if (target) {
      this.pushEventTo(target, event, payload);
    } else {
      this.pushEvent(event, payload);
    }
  },
};

export default OrgDisplayNameFormHook;
