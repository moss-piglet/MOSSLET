# Post-Quantum Encryption Migration

## Current Status (May 2026)

**Phase 1 COMPLETE**: Swapped `enacl` (C NIF, libsodium) for `metamorphic_crypto` v0.2 (Rust NIF, precompiled).

- Same NaCl wire format — zero data migration needed
- All existing encrypted data (text + binary/images) decrypts correctly
- `libsodium-dev` removed from Dockerfile
- Precommit passes, all tests green

**Phase 2 COMPLETE**: Hybrid PQ key wrapping (server-side) + PQ fields on users table.

- `pq_public_key` and `encrypted_pq_private_key` columns added to `users`
- PQ keypairs generated at registration via `MetamorphicCrypto.Hybrid.generate_keypair()`
- All server-side seal/unseal operations accept PQ key options
- `Encrypted.Utils.encrypt_message_for_user_with_pk/3` uses `MetamorphicCrypto.Seal.seal_for_user` when PQ key available
- `Encrypted.Utils.decrypt_message_for_user/3` uses `MetamorphicCrypto.Seal.unseal_from_user` (auto-detects v1/v2)
- PQ private key re-encrypted on password change
- `changeset_for_pq_migration/2` exists for progressive migration of existing users

**Phase 3 IN PROGRESS**: Browser-side WASM crypto + hybrid PQ for conversations.

- `metamorphic-crypto` Rust crate compiled to WASM, vendored in `assets/vendor/metamorphic-crypto/`
- WASM binary served at `/wasm/metamorphic_crypto_bg.wasm`
- `nacl.js` replaced with WASM-backed drop-in (same Rust code as server NIF)
- `sealForUser`/`unsealFromUser` added to browser crypto (auto-detects v1 legacy vs v2 hybrid)
- `session.js` centralizes key reading from DOM data attributes
- Conversation LiveView passes PQ keys via `data-pq-public-key` and `data-encrypted-pq-private-key`
- `start-conversation.js` seals conversation keys with hybrid PQ when PQ keys available
- `conversation-hooks.js` and `message-reactions.js` unseal via `unsealFromUser` (auto-detects format)
- All existing conversations (v1 sealed) continue to decrypt without migration
- All server-side seal operations (post_key, group_key, memory_key, connection_key, profile_key) pass PQ opts via `pq_opts_for_user/1` helper
- `PqResealWorker` (Oban, `:security` queue) progressively re-seals v1 context keys on login
- Re-seal is non-blocking (background job), retryable, and deduplicated (unique per 5 min)

### Phase 1 Files Changed

- `mix.exs` — removed `enacl`, added `metamorphic_crypto ~> 0.2`
- `lib/mosslet/encrypted/utils.ex` — rewritten to use `MetamorphicCrypto.SecretBox`, `BoxSeal`, `KDF`, `Seal`, `Hybrid`
- `lib/mosslet/platform/config.ex` — switched to `:crypto.strong_rand_bytes`
- `lib/mosslet/extensions/password_generator/word_generator.ex` — switched to `:crypto.strong_rand_bytes`
- `Dockerfile` — removed `libsodium-dev` from builder + runner stages

### Phase 2 Files Changed

- `priv/repo/migrations/20260514155214_add_pq_key_fields_to_users.exs` — adds PQ columns
- `lib/mosslet/accounts/user.ex` — PQ fields on schema, PQ keypair at registration, PQ re-encrypt on password change
- `lib/mosslet/encrypted/utils.ex` — `generate_pq_key_pairs/0`, hybrid seal/unseal with PQ opts
- `lib/mosslet/encrypted/users/utils.ex` — all decrypt paths pass PQ opts when available

### Phase 3 Files Changed (Conversations + Server-Side PQ Seal)

