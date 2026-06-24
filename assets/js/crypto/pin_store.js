/**
 * TOFU key-pin store (EPIC #291 / Phase 1 — #293).
 *
 * Tamper-evident Trust-On-First-Use pinning of a peer's hybrid public-key
 * fingerprint. The viewer's browser computes the peer's fingerprint (see
 * ./fingerprint.js) and, on first encounter, seals it under the viewer's
 * user_key (NaCl secretbox) — producing an opaque blob the server stores but
 * can neither read nor forge. On subsequent encounters the browser recomputes
 * the fingerprint from whatever key the server now serves, unseals the pin, and
 * compares. Match → proceed. Mismatch → surfaced as a client-authoritative
 * signal for later phases (#294 verify-before-seal, #295 alert UI).
 *
 * This module is the SINGLE primitive both the connection-card hook (now) and
 * every recipient seal path (#294) consume. The match/mismatch verdict is
 * computed entirely client-side — the server is the adversary in this threat
 * model and is never trusted to report it.
 *
 * ---------------------------------------------------------------------------
 * Defense-in-depth: per-device IndexedDB shadow
 * ---------------------------------------------------------------------------
 * The server stores the sealed pin so it survives across devices (cross-device
 * continuity, ZK-safe). But a malicious server could DELETE a pin to force a
 * silent re-TOFU of a substituted key. To detect that downgrade on a returning
 * device, we ALSO keep a local, per-device shadow of the last-known-good
 * fingerprint. If the server drops the pin but the local shadow disagrees with
 * the freshly served key, we treat it as a mismatch and refuse to re-pin.
 *
 * The shadow stores only a fingerprint (a hash of PUBLIC keys — not secret), in
 * a dedicated IndexedDB DB that is wiped on `mosslet:logout`.
 *
 * The true fix for legitimate-rotation-vs-attack ambiguity is signed key
 * history (mosskeys) — out of scope here. Interim policy (per #291): any change
 * is "needs re-verification", surfaced via out-of-band safety-number compare.
 */

import { computeFingerprint } from "./fingerprint";
import {
  getUserKey,
  getSealedUserKey,
  encryptWithKey,
  decryptWithKey,
} from "./session";

export const PIN_STATUS = {
  PINNED: "pinned", // newly pinned this encounter (TOFU)
  MATCH: "match", // existing pin matches the served key
  MISMATCH: "mismatch", // served key differs from the pin (rotation OR attack)
  UNAVAILABLE: "unavailable", // keys not ready / peer key missing — no verdict
  ERROR: "error", // unexpected failure
};

export const PEER_KEY_CHANGED_EVENT = "mosslet:peer-key-changed";

// ---------------------------------------------------------------------------
// Versioned pin record (EPIC #291 / Phase 3 — #295).
// ---------------------------------------------------------------------------
// The sealed pin blob is a single opaque, viewer-sealed JSON record — NOT a
// bare fingerprint. This keeps the server unable to distinguish a merely-pinned
// pair from an out-of-band-VERIFIED one (no plaintext/null-column targeting
// oracle): every key_pins row is one identical ciphertext. The record is
// versioned so it can evolve toward signed key-history / transparency-log proof
// references (mosskeys / metamorphic-log) without a schema migration.
//
//   v1 = { v: 1, fingerprint: "<b64>", verified: bool, verified_at: "<iso>"|null }
//
// BACKWARD COMPAT: pins written before #295 sealed a bare fingerprint STRING.
// decodePinRecord tolerates that (treats it as { fingerprint, verified: false }).
const PIN_RECORD_VERSION = 1;

/**
 * Decode an unsealed pin payload into a normalized record.
 * Accepts a v1 JSON record or a legacy bare-fingerprint string.
 * @param {string} plaintext - unsealed pin payload
 * @returns {{fingerprint: string, verified: boolean, verifiedAt: string|null}|null}
 */
export function decodePinRecord(plaintext) {
  if (!plaintext || typeof plaintext !== "string") return null;
  const trimmed = plaintext.trim();
  if (trimmed.startsWith("{")) {
    try {
      const rec = JSON.parse(trimmed);
      if (rec && typeof rec.fingerprint === "string") {
        return {
          fingerprint: rec.fingerprint,
          verified: rec.verified === true,
          verifiedAt: typeof rec.verified_at === "string" ? rec.verified_at : null,
        };
      }
    } catch {
      // fall through to legacy handling
    }
  }
  // Legacy: the whole payload is the bare fingerprint.
  return { fingerprint: plaintext, verified: false, verifiedAt: null };
}

/**
 * Encode a normalized pin record to the canonical v1 JSON payload (to be sealed).
 * @param {{fingerprint: string, verified?: boolean, verifiedAt?: string|null}} record
 * @returns {string}
 */
