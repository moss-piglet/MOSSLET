/**
 * GroupMetadataFormHook — browser-side group name/description encryption (ZK write path).
 *
 * Intercepts the group edit form submit, unseals the per-group key from a
 * data attribute, encrypts name and description with that key, and pushes a
 * ZK event. The server stores only ciphertext.
 *
 * Only active in edit mode (data-action="edit"). In create mode the form
 * submits normally (server generates the group key during creation).
 *
 * Data attributes on the form:
 *   data-sealed-group-key — base64 sealed group_key (per-user copy)
 *   data-action            — "edit" or "new"
 *   data-public            — "true" for public groups (skip encryption)
 */
import { unsealContextKey, getPublicKey, unwrapKey, encryptWithKey } from "../crypto/session";

const GroupMetadataFormHook = {
  mounted() {
    this._groupKey = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
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

  _onSubmit(e) {
    if (this.el.dataset.action !== "edit") return;
    if (this.el.dataset.public === "true") return;
    if (!this._groupKey) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit().catch((err) => {
      console.error("GroupMetadataFormHook: encryption failed, falling back:", err);
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit() {
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

    const userId = this.el.querySelector('input[name="group[user_id]"]')?.value;
    const userName = this.el.querySelector('input[name="group[user_name]"]')?.value;

    const target = this.el.getAttribute("phx-target");
    const payload = {
      encrypted_name: encryptedName,
      encrypted_description: encryptedDescription,
      name_blind_index: name.toLowerCase(),
      user_connections: userConnections,
      user_id: userId,
      user_name: userName,
    };

    if (target) {
      this.pushEventTo(target, "save_group_zk", payload);
    } else {
      this.pushEvent("save_group_zk", payload);
    }
  },
};

export default GroupMetadataFormHook;
