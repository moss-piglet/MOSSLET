import { classifyDataUrl, preloadModel } from "../ai/nsfw-check";

/**
 * NsfwCheck hook — client-side NSFW image classification for upload flows.
 *
 * Listens for "nsfw:check" events from the server with a {data_url} payload,
 * runs NSFWJS classification entirely in the browser, and pushes the result
 * back via "nsfw:result".
 *
 * Model lifecycle events pushed to server (for Logger-based monitoring):
 *   - "nsfw:model_ready" — model loaded successfully
 *   - "nsfw:model_unavailable" — model failed to load (CDN, WebGL, etc.)
 *
 * ## Fail-open design
 *
 * All failure modes result in the upload proceeding (fail-open). This is
 * intentional — the UI always implies NSFW checking is active (deterrent
 * effect) while server-side moderation (LLM vision + Bumblebee fallback)
 * provides a genuine safety net regardless of client-side model state.
 *
 * Failure modes (all fail-open, all silent to user):
 *   1. CDN unreachable — dynamic import() of nsfwjs rejects
 *   2. Model download fails partway — nsfw.load() rejects
 *   3. IndexedDB cache corrupted — validateModel() rejects, re-download attempted
 *   4. Classification throws at runtime — caught in classifyImage/classifyDataUrl
 *   5. No WebGL/WASM backend — TF.js initialization fails
 *
 * When any failure occurs, classifyImage returns {isNSFW: false} and the
 * hook pushes a "safe" nsfw:result. The user sees no indication that the
 * check was skipped — this preserves the deterrent effect.
 *
 * Usage in HEEx:
 *   <div id="nsfw-checker" phx-hook="NsfwCheck" phx-update="ignore"></div>
 */
const NsfwCheck = {
  mounted() {
    this.checkInProgress = false;

    preloadModel((stage, _percent) => {
      if (stage === "model_ready") {
        this.pushEvent("nsfw:model_ready", {});
      }
    }).catch(() => {
      this.pushEvent("nsfw:model_unavailable", {});
    });

    this.handleEvent("nsfw:check", async ({ data_url, check_id }) => {
      if (this.checkInProgress) return;
      this.checkInProgress = true;

      try {
        const result = await classifyDataUrl(data_url);

        this.pushEvent("nsfw:result", {
          check_id: check_id || "default",
          is_nsfw: result.isNSFW,
          reason: result.reason,
          predictions: result.predictions.map((p) => ({
            class: p.className,
            probability: Math.round(p.probability * 1000) / 1000,
          })),
          source: result.source,
          error: result.error || null,
        });
      } catch (error) {
        this.pushEvent("nsfw:result", {
          check_id: check_id || "default",
          is_nsfw: false,
          reason: null,
          predictions: [],
          source: "client",
          error: error.message,
        });
      } finally {
        this.checkInProgress = false;
      }
    });
  },

  destroyed() {},
};

export default NsfwCheck;
