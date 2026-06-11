import { generateKey, sealForUser, b64Decode } from "../crypto/nacl";

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
        guardian_recipients,
      } = payload;

      try {
        const conversationKey = await generateKey();
        const keyBytes = b64Decode(conversationKey);

        const keyForCurrentUser = await sealForUser(
          keyBytes,
          current_user_public_key,
          current_user_pq_public_key,
        );
        const keyForOtherUser = await sealForUser(
          keyBytes,
          other_user_public_key,
          other_user_pq_public_key,
        );

        const userConversations = [
          { user_id: current_user_id, key: keyForCurrentUser },
          { user_id: other_user_id, key: keyForOtherUser },
        ];

        // Guardianship co-seal (server-authoritative): seal the conversation_key
        // for each active guardian's PUBLIC key, exactly like any other
        // participant. ZK end-to-end — the server never sees the key.
        for (const guardian of guardian_recipients || []) {
          const keyForGuardian = await sealForUser(
            keyBytes,
            guardian.public_key,
            guardian.pq_public_key,
          );
          userConversations.push({
            user_id: guardian.user_id,
            key: keyForGuardian,
          });
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
