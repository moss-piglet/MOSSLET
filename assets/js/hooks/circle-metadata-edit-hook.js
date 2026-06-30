/**
 * CircleMetadataEditHook — browser-side ZK edit of a business circle's
 * name/description (Task #351). Modeled on the edit path of
 * GroupMetadataFormHook.
 *
 * On mount it unseals the viewer's per-group key (from `data-sealed-group-key`),
 * decrypts the current name/description, and prefills the form inputs so the
 * editor sees plaintext locally. On submit it re-encrypts both fields with the
 * group key and pushes `save_circle_metadata_zk`. The raw group_key and the
 * plaintext NEVER reach the server (zero-knowledge).
 *
 * Data attributes on the form:
 *   data-sealed-group-key      — base64 sealed group_key (per-user copy)
 *   data-encrypted-name        — current ciphertext name
 *   data-encrypted-description — current ciphertext description
 *   data-circle-id             — the circle (group) id
 */
import {
  unsealContextKey,
  getPublicKey,
  unwrapKey,
  encryptWithKey,
  decryptWithKey,
} from "../crypto/session";

const CircleMetadataEditHook = {
  mounted() {
    this._groupKey = null;
    this._init();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  async _init() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._init(), {
        once: true,
      });
      return;
    }

    const sealedKey = this.el.dataset.sealedGroupKey;
    if (!sealedKey) return;

    try {
      const raw = await unsealContextKey(sealedKey);
      if (raw) {
        this._groupKey = unwrapKey(raw);
        await this._prefill();
      }
    } catch (e) {
      console.error("CircleMetadataEditHook: failed to unseal group key:", e);
    }
  },

  _nameInput() {
    return this.el.querySelector('input[name="circle[name]"]');
  },

  _descInput() {
    return this.el.querySelector(
      'textarea[name="circle[description]"], input[name="circle[description]"]',
    );
  },

  async _prefill() {
    const encName = this.el.dataset.encryptedName;
    const encDesc = this.el.dataset.encryptedDescription;
    const nameInput = this._nameInput();
    const descInput = this._descInput();

    if (encName && nameInput && !nameInput.value) {
      const name = await decryptWithKey(encName, this._groupKey);
      if (name) nameInput.value = name;
    }

    if (encDesc && descInput && !descInput.value) {
      const description = await decryptWithKey(encDesc, this._groupKey);
      if (description) descInput.value = description;
    }
  },

  _onSubmit(e) {
    if (!getPublicKey()) return;
    if (!this._groupKey) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSave().catch((err) => {
      console.error("CircleMetadataEditHook: save failed:", err);
    });
  },

  async _encryptAndSave() {
    const name = this._nameInput()?.value?.trim() || "";
    const description = this._descInput()?.value?.trim() || "";

    if (!name) return;

    const [encryptedName, encryptedDescription] = await Promise.all([
      encryptWithKey(name, this._groupKey),
      description
        ? encryptWithKey(description, this._groupKey)
        : Promise.resolve(null),
    ]);

    this.pushEvent("save_circle_metadata_zk", {
      circle_id: this.el.dataset.circleId,
      encrypted_name: encryptedName,
      encrypted_description: encryptedDescription,
      name_blind_index: name.toLowerCase(),
    });
  },
};

export default CircleMetadataEditHook;
