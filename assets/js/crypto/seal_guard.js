/**
 * Verify-before-seal gate (EPIC #291 / Phase 2 — #294).
 *
 * The SINGLE chokepoint every browser-side `sealForUser(...)` to a peer must
 * pass through before sealing a shared context key (conversation_key, org_key,
 * group_key, post_key, file_key, conn_key) for that recipient. It consumes the
 * unified TOFU pin store from #293 (`./pin_store` verifyOrPin), keyed by the
 * PEER's user id — one pin per peer, independent of relationship type.
 *
 * Threat model: the server is the adversary. It distributes recipient public
 * keys AND the opaque sealed pin. A coerced/compromised server could substitute
 * a recipient key to silently MITM "E2E" content, or strip a pin / downgrade a
 * key to force a re-TOFU of a substituted key. This gate makes every such move
 * either detected (refuse) or impossible-to-exploit-silently.
 *
 * ---------------------------------------------------------------------------
 * POLICY (user-confirmed, #294 — no silent security gaps)
 * ---------------------------------------------------------------------------
 * Maps onto verifyOrPin's verdicts (pin_store.js, reused unchanged):
 *
 *   MATCH / PINNED                 -> SEAL. PINNED also yields a pin to persist
 *                                     server-side (TOFU first contact).
 *   MISMATCH                       -> REFUSE this recipient. verifyOrPin already
 *                                     fired PEER_KEY_CHANGED_EVENT for #295/#296.
 *   ERROR                          -> REFUSE. A corrupt pin blob / garbage key
 *                                     bytes / reseal failure is treated as a
 *                                     possible attack (fail-closed).
 *   UNAVAILABLE, peer keys COMPLETE-> DEFER (self-heal). computeFingerprint
 *                                     already succeeded, so the only remaining
 *                                     UNAVAILABLE cause is the viewer's own
 *                                     user_key not being unsealed yet (an
 *                                     Elixir/Fly/login timing race). We wait for
 *                                     `mosslet:keys-ready` once and retry.
 *   UNAVAILABLE, peer MISSING pq,
 *     HAS a sealed pin             -> REFUSE. The peer was full-hybrid when
 *                                     pinned; a now-missing PQ key is a downgrade
 *                                     attack.
 *   UNAVAILABLE, peer MISSING pq,
 *     NO pin                       -> ALLOW. Genuine legacy peer that has not yet
 *                                     generated a PQ key (progressive keygen,
 *                                     task #11). Cannot fingerprint, but there is
 *                                     no prior trust to violate. Documented
 *                                     interim gap, closed by signed key-history
 *                                     (mosskeys). NOT pinnable yet.
 *
 * A recipient with no X25519 public key at all is skipped (not sealable by any
 * path regardless) and never treated as an attack.
 */
import { monitorPeerKey, PIN_STATUS } from "./pin_store";
import { getPublicKey, getSealedUserKey } from "./session";

const KEYS_READY_EVENT = "mosslet:keys-ready";
const KEY_WAIT_TIMEOUT_MS = 15_000;

function viewerReady() {
  return !!getPublicKey() && !!getSealedUserKey();
}

function waitForKeysOnce() {
  return new Promise((resolve) => {
    if (viewerReady()) {
      resolve();
      return;
    }
    const timer = setTimeout(resolve, KEY_WAIT_TIMEOUT_MS);
    window.addEventListener(
      KEYS_READY_EVENT,
      () => {
        clearTimeout(timer);
        resolve();
      },
      { once: true },
    );
  });
}

function peerComplete(recipient) {
  return !!recipient.public_key && !!recipient.pq_public_key;
}

/**
 * Run a single recipient through verifyOrPin and classify the verdict per the
 * #294 policy above.
 *
 * @returns {Promise<{decision: "seal"|"refuse"|"defer", pin?: {peer_user_id, sealed_pin}}>}
 */
