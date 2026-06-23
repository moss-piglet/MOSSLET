/**
 * GuardianAvatarSeal — family guardian safety override seal flow (Task #284).
 *
 * A guardian must be able to see their MANAGED member's PERSONAL avatar so a
 * minor can't obscure their identity behind a misleading org avatar. The
 * personal avatar blob is secretbox-encrypted with the OWNER's `conn_key`, and a
 * guardian has NO personal `UserConnection` to the managed member — so no sealed
 * copy of the managed member's `conn_key` exists for the guardian.
 *
 * This hook runs in the MANAGED member's browser (the only place `conn_key`
 * exists). When the family dashboard pushes `seal_avatar_key_for_guardians` with
 * the active guardianships that still need it (each carrying the guardian's
 * public keys — a server-authoritative recipient set, I1), we:
 *
 *   1. Resolve our own canonical raw `conn_key` (via getConnKey: unseal our
 *      Membership/session sealed conn_key, then unwrap any double-base64).
 *   2. Seal it FOR each guardian's public key via `sealForUser` (Cat-5 hybrid).
 *   3. Push `finalize_managed_avatar_key` with `{sealed: [{guardianship_id,
 *      sealed_key}]}`.
 *
 * The server persists per-guardianship (`Guardianship.managed_avatar_key`). The
 * guardian's browser later unseals it through the EXISTING DecryptAvatar path
 * and decrypts the managed member's LIVE personal avatar. The raw `conn_key` and
 * plaintext avatar never reach the server. Mirrors OrgMembers' seal flow (#225).
 */
import { getConnKey, getPublicKey } from "../crypto/session";
import { sealForUser, b64Decode } from "../crypto/nacl";
import { guardRecipients } from "../crypto/seal_guard";

const GuardianAvatarSeal = {
  mounted() {
    this.handleEvent("seal_avatar_key_for_guardians", (payload) =>
      this._sealForGuardians(payload),
    );
  },

  async _sealForGuardians(payload) {
    const guardians = (payload && payload.guardians) || [];
    if (guardians.length === 0) return;

    if (!getPublicKey()) {
      this._onKeysReady = () => this._sealForGuardians(payload);
      window.addEventListener("mosslet:keys-ready", this._onKeysReady, {
        once: true,
      });
      return;
    }

    try {
      const connKey = await getConnKey();
      if (!connKey) return;

      const keyBytes = b64Decode(connKey);

      // Verify-before-seal (#294): the guardians are peers (keyed by their user
      // id in the unified pin store). Only seal our conn_key for guardians whose
      // served key matches the pinned fingerprint (or is pinned now via TOFU).
      // guardRecipients preserves each object's extra fields (guardianship_id).
      const { sealable, pinsToStore } = await guardRecipients(guardians);

      if (pinsToStore.length > 0) {
        this._push("store_peer_pins", { pins: pinsToStore });
      }

      const sealed = await Promise.all(
        sealable.map(async (g) => {
          const sealedKey = await sealForUser(
            keyBytes,
            g.public_key,
            g.pq_public_key || null,
          );
          return { guardianship_id: g.guardianship_id, sealed_key: sealedKey };
        }),
      );

      this._push("finalize_managed_avatar_key", { sealed });
    } catch (e) {
      console.error("GuardianAvatarSeal: sealing conn_key failed:", e);
    }
  },

  destroyed() {
    if (this._onKeysReady) {
      window.removeEventListener("mosslet:keys-ready", this._onKeysReady);
    }
  },

  _push(event, payload) {
    const target = this.el.getAttribute("phx-target");
    if (target) {
      this.pushEventTo(target, event, payload);
    } else {
      this.pushEvent(event, payload);
    }
  },
};

export default GuardianAvatarSeal;
