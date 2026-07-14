# 🎙️ Mosslet E2EE Voice Notes — Design Doc (v1)

> **Status: APPROVED — ready to implement.**
> Board task **#383** (EPIC **#377** "Reason-to-return features"). Companion
> spec: `docs/ZK_FILE_SHARING_DESIGN.md` (the ZK pipeline this reuses verbatim).
> Follow-on: E2EE **video** notes v2 extends this exact pipeline.

## 0. TL;DR

Async, end-to-end-encrypted **voice notes** sent as intimate COMMUNICATION (a
warm message to your people) into a **Conversation (DM)** or a **Group** (which
covers personal, family, and business-circle cohorts). Voice-first because it's
far cheaper than video, warmer, lower production pressure, and de-risks the
record→encrypt→upload→playback hook before video.

**Zero new cryptographic primitives.** We reuse the approved ZK file-sharing
model (**Option B**): a fresh **per-note `file_key`** (NaCl secretbox) encrypts
the audio blob in the browser; the `file_key` is sealed **per recipient** with
`sealForUser` (Cat-5 hybrid ML-KEM-1024 + X25519) — exactly like
`UserPost.key` / `UserConversation.key` / `UserGroup.key` / `UserSharedFile.key`.
The server stores only the opaque blob (Tigris) + Cloak-wrapped sealed key
copies, never the `file_key` or the plaintext audio.

Why Option B (per-note key sealed per recipient) rather than reusing the
conversation/group key: **one unified pipeline works for every cohort** — DM
participants, family groups, and business circles — with a
server-authoritative recipient set resolved from membership, and no coupling to
any single context's key. Do it right once; video v2 inherits it.

## 1. Goals & Non-Goals

### Goals
1. A user records a voice note in a DM or Group composer; it is encrypted in the
   browser and readable **only** by the cohort's current members, ZK PQ end to
   end.
2. **Zero new crypto** — `encryptSecretbox`/`decryptSecretbox` for the blob;
   `sealForUser`/`unsealFromUser` for the `file_key`.
3. Server stores an **opaque blob** on object storage + sealed key copies in
   Postgres. Server never sees the `file_key` or the audio.
4. Recipient set is **server-authoritative** (I1): the cohort's membership
   (conversation participants or confirmed group members), resolved server-side.
5. The note appears **in the message stream** of the conversation/group, ordered
   with text messages, with a beautiful audio-bubble player.
6. One pipeline for personal (DM), family (group), and business (org circle
   group) accounts.

### Non-Goals (out of scope / forbidden)
- ❌ No new KEM / symmetric scheme / bespoke primitive.
- ❌ No server-readable audio. Server never seals a `file_key` for itself and
  never decrypts a blob (contrast public posts — voice notes are private-only).
- ❌ No client-chosen recipient set. Recipients = cohort membership, server-side.
- ❌ No server-side content scanning of plaintext (server holds only ciphertext).
  Optional client-side capability gating / graceful fail-open only.
- ❌ No fake ephemerality / self-destruct claims. IF we add expiry later, reuse
  the file-sharing revocation honesty: "future access only; past downloads can't
  be recalled."

## 2. Invariants (CI/review checklist — mirrors ZK_FILE_SHARING_DESIGN §3)

1. **I1 — Server-authoritative recipients.** The `file_key` may be sealed only
   for the cohort's members, resolved server-side; `finalize_*` drops any
   `user_id` not a current member. A tampered client cannot seal for an outsider.
2. **I2 — No server read key.** No server self-seal, no server-side
   `unsealFromUser`, no server-side blob decryption on this path.
3. **I3 — Opaque storage.** Object store receives only browser-produced
   ciphertext (`SharedFileStorage.put_encrypted_blob/1` semantics).
4. **I4 — Transparency (where surfaced).** Playback/notes UI can truthfully list
   who holds a sealed key (the readers), consistent with file sharing.
5. **I5 — Honest revocation.** Deleting a note removes the blob + all sealed keys
   + the record; UI never claims to recall already-downloaded copies.
