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

### What Remains

1. **Progressive PQ migration for existing users** — on login, detect missing PQ keys, generate hybrid keypair client-side, re-seal user_key/conn_key, push to server
2. **Posts/timeline** — currently server-side encrypted; move to browser-side encrypt/decrypt
3. **Groups/connections** — same pattern: browser-side seal/unseal
4. **User profile data** — user_key and conn_key encryption in browser
5. **Data export** — client-side batch decryption (like Metamorphic's pattern)
6. **Key cache** — persistent key cache (IndexedDB + Web Crypto wrapping key) for browser restart survival
7. **Recovery key** — client-side recovery key generation + password reset flow
8. **Login hook** — pre-submit KDF (password never in sessionStorage)
9. **Registration hook** — client-side key generation during registration

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
