/**
 * VoiceNotePlayer — plays an end-to-end-encrypted voice note (Task #383, see
 * docs/VOICE_NOTES_DESIGN.md). The read-path mirror of shared-file-hook's
 * download + conversation-hooks' DecryptMessage, with ZERO new crypto.
 *
 * On first play the hook asks the server for the note (authorized on a
 * UserVoiceNote row server-side), receives its own sealed `file_key` + the
 * OPAQUE ciphertext relayed inline, unseals the key, decrypts the audio,
 * verifies the plaintext SHA-256 checksum (I7), and plays it. The server never
 * decrypts (I2).
 *
 * Playback uses the Web Audio API (decodeAudioData → AudioBufferSourceNode)
 * rather than an <audio> element. This is the reliable cross-browser path:
 * WebKit (Safari / DuckDuckGo) cannot play MediaRecorder-produced blobs
 * (webm/opus OR fragmented mp4) through an <audio src=blob:> element — it
 * fails with MEDIA_ERR_SRC_NOT_SUPPORTED — but decodeAudioData decodes those
 * same bytes just fine. Chrome/Firefox also work with this path, and no format
 * change is needed, so existing notes keep working.
 *
 * Hook element carries:
 *   data-voice-note-id   — the VoiceNote id
 *   data-duration-ms     — non-secret scrubber length (fallback)
 * and contains:
 *   [data-voice-play]     — play/pause toggle button
 *   [data-voice-progress] — a range element (0..1000)
 *   [data-voice-elapsed]  — elapsed-time text target
 *   [data-voice-verified] — integrity affordance (revealed on verified play)
 *
 * Read path:
 *   Browser → "request_voice_note" { voice_note_id }  (reply)
 *   Server  → reply { sealed_key, blob (base64 ciphertext), checksum,
 *                     mime_hint, duration_ms }
 */
import {
  unsealContextKey,
  getPublicKey,
  unwrapKey,
} from "../crypto/session";
import { decryptSecretbox, decryptSecretboxToString } from "../crypto/nacl";

const KEY_WAIT_TIMEOUT_MS = 15_000;

// A single shared AudioContext across all player instances. Browsers cap the
// number of concurrent AudioContexts (~6), so we must not create one per
// bubble. It is created/resumed lazily inside a user gesture (first play).
let sharedCtx = null;

function getAudioContext() {
  if (!sharedCtx) {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    sharedCtx = new Ctx();
  }
  return sharedCtx;
}