6. **I6 — Same crypto everywhere.** `encryptSecretbox` blob; `sealForUser` key.
7. **I7 — Integrity.** Browser stores an encrypted plaintext SHA-256 checksum;
   recipient recomputes after decrypt and verifies (anti-tamper), fully ZK.
8. `sender_id` / `user_id` / context FKs set **programmatically** (never `cast`).
9. All new DB writes via the `Repo.transaction_on_primary/1` shim.

## 3. Data model

New context: **`Mosslet.VoiceNotes`**.

### 3.1 `VoiceNotes.VoiceNote` (table `voice_notes`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | binary_id | |
| `sender_id` | `belongs_to User` | programmatic. |
| `conversation_id` | `belongs_to Conversation` (nullable) | set when delivered into a DM. |
| `group_id` | `belongs_to Group` (nullable) | set when delivered into a group (covers family + business circle). |
| `storage_path` | `Encrypted.Binary` | Tigris key for the opaque blob. |
| `checksum` | `Encrypted.Binary` | browser plaintext SHA-256, encrypted with `file_key` (I7). |
| `media_type` | `:string` | `"audio"` (video v2 will add `"video"`). |
| `mime_hint` | `:string` (nullable, non-secret) | e.g. `audio/webm;codecs=opus` — retained for reference/possible download; playback decodes via Web Audio and does not depend on it. |
| `duration_ms` | `:integer` | non-secret metadata for the player scrubber. |
| `size_bytes` | `:integer` | non-secret metric. |
| `has_many :user_voice_notes` | | per-recipient sealed keys. |
| `timestamps()` | | |

- **Exactly one** of `conversation_id` / `group_id` is set. Enforce with a DB
  CHECK constraint + changeset validation. Both are FKs with `on_delete`
  behaviour so deleting a conversation/group cleans up notes (blob teardown via
  context — see §5).
- **No `file_key` material here** — only `UserVoiceNote.key` holds sealed keys.

### 3.2 `VoiceNotes.UserVoiceNote` (table `user_voice_notes`)

Mirrors `UserSharedFile` / `UserConversation` / `UserGroup` exactly.

| Field | Type | Notes |
|-------|------|-------|
| `id` | binary_id | |
| `voice_note_id` | `belongs_to VoiceNote` | |
| `user_id` | `belongs_to User` | recipient (programmatic). |
| `key` | `Encrypted.Binary` | `file_key` sealed for this user via `sealForUser`. |
| `timestamps()` | | `unique_constraint([:voice_note_id, :user_id])` |

### 3.3 Message-stream integration

