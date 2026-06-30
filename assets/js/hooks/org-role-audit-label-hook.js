/**
 * OrgRoleAuditLabel — precompute opaque org_key-encrypted AUDIT labels for the
 * two org-level roles (Task #353).
 *
 * Changing a teammate's ORG role ("Make admin" / "Make member") is a plain
 * `phx-click` with no plaintext to encrypt at click time. So on mount this hook
 * encrypts the two human-readable role names ("Admin", "Member") under the
 * org_key — the audit panel's read key — and pushes both ciphertexts to the
 * server, which caches them and attaches the matching one to the next
 * `role_changed` event. The activity log then reads "changed X's role to Admin".
 *
 * The role itself is non-sensitive (the server already stores `membership.role`),
 * but we keep the label channel uniform: every audit label is org_key ciphertext
 * the server can't read (invariant I6). Best-effort — if the org_key is
 * unavailable the log falls back to a generic "role was changed" phrase.
 *
 * Data attributes:
 *   data-sealed-org-key — base64 sealed org_key (per-user copy)
 */
import {
  unsealContextKey,
  getPublicKey,
  unwrapKey,
  encryptWithKey,
} from "../crypto/session";

const ROLE_LABELS = { admin: "Admin", member: "Member" };

const OrgRoleAuditLabel = {
  mounted() {
    this._run();
  },

  async _run() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._run(), {
        once: true,
      });
      return;
    }

    const sealedOrgKey = this.el.dataset.sealedOrgKey;
    if (!sealedOrgKey) return;

    try {
      const raw = await unsealContextKey(sealedOrgKey);
      if (!raw) return;
      const orgKey = unwrapKey(raw);

      const labels = {};
      for (const [role, name] of Object.entries(ROLE_LABELS)) {
        const label = await encryptWithKey(name, orgKey);
        if (label) labels[role] = label;
      }

      if (Object.keys(labels).length > 0) {
        this.pushEvent("cache_org_role_labels", { labels });
      }
    } catch (_e) {
      // best-effort — the log falls back to a generic role-change phrase
    }
  },
};

export default OrgRoleAuditLabel;
