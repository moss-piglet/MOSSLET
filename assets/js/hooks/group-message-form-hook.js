/**
 * GroupMessageFormHook — browser-side group message encryption (zero-knowledge write path).
 *
 * For non-public groups, this hook intercepts the message form submit,
 * unseals the group key, and encrypts the message content before sending.
 * The server receives only ciphertext — it never sees the plaintext.
 *
 * Public groups bypass encryption entirely (server handles it).
 *
 * Data attributes on the form:
 *   data-public         — "true" for public groups (skip encryption)
 *   data-sealed-group-key — base64 sealed group_key
 */
import {
  encryptSecretboxString,
  b64Decode,
} from "../crypto/nacl";
import { unsealContextKey, getPublicKey } from "../crypto/session";

const MENTION_TOKEN_RE = /@\[([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\]/gi;

/**
 * Group keys follow the same double-encoding pattern as post keys.
 */
function unwrapGroupKey(unsealedB64) {
  try {
    return atob(unsealedB64);
  } catch {
    return unsealedB64;
  }
}

function extractMentionIds(text) {
  const ids = [];
  let match;
  while ((match = MENTION_TOKEN_RE.exec(text)) !== null) {
    if (!ids.includes(match[1])) ids.push(match[1]);
  }
  MENTION_TOKEN_RE.lastIndex = 0;
  return ids;
}

const GroupMessageFormHook = {
  mounted() {
    this._fallback = false;
    this._groupKey = null;
    this.el.addEventListener("submit", (e) => this._onSubmit(e), true);
    this._unsealKey();
  },

  updated() {
    if (!this._groupKey) this._unsealKey();
  },

  async _unsealKey() {
    if (this.el.dataset.public === "true") return;
    if (!getPublicKey()) return;

    const sealedKey = this.el.dataset.sealedGroupKey;
    if (!sealedKey) return;

    try {
      const raw = await unsealContextKey(sealedKey);
      if (raw) this._groupKey = unwrapGroupKey(raw);
    } catch (e) {
      console.error("GroupMessageFormHook: failed to unseal group key:", e);
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
      console.error("GroupMessageFormHook: encryption failed, falling back:", err);
      this._fallback = true;
      this.el.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });
  },

  async _encryptAndSubmit(content) {
    const mentionIds = extractMentionIds(content);
    const encryptedContent = await encryptSecretboxString(content, this._groupKey);

    const target = this.el.getAttribute("phx-target");
    const payload = {
      encrypted_content: encryptedContent,
      group_id: this.el.querySelector('input[name="group_message[group_id]"]')?.value,
      sender_id: this.el.querySelector('input[name="group_message[sender_id]"]')?.value,
      mention_ids: mentionIds,
    };

    if (target) {
      this.pushEventTo(target, "save_encrypted", payload);
    } else {
      this.pushEvent("save_encrypted", payload);
    }
  },
};

export default GroupMessageFormHook;
