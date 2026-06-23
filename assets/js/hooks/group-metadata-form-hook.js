/**
 * GroupMetadataFormHook — browser-side group name/description encryption (ZK write path).
 *
 * Intercepts the group form submit for both create and edit actions.
 *
 * Edit mode: unseals the existing per-group key from a data attribute,
 * encrypts name and description with that key, and pushes save_group_zk.
 *
 * Create mode (two-phase commit, same pattern as PostFormHook):
 *   Phase 1: Browser generates group_key, encrypts name/description, seals key
 *            for creator, and pushes "create_group_zk" with encrypted content +
 *            member list. NO raw key leaves the browser.
 *   Phase 2: Server responds with "seal_group_key_for_members" containing each
 *            member's public_key, pq_public_key, and plaintext display name.
 *            Browser seals group_key for each member, encrypts their display
 *            names with group_key, and pushes "finalize_group_zk" with sealed
 *            keys. The raw group_key NEVER exists in server memory.
 *
 * Public groups and WASM-unavailable scenarios fall through to normal server-side
 * encryption.
 *
 * Data attributes on the form:
 *   data-sealed-group-key — base64 sealed group_key (per-user copy, edit only)
 *   data-action            — "edit" or "new"
 *   data-public            — "true" for public groups (skip encryption)
 */
import { unsealContextKey, getPublicKey, getPqPublicKey, unwrapKey, encryptWithKey } from "../crypto/session";
import { generateKey, sealForUser, b64Decode, encryptSecretboxString } from "../crypto/nacl";
import { guardRecipients } from "../crypto/seal_guard";

