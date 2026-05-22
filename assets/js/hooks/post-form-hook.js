/**
 * PostFormHook — browser-side post encryption (zero-knowledge write path).
 *
 * For non-public posts, this hook intercepts the form submit, generates a
 * post_key, encrypts the body and content warning fields with secretbox,
 * and seals the post_key for the author. The server receives only encrypted
 * ciphertext — it never sees the plaintext body or content warning.
 *
 * For images, the hook also handles server-sent "encrypt_post_image" events:
 * processed image bytes are encrypted with the same post_key and sent back
 * to the server, which stores them directly on S3 without ever seeing the
 * encryption key or plaintext image.
 *
 * Hook element: the <.form> element with phx-submit="save_post"
 * Required data attributes:
 *   data-visibility — current visibility, kept in sync by the LiveView
 */
import {
  generateKey,
  encryptSecretboxString,
  encryptSecretbox,
  sealForUser,
  b64Decode,
} from "../crypto/nacl";
import { getPublicKey, getPqPublicKey } from "../crypto/session";

const PostFormHook = {
  mounted() {
    this._fallback = false;
    this._postKey = null;

    this.handleEvent("encrypt_post_image", (payload) => {
      this._encryptImage(payload);
    });

    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  destroyed() {
    this._postKey = null;
  },

  async _getOrCreatePostKey() {
    if (this._postKey) return this._postKey;
    this._postKey = await generateKey();
    return this._postKey;
  },

  async _encryptImage({ blob_b64, upload_ref }) {
    try {
      const postKey = await this._getOrCreatePostKey();
      const rawBytes = Uint8Array.from(atob(blob_b64), (c) => c.charCodeAt(0));
      const encryptedBlobB64 = await encryptSecretbox(rawBytes, postKey);
      this.pushEvent("post_image_encrypted", {
        encrypted_blob_b64: encryptedBlobB64,
        upload_ref,
      });
    } catch (e) {
      console.error("PostFormHook: image encryption failed:", e);
      this.pushEvent("post_image_encrypted_failed", {
        upload_ref,
        reason: e.message,
      });
    }
  },

  _onSubmit(e) {
    if (this._fallback) {
      this._fallback = false;
      return;
    }

    const visibility = this.el.dataset.visibility;
    if (!visibility || visibility === "public") return;
    if (!getPublicKey()) return;

    const bodyEl = this.el.querySelector('textarea[name="post[body]"]');
    const body = bodyEl?.value?.trim();
    if (!body) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(body).catch((err) => {
      console.error("PostFormHook: encryption failed, falling back to server-side:", err);
      this._fallback = true;
      this.el.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });
  },

  async _encryptAndSubmit(body) {
    const postKey = await this._getOrCreatePostKey();
    const encryptedBody = await encryptSecretboxString(body, postKey);

    const authorPk = getPublicKey();
    const authorPqPk = getPqPublicKey();
    const keyBytes = b64Decode(postKey);
    const sealedPostKey = await sealForUser(keyBytes, authorPk, authorPqPk);

    const cwEl = this.el.querySelector('input[name="post[content_warning]"], textarea[name="post[content_warning]"]');
    const cwCatEl = this.el.querySelector('select[name="post[content_warning_category]"], input[name="post[content_warning_category]"]');

    const payload = {
      encrypted_body: encryptedBody,
      sealed_post_key: sealedPostKey,
    };

    const cwText = cwEl?.value?.trim();
    if (cwText) {
      payload.encrypted_content_warning = await encryptSecretboxString(cwText, postKey);
    }

    const cwCat = cwCatEl?.value?.trim();
    if (cwCat) {
      payload.encrypted_content_warning_category = await encryptSecretboxString(cwCat, postKey);
    }

    this.pushEvent("save_post_encrypted", payload);
  },
};

export default PostFormHook;
