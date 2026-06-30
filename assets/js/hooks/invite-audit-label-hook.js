/**
 * InviteAuditLabel — attach an opaque org_key-encrypted AUDIT label (the invited
 * email) to the "invite teammate" submit (Task #353).
 *
 * A `member_invited` event's target is a NOT-YET member, so the audit panel's
 * member directory can't resolve a name. To still give admins useful insight
 * ("invited teammate@example.com"), this hook intercepts the form submit,
 * encrypts the typed email under the org_key — the audit panel's read key — and
 * pushes `invite_member` carrying the opaque `encrypted_label`.
 *
 * The email is necessarily known to the server (it sends the invitation), so
 * this isn't about hiding it — it keeps the audit label channel uniform: every
 * label is org_key ciphertext the server treats as opaque (invariant I6).
 *
 * Best-effort: if the org_key isn't sealed for the viewer, the invite still
 * goes through (without a label) and the log falls back to a generic phrase.
 *
 * Data attributes on the form:
 *   data-sealed-org-key — base64 sealed org_key (per-user copy)
 */
import {
  unsealContextKey,
  getPublicKey,
  unwrapKey,
  encryptWithKey,
} from "../crypto/session";

const InviteAuditLabel = {
  mounted() {
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  _emailInput() {
    return this.el.querySelector('input[name="invite[email]"]');
  },

  _onSubmit(e) {
    const sealedOrgKey = this.el.dataset.sealedOrgKey;
    const email = this._emailInput()?.value?.trim() || "";
    if (!sealedOrgKey || !email || !getPublicKey()) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndInvite(email).catch((err) => {
      console.error("InviteAuditLabel: failed, inviting without label:", err);
      this.pushEvent("invite_member", { invite: { email } });
    });
  },

  async _encryptAndInvite(email) {
    let label = null;
    try {
      const raw = await unsealContextKey(this.el.dataset.sealedOrgKey);
      if (raw) label = await encryptWithKey(email, unwrapKey(raw));
    } catch (_e) {
      label = null;
    }

    this.pushEvent("invite_member", {
      invite: { email },
      encrypted_label: label,
    });
  },
};

export default InviteAuditLabel;
