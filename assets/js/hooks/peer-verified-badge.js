/**
 * Read-only peer "verified key" badge (EPIC #291 / Phase 4 — #296).
 *
 * Mirrors the client-side TOFU verification state of a peer (post author) onto
 * dense surfaces like the timeline, WITHOUT performing any pinning, sealing, or
 * server writes — those happen only on the connections / conversation surfaces.
 * The badge element is shown only when the peer's CURRENT served key matches a
 * viewer-sealed pin record that is marked out-of-band `verified`.
 *
 * The server is the adversary in this threat model: it serves the peer public
 * keys AND the opaque sealed pin. This hook recomputes the fingerprint from the
 * served keys, unseals the viewer-sealed record under the viewer's user_key, and
 * decides locally. It also listens to PEER_PIN_STATUS_EVENT so verifying (or a
 * key change) on another surface live-updates the badge with no page reload.
 *
 * DOM contract:
 *   data-peer-user-id, data-peer-public-key, data-peer-pq-public-key,
 *   data-sealed-pin (opaque viewer-sealed v1 record blob)
 * The element starts `hidden`; the hook unhides it only when verified.
 */
import { computeFingerprint } from "../crypto/fingerprint";
import {
  decodePinRecord,
  getPinStatus,
  PIN_STATUS,
  PEER_PIN_STATUS_EVENT,
} from "../crypto/pin_store";
import { getUserKey, getSealedUserKey, decryptWithKey } from "../crypto/session";

const PeerVerifiedBadge = {
  async mounted() {
    this._onKeysReady = null;

    this._onPinStatus = (e) => {
      if (e && e.detail && e.detail.peerUserId === this.el.dataset.peerUserId) {
        this._apply(e.detail);
      }
    };
    window.addEventListener(PEER_PIN_STATUS_EVENT, this._onPinStatus);

    // Prefer a verdict already computed this session (e.g. on the connections
    // page) so we don't redo crypto; otherwise compute it read-only.
    const known = getPinStatus(this.el.dataset.peerUserId);
    if (known) {
      this._apply(known);
    } else if (!(await this._compute())) {
      this._onKeysReady = () => this._compute();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });
    }
  },

  destroyed() {
    window.removeEventListener(PEER_PIN_STATUS_EVENT, this._onPinStatus);
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
      this._onKeysReady = null;
    }
  },

  _apply({ status, verified }) {
    const mismatch = status === PIN_STATUS.MISMATCH;
    this.el.hidden = mismatch || !verified;
  },

  // Read-only verdict: never pins, never writes, never dispatches. Returns true
  // once a definitive state is rendered; false only while the viewer's keys are
  // not yet unsealed (so the caller can retry on mosslet:keys-ready).
  async _compute() {
    const d = this.el.dataset;
    if (!d.peerPublicKey || !d.peerPqPublicKey || !d.sealedPin) {
      this.el.hidden = true;
      return true;
    }

    const userKey = await getUserKey(getSealedUserKey());
    if (!userKey) {
      this.el.hidden = true;
      return false;
    }

    try {
      const [peerFp, plaintext] = await Promise.all([
        computeFingerprint(d.peerPublicKey, d.peerPqPublicKey),
        decryptWithKey(d.sealedPin, userKey),
      ]);
      const record = decodePinRecord(plaintext);
      const verified = !!(record && record.verified && record.fingerprint === peerFp);
      this.el.hidden = !verified;
    } catch (e) {
      console.error("PeerVerifiedBadge: verdict compute failed:", e);
      this.el.hidden = true;
    }
    return true;
  },
};

export default PeerVerifiedBadge;