const GroupMetadataFormHook = {
  mounted() {
    this._groupKey = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);

    this.handleEvent("seal_group_key_for_members", (payload) => {
      this._sealKeyForMembersAndFinalize(payload);
    });

    this.handleEvent("seal_group_key_for_new_members", (payload) => {
      this._sealKeyForNewMembersAndFinalize(payload);
    });
  },

  updated() {
    if (!this._groupKey) this._unsealKey();
  },

  async _unsealKey() {
    if (this.el.dataset.action !== "edit") return;
    if (this.el.dataset.public === "true") return;
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), {
        once: true,
      });
      return;
    }

    const sealedKey = this.el.dataset.sealedGroupKey;
    if (!sealedKey) return;

    try {
      const raw = await unsealContextKey(sealedKey);
      if (raw) this._groupKey = unwrapKey(raw);
    } catch (e) {
      console.error("GroupMetadataFormHook: failed to unseal group key:", e);
    }
  },

  _isPublicGroup() {
    if (this.el.dataset.action === "new") {
      const checkbox = this.el.querySelector('input[name="group[public?]"]');
      return checkbox?.checked || false;
    }
    return this.el.dataset.public === "true";
  },

  _onSubmit(e) {
    const action = this.el.dataset.action;
    if (this._isPublicGroup()) return;
    if (!getPublicKey()) return;

    if (action === "edit" && !this._groupKey) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    const handler = action === "new" ? this._encryptAndCreate() : this._encryptAndUpdate();

    handler.catch((err) => {
      console.error("GroupMetadataFormHook: encryption failed, falling back:", err);
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  /**
   * Phase 1: Generate group_key, encrypt content, seal key for creator.
   * Send to server along with member list. Server will respond with
   * "seal_group_key_for_members" containing member public keys.
   */
  async _encryptAndCreate() {
    const groupKey = await generateKey();
    this._pendingGroupKey = groupKey;

    const nameInput = this.el.querySelector('input[name="group[name]"]');
    const descInput = this.el.querySelector('input[name="group[description]"]');
    const name = nameInput?.value?.trim() || "";
    const description = descInput?.value?.trim() || "";

    if (!name) return;

    const [encryptedName, encryptedDescription] = await Promise.all([
      encryptSecretboxString(name, groupKey),
      description ? encryptSecretboxString(description, groupKey) : Promise.resolve(null),
    ]);

    const authorPk = getPublicKey();
    const authorPqPk = getPqPublicKey();
    const keyBytes = b64Decode(groupKey);
    const sealedCreatorKey = await sealForUser(keyBytes, authorPk, authorPqPk);

    const userConnections = Array.from(
      this.el.querySelectorAll('input[name="group[user_connections][]"]'),
    ).map((i) => i.value);

    const userNameInput = this.el.querySelector('input[name="group[user_name]"]');
    const userName = userNameInput?.value?.trim() || "";
    const encryptedUserName = userName
      ? await encryptSecretboxString(userName, groupKey)
      : null;

    const requirePassword = this.el.querySelector(
      'input[name="group[require_password?]"]',
    );
    const passwordInput = this.el.querySelector(
      'input[name="group[password]"]',
    );

    // Circle classification hint (#229b, business circles only). Read the checked
    // radio, falling back to any plain/hidden input, then default to "community".
    // The server re-checks the :team authority gate regardless of this value.
    const circleTypeEl =
      this.el.querySelector(
        'input[name="group[org_circle_type]"]:checked',
      ) || this.el.querySelector('input[name="group[org_circle_type]"]');

    const target = this.el.getAttribute("phx-target");
    const payload = {
      encrypted_name: encryptedName,
      encrypted_description: encryptedDescription,
      name_blind_index: name.toLowerCase(),
      sealed_creator_key: sealedCreatorKey,
      encrypted_user_name: encryptedUserName,
      user_connections: userConnections,
      user_id: this.el.querySelector('input[name="group[user_id]"]')?.value,
      require_password: requirePassword?.checked ? "true" : "false",
      password: passwordInput?.value || "",
      circle_type: circleTypeEl?.value || "community",
    };

    if (target) {
      this.pushEventTo(target, "create_group_zk", payload);
    } else {
      this.pushEvent("create_group_zk", payload);
    }
  },

  /**
   * Phase 2: Server sent back member public keys + display names.
   * Seal group_key for each member, encrypt their display names,
   * and send "finalize_group_zk" back.
   */
  async _sealKeyForMembersAndFinalize(payload) {
    try {
      const groupKey = this._pendingGroupKey;
      if (!groupKey) {
        console.error("GroupMetadataFormHook: no pending group key for Phase 2");
        return;
      }

      const keyBytes = b64Decode(groupKey);
      const members = payload.members || [];

      // Verify-before-seal (#294): only seal the group_key for members whose
      // served key matches their pinned fingerprint (or is pinned now via TOFU).
      const { sealable, pinsToStore } = await guardRecipients(members);

      if (pinsToStore.length > 0) {
        this._pushGroup("store_peer_pins", { pins: pinsToStore });
      }

      const sealedMembers = await Promise.all(
        sealable.map(async (member) => {
          const sealedKey = await sealForUser(
            keyBytes,
            member.public_key,
            member.pq_public_key || null,
          );
          const encryptedName = member.name
            ? await encryptSecretboxString(member.name, groupKey)
            : null;
          const encryptedMoniker = member.moniker
            ? await encryptSecretboxString(member.moniker, groupKey)
            : null;
          const encryptedAvatarImg = member.avatar_img
            ? await encryptSecretboxString(member.avatar_img, groupKey)
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

      // Encrypt owner's moniker/avatar with group_key
      const encryptedOwnerMoniker = payload.owner_moniker
        ? await encryptSecretboxString(payload.owner_moniker, groupKey)
        : null;
      const encryptedOwnerAvatarImg = payload.owner_avatar_img
        ? await encryptSecretboxString(payload.owner_avatar_img, groupKey)
        : null;

      const target = this.el.getAttribute("phx-target");
      const finalPayload = {
        sealed_members: sealedMembers,
        encrypted_owner_moniker: encryptedOwnerMoniker,
        encrypted_owner_avatar_img: encryptedOwnerAvatarImg,
      };

      if (target) {
        this.pushEventTo(target, "finalize_group_zk", finalPayload);
      } else {
        this.pushEvent("finalize_group_zk", finalPayload);
      }

      this._pendingGroupKey = null;
    } catch (err) {
      console.error("GroupMetadataFormHook: Phase 2 sealing failed:", err);
      this._pendingGroupKey = null;
    }
  },

  /**
   * Edit Phase 2: Server sent back public keys for members newly added during an
   * edit. Seal the existing (already-unsealed) group_key for each, encrypt their
   * display name/moniker/avatar with the group_key, and push
   * "finalize_group_members_zk". The raw group_key never leaves the browser.
   */
  async _sealKeyForNewMembersAndFinalize(payload) {
    try {
      const groupKey = this._groupKey;
      if (!groupKey) {
        console.error(
          "GroupMetadataFormHook: no group key available to seal for new members",
        );
        return;
      }

      const keyBytes = b64Decode(groupKey);
      const members = payload.members || [];

      // Verify-before-seal (#294): drop members whose served key fails pin
      // verification; auto-pin first-contact peers and persist them.
      const { sealable, pinsToStore } = await guardRecipients(members);

      if (pinsToStore.length > 0) {
        this._pushGroup("store_peer_pins", { pins: pinsToStore });
      }

      const sealedMembers = await Promise.all(
        sealable.map(async (member) => {
          const sealedKey = await sealForUser(
            keyBytes,
            member.public_key,
            member.pq_public_key || null,
          );
          const encryptedName = member.name
            ? await encryptWithKey(member.name, groupKey)
            : null;
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

      const target = this.el.getAttribute("phx-target");
      const finalPayload = { sealed_members: sealedMembers };

      if (target) {
        this.pushEventTo(target, "finalize_group_members_zk", finalPayload);
      } else {
        this.pushEvent("finalize_group_members_zk", finalPayload);
      }
    } catch (err) {
      console.error(
        "GroupMetadataFormHook: sealing for new members failed:",
        err,
      );
    }
  },

  async _encryptAndUpdate() {
    const nameInput = this.el.querySelector('input[name="group[name]"]');
    const descInput = this.el.querySelector('input[name="group[description]"]');
    const name = nameInput?.value?.trim() || "";
    const description = descInput?.value?.trim() || "";

    const [encryptedName, encryptedDescription] = await Promise.all([
      name ? encryptWithKey(name, this._groupKey) : Promise.resolve(null),
      description ? encryptWithKey(description, this._groupKey) : Promise.resolve(null),
    ]);

    const userConnectionsInput = this.el.querySelector(
      'input[name="group[user_connections][]"]',
    );
    const userConnections = userConnectionsInput
      ? Array.from(
          this.el.querySelectorAll('input[name="group[user_connections][]"]'),
        ).map((i) => i.value)
      : [];

    const target = this.el.getAttribute("phx-target");
    const payload = {
      encrypted_name: encryptedName,
      encrypted_description: encryptedDescription,
      name_blind_index: name.toLowerCase(),
      user_connections: userConnections,
    };

    if (target) {
      this.pushEventTo(target, "save_group_zk", payload);
    } else {
      this.pushEvent("save_group_zk", payload);
    }
  },

  _pushGroup(event, payload) {
    const target = this.el.getAttribute("phx-target");
    if (target) {
      this.pushEventTo(target, event, payload);
    } else {
      this.pushEvent(event, payload);
    }
  },
};

export default GroupMetadataFormHook;
