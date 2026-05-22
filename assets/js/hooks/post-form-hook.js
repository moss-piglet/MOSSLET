/**
 * PostFormHook — browser-side post encryption (true zero-knowledge write path).
 *
 * For non-public posts, this hook intercepts the form submit, generates a
 * post_key, encrypts the body and content warning fields with secretbox,
 * and sends them to the server via "save_post_encrypted".
 *
 * The server then responds with "encrypt_post_fields" containing plaintext
 * metadata (username, avatar_url, image paths, url_preview) and recipient
 * public keys. This hook encrypts ALL fields with the post_key, seals the
 * post_key for every recipient (same hybrid PQ pattern as conversations),
 * and sends "finalize_post_encrypted" back. The server stores everything
 * as-is — it NEVER sees the raw post_key.
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

    this.handleEvent("encrypt_post_fields", (payload) => {
      this._encryptFieldsAndFinalize(payload);
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

    const cwEl = this.el.querySelector(
      'input[name="post[content_warning]"], textarea[name="post[content_warning]"]',
    );
    const cwCatEl = this.el.querySelector(
      'select[name="post[content_warning_category]"], input[name="post[content_warning_category]"]',
    );

    const payload = { encrypted_body: encryptedBody };

    const cwText = cwEl?.value?.trim();
    if (cwText) {
      payload.encrypted_content_warning = await encryptSecretboxString(cwText, postKey);
    }

    const cwCat = cwCatEl?.value?.trim();
    if (cwCat) {
      payload.encrypted_content_warning_category = await encryptSecretboxString(cwCat, postKey);
    }

    // Phase 1: send encrypted body + CW to server.
    // Server will respond with "encrypt_post_fields" containing metadata
    // and recipient public keys for Phase 2.
    this.pushEvent("save_post_encrypted", payload);
  },

  /**
   * Phase 2: Server sent back plaintext metadata + recipient public keys.
   * Encrypt ALL fields with post_key, seal post_key for every recipient,
   * and send "finalize_post_encrypted" back.
   */
  async _encryptFieldsAndFinalize(payload) {
    try {
      const postKey = await this._getOrCreatePostKey();

      // Encrypt username
      const encryptedUsername = payload.username
        ? await encryptSecretboxString(payload.username, postKey)
        : null;

      // Encrypt avatar_url
      const encryptedAvatarUrl = payload.avatar_url
        ? await encryptSecretboxString(payload.avatar_url, postKey)
        : null;

      // Encrypt image_urls (array of S3 paths)
      const imageUrls = payload.image_urls || [];
      const encryptedImageUrls = await Promise.all(
        imageUrls.filter((u) => u).map((url) => encryptSecretboxString(url, postKey)),
      );

      // Encrypt image_alt_texts (array of strings)
      const imageAltTexts = payload.image_alt_texts || [];
      const encryptedImageAltTexts = await Promise.all(
        imageAltTexts.filter((t) => t).map((text) => encryptSecretboxString(text, postKey)),
      );

      // Encrypt url_preview (map of string key → string value)
      let encryptedUrlPreview = null;
      if (payload.url_preview && typeof payload.url_preview === "object") {
        const entries = Object.entries(payload.url_preview);
        const encryptedEntries = await Promise.all(
          entries.map(async ([key, value]) => {
            if (typeof value === "string" && value !== "") {
              return [key, await encryptSecretboxString(value, postKey)];
            }
            return [key, value];
          }),
        );
        encryptedUrlPreview = Object.fromEntries(encryptedEntries);
      }

      // Seal post_key for the author
      const authorPk = getPublicKey();
      const authorPqPk = getPqPublicKey();
      const keyBytes = b64Decode(postKey);
      const sealedAuthorKey = await sealForUser(keyBytes, authorPk, authorPqPk);

      // Seal post_key for each recipient (same pattern as start-conversation.js)
      const recipientKeys = payload.recipient_keys || [];
      const sealedRecipientKeys = await Promise.all(
        recipientKeys.map(async (recipient) => ({
          user_id: recipient.user_id,
          sealed_key: await sealForUser(
            keyBytes,
            recipient.public_key,
            recipient.pq_public_key || null,
          ),
        })),
      );

      // Phase 2 complete: send everything back to the server
      this.pushEvent("finalize_post_encrypted", {
        encrypted_username: encryptedUsername,
        encrypted_avatar_url: encryptedAvatarUrl,
        encrypted_image_urls: encryptedImageUrls,
        encrypted_image_alt_texts: encryptedImageAltTexts,
        encrypted_url_preview: encryptedUrlPreview,
        sealed_author_key: sealedAuthorKey,
        sealed_recipient_keys: sealedRecipientKeys,
      });

      // Clear cached post_key after successful submission
      this._postKey = null;
    } catch (err) {
      console.error("PostFormHook: field encryption failed:", err);
      // On failure, the server still has the pending_zk_post_params.
      // The user will need to try submitting again.
    }
  },
};

export default PostFormHook;
