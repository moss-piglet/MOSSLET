import { classifyDataUrl, preloadModel, disposeModel } from "../ai/nsfw-check";

/**
 * NsfwCheck hook — client-side NSFW image classification for upload flows.
 *
 * Listens for "nsfw:check" events from the server with a {data_url} payload,
 * runs NSFWJS classification entirely in the browser, and pushes the result
 * back via "nsfw:result".
 *
 * Also pre-loads the model when mounted so it's ready when the user uploads.
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

  destroyed() {
    // Don't dispose model on destroy — it's cached and reusable across navigations
  },
};

export default NsfwCheck;