- `assets/vendor/metamorphic-crypto/` — WASM build (JS glue + `.wasm` binary)
- `priv/static/wasm/metamorphic_crypto_bg.wasm` — served by Phoenix static
- `lib/mosslet_web.ex` — added `"wasm"` to `static_paths`
- `config/test.exs` — added `'wasm-unsafe-eval'` to CSP
- `assets/js/crypto/nacl.js` — replaced libsodium-wrappers with WASM-backed implementation
- `assets/js/crypto/session.js` — new shared key helpers (centralizes DOM queries)
- `assets/js/hooks/conversation-hooks.js` — uses `unsealFromUser` via session.js
- `assets/js/hooks/message-reactions.js` — uses shared `getConversationKey` from session.js
- `assets/js/hooks/start-conversation.js` — uses `sealForUser` with PQ keys
- `lib/mosslet_web/live/conversation_live/show.ex` — passes PQ data attributes on composer
- `lib/mosslet_web/live/conversation_live/index.ex` — passes PQ keys in start-conversation event
- `lib/mosslet/encrypted/utils.ex` — added `pq_opts_for_user/1` helper
- `lib/mosslet/timeline/user_post.ex` — passes PQ opts when sealing post_key
- `lib/mosslet/accounts/user_connection.ex` — passes PQ opts when sealing connection_key
- `lib/mosslet/accounts/connection.ex` — passes PQ opts when sealing profile_key (private/connections)
- `lib/mosslet/memories/user_memory.ex` — passes PQ opts when sealing memory_key
- `lib/mosslet/groups/user_group.ex` — passes PQ opts when sealing group_key
- `lib/mosslet_web/helpers.ex` — passes PQ opts when sealing trix upload key
- `lib/mosslet/workers/pq_reseal_worker.ex` — new Oban worker for progressive v1→v2 re-seal
- `lib/mosslet/accounts.ex` — enqueues PqResealWorker on login

### Phase 3 Files Changed (Registration ZK)

- `assets/js/hooks/registration-hook.js` — new: browser-side key generation via WASM
- `assets/js/hooks/index.js` — registers RegistrationHook
- `assets/js/crypto/nacl.js` — exports generateKeyPair, generateSalt, encryptPrivateKey from WASM
- `lib/mosslet_web/live/user_registration_live.ex` — attaches RegistrationHook, routes to ZK or fallback changeset
- `lib/mosslet/accounts/user.ex` — `registration_changeset_zk/2`, `apply_zk_key_material/2`, ZK-aware `maybe_hash_password_no_name/2`

### Phase 3 Files Changed (Recovery Key ZK)

- `priv/repo/migrations/20260516030402_add_recovery_key_fields_to_users.exs` — adds recovery_key_hash, encrypted_recovery_private_key, recovery_key_created_at
- `lib/mosslet/accounts/user.ex` — `recovery_key_setup_changeset/2`, `recovery_key_clear_changeset/1`, `recovery_reset_password_changeset/3`
- `lib/mosslet/accounts.ex` — `setup_recovery_key/3`, `clear_recovery_key/1`, `verify_recovery_key/2`, `reset_password_with_recovery/5`
- `lib/mosslet_web/controllers/api/auth_controller.ex` — `recovery_data/2`, `recovery_reset/2` endpoints
- `lib/mosslet_web/router.ex` — routes for `/api/auth/recovery-data` and `/api/auth/recovery-reset`
- `lib/mosslet_web/routes/auth_routes.ex` — route for `/auth/recover-account`
- `assets/js/hooks/recovery-key-setup-hook.js` — new: browser-side recovery key generation
- `assets/js/hooks/account-recovery-hook.js` — new: browser-side account recovery via key
- `assets/js/crypto/nacl.js` — exports generateRecoveryKey, encryptPrivateKeyForRecovery, decryptPrivateKeyWithRecovery, recoveryKeyToSecret
- `lib/mosslet_web/live/user_settings/edit_forgot_password_live.ex` — rewritten for ZK recovery key setup
- `lib/mosslet_web/live/user_account_recovery_live.ex` — new: account recovery page (unauthenticated)
- `lib/mosslet_web/live/user_login_live.ex` — added link to recovery key page

