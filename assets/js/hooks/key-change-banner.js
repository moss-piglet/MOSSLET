/**
 * Connections-page key-change banner (EPIC #291 / Phase 4 — #296).
 *
 * A page-level, honest-disclosure alert that appears whenever ONE OR MORE of the
 * viewer's connections is currently in a TOFU "key changed" (mismatch) state.
 * The inline per-card amber badge tells the viewer WHICH contact changed; this
 * banner makes sure the viewer notices AT ALL without opening each card.
 *
 * Detection is entirely client-side (the server is the adversary in this threat
 * model and is never trusted to report verification state). Every verdict is
 * broadcast by `pin_store` via PEER_PIN_STATUS_EVENT; this hook simply tallies
 * the set of peers currently in mismatch and toggles its own visibility + count.
 * Nothing about who-changed or the verdict is ever sent to the server.
 *
 * DOM contract:
 *   - the hook element is the banner container (hidden by default)
 *   - [data-key-change-count] is filled with the current mismatch count
 *   - [data-key-change-plural] is shown only when count !== 1
 */
import { PEER_PIN_STATUS_EVENT, PIN_STATUS } from "../crypto/pin_store";

const KeyChangeBanner = {
  mounted() {
    this._mismatched = new Set();

    this._onPinStatus = (e) => {
      if (!e || !e.detail || !e.detail.peerUserId) return;
      const { peerUserId, status } = e.detail;
      if (status === PIN_STATUS.MISMATCH) {
        this._mismatched.add(peerUserId);
      } else {
        this._mismatched.delete(peerUserId);
      }
      this._render();
    };
    window.addEventListener(PEER_PIN_STATUS_EVENT, this._onPinStatus);
    this._render();
  },

  destroyed() {
    window.removeEventListener(PEER_PIN_STATUS_EVENT, this._onPinStatus);
  },

  _render() {
    const count = this._mismatched.size;
    this.el.hidden = count === 0;

    this.el.querySelectorAll("[data-key-change-count]").forEach((el) => {
      el.textContent = String(count);
    });
    this.el.querySelectorAll("[data-key-change-plural]").forEach((el) => {
      el.hidden = count === 1;
    });
  },
};

export default KeyChangeBanner;
