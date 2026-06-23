import { generateKey, sealForUser, b64Decode } from "../crypto/nacl";
import { guardRecipients } from "../crypto/seal_guard";

const StartConversation = {
  mounted() {
    this.handleEvent("start-conversation", async (payload) => {
      const {
        user_connection_id,
        current_user_id,
        current_user_public_key,
        current_user_pq_public_key,
        other_user_id,
        other_user_public_key,
        other_user_pq_public_key,
        other_user_sealed_pin,
        guardian_recipients,
      } = payload;

      try {
        const conversationKey = await generateKey();
        const keyBytes = b64Decode(conversationKey);

        // The current user always seals their own copy (no peer check).
        const keyForCurrentUser = await sealForUser(
          keyBytes,
          current_user_public_key,
          current_user_pq_public_key,
        );

        const userConversations = [
          { user_id: current_user_id, key: keyForCurrentUser },
        ];

        // Verify-before-seal (#294): the other participant AND every guardian
        // co-recipient are peers. Only seal the conversation_key for those whose
        // served key matches their pinned fingerprint (or is pinned now via
        // TOFU). A mismatched/unverifiable peer is dropped — the conversation
        // key is never sealed to a possibly-substituted key. Guardianship
        // co-seal stays server-authoritative; pins are keyed by peer user id.
        const peers = [
          {
            user_id: other_user_id,
            public_key: other_user_public_key,
            pq_public_key: other_user_pq_public_key,
            sealed_pin: other_user_sealed_pin || null,
          },
          ...(guardian_recipients || []),
        ];

        const { sealable, pinsToStore } = await guardRecipients(peers);

        if (pinsToStore.length > 0) {
          this.pushEvent("store_peer_pins", { pins: pinsToStore });
        }

        for (const peer of sealable) {
          const sealedKey = await sealForUser(
            keyBytes,
            peer.public_key,
            peer.pq_public_key || null,
          );
          userConversations.push({ user_id: peer.user_id, key: sealedKey });
        }

        this.pushEvent("create_conversation", {
          user_connection_id: user_connection_id,
          user_conversations: userConversations,
        });
      } catch (err) {
        console.error("Failed to generate conversation key:", err);
      }
    });
  },
};

export default StartConversation;
