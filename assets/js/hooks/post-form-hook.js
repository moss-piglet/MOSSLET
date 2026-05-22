/**
 * PostFormHook — browser-side post encryption (zero-knowledge write path).
 *
 * For non-public posts, this hook intercepts the form submit, generates a
 * post_key, encrypts the body and content warning fields with secretbox,
 * and seals the post_key for the author. The server receives only encrypted
 * ciphertext — it never sees the plaintext body or content warning.
 *
 * Public posts bypass encryption entirely — the server needs plaintext for
 * AI moderation, SEO rendering, and Bluesky federation.
 *
 * Hook element: the <.form> element with phx-submit="save_post"
 * Required data attributes:
 *   data-visibility — current visibility, kept in sync by the LiveView
 */
import {
  generateKey,
  encryptSecretboxString,
  sealForUser,
  b64Decode,
} from "../crypto/nacl";
import { getPublicKey, getPqPublicKey } from "../crypto/session";

const PostFormHook = {
  mounted() {
    this._fallback = false;
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  _onSubmit(e) {
    if (this._fallback) {
      this._fallback = false;
      return; // let LiveView handle the re-dispatched submit
    }

    const visibility = this.el.dataset.visibility;
    if (!visibility || visibility === "public") return;
    if (!getPublicKey()) return;

    const bodyEl = this.el.querySelector('textarea[name="post[body]"]');
    const body = bodyEl?.value?.trim();
    if (!body) return;

    // Must preventDefault synchronously — async handlers run after the
    // event has already propagated.
    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(body).catch((err) => {
      console.error("PostFormHook: encryption failed, falling back to server-side:", err);
      // Re-dispatch the submit so LiveView's phx-submit="save_post" fires
      this._fallback = true;
      this.el.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });
  },

  async _encryptAndSubmit(body) {
    const postKey = await generateKey();
    const encryptedBody = await encryptSecretboxString(body, postKey);

    const authorPk = getPublicKey();
    const authorPqPk = getPqPublicKey();
    const keyBytes = b64Decode(postKey);
    const sealedPostKey = await sealForUser(keyBytes, authorPk, authorPqPk);

    // Encrypt optional content warning fields if present
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