async function classify(recipient) {
  const peerUserId = recipient.user_id;
  const peerPublicKey = recipient.public_key;
  const peerPqPublicKey = recipient.pq_public_key;

  const verdict = await monitorPeerKey({
    peerUserId,
    sealedPin: recipient.sealed_pin || null,
    peerPublicKey,
    peerPqPublicKey,
    keyHistory: recipient.key_history || null,
  });

  switch (verdict.status) {
    case PIN_STATUS.PINNED:
      return verdict.sealedPinToStore
        ? {
            decision: "seal",
            pin: { peer_user_id: peerUserId, sealed_pin: verdict.sealedPinToStore },
          }
        : { decision: "seal" };

    case PIN_STATUS.MATCH:
      return { decision: "seal" };

    case PIN_STATUS.MISMATCH:
    case PIN_STATUS.ERROR:
      return { decision: "refuse" };

    case PIN_STATUS.UNAVAILABLE:
    default:
      if (peerComplete(recipient)) {
        // computeFingerprint succeeded; the only UNAVAILABLE cause left is the
        // viewer's own user_key not being unsealed yet — a self-healing race.
        return { decision: "defer" };
      }
      // Peer is missing a PQ key (cannot fingerprint).
      if (recipient.sealed_pin) {
        // Was full-hybrid when pinned -> PQ downgrade attack.
        return { decision: "refuse" };
      }
      // Genuine legacy first-contact peer (no pin, no PQ key): allow, but not
      // pinnable. Interim gap documented above.
      return { decision: "seal" };
  }
}

/**
 * Gate a batch of recipients before sealing a shared key for them.
 *
 * Each recipient is `{user_id, public_key, pq_public_key, sealed_pin}` — the
 * server-hydrated shape (see `MossletWeb.Helpers.hydrate_sealed_pins/2`).
 *
 * If the viewer's keys are not ready yet (or a complete, pinned peer reports
 * UNAVAILABLE because the user_key has not unsealed), we wait once for
 * `mosslet:keys-ready` and re-run — the timing race self-heals. Recipients that
 * still cannot be verified after that are handled per policy (refuse vs allow).
 *
 * @param {Array<Object>} recipients
 * @returns {Promise<{
 *   sealable: Array<Object>,      // safe to sealForUser
 *   pinsToStore: Array<{peer_user_id: string, sealed_pin: string}>,
 *   mismatched: Array<string>,    // peer_user_ids refused (mismatch/error/downgrade)
 * }>}
 */
export async function guardRecipients(recipients) {
  const list = Array.isArray(recipients) ? recipients : [];

  if (!viewerReady()) {
    await waitForKeysOnce();
  }

  let result = await classifyBatch(list);

  // A single retry if any recipient deferred (viewer user_key still unsealing).
  if (result.deferred && !viewerReady()) {
    await waitForKeysOnce();
    result = await classifyBatch(list);
  } else if (result.deferred) {
    // Viewer reports ready but a complete peer still came back UNAVAILABLE; give
    // the user_key unseal one more tick to settle, then re-classify.
    await waitForKeysOnce();
    result = await classifyBatch(list);
  }

  // After the retry, anything STILL deferred cannot be verified for a complete,
  // pinned/pinnable peer. Fail closed (refuse) — never seal to an unverifiable
  // peer that should have been verifiable.
  const sealable = [];
  const mismatched = [];
  for (const entry of result.entries) {
    if (entry.decision === "seal") {
      sealable.push(entry.recipient);
    } else {
      // "refuse" or still-"defer" both fail closed.
      mismatched.push(entry.recipient.user_id);
    }
  }

  return { sealable, pinsToStore: result.pinsToStore, mismatched };
}

async function classifyBatch(list) {
  const entries = [];
  const pinsToStore = [];
  const mismatched = [];
  let deferred = false;

  for (const recipient of list) {
    if (!recipient || !recipient.user_id || !recipient.public_key) {
      // Not sealable by any path; skip silently (not an attack).
      continue;
    }
    const c = await classify(recipient);
    entries.push({ recipient, decision: c.decision });
    if (c.pin) pinsToStore.push(c.pin);
    if (c.decision === "refuse") mismatched.push(recipient.user_id);
    if (c.decision === "defer") deferred = true;
  }

  return { entries, pinsToStore, mismatched, deferred };
}
