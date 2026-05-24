/**
 * ZkMoodInsights — browser-side mood insight generation hook.
 *
 * Replaces the server-side flow that decrypted journal entries to generate
 * mood insights via an LLM. Now entries are decrypted client-side (Task #40)
 * and mood patterns are analyzed entirely in the browser.
 *
 * Flow:
 *   1. Server pushes "zk_insights:generate" with sealed entry metadata
 *   2. Hook decrypts entries using cached user key
 *   3. Mood insight generated locally via deterministic pattern analysis
 *   4. Hook pushes insight text back to server for encrypted caching
 *
 * Usage in HEEx:
 *   <div id="zk-mood-insights"
 *        phx-hook="ZkMoodInsights"
 *        phx-update="ignore"
 *        data-sealed-user-key={@sealed_user_key}
 *   ></div>
 */
import { getUserKey, decryptWithKey, getPublicKey } from "../crypto/session";
import { generateMoodInsight } from "../ai/mood-insights";

const ZkMoodInsights = {
  mounted() {
    if (!getPublicKey()) {
      window.addEventListener(
        "mosslet:keys-ready",
        () => this._listenForGenerate(),
        { once: true }
      );
      return;
    }
    this._listenForGenerate();
  },

  _listenForGenerate() {
    this.handleEvent("zk_insights:generate", async (payload) => {
      try {
        const insight = await this._generateInsight(payload);
        this.pushEvent("zk_insights:result", { insight });
      } catch (e) {
        console.error("ZkMoodInsights: generation failed:", e);
        this.pushEvent("zk_insights:result", {
          insight:
            "Keep journaling! Your writing practice is building a meaningful record of your inner life.",
        });
      }
    });

    // If entries are already waiting (mounted after server sent event),
    // notify the server we're ready
    this.pushEvent("zk_insights:ready", {});
  },

  async _generateInsight({ entries }) {
    const sealedKey = this.el.dataset.sealedUserKey;
    if (!sealedKey || !entries || entries.length === 0) {
      return "Start journaling to see mood insights! Write a few entries and I'll help identify patterns.";
    }

    const userKey = await getUserKey(sealedKey);
    if (!userKey) {
      return "Keep journaling! Your writing practice is building a meaningful record of your inner life.";
    }

    // Decrypt mood for each entry (date and word_count are plaintext)
    const decryptedEntries = await Promise.all(
      entries.map(async (entry) => {
        let mood = null;
        if (entry.encrypted_mood) {
          try {
            mood = await decryptWithKey(entry.encrypted_mood, userKey);
          } catch {
            // mood decryption failed — skip this mood
          }
        }
        return {
          mood,
          entry_date: entry.entry_date,
          word_count: entry.word_count || 0,
        };
      })
    );

    return generateMoodInsight(decryptedEntries);
  },
};

export default ZkMoodInsights;
