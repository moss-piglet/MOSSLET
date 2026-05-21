import { unsealContextKey, decryptWithKey, decryptSecretbox, getPublicKey } from "../crypto/session";

/**
 * Server-registered users have conn_key sealed as a 44-char base64 string,
 * so unsealFromUser returns those ASCII bytes re-encoded as base64 (~60 chars,
 * double-encoded). Browser-registered users seal raw 32 bytes, so unseal
 * returns the correct 44-char base64 key directly.
 *
 * We detect double-encoding by length: 44 chars = correct base64 of 32 bytes;
 * longer = double-encoded, needs one atob() unwrap.
 */
function unwrapConnKey(unsealedB64) {
  if (unsealedB64.length > 44) {
    try {
      return atob(unsealedB64);
    } catch {
      return unsealedB64;
    }
  }
  return unsealedB64;
}

function b64Encode(uint8Array) {
  let binary = "";
  for (let i = 0; i < uint8Array.length; i++) {
    binary += String.fromCharCode(uint8Array[i]);
  }
  return btoa(binary);
}

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
      // Try decryptSecretboxToString first (Path B, plaintext is UTF-8 base64).
      // If that fails with UTF-8 error, fall back to decryptSecretbox (Path A).
      let imageBase64 = await decryptWithKey(encryptedBlob, connKey);

      if (!imageBase64) {
        const rawBytes = await decryptSecretbox(encryptedBlob, connKey);
        if (!rawBytes) return;
        imageBase64 = b64Encode(rawBytes);
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
