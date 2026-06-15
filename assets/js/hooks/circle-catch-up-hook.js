/**
 * CircleCatchUpHook — give later-joining circle members access to EARLIER files
 * (explicit, never silent — Task #232, see docs/ZK_FILE_SHARING_DESIGN.md §6.2).
 *
 * When someone joins a business circle after a file was shared, they hold no
 * sealed `file_key` for it, so they can't read it. An authorized current reader
 * (the uploader, a circle owner/admin, or an org admin) can explicitly "catch
 * everyone up": their browser unseals each file_key it can read and RE-SEALS it
 * for the members who lack access. The server NEVER sees a raw file_key (I2/I3);
 * the recipient set stays server-authoritative (I1); the action is explicit and
 * surfaced, never automatic.
 *
 * The button uses phx-click="request_catch_up" (handled by the LiveView). This
 * hook only listens for the server's re-seal payload and does the crypto:
 *
 *   Browser → "request_catch_up" (no payload; LiveView authorizes + builds set)
 *   Server  → "reseal_files_for_members" {
 *               files: [{ shared_file_id, sealed_key,
 *                         missing: [{ user_id, public_key, pq_public_key }] }]
 *             }
 *   Browser → "finalize_catch_up_zk" { sealed_entries: [{ shared_file_id,
 *                                       user_id, sealed_key }] }
 *
 * `sealed_key` in the payload is the ACTOR's own sealed copy of the file_key,
 * which only the actor can unseal. The re-sealed entries are sealed for each
 * missing member's public key (Cat-5 hybrid via sealForUser).
 */
import { unsealContextKey, getPublicKey, unwrapKey } from "../crypto/session";
import { sealForUser, b64Decode } from "../crypto/nacl";

const KEY_WAIT_TIMEOUT_MS = 15_000;

const CircleCatchUpHook = {
  mounted() {
    this.handleEvent("reseal_files_for_members", (p) => this._reseal(p));
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  async _reseal({ files }) {
    try {
      if (!getPublicKey()) await this._waitForKeys();

      const list = files || [];
      const sealedEntries = [];

      for (const file of list) {
        // Unseal the actor's own sealed copy of this file's file_key.
        const rawKey = await unsealContextKey(file.sealed_key);
        if (!rawKey) continue;
        const fileKey = unwrapKey(rawKey);
        const keyBytes = b64Decode(fileKey);

        const missing = file.missing || [];
        for (const member of missing) {
          const sealedKey = await sealForUser(
            keyBytes,
            member.public_key,
            member.pq_public_key || null,
          );
          sealedEntries.push({
            shared_file_id: file.shared_file_id,
            user_id: member.user_id,
            sealed_key: sealedKey,
          });
        }
      }

      this.pushEvent("finalize_catch_up_zk", { sealed_entries: sealedEntries });
    } catch (err) {
      console.error("CircleCatchUpHook: re-seal failed:", err);
      this.pushEvent("catch_up_failed", { reason: "reseal" });
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
};

export default CircleCatchUpHook;
