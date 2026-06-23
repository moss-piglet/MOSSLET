import { unsealContextKey, decryptWithKey, getPublicKey, unwrapKey } from "../crypto/session";
import { verifyOrPin } from "../crypto/pin_store";

const DecryptConnectionCard = {
  async mounted() {
    this._cache = null;
    this._cachedAttrs = null;
    this._onKeysReady = null;
    this._pinnedFor = null;

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
    } catch (e) {
      console.error("DecryptConnectionCard: TOFU pin failed:", e);
    }
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
