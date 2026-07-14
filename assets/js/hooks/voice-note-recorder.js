/**
 * VoiceNoteRecorder — end-to-end-encrypted voice notes (Task #383, see
 * docs/VOICE_NOTES_DESIGN.md). Modeled on shared-file-hook.js (the ZK
 * file-sharing write path) with ZERO new crypto.
 *
 * The browser records audio with MediaRecorder, generates a per-note `file_key`
 * (NaCl secretbox), encrypts the audio blob, and uploads the OPAQUE ciphertext
 * to the server (which stores it on object storage without ever seeing the key
 * or plaintext — I2/I3). It then seals the `file_key` per recipient with
 * sealForUser (Cat-5 hybrid) against the server-authoritative cohort member set
 * (I1). A plaintext SHA-256 checksum is encrypted WITH the file_key (recipients
 * verify after decrypt — I7).
 *
 * A short (optional, empty in v1) text caption is encrypted with the cohort's
 * message key (the conversation_key for a DM, the group_key for a group) so the
 * note can be delivered AS a normal stream message referencing its VoiceNote.
 *
 * Graceful fail-open (§4.3): if the device/browser has no mic or no
 * MediaRecorder, the record affordance is disabled with honest copy and text
 * messaging is never broken.
 *
 * Hook element (the composer wrapper) carries:
 *   data-max-bytes        — server-enforced max ciphertext size (client check)
 *   data-max-duration-ms  — server-enforced max duration (client check)
 *   data-cohort           — "conversation" | "group"
 *   data-sealed-key       — the sealed conversation_key OR group_key (caption)
 *   data-group-id         — (group only) the group id
 *   data-sender-id        — (group only) the sender's user_group id
 *
 * Write path:
 *   Browser → "create_voice_note"  { upload_ref, media_type, mime_hint,
 *                                     duration_ms, size_bytes, checksum,
 *                                     blob_chunks_total }  (then streams chunks)
 *   Browser → "voice_note_chunk"   { upload_ref, index, total, chunk_b64 }
 *   Server  → "voice_note_created" { voice_note_id, recipients: [{user_id,
 *                                     public_key, pq_public_key}] }
 *   Browser → "finalize_voice_note"{ voice_note_id, sealed_recipients,
 *                                     encrypted_caption }
 */
import {
  unsealContextKey,
  getConversationKey,
  getPublicKey,
  unwrapKey,
} from "../crypto/session";
import {
  generateKey,
  sealForUser,
  encryptSecretbox,
  encryptSecretboxString,
  encryptDmMessage,
  b64Decode,
} from "../crypto/nacl";
import { guardRecipients } from "../crypto/seal_guard";

const CHUNK_BYTES = 512 * 1024;
const KEY_WAIT_TIMEOUT_MS = 15_000;

