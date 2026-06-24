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
import { renderQrSvg } from "../crypto/qr";
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
    this._safetyDigits = null;
    this._state = null;
    this._scanning = false;
    this._stream = null;
    this._rafId = null;
    this._detector = null;
    this._lazy = this.el.dataset.lazy === "true";
    this._rendered = false;

    this._onPeerKeyChanged = (e) => {
      if (e && e.detail && e.detail.peerUserId === this.el.dataset.peerUserId) {
        this._render();
      }
    };
    window.addEventListener(PEER_KEY_CHANGED_EVENT, this._onPeerKeyChanged);

    this._wireActions();
    this._initScanSupport();

    // Lazy panels (e.g. inside a connection-card modal) defer the WASM
    // fingerprint compute + pin unseal until the panel is actually opened, so a
    // page full of connection cards doesn't run N crypto computations on load.
    this._onOpen = () => this._ensureRendered();
    this.el.addEventListener("verification:open", this._onOpen);
    this._onClose = () => this._stopScan();
    this.el.addEventListener("verification:close", this._onClose);

    if (!this._lazy) {
      await this._ensureRendered();
    }
  },

  async _ensureRendered() {
    if (this._rendered) return;
    this._rendered = true;
    if (!(await this._render())) {
      this._onKeysReady = () => this._render();
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, { once: true });
    }
  },

  destroyed() {
    this._stopScan();
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
      this._onKeysReady = null;
    }
    if (this._onOpen) this.el.removeEventListener("verification:open", this._onOpen);
    if (this._onClose) this.el.removeEventListener("verification:close", this._onClose);
    window.removeEventListener(PEER_KEY_CHANGED_EVENT, this._onPeerKeyChanged);
  },

  _wireActions() {
    this.el.querySelectorAll('[data-action="verify"]').forEach((btn) => {
      btn.addEventListener("click", () => this._verify("verify_peer_key"));
    });
    this.el.querySelectorAll('[data-action="repin"]').forEach((btn) => {
      btn.addEventListener("click", () => this._verify("repin_peer_key"));
    });
    this.el.querySelectorAll('[data-action="qr-toggle"]').forEach((btn) => {
      btn.addEventListener("click", () => this._toggleQr());
    });
    this.el.querySelectorAll('[data-action="scan-start"]').forEach((btn) => {
      btn.addEventListener("click", () => this._startScan());
    });
    this.el.querySelectorAll('[data-action="scan-stop"]').forEach((btn) => {
      btn.addEventListener("click", () => this._stopScan());
    });
  },

  // BarcodeDetector is the only supported scanner. It's a Chromium-only API
  // (Chrome/Edge on Android, ChromeOS, and macOS); Safari, Firefox, and
  // WebKit-shell browsers like DuckDuckGo don't expose it. Without it (or
  // without a camera) we keep the manual safety-number compare, which is exactly
  // as secure; the scan affordance simply stays hidden.
  _initScanSupport() {
    const supported =
      typeof window.BarcodeDetector !== "undefined" &&
      !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
    this.el.querySelectorAll("[data-scan-supported]").forEach((el) => {
      el.hidden = !supported;
    });
    this.el.querySelectorAll("[data-scan-unsupported]").forEach((el) => {
      el.hidden = supported;
    });
    this._scanSupported = supported;
  },

  _show(state) {
    this._state = state;
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

    const sn = safetyNumber(selfFp, peerFp);
    this._safetyDigits = sn.replace(/\D/g, "");
    this._fill("[data-safety-number]", sn);

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

  // --- QR show / scan-to-verify (EPIC #291 / #302) -------------------------
  // The QR encodes ONLY the viewer's locally-computed safety number (60 digits
  // derived from PUBLIC keys — no secrets). Because the safety number is
  // order-independent, the peer's scanner compares the scanned digits to its
  // OWN computed safety number for the pair. A match is exactly as trustworthy
  // as reading the digits aloud, so it routes into the SAME verify path; a
  // mismatch never auto-trusts.

  _toggleQr() {
    const region = this.el.querySelector("[data-qr-region]");
    if (!region) return;
    const opening = region.hidden;
    region.hidden = !opening;
    if (opening) {
      this._renderQr();
    } else {
      this._stopScan();
    }
  },

  _renderQr() {
    const target = this.el.querySelector("[data-qr-target]");
    if (!target || !this._safetyDigits) return;
    try {
      target.innerHTML = renderQrSvg(this._safetyDigits, {
        title: "Safety number QR code",
      });
    } catch (e) {
      console.error("KeySafetyNumber: QR render failed:", e);
    }
  },

  async _startScan() {
    if (this._scanning || !this._scanSupported || !this._safetyDigits) return;
    this._scanning = true;
    this._setScanState("scanning");
    this._fillScanStatus("");

    const video = this.el.querySelector("[data-qr-video]");
    if (!video) {
      this._scanning = false;
      return;
    }

    try {
      this._detector = new window.BarcodeDetector({ formats: ["qr_code"] });
      this._stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" },
        audio: false,
      });
      video.srcObject = this._stream;
      video.setAttribute("playsinline", "");
      await video.play();
      this._scanLoop(video);
    } catch (e) {
      console.error("KeySafetyNumber: camera/scan start failed:", e);
      this._scanning = false;
      this._setScanState("error");
      this._fillScanStatus(
        "Couldn't start the camera. Check camera permissions, or compare the digits above instead.",
      );
    }
  },

  _scanLoop(video) {
    const tick = async () => {
      if (!this._scanning) return;
      try {
        const codes = await this._detector.detect(video);
        if (codes && codes.length) {
          const raw = (codes[0].rawValue || "").replace(/\D/g, "");
          if (raw) {
            this._onScanResult(raw);
            return;
          }
        }
      } catch {
        // transient detect errors are ignored; keep scanning
      }
      this._rafId = requestAnimationFrame(tick);
    };
    this._rafId = requestAnimationFrame(tick);
  },

  _onScanResult(scannedDigits) {
    this._stopScan();
    if (scannedDigits === this._safetyDigits) {
      this._setScanState("match");
      this._fillScanStatus("");
      // A match is an explicit, out-of-band confirmation: route into the SAME
      // verify path as the manual button (repin when the key has changed).
      const event = this._state === "mismatch" ? "repin_peer_key" : "verify_peer_key";
      this._verify(event);
    } else {
      this._setScanState("mismatch");
      this._fillScanStatus(
        "The scanned code does not match this contact's safety number on your device. Do not trust this key — try again in person, or compare the digits manually.",
      );
    }
  },

  _stopScan() {
    this._scanning = false;
    if (this._rafId) {
      cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }
    if (this._stream) {
      this._stream.getTracks().forEach((t) => t.stop());
      this._stream = null;
    }
    const video = this.el.querySelector("[data-qr-video]");
    if (video) video.srcObject = null;
    this._detector = null;
    if (this._scanState === "scanning") this._setScanState("idle");
  },

  _setScanState(state) {
    this._scanState = state;
    this.el.querySelectorAll("[data-scan-state]").forEach((el) => {
      el.hidden = el.dataset.scanState !== state;
    });
  },

  _fillScanStatus(text) {
    this.el.querySelectorAll("[data-scan-status]").forEach((el) => {
      el.textContent = text;
    });
  },
};

export default KeySafetyNumber;
