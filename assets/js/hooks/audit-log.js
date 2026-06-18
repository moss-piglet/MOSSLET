/**
 * AuditLog — ZK admin activity log rendering + export (Task #212, §12 of
 * docs/BUSINESS_CIRCLES_DESIGN.md).
 *
 * Option B (metadata-only): the server stores only opaque ids + a non-sensitive
 * action category + timestamp. This hook reconstructs the human-readable
 * description CLIENT-SIDE from data the viewing admin already holds keys for —
 * specifically each teammate's org `display_name`, decrypted with the per-org
 * `org_key` (the same key the OrgMembers roster uses). The plaintext names never
 * reach the server.
 *
 * The hook element (the audit section) carries:
 *   data-sealed-org-key   — the viewer's Membership.key (org_key sealed for them)
 *   data-member-directory — JSON [{id, name}] where name is the org_key-encrypted
 *                           display-name ciphertext for each org member
 *
 * Each row carries:
 *   data-audit-row
 *   data-audit-action       — category ("role_changed", "file_shared", …)
 *   data-audit-actor-id     — who performed it
 *   data-audit-target-id    — polymorphic target (may be empty)
 *   data-audit-target-type  — "user" | "group" | "shared_file" | ""
 *   data-audit-at           — ISO timestamp (naive UTC)
 *   [data-audit-text]       — element filled with the enriched description
 *
 * "Download" (a [data-audit-export] button) exports a local CSV copy assembled
 * from the rendered rows — useful day-to-day and as the owner's final snapshot
 * before deleting the org (after which the log is permanently cascade-deleted).
 */
import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";

const AuditLog = {
  mounted() {
    this._orgKey = null;
    this._names = {};
    // Delegated click: the export button is conditionally rendered and may be
    // patched in/out, so listen on the (stable) hook root rather than the button.
    this._exportHandler = (e) => {
      if (e.target.closest("[data-audit-export]")) {
        e.preventDefault();
        this._export();
      }
    };
    this.el.addEventListener("click", this._exportHandler);

    // Allow other parts of the page (e.g. the delete-org modal's "download a copy
    // first" button) to trigger the export via JS.dispatch to this element.
    this._dispatchExport = () => this._export();
    this.el.addEventListener("mosslet:export-audit-log", this._dispatchExport);

    this._run();
  },

  updated() {
    // New rows may have been streamed in (realtime refresh) — re-render.
    this._rendered = false;
    this._run();
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
    if (this._exportHandler) {
      this.el.removeEventListener("click", this._exportHandler);
    }
    if (this._dispatchExport) {
      this.el.removeEventListener("mosslet:export-audit-log", this._dispatchExport);
    }
  },

  async _run() {
    if (!getPublicKey()) {
      if (!this._onKeysReady) {
        this._onKeysReady = () => this._run();
        window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });
      }
      return;
    }

    await this._ensureOrgKey();
    await this._buildNameMap();
    this._renderRows();
  },

  async _ensureOrgKey() {
    if (this._orgKey) return this._orgKey;
    const sealed = this.el.dataset.sealedOrgKey;
    if (sealed) {
      const raw = await unsealContextKey(sealed);
      if (raw) this._orgKey = unwrapKey(raw);
    }
    return this._orgKey;
  },

  // Decrypt every member's display-name ciphertext with the org_key into an
  // id -> name map. Best-effort: unresolved ids fall back to a generic label.
  // Rebuilds whenever the member directory changes (e.g. a teammate sets/updates
  // their org display name, patched in live via {:org_updated}) so the feed
  // reflects "Jaybo joined" instead of "A former teammate" without a refresh.
  async _buildNameMap() {
    const orgKey = this._orgKey;
    if (!orgKey) return;

    const raw = this.el.dataset.memberDirectory || "[]";
    if (this._namesBuilt && raw === this._directoryRaw) return;

    let directory = [];
    try {
      directory = JSON.parse(raw);
    } catch (_e) {
      directory = [];
    }

    const names = {};
    for (const member of directory) {
      if (!member.id || !member.name) continue;
      const name = await decryptWithKey(member.name, orgKey);
      if (name) names[member.id] = name;
    }
    this._names = names;
    this._namesBuilt = true;
    this._directoryRaw = raw;
  },

  _renderRows() {
    if (this._rendered) return;
    const rows = this.el.querySelectorAll("[data-audit-row]");
    for (const row of rows) {
      const target = row.querySelector("[data-audit-text]");
      if (target) target.textContent = this._describe(row.dataset);
      this._renderLocalTime(row);
    }
    this._rendered = true;
  },

  // Show the viewer's LOCAL time next to the (server-rendered) UTC time. The
  // stored timestamp is naive UTC, so append "Z" before parsing.
  _renderLocalTime(row) {
    const el = row.querySelector("[data-audit-local]");
    const at = row.dataset.auditAt;
    if (!el || !at) return;

    const date = new Date(/[zZ]|[+-]\d{2}:?\d{2}$/.test(at) ? at : at + "Z");
    if (isNaN(date.getTime())) return;

    const local = date.toLocaleString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    el.textContent = `· ${local} local`;
    el.classList.remove("hidden");
  },

  _describe(d) {
    const actor = this._names[d.auditActorId] || "A former teammate";
    const targetName =
      d.auditTargetType === "user" ? this._names[d.auditTargetId] || "a former teammate" : null;

    switch (d.auditAction) {
      case "member_invited":
        return `${actor} invited a new teammate`;
      case "member_added":
        return `${actor} joined the organization`;
      case "member_removed":
        return `${actor} removed ${targetName} from the organization`;
      case "role_changed":
        return `${actor} changed ${targetName}'s role`;
      case "circle_created":
        return `${actor} created a circle`;
      case "file_shared":
        return `${actor} shared a file`;
      case "file_revoked":
        return `${actor} removed a file`;
      default:
        return `${actor} performed an action`;
    }
  },

  _export() {
    const rows = this.el.querySelectorAll("[data-audit-row]");
    const lines = [["timestamp_utc", "action", "description"]];

    rows.forEach((row) => {
      const text = (row.querySelector("[data-audit-text]")?.textContent || "").trim();
      lines.push([row.dataset.auditAt || "", row.dataset.auditAction || "", text]);
    });

    const csv = lines.map((cols) => cols.map((c) => this._csvCell(c)).join(",")).join("\r\n");
    const stamp = new Date().toISOString().slice(0, 10);

    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `activity-log-${stamp}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  },

  _csvCell(value) {
    const s = String(value ?? "");
    if (/[",\r\n]/.test(s)) {
      return `"${s.replace(/"/g, '""')}"`;
    }
    return s;
  },
};

export default AuditLog;