export function encodePinRecord({ fingerprint, verified = false, verifiedAt = null }) {
  return JSON.stringify({
    v: PIN_RECORD_VERSION,
    fingerprint,
    verified: verified === true,
    verified_at: verified ? verifiedAt || new Date().toISOString() : null,
  });
}

// In-memory verdict map keyed by peerUserId, queryable by later phases without a
// server round-trip. Cleared on logout.
const _statusByPeer = new Map();

/**
 * Returns the last computed verdict for a connection, or null if not yet
 * evaluated this session.
 *
 * @param {string} peerUserId
 * @returns {{status: string, fingerprint: string|null, verified: boolean, verifiedAt: string|null} | null}
 */
export function getPinStatus(peerUserId) {
  return _statusByPeer.get(peerUserId) || null;
}

function recordStatus(peerUserId, status, fingerprint, extra = {}) {
  const entry = {
    status,
    fingerprint: fingerprint || null,
    verified: extra.verified === true,
    verifiedAt: extra.verifiedAt || null,
  };
  _statusByPeer.set(peerUserId, entry);
  if (status === PIN_STATUS.MISMATCH) {
    try {
      window.dispatchEvent(
        new CustomEvent(PEER_KEY_CHANGED_EVENT, {
          detail: { peerUserId, status, fingerprint: entry.fingerprint },
        }),
      );
    } catch {
      // best-effort: a failed dispatch must never break the caller
    }
  }
  return entry;
}

/**
 * Verify a peer's served public key against the stored pin, or pin it on first
 * encounter.
 *
 * The caller is responsible for persisting `sealedPinToStore` (when present)
 * back to the server, e.g. via `pushEvent("store_peer_pin", ...)`. This keeps
 * the primitive transport-agnostic so #294 seal paths can reuse it.
 *
 * @param {Object} args
 * @param {string} args.peerUserId - the peer user id the pin is keyed under
 * @param {string|null} args.sealedPin - existing viewer-sealed pin, or null/"" if unpinned
 * @param {string} args.peerPublicKey - peer X25519 public key (base64)
 * @param {string} args.peerPqPublicKey - peer ML-KEM public key (base64)
 * @returns {Promise<{status: string, fingerprint: string|null, sealedPinToStore?: string}>}
 */
export async function verifyOrPin({
  peerUserId,
  sealedPin,
  peerPublicKey,
  peerPqPublicKey,
}) {
  if (!peerUserId || !peerPublicKey || !peerPqPublicKey) {
    return recordStatus(peerUserId, PIN_STATUS.UNAVAILABLE, null);
  }

  let fingerprint;
  try {
    fingerprint = await computeFingerprint(peerPublicKey, peerPqPublicKey);
  } catch (e) {
    console.error("pin_store: fingerprint compute failed:", e);
    return recordStatus(peerUserId, PIN_STATUS.ERROR, null);
  }

  const userKey = await getUserKey(getSealedUserKey());
  if (!userKey) {
    return recordStatus(peerUserId, PIN_STATUS.UNAVAILABLE, fingerprint);
  }

  const shadow = await getShadow(peerUserId);

  // --- Existing server-side pin: unseal and compare -----------------------
  if (sealedPin) {
    let plaintext;
    try {
      plaintext = await decryptWithKey(sealedPin, userKey);
    } catch (e) {
      console.error("pin_store: pin unseal failed:", e);
      return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
    }
    if (!plaintext) {
      return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
    }

    const record = decodePinRecord(plaintext);
    if (!record) {
      return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
    }

    const matches =
      record.fingerprint === fingerprint && (!shadow || shadow === fingerprint);
    if (matches) {
      await putShadow(peerUserId, fingerprint);
      return recordStatus(peerUserId, PIN_STATUS.MATCH, fingerprint, {
        verified: record.verified,
        verifiedAt: record.verifiedAt,
      });
    }
    return recordStatus(peerUserId, PIN_STATUS.MISMATCH, fingerprint);
  }

  // --- No server-side pin -------------------------------------------------
  // If a local shadow exists and disagrees, the server likely dropped a pin to
  // force a re-TOFU of a different key — refuse to silently re-pin.
  if (shadow && shadow !== fingerprint) {
    return recordStatus(peerUserId, PIN_STATUS.MISMATCH, fingerprint);
  }

  // TOFU (or benign re-pin of the same key the shadow already trusts): seal a
  // v1 record (verified:false) under the viewer's user_key and hand it back to
  // the caller for server persistence.
  let sealedPinToStore;
  try {
    sealedPinToStore = await encryptWithKey(
      encodePinRecord({ fingerprint, verified: false }),
      userKey,
    );
  } catch (e) {
    console.error("pin_store: pin seal failed:", e);
    return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
  }
  if (!sealedPinToStore) {
    return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
  }

  await putShadow(peerUserId, fingerprint);
  const entry = recordStatus(peerUserId, PIN_STATUS.PINNED, fingerprint);
  return { ...entry, sealedPinToStore };
}

