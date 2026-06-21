/**
 * OrgAvatarFormHook — browser-side org display-AVATAR encryption (ZK write path, #277).
 *
 * The companion to OrgDisplayNameFormHook: the member sets the avatar their
 * org-mates see (separate from their personal avatar). The whole pipeline runs
 * in the browser so the server NEVER sees the plaintext image (invariant I3):
 *
 *   1. The member picks an image file.
 *   2. The hook resizes/crops it to a small square WebP on a <canvas>.
 *   3. It unseals the per-org `org_key` from the member's own `Membership.key`
 *      and encrypts the WebP bytes with it (secretbox).
 *   4. It pushes "save_org_avatar" with the opaque ciphertext only.
 *
 * Every org-mate holds the same `org_key`, so any of them can decrypt + display
 * it (see assets/js/hooks/org-avatar.js + the circle-chat hooks). When unset,
 * the chat falls back to initials derived from the org display name.
 *
 * Data attributes on the hook element:
 *   data-sealed-org-key            — base64 org_key sealed for this member (Membership.key)
 *   data-current-encrypted-avatar  — existing ciphertext (optional), decrypted on
 *                                    mount to show the current avatar in the preview
 *
 * Child elements (by data attribute):
 *   [data-org-avatar-input]    — <input type="file">
 *   [data-org-avatar-trigger]  — button that opens the file picker
 *   [data-org-avatar-preview]  — <img> for the current/selected avatar
 */
import { encryptSecretbox } from "../crypto/nacl";
import { unsealContextKey, getPublicKey, unwrapKey } from "../crypto/session";
import { decryptOrgAvatarUrl } from "./org-avatar";

const AVATAR_SIZE = 256;
const MAX_INPUT_BYTES = 8 * 1024 * 1024;
const ACCEPTED = ["image/jpeg", "image/png", "image/webp", "image/gif", "image/heic", "image/heif"];

const OrgAvatarFormHook = {
  mounted() {
    this._orgKey = null;
    this._busy = false;

    this.input = this.el.querySelector("[data-org-avatar-input]");
    this.trigger = this.el.querySelector("[data-org-avatar-trigger]");
    this.preview = this.el.querySelector("[data-org-avatar-preview]");

    if (this.trigger && this.input) {
      this._onTrigger = () => this.input.click();
      this.trigger.addEventListener("click", this._onTrigger);
    }

    if (this.input) {
      this._onChange = (e) => this._onFile(e);
      this.input.addEventListener("change", this._onChange);
    }

    this._unsealKey();
  },

  destroyed() {
    if (this.trigger && this._onTrigger) {
      this.trigger.removeEventListener("click", this._onTrigger);
    }
    if (this.input && this._onChange) {
      this.input.removeEventListener("change", this._onChange);
    }
  },

  async _unsealKey() {
    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._unsealKey(), { once: true });
      return;
    }

    const sealed = this.el.dataset.sealedOrgKey;
    if (!sealed) return;

    try {
      const raw = await unsealContextKey(sealed);
      if (raw) this._orgKey = unwrapKey(raw);
      if (this._orgKey) this._showCurrent();
    } catch (e) {
      console.error("OrgAvatarFormHook: failed to unseal org key:", e);
    }
  },

  // Decrypt + show the member's existing org avatar (if any) in the preview.
  async _showCurrent() {
    const current = this.el.dataset.currentEncryptedAvatar;
    if (!current || !this._orgKey || !this.preview) return;

    const url = await decryptOrgAvatarUrl(current, this._orgKey);
    if (url) this.preview.src = url;
  },

  async _onFile(e) {
    const file = e.target?.files?.[0];
    if (!file) return;
    if (this._busy) return;

    if (!ACCEPTED.includes(file.type)) {
      this._push("org_avatar_invalid", {});
      return;
    }
    if (file.size > MAX_INPUT_BYTES) {
      this._push("org_avatar_invalid", {});
      return;
    }

    this._busy = true;
    try {
      const webpBytes = await this._toSquareWebp(file);
      if (!webpBytes) {
        this._push("org_avatar_invalid", {});
        return;
      }

      if (this.preview) {
        const blob = new Blob([webpBytes], { type: "image/webp" });
        this.preview.src = URL.createObjectURL(blob);
      }

      if (!this._orgKey) await this._unsealKey();
      if (!this._orgKey) {
        this._push("org_avatar_invalid", {});
        return;
      }

      const encrypted = await encryptSecretbox(webpBytes, this._orgKey);
      if (!encrypted) {
        this._push("org_avatar_invalid", {});
        return;
      }

      this._push("save_org_avatar", { encrypted_avatar: encrypted });
    } catch (err) {
      console.error("OrgAvatarFormHook: encryption failed:", err);
      this._push("org_avatar_invalid", {});
    } finally {
      this._busy = false;
      if (this.input) this.input.value = "";
    }
  },

  // Draw the image cover-cropped to a centered square and export as WebP bytes.
  _toSquareWebp(file) {
    return new Promise((resolve) => {
      const url = URL.createObjectURL(file);
      const img = new Image();

      img.onload = () => {
        try {
          const canvas = document.createElement("canvas");
          canvas.width = AVATAR_SIZE;
          canvas.height = AVATAR_SIZE;
          const ctx = canvas.getContext("2d");
          if (!ctx) {
            URL.revokeObjectURL(url);
            resolve(null);
            return;
          }

          const side = Math.min(img.width, img.height);
          const sx = (img.width - side) / 2;
          const sy = (img.height - side) / 2;
          ctx.drawImage(img, sx, sy, side, side, 0, 0, AVATAR_SIZE, AVATAR_SIZE);

          canvas.toBlob(
            async (blob) => {
              URL.revokeObjectURL(url);
              if (!blob) {
                resolve(null);
                return;
              }
              const buf = await blob.arrayBuffer();
              resolve(new Uint8Array(buf));
            },
            "image/webp",
            0.85
          );
        } catch (_e) {
          URL.revokeObjectURL(url);
          resolve(null);
        }
      };

      img.onerror = () => {
        URL.revokeObjectURL(url);
        resolve(null);
      };

      img.src = url;
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

export default OrgAvatarFormHook;
