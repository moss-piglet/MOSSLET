/**
 * PinLinkFormHook — browser-side link-pin encryption (ZK write path, #229d).
 *
 * A member pins a free URL to the dashboard. The hook encrypts the label + URL
 * with the appropriate key and pushes "save_pin_link" with ONLY ciphertext
 * (plus the plaintext `scope`); the server never sees the plaintext or the key.
 *
 * Two scopes, selected by `data-pin-scope`:
 *   "personal"   — encrypts with the viewer's `user_key` (mirrors
 *                  StatusFormHook / BlockReasonFormHook). The sealed user_key is
 *                  read from the DOM via getSealedUserKey() — no attribute needed.
 *   "org_shared" — encrypts with the per-org `org_key`, unsealed from
 *                  `data-sealed-org-key` (mirrors AnnouncementFormHook org tier).
 *
 * Inputs:
 *   input[name="pin[label]"] — required
 *   input[name="pin[url]"]   — required
 */
import {
  unsealContextKey,
  unwrapKey,
  encryptWithKey,
  getPublicKey,
  getUserKey,
  getSealedUserKey,
} from "../crypto/session";

const MAX_LABEL_LEN = 120;
const MAX_URL_LEN = 2000;

const PinLinkFormHook = {
  mounted() {
    this._key = null;
    this._keyScope = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    // Re-unseal when the key is missing OR the scope changed (personal ⇄
    // org_shared), so a link is always encrypted with the right key — the
    // user_key for personal, the org_key for org-wide. Otherwise a stale
    // personal key would be used after switching to "Share with the team".
    if (!this._key || this._keyScope !== this._scope()) this._unsealKey();
  },

  _scope() {
    return this.el.dataset.pinScope === "org_shared" ? "org_shared" : "personal";
  },

  async _unsealKey() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), {
        once: true,
      });
      return;
    }

    const scope = this._scope();
    this._key = null;
    this._keyScope = scope;

    try {
      if (scope === "org_shared") {
        const sealed = this.el.dataset.sealedOrgKey;
        if (!sealed) return;
        const raw = await unsealContextKey(sealed);
        if (raw && this._keyScope === "org_shared") this._key = unwrapKey(raw);
      } else {
        const sealedUserKey = getSealedUserKey();
        if (sealedUserKey && this._keyScope === "personal") {
          this._key = await getUserKey(sealedUserKey);
        }
      }
    } catch (e) {
      console.error("PinLinkFormHook: failed to unseal key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._key) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    const labelInput = this.el.querySelector('input[name="pin[label]"]');
    const urlInput = this.el.querySelector('input[name="pin[url]"]');

    const label = labelInput?.value?.trim() || "";
    const url = urlInput?.value?.trim() || "";

    if (
      !label ||
      !url ||
      label.length > MAX_LABEL_LEN ||
      url.length > MAX_URL_LEN
    ) {
      this._push("pin_link_invalid", {});
      return;
    }

    this._encryptAndSubmit(label, url).catch((err) => {
      console.error("PinLinkFormHook: encryption failed:", err);
      this._push("pin_link_invalid", {});
    });
  },

  async _encryptAndSubmit(label, url) {
    const [encryptedLabel, encryptedUrl] = await Promise.all([
      encryptWithKey(label, this._key),
      encryptWithKey(url, this._key),
    ]);

    if (!encryptedLabel || !encryptedUrl) {
      this._push("pin_link_invalid", {});
      return;
    }

    this._push("save_pin_link", {
      scope: this._scope(),
      encrypted_label: encryptedLabel,
      encrypted_url: encryptedUrl,
    });
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

export default PinLinkFormHook;
