const TRANSFORMERS_CDN = "https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.0.2";

const MODELS = {
  textModeration: "Xenova/toxic-bert",
  nsfwDetection: "nickmuchi/yolos-small-finetuned-masks",
};

let transformersModule = null;
let pipelines = {};
let loadingPromises = {};
let activeInstances = 0;

async function getTransformers() {
  if (transformersModule) return transformersModule;
  transformersModule = await import(TRANSFORMERS_CDN);
  transformersModule.env.allowLocalModels = false;
  transformersModule.env.useBrowserCache = true;
  return transformersModule;
}

async function loadPipeline(task, model, options = {}) {
  const key = `${task}:${model}`;
  if (pipelines[key]) return pipelines[key];
  if (loadingPromises[key]) return loadingPromises[key];

  loadingPromises[key] = (async () => {
    try {
      const { pipeline } = await getTransformers();
      pipelines[key] = await pipeline(task, model, {
        progress_callback: (progress) => {
          if (progress.status === "progress") {
            window.dispatchEvent(
              new CustomEvent("ai:model-progress", {
                detail: { task, model, progress: progress.progress },
              })
            );
          }
        },
        ...options,
      });
      return pipelines[key];
    } catch (error) {
      console.error(`Failed to load ${task} pipeline:`, error);
      delete loadingPromises[key];
      throw error;
    }
  })();

  return loadingPromises[key];
}

function disposePipelines() {
  for (const key of Object.keys(pipelines)) {
    try {
      if (pipelines[key]?.dispose) {
        pipelines[key].dispose();
      }
    } catch (e) {
      console.warn(`Failed to dispose pipeline ${key}:`, e);
    }
  }
  pipelines = {};
  loadingPromises = {};
}

async function checkWebGPUSupport() {
  if (!navigator.gpu) return false;
  try {
    const adapter = await navigator.gpu.requestAdapter();
    return !!adapter;
  } catch {
    return false;
  }
}

async function moderateText(text) {
  try {
    const classifier = await loadPipeline(
      "text-classification",
      MODELS.textModeration
    );
    const result = await classifier(text);
    const toxic = result.find((r) => r.label === "toxic");
    return {
      success: true,
      isToxic: toxic && toxic.score > 0.7,
      score: toxic?.score || 0,
      source: "client",
    };
  } catch (error) {
    console.warn("Client moderation failed, will use server fallback:", error);
    return { success: false, error: error.message, source: "client" };
  }
}

async function checkImageNSFW(imageData) {
  try {
    const detector = await loadPipeline(
      "object-detection",
      MODELS.nsfwDetection
    );
    const result = await detector(imageData);
    const nsfwLabels = ["nsfw", "explicit", "nude", "porn"];
    const hasNSFW = result.some(
      (r) => nsfwLabels.includes(r.label.toLowerCase()) && r.score > 0.5
    );
    return { success: true, isNSFW: hasNSFW, detections: result, source: "client" };
  } catch (error) {
    console.warn("Client NSFW check failed, will use server fallback:", error);
    return { success: false, error: error.message, source: "client" };
  }
}

const PrivacyFirstAI = {
  mounted() {
    activeInstances++;
    this.aiReady = false;
    this.pendingRequests = new Map();
    this.capabilities = {
      webgpu: false,
      textModeration: false,
      nsfwDetection: false,
    };

    this.checkCapabilities();

    this.handleEvent("ai:moderate-text", async ({ text, request_id }) => {
      const result = await this.moderateTextWithFallback(text);
      this.pushEvent("ai:moderation-result", { request_id, ...result });
    });

    this.handleEvent("ai:check-nsfw", async ({ image_data, request_id }) => {
      const result = await this.checkNSFWWithFallback(image_data);
      this.pushEvent("ai:nsfw-result", { request_id, ...result });
    });

    this.handleEvent("ai:get-capabilities", () => {
      this.pushEvent("ai:capabilities", this.capabilities);
    });
  },

  destroyed() {
    activeInstances--;
    for (const [, cleanup] of this.pendingRequests) {
      cleanup();
    }
    this.pendingRequests.clear();

    if (activeInstances === 0) {
      disposePipelines();
    }
  },

  async checkCapabilities() {
    this.capabilities.webgpu = await checkWebGPUSupport();
    this.capabilities.textModeration = true;
    this.capabilities.nsfwDetection = true;
    this.aiReady = true;
    this.pushEvent("ai:ready", this.capabilities);
  },

  async moderateTextWithFallback(text) {
    if (this.capabilities.textModeration) {
      const result = await moderateText(text);
      if (result.success) return result;
    }
    return this.serverFallback("moderate_text", { text });
  },

  async checkNSFWWithFallback(imageData) {
    if (this.capabilities.nsfwDetection) {
      const result = await checkImageNSFW(imageData);
      if (result.success) return result;
    }
    return this.serverFallback("check_nsfw", { image_data: imageData });
  },

  async serverFallback(action, params) {
    return new Promise((resolve) => {
      const requestId = crypto.randomUUID();

      const handler = (event) => {
        if (event.detail.request_id === requestId) {
          cleanup();
          resolve({ ...event.detail, source: "server" });
        }
      };

      const timeoutId = setTimeout(() => {
        cleanup();
        resolve({ success: false, error: "Server timeout", source: "server" });
      }, 30000);

      const cleanup = () => {
        window.removeEventListener("ai:server-response", handler);
        clearTimeout(timeoutId);
        this.pendingRequests.delete(requestId);
      };

      this.pendingRequests.set(requestId, cleanup);
      window.addEventListener("ai:server-response", handler);
      this.pushEvent("ai:server-fallback", { action, params, request_id: requestId });
    });
  },
};

export default PrivacyFirstAI;
