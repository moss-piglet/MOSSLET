import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";
import { verifyOrPin, PIN_STATUS, PEER_PIN_STATUS_EVENT } from "../crypto/pin_store";

const DecryptConnectionCard = {
  async mounted() {
    this._cache = null;
    this._cachedAttrs = null;
    this._onKeysReady = null;
    this._pinnedFor = null;

    // Live-sync the card badges when the verdict for THIS peer changes anywhere
    // this session — e.g. the user marks the peer verified (or re-pins after a
    // key change) inside the verification modal. pin_store fires this on every
    // verdict, so the card updates without a page reload (EPIC #291 / #296).
    this._onPinStatus = (e) => {
      if (e && e.detail && e.detail.peerUserId === this.el.dataset.peerUserId) {
        this._applyBadges(e.detail);
      }
    };
    window.addEventListener(PEER_PIN_STATUS_EVENT, this._onPinStatus);

    if (!await this._decrypt()) {
      this._onKeysReady = () => this._decrypt();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });
    }

    this._pin();
  },

  async updated() {
    // The visible target spans live outside this (phx-update-managed) element,
    // so a server re-render resets them to "". Re-apply the cached plaintext if
    // the encrypted attributes are unchanged; otherwise re-decrypt from scratch.
    if (this._cache && this._cachedAttrs === this._attrFingerprint()) {
      this._applyCache();
    } else {
      this._cache = null;
      this._cachedAttrs = null;
      await this._decrypt();
    }
    this._pin();
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
      this._onKeysReady = null;
    }
    window.removeEventListener(PEER_PIN_STATUS_EVENT, this._onPinStatus);
  },

  // TOFU key pinning (EPIC #291 / #293, REVISED — unified key_pins). Compute
  // the peer's fingerprint from the served public keys and verify it against
  // the viewer-sealed pin (or pin it on first encounter), keyed by the PEER's
  // user id (one pin per peer, independent of relationship). When a new pin is
  // produced, persist the opaque blob server-side. Idempotent per
  // (peer-user, peer-key, pin) so re-renders don't re-push.
  async _pin() {
    const d = this.el.dataset;
    const peerUserId = d.peerUserId;
    const peerPublicKey = d.peerPublicKey;
    const peerPqPublicKey = d.peerPqPublicKey;
    if (!peerUserId || !peerPublicKey || !peerPqPublicKey) return;

    const guard = [peerUserId, peerPublicKey, peerPqPublicKey, d.sealedPeerPin || ""].join("|");
    if (this._pinnedFor === guard) return;
    this._pinnedFor = guard;

    try {
      const result = await verifyOrPin({
        peerUserId,
        sealedPin: d.sealedPeerPin || null,
        peerPublicKey,
        peerPqPublicKey,
      });

      if (result && result.sealedPinToStore) {
        this.pushEvent("store_peer_pin", {
          peer_user_id: peerUserId,
          sealed_pin: result.sealedPinToStore,
        });
      }

      this._applyVerifiedBadge(result);
    } catch (e) {
      console.error("DecryptConnectionCard: TOFU pin failed:", e);
    }
  },

  // Reflect the client-determined out-of-band verified state as a read-only
  // badge on the card (EPIC #291 / Phase 3 / #295). The full compare/verify
  // actions live on the connection show page; the card only mirrors the state.
  // The badge element (if present) lives in the card scope, keyed by peer id.
  _applyVerifiedBadge(result) {
    this._applyBadges({
      status: result && result.status,
      verified: !!(result && result.verified),
    });
  },

  // Toggle BOTH the verified (emerald) and key-changed (amber) badges from a
  // verdict, so a card always shows at most one. A mismatch wins over a stale
  // verified flag — a changed key is never "verified" until re-pinned (#296).
  _applyBadges({ status, verified }) {
    const peerUserId = this.el.dataset.peerUserId;
    if (!peerUserId) return;
    const mismatch = status === PIN_STATUS.MISMATCH;

    const verifiedBadge = document.querySelector(
      `[data-conn-verified-badge="${peerUserId}"]`,
    );
    if (verifiedBadge) verifiedBadge.hidden = mismatch || !verified;

    const changedBadge = document.querySelector(
      `[data-conn-keychanged-badge="${peerUserId}"]`,
    );
    if (changedBadge) changedBadge.hidden = !mismatch;
  },

  _attrFingerprint() {
    const d = this.el.dataset;
    return [
      d.sealedUconnKey,
      d.encryptedConnName,
      d.encryptedConnUsername,
      d.encryptedConnLabel,
      d.encryptedConnEmail,
      d.encryptedArrivalName,
      d.encryptedArrivalEmail,
      d.encryptedArrivalLabel,
    ].join("|");
  },

  _scopeEl() {
    const scope = this.el.dataset.connScope;
    return scope
      ? document.querySelector(`[data-conn-scope="${scope}"]`) || this.el.parentElement
      : this.el.parentElement;
  },

  _applyCache() {
    if (!this._cache) return;
    const scopeEl = this._scopeEl();
    if (!scopeEl) return;

    this._cache.forEach(({ selector, value }) => {
      scopeEl.querySelectorAll(selector).forEach((el) => {
        el.textContent = value;
        el.classList.remove("animate-pulse");
      });
    });
  },

  async _decrypt() {
    const sealedKey = this.el.dataset.sealedUconnKey;
    if (!sealedKey) return true;
    if (!getPublicKey()) return false;

    try {
      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) return true;

      const connKey = unwrapKey(rawKey);
      const d = this.el.dataset;

      const fields = [
        ["[data-decrypt-conn-name]", d.encryptedConnName],
        ["[data-decrypt-conn-username]", d.encryptedConnUsername],
        ["[data-decrypt-conn-label]", d.encryptedConnLabel],
        ["[data-decrypt-conn-email]", d.encryptedConnEmail],
        ["[data-decrypt-arrival-name]", d.encryptedArrivalName],
        ["[data-decrypt-arrival-email]", d.encryptedArrivalEmail],
        ["[data-decrypt-arrival-label]", d.encryptedArrivalLabel],
      ];

      const cache = [];

      for (const [selector, encrypted] of fields) {
        if (!encrypted) continue;
        const value = await decryptWithKey(encrypted, connKey);
        if (value) cache.push({ selector, value });
      }

      this._cache = cache;
      this._cachedAttrs = this._attrFingerprint();
      this._applyCache();

      return true;
    } catch (e) {
      console.error("DecryptConnectionCard: decryption failed:", e);
      return true;
    }
  },
};

export default DecryptConnectionCard;
