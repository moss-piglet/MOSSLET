/**
 * ReplyFormHook — browser-side reply encryption (zero-knowledge write path).
 *
 * For non-public posts, this hook intercepts the reply form submit,
 * reads the cached parent post_key (populated by DecryptPost), and encrypts
 * the reply body + username before sending. The server receives only ciphertext.
 *
 * If the post_key isn't cached (e.g. public post, or DecryptPost hasn't run),
 * the hook falls through to the normal server-side encryption path.
 *
 * Data attributes on the hook element:
 *   data-post-id    — the parent post's ID (for post_key cache lookup)
 *   data-visibility — "public" skips encryption
 *
 * Works for both modal reply forms (PostLive.Replies.FormComponent,
 * GroupLive.Replies.FormComponent) and inline timeline reply composers
 * (ReplyComposerComponent, NestedReplyComposerComponent).
 */
import { encryptSecretboxString } from "../crypto/nacl";
import { getCachedPostKey } from "../crypto/session";

const ReplyFormHook = {
  mounted() {
    this._fallback = false;
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
  },

  _onSubmit(e) {
    if (this._fallback) {
      this._fallback = false;
      return;
    }

    const visibility = this.el.dataset.visibility;
    if (visibility === "public") return;

    const postId = this.el.dataset.postId;
    if (!postId) return;

    const postKey = getCachedPostKey(postId);
    if (!postKey) return;

    const body = this._getReplyBody();
    const username = this._getReplyUsername();
    if (!body || !body.trim()) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(body, username, postKey, postId).catch((err) => {
      console.error("ReplyFormHook: encryption failed, falling back:", err);
      this._fallback = true;
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true })
      );
    });
  },

  async _encryptAndSubmit(body, username, postKey, postId) {
    const encryptedBody = await encryptSecretboxString(body, postKey);
    const encryptedUsername = username
      ? await encryptSecretboxString(username, postKey)
      : null;

    const payload = {
      encrypted_body: encryptedBody,
      encrypted_username: encryptedUsername,
      post_id: postId,
    };

    this._collectHiddenFields(payload);

    const target = this.el.getAttribute("phx-target");
    if (target) {
      this.pushEventTo(target, "save_reply_zk", payload);
    } else {
      this.pushEvent("save_reply_zk", payload);
    }

    this._clearForm();
  },

  _getReplyBody() {
    const trixInput = this.el.querySelector('input[id^="trix-editor"]');
    if (trixInput) return trixInput.value;

    const textarea = this.el.querySelector("textarea");
    if (textarea) return textarea.value;

    const bodyInput = this.el.querySelector(
      'input[name$="[body]"], input[name="reply[body]"]'
    );
    return bodyInput?.value || null;
  },

  _getReplyUsername() {
    const input = this.el.querySelector(
      'input[name$="[username]"], input[name="reply[username]"]'
    );
    return input?.value || null;
  },

  _collectHiddenFields(payload) {
    const fields = [
      "user_id",
      "group_id",
      "visibility",
      "image_urls",
      "parent_reply_id",
    ];
    for (const field of fields) {
      const input = this.el.querySelector(
        `input[name$="[${field}]"], input[name="reply[${field}]"]`
      );
      if (input && input.value) {
        payload[field] = input.value;
      }
    }
  },

  _clearForm() {
    const textarea = this.el.querySelector("textarea");
    if (textarea) textarea.value = "";

    const trixInput = this.el.querySelector('input[id^="trix-editor"]');
    if (trixInput) trixInput.value = "";

    const trixEditor = this.el.querySelector("trix-editor");
    if (trixEditor && trixEditor.editor) trixEditor.editor.loadHTML("");
  },
};

export default ReplyFormHook;
