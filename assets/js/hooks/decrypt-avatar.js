import {
  unsealContextKey,
  unwrapConnKey,
  decryptWithKey,
  decryptSecretbox,
  getPublicKey,
  b64Encode,
} from "../crypto/session";

const DecryptAvatar = {
  mounted() {
    this._cached = null;
    this._cachedAttrs = null;
    this._decrypting = false;
    this._keysReadyHandler = null;
    this._decrypt();
  },

  updated() {
    const currentAttrs = this._attrFingerprint();
    if (this._cachedAttrs && this._cachedAttrs === currentAttrs) {
      this._apply();
    } else {
      this._cached = null;
      this._cachedAttrs = null;
      this._decrypt();
    }
  },

  destroyed() {
    this._cached = null;
    this._cachedAttrs = null;
    if (this._keysReadyHandler) {
      window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
      this._keysReadyHandler = null;
    }
  },

  _attrFingerprint() {
    return (this.el.dataset.encryptedBlob || "") + "|" + (this.el.dataset.sealedKey || "");
  },

  async _decrypt() {
    if (this._decrypting) return;
    this._decrypting = true;

    const encryptedBlob = this.el.dataset.encryptedBlob;
    const sealedKey = this.el.dataset.sealedKey;

    if (!encryptedBlob || !sealedKey) {
      this._decrypting = false;
      return;
    }

    if (!getPublicKey()) {
      if (this._keysReadyHandler) {
        window.removeEventListener("mosslet:keys-ready", this._keysReadyHandler);
      }
      this._keysReadyHandler = () => {
        this._keysReadyHandler = null;
        this._decrypt();
      };
      window.addEventListener("mosslet:keys-ready", this._keysReadyHandler, { once: true });
      this._decrypting = false;
      return;
    }

    try {
      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) return;

      const connKey = unwrapConnKey(rawKey);

      // Legacy encrypt has two paths:
      //   Path A: encrypt_string(raw_image_bytes, key) — plaintext is raw binary
      //   Path B: encrypt(Base.encode64(raw_image), key) — plaintext is base64 string
      //
      // Try binary path first (Path A) since avatars are image data.
      // Fall back to string path (Path B) for legacy base64-encoded images.
      let imageBase64;
      const rawBytes = await decryptSecretbox(encryptedBlob, connKey);
      if (rawBytes) {
        imageBase64 = b64Encode(rawBytes);
      } else {
        imageBase64 = await decryptWithKey(encryptedBlob, connKey);
        if (!imageBase64) return;
      }

      this._cached = imageBase64;
      this._cachedAttrs = this._attrFingerprint();
      this._apply();
    } catch (e) {
      console.error("DecryptAvatar failed:", e);
    } finally {
      this._decrypting = false;
    }
  },

  _apply() {
    if (!this._cached) return;

    const mime = this.el.dataset.mime || "image/webp";
    const dataUrl = "data:" + mime + ";base64," + this._cached;

    if (this.el.tagName === "IMG") {
      this.el.src = dataUrl;
    } else {
      this.el.style.backgroundImage = "url('" + dataUrl + "')";
    }

    const placeholder = this.el.querySelector("[data-zk-placeholder]");
    if (placeholder) placeholder.remove();
  },
};

export default DecryptAvatar;