### Phase 3 Files Changed (Profile pre_decrypt_user)

- `lib/mosslet/accounts/user.ex` — adds `:decrypted` virtual field to User schema
- `lib/mosslet_web/helpers.ex` — new `pre_decrypt_user/2` function: unseals user_key once, decrypts all profile fields (email, username, name, avatar_url, status_message), attaches as `.decrypted` map. Also adds `.decrypted` fast-path to `user_name/2`, `username/2,3`, `maybe_decr_username_for_user_group/3`
- `lib/mosslet_web/user_auth.ex` — `mount_current_scope/2` now calls `pre_decrypt_user` on the current user at mount time, so all authenticated pages have `user.decrypted` populated
- `lib/mosslet_web/components/design_system.ex` — `decr()` → `.decrypted[:username]`
- `lib/mosslet_web/live/user_settings_live.html.heex` — 8 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/user_settings/edit_profile_live.ex` — 5 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/user_settings/edit_password_live.ex` — 3 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/user_settings/edit_email_live.ex` — 1 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/user_settings/edit_details_live.ex` — 2 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/user_settings/manage_data_live.ex` — 1 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/post_live/form_component.ex` — 4 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/post_live/components.ex` — 2 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/post_live/replies/form_component.ex` — 2 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/group_live/form_component.ex` — 2 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/group_live/show.html.heex` — 2 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/group_live/replies/form_component.ex` — 2 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/user_connection_live/components.ex` — 1 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/user_connection_live/invite.ex` — 2 `decr()` → `.decrypted[:field]`
- `lib/mosslet_web/live/journal_live/book.ex` — 2 `decr()` → `.decrypted[:field]`

### Key Implementation Details

**Decrypt fallback pattern** (`Encrypted.Utils.decrypt/1`):
1. Try `MetamorphicCrypto.SecretBox.decrypt_string` (UTF-8 text — fast path)
2. If that fails, try `MetamorphicCrypto.SecretBox.decrypt` (raw binary — images/avatars)

**WASM initialization** (`nacl.js`):
- `ensureReady()` loads WASM on first crypto call
- All functions `await ensureReady()` then delegate to WASM bindings
- Same Rust code as NIF = guaranteed wire-format compatibility

**Hybrid auto-detection**:
- v1 (legacy): raw `crypto_box_seal` output — no version prefix
- v2 (hybrid): `0x02 || ML-KEM-768+X25519 cipherText || nonce || secretbox`
- `unsealFromUser` checks first byte; both server NIF and browser WASM use the same detection logic

---

## Phase 3 Remaining: Full Zero-Knowledge (NEXT)

Extend the WASM-backed browser crypto to all encrypted content, not just conversations.

### Architecture

```
metamorphic-crypto (Rust crate)
├── Compiles to WASM → browser (JS hooks encrypt/decrypt)
├── Compiles to NIF  → metamorphic_crypto Hex package (server-side)
└── Compiles to UniFFI → iOS/Android (native apps, future)
```

### What's Done (Conversations Only)

Conversations are now fully zero-knowledge with PQ support:
- Browser generates conversation keys, encrypts messages
- Server never sees plaintext message content
- New conversations sealed with hybrid PQ when both users have PQ keys
- Existing v1-sealed conversation keys auto-detected and decrypted

### What's Done

- **user_key / conn_key**: PQ-sealed at registration and progressively migrated on login
- **All resource context keys** (post, group, memory, connection, profile): PQ-sealed for new operations, v1 re-sealed in background via `PqResealWorker`
- **Conversations**: Fully browser-side ZK with PQ — sealForUser/unsealFromUser in WASM
- **WASM crypto module**: metamorphic-crypto compiled to WASM, served at `/wasm/`, same Rust code as server NIF
- **Posts (read path)**: Non-public post bodies decrypted browser-side via DecryptPost hook
- **Posts (write path)**: Non-public post body encryption browser-side via PostFormHook; multi-recipient key sealing remains server-side (pragmatic hybrid)
- **Groups**: GroupMessage content encrypted/decrypted browser-side via GroupMessageFormHook + DecryptGroupMessage
- **Registration**: Browser-side key generation via RegistrationHook — user_key, user_attributes_key, conn_key, X25519+PQ keypairs all generated in WASM; server receives only encrypted blobs and public keys. Graceful fallback to server-side key generation if WASM unavailable.
- **Recovery key**: ZK recovery key setup (RecoveryKeySetupHook) + account recovery (AccountRecoveryHook). Browser generates recovery key, encrypts private key backup. Server stores only Argon2 hash + encrypted blob. Recovery key consumed on use. New fields: `recovery_key_hash`, `encrypted_recovery_private_key`, `recovery_key_created_at`. Coexists with legacy `is_forgot_pwd?` email-based reset.
- **Profile data (phase 1 — pre_decrypt_user)**: Consolidated 41 scattered `decr()` template calls into a single `pre_decrypt_user/2` function that unseals the user_key once at mount time and decrypts all profile fields (email, username, name, avatar_url, status_message) in one pass. Results attached as `user.decrypted` map. 19 files updated. Performance improvement: 1 asymmetric unseal + N secretbox ops instead of N full decrypt chains. The decrypted map also carries sealed_user_key + encrypted field blobs for future browser-side ZK migration.

### What Remains — Browser-Side ZK Roadmap

Moving encryption from server to browser for all content. This is the path from "server encrypts, browser receives plaintext" to "browser encrypts, server stores opaque blobs."

#### Assessment: What Makes Posts Different from Conversations

Conversations were straightforward to make ZK because:
- Simple data model (one key per conversation, messages are strings)
- No visibility tiers (always two-party)
- No server-side rendering needed (messages rendered in JS hooks)

Posts are significantly more complex:
- **Visibility tiers**: public (server_public_key), connections, specific_groups, specific_users, private
- **UserPost fan-out**: Each recipient gets their own sealed copy of the post_key
- **Rich content**: Trix editor, image uploads (encrypted + uploaded to S3), URL previews, content warnings
- **Server-side rendering**: Templates call `decr_item()` inline — ALL decryption happens server-side before HTML reaches the browser
- **Timeline queries**: Posts are fetched, decrypted, and rendered in a single server round-trip
- **Public posts**: Must remain server-decryptable for unauthenticated viewers and SEO

#### Phase 3a: Infrastructure Prerequisites

These are needed before any content can move to browser-side encryption.

**1. SessionKeyDeriver hook (like Metamorphic)**

Currently Mosslet passes keys via data attributes on specific elements (e.g., `#conversation-composer`). For browser-side ZK across all pages, we need a central hook that:
- Derives session_key + private_key + user_key on every authenticated page load
- Stores derived keys in sessionStorage
- Provides them to all other hooks via `session.js` helpers
- Handles the persistent key cache (IndexedDB + Web Crypto wrapping key) so users don't re-enter passwords on browser restart