const VoiceNoteRecorder = {
  mounted() {
    this._fileKey = null;
    this._pending = null;
    this._recorder = null;
    this._stream = null;
    this._recChunks = [];
    this._startedAt = 0;
    this._timerId = null;
    this._analyser = null;
    this._rafId = null;
    this._audioCtx = null;

    this.handleEvent("voice_note_created", (p) => this._onCreated(p));

    // Capability gating (fail-open). Disable the record affordance with honest
    // copy when the device/browser can't record; never break text messaging.
    if (!this._isSupported()) {
      this.el.dataset.unsupported = "true";
      return;
    }

    this._recordBtn = this.el.querySelector("[data-voice-record]");
    this._stopBtn = this.el.querySelector("[data-voice-stop]");
    this._cancelBtn = this.el.querySelector("[data-voice-cancel]");
    this._timerEl = this.el.querySelector("[data-voice-timer]");
    this._barsEl = this.el.querySelector("[data-voice-bars]");

    this._onRecord = (e) => {
      e.preventDefault();
      this._startRecording();
    };
    this._onStop = (e) => {
      e.preventDefault();
      this._stopRecording(true);
    };
    this._onCancel = (e) => {
      e.preventDefault();
      this._stopRecording(false);
    };

    this._recordBtn?.addEventListener("click", this._onRecord);
    this._stopBtn?.addEventListener("click", this._onStop);
    this._cancelBtn?.addEventListener("click", this._onCancel);
  },

  destroyed() {
    this._teardownStream();
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  _isSupported() {
    return (
      typeof MediaRecorder !== "undefined" &&
      !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia)
    );
  },

  _pickMimeType() {
    const candidates = [
      "audio/webm;codecs=opus",
      "audio/webm",
      "audio/mp4",
      "audio/ogg;codecs=opus",
    ];
    for (const t of candidates) {
      if (MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(t)) {
        return t;
      }
    }
    return "";
  },

  // --- Recording ---

  async _startRecording() {
    if (this._recorder) return;
    try {
      this._stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (err) {
      console.error("VoiceNoteRecorder: mic permission denied:", err);
      this.pushEvent("voice_note_no_mic", {});
      return;
    }

    const mimeType = this._pickMimeType();
    this._mimeType = mimeType;
    this._recChunks = [];

    try {
      this._recorder = mimeType
        ? new MediaRecorder(this._stream, { mimeType })
        : new MediaRecorder(this._stream);
    } catch (err) {
      console.error("VoiceNoteRecorder: MediaRecorder init failed:", err);
      this._teardownStream();
      this.pushEvent("voice_note_upload_failed", { reason: "recorder" });
      return;
    }

    this._recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) this._recChunks.push(e.data);
    };
    this._recorder.onstop = () => this._onRecorderStop();

    this._recorder.start();
    this._startedAt = Date.now();
    this._setState("recording");
    this._startTimer();
    this._startMeter();
  },

  _stopRecording(send) {
    if (!this._recorder) return;
    this._shouldSend = send;
    this._stopTimer();
    this._stopMeter();
    try {
      if (this._recorder.state !== "inactive") this._recorder.stop();
    } catch (_e) {
      // ignore
    }
  },

  async _onRecorderStop() {
    const durationMs = Date.now() - this._startedAt;
    const chunks = this._recChunks;
    this._recorder = null;
    this._teardownStream();
    this._setState("idle");

    if (!this._shouldSend || chunks.length === 0) {
      this._recChunks = [];
      return;
    }

    const blob = new Blob(chunks, { type: this._mimeType || "audio/webm" });
    this._recChunks = [];
    await this._encryptAndUpload(blob, durationMs);
  },

  // --- Encrypt + upload (write path) ---

  async _encryptAndUpload(blob, durationMs) {
    try {
      const maxDuration = parseInt(this.el.dataset.maxDurationMs || "0", 10);
      if (maxDuration && durationMs > maxDuration) {
        this.pushEvent("voice_note_too_long", { duration_ms: durationMs });
        return;
      }

      if (!getPublicKey()) await this._waitForKeys();

      const bytes = new Uint8Array(await blob.arrayBuffer());

      const maxBytes = parseInt(this.el.dataset.maxBytes || "0", 10);

      // Per-note symmetric key (never leaves the browser un-sealed).
      const fileKeyB64 = await generateKey();
      this._fileKey = unwrapKey(fileKeyB64);

      const checksumHex = await this._sha256Hex(bytes);
      const encryptedChecksum = await this._encryptWithFileKey(checksumHex);

      const cipherB64 = await encryptSecretbox(bytes, this._fileKey);

      if (maxBytes && cipherB64.length * 0.75 > maxBytes) {
        this.pushEvent("voice_note_too_long", { size: bytes.length });
        this._fileKey = null;
        return;
      }

      // Optional caption (empty in v1) encrypted with the cohort message key so
      // the note is delivered AS a normal stream message.
      const encryptedCaption = await this._encryptCaption("");

      const chunks = this._chunk(cipherB64, CHUNK_BYTES);
      this._pending = {
        upload_ref: cryptoRandomRef(),
        encrypted_caption: encryptedCaption,
      };

      this.pushEvent("create_voice_note", {
        upload_ref: this._pending.upload_ref,
        media_type: "audio",
        mime_hint: this._mimeType || "audio/webm",
        duration_ms: durationMs,
        size_bytes: bytes.length,
        checksum: encryptedChecksum,
        blob_chunks_total: chunks.length,
      });

      for (let i = 0; i < chunks.length; i++) {
        this.pushEvent("voice_note_chunk", {
          upload_ref: this._pending.upload_ref,
          index: i,
          total: chunks.length,
          chunk_b64: chunks[i],
        });
      }
    } catch (err) {
      console.error("VoiceNoteRecorder: upload failed:", err);
      this.pushEvent("voice_note_upload_failed", { reason: "encryption" });
      this._fileKey = null;
      this._pending = null;
    }
  },

  // Server inserted the VoiceNote + returned the server-authoritative recipient
  // set (I1). Seal the file_key for each and finalize.
  async _onCreated({ voice_note_id, recipients }) {
    try {
      if (!this._fileKey) return;
      const keyBytes = b64Decode(this._fileKey);
      const list = recipients || [];

      // Verify-before-seal (#294): drop any recipient whose served key doesn't
      // match their pinned fingerprint (or pin now via TOFU).
      const { sealable, pinsToStore } = await guardRecipients(list);

      if (pinsToStore.length > 0) {
        this.pushEvent("store_peer_pins", { pins: pinsToStore });
      }

      const sealed_recipients = await Promise.all(
        sealable.map(async (r) => {
          const sealed_key = await sealForUser(
            keyBytes,
            r.public_key,
            r.pq_public_key || null,
          );
          return { user_id: r.user_id, sealed_key };
        }),
      );

      this.pushEvent("finalize_voice_note", {
        voice_note_id,
        sealed_recipients,
        encrypted_caption: this._pending ? this._pending.encrypted_caption : null,
      });
    } catch (err) {
      console.error("VoiceNoteRecorder: sealing failed:", err);
      this.pushEvent("voice_note_upload_failed", { reason: "sealing" });
    } finally {
      this._fileKey = null;
      this._pending = null;
    }
  },

  // --- Caption / key helpers ---

  async _encryptCaption(text) {
    const sealedKey = this.el.dataset.sealedKey;
    const cohort = this.el.dataset.cohort;
    if (!sealedKey) return null;

    try {
      if (cohort === "conversation") {
        const convKey = await getConversationKey(sealedKey);
        return convKey ? await encryptDmMessage(text, convKey) : null;
      }

      const raw = await unsealContextKey(sealedKey);
      if (!raw) return null;
      return await encryptSecretboxString(text, unwrapKey(raw));
    } catch (err) {
      console.error("VoiceNoteRecorder: caption encryption failed:", err);
      return null;
    }
  },

  async _encryptWithFileKey(text) {
    // The file_key is a raw base64 key; secretbox-encrypt the checksum string.
    return await encryptSecretboxString(text, this._fileKey);
  },

  // --- Recording UI feedback ---

  _setState(state) {
    this.el.dataset.recording = state === "recording" ? "true" : "false";
  },

  _startTimer() {
    if (!this._timerEl) return;
    const tick = () => {
      const elapsed = Date.now() - this._startedAt;
      this._timerEl.textContent = formatDuration(elapsed);
      const maxDuration = parseInt(this.el.dataset.maxDurationMs || "0", 10);
      if (maxDuration && elapsed >= maxDuration) this._stopRecording(true);
    };
    tick();
    this._timerId = setInterval(tick, 250);
  },

  _stopTimer() {
    if (this._timerId) clearInterval(this._timerId);
    this._timerId = null;
  },

  _startMeter() {
    if (!this._barsEl || !this._stream) return;
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      this._audioCtx = new Ctx();
      const source = this._audioCtx.createMediaStreamSource(this._stream);
      this._analyser = this._audioCtx.createAnalyser();
      this._analyser.fftSize = 64;
      source.connect(this._analyser);

      const bars = Array.from(this._barsEl.querySelectorAll("[data-voice-bar]"));
      const data = new Uint8Array(this._analyser.frequencyBinCount);

      const draw = () => {
        this._analyser.getByteFrequencyData(data);
        const step = Math.floor(data.length / (bars.length || 1)) || 1;
        bars.forEach((bar, i) => {
          const v = data[i * step] || 0;
          const scale = Math.max(0.15, v / 255);
          bar.style.transform = `scaleY(${scale.toFixed(3)})`;
        });
        this._rafId = requestAnimationFrame(draw);
      };
      draw();
    } catch (_e) {
      // amplitude meter is decorative — ignore failures
    }
  },

  _stopMeter() {
    if (this._rafId) cancelAnimationFrame(this._rafId);
    this._rafId = null;
    if (this._audioCtx) {
      try {
        this._audioCtx.close();
      } catch (_e) {
        // ignore
      }
    }
    this._audioCtx = null;
    this._analyser = null;
  },

  _teardownStream() {
    this._stopMeter();
    this._stopTimer();
    if (this._stream) {
      this._stream.getTracks().forEach((t) => t.stop());
    }
    this._stream = null;
    this._setState("idle");
  },

  // --- Shared helpers ---

  async _sha256Hex(bytes) {
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    return Array.from(new Uint8Array(digest))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
  },

  _chunk(str, size) {
    const out = [];
    for (let i = 0; i < str.length; i += size) {
      out.push(str.slice(i, i + size));
    }
    return out.length ? out : [""];
  },

  _waitForKeys() {
    return new Promise((resolve, reject) => {
      if (getPublicKey()) {
        resolve();
        return;
      }
      const timer = setTimeout(() => {
        if (this._onKeysReady) {
          window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
          this._onKeysReady = null;
        }
        reject(new Error("Timed out waiting for crypto keys"));
      }, KEY_WAIT_TIMEOUT_MS);

      this._onKeysReady = () => {
        clearTimeout(timer);
        this._onKeysReady = null;
        resolve();
      };
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, {
        once: true,
      });
    });
  },
};

function formatDuration(ms) {
  const totalSec = Math.floor(ms / 1000);
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  return `${min}:${sec.toString().padStart(2, "0")}`;
}

function cryptoRandomRef() {
  const arr = new Uint8Array(16);
  crypto.getRandomValues(arr);
  return Array.from(arr)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export default VoiceNoteRecorder;
