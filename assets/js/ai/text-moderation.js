/**
 * Browser-side text moderation using toxic-bert via Transformers.js.
 *
 * Provides a lightweight toxicity check for public post content entirely
 * in the browser — no server round-trip needed for the initial filter.
 *
 * Uses Xenova/toxic-bert (~67MB, cached in browser after first load).
 * Falls open on failure: if the model can't load or classify, the text
 * is approved and the server-side LLM provides backup moderation.
 */

const TRANSFORMERS_CDN =
  "https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.0.2";
const MODEL_NAME = "Xenova/toxic-bert";

let transformersModule = null;
let classifier = null;
let loadingPromise = null;

async function getTransformers() {
  if (transformersModule) return transformersModule;
  transformersModule = await import(TRANSFORMERS_CDN);
  transformersModule.env.allowLocalModels = false;
  transformersModule.env.useBrowserCache = true;
  return transformersModule;
}

/**
 * Load the toxic-bert classifier. Returns the cached instance if already loaded.
 * Non-blocking: call early to pre-warm the model.
 */
async function loadClassifier() {
  if (classifier) return classifier;
  if (loadingPromise) return loadingPromise;

  loadingPromise = (async () => {
    try {
      const { pipeline } = await getTransformers();
      classifier = await pipeline("text-classification", MODEL_NAME);
      return classifier;
    } catch (error) {
      console.warn("Failed to load toxic-bert:", error);
      loadingPromise = null;
      throw error;
    }
  })();

  return loadingPromise;
}

/**
 * Pre-warm the model in the background. Safe to call multiple times.
 */
export function preloadTextModeration() {
  loadClassifier().catch(() => {});
}

/**
 * Classify text for toxicity.
 *
 * @param {string} text - The text to check.
 * @returns {Promise<{approved: boolean, reason: string|null, score: number, source: string}>}
 *
 * Returns {approved: true} if the text passes, or {approved: false, reason: "..."}
 * if the text is likely toxic. Falls open on any failure.
 */
export async function moderateText(text) {
  if (!text || text.trim().length === 0) {
    return { approved: true, reason: null, score: 0, source: "client" };
  }

  try {
    const cls = await loadClassifier();
    const result = await cls(text);
    const toxic = result.find((r) => r.label === "toxic");
    const score = toxic?.score || 0;

    if (score > 0.7) {
      return {
        approved: false,
        reason: "Content may violate community guidelines",
        score,
        source: "client",
      };
    }

    return { approved: true, reason: null, score, source: "client" };
  } catch (error) {
    // Fail open — let the server-side moderation handle it
    console.warn("Client text moderation failed, falling through:", error);
    return { approved: true, reason: null, score: 0, source: "client_error" };
  }
}

/**
 * Dispose the classifier and free resources.
 */
export function disposeTextModeration() {
  if (classifier?.dispose) {
    try {
      classifier.dispose();
    } catch (e) {
      console.warn("Failed to dispose toxic-bert:", e);
    }
  }
  classifier = null;
  loadingPromise = null;
}
