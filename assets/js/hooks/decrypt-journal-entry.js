import { getUserKey, decryptWithKey, getPublicKey } from "../crypto/session";
import { renderMarkdown } from "../utils/render-markdown";

const DecryptJournalEntry = {
  async mounted() {
    this._boundDecrypt = () => this.decrypt();

    if (!getPublicKey()) {
      window.addEventListener("mosslet:keys-ready", () => this._init(), {
        once: true,
      });
      return;
    }
    await this._init();
  },

  async _init() {
    await this.decrypt();
    document.addEventListener("phx:update", this._boundDecrypt);
  },

  destroyed() {
    document.removeEventListener("phx:update", this._boundDecrypt);
  },

  async decrypt() {
    const sealedKey = this.el.dataset.sealedUserKey;
    if (!sealedKey) return;

    try {
      const userKey = await getUserKey(sealedKey);
      if (!userKey) return;

      const entryId = this.el.dataset.entryId;
      const encTitle = this.el.dataset.encryptedTitle;
      const encBody = this.el.dataset.encryptedBody;
      const encMood = this.el.dataset.encryptedMood;
      const isForm = this.el.dataset.form === "true";

      let decryptedTitle = null;
      let decryptedBody = null;
      let decryptedMood = null;

      if (encTitle) {
        decryptedTitle = await decryptWithKey(encTitle, userKey);
        if (decryptedTitle && !isForm) {
          this._applyToTargets(
            `[data-decrypt-journal-title="${entryId}"]`,
            decryptedTitle
          );
        }
      }

      if (encBody) {
        decryptedBody = await decryptWithKey(encBody, userKey);
        if (decryptedBody && !isForm) {
          this._applyBody(entryId, decryptedBody);
        }
      }

      if (encMood) {
        decryptedMood = await decryptWithKey(encMood, userKey);
        if (decryptedMood && !isForm) {
          this._applyMoodBadge(entryId, decryptedMood);
        }
      }

      if (isForm) {
        this._applyFormFields(entryId, decryptedTitle, decryptedBody, decryptedMood);
      }
    } catch (e) {
      console.error("DecryptJournalEntry: decryption failed:", e);
    }
  },

  _applyToTargets(selector, text) {
    const targets = document.querySelectorAll(selector);
    for (const el of targets) {
      if (el.classList.contains("privacy-placeholder")) continue;
      el.textContent = text;
    }
  },

  _applyBody(entryId, body) {
    const proseTargets = document.querySelectorAll(
      `[data-decrypt-journal-body-prose="${entryId}"]`
    );
    for (const el of proseTargets) {
      if (el.classList.contains("privacy-placeholder")) continue;
      el.innerHTML = renderMarkdown(body);
    }

    const previewTargets = document.querySelectorAll(
      `[data-decrypt-journal-body-preview="${entryId}"]`
    );
    for (const el of previewTargets) {
      if (el.classList.contains("privacy-placeholder")) continue;
      const maxLen = 300;
      let preview = body;
      if (preview.length > maxLen) {
        preview = preview.slice(0, maxLen).replace(/\s+\S*$/, "") + "...";
      }
      el.innerHTML = renderMarkdown(preview);
    }

    const plainTargets = document.querySelectorAll(
      `[data-decrypt-journal-body="${entryId}"]`
    );
    for (const el of plainTargets) {
      if (el.classList.contains("privacy-placeholder")) continue;
      el.textContent = body;
    }
  },

  _applyMoodBadge(entryId, mood) {
    const targets = document.querySelectorAll(
      `[data-decrypt-journal-mood-badge="${entryId}"]`
    );
    for (const el of targets) {
      const emoji = moodEmoji(mood);
      el.textContent = `${emoji} ${mood}`;
      el.classList.remove("hidden");
    }
  },

  _applyFormFields(entryId, title, body, mood) {
    if (title) {
      const titleInputs = document.querySelectorAll(
        `[data-decrypt-journal-form-title="${entryId}"]`
      );
      for (const el of titleInputs) {
        if (!el.dataset.decryptApplied) {
          el.value = title;
          el.dataset.decryptApplied = "1";
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }
      }
    }

    if (body) {
      const bodyInputs = document.querySelectorAll(
        `[data-decrypt-journal-form-body="${entryId}"]`
      );
      for (const el of bodyInputs) {
        if (!el.dataset.decryptApplied) {
          el.value = body;
          el.dataset.decryptApplied = "1";
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }
      }
    }

    if (mood) {
      const moodInputs = document.querySelectorAll(
        `[data-decrypt-journal-form-mood="${entryId}"]`
      );
      for (const el of moodInputs) {
        if (!el.dataset.decryptApplied) {
          el.value = mood;
          el.dataset.decryptApplied = "1";
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }
      }
    }
  },
};