This is the foundation — every other browser-side feature depends on it.

Reference: Metamorphic's `SessionKeyDeriver` hook (see `METAMORPHIC_ENCRYPTION_ARCHITECTURE_EXAMPLE.md`)

**2. LoginHook (pre-submit KDF)**

Currently the password is submitted to the server, which derives the session key. For true ZK:
- Browser intercepts login form submit
- Derives session_key via Argon2id KDF in WASM (already available in metamorphic-crypto)
- Stores derived key in sessionStorage (password never stored)
- Submits the form normally for server-side password verification

This ensures the raw password never touches sessionStorage. The `deriveSessionKey()` function already exists in the WASM module.

**3. RegistrationHook (client-side key generation)**

Currently registration generates all keys server-side. For ZK:
- Browser generates X25519 keypair + hybrid PQ keypair + user_key + conn_key
- Encrypts private keys with session_key (derived from password)
- Seals user_key/conn_key with hybrid PQ
- Injects encrypted blobs into hidden form fields
- Submits form — server stores opaque blobs

This is how Metamorphic does registration. The WASM module already has all the primitives.

**4. Key cache (browser restart survival)**

SessionStorage is cleared on browser close. Without a persistent cache, users would have to re-enter their password every time they reopen the browser. Solution:
- AES-256-GCM wrapping key (non-extractable CryptoKey) in IndexedDB
- Encrypted key payload in localStorage
- Validated on restore via trial decryption
- Cleared on logout and password change

