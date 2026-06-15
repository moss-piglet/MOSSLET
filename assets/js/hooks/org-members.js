/**
 * OrgMembers — org-scoped ZK display-name read + key-sealing (Task #225).
 *
 * Renders the org member roster under zero-knowledge: every member holds the
 * same per-org `org_key` (sealed to them in `Membership.key`), encrypts an
 * org-facing `display_name` with it, and can therefore decrypt every other
 * member's display name WITHOUT a personal UserConnection. The raw `org_key`
 * and plaintext display names never reach the server.
 *
 * Mirrors DecryptGroupMetadata (read) + GroupMetadataFormHook Phase-2 (seal).
 *
 * The hook element (the roster wrapper) carries:
 *   data-sealed-org-key   — the VIEWER's Membership.key (org_key sealed for them),
 *                            or "" when not yet sealed for the viewer.
 *   data-can-bootstrap     — "true" when the viewer is the org owner AND nobody
 *                            holds the org_key yet (lazy bootstrap, design Q1=A).
 *
 * Each roster row carries:
 *   data-org-member-row             — marker
 *   data-encrypted-display-name     — ciphertext (org_key secretbox), or "" if unset
 *   [data-decrypt-org-name]         — element to fill with the decrypted name
 *
 * Server events:
 *   "seal_org_key_for_members" -> payload.members = [{user_id, public_key, pq_public_key}]
 *      The server (server-authoritative recipient set) asks us to seal the
 *      org_key for members who don't have it yet. We seal + push "finalize_org_key".
 *   "bootstrap_org_key"        -> we are the owner and must generate the org_key,
 *      seal our own copy, and push "finalize_org_key" with just our entry.
 */
import {
  unsealContextKey,
  decryptWithKey,
  getPublicKey,
  getPqPublicKey,
  unwrapKey,
} from "../crypto/session";
import { generateKey, sealForUser, b64Decode } from "../crypto/nacl";

const OrgMembers = {
  mounted() {
    this._orgKey = null;

    this.handleEvent("seal_org_key_for_members", (payload) =>
      this._sealForMembers(payload),
    );
    this.handleEvent("bootstrap_org_key", () => this._bootstrap());

    this._run();
  },

  updated() {
    this._decrypted = false;
    this._run();
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  async _run() {
    if (!getPublicKey()) {
      if (!this._onKeysReady) {
        this._onKeysReady = () => this._run();
        window.addEventListener("mosslet:keys-ready", this._onKeysReady, {
          once: true,
        });
      }
      return;
    }

    await this._ensureOrgKey();
    await this._decryptRoster();
  },

  // Resolve the viewer's raw org_key (cached for the page lifetime of this hook).
  async _ensureOrgKey() {
    if (this._orgKey) return this._orgKey;

    const sealed = this.el.dataset.sealedOrgKey;
    if (sealed) {
      const raw = await unsealContextKey(sealed);
      if (raw) this._orgKey = unwrapKey(raw);
    }
    return this._orgKey;
  },

  // Decrypt every roster row's display name with the org_key.
  async _decryptRoster() {
    if (this._decrypted) return;
    const orgKey = this._orgKey;
    if (!orgKey) return;

    const rows = this.el.querySelectorAll("[data-org-member-row]");
    for (const row of rows) {
      const ciphertext = row.dataset.encryptedDisplayName;
      if (!ciphertext) continue;

      const name = await decryptWithKey(ciphertext, orgKey);
      if (name) {
        row.querySelectorAll("[data-decrypt-org-name]").forEach((el) => {
          el.textContent = name;
        });
      }
    }
    this._decrypted = true;
  },

  // Owner bootstrap (design Q1=A): nobody holds the org_key yet. Generate it,
  // seal our own copy, and persist. We are the first key-holder.
  async _bootstrap() {
    try {
      const orgKey = await generateKey();
      this._orgKey = unwrapKey(orgKey);

      const keyBytes = b64Decode(orgKey);
      const myPk = getPublicKey();
      const myPqPk = getPqPublicKey();
      const userId = this.el.dataset.currentUserId;

      const sealedKey = await sealForUser(keyBytes, myPk, myPqPk || null);

      this._push("finalize_org_key", {
        sealed_members: [{ user_id: userId, sealed_key: sealedKey }],
      });
    } catch (e) {
      console.error("OrgMembers: bootstrap failed:", e);
    }
  },

  // Seal the org_key (which we already hold) for members who lack it. The member
  // list (public keys) is server-authoritative (D1).
  async _sealForMembers(payload) {
    try {
      const orgKey = await this._ensureOrgKey();
      if (!orgKey) return;

      const keyBytes = b64Decode(orgKey);
      const members = payload.members || [];
      if (members.length === 0) return;

      const sealedMembers = await Promise.all(
        members.map(async (member) => {
          const sealedKey = await sealForUser(
            keyBytes,
            member.public_key,
            member.pq_public_key || null,
          );
          return { user_id: member.user_id, sealed_key: sealedKey };
        }),
      );

      this._push("finalize_org_key", {
        sealed_members: sealedMembers,
      });
    } catch (e) {
      console.error("OrgMembers: sealing for members failed:", e);
    }
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

export default OrgMembers;
