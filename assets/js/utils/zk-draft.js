/**
 * zk-draft — reusable, zero-knowledge client-side draft persistence.
 *
 * Keeps an in-progress composition (a time-capsule letter today; a journal
 * entry tomorrow) from being lost to a page refresh, navigation, or dropped
 * socket — WITHOUT ever letting the server see the plaintext.
 *
 * The zero-knowledge invariant is preserved by encrypting every field with the
 * user's own key (via the existing WASM crypto in ../crypto/session) BEFORE it
 * touches localStorage. Only ciphertext is ever persisted. A wrong/absent key
 * (e.g. a stale draft left by another user on a shared browser) simply fails to
 * decrypt and is discarded — cross-user safety falls out of the crypto for free.
 *
 * The module makes no assumptions about the framework or page structure beyond
 * the field descriptors it is handed. It is deliberately DOM-light so it can be
 * unit-tested and dropped into any composer.
 *
 * Storage envelope (localStorage value):
 *
 *   { "v": 1, "ts": 1731542400000, "fields": { "title": "<ct>", "body": "<ct>", ... } }
 *
 * Empty fields are stored as null (never encrypted). Nothing plaintext is ever
 * written, and drafts are never rendered as HTML — only assigned to input
 * `.value`, so there is no XSS surface.
 *
 * Usage:
 *
 *   const draft = createZkDraft({
 *     key: rawUserKey,                       // base64 symmetric key
 *     storageKey: "mosslet:draft:capsule",
 *     fields: [
 *       { name: "title", el: titleInput },
 *       { name: "body",  el: bodyTextarea },
 *     ],
 *   });
 *   draft.start();                 // wire input + visibility/pagehide + logout
 *   await draft.restore();         // fill empty inputs from a saved draft
 *   // ... on successful submit:
 *   draft.clear();
 *   // ... on teardown (LiveView destroyed()):
 *   draft.stop();
 */
import { encryptWithKey, decryptWithKey } from "../crypto/session";

const DEFAULT_DEBOUNCE_MS = 1000;
const DEFAULT_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000; // 30 days
const ENVELOPE_VERSION = 1;

/**
 * @typedef {Object} ZkDraftField
 * @property {string} name - stable field name used as the envelope key
 * @property {HTMLInputElement|HTMLTextAreaElement} [el] - element to read/write
 * @property {() => string} [get] - custom value reader (defaults to el.value)
 * @property {(value: string) => void} [set] - custom value writer
 *   (defaults to setting el.value + dispatching an `input` event so listeners
 *   such as AutoResize re-fit)
 */

/**
 * @param {Object} opts
 * @param {string} opts.key - base64 symmetric key (e.g. the unsealed user_key)
 * @param {string} opts.storageKey - localStorage key for this composer
 * @param {ZkDraftField[]} opts.fields
 * @param {number} [opts.debounceMs]
 * @param {number} [opts.maxAgeMs] - discard drafts older than this
 * @param {(values: Record<string,string>) => boolean} [opts.canRestore]
 *   - guard deciding whether a restore should overwrite the current inputs.
 *     Receives the CURRENT (live) field values. Defaults to "only when every
 *     field is empty" so we never clobber something the user has already typed.
 */
