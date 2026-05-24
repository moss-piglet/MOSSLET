/**
 * Client-side NSFW image classification using NSFWJS + TensorFlow.js.
 *
 * Architecture:
 * - Lazy-loads NSFWJS (which bundles TF.js) from CDN via dynamic import()
 *   (CSP-safe under existing 'unsafe-eval' directive)
 * - Model weights served from our own /models/mobilenet_v2_mid/ (self-hosted)
 * - All inference runs entirely in the browser — zero-knowledge
 * - Model cached in IndexedDB after first load for instant subsequent visits
 * - Uses MobileNetV2Mid (~4.1MB weights, ~93% accuracy, graph model)
 *
 * Fail-open design (intentional):
 *
 * Every public API (classifyImage, classifyDataUrl) catches all errors and
 * returns {isNSFW: false} on failure. This means uploads always proceed when
 * the model is unavailable. This is by design:
 *
 *   - The UI always implies NSFW checking is active, providing a deterrent
 *     effect even when the model hasn't loaded.
 *   - Server-side moderation (LLM vision model + Bumblebee/FLAME fallback)
 *     provides a genuine safety net for all uploaded images regardless of
 *     client-side model state.
 *   - We intentionally do NOT inform the user when the model is unavailable
 *     to preserve the deterrent effect.
 *
 * Failure modes (all silent, all fail-open):
 *   1. CDN unreachable (no internet, CDN down) — import() rejects
 *   2. Model download fails partway — nsfw.load() rejects
 *   3. IndexedDB cache corrupted — validateModel() rejects, re-download
 *      attempted; if that also fails, same as #2
 *   4. Classification throws at runtime — caught in classifyImage
 *   5. No WebGL/WASM backend (TF.js can't initialize) — loadModel throws
 *
 * Uses jsDelivr's +esm endpoint for fully resolved ESM bundles,
 * matching the existing privacy-first-ai.js pattern.
 */

const NSFWJS_ESM = "https://cdn.jsdelivr.net/npm/nsfwjs@4.3.0/+esm";
const MODEL_URL = "/models/mobilenet_v2_mid/model.json";
const INDEXEDDB_KEY = "indexeddb://nsfwjs-mobilenet-v2-mid";

let nsfwModule = null;
let nsfwModel = null;
let loadingPromise = null;

async function ensureNsfwjs() {
  if (nsfwModule) return nsfwModule;
  nsfwModule = await import(NSFWJS_ESM);
  return nsfwModule;
}

/**
 * Validate that a loaded model can actually classify by running a tiny
 * dummy prediction. Catches corrupted or version-mismatched IndexedDB caches.
 */
async function validateModel(model) {
  const nsfw = await ensureNsfwjs();
  const tf = nsfw.NSFWJS ? undefined : await import("https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.22.0/+esm");
  const tfRef = globalThis.tf || tf;
  const dummy = tfRef.zeros([1, 224, 224, 3]);
  try {
    const result = model.model.predict(dummy);
    const data = await result.data();
    result.dispose();
    return data.length === 5;
  } catch {
    return false;
  } finally {
    dummy.dispose();
  }
}

async function loadModel(onProgress) {
  if (nsfwModel) return nsfwModel;
  if (loadingPromise) return loadingPromise;

  loadingPromise = (async () => {
    try {
      const nsfw = await ensureNsfwjs();

      if (onProgress) onProgress("loading_model", 0);

      // Try IndexedDB cache first
      try {
        const cached = await nsfw.load(INDEXEDDB_KEY, { type: "graph" });
        if (await validateModel(cached)) {
          nsfwModel = cached;
          if (onProgress) onProgress("model_ready", 100);
          return nsfwModel;
        }
        // Cached model failed validation — dispose and re-download
        if (cached.model && cached.model.dispose) cached.model.dispose();
      } catch (_e) {
        // IndexedDB cache miss — load from server
      }

      const model = await nsfw.load(MODEL_URL, { type: "graph" });
      nsfwModel = model;

      // Cache to IndexedDB for next visit (non-blocking)
      try {
        if (nsfwModel.model && nsfwModel.model.save) {
          await nsfwModel.model.save(INDEXEDDB_KEY);
        }
      } catch (_e) {
        // IndexedDB save failed — non-critical
      }

      if (onProgress) onProgress("model_ready", 100);
      return nsfwModel;
    } catch (error) {
      // Reset state so next attempt starts fresh
      nsfwModel = null;
      loadingPromise = null;
      throw error;
    }
  })();

  return loadingPromise;
}