Add a nullable `voice_note_id` (`belongs_to VoiceNote`) to **`messages`** and
**`group_messages`**. A voice note is delivered AS a message referencing its
`VoiceNote`, so it reuses the existing stream, broadcast, ordering, and deletion
machinery. The message `content` carries the (browser-encrypted) optional text
caption; for a pure voice note the caption is the encrypted empty string (keeps
`content`'s `validate_required` satisfied without special-casing). `voice_note_id`
is set programmatically in the create-message path (not `cast`).

## 4. Crypto flow (reuses ZK_FILE_SHARING_DESIGN §4 verbatim)

### 4.1 Send (write path — two-phase, mirrors `SharedFileHook`)
```
1. Browser: MediaRecorder → audio blob (opus/webm; mp4/aac fallback on Safari).
2. Browser: file_key = generateKey()               (NaCl 32 bytes)
3. Browser: checksum = SHA-256(plaintext); enc w/ file_key (I7)
4. Browser: ciphertext = encryptSecretbox(audioBytes, file_key)
5. Browser → Server "create_voice_note" { conversation_id|group_id, media_type,
   mime_hint, duration_ms, size_bytes, checksum, blob_chunks_total }, then
   streams "voice_note_chunk" { upload_ref, index, total, chunk_b64 }.
6. Server: assemble ciphertext → SharedFileStorage.put_encrypted_blob/1 →
   storage_path; insert VoiceNote (FKs stamped server-side, I2/I3); reply
   "voice_note_created" { voice_note_id, recipients:[{user_id, public_key,
   pq_public_key}] } — recipients resolved server-side (I1).
7. Browser: guardRecipients (verify-before-seal / TOFU pins, #294), then
   sealed = sealForUser(file_key, pk, pq_pk) per recipient (sender included).
8. Browser → Server "finalize_voice_note" { voice_note_id, sealed_recipients,
   encrypted_caption }.
9. Server: insert one UserVoiceNote per ELIGIBLE recipient (drop non-members,
   I1); create the Message/GroupMessage with voice_note_id + encrypted_caption;
   broadcast to the stream.
```

### 4.2 Play (read path — mirrors `SharedFileHook` download + `DecryptMessage`)
```
1. Browser (on play/visible) → "request_voice_note" { voice_note_id }.
2. Server authorizes (requester holds a UserVoiceNote row), returns
   "voice_note_ready" { sealed_key, blob (inline ciphertext via
   get_encrypted_blob — avoids Tigris CORS), checksum, mime_hint, duration_ms }.
   (Presigned URL is an alternative; inline relay matches the DM image #349 fix.)
3. Browser: file_key = unsealFromUser(sealed_key, ...); plain =
   decryptSecretbox(blob, file_key); verify checksum (I7); decode via the
   Web Audio API (decodeAudioData → AudioBufferSourceNode) and play. Never
   touches the server for decryption (I2).
```

> **Playback path (why Web Audio, not `<audio>`):** WebKit (Safari / DuckDuckGo)
> cannot play MediaRecorder-produced blobs — neither `webm/opus` nor fragmented
> `mp4/aac` — through an `<audio src=blob:>` element; it fails with
> `MEDIA_ERR_SRC_NOT_SUPPORTED` (and `canPlayType`/`isTypeSupported` both lie
> and report support). `AudioContext.decodeAudioData` decodes those exact bytes
> reliably on Chrome, Firefox, and WebKit, so the player decodes the decrypted
> bytes and plays through an `AudioBufferSourceNode` (shared AudioContext,
> rAF-driven scrubber, pause/resume/seek). No format change is needed and
> existing notes keep working.

### 4.3 Chunking / size limits
Reuse `SharedFileHook`'s 512 KB-ciphertext chunking over the LV channel. Cap
duration at **5 minutes** (v1) and enforce a byte cap server-side + client-side
(defense in depth), well within `SharedFileStorage` + secretbox memory limits.
Graceful fail-open for no-mic / unsupported browser (mirror image NSFW pattern):
hide/disable the record affordance with honest copy, never break text messaging.

## 5. Context `Mosslet.VoiceNotes` (all writes via `Repo.transaction_on_primary/1`)

- `recipients_for_conversation(conversation)` / `recipients_for_group(group)` →
  `[%{user_id, public_key, pq_public_key}]`, server-authoritative (I1).
- `create_voice_note_zk(context, sender, attrs)` — `context` is a `Conversation`
  or `Group`; validates sender membership + size; inserts `VoiceNote`.
- `finalize_voice_note_zk(voice_note, sealed_recipients)` — inserts
  `UserVoiceNote` per eligible recipient (drops ineligible — I1).
- `get_user_voice_note(voice_note, user)` — the requester's sealed key (read
  auth + hand to browser).
- `blob_for(voice_note, user)` — authorizes then relays inline ciphertext
  (`get_encrypted_blob`) or `presigned_url`.
- `list_readers(voice_note)` — transparency (I4).
- `delete_voice_note(voice_note, actor)` — blob + sealed keys + record (I5);
  authorized to sender (or group admin/owner).
