/**
 * SharedFileHook — org-scoped zero-knowledge file sharing (Task #221, see
 * docs/ZK_FILE_SHARING_DESIGN.md).
 *
 * The browser encrypts a file with a per-file `file_key` (NaCl secretbox),
 * uploads the OPAQUE ciphertext to the server (which stores it on object
 * storage without ever seeing the key or plaintext — I2/I3), then seals the
 * `file_key` per recipient with sealForUser (Cat-5 hybrid) against the
 * server-authoritative circle member set (I1). The original filename + a
 * plaintext SHA-256 checksum are encrypted WITH the file_key (so even the name
 * is ZK; recipients verify the checksum after decrypt — I7).
 *
 * Mirrors OrgMembers (seal pattern) + the post-image ZK upload (opaque blob).
 *
 * Hook element (the Files panel wrapper) carries:
 *   data-max-bytes  — server-enforced max file size (defense-in-depth client check)
 *
 * Upload (write path):
 *   Browser → "create_shared_file"  { encrypted_filename, checksum, size_bytes,
 *                                      blob_chunks_total }  (then streams chunks)
 *   Browser → "shared_file_chunk"   { upload_ref, index, total, chunk_b64 }
 *   Server  → "shared_file_created" { shared_file_id, recipients: [{user_id,
 *                                      public_key, pq_public_key}] }
 *   Browser → "finalize_shared_file"{ shared_file_id, sealed_recipients: [...] }
 *
 * Download (read path):
 *   Browser → "request_shared_file" { shared_file_id }
 *   Server  → "shared_file_ready"   { shared_file_id, sealed_key, presigned_url,
 *                                      encrypted_filename, checksum }
 *   Browser fetches the opaque blob, decrypts, verifies checksum, downloads.
 */
import {
  unsealContextKey,
  decryptWithKey,
  encryptWithKey,
  getPublicKey,
  getPqPublicKey,
  unwrapKey,
} from "../crypto/session";
import {
  generateKey,
  sealForUser,
  encryptSecretbox,
  decryptSecretbox,
  b64Decode,
  b64Encode,
} from "../crypto/nacl";
import { guardRecipients } from "../crypto/seal_guard";

// 512 KB of ciphertext per chunk (base64-expanded ~683 KB per event) keeps us
// well within the LiveView channel frame limit while uploading large files.
const CHUNK_BYTES = 512 * 1024;
const KEY_WAIT_TIMEOUT_MS = 15_000;

