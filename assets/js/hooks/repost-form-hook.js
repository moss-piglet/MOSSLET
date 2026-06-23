/**
 * RepostFormHook — browser-side repost encryption (true zero-knowledge write path).
 *
 * For non-public reposts, this hook handles the encryption flow:
 *
 * Server pushes "repost_encrypt_request" with the original post's encrypted
 * fields + recipient public keys. The hook reads the already-decrypted body
 * from the DecryptPost cache (or unseals the post_key on the fly), generates
 * a new post_key, encrypts body/username/avatar/images/etc, seals the key for
 * all recipients, and pushes "repost_encrypted" back.
 *
 * The server creates the repost using the pre-encrypted blobs and pre-sealed
 * keys — it NEVER sees the raw post_key or plaintext content.
 *
 * If encryption fails, the hook pushes "repost_encrypt_failed" and the server
 * shows an error. There is NO server-side fallback for non-public content —
 * allowing one would break the zero-knowledge guarantee.
 *
 * Public reposts bypass this hook entirely (server handles them, since it
 * needs to read public content anyway for SEO/federation).
 *
 * Hook element: a hidden div rendered on pages with repost capability.
 * Required data attributes: none (all data comes via push_event payloads).
 */
import {
  generateKey,
  encryptSecretboxString,
  sealForUser,
  b64Decode,
} from "../crypto/nacl";
import {
  getPublicKey,
  getPqPublicKey,
  getCachedPostKey,
  unsealContextKey,
  decryptWithKey,
  encryptWithKey,
  unwrapKey,
} from "../crypto/session";
import { guardRecipients } from "../crypto/seal_guard";