- Teardown hooks called when a conversation/group is deleted (blob cleanup so
  Tigris blobs aren't orphaned — mirror `Files.delete_all_for_group/1`).

Storage: reuse `Mosslet.FileUploads.SharedFileStorage` (opaque blobs). Optionally
add a `uploads/voice/` prefix variant; reusing the existing `uploads/files/`
prefix is acceptable for v1 (blobs are opaque + typeless either way).

## 6. UI / UX (idiomatic LiveView + Tailwind v4; DESIGN_SYSTEM.ex)

- **Composer:** a mic button next to the send control in `ConversationLive.Show`
  and `GroupLive.GroupMessage.Form`. Tapping starts recording with a live timer +
  lightweight waveform/amplitude bars, a cancel (trash) and a stop/send control.
  Micro-interactions, clear recording state, mobile-first (large touch targets,
  respects safe-area). Capability-gated with honest copy when mic is unavailable.
- **Bubble:** an audio player component in the message stream — play/pause,
  scrubber (from `duration_ms`), elapsed time, "🎙️ Voice note" label, optional
  decrypted caption, a "verified" (checksum) affordance, and sender identity
  consistent with existing bubbles. Lazy-loads/decrypts on first play.
- **Hooks:** `assets/js/hooks/voice-note-recorder.js` (MediaRecorder capture +
  file_key gen + checksum + encrypt + chunked upload + seal, modeled on
  `shared-file-hook.js`) and `assets/js/hooks/voice-note-player.js` (request →
  decrypt → verify → play). Register in `assets/js/hooks/index.js`. Reuse
  `crypto/nacl.js`, `crypto/session.js`, `crypto/seal_guard.js`. No new WASM.
- Honest privacy copy: "Recorded and encrypted on your device. Mosslet can't
  hear it."

## 7. Security checklist (applied at implementation)
- [ ] I1 recipients resolved server-side; `finalize` drops ineligible; tested
      (outsider can't be sealed; non-member can't fetch a blob).
- [ ] I2 no server self-seal / unseal / decrypt on this path.
- [ ] I3 only browser-produced ciphertext hits the object store.
- [ ] I5 delete removes blob + sealed keys + record; honest copy.
- [ ] I6 `encryptSecretbox` blob + `sealForUser` key only.
- [ ] I7 recipient recomputes + verifies checksum; mismatch warns.
- [ ] `sender_id`/`user_id`/context FKs + `voice_note_id` set programmatically.
- [ ] Read path authorizes on a `UserVoiceNote` row before relaying the blob.
- [ ] All writes via `Repo.transaction_on_primary/1`.
- [ ] `mix precommit` clean (no NEW warnings beyond the known pre-existing set).

## 8. Implementation order (each step self-contained + testable)
1. **Migrations:** `create_voice_notes`, `create_user_voice_notes`,
   `add_voice_note_id_to_messages`, `add_voice_note_id_to_group_messages`
   (nullable FK + CHECK: exactly one of conversation_id/group_id).
2. **Schemas:** `VoiceNotes.VoiceNote` + `VoiceNotes.UserVoiceNote` (programmatic
   FKs; `insert_changeset`s mirroring `Files.SharedFile`/`UserSharedFile`).
3. **Context `Mosslet.VoiceNotes`:** recipients resolution + create/finalize/
   read/delete/teardown (§5). Wire message/group-message create to accept
   `voice_note_id`.
4. **JS hooks:** recorder + player (§6); register + crypto reuse.
5. **UI:** composer mic + preview; stream audio bubble; both DM and Group.
6. **Tests:** context ZK round-trip, eligibility (I1), read-auth, delete (I5),
   checksum (I7); LiveView send/receive for DM + Group.
7. **Verify:** `mix precommit` + browser walkthrough (record → send → play on the
   recipient side) on mobile + desktop widths.

## 9. Open questions (resolve during build if they arise)
- **Q1 — Max duration → 5 min (v1).** Revisit for longer once bandwidth is fine.
- **Q2 — Blob prefix → reuse `uploads/files/` or add `uploads/voice/`.** Cosmetic;
  either is opaque. Prefer `uploads/voice/` for cleaner ops if trivial.
- **Q3 — Inline relay vs presigned URL for playback → inline `get_encrypted_blob`**
  (matches the #349 CORS fix), with presigned as a documented alternative.
- **Q4 — Business-circle delivery in v1?** #383 scopes DM + Group; a group with
  `org_id` already IS a business circle, so it comes "for free," but surface the
  composer there only after DM/Group are solid.
