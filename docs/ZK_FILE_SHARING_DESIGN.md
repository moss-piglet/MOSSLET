# 📎 Mosslet ZK File Sharing — Design Doc (Phase 3d)

> **Status: APPROVED (Q1–Q7 resolved — see §8).**
> This doc is the binding spec for the org-scoped ZK file-sharing portion of
> EPIC #207, Phase 3 (board task #212). Companion doc:
> `BUSINESS_CIRCLES_DESIGN.md` (Phase 3c).

## Guiding philosophy — protection without policing

> **We protect businesses; we do not police them.** Zero-knowledge means privacy
> *from Mosslet and from outsiders*. We never inspect a business's file content
> (we cannot — it is ciphertext to us, and content policing is a matter for the
> business and governments, not their software vendor). But we **do** defend
> businesses against malicious users, malware, and AI-driven attacks — using
> **client-side defenses at the trust boundary** (where the file is already
> plaintext on the user's own device) and a **server that holds only unreadable
> ciphertext** (so a breach of Mosslet yields math, not data). See §10 for the
> client-side ZK threat-protection design.

## 0. TL;DR

Org-scoped **zero-knowledge file sharing** lets a business-org member upload a
file that is **encrypted in the browser** and shared with other members of the
**same business circle** — the server stores only **opaque encrypted blobs** and
sealed key copies, never plaintext and never the file key.

It reuses two things we already ship, **with zero new cryptographic primitives**:

1. **The ZK upload path:** the browser encrypts the file bytes with a per-file
   `file_key` (NaCl secretbox, `encryptSecretbox`) and uploads the **already-
   encrypted blob** via the existing `upload_pre_encrypted_to_storage/1` flow
   (`image_upload_writer.ex:519`). The server `put_object`s the opaque bytes to
   object storage (Tigris) and never sees the key or plaintext.
2. **The recipient-sealing pattern:** the `file_key` is sealed per recipient with
   `sealForUser` (Cat-5 hybrid ML-KEM-1024 + X25519) — **exactly** like
   `UserPost.key` / `UserGroup.key` / `UserConversation.key`. Each recipient
   decrypts the `file_key` with their own private key, fetches the opaque blob,
   and decrypts it **in the browser**.

The recipient set is **server-authoritative**: it is the membership of a
**business circle** (a `UserGroup` cohort), not a client-chosen list. The browser
does the sealing; the server chooses *who* may be sealed for.

A **mandatory transparency surface** lists, for every shared file, exactly which
people can read it (derived from the circle's members) and lets authorized users
**revoke** a file (delete the blob + all sealed keys) — with honest "future
access only / past downloads can't be recalled" copy.

## 1. Goals & Non-Goals

### Goals

1. A business-circle member can share a file (e.g. a PDF, doc, image) that is
   readable **only** by members of that circle, ZK PQ end to end.
2. **Zero new cryptographic primitives** — `encryptSecretbox` for the blob,
   `sealForUser`/`unsealFromUser` for the `file_key`, identical to posts/circles.
3. Server stores **opaque encrypted blobs** on object storage + sealed key copies
   in Postgres. Server never sees the `file_key` or plaintext.
4. A **mandatory transparency surface**: every file shows exactly who can read
   it (the circle's current members).
5. **Revocation** that is cryptographically honest: deleting a file removes the
   blob + all sealed keys (no future access); we never claim to recall copies
   already downloaded.
6. Org-scoped: files belong to a business circle within a `:business` org.

### Non-Goals (explicitly out of scope / forbidden)

- ❌ **No new crypto.** No new KEM, no new symmetric scheme, no per-file
  asymmetric keypair. `file_key` is a symmetric NaCl key sealed with the existing
  hybrid PQ `sealForUser`.
- ❌ **No master key / no server-readable files.** The server never seals a
  `file_key` for itself and never decrypts file content. (Contrast: public posts
  are server-readable by design — **file sharing is private-only**, never sealed
  for the server.)
- ❌ **No client-chosen recipient set.** Recipients are the circle's members,
  resolved server-side. A tampered client cannot seal a file for an outsider and
  cannot expand the recipient set.
- ❌ **No silent access changes.** Adding a member to a circle does not silently
  retro-seal existing files for them. By default a new member only gets files
  shared *after* they join ("future files only"). Granting access to earlier
  files is possible but **only via an explicit, surfaced "Catch up" action** by
  an authorized current reader — never automatic, never silent (see §6.2). The
  transparency surface always reflects current reality.
- ❌ **No cross-org / cross-circle leakage.** A file is pinned to one circle;
  eligibility queries are always circle-scoped.
- ❌ **No server-side virus/content scanning of plaintext** (server can't see
  plaintext). Optional client-side checks only, mirroring existing image NSFW
  handling (fail-open documented).

## 2. Terminology

| Term | Meaning |
|------|---------|
| **Business org** | `Orgs.Org` with `type: :business`. |
| **Business circle** | `Groups.Group` with `org_id` set (see `BUSINESS_CIRCLES_DESIGN.md`). |
| **Circle member** | A user with a `Groups.UserGroup` row for that circle. |
| **Shared file** | A `Files.SharedFile` record: metadata + storage path for one uploaded, encrypted file. |
| **`file_key`** | A per-file symmetric NaCl key (32 bytes) generated in the browser. Encrypts the file bytes. |
| **File access record** | A `Files.UserSharedFile` row: the `file_key` sealed for one recipient's public key (mirrors `UserPost`/`UserGroup`). |

## 3. Threat model & invariants

**Trust boundaries (unchanged from `ENCRYPTION_ARCHITECTURE.md`):**

- Server sees: the Cloak-wrapped sealed `file_key` copies (in Postgres) and the
  opaque encrypted blob (on Tigris). **Never the `file_key` in the clear. Never
  the plaintext file.**
- Browser (uploader's device) sees: plaintext file while encrypting; the
  uploader's own private key.
- Recipient's browser sees: the `file_key` after unsealing with their own private
  key, and the plaintext file after decrypting the fetched blob.

**Invariants (CI/review checklist):**

1. **I1 — Recipients are server-authoritative.** The set of users a `file_key`
   may be sealed for is the circle's `UserGroup` members, resolved **server-
   side**. The browser seals only for the public keys the server returns; a
   tampered client cannot add an outsider, and the server rejects sealed-key
   entries for ineligible `user_id`s before insert.
2. **I2 — No server read key.** The server never seals a `file_key` for itself,
   never `unsealFromUser`s a file key, and never decrypts a file blob anywhere.
   (No `Encrypted.Session.server_public_key()` on this path.)
3. **I3 — Opaque storage.** The object store receives only ciphertext produced
   in the browser (`upload_pre_encrypted_to_storage/1` semantics). The server
   `put_object`s bytes it cannot read.
4. **I4 — Transparency is mandatory and truthful.** Every shared file's UI lists
   exactly the users who currently hold a sealed `file_key` (= the people who can
   read it). No hidden recipients.
5. **I5 — Honest revocation.** Deleting a file removes the blob + all
   `UserSharedFile` rows (no future access). UI never claims to recall copies a
   recipient already downloaded.
6. **I6 — Same crypto everywhere.** `encryptSecretbox` for the blob;
   `sealForUser`/`unsealFromUser` for the `file_key`. No bespoke primitives.

## 4. How it maps onto the EXISTING ZK paths

### 4.1 Upload (write path) — mirrors post-image ZK upload

The post-image ZK flow already does exactly this for images
(`post-form-hook.js:_encryptImage` + `upload_pre_encrypted_to_storage/1`). We
generalize it to arbitrary files:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    SHARING A FILE (Browser → Server)                      │
├──────────────────────────────────────────────────────────────────────────┤
│  1. Browser: file_key = generateKey()                       (NaCl 32 bytes)│
│  2. Browser: ciphertext = encryptSecretbox(fileBytes, file_key)            │
│  3. Browser → Server: upload the OPAQUE ciphertext (multipart / chunked)   │
│     via the existing pre-encrypted upload writer.                          │
│  4. Server: put_object(path, ciphertext) on Tigris  → returns storage path │
│     (server never sees file_key or plaintext — I2/I3).                     │
│  5. Server → Browser: returns the circle members' public keys              │
│     %{user_id, public_key, pq_public_key} (server-authoritative — I1).     │
│  6. Browser: for each member,                                              │
│     sealed = sealForUser(file_key_bytes, public_key, pq_public_key)        │
│     (Cat-5 hybrid; uploader included).                                     │
│  7. Browser → Server: finalize with                                        │
│     %{storage_path, size, encrypted_filename, sealed_recipients: [...]}    │
│  8. Server: insert SharedFile + one UserSharedFile per sealed recipient.   │
│     All writes via Repo.transaction/1 shim.                                │
└──────────────────────────────────────────────────────────────────────────┘
```

This is the **same two-phase shape** as `create_group_zk` (server inserts the
parent record + returns member public keys, browser seals, server persists the
per-recipient sealed keys). We reuse that orchestration pattern verbatim.

> **Filename + metadata are encrypted too.** The original filename and any note
> are human-entered text → encrypted with `file_key` in the browser (`Encrypted.
> Binary` on the server, double-wrapped by Cloak). The server stores only
> ciphertext + non-sensitive system fields (size, content-type category if we
> choose to expose it, timestamps). Content-type is sensitive-ish; default to
> NOT storing a precise MIME server-side — store an encrypted filename and let
> the browser infer type. (Q4.)

### 4.2 Download (read path) — mirrors DM image / post read

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    READING A FILE (Server → Browser)                      │
├──────────────────────────────────────────────────────────────────────────┤
│  1. Browser requests file; server returns the user's sealed file_key       │
│     (UserSharedFile.key) + a short-lived presigned GET URL for the blob.   │
│  2. Browser: file_key = unsealFromUser(sealed_key, pk, sk, pq_sk)          │
│     (auto-detects v1/v2/v3 — existing logic).                              │
│  3. Browser: fetch(presigned_url) → opaque ciphertext bytes.               │
│  4. Browser: plaintext = decryptSecretbox(ciphertext, file_key).           │
│  5. Browser: trigger a client-side download / preview of the plaintext.    │
│     Server never decrypts (I2).                                            │
└──────────────────────────────────────────────────────────────────────────┘
```

Presigned URLs reuse the existing helpers (`generate_presigned_url/1` in
`tigris.ex` / `helpers.ex`). The server authorizes the request by checking the
requester has a `UserSharedFile` row (circle membership) before issuing the
presigned URL — so the blob URL isn't handed to non-members. The blob is opaque
regardless, but we still gate it (defense in depth).

### 4.3 Why this is "reuse, not new"

| Concern | Existing mechanism reused |
|---------|---------------------------|
| Blob encryption | `encryptSecretbox` / `decryptSecretbox` (`nacl.js`) — same as post images & DM messages |
| Opaque upload | `upload_pre_encrypted_to_storage/1` (`image_upload_writer.ex:519`) |
| Object storage | Tigris client (`tigris.ex`), presigned URLs |
| Per-recipient key seal | `sealForUser` (`nacl.js:157`) — same as posts/circles/DMs |
| Recipient unseal | `unsealFromUser` — same auto-detect v1/v2/v3 |
| Two-phase orchestration | `create_group_zk` server-seal-finalize shape |
| Server-authoritative recipients | the membership-resolver pattern from circles/guardianship |
| At-rest wrap | `Encrypted.Binary` (Cloak) on the sealed keys + encrypted filename |

## 5. Data model

Follows `ENCRYPTION_ARCHITECTURE.md`. Migrations via `mix ecto.gen.migration`.

### 5.1 New schema: `Files.SharedFile` (table `shared_files`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | binary_id | |
| `group_id` | `belongs_to Group` | the business circle (must have `org_id` set). |
| `org_id` | `belongs_to Org` | denormalized for org-scoped queries/cleanup (set in context, not cast). |
| `uploader_id` | `belongs_to User` | set programmatically (not cast). |
| `storage_path` | `Encrypted.Binary` | object-store key for the opaque blob (encrypted at rest — it's a pointer, low-sensitivity but no reason to leak). |
| `encrypted_filename` | `Encrypted.Binary` | original filename, encrypted with `file_key` in browser. |
| `size_bytes` | `:integer` | plaintext system metric (for quota/UX). |
| `checksum` | `Encrypted.Binary` | **(Q5 = YES)** browser-computed integrity hash (e.g. SHA-256) of the plaintext, encrypted with `file_key`. The recipient's browser recomputes after decrypt and verifies — detects corruption or a malicious mid-stream swap, fully ZK. |
| `scan_verdict` | `Encrypted.Binary` (optional) | browser-side threat-scan result (see §10), encrypted with `file_key` so recipients see "scanned ✓/⚠" without the server reading anything. |
| `has_many :user_shared_files` | | per-recipient sealed keys. |
| `timestamps()` | | |

### 5.2 New schema: `Files.UserSharedFile` (table `user_shared_files`)

Mirrors `UserPost`/`UserGroup` exactly — the per-recipient sealed `file_key`.

| Field | Type | Notes |
|-------|------|-------|
| `id` | binary_id | |
| `shared_file_id` | `belongs_to SharedFile` | |
| `user_id` | `belongs_to User` | recipient (set programmatically, not cast). |
| `key` | `Encrypted.Binary` | the `file_key` sealed for this user's public key via `sealForUser`. |
| `timestamps()` | | |
| | | `unique_constraint([:shared_file_id, :user_id])` |

> **No key material in `SharedFile`** — only `UserSharedFile.key` holds sealed
> keys, exactly like the post/circle pattern. The server can never assemble a
> usable `file_key`.

### 5.3 New context: `Mosslet.Files`

CRUD + ZK orchestration, all writes via `Repo.transaction/1` shim:

- `create_shared_file_zk(group, uploader, %{storage_path, encrypted_filename,
  size_bytes, ...})` → inserts `SharedFile`; returns the circle members'
  public keys (server-authoritative — I1) for the browser to seal.
- `finalize_shared_file_zk(shared_file, sealed_recipients)` → inserts one
  `UserSharedFile` per **eligible** recipient (drops any `user_id` not a current
  circle member — I1).
- `list_shared_files_for_group(group, user)` → files in the circle the user can
  read (joins `user_shared_files`), circle-scoped.
- `get_user_shared_file(shared_file, user)` → the requester's sealed key (for the
  read path); authorizes the presigned URL.
- `delete_shared_file(shared_file, actor)` → deletes the blob (Tigris) + all
  `UserSharedFile` rows + the `SharedFile` (revocation — I5). Authorized to
  uploader or circle admin/owner.
- `list_readers(shared_file)` → the users who currently hold a sealed key (the
  transparency surface — I4).

### 5.4 Storage, size limits

- **Object store:** Tigris (existing `tigris.ex` / `memories_bucket()`), under a
  new folder prefix (e.g. `uploads/files/`). Opaque blobs only.
- **Max size (Q1 = 50 MB):** **50 MB** per file in Phase 3 (chunked upload via
  the existing UploadWriter streaming). 25 MB felt stingy for a paid business
  tool (smaller than a typical email attachment); 50 MB covers the overwhelming
  majority of business files (PDFs, decks, spreadsheets, design exports) while
  staying within browser-side secretbox memory limits. Streaming/chunked
  encryption for larger media is noted as a future enhancement.
- **Allowed types (Q3 = allow-all, fail-open):** allow-all (the server cannot
  inspect ciphertext anyway); rely on the encrypted filename + client-side
  preview + the client-side threat scan (§10). We document fail-open exactly like
  the existing image NSFW handling. "We can't see your files, so we don't police
  them" is both the honest technical reality and a selling point.

## 6. UX / transparency (mandatory)

### 6.1 Files panel on the business circle (Show page)

Within `BusinessLive.Show` (or the circle Show page scoped to the org): a
**Files** section listing shared files the user can read — decrypted filename
(browser-side), size, uploader, date, a **download** action, and (for
uploader/admin) a **delete/revoke** action. Upload entry point with the ZK
upload hook.

### 6.2 Transparency surface (mandatory — I4)

For each file, a clear, always-available **"Who can read this file"** disclosure
listing the circle members who currently hold a sealed key (decrypted member
names browser-side). Honest copy:

> **Who can read this file**
> Everyone in **[circle name]** can open this file with their own key. Mosslet's
> servers can't read it.
> *Adding someone to the circle later does **not** give them this file — only
> files shared after they join, unless an authorized member uses **Catch up**
> (see §6.2.1). Deleting a file removes it for everyone, but can't recall copies
> already downloaded.*

This makes the "future files only" semantics and revocation honesty explicit
(I4/I5), mirroring the guardianship transparency-panel discipline.

### 6.2.1 Catch up (explicit, never silent)

By default a member who joins after a file was shared holds no sealed `file_key`
for it and cannot read it. This is correct behavior, not a bug — the server can
never re-seal a `file_key` because it never holds one (I2/I3). To let earlier
files reach later-joining members **without** violating the "no silent retro-seal"
non-goal, we offer a single, explicit, surfaced **"Catch up"** action:

- **Who can trigger it:** an authorized *current reader* — the file uploader, a
  circle owner/admin, or an org admin. NOT every member (which would silently
  widen access). The affordance is shown only when at least one current member
  is missing access to one or more files.
- **How it works (client-side re-seal, ZK):** the server hands the actor's
  browser *its own* sealed `file_key` for each readable file plus the public keys
  of the members who lack access (server-authoritative, I1). The browser unseals
  each `file_key`, re-seals it with `sealForUser` for each missing member, and
  returns only the new sealed copies. The raw `file_key` never reaches the server
  (I2/I3).
- **Server enforcement:** `finalize_catch_up_zk/2` inserts a `UserSharedFile`
  only when the target is a *current confirmed circle member* of that file's
  circle and doesn't already hold a row (I1, idempotent). A tampered client can
  neither widen the recipient set nor seal for an outsider.
- **Never silent:** the action is an explicit button with honest tooltip copy
  ("Give members who joined later access to earlier files. Re-encrypted on your
  device — Mosslet still can't read them."), mirroring the §6.3 revocation
  discipline. The transparency surface (§6.2) updates to reflect the new readers.

### 6.3 Revocation (honest — I5)

- **Delete a file:** removes the Tigris blob + all sealed keys + the record. No
  one can fetch/decrypt it afterward. UI states plainly that already-downloaded
  copies cannot be recalled.
- **Member leaves or is removed from the circle:** their `UserGroup` row is
  removed (so they are not a recipient of new files) **and** their existing
  `UserSharedFile` rows for the circle are revoked. The act of leaving (member's
  own choice) or removal/offboarding (admin's choice) IS the explicit trigger —
  consistent with "explicit, never silent." This deletes the departed member's
  sealed `file_key` rows, preventing *future* fetches by them; if they are
  re-added later they must be explicitly **caught up** again to regain access.
  Honest copy: already-downloaded copies cannot be recalled. **(Q6 = YES.)** The
  underlying `Files.revoke_member_file_access/2` remains available as a
  standalone admin action as well.


## 7. Security review checklist (applied at implementation)

- [ ] **I1** Recipient public keys resolved **server-side** from the circle's
      `UserGroup` members; browser seals only for the server-provided set;
      finalize drops sealed entries for ineligible `user_id`s. Tested.
- [ ] **I2** No server self-seal, no server-side `unsealFromUser`, no server-side
      file decryption anywhere. `server_public_key()` never used on this path.
- [ ] **I3** Upload stores only browser-produced ciphertext
      (`upload_pre_encrypted_to_storage` semantics). Verified server never holds
      `file_key` or plaintext.
- [ ] **I4** Transparency surface lists exactly the current key-holders for each
      file; no hidden recipients. Tested.
- [ ] **I5** Delete removes blob + all sealed keys + record; UI copy is honest
      about already-downloaded copies.
- [ ] **I6** Blob uses `encryptSecretbox`; key uses `sealForUser`/`unsealFromUser`
      with each recipient's `key_pair["public"]` + `pq_public_key`. No bespoke
      primitive.
- [ ] **I7 (integrity)** Recipient browser recomputes the plaintext checksum and
      verifies against the decrypted `checksum` field; mismatch surfaces a clear
      warning. Tested.
- [ ] **I8 (threat scan)** Client-side scan runs at the trust boundary
      (upload + download); fail-open is documented; no plaintext leaves the
      browser for scanning. Tested.
- [ ] `org_id`/`uploader_id`/`user_id` set programmatically (never `cast`).
- [ ] Presigned GET URLs issued only after verifying the requester holds a
      `UserSharedFile` row (membership gate); URLs short-lived.
- [ ] All new DB writes wrapped in `Repo.transaction/1` shim.
- [ ] `mix precommit` clean (no NEW warnings beyond the ~17 known pre-existing).

## 8. Resolved questions

- **Q1 — Max file size → 50 MB** (Phase 3; streaming-encryption for larger media
  deferred).
- **Q2 — Per-org storage quota → NONE in Phase 3**; track `size_bytes` for a
  future soft cap (don't nickel-and-dime early; launch generous).
- **Q3 — Allowed file types → ALLOW-ALL**, document fail-open (server can't
  inspect ciphertext); client-side preview + scan instead.
- **Q4 — Store MIME server-side → NO**; encrypt the filename, infer type
  browser-side (minimize metadata leakage — this *is* the ZK value).
- **Q5 — Integrity checksum → YES** (encrypted `checksum` field; recipient
  verifies after decrypt — anti-tamper, fully ZK).
- **Q6 — Departed-member revocation → YES**, explicit action deleting their
  `UserSharedFile` rows, with honest "can't recall downloads" copy; never silent.
- **Q7 — Sharing granularity → WHOLE BUSINESS CIRCLE** as the recipient cohort
  (mirrors how posts reuse `shared_users`; simplest mental model + least code).
  Ad-hoc per-person lists are deferred unless customers ask.

## 9. Implementation plan

1. **Schema & migrations (no UI):**
   - `mix ecto.gen.migration create_shared_files` + `create_user_shared_files`.
   - `Files.SharedFile` (with `checksum` + optional `scan_verdict`) +
     `Files.UserSharedFile` schemas (key material only on `UserSharedFile.key`;
     programmatic FKs not cast).
2. **Storage:** add a `uploads/files/` prefix path helper to the Tigris client;
   reuse `upload_pre_encrypted_to_storage` semantics for opaque blobs and
   `generate_presigned_url` for reads.
3. **Context `Mosslet.Files`:** `create_shared_file_zk`,
   `finalize_shared_file_zk`, `list_shared_files_for_group`,
   `get_user_shared_file`, `delete_shared_file`, `revoke_member_file_access`,
   `list_readers`. All writes via `Repo.transaction/1`. Server-authoritative
   recipient resolution from the circle's `UserGroup` members (I1).
4. **JS hook:** `assets/js/hooks/shared-file-hook.js` — generate `file_key`,
   run the client-side threat scan (§10), compute the plaintext checksum,
   `encryptSecretbox` the bytes, upload opaque blob, seal `file_key` per
   server-provided member key, finalize; download path unseals + fetches +
   decrypts + verifies checksum + re-scans in the browser. Register in
   `assets/js/app.js`.
5. **UI:** Files panel + transparency surface + upload/download/revoke +
   "scanned ✓/⚠" + checksum-verified badge on the business circle Show page;
   honest copy per §6.
6. **Tests:** LiveView + context tests mirroring `family_live_test.exs`
   conventions (onboarded_user + log_in + get_key; letters-only names). Cover:
   ZK upload/seal round-trip, eligibility enforcement (outsider can't be sealed),
   read authorization (non-member can't get presigned URL), revocation removes
   blob + keys, departed-member access revocation, transparency lists exactly
   current readers, checksum verify.
7. **Verify:** `mix precommit`, browser walkthrough, security checklist §7.

## 10. Client-side ZK threat protection (protection without policing)

This is how we **protect** businesses from malicious files, malware, and
AI-driven attacks **without** the server ever reading plaintext — reconciling
"don't police content" with "defend the business."

### 10.1 The trust-boundary principle

A file is plaintext in exactly two places, both on the user's **own device**:
the **uploader's browser** (before encryption) and the **recipient's browser**
(after decryption). All content-level defense runs there — never on the server,
which only ever holds opaque ciphertext. This mirrors the existing image NSFW
flow (client-side, documented fail-open).

### 10.2 Layers

1. **Structural hardening (always on, free with the architecture).**
   - **Server can't be the leak.** Opaque blobs + sealed keys → a breach of
     Mosslet (including an AI-orchestrated one) yields unreadable math, not data.
     This is the headline business pitch.
   - **Server-authoritative recipients (I1).** A compromised/AI-driven malicious
     client cannot exfiltrate by sealing a file for an outsider — the server
     chooses the recipient set from circle membership.
   - **Rate limiting + 50 MB cap + audit trail (§12 of the circles doc).** Blunt
     automated/abusive upload behavior; every share/revoke is logged (ZK, for
     admins).

2. **Integrity verification (I7).** Uploader's browser computes a checksum of the
   plaintext (encrypted with `file_key`). The recipient recomputes after decrypt
   and verifies → detects corruption or a malicious mid-stream swap. Mismatch =
   clear warning, no silent acceptance.

3. **Client-side malware / heuristic scan (I8).** At the trust boundary, the
   uploader's browser runs an optional scan over the plaintext bytes before
   encryption:
   - Dangerous-extension / double-extension warnings (e.g. `.exe`, `.scr`,
     `invoice.pdf.exe`).
   - Office-macro / active-content heuristics (warn on macro-bearing documents).
   - A pluggable WASM-based signature/heuristic scanner can be added behind the
     same interface (no new server surface).
   - The verdict is stored encrypted in `scan_verdict` (readable only by circle
     members) so recipients see "scanned ✓/⚠" — the server never reads it.
   - **Fail-open** (documented): if the scan cannot run (unsupported browser,
     model load failure), the upload proceeds and is marked "not scanned" rather
     than blocked, exactly like the existing NSFW behavior. We never let a
     scanner outage break legitimate sharing.
   - The recipient's browser may **re-scan after decrypt** (defense in depth, in
     case the uploader's client was compromised).

### 10.3 What we explicitly do NOT do

- ❌ No server-side content scanning (we can't read it; doing so would break ZK).
- ❌ No content policing / moderation of business files (matter for the business
  + governments, not the vendor).
- ❌ No "scan" that uploads plaintext anywhere off-device.

---

**Sign-off status: APPROVED.** Q1–Q7 resolved (§8); client-side ZK threat
protection (§10) + integrity checksum + departed-member revocation approved.
Implementing in the order in §9.
