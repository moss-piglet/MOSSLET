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

        this.pushEvent("create_conversation", {
          user_connection_id: user_connection_id,
          user_conversations: [
            { user_id: current_user_id, key: keyForCurrentUser },
            { user_id: other_user_id, key: keyForOtherUser },
          ],
        });
      } catch (err) {
        console.error("Failed to generate conversation key:", err);
      }
    });
  },
};

export default StartConversation;
