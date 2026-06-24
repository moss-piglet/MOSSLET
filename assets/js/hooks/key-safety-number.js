/**
 * Key verification UI hook (EPIC #291 / Phase 3 — #295).
 *
 * Renders the Signal-style safety number for the (viewer, peer) pair, surfaces
 * the TOFU pin state (pinned / out-of-band verified / key-changed), and drives
 * the "Mark as verified" and "Re-verify & re-pin" actions — all client-side.
 *
 * The server is the adversary in this threat model: it serves the peer's public
 * keys AND the opaque sealed pin record. This hook recomputes the fingerprint
 * from whatever keys the server now serves, unseals the viewer-sealed v1 record
 * (under the viewer's user_key), and decides the state locally. The server can
 * neither read nor forge the record, and cannot fake a "verified" badge.
 *
 * DOM contract (set by the key_verification_panel component):
 *   data-peer-user-id, data-peer-public-key, data-peer-pq-public-key,
 *   data-sealed-pin (opaque viewer-sealed v1 record blob, or "")
 *
 * State regions toggled via the `hidden` attribute:
 *   [data-state="loading"|"unverified"|"verified"|"mismatch"|"unavailable"]
 * Fill targets: [data-safety-number], [data-verified-at]
 * Actions (plain DOM buttons): [data-action="verify"], [data-action="repin"]
 */
import { computeFingerprint, safetyNumber } from "../crypto/fingerprint";
import {
  markVerified,
  decodePinRecord,
  PIN_STATUS,
  PEER_KEY_CHANGED_EVENT,
} from "../crypto/pin_store";
import {
  getPublicKey,
  getPqPublicKey,
  getUserKey,
  getSealedUserKey,
  decryptWithKey,
} from "../crypto/session";

const KeySafetyNumber = {
  async mounted() {
    this._busy = false;
    this._onKeysReady = null;
    this._onPeerKeyChanged = (e) => {
      if (e && e.detail && e.detail.peerUserId === this.el.dataset.peerUserId) {
        this._render();
      }
    };
    window.addEventListener(PEER_KEY_CHANGED_EVENT, this._onPeerKeyChanged);

    this._wireActions();

    if (!(await this._render())) {
      this._onKeysReady = () => this._render();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });
    }
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
      this._onKeysReady = null;
    }
    window.removeEventListener(PEER_KEY_CHANGED_EVENT, this._onPeerKeyChanged);
  },

  _wireActions() {
    this.el.querySelectorAll('[data-action="verify"]').forEach((btn) => {
      btn.addEventListener("click", () => this._verify("verify_peer_key"));
    });
    this.el.querySelectorAll('[data-action="repin"]').forEach((btn) => {
      btn.addEventListener("click", () => this._verify("repin_peer_key"));
    });
  },

  _show(state) {
    this.el.querySelectorAll("[data-state]").forEach((el) => {
      el.hidden = el.dataset.state !== state;
    });
  },

  _fill(selector, value) {
    this.el.querySelectorAll(selector).forEach((el) => {
      el.textContent = value;
    });
  },

  // Returns true once a definitive state has been rendered (so the keys-ready
  // retry can stop). Returns false only while the viewer's keys are not ready.
  async _render() {
    const d = this.el.dataset;
    const peerPublicKey = d.peerPublicKey;
    const peerPqPublicKey = d.peerPqPublicKey;

    // Peer can't be fingerprinted (legacy peer without a PQ key yet).
    if (!peerPublicKey || !peerPqPublicKey) {
      this._show("unavailable");
      return true;
    }

    const selfPublicKey = getPublicKey();
    const selfPqPublicKey = getPqPublicKey();
    if (!selfPublicKey || !selfPqPublicKey) {
      this._show("loading");
      return false;
    }

    let selfFp, peerFp;
    try {
      [selfFp, peerFp] = await Promise.all([
        computeFingerprint(selfPublicKey, selfPqPublicKey),
        computeFingerprint(peerPublicKey, peerPqPublicKey),
      ]);
    } catch (e) {
      console.error("KeySafetyNumber: fingerprint compute failed:", e);
      this._show("unavailable");
      return true;
    }

    this._fill("[data-safety-number]", safetyNumber(selfFp, peerFp));

    // Decide pinned / verified / mismatch from the viewer-sealed record.
    const sealedPin = d.sealedPin || "";
    if (!sealedPin) {
      // Not yet pinned server-side (TOFU push may be in flight): treat as
      // pinned-but-unverified — the user can still verify out-of-band.
      this._show("unverified");
      return true;
    }

    const userKey = await getUserKey(getSealedUserKey());
    if (!userKey) {
      this._show("loading");
      return false;
    }

    let record = null;
    try {
      const plaintext = await decryptWithKey(sealedPin, userKey);
      record = decodePinRecord(plaintext);
    } catch (e) {
      console.error("KeySafetyNumber: pin unseal failed:", e);
    }

    if (!record) {
      this._show("unverified");
      return true;
    }

    if (record.fingerprint !== peerFp) {
      // Served key differs from the pinned record: rotation OR substitution.
      this._show("mismatch");
      return true;
    }

    if (record.verified) {
      this._fill("[data-verified-at]", this._formatDate(record.verifiedAt));
      this._show("verified");
    } else {
      this._show("unverified");
    }
    return true;
  },

  async _verify(event) {
    if (this._busy) return;
    this._busy = true;
    const d = this.el.dataset;
    try {
      const result = await markVerified({
        peerUserId: d.peerUserId,
        peerPublicKey: d.peerPublicKey,
        peerPqPublicKey: d.peerPqPublicKey,
      });

      if (result && result.sealedPinToStore && result.status !== PIN_STATUS.ERROR) {
        this.pushEvent(event, {
          peer_user_id: d.peerUserId,
          sealed_pin: result.sealedPinToStore,
        });
        // Reflect the new sealed record locally so the panel updates without a
        // server round-trip (the server write is opaque and fire-and-forget).
        d.sealedPin = result.sealedPinToStore;
        await this._render();
      }
    } catch (e) {
      console.error("KeySafetyNumber: verify failed:", e);
    } finally {
      this._busy = false;
    }
  },

  _formatDate(iso) {
    if (!iso) return "";
    try {
      return new Date(iso).toLocaleDateString(undefined, {
        year: "numeric",
        month: "short",
        day: "numeric",
      });
    } catch {
      return "";
    }
  },
};

export default KeySafetyNumber;