/**
 * Mark a peer's CURRENT served key as out-of-band verified, or re-verify and
 * re-pin after a key change. Both are explicit, user-initiated actions gated by
 * an out-of-band safety-number comparison in the UI (#295), so they bypass the
 * mismatch/shadow guards: the user is asserting trust in the key the server is
 * serving RIGHT NOW.
 *
 * Recomputes the fingerprint from the served keys, seals a v1 record with
 * verified:true, refreshes the per-device shadow (critical — otherwise a stale
 * shadow would keep flagging MISMATCH after a legitimate rotation), and returns
 * the sealed record for the caller to persist server-side.
 *
 * @param {Object} args
 * @param {string} args.peerUserId
 * @param {string} args.peerPublicKey - peer X25519 public key (base64)
 * @param {string} args.peerPqPublicKey - peer ML-KEM public key (base64)
 * @returns {Promise<{status: string, fingerprint: string|null, verified: boolean, verifiedAt: string|null, sealedPinToStore?: string}>}
 */
export async function markVerified({ peerUserId, peerPublicKey, peerPqPublicKey }) {
  if (!peerUserId || !peerPublicKey || !peerPqPublicKey) {
    return recordStatus(peerUserId, PIN_STATUS.UNAVAILABLE, null);
  }

  let fingerprint;
  try {
    fingerprint = await computeFingerprint(peerPublicKey, peerPqPublicKey);
  } catch (e) {
    console.error("pin_store: fingerprint compute failed:", e);
    return recordStatus(peerUserId, PIN_STATUS.ERROR, null);
  }

  const userKey = await getUserKey(getSealedUserKey());
  if (!userKey) {
    return recordStatus(peerUserId, PIN_STATUS.UNAVAILABLE, fingerprint);
  }

  const verifiedAt = new Date().toISOString();
  let sealedPinToStore;
  try {
    sealedPinToStore = await encryptWithKey(
      encodePinRecord({ fingerprint, verified: true, verifiedAt }),
      userKey,
    );
  } catch (e) {
    console.error("pin_store: verified record seal failed:", e);
    return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
  }
  if (!sealedPinToStore) {
    return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
  }

  await putShadow(peerUserId, fingerprint);
  const entry = recordStatus(peerUserId, PIN_STATUS.MATCH, fingerprint, {
    verified: true,
    verifiedAt,
  });
  return { ...entry, sealedPinToStore };
}

// ---------------------------------------------------------------------------
// Per-device IndexedDB shadow (last-known-good fingerprint per peer user).
// Self-contained DB, wiped on logout. Stores only public-derived fingerprints.
// ---------------------------------------------------------------------------

const SHADOW_DB_NAME = "_mosslet_pins";
const SHADOW_DB_VERSION = 1;
const SHADOW_STORE = "pins";

function openShadowDB() {
  return new Promise((resolve, reject) => {
    let request;
    try {
      request = indexedDB.open(SHADOW_DB_NAME, SHADOW_DB_VERSION);
    } catch (e) {
      return reject(e);
    }
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(SHADOW_STORE)) {
        db.createObjectStore(SHADOW_STORE);
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

/**
 * Read the locally shadowed fingerprint for a peer, or null.
 * Failures resolve to null — the shadow is best-effort hardening, never a gate.
 * @param {string} peerUserId
 * @returns {Promise<string|null>}
 */
export async function getShadow(peerUserId) {
  try {
    const db = await openShadowDB();
    return await new Promise((resolve) => {
      const tx = db.transaction(SHADOW_STORE, "readonly");
      const req = tx.objectStore(SHADOW_STORE).get(peerUserId);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => resolve(null);
    });
  } catch {
    return null;
  }
}

async function putShadow(peerUserId, fingerprint) {
  try {
    const db = await openShadowDB();
    await new Promise((resolve) => {
      const tx = db.transaction(SHADOW_STORE, "readwrite");
      tx.objectStore(SHADOW_STORE).put(fingerprint, peerUserId);
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    });
  } catch {
    // best-effort
  }
}

const SHADOW_DELETE_TIMEOUT_MS = 2000;

/**
 * Wipe the shadow store. Returns a Promise that always resolves.
 * @returns {Promise<void>}
 */
export function clearPinShadow() {
  return new Promise((resolve) => {
    let settled = false;
    const done = () => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve();
    };
    const timer = setTimeout(done, SHADOW_DELETE_TIMEOUT_MS);
    try {
      const request = indexedDB.deleteDatabase(SHADOW_DB_NAME);
      request.onsuccess = done;
      request.onerror = done;
      request.onblocked = done;
    } catch {
      done();
    }
  });
}

window.addEventListener("mosslet:logout", () => {
  _statusByPeer.clear();
  void clearPinShadow();
});
