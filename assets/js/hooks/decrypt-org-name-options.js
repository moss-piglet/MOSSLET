/**
 * DecryptOrgNameOptions — org-scoped ZK display names inside a <select> (#267).
 *
 * The guardianship "establish" form lets an admin pick a Guardian and a Managed
 * member from <select> dropdowns. Those options must show each member's REAL
 * org-facing display name so the admin doesn't pick the wrong person when there
 * is more than one — but the server only holds ciphertext (the same per-org
 * `org_key` ZK model the roster uses, Task #225). The server renders a neutral
 * placeholder ("Family member" / "You"); this hook decrypts the option text in
 * the browser, exactly like OrgMembers does for the roster rows.
 *
 * Data attributes:
 *   on the <select> (hook element):
 *     data-sealed-org-key — base64 org_key sealed for the viewer (Membership.key)
 *   on each <option>:
 *     data-encrypted-display-name — ciphertext (org_key secretbox), or "" if unset
 *
 * Options without a ciphertext keep their server-rendered placeholder. We do NOT
 * use phx-update="ignore": option lists change as members come and go, so we let
 * LiveView patch them and re-decrypt in updated(), mirroring OrgMembers.
 */
import {
  unsealContextKey,
  decryptWithKey,
  getPublicKey,
  unwrapKey,
} from "../crypto/session";

const DecryptOrgNameOptions = {
  mounted() {
    this._orgKey = null;
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

    await this._decrypt();
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

  async _decrypt() {
    if (this._decrypted) return;

    const orgKey = await this._ensureOrgKey();
    if (!orgKey) return;

    const options = this.el.querySelectorAll(
      "option[data-encrypted-display-name]",
    );

    for (const option of options) {
      const ciphertext = option.dataset.encryptedDisplayName;
      if (!ciphertext) continue;

      const name = await decryptWithKey(ciphertext, orgKey);
      if (name) option.textContent = name;
    }

    this._decrypted = true;
  },
};

export default DecryptOrgNameOptions;