Reference: Metamorphic's `key_cache.js`

#### Phase 3b: Post Decryption in Browser (Read Path)

Move post decryption from server-side templates to browser-side JS hooks. This is the lower-risk step — it doesn't change how posts are encrypted, just where they're decrypted.

**Architecture change:**
- Server sends encrypted post content + sealed post_key to the browser (instead of decrypted plaintext)
- JS `DecryptPost` hook unseals the post_key, decrypts content, renders HTML
- Similar to how `DecryptMessage` works for conversations today

**Implications:**
- Templates change from `decr_item(post.body, ...)` to passing raw encrypted blobs
- Each post component needs a `phx-hook="DecryptPost"` with data attributes
- Images stay server-decrypted for now (they require S3 fetch + decrypt, which is server-only)
- **Public posts** can still be server-decrypted (optimization: avoid WASM overhead for public content)
- Timeline loading may feel slower (decrypt in JS vs server). Mitigate with: decrypt-on-scroll, skeleton loading, cached decrypted content

**What changes:**
- `index.html.heex` — pass encrypted blobs in data attributes instead of calling `decr_item()`
- New JS hook `DecryptPost` — unseals post_key, decrypts body/username/avatar/cw
- `session.js` — extended to provide privateKey/pqPrivateKey for post unseal

**What doesn't change:**
- Post creation flow (still server-side encrypted)
- Database schema
- UserPost key distribution
- Image encryption/decryption (still server-side)

#### Phase 3c: Post Encryption in Browser (Write Path)

Move post encryption from server to browser. This is the bigger change — the server would receive opaque ciphertext.