export function createZkDraft({
  key,
  storageKey,
  fields,
  debounceMs = DEFAULT_DEBOUNCE_MS,
  maxAgeMs = DEFAULT_MAX_AGE_MS,
  canRestore,
}) {
  if (!storageKey) throw new Error("zk-draft: storageKey is required");
  if (!Array.isArray(fields) || fields.length === 0) {
    throw new Error("zk-draft: at least one field is required");
  }

  const readField = (f) => {
    if (typeof f.get === "function") return f.get();
    return f.el ? f.el.value : "";
  };

  const writeField = (f, value) => {
    if (typeof f.set === "function") {
      f.set(value);
      return;
    }
    if (f.el) {
      f.el.value = value;
      // Let hooks that manage their own DOM (e.g. AutoResize) react. Safe even
      // inside phx-update="ignore" containers — we're touching .value, not HTML.
      f.el.dispatchEvent(new Event("input", { bubbles: true }));
    }
  };

  const currentValues = () => {
    const out = {};
    for (const f of fields) out[f.name] = readField(f) || "";
    return out;
  };

  const allEmpty = (values) =>
    Object.values(values).every((v) => !v || !v.trim());

  const restoreGuard = typeof canRestore === "function" ? canRestore : allEmpty;

  let debounceTimer = null;

  async function saveNow() {
    if (!key) return;

    const values = currentValues();

    // Nothing worth persisting — drop any stale draft so we don't restore
    // emptiness over a fresh page later.
    if (allEmpty(values)) {
      clear();
      return;
    }

    try {
      const encryptedFields = {};
      await Promise.all(
        fields.map(async (f) => {
          const raw = values[f.name];
          encryptedFields[f.name] =
            raw && raw.length ? await encryptWithKey(raw, key) : null;
        })
      );

      const envelope = {
        v: ENVELOPE_VERSION,
        ts: Date.now(),
        fields: encryptedFields,
      };

      localStorage.setItem(storageKey, JSON.stringify(envelope));
    } catch (e) {
      // Never surface plaintext; a failed save just means no draft this round.
      console.warn("zk-draft: save failed:", e?.name || "error");
    }
  }

  function scheduleSave() {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      debounceTimer = null;
      void saveNow();
    }, debounceMs);
  }

  function flush() {
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
    // Best-effort, async-safe: we can't await inside pagehide/visibilitychange,
    // but kicking off the encrypt+write is the best we can do without blocking.
    void saveNow();
  }

  function readEnvelope() {
    const raw = localStorage.getItem(storageKey);
    if (!raw) return null;
    try {
      const env = JSON.parse(raw);
      if (!env || env.v !== ENVELOPE_VERSION || !env.fields) return null;
      if (typeof env.ts === "number" && Date.now() - env.ts > maxAgeMs) {
        clear();
        return null;
      }
      return env;
    } catch {
      // Corrupt/old draft — discard rather than crash.
      clear();
      return null;
    }
  }

  /**
   * Decrypts a saved draft and fills the (empty) inputs.
   * @returns {Promise<boolean>} true if a draft was restored
   */
  async function restore() {
    if (!key) return false;

    const env = readEnvelope();
    if (!env) return false;

    // Never clobber whatever the user already has in front of them.
    if (!restoreGuard(currentValues())) return false;

    let restoredAny = false;
    try {
      for (const f of fields) {
        const ct = env.fields[f.name];
        if (!ct) continue;
        const plain = await decryptWithKey(ct, key);
        if (plain == null) {
          // A single field failing to decrypt means the blob is unusable
          // (wrong key / corruption) — discard the whole draft.
          clear();
          return false;
        }
        if (plain.length) {
          writeField(f, plain);
          restoredAny = true;
        }
      }
    } catch (e) {
      console.warn("zk-draft: restore failed:", e?.name || "error");
      clear();
      return false;
    }

    return restoredAny;
  }

  function clear() {
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
    try {
      localStorage.removeItem(storageKey);
    } catch {
      // ignore
    }
  }

  // --- lifecycle wiring -----------------------------------------------------

  const inputHandlers = [];
  let onVisibility = null;
  let onPageHide = null;
  let onLogout = null;
  let started = false;

  function start() {
    if (started) return;
    started = true;

    for (const f of fields) {
      if (!f.el) continue;
      const handler = () => scheduleSave();
      f.el.addEventListener("input", handler);
      inputHandlers.push({ el: f.el, handler });
    }

    onVisibility = () => {
      if (document.visibilityState === "hidden") flush();
    };
    document.addEventListener("visibilitychange", onVisibility);

    onPageHide = () => flush();
    window.addEventListener("pagehide", onPageHide);

    // A draft must not outlive the session's crypto state.
    onLogout = () => clear();
    window.addEventListener("mosslet:logout", onLogout);
  }

  function stop() {
    if (!started) return;
    started = false;

    for (const { el, handler } of inputHandlers) {
      el.removeEventListener("input", handler);
    }
    inputHandlers.length = 0;

    if (onVisibility) {
      document.removeEventListener("visibilitychange", onVisibility);
      onVisibility = null;
    }
    if (onPageHide) {
      window.removeEventListener("pagehide", onPageHide);
      onPageHide = null;
    }
    if (onLogout) {
      window.removeEventListener("mosslet:logout", onLogout);
      onLogout = null;
    }
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
  }

  return {
    saveNow,
    scheduleSave,
    flush,
    restore,
    clear,
    start,
    stop,
  };
}

export default createZkDraft;
