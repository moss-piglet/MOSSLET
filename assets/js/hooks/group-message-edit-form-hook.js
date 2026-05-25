/**
 * GroupMessageEditFormHook — browser-side ZK edit for group messages.
 *
 * For non-public groups, this hook:
 * 1. Populates the edit textarea with the already-decrypted message
 *    content from the rendered DOM element (DecryptGroupMessage already
 *    decrypted it)
 * 2. Intercepts form submit, encrypts content with the group key,
 *    and pushes "update_encrypted" with the ciphertext
 *
 * Public groups skip encryption (server handles it via the legacy path).
 *
 * Data attributes on the form:
 *   data-public            — "true" for public groups
 *   data-sealed-group-key  — base64 sealed group_key (non-public only)
 *   data-message-id        — the message ID being edited
 */
import { encryptSecretboxString } from "../crypto/nacl";
import { unsealContextKey, getPublicKey, unwrapKey } from "../crypto/session";

const GroupMessageEditFormHook = {
  mounted() {
    this._groupKey = null;
    this._fallback = false;
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);

    if (this.el.dataset.public !== "true") {
      this._unsealKey();
      this._populateFromDecryptedMessage();
    }
  },

  updated() {
    if (this.el.dataset.public !== "true" && !this._groupKey) {
      this._unsealKey();
    }
    this._populateFromDecryptedMessage();
  },

  async _unsealKey() {
    if (!getPublicKey()) return;

    const sealedKey = this.el.dataset.sealedGroupKey;
    if (!sealedKey) return;

    try {
      const raw = await unsealContextKey(sealedKey);
      if (raw) this._groupKey = unwrapKey(raw);
    } catch (e) {
      console.error("GroupMessageEditFormHook: failed to unseal group key:", e);
    }
  },

  _populateFromDecryptedMessage() {
    const messageId = this.el.dataset.messageId;
    if (!messageId) return;

    const textarea = this.el.querySelector("textarea");
    if (!textarea || textarea.value) return;

    const decryptedEl = document.getElementById(`decrypt-msg-${messageId}`);
    if (decryptedEl) {
      const text = decryptedEl.textContent?.trim();
      if (text && text !== "Decrypting...") {
        textarea.value = text;
      }
    }
  },

  _onSubmit(e) {
    if (this._fallback) {
      this._fallback = false;
      return;
    }

    if (this.el.dataset.public === "true") return;
    if (!this._groupKey) return;

    const textarea = this.el.querySelector("textarea");
    const content = textarea?.value?.trim();
    if (!content) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    this._encryptAndSubmit(content).catch((err) => {
      console.error(
        "GroupMessageEditFormHook: encryption failed, falling back:",
        err,
      );
      textarea.value = content;
      this._fallback = true;
      this.el.dispatchEvent(
        new Event("submit", { bubbles: true, cancelable: true }),
      );
    });
  },

  async _encryptAndSubmit(content) {
    const encryptedContent = await encryptSecretboxString(
      content,
      this._groupKey,
    );

    const target = this.el.getAttribute("phx-target");
    const payload = { encrypted_content: encryptedContent };

    if (target) {
      this.pushEventTo(target, "update_encrypted", payload);
    } else {
      this.pushEvent("update_encrypted", payload);
    }
  },
};

export default GroupMessageEditFormHook;
