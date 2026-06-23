/**
 * CircleAddMembersHook — add members to an existing business circle (ZK write
 * path). Self-contained on the org-scoped circle dashboard
 * (BusinessLive.CircleShow); see docs/BUSINESS_CIRCLES_DESIGN.md +
 * docs/ORG_DISPLAY_NAME_DESIGN.md.
 *
 * Membership in the org is the ONLY prerequisite for being added — NO personal
 * UserConnection is required. This works because every org member shares the
 * org-scoped ZK identity: one `org_key` (sealed per member) and an org-facing
 * `display_name` encrypted with it. The circle owner/admin already holds the
 * `org_key`, so their browser can decrypt any member's org display name and the
 * member's public key (server-provided, not secret) is the sealing target.
 *
 * Two-phase:
 *   Phase 1: On submit, collect the selected org-member ids and push
 *            "request_add_members". The server (server-authoritative recipient
 *            set — I1) returns each member's public_key, pq_public_key, org
 *            display_name CIPHERTEXT, and a server-generated moniker/avatar.
 *   Phase 2: On "seal_group_key_for_new_members", the browser:
 *              - unseals the circle group_key (data-sealed-group-key) and the
 *                org_key (data-sealed-org-key) — both per-user sealed copies,
 *              - decrypts each member's org display name with the org_key,
 *              - seals the group_key for each member's public key,
 *              - encrypts the name/moniker/avatar with the group_key,
 *            then pushes "finalize_group_members_zk". The raw group_key/org_key
 *            and plaintext names NEVER reach the server (ZK).
 *
 * Form element carries:
 *   data-sealed-group-key — the viewer's sealed circle group_key (per-user copy)
 *   data-sealed-org-key   — the viewer's sealed org_key (per-user copy)
 *
 * Selected members are the checked inputs[name="add_members[]"] within the form.
 */
import {
  unsealContextKey,
  decryptWithKey,
  encryptWithKey,
  getPublicKey,
  unwrapKey,
} from "../crypto/session";
import { sealForUser, b64Decode } from "../crypto/nacl";
import { guardRecipients } from "../crypto/seal_guard";

const FALLBACK_NAME = "Team member";

const CircleAddMembersHook = {
  mounted() {
    this._groupKey = null;
    this._orgKey = null;
    this._unsealKeys();

    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);

    this.handleEvent("seal_group_key_for_new_members", (payload) =>
      this._sealAndFinalize(payload),
    );
  },

  updated() {
    if (!this._groupKey || !this._orgKey) this._unsealKeys();
  },

  async _unsealKeys() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKeys(), {
        once: true,
      });
      return;
    }

    try {
      const sealedGroupKey = this.el.dataset.sealedGroupKey;
      if (sealedGroupKey && !this._groupKey) {
        const raw = await unsealContextKey(sealedGroupKey);
        if (raw) this._groupKey = unwrapKey(raw);
      }

      const sealedOrgKey = this.el.dataset.sealedOrgKey;
      if (sealedOrgKey && !this._orgKey) {
        const raw = await unsealContextKey(sealedOrgKey);
        if (raw) this._orgKey = unwrapKey(raw);
      }
    } catch (e) {
      console.error("CircleAddMembersHook: failed to unseal keys:", e);
    }
  },

  _onSubmit(e) {
    e.preventDefault();
    e.stopImmediatePropagation();

    if (!this._groupKey) return;

    const selected = Array.from(
      this.el.querySelectorAll('input[name="add_members[]"]:checked'),
    ).map((i) => i.value);

    if (selected.length === 0) return;

    this.pushEvent("request_add_members", { user_ids: selected });
  },

  async _sealAndFinalize(payload) {
    try {
      const groupKey = this._groupKey;
      if (!groupKey) {
        console.error(
          "CircleAddMembersHook: no group key available to seal for new members",
        );
        return;
      }

      const keyBytes = b64Decode(groupKey);
      const members = payload.members || [];

      // Verify-before-seal (#294): only seal the circle group_key for members
      // whose served key matches their pinned fingerprint (or is pinned now via
      // TOFU). Substituting a member key here would leak the whole group_key, so
      // a mismatched/unverifiable member is dropped from the seal set. Pins are
      // keyed by peer user id (unified store) and persisted via store_peer_pins.
      const { sealable, pinsToStore } = await guardRecipients(members);

      if (pinsToStore.length > 0) {
        this.pushEvent("store_peer_pins", { pins: pinsToStore });
      }

      const sealedMembers = await Promise.all(
        sealable.map(async (member) => {
          const sealedKey = await sealForUser(
            keyBytes,
            member.public_key,
            member.pq_public_key || null,
          );

          const name = await this._resolveName(member);

          const encryptedName = await encryptWithKey(name, groupKey);
          const encryptedMoniker = member.moniker
            ? await encryptWithKey(member.moniker, groupKey)
            : null;
          const encryptedAvatarImg = member.avatar_img
            ? await encryptWithKey(member.avatar_img, groupKey)
            : null;

          return {
            user_id: member.user_id,
            sealed_key: sealedKey,
            encrypted_name: encryptedName,
            encrypted_moniker: encryptedMoniker,
            encrypted_avatar_img: encryptedAvatarImg,
          };
        }),
      );

      this.pushEvent("finalize_group_members_zk", {
        sealed_members: sealedMembers,
      });
    } catch (err) {
      console.error("CircleAddMembersHook: sealing for new members failed:", err);
    }
  },

  // Decrypt the member's org display name with the org_key. Falls back to a
  // neutral label when the member hasn't set an org display name yet or the
  // org_key isn't available — the circle still gets a valid (encrypted) name.
  async _resolveName(member) {
    if (member.encrypted_display_name && this._orgKey) {
      try {
        const name = await decryptWithKey(
          member.encrypted_display_name,
          this._orgKey,
        );
        if (name) return name;
      } catch (e) {
        console.error("CircleAddMembersHook: failed to decrypt org name:", e);
      }
    }
    return FALLBACK_NAME;
  },
};

export default CircleAddMembersHook;
