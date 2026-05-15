/**
 * PostFormHook — browser-side post body encryption (zero-knowledge write path).
 *
 * For non-public posts, this hook intercepts the form submit, generates a
 * post_key, encrypts the body with secretbox, and seals the post_key for the
 * author. The server receives only encrypted ciphertext — it never sees the
 * plaintext body.
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
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  async _onSubmit(e) {
    const visibility = this.el.dataset.visibility;
    if (!visibility || visibility === "public") return;
    if (!getPublicKey()) return;

    const bodyEl = this.el.querySelector('textarea[name="post[body]"]');
    const body = bodyEl?.value?.trim();
    if (!body) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    try {
      const postKey = await generateKey();
      const encryptedBody = await encryptSecretboxString(body, postKey);

      const authorPk = getPublicKey();
      const authorPqPk = getPqPublicKey();
      const keyBytes = b64Decode(postKey);
      const sealedPostKey = await sealForUser(keyBytes, authorPk, authorPqPk);

      this.pushEvent("save_post_encrypted", {
        encrypted_body: encryptedBody,
        sealed_post_key: sealedPostKey,
      });
    } catch (err) {
      console.error("PostFormHook: encryption failed, falling back to server-side:", err);
    }
  },
};

export default PostFormHook;