const RepostFormHook = {
  mounted() {
    this.handleEvent("repost_encrypt_request", (payload) => {
      this._encryptRepost(payload);
    });
  },

  async _encryptRepost(payload) {
    try {
      const {
        original_post_id,
        encrypted_body,
        encrypted_username: origEncUsername,
        encrypted_avatar_url: origEncAvatar,
        encrypted_image_urls: origEncImageUrls,
        encrypted_image_alt_texts: origEncImageAltTexts,
        encrypted_url_preview: origEncUrlPreview,
        encrypted_content_warning: origEncCw,
        encrypted_content_warning_category: origEncCwCat,
        sealed_post_key,
        recipient_keys,
        repost_type,
        selected_user_ids,
        note,
        encrypted_share_note: preEncryptedNote,
      } = payload;

      // Step 1: Get the original post's decrypted post_key to decrypt fields
      let originalPostKey = getCachedPostKey(original_post_id);

      if (!originalPostKey && sealed_post_key) {
        const unsealed = await unsealContextKey(sealed_post_key);
        if (unsealed) {
          originalPostKey = unwrapKey(unsealed);
        }
      }

      if (!originalPostKey) {
        this.pushEvent("repost_encrypt_failed", { reason: "no_post_key" });
        return;
      }

      // Step 2: Decrypt original fields using the original post_key
      const body = encrypted_body
        ? await decryptWithKey(encrypted_body, originalPostKey)
        : null;
      const username = origEncUsername
        ? await decryptWithKey(origEncUsername, originalPostKey)
        : null;
      const avatarUrl = origEncAvatar
        ? await decryptWithKey(origEncAvatar, originalPostKey)
        : null;

      let imageUrls = [];
      if (origEncImageUrls && Array.isArray(origEncImageUrls)) {
        for (const enc of origEncImageUrls) {
          if (enc) {
            const dec = await decryptWithKey(enc, originalPostKey);
            if (dec) imageUrls.push(dec);
          }
        }
      }

      let imageAltTexts = [];
      if (origEncImageAltTexts && Array.isArray(origEncImageAltTexts)) {
        for (const enc of origEncImageAltTexts) {
          if (enc) {
            const dec = await decryptWithKey(enc, originalPostKey);
            if (dec) imageAltTexts.push(dec);
          }
        }
      }

      let urlPreview = null;
      if (origEncUrlPreview && typeof origEncUrlPreview === "object") {
        urlPreview = {};
        for (const [key, value] of Object.entries(origEncUrlPreview)) {
          if (typeof value === "string" && value !== "") {
            urlPreview[key] = await decryptWithKey(value, originalPostKey);
          } else {
            urlPreview[key] = value;
          }
        }
      }

      let cw = null;
      if (origEncCw) cw = await decryptWithKey(origEncCw, originalPostKey);

      let cwCat = null;
      if (origEncCwCat) cwCat = await decryptWithKey(origEncCwCat, originalPostKey);

      if (!body) {
        this.pushEvent("repost_encrypt_failed", { reason: "decrypt_failed" });
        return;
      }

      // Step 3: Generate a new post_key for the repost
      const newPostKey = await generateKey();

      // Step 4: Encrypt all fields with the new post_key
      const encBody = await encryptSecretboxString(body, newPostKey);
      const encUsername = username
        ? await encryptSecretboxString(username, newPostKey)
        : null;
      const encAvatarUrl = avatarUrl
        ? await encryptSecretboxString(avatarUrl, newPostKey)
        : null;

      const encImageUrls = await Promise.all(
        imageUrls.filter((u) => u).map((url) => encryptSecretboxString(url, newPostKey)),
      );

      const encImageAltTexts = await Promise.all(
        imageAltTexts.filter((t) => t).map((text) => encryptSecretboxString(text, newPostKey)),
      );

      let encUrlPreview = null;
      if (urlPreview && typeof urlPreview === "object") {
        const entries = Object.entries(urlPreview);
        const encEntries = await Promise.all(
          entries.map(async ([key, value]) => {
            if (typeof value === "string" && value !== "") {
              return [key, await encryptSecretboxString(value, newPostKey)];
            }
            return [key, value];
          }),
        );
        encUrlPreview = Object.fromEntries(encEntries);
      }

      let encCw = null;
      if (cw) encCw = await encryptSecretboxString(cw, newPostKey);

      let encCwCat = null;
      if (cwCat) encCwCat = await encryptSecretboxString(cwCat, newPostKey);

      // Encrypt the share note with the new post_key.
      // If the note was pre-encrypted browser-side (with the original post_key),
      // decrypt it first, then re-encrypt with the new key.
      // If it arrived as plaintext (fallback), encrypt directly.
      let encNote = null;
      if (preEncryptedNote) {
        const decNote = await decryptWithKey(preEncryptedNote, originalPostKey);
        if (decNote) {
          encNote = await encryptWithKey(decNote, newPostKey);
        }
      } else if (note && note.trim() !== "") {
        encNote = await encryptWithKey(note, newPostKey);
      }

      // Step 5: Seal the new post_key for the author
      const authorPk = getPublicKey();
      const authorPqPk = getPqPublicKey();
      const keyBytes = b64Decode(newPostKey);
      const sealedAuthorKey = await sealForUser(keyBytes, authorPk, authorPqPk);

      // Step 6: Seal the new post_key for each recipient.
      // Verify-before-seal (#294): drop recipients whose served key fails pin
      // verification; auto-pin first-contact peers and persist them.
      const { sealable, pinsToStore } = await guardRecipients(
        recipient_keys || [],
      );

      if (pinsToStore.length > 0) {
        this.pushEvent("store_peer_pins", { pins: pinsToStore });
      }

      const sealedRecipientKeys = await Promise.all(
        sealable.map(async (r) => ({
          user_id: r.user_id,
          sealed_key: await sealForUser(
            keyBytes,
            r.public_key,
            r.pq_public_key || null,
          ),
        })),
      );

      // Step 7: Push the fully-encrypted repost back to the server
      this.pushEvent("repost_encrypted", {
        original_post_id,
        repost_type,
        selected_user_ids,
        encrypted_body: encBody,
        encrypted_username: encUsername,
        encrypted_avatar_url: encAvatarUrl,
        encrypted_image_urls: encImageUrls,
        encrypted_image_alt_texts: encImageAltTexts,
        encrypted_url_preview: encUrlPreview,
        encrypted_content_warning: encCw,
        encrypted_content_warning_category: encCwCat,
        encrypted_share_note: encNote,
        sealed_author_key: sealedAuthorKey,
        sealed_recipient_keys: sealedRecipientKeys,
      });
    } catch (err) {
      console.error("RepostFormHook: encryption failed:", err);
      this.pushEvent("repost_encrypt_failed", { reason: err.message });
    }
  },
};

export default RepostFormHook;