**Architecture change:**
- JS `PostFormHook` intercepts form submit (like `ConversationComposer` does)
- Browser generates post_key, encrypts body/username/avatar/cw with secretbox
- Browser seals post_key for each recipient (requires knowing recipients' public keys)
- Server receives encrypted blobs + sealed keys, stores as-is
- Server **never sees plaintext post content** for private/connections posts

**Hard problems:**
1. **Recipient list is server-determined**: The server knows who a user's connections are, but the browser needs their public keys to seal the post_key. Either:
   - Server sends recipient public keys to the browser (leaks who the recipients are to any browser extension)
   - Server seals the post_key on behalf of each recipient after receiving the encrypted post (hybrid approach — server sees post_key but not content... wait, that defeats the purpose)
   - Best: Server sends `[{user_id, public_key, pq_public_key}]` for connections. This is already semi-public data.

2. **Image uploads**: Currently images are encrypted server-side in `ImageUploadWriter`. For ZK:
   - Browser encrypts image bytes with post_key before upload
   - Upload encrypted blob to S3 (via presigned URL or LiveView upload)
   - Server never sees plaintext image
   - This requires changes to the upload pipeline

3. **URL previews**: Server fetches URL metadata. For ZK:
   - Server still fetches the URL preview (it sees the URL, which is in the post body)
   - For full ZK: server shouldn't see URLs either — but this is impractical for preview generation
   - Pragmatic: keep URL preview as server-side, encrypt the preview data with the post_key

4. **Public posts**: These MUST remain server-decryptable for:
   - Unauthenticated visitors (SEO, link sharing)
   - Server-side moderation (AI content moderation)
   - Bluesky federation (export worker decrypts post content)
   - Email notifications (post content in notification emails)

**Recommendation**: Only move **private and connections-visibility** posts to browser-side encryption. Public posts stay server-encrypted because the server needs to read them anyway.

#### Phase 3d: Groups, Memories, Profile Data

Same pattern as posts but simpler:
- Groups: `GroupMessage` content encrypted in browser with group_key
- Memories: Memory content encrypted in browser with memory_key
- Profile: Username, email, avatar encrypted in browser with user_key/conn_key

These can follow the same phased approach: first move the read path (decrypt in browser), then the write path (encrypt in browser).

#### Phase 3e: Supporting Features

**Recovery key**: Client-side recovery key generation + password reset flow. The WASM module already has `generateRecoveryKey()`, `encryptPrivateKeyForRecovery()`, `decryptPrivateKeyWithRecovery()`.

**Data export**: Client-side batch decryption — server sends encrypted blobs via push_event, JS decrypts everything and triggers download. Zero-knowledge export.

#### Priority Order

1. ~~**SessionKeyDeriver + LoginHook + key cache**~~ — DONE
2. ~~**Post decrypt in browser**~~ (read path) — DONE
3. ~~**Post encrypt in browser**~~ (write path) — DONE (connections/private posts)
4. ~~**Groups**~~ — DONE (read + write); Memories skipped (phasing out)
5. ~~**RegistrationHook**~~ — DONE (browser-side key generation)
6. ~~**Recovery key**~~ — DONE (ZK setup + account recovery)
7. ~~**Profile data**~~ — DONE: `pre_decrypt_user` consolidates user profile field decryption. 41 `decr()` call sites migrated to `.decrypted[:field]` pattern across 19 files. Sealed user_key + encrypted blobs included in decrypted map for future browser-side ZK (DecryptUserField hook). Remaining: `decr_avatar`/`decr_banner` (conn_key fields), `decr_uconn` (connection-shared data), and `decr_item` calls for profile/post context keys.
8. ~~**Subscription/billing ZK**~~ — DONE
9. ~~**Data export**~~ — DONE (client-side batch decryption + download)
10. ~~**Avatar/banner ZK display**~~ — DONE (Phases 1, 2, 2.5, 2.6, 2.7 — browser-side decryption of avatars/banners across all pages)
11. ~~**Avatar/banner ZK upload**~~ — DONE (Phase 4 — browser-side encryption for upload path, server never unseals conn_key)
12. ~~**Phase 4.5 cleanup**~~ — DONE (extracted shared upload helpers, fixed error handling, DRYed JS hooks, added timeout safety)
13. **Phase 5: Avatar/banner display pipeline → ZK** — DONE
    - Banner display: `user_home_live`, `timeline_live/index`, `edit_profile_live` now return encrypted data maps. `fetch_and_cache_banner` only stores encrypted binary in ETS. `liquid_timeline_header`, `liquid_banner_upload` support `encrypted_banner_data` attr.
    - Avatar display: `get_user_avatar` (~700 lines) replaced with `ensure_avatar_cached` (~50 lines). `decrypt_user_or_uconn_binary` removed. All display paths use `encrypted_avatar_data` + DecryptAvatar hook. ~600 lines removed from `helpers.ex`.
14. **Phase 6: Post images → ZK** — DONE
    - `TrixContentPostHook` uses cached post_key from `DecryptPost` via `session.js` `cachePostKey/getCachedPostKey` to decrypt image blobs in WASM.
    - New `"fetch_encrypted_post_images"` server event returns raw encrypted S3 blobs (base64-encoded). Server acts only as S3 proxy — never decrypts image content.
    - Same dual-path decryption as `DecryptAvatar` (string path B / binary path A).
    - Falls back to legacy server-side decrypt for public posts (server has server keypair).
    - Reply images remain on legacy server-side path (future migration).
15. **Phase 7: Post fields beyond body → ZK** — DONE
    - `decrypt_post_fields/3` extended: for `browser_decrypt?` posts, passes encrypted blobs for username, content_warning, content_warning_category, and url_preview (as JSON map).
    - `DecryptPost` hook extended to decrypt all fields and populate external DOM targets: `[data-decrypt-handle-target]` (username), `[data-decrypt-cw-text-target]` / `[data-decrypt-cw-category-target]` (content warnings), `[data-decrypt-url-preview-target]` (URL preview card).
    - `PostFormHook` extended to encrypt content_warning text/category alongside body.
    - `Post.encrypt_content_warning_if_present/3` accepts pre-encrypted CW ciphertext from browser.
16. **Phase 8: True ZK Read — favs_list, reposts_list, share_note, image_alt_texts → browser** — DONE
    - `decrypt_post_fields/3` no longer decrypts `favs_list`, `reposts_list`, `share_note`, or `image_alt_texts` server-side for `browser_decrypt?` posts. Passes encrypted blobs as `encrypted_favs_list`, `encrypted_reposts_list`, `encrypted_share_note`, `encrypted_image_alt_texts`.
    - `raw_key` removed from the `post.decrypted` map for non-public posts — the server no longer stores the plaintext post_key in process memory across renders.
    - `DecryptPost` hook extended with `decryptList()` helper to decrypt encrypted ID lists and string lists. Computes `liked` (fav membership) and `can_repost` (repost membership) browser-side, updating button DOM via the same pattern as `phx:update_post_fav_count`.
    - Share note decrypted browser-side, applied to `[data-decrypt-share-note-target]` DOM targets.
    - Image alt texts decrypted and cached per-post via `getCachedImageAltTexts()` export for future image modal integration.
    - `data-current-user-id`, `data-post-user-id`, `data-allow-shares`, `data-is-ephemeral` attributes added to DecryptPost element for browser-side membership and permission checks.
    - For timeline template: `liked` defaults to `false`, `can_repost` uses structural checks only (allow_shares, user_id, is_ephemeral) — hook corrects after decryption.
    - Image modal alt text decryption (`show_timeline_images` handler) still server-side (on-demand, not stored in assigns). Future: read from browser cache.

### What Remains — ZK PQ Finalization Roadmap

13. **Remaining `decr_avatar`/`decr_banner` server-side calls** — DONE. Banner display pipeline fully migrated to ZK (user_home_live, timeline_live, edit_profile_live). Avatar `get_user_avatar` replaced with `ensure_avatar_cached` (~600 lines removed). Legacy wrappers (`maybe_get_user_avatar`, `maybe_get_avatar_src`) now return `nil` and only trigger ETS population — all display goes through `encrypted_avatar_data` + DecryptAvatar hook. ~10 S3 deletion calls stay server-side (intentional — operational, not user content).
14. **Post images** — DONE. Post image display migrated to ZK browser-side decryption. `TrixContentPostHook` uses cached post_key from `DecryptPost` to decrypt image blobs in WASM. New `"fetch_encrypted_post_images"` server event returns raw encrypted S3 blobs (server never decrypts image content). Falls back to legacy server-side decrypt for public posts. Reply images remain server-side (future migration).
15. **Remaining post data fields** — DONE. Extended `DecryptPost` hook to decrypt username, content_warning, content_warning_category, and url_preview browser-side. `decrypt_post_fields/3` passes encrypted blobs for non-public posts. `PostFormHook` extended to encrypt content_warning fields. Post schema `encrypt_content_warning_if_present/3` accepts pre-encrypted CW from browser.
16. **True ZK Read (favs_list, reposts_list, share_note, image_alt_texts)** — DONE. All four fields moved to browser-side decryption for non-public posts. `raw_key` removed from `post.decrypted` map. `liked`/`can_repost` computed browser-side by DecryptPost hook after decrypting encrypted ID lists. Share note applied via DOM target. Image alt texts cached for future modal integration.
17. **Full data structure audit** — Comprehensive review of ALL encrypted data structures (excl. memories) to identify any gaps.
18. **ZK AI migration** — Journal insights, mood prompts, language filters → browser-based AI.
19. **NSFW fail-open verification** — Document behavior for all failure modes.
20. **Marketing updates** — Landing page, features, privacy policy reflecting fully ZK PQ architecture.

#### Phase 3f: Subscription/Billing ZK (NEW)

The billing system has deep server-side encryption key dependency. The `@key` / `@current_scope.key` flows through:

- `SubscribeController` — passes session key to Stripe checkout
- `SubscribeLive` — passes `@key` via `phx-value-key` on checkout/switch buttons
- `BillingLive` — decrypts customer IDs + emails for display, re-encrypts on format change
- `ReferralsLive` — decrypts referral codes, connect account IDs for Stripe Connect
- `TrialExpiredLive` — decrypts customer ID for Stripe portal
- `Customer` schema — encrypts/decrypts email, provider, provider_customer_id with session key
- Stripe service modules (checkout, portal, connect, sync) — all accept session_key parameter
- Background workers (`referral_payout_worker`) — already pass `nil` for key (can't encrypt)

**Decision needed**: Billing identifiers (Stripe customer IDs, payment intent IDs, invoice IDs) are **server-operational data** — the server needs them to call Stripe APIs. Options:
1. **Encrypt billing data with server-side key** (not user key) — server can always decrypt, no ZK overhead for operational data
2. **Keep billing data encrypted with user key** but decrypt in browser — complex, requires JS hooks on all billing pages
3. **Store billing identifiers unencrypted** — they're Stripe-generated IDs, not user content. Only encrypt user-facing data (email on customer record)

Option 1 is recommended: use a server-managed encryption key for billing operational data. This keeps Cloak defense-in-depth without requiring user keys for server→Stripe API calls.

### Reference

See `docs/METAMORPHIC_ENCRYPTION_ARCHITECTURE_EXAMPLE.md` for the full ZK pattern (Metamorphic app).

---

## Dependency Chain

```
metamorphic-crypto (Rust crate, the core — github.com/moss-piglet/metamorphic-crypto)
├── WASM build → browser (Mosslet + Metamorphic)
│     assets/vendor/metamorphic-crypto/metamorphic_crypto.js (wasm-bindgen glue)
│     assets/vendor/metamorphic-crypto/metamorphic_crypto_bg.wasm (compiled binary)
│     priv/static/wasm/metamorphic_crypto_bg.wasm (served by Phoenix)
└── NIF build → metamorphic_crypto (Hex package)
      Used by Mosslet server + Metamorphic server
```

Note: `@noble/post-quantum` was the original browser-side PQ library (pure JS). It has been replaced by the WASM build of `metamorphic-crypto` for both Mosslet and Metamorphic, ensuring the same Rust code runs on server (NIF) and browser (WASM).

### Upstream Monitoring

- **`metamorphic-crypto`** (Rust crate): Our implementation. Uses `ml-kem` crate (RustCrypto group) for ML-KEM-768, which tracks FIPS-203 final.
- **`metamorphic_crypto`** (Hex): Elixir NIF wrapper around the Rust crate.

### What to Watch

| Concern | Status | Action Needed |
|---------|--------|---------------|
| ML-KEM-768 (FIPS-203) | **Final standard** (Aug 2024) | Stable. No changes expected. |
| Hybrid KEM combiner | Draft (`irtf-cfrg-concrete-hybrid-kems`) | Monitor for breaking changes to the combiner construction |
| `ml-kem` Rust crate | Stable, RustCrypto group | Track for FIPS-203 compliance updates |
| FN-DSA (FIPS-206) | **Not final** — don't use yet | Wait for finalization if we ever need PQ signatures |

### When to Update metamorphic-crypto

- If the hybrid KEM IETF draft has breaking changes to the combiner (SHA3-256 over both shared secrets)
- If `ml-kem` Rust crate releases a security fix
- If we want to bump security level (ML-KEM-1024 instead of 768)
- Updates to the Rust crate automatically flow to both WASM and NIF builds

### Reference

- Standalone crate: `github.com/moss-piglet/metamorphic-crypto` (source of truth)
- Hex wrapper: `github.com/moss-piglet/metamorphic_crypto`
- Mosslet Dockerfile: `libsodium-dev` already removed, ready to deploy
