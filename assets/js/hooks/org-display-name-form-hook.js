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
 * EDIT mode (Task #263): the SAME hook also drives the per-row "edit name" form.
 * Because every member's `Membership.key` unseals to the SAME `org_key`, an
 * admin/owner can decrypt + re-encrypt ANY member's display name (the server
 * still authorizes the write). When present:
 *   data-target-user-id        — the membership whose name is being edited; sent
 *                                back so the server stores it on the right row.
 *   data-current-encrypted-name — the existing ciphertext; decrypted on mount to
 *                                PREFILL the input so a rename (e.g. marriage)
 *                                starts from the current value.
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
  decryptWithKey,
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
      if (this._orgKey) this._prefill();
    } catch (e) {
      console.error("OrgDisplayNameFormHook: failed to unseal org key:", e);
    }
  },

  // EDIT mode: decrypt the current ciphertext (if any) and seed the input, but
  // only while it's still empty so we never clobber what the user is typing.
  async _prefill() {
    const current = this.el.dataset.currentEncryptedName;
    if (!current || !this._orgKey) return;

    const input = this.el.querySelector('input[name="org_display_name[name]"]');
    if (!input || input.value.trim()) return;

    try {
      const name = await decryptWithKey(current, this._orgKey);
      if (name && !input.value.trim()) {
        input.value = name;
        input.focus();
        input.setSelectionRange(name.length, name.length);
      }
    } catch (e) {
      console.error("OrgDisplayNameFormHook: failed to prefill name:", e);
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

    const payload = { encrypted_display_name: encryptedName };
    const targetUserId = this.el.dataset.targetUserId;
    if (targetUserId) payload.target_user_id = targetUserId;

    this._push("save_org_display_name", payload);
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