const VoiceNotePlayer = {
  mounted() {
    this._loading = false;
    this._loaded = false;
    this._playing = false;
    this._seeking = false;

    this._buffer = null; // decoded AudioBuffer
    this._source = null; // current AudioBufferSourceNode
    this._offset = 0; // seconds into the buffer where playback resumes
    this._startedAt = 0; // ctx.currentTime when the current source started
    this._rafId = null;

    this._playBtn = this.el.querySelector("[data-voice-play]");
    this._progress = this.el.querySelector("[data-voice-progress]");
    this._elapsed = this.el.querySelector("[data-voice-elapsed]");

    this._onPlayClick = (e) => {
      e.preventDefault();
      // Create + resume the AudioContext synchronously within the click gesture
      // so WebKit's autoplay policy unlocks it before the async decode.
      const ctx = getAudioContext();
      if (ctx && ctx.state === "suspended") ctx.resume();
      this._togglePlay();
    };
    this._playBtn?.addEventListener("click", this._onPlayClick);

    if (this._progress) {
      this._onSeekInput = () => this._onSeekPreview();
      this._onSeekChange = () => this._onSeekCommit();
      this._progress.addEventListener("input", this._onSeekInput);
      this._progress.addEventListener("change", this._onSeekChange);
    }
  },

  destroyed() {
    this._stopRaf();
    this._stopSource();
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  async _togglePlay() {
    if (this._loaded) {
      if (this._playing) {
        this._pause();
      } else {
        this._play();
      }
      return;
    }

    if (this._loading) return;
    await this._load();
  },

  async _load() {
    const voiceNoteId = this.el.dataset.voiceNoteId;
    if (!voiceNoteId) return;

    this._loading = true;
    this._setState("loading");

    try {
      if (!getPublicKey()) await this._waitForKeys();
    } catch (_e) {
      this._loading = false;
      this._setState("error");
      return;
    }

    this.pushEvent("request_voice_note", { voice_note_id: voiceNoteId }, (reply) =>
      this._onReady(reply),
    );
  },

  async _onReady(reply) {
    try {
      const { sealed_key, blob, checksum } = reply || {};
      if (!sealed_key || !blob) throw new Error("missing payload");

      const rawKey = await unsealContextKey(sealed_key);
      if (!rawKey) throw new Error("unseal failed");
      const fileKey = unwrapKey(rawKey);

      const plainBytes = await decryptSecretbox(blob, fileKey);

      // Verify integrity (I7): recompute the plaintext checksum + compare.
      let verified = true;
      if (checksum) {
        const expected = await decryptSecretboxToString(checksum, fileKey);
        const actual = await this._sha256Hex(plainBytes);
        verified = expected != null && expected === actual;
      }

      const ctx = getAudioContext();
      if (!ctx) throw new Error("no audio context");

      // decodeAudioData detaches the buffer it is given, so hand it a fresh copy
      // (plainBytes may be a view into WASM memory we don't want detached).
      const audioData = plainBytes.slice().buffer;
      this._buffer = await this._decode(ctx, audioData);

      this._loaded = true;
      this._loading = false;
      this._offset = 0;
      this._setState("ready");
      this._setVerified(verified);

      this._play();
    } catch (err) {
      console.error("VoiceNotePlayer: playback failed:", err);
      this._loading = false;
      this._setState("error");
      this.pushEvent("voice_note_play_failed", {
        voice_note_id: this.el.dataset.voiceNoteId,
      });
    }
  },

  _decode(ctx, arrayBuffer) {
    // Promise form is supported everywhere we target, but fall back to the
    // legacy callback form for older WebKit just in case.
    try {
      const maybePromise = ctx.decodeAudioData(arrayBuffer);
      if (maybePromise && typeof maybePromise.then === "function") {
        return maybePromise;
      }
    } catch (_e) {
      // fall through to callback form
    }
    return new Promise((resolve, reject) => {
      ctx.decodeAudioData(arrayBuffer, resolve, reject);
    });
  },

  _play() {
    const ctx = getAudioContext();
    if (!ctx || !this._buffer) return;
    if (ctx.state === "suspended") ctx.resume();

    this._stopSource();

    const source = ctx.createBufferSource();
    source.buffer = this._buffer;
    source.connect(ctx.destination);
    source.onended = () => this._onEnded();

    const offset = Math.min(this._offset, this._buffer.duration);
    source.start(0, offset);

    this._source = source;
    this._startedAt = ctx.currentTime;
    this._setPlaying(true);
    this._startRaf();
  },

  _pause() {
    const ctx = getAudioContext();
    if (ctx && this._source) {
      this._offset = Math.min(
        this._offset + (ctx.currentTime - this._startedAt),
        this._buffer ? this._buffer.duration : this._offset,
      );
    }
    this._stopSource();
    this._setPlaying(false);
    this._stopRaf();
  },

  _stopSource() {
    if (this._source) {
      this._source.onended = null;
      try {
        this._source.stop();
      } catch (_e) {
        // already stopped
      }
      try {
        this._source.disconnect();
      } catch (_e) {
        // ignore
      }
      this._source = null;
    }
  },

  _onEnded() {
    // Natural end (manual stops null out onended first).
    this._offset = 0;
    this._source = null;
    this._setPlaying(false);
    this._stopRaf();
    if (this._progress && !this._seeking) this._progress.value = 0;
    if (this._elapsed) this._elapsed.textContent = formatDuration(0);
  },

  _currentPosition() {
    const ctx = getAudioContext();
    if (this._playing && ctx && this._source) {
      return Math.min(
        this._offset + (ctx.currentTime - this._startedAt),
        this._buffer ? this._buffer.duration : 0,
      );
    }
    return this._offset;
  },

  _startRaf() {
    this._stopRaf();
    const tick = () => {
      this._renderProgress();
      this._rafId = requestAnimationFrame(tick);
    };
    this._rafId = requestAnimationFrame(tick);
  },

  _stopRaf() {
    if (this._rafId) cancelAnimationFrame(this._rafId);
    this._rafId = null;
  },

  _renderProgress() {
    if (!this._buffer) return;
    const duration = this._buffer.duration || 0;
    if (!duration) return;
    const pos = this._currentPosition();
    const ratio = pos / duration;
    if (this._progress && !this._seeking) {
      this._progress.value = Math.round(ratio * 1000);
    }
    if (this._elapsed) {
      this._elapsed.textContent = formatDuration(pos * 1000);
    }
  },

  _onSeekPreview() {
    this._seeking = true;
    if (!this._buffer || !this._elapsed) return;
    const ratio = (parseInt(this._progress.value, 10) || 0) / 1000;
    this._elapsed.textContent = formatDuration(
      ratio * this._buffer.duration * 1000,
    );
  },

  _onSeekCommit() {
    if (!this._buffer) {
      this._seeking = false;
      return;
    }
    const ratio = (parseInt(this._progress.value, 10) || 0) / 1000;
    this._offset = ratio * this._buffer.duration;
    this._seeking = false;
    if (this._playing) this._play();
  },

  _setPlaying(playing) {
    this._playing = playing;
    this.el.dataset.playing = playing ? "true" : "false";
  },

  _setState(state) {
    this.el.dataset.state = state;
  },

  _setVerified(verified) {
    this.el.dataset.verified = verified ? "true" : "false";
  },

  async _sha256Hex(bytes) {
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    return Array.from(new Uint8Array(digest))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
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

export default VoiceNotePlayer;
