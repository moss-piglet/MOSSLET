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
import {
  parseHistory,
  verifyChain,
  headMatchesServedKeys,
  CHAIN_STATUS,
} from "./key_history";

export const PIN_STATUS = {
  PINNED: "pinned", // newly pinned this encounter (TOFU)
  MATCH: "match", // existing pin matches the served key
  MISMATCH: "mismatch", // served key differs from the pin (rotation OR attack)
  UNAVAILABLE: "unavailable", // keys not ready / peer key missing — no verdict
  ERROR: "error", // unexpected failure
};

export const PEER_KEY_CHANGED_EVENT = "mosslet:peer-key-changed";

// Fired on EVERY status verdict (not just mismatch), so any surface — the
// connection-card badges, the connections-page key-change banner (#296), and the
// timeline verified badge — can live-update without a server round-trip or page
// reload. detail: { peerUserId, status, verified, fingerprint }. Stays ZK-safe:
// it carries only the client-computed verdict + a public-key-derived fingerprint,
// never secret material, and never leaves the browser.
export const PEER_PIN_STATUS_EVENT = "mosslet:peer-pin-status";

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
// v2 (EPIC #291 / #290 step 4 — #315) ADDS signed-key-history monitoring fields:
//
//   v2 = { v: 2, fingerprint, verified, verified_at,
//          root_signing_pub: "<b64>"|null,   // genesis signing key pinned at TOFU
//          head_seq: <int>|null }            // last accepted chain head seq
//
// The root_signing_pub is the cryptographic anchor: once pinned at first
// contact, EVERY later key the server serves must be reachable as a signed,
// hash-chained rotation FROM that root. A valid chain to the served key is a
// legitimate rotation (auto-accept, update head_seq); an invalid/forked chain or
// a head that does not match the served key is a substitution attempt (MISMATCH
// → #296 alert). head_seq lets us recognise forward progress vs. replay.
//
// BACKWARD COMPAT: decodePinRecord tolerates a v1 JSON record (root_signing_pub
// /head_seq absent → null) and a legacy bare-fingerprint STRING (pre-#295).
const PIN_RECORD_VERSION = 2;

/**
 * Decode an unsealed pin payload into a normalized record.
 * Accepts a v2/v1 JSON record or a legacy bare-fingerprint string.
 * @param {string} plaintext - unsealed pin payload
 * @returns {{fingerprint: string, verified: boolean, verifiedAt: string|null, rootSigningPub: string|null, headSeq: number|null}|null}
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
          rootSigningPub:
            typeof rec.root_signing_pub === "string" ? rec.root_signing_pub : null,
          headSeq: Number.isSafeInteger(rec.head_seq) ? rec.head_seq : null,
        };
      }
    } catch {
      // fall through to legacy handling
    }
  }
  // Legacy: the whole payload is the bare fingerprint.
  return {
    fingerprint: plaintext,
    verified: false,
    verifiedAt: null,
    rootSigningPub: null,
    headSeq: null,
  };
}

/**
 * Encode a normalized pin record to the canonical v2 JSON payload (to be sealed).
 * @param {{fingerprint: string, verified?: boolean, verifiedAt?: string|null, rootSigningPub?: string|null, headSeq?: number|null}} record
 * @returns {string}
 */
