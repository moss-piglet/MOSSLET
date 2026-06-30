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
import { unsealContextKey, unwrapKey, encryptWithKey } from "../crypto/session";

const ROLE_LABELS = { admin: "Admin", member: "Member" };

const OrgRoleAuditLabel = {
  mounted() {
    this._cached = false;
    // `mosslet:keys-ready` fires only AFTER the private key is derived (see
    // session-key-deriver.js). We must gate on THAT, not on `getPublicKey()` —
    // the public key is stored early (before the private key), so a
    // public-key-only "ready" check would let `unsealContextKey` below fail
    // silently with no retry, leaving the org role labels uncached (the audit
    // log then drops to a generic "changed X's role" phrase). We always listen
    // and retry until we successfully cache once (idempotent via `_cached`).
    this._onKeysReady = () => this._run();
    window.addEventListener("mosslet:keys-ready", this._onKeysReady);
    this._run();
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  async _run() {
    if (this._cached) return;

    const sealedOrgKey = this.el.dataset.sealedOrgKey;
    if (!sealedOrgKey) return;

    try {
      const raw = await unsealContextKey(sealedOrgKey);
      // Keys not ready yet (private key still deriving) — the keys-ready
      // listener will retry.
      if (!raw) return;
      const orgKey = unwrapKey(raw);

      const labels = {};
      for (const [role, name] of Object.entries(ROLE_LABELS)) {
        const label = await encryptWithKey(name, orgKey);
        if (label) labels[role] = label;
      }

      if (Object.keys(labels).length > 0) {
        this.pushEvent("cache_org_role_labels", { labels });
        this._cached = true;
      }
    } catch (_e) {
      // best-effort — the log falls back to a generic role-change phrase
    }
  },
};

export default OrgRoleAuditLabel;
