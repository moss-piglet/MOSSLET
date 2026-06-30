/**
 * CircleAuditLabel — precompute an opaque org_key-encrypted AUDIT label for the
 * circle currently being managed (Task #353).
 *
 * The manage panel's destructive/role actions (delete circle, change a member's
 * circle role) are plain `phx-click`s with no plaintext to encrypt at click
 * time, and on delete the circle name is gone afterwards. So on mount this hook
 * decrypts the circle name once (with the viewer's per-group key), re-encrypts
 * it under the org_key — the audit panel's read key — and pushes the resulting
 * ciphertext to the server, which caches it for the open circle and attaches it
 * to any `role_changed` / `circle_deleted` event. The plaintext name and the
 * raw keys NEVER reach the server (zero-knowledge, invariant I6).
 *
 * Best-effort: if either key is unavailable the panel still works; the activity
 * log just falls back to a generic label.
 *
 * Data attributes:
 *   data-sealed-group-key — base64 sealed group_key (per-user copy)
 *   data-sealed-org-key   — base64 sealed org_key (per-user copy)
 *   data-encrypted-name   — current ciphertext circle name (group_key secretbox)
 */
import {
  unsealContextKey,
  getPublicKey,
  unwrapKey,
  encryptWithKey,
  decryptWithKey,
} from "../crypto/session";

const CircleAuditLabel = {
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

    const sealedGroupKey = this.el.dataset.sealedGroupKey;
    const sealedOrgKey = this.el.dataset.sealedOrgKey;
    const encryptedName = this.el.dataset.encryptedName;
    if (!sealedGroupKey || !sealedOrgKey || !encryptedName) return;

    try {
      const rawGroup = await unsealContextKey(sealedGroupKey);
      if (!rawGroup) return;
      const name = await decryptWithKey(encryptedName, unwrapKey(rawGroup));
      if (!name) return;

      const rawOrg = await unsealContextKey(sealedOrgKey);
      if (!rawOrg) return;
      const label = await encryptWithKey(name, unwrapKey(rawOrg));
      if (label) this.pushEvent("cache_circle_audit_label", { label });
    } catch (_e) {
      // best-effort — leave the cache empty, the log falls back to generic text
    }
  },
};

export default CircleAuditLabel;
