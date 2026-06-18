/**
 * AnnouncementFormHook — browser-side announcement encryption (ZK write path, #229c).
 *
 * A team lead writes an announcement (optional title + body). The hook unseals
 * the tier's shared key and encrypts the title/body with it (secretbox), then
 * pushes "save_announcement" with ONLY ciphertext + plaintext surface metadata
 * (priority, expires_at). The server never sees the plaintext or the key.
 *
 * Two tiers, selected by `data-key-tier`:
 *   "org"   — org-wide announcement. Unseals the per-org `org_key` from
 *             `data-sealed-org-key` (the viewer's Membership.key). Mirrors
 *             OrgDisplayNameFormHook.
 *   "group" — circle announcement. Unseals the circle `group_key` from
 *             `data-sealed-group-key` (the viewer's UserGroup.key). Mirrors the
 *             edit path of GroupMetadataFormHook.
 *
 * Inputs:
 *   input[name="announcement[title]"]     — optional
 *   textarea[name="announcement[body]"]   — required
 *   input[name="announcement[priority]"]  — "normal" | "pinned"
 *   input[name="announcement[expires_at]"] — optional (plaintext datetime-local)
 */
import {
  unsealContextKey,
  getPublicKey,
  unwrapKey,
  encryptWithKey,
} from "../crypto/session";

const MAX_TITLE_LEN = 160;
const MAX_BODY_LEN = 5000;

const AnnouncementFormHook = {
  mounted() {
    this._key = null;
    this._unsealKey();
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  updated() {
    if (!this._key) this._unsealKey();
  },

  _sealedKey() {
    return this.el.dataset.keyTier === "org"
      ? this.el.dataset.sealedOrgKey
      : this.el.dataset.sealedGroupKey;
  },

  async _unsealKey() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), {
        once: true,
      });
      return;
    }

    const sealed = this._sealedKey();
    if (!sealed) return;

    try {
      const raw = await unsealContextKey(sealed);
      if (raw) this._key = unwrapKey(raw);
    } catch (e) {
      console.error("AnnouncementFormHook: failed to unseal key:", e);
    }
  },

  _onSubmit(e) {
    if (!this._key) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    const titleInput = this.el.querySelector(
      'input[name="announcement[title]"]',
    );
    const bodyInput = this.el.querySelector(
      'textarea[name="announcement[body]"]',
    );
    const expiresInput = this.el.querySelector(
      'input[name="announcement[expires_at]"]',
    );

    const title = titleInput?.value?.trim() || "";
    const body = bodyInput?.value?.trim() || "";
    const priority = this._readPriority();
    const expiresAt = this._toUtcIso(expiresInput?.value?.trim() || "");

    if (!body || body.length > MAX_BODY_LEN || title.length > MAX_TITLE_LEN) {
      this._push("announcement_invalid", {});
      return;
    }

    this._encryptAndSubmit(title, body, priority, expiresAt).catch((err) => {
      console.error("AnnouncementFormHook: encryption failed:", err);
      this._push("announcement_invalid", {});
    });
  },

  async _encryptAndSubmit(title, body, priority, expiresAt) {
    const [encryptedTitle, encryptedBody] = await Promise.all([
      title ? encryptWithKey(title, this._key) : Promise.resolve(null),
      encryptWithKey(body, this._key),
    ]);

    if (!encryptedBody) {
      this._push("announcement_invalid", {});
      return;
    }

    this._push("save_announcement", {
      encrypted_title: encryptedTitle,
      encrypted_body: encryptedBody,
      priority: priority,
      expires_at: expiresAt,
    });
  },

  // Converts a `datetime-local` value (interpreted in the member's LOCAL
  // timezone) into a UTC ISO8601 string, so the server stores the intended
  // wall-clock auto-hide time regardless of timezone. Empty → "".
  _toUtcIso(localValue) {
    if (!localValue) return "";
    const date = new Date(localValue);
    if (isNaN(date.getTime())) return localValue;
    return date.toISOString();
  },

  _readPriority() {
    const checkbox = this.el.querySelector(
      'input[type="checkbox"][name="announcement[priority]"]',
    );
    if (checkbox) return checkbox.checked ? "pinned" : "normal";

    const radio = this.el.querySelector(
      'input[type="radio"][name="announcement[priority]"]:checked',
    );
    if (radio) return radio.value === "pinned" ? "pinned" : "normal";

    const select = this.el.querySelector(
      'select[name="announcement[priority]"]',
    );
    if (select) return select.value === "pinned" ? "pinned" : "normal";

    return "normal";
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

export default AnnouncementFormHook;