function moodEmoji(mood) {
  const map = {
    joyful: "\u{1F929}",
    happy: "\u{1F60A}",
    excited: "\u{1F389}",
    hopeful: "\u{1F31F}",
    goodday: "\u2600\uFE0F",
    cheerful: "\u{1F604}",
    elated: "\u{1F970}",
    blissful: "\u{1F60C}",
    optimistic: "\u{1F308}",
    grateful: "\u{1F64F}",
    thankful: "\u{1F499}",
    blessed: "\u2728",
    appreciative: "\u{1F338}",
    fortunate: "\u{1F340}",
    loved: "\u2764\uFE0F",
    loving: "\u{1F497}",
    romantic: "\u{1F339}",
    affectionate: "\u{1F917}",
    tender: "\u{1F495}",
    adoring: "\u{1F618}",
    content: "\u{1F60C}",
    peaceful: "\u{1F54A}\uFE0F",
    serene: "\u{1F33F}",
    calm: "\u{1F30A}",
    relaxed: "\u{1F6CB}\uFE0F",
    tranquil: "\u{1F332}",
    centered: "\u{1F9D8}",
    mellow: "\u{1F33B}",
    cozy: "\u2615",
    energized: "\u26A1",
    refreshed: "\u{1F4AA}",
    alive: "\u{1F525}",
    vibrant: "\u{1F31E}",
    awake: "\u2615",
    invigorated: "\u{1F3C3}",
    inspired: "\u{1F4A1}",
    creative: "\u{1F3A8}",
    curious: "\u{1F50D}",
    confident: "\u{1F451}",
    proud: "\u{1F3C6}",
    accomplished: "\u2705",
    determined: "\u{1F4AA}",
    focused: "\u{1F3AF}",
    ambitious: "\u{1F680}",
    driven: "\u{1F5A5}\uFE0F",
    playful: "\u{1F61C}",
    silly: "\u{1F92A}",
    adventurous: "\u{1F9ED}",
    spontaneous: "\u{1F388}",
    carefree: "\u{1F343}",
    mischievous: "\u{1F608}",
    supported: "\u{1F91D}",
    connected: "\u{1F517}",
    belonging: "\u{1F3E0}",
    understood: "\u{1F4AC}",
    included: "\u{1F465}",
    social: "\u{1F37B}",
    growing: "\u{1F331}",
    grounded: "\u{1F333}",
    breathing: "\u{1F32C}\uFE0F",
    healing: "\u{1F49A}",
    learning: "\u{1F4DA}",
    evolving: "\u{1F98B}",
    patient: "\u{1F54B}",
    neutral: "\u{1F610}",
    tired: "\u{1F634}",
    exhausted: "\u{1F62B}",
    sleepy: "\u{1F62A}",
    fatigued: "\u{1F971}",
    burnedout: "\u{1F6AB}",
    groggy: "\u{1F974}",
    weary: "\u{1F629}",
    bored: "\u{1F611}",
    mixed: "\u{1F615}",
    latenight: "\u{1F319}",
    drained: "\u{1F50B}",
    indifferent: "\u{1F636}",
    okay: "\u{1F44D}",
    meh: "\u{1F612}",
    blah: "\u{1F644}",
    numb: "\u{1F6AB}",
    surprised: "\u{1F62F}",
    amazed: "\u{1F631}",
    shocked: "\u{1F632}",
    astonished: "\u{1F62E}",
    bewildered: "\u{1F635}",
    anxious: "\u{1F630}",
    worried: "\u{1F61F}",
    stressed: "\u{1F625}",
    nervous: "\u{1F616}",
    restless: "\u{1F62C}",
    uneasy: "\u{1F622}",
    tense: "\u{1F624}",
    panicked: "\u{1F628}",
    sad: "\u{1F622}",
    lonely: "\u{1F614}",
    melancholic: "\u{1F31C}",
    heartbroken: "\u{1F494}",
    grieving: "\u{1F62D}",
    down: "\u{1F61E}",
    hopeless: "\u{1F626}",
    disappointed: "\u{1F61E}",
    empty: "\u{1F573}\uFE0F",
    nostalgic: "\u{1F4F7}",
    reminiscing: "\u{1F39E}\uFE0F",
    thoughtful: "\u{1F4AD}",
    contemplative: "\u{1F914}",
    introspective: "\u{1FA9E}",
    pensive: "\u{1F614}",
    wistful: "\u{1F343}",
    frustrated: "\u{1F621}",
    angry: "\u{1F620}",
    overwhelmed: "\u{1F4A5}",
    irritated: "\u{1F624}",
    resentful: "\u{1F92C}",
    bitter: "\u{1F922}",
    annoyed: "\u{1F612}",
    rageful: "\u{1F47F}",
    hurt: "\u{1FA79}",
    embarrassed: "\u{1F633}",
    ashamed: "\u{1F625}",
    insecure: "\u{1F910}",
    exposed: "\u{1F648}",
    fragile: "\u{1F9CA}",
    scared: "\u{1F631}",
    jealous: "\u{1F49A}",
    confused: "\u{1F615}",
    lost: "\u{1F9ED}",
    uncertain: "\u2753",
    conflicted: "\u2696\uFE0F",
    torn: "\u{1F616}",
    doubtful: "\u{1F914}",
    relieved: "\u{1F60C}",
    free: "\u{1F985}",
    liberated: "\u{1F3C4}",
    unburdened: "\u{1F54A}\uFE0F",
    light: "\u2728",
  };
  return map[mood] || "\u{1F60A}";
}

export default DecryptJournalEntry;