export function encodePinRecord({
  fingerprint,
  verified = false,
  verifiedAt = null,
  rootSigningPub = null,
  headSeq = null,
}) {
  return JSON.stringify({
    v: PIN_RECORD_VERSION,
    fingerprint,
    verified: verified === true,
    verified_at: verified ? verifiedAt || new Date().toISOString() : null,
    root_signing_pub: rootSigningPub || null,
    head_seq: Number.isSafeInteger(headSeq) ? headSeq : null,
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
    rootSigningPub: extra.rootSigningPub || null,
    headSeq: Number.isSafeInteger(extra.headSeq) ? extra.headSeq : null,
  };
  _statusByPeer.set(peerUserId, entry);
  if (peerUserId) {
    try {
      window.dispatchEvent(
        new CustomEvent(PEER_PIN_STATUS_EVENT, {
          detail: {
            peerUserId,
            status,
            verified: entry.verified,
            fingerprint: entry.fingerprint,
          },
        }),
      );
    } catch {
      // best-effort: a failed dispatch must never break the caller
    }
  }
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
 * MONITOR: chain-validate a peer's signed key history (#290 step 4 / #315) and
 * derive a trust verdict — the real security win over plain TOFU.
 *
 * Given the peer's served encryption keys AND their serialized key-history chain
 * (hydrated server-side; see `MossletWeb.Helpers.hydrate_sealed_pins/2`), this:
 *
 *   - No history available  -> falls back to plain fingerprint TOFU
 *     (`verifyOrPin`), so every existing #293/#295/#302 path keeps working.
 *   - First contact + valid chain to served keys -> TOFU-PIN the genesis ROOT
 *     signing key (+ head_seq). Status PINNED (caller persists the v2 pin).
 *   - Existing v2 pin -> `verifyChain(entries, pinnedRootSigningPub)`:
 *       VALID && head == served keys -> LEGITIMATE ROTATION: auto-accept,
 *         update tracked fingerprint + head_seq, keep the pinned root, status
 *         MATCH, NO alarm (reseals the pin only when something changed).
 *       INVALID / ROOT_MISMATCH / head != served -> SUBSTITUTION: status
 *         MISMATCH, which fires PEER_KEY_CHANGED_EVENT for the #296 alert UI.
 *   - Pre-#315 (v1/legacy) pin + history now present -> opportunistically
 *     upgrade to a v2 pin (adopt the root) IFF the served key matches the
 *     already-trusted fingerprint; a differing fingerprint stays a #293 mismatch.
 *
 * The verdict is computed entirely client-side; the server is never trusted to
 * report it. Returns the same shape as `verifyOrPin` (+ `sealedPinToStore` when
 * a new/updated v2 pin should be persisted).
 *
 * @param {Object} args
 * @param {string} args.peerUserId
 * @param {string|null} args.sealedPin
 * @param {string} args.peerPublicKey - served X25519 pubkey (base64)
 * @param {string} args.peerPqPublicKey - served ML-KEM pubkey (base64)
 * @param {string|Object[]|null} args.keyHistory - serialized chain (JSON array)
 * @returns {Promise<{status: string, fingerprint: string|null, sealedPinToStore?: string}>}
 */
export async function monitorPeerKey({
  peerUserId,
  sealedPin,
  peerPublicKey,
  peerPqPublicKey,
  keyHistory,
}) {
  const entries = parseHistory(keyHistory);
  if (entries.length === 0) {
    // No signed history → preserve plain TOFU exactly (additive, never a
    // regression for peers who have not generated signing keys yet).
    return verifyOrPin({ peerUserId, sealedPin, peerPublicKey, peerPqPublicKey });
  }

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

  let record = null;
  if (sealedPin) {
    let plaintext;
    try {
      plaintext = await decryptWithKey(sealedPin, userKey);
    } catch (e) {
      console.error("pin_store: pin unseal failed:", e);
      return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
    }
    record = plaintext ? decodePinRecord(plaintext) : null;
  }

  // --- Existing v2 pin with a pinned root: full chain monitoring ----------
  if (record && record.rootSigningPub) {
    const chain = await verifyChain(entries, record.rootSigningPub);
    if (chain.valid && headMatchesServedKeys(chain.headEntry, peerPublicKey, peerPqPublicKey)) {
      const headSeq = chain.headEntry.seq;
      const changed = record.fingerprint !== fingerprint || record.headSeq !== headSeq;
      await putShadow(peerUserId, fingerprint);
      const entry = recordStatus(peerUserId, PIN_STATUS.MATCH, fingerprint, {
        verified: record.verified,
        verifiedAt: record.verifiedAt,
        rootSigningPub: record.rootSigningPub,
        headSeq,
      });
      if (changed) {
        const resealed = await tryReseal(userKey, {
          fingerprint,
          verified: record.verified,
          verifiedAt: record.verifiedAt,
          rootSigningPub: record.rootSigningPub,
          headSeq,
        });
        if (resealed) return { ...entry, sealedPinToStore: resealed };
      }
      return entry;
    }
    // Invalid chain / root mismatch / head != served key => substitution.
    return recordStatus(peerUserId, PIN_STATUS.MISMATCH, fingerprint, {
      rootSigningPub: record.rootSigningPub,
      headSeq: record.headSeq,
    });
  }

  // --- First contact OR upgrading a pre-#315 (v1/legacy) pin --------------
  // Validate the chain INTERNALLY and confirm it leads to the served keys
  // before trusting/pinning the root.
  const chain = await verifyChain(entries, null);
  const leadsToServed =
    chain.valid && headMatchesServedKeys(chain.headEntry, peerPublicKey, peerPqPublicKey);

  if (!leadsToServed) {
    if (record) {
      return record.fingerprint === fingerprint
        ? recordStatus(peerUserId, PIN_STATUS.MATCH, fingerprint, {
            verified: record.verified,
            verifiedAt: record.verifiedAt,
          })
        : recordStatus(peerUserId, PIN_STATUS.MISMATCH, fingerprint);
    }
    return verifyOrPin({ peerUserId, sealedPin, peerPublicKey, peerPqPublicKey });
  }

  const rootSigningPub = entries[0].sign_pub;
  const headSeq = chain.headEntry.seq;
  const shadow = await getShadow(peerUserId);

  if (record) {
    // Upgrade a v1/legacy pin only if the served key matches what we trusted.
    if (record.fingerprint !== fingerprint || (shadow && shadow !== fingerprint)) {
      return recordStatus(peerUserId, PIN_STATUS.MISMATCH, fingerprint);
    }
    await putShadow(peerUserId, fingerprint);
    const entry = recordStatus(peerUserId, PIN_STATUS.MATCH, fingerprint, {
      verified: record.verified,
      verifiedAt: record.verifiedAt,
      rootSigningPub,
      headSeq,
    });
    const resealed = await tryReseal(userKey, {
      fingerprint,
      verified: record.verified,
      verifiedAt: record.verifiedAt,
      rootSigningPub,
      headSeq,
    });
    return resealed ? { ...entry, sealedPinToStore: resealed } : entry;
  }

  // True first contact with a valid chain: TOFU-pin the genesis root + head.
  if (shadow && shadow !== fingerprint) {
    return recordStatus(peerUserId, PIN_STATUS.MISMATCH, fingerprint);
  }
  const sealedPinToStore = await tryReseal(userKey, {
    fingerprint,
    verified: false,
    rootSigningPub,
    headSeq,
  });
  if (!sealedPinToStore) {
    return recordStatus(peerUserId, PIN_STATUS.ERROR, fingerprint);
  }
  await putShadow(peerUserId, fingerprint);
  const entry = recordStatus(peerUserId, PIN_STATUS.PINNED, fingerprint, {
    rootSigningPub,
    headSeq,
  });
  return { ...entry, sealedPinToStore };
}

// Seal a v2 pin record under the viewer's user_key; null on failure.
async function tryReseal(userKey, record) {
  try {
    const sealed = await encryptWithKey(encodePinRecord(record), userKey);
    return sealed || null;
  } catch (e) {
    console.error("pin_store: pin reseal failed:", e);
    return null;
  }
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
