/**
 * DecryptComposerGuardians — ZK family-name resolution for the composer chip (#270).
 *
 * The guardianship transparency chip (I2) lists the guardians who will co-read a
 * post being written. When a guardian is also a personal connection the server
 * decrypts the name directly; but a guardian without a personal UserConnection
 * (the common Family case) is rendered as a neutral "your guardian" placeholder.
 *
 * For those ZK entries the server provides the family `org_key` data (Task #225):
 * both parties hold the same per-org `org_key` (sealed in their Membership.key)
 * and the guardian's `display_name` is `org_key`-sealed. This hook unseals the
 * org_key and decrypts each guardian's display name in the browser. The
 * "(guardian)" role suffix stays server-rendered; only the NAME resolves.
 *
 * Each entry element carries:
 *   [data-guardian-name]            — the span to fill with the decrypted name
 *   data-sealed-org-key             — base64 org_key sealed for the viewer, or ""
 *   data-encrypted-display-name     — ciphertext (org_key secretbox), or ""
 *
 * Entries without a sealed org key keep their server-rendered text.
 */
import {
  unsealContextKey,
  decryptWithKey,
  getPublicKey,
  unwrapKey,
} from "../crypto/session";

const _orgKeyCache = new Map();

async function getOrgKey(sealedOrgKey) {
  if (!sealedOrgKey) return null;
  const cached = _orgKeyCache.get(sealedOrgKey);
  if (cached) return cached;

  const raw = await unsealContextKey(sealedOrgKey);
  if (!raw) return null;

  const orgKey = unwrapKey(raw);
  _orgKeyCache.set(sealedOrgKey, orgKey);
  return orgKey;
}

const DecryptComposerGuardians = {
  mounted() {
    this._run();
  },

  updated() {
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

  async _decrypt() {
    const entries = this.el.querySelectorAll(
      "[data-guardian-name][data-sealed-org-key]",
    );

    for (const entry of entries) {
      const sealedOrgKey = entry.dataset.sealedOrgKey;
      const ciphertext = entry.dataset.encryptedDisplayName;
      if (!sealedOrgKey || !ciphertext) continue;

      try {
        const orgKey = await getOrgKey(sealedOrgKey);
        if (!orgKey) continue;

        const name = await decryptWithKey(ciphertext, orgKey);
        if (name) entry.textContent = name;
      } catch {
        // unseal or decryption failure — placeholder preserved
      }
    }
  },
};

export default DecryptComposerGuardians;