/**
 * Classify an image for NSFW content.
 *
 * @param {HTMLImageElement|HTMLCanvasElement|HTMLVideoElement|ImageData} imageInput
 *   The image to classify.
 * @param {Object} [options]
 * @param {Function} [options.onProgress] - Progress callback: (stage, percent)
 * @returns {Promise<{isNSFW: boolean, predictions: Array, reason: string|null}>}
 */
export async function classifyImage(imageInput, options = {}) {
  try {
    const model = await loadModel(options.onProgress);
    const predictions = await model.classify(imageInput, 5);

    const porn = predictions.find((p) => p.className === "Porn");
    const hentai = predictions.find((p) => p.className === "Hentai");
    const sexy = predictions.find((p) => p.className === "Sexy");

    const pornScore = porn ? porn.probability : 0;
    const hentaiScore = hentai ? hentai.probability : 0;
    const sexyScore = sexy ? sexy.probability : 0;

    const isNSFW =
      pornScore > 0.60 ||
      hentaiScore > 0.60 ||
      (pornScore + hentaiScore) > 0.70 ||
      (pornScore + hentaiScore + sexyScore) > 0.85;

    let reason = null;
    if (isNSFW) {
      if (pornScore > hentaiScore) {
        reason = "Image flagged as explicit content.";
      } else {
        reason = "Image flagged as explicit drawn content.";
      }
    }

    return {
      isNSFW,
      predictions,
      reason,
      source: "client",
    };
  } catch (error) {
    // Fail-open: any error (model not loaded, classification crash, WebGL
    // failure, etc.) results in a "safe" verdict. Server-side moderation
    // catches what the client misses. We intentionally do not surface this
    // to the user to preserve the deterrent effect.
    return {
      isNSFW: false,
      predictions: [],
      reason: null,
      source: "client",
      error: error.message,
    };
  }
}

/**
 * Classify a data URL image for NSFW content.
 * Creates a temporary image element, waits for full decode, then classifies.
 *
 * @param {string} dataUrl - data:image/...;base64,... string
 * @param {Object} [options] - Same options as classifyImage
 * @returns {Promise<{isNSFW: boolean, predictions: Array, reason: string|null}>}
 */
export async function classifyDataUrl(dataUrl, options = {}) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = async () => {
      try {
        // Ensure the browser has fully decoded the image pixels before
        // passing to TF.js (onload fires on download, not decode).
        if (img.decode) await img.decode();
      } catch {
        // decode() can reject for certain formats; proceed anyway
      }
      try {
        const result = await classifyImage(img, options);
        resolve(result);
      } catch (error) {
        resolve({
          isNSFW: false,
          predictions: [],
          reason: null,
          source: "client",
          error: error.message,
        });
      }
    };
    img.onerror = () => {
      resolve({
        isNSFW: false,
        predictions: [],
        reason: null,
        source: "client",
        error: "Failed to load image from data URL",
      });
    };
    img.src = dataUrl;
  });
}

/**
 * Pre-warm the model by loading it in the background.
 * Returns a promise that resolves when the model is ready,
 * or rejects if loading fails (CDN unreachable, no WebGL, etc.).
 */
export function preloadModel(onProgress) {
  return loadModel(onProgress);
}

/**
 * Dispose the model and free TF.js tensor resources.
 */
export function disposeModel() {
  if (nsfwModel) {
    // NSFWJS exposes dispose() which cleans up the underlying TF.js model
    // and intermediate models. If not available, dispose the TF model directly.
    if (typeof nsfwModel.dispose === "function") {
      nsfwModel.dispose();
    } else if (nsfwModel.model && typeof nsfwModel.model.dispose === "function") {
      nsfwModel.model.dispose();
    }
    nsfwModel = null;
    loadingPromise = null;
  }
}
