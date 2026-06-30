/**
 * OrgLogoDisplay — browser-side ZK decryption + render of an org brand logo (#228).
 *
 * The org logo blob in object storage is encrypted with the per-org `org_key`
 * (#225). Any member holds that key (sealed in Membership.key), so the server
 * delivers the opaque CIPHERTEXT inline (base64) and this hook decrypts it with
 * the org_key and points the <img> at an object URL. The server never sees the
 * plaintext logo (invariant I3).
 *
 * Delivering the ciphertext inline (rather than via a cross-origin presigned
 * GET) means there is NO Tigris CORS dependency, so the logo renders identically
 * on the apex (`mosslet.com`) and on a branded subdomain (`acme.mosslet.com`) —
 * Task #349. This mirrors the personal-avatar `DecryptAvatar` read path.
 *
 * Loading/error UI is driven by a `data-state` attribute on the hook element
 * (read by the org_logo component's Tailwind `group-data-[state=…]` classes):
 *   "loading" (initial) — spinner shown, <img> hidden
 *   "ready"             — <img> shown, spinner hidden
 *   "error"             — building-icon fallback shown, spinner hidden
 *
 * Data attributes on the hook element (a wrapper containing an [data-logo-img]):
 *   data-sealed-org-key  — base64 org_key sealed for this member (Membership.key)
 *   data-encrypted-blob  — base64 org_key-secretbox ciphertext of the logo
 */
import { decryptSecretbox } from "../crypto/nacl";
import { unsealContextKey, getPublicKey, unwrapKey } from "../crypto/session";

const KEY_WAIT_TIMEOUT_MS = 15_000;

const OrgLogoDisplay = {
  mounted() {
    this._objectUrl = null;
    this._orgKey = null;
    this._keysReadyHandler = null;
    this._renderedBlob = null;
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
    const encryptedBlob = this.el.dataset.encryptedBlob;
    const sealed = this.el.dataset.sealedOrgKey;
    if (!encryptedBlob || !sealed) {
      this._setState("error");
      return;
    }

    // Avoid redundant re-decrypt when LiveView re-renders the same blob.
    if (this._renderedBlob === encryptedBlob && this.el.dataset.state === "ready") return;
    this._renderedBlob = encryptedBlob;

    try {
      if (!getPublicKey()) await this._waitForKeys();

      const orgKey = await this._ensureOrgKey(sealed);
      if (!orgKey) {
        this._setState("error");
        return;
      }

      const plainBytes = await decryptSecretbox(encryptedBlob, orgKey);
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
      this._renderedBlob = null;
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