const SharedFileHook = {
  mounted() {
    this._fileKey = null;
    this._pending = null;

    this.handleEvent("shared_file_created", (p) => this._onCreated(p));
    this.handleEvent("shared_file_ready", (p) => this._onReady(p));

    const input = this.el.querySelector("[data-shared-file-input]");
    if (input) {
      this._onChange = (e) => this._onFileSelected(e);
      input.addEventListener("change", this._onChange);
    }

    this.el.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-download-shared-file]");
      if (btn) {
        e.preventDefault();
        this.pushEvent("request_shared_file", {
          shared_file_id: btn.dataset.downloadSharedFile,
        });
      }
    });
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  // --- Upload (write path) ---

  async _onFileSelected(e) {
    const input = e.target;
    const file = input.files && input.files[0];
    if (!file) return;

    try {
      const maxBytes = parseInt(this.el.dataset.maxBytes || "0", 10);
      if (maxBytes && file.size > maxBytes) {
        this.pushEvent("shared_file_too_large", {
          name: file.name,
          size: file.size,
        });
        input.value = "";
        return;
      }

      if (!getPublicKey()) await this._waitForKeys();

      const bytes = new Uint8Array(await file.arrayBuffer());

      // Per-file symmetric key (never leaves the browser un-sealed).
      const fileKeyB64 = await generateKey();
      this._fileKey = unwrapKey(fileKeyB64);

      // Plaintext SHA-256 (anti-tamper, I7) + filename — both encrypted with
      // the file_key so the server learns neither.
      const checksumHex = await this._sha256Hex(bytes);
      const encryptedChecksum = await encryptWithKey(checksumHex, this._fileKey);
      const encryptedFilename = await encryptWithKey(file.name, this._fileKey);

      // Opaque ciphertext of the file bytes.
      const cipherB64 = await encryptSecretbox(bytes, this._fileKey);

      const chunks = this._chunk(cipherB64, CHUNK_BYTES);
      this._pending = {
        upload_ref: cryptoRandomRef(),
        chunks,
        encrypted_filename: encryptedFilename,
        checksum: encryptedChecksum,
        size_bytes: file.size,
      };

      this.pushEvent("create_shared_file", {
        upload_ref: this._pending.upload_ref,
        encrypted_filename: encryptedFilename,
        checksum: encryptedChecksum,
        size_bytes: file.size,
        blob_chunks_total: chunks.length,
      });

      for (let i = 0; i < chunks.length; i++) {
        this.pushEvent("shared_file_chunk", {
          upload_ref: this._pending.upload_ref,
          index: i,
          total: chunks.length,
          chunk_b64: chunks[i],
        });
      }

      input.value = "";
    } catch (err) {
      console.error("SharedFileHook: upload failed:", err);
      this.pushEvent("shared_file_upload_failed", { reason: "encryption" });
      input.value = "";
    }
  },

  // Server inserted the SharedFile + returned the server-authoritative recipient
  // set (I1). Seal the file_key for each and finalize.
  async _onCreated({ shared_file_id, recipients }) {
    try {
      if (!this._fileKey) return;
      const keyBytes = b64Decode(this._fileKey);
      const list = recipients || [];

      // Verify-before-seal (#294): only seal the file_key for recipients whose
      // served key matches their pinned fingerprint (or is pinned now via TOFU).
      // A mismatched/unverifiable circle member is dropped from the seal set.
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

      this.pushEvent("finalize_shared_file", {
        shared_file_id,
        sealed_recipients,
      });
    } catch (err) {
      console.error("SharedFileHook: sealing failed:", err);
      this.pushEvent("shared_file_upload_failed", { reason: "sealing" });
    } finally {
      this._fileKey = null;
      this._pending = null;
    }
  },

  // --- Download (read path) ---

  async _onReady({
    shared_file_id,
    sealed_key,
    presigned_url,
    encrypted_filename,
    checksum,
  }) {
    try {
      if (!getPublicKey()) await this._waitForKeys();

      const rawKey = await unsealContextKey(sealed_key);
      if (!rawKey) throw new Error("unseal failed");
      const fileKey = unwrapKey(rawKey);

      const resp = await fetch(presigned_url);
      if (!resp.ok) throw new Error("fetch failed: " + resp.status);
      const cipherBytes = new Uint8Array(await resp.arrayBuffer());

      const plainBytes = await decryptSecretbox(b64Encode(cipherBytes), fileKey);

      // Verify integrity (I7): recompute the plaintext checksum and compare.
      let verified = true;
      if (checksum) {
        const expected = await decryptWithKey(checksum, fileKey);
        const actual = await this._sha256Hex(plainBytes);
        verified = expected != null && expected === actual;
      }

      const filename =
        (encrypted_filename &&
          (await decryptWithKey(encrypted_filename, fileKey))) ||
        "download";

      this._triggerDownload(plainBytes, filename);

      this.pushEvent("shared_file_downloaded", {
        shared_file_id,
        verified,
      });
    } catch (err) {
      console.error("SharedFileHook: download failed:", err);
      this.pushEvent("shared_file_download_failed", {
        shared_file_id,
        reason: "decrypt",
      });
    }
  },

  // --- Helpers ---

  _triggerDownload(bytes, filename) {
    const blob = new Blob([bytes], { type: "application/octet-stream" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  },

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

function cryptoRandomRef() {
  const arr = new Uint8Array(16);
  crypto.getRandomValues(arr);
  return Array.from(arr)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * DecryptSharedFileName — renders a shared file's ORIGINAL filename in the Files
 * panel without the server ever seeing it (ZK).
 *
 * The filename was encrypted in the browser with the per-file `file_key`. This
 * hook unseals the viewer's own sealed `file_key` (same path as download), then
 * decrypts the filename and writes it into the row.
 *
 * Hook element carries:
 *   data-sealed-file-key      — the viewer's `file_key`, sealed for their pubkey
 *   data-encrypted-filename   — the filename ciphertext (secretbox w/ file_key)
 * and contains a `[data-shared-filename]` target element.
 */
const DecryptSharedFileName = {
  mounted() {
    this._render();
  },

  updated() {
    this._render();
  },

  async _render() {
    const target = this.el.querySelector("[data-shared-filename]");
    if (!target) return;

    const sealedKey = this.el.dataset.sealedFileKey;
    const encryptedFilename = this.el.dataset.encryptedFilename;
    if (!sealedKey || !encryptedFilename) return;

    try {
      if (!getPublicKey()) await this._waitForKeys();

      const rawKey = await unsealContextKey(sealedKey);
      if (!rawKey) throw new Error("unseal failed");
      const fileKey = unwrapKey(rawKey);

      const name = await decryptWithKey(encryptedFilename, fileKey);
      if (name) {
        target.textContent = name;
        target.setAttribute("title", name);
      } else {
        target.textContent = "Encrypted file";
      }
    } catch (err) {
      console.error("DecryptSharedFileName: failed:", err);
      target.textContent = "Encrypted file";
    }
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

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },
};

export default SharedFileHook;
export { DecryptSharedFileName };
