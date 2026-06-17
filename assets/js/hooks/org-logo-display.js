/**
 * OrgLogoDisplay — browser-side ZK decryption + render of an org brand logo (#228).
 *
 * The org logo blob in object storage is encrypted with the per-org `org_key`
 * (#225). Any member holds that key (sealed in Membership.key), so the server
 * hands the browser a short-lived presigned GET URL; this hook fetches the
 * ciphertext, decrypts it with the org_key, and points the <img> at an object
 * URL. The server never sees the plaintext logo (invariant I3).
 *
 * Mirrors SharedFileHook's download path (fetch presigned -> decryptSecretbox).
 *
 * Loading/error UI is driven by a `data-state` attribute on the hook element
 * (read by the org_logo component's Tailwind `group-data-[state=…]` classes):
 *   "loading" (initial) — spinner shown, <img> hidden
 *   "ready"             — <img> shown, spinner hidden
 *   "error"             — building-icon fallback shown, spinner hidden
 *
 * Data attributes on the hook element (a wrapper containing an [data-logo-img]):
 *   data-sealed-org-key  — base64 org_key sealed for this member (Membership.key)
 *   data-logo-url        — short-lived presigned GET URL for the opaque blob
 */
import { decryptSecretbox, b64Encode } from "../crypto/nacl";
import { unsealContextKey, getPublicKey, unwrapKey } from "../crypto/session";

const KEY_WAIT_TIMEOUT_MS = 15_000;

const OrgLogoDisplay = {
  mounted() {
    this._objectUrl = null;
    this._orgKey = null;
    this._keysReadyHandler = null;
    this._loadedUrl = null;
    this._run();
  },

  updated() {
    this._run();
  },

  destroyed() {
    this._revoke();
    if (this._keysReadyHandler) {
      window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
      this._keysReadyHandler = null;
    }
  },

  _setState(state) {
    this.el.dataset.state = state;
  },

  async _run() {
    const presignedUrl = this.el.dataset.logoUrl;
    const sealed = this.el.dataset.sealedOrgKey;
    if (!presignedUrl || !sealed) {
      this._setState("error");
      return;
    }

    // Avoid redundant re-fetch when LiveView re-renders without a new URL.
    if (this._loadedUrl === presignedUrl && this.el.dataset.state === "ready") return;
    this._loadedUrl = presignedUrl;

    try {
      if (!getPublicKey()) await this._waitForKeys();

      const orgKey = await this._ensureOrgKey(sealed);
      if (!orgKey) {
        this._setState("error");
        return;
      }

      const resp = await fetch(presignedUrl);
      if (!resp.ok) throw new Error("fetch failed: " + resp.status);
      const cipherBytes = new Uint8Array(await resp.arrayBuffer());

      const plainBytes = await decryptSecretbox(b64Encode(cipherBytes), orgKey);
      if (!plainBytes) {
        this._setState("error");
        return;
      }

      this._revoke();
      const blob = new Blob([plainBytes], { type: "image/webp" });
      this._objectUrl = URL.createObjectURL(blob);

      const img = this.el.querySelector("[data-logo-img]") || this.el.querySelector("img");
      if (img) {
        img.onerror = () => this._setState("error");
        img.src = this._objectUrl;
      }
      this._setState("ready");
    } catch (err) {
      console.error("OrgLogoDisplay: failed to render logo:", err);
      this._loadedUrl = null;
      this._setState("error");
    }
  },

  async _ensureOrgKey(sealed) {
    if (this._orgKey) return this._orgKey;
    const raw = await unsealContextKey(sealed);
    if (raw) this._orgKey = unwrapKey(raw);
    return this._orgKey;
  },

  _revoke() {
    if (this._objectUrl) {
      URL.revokeObjectURL(this._objectUrl);
      this._objectUrl = null;
    }
  },

  _waitForKeys() {
    return new Promise((resolve, reject) => {
      if (getPublicKey()) {
        resolve();
        return;
      }

      const timer = setTimeout(() => {
        if (this._keysReadyHandler) {
          window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
          this._keysReadyHandler = null;
        }
        reject(new Error("Timed out waiting for crypto keys"));
      }, KEY_WAIT_TIMEOUT_MS);

      this._keysReadyHandler = () => {
        clearTimeout(timer);
        this._keysReadyHandler = null;
        resolve();
      };

      window.addEventListener("mosslet:keys-ready", this._keysReadyHandler, {
        once: true,
      });
    });
  },
};

export default OrgLogoDisplay;
