# Post-Quantum Encryption Migration

## Current Status (May 2026)

**Phase 1 COMPLETE**: Swapped `enacl` (C NIF, libsodium) for `metamorphic_crypto` v0.1.2 (Rust NIF, precompiled).

- Same NaCl wire format — zero data migration needed
- All existing encrypted data (text + binary/images) decrypts correctly
- `libsodium-dev` removed from Dockerfile
- Precommit passes, all tests green

### Files Changed (Mosslet)

- `mix.exs` — removed `enacl`, already had `metamorphic_crypto ~> 0.1.2`
- `lib/mosslet/encrypted/utils.ex` — rewritten to use `MetamorphicCrypto.SecretBox`, `BoxSeal`, `KDF`
- `lib/mosslet/platform/config.ex` — switched to `:crypto.strong_rand_bytes`
- `lib/mosslet/extensions/password_generator/word_generator.ex` — switched to `:crypto.strong_rand_bytes`
- `Dockerfile` — removed `libsodium-dev` from builder + runner stages

### Key Implementation Detail

`Mosslet.Encrypted.Utils.decrypt/1` uses a fallback pattern:
1. Try `MetamorphicCrypto.SecretBox.decrypt_string` (UTF-8 text — fast path)
2. If that fails, try `MetamorphicCrypto.SecretBox.decrypt` (raw binary — images/avatars)

This handles both encrypted text fields AND encrypted binary blobs through the same interface.

---

## Phase 2: Hybrid Post-Quantum Key Wrapping (NEXT)

Add ML-KEM-768 + X25519 hybrid encryption for key distribution.

### What This Achieves

Quantum resistance for all **key distribution** (the `box_seal` / `unseal` operations that wrap context keys for each user). The symmetric encryption (XSalsa20-Poly1305) is already quantum-resistant at 256-bit keys.

### Steps

1. **Migration**: Add `pq_public_key` and `encrypted_pq_private_key` columns to `users`
2. **Key generation**: On next login, generate hybrid keypair via `MetamorphicCrypto.Hybrid.generate_keypair()`
3. **Seal operations**: Use `MetamorphicCrypto.Seal.seal_for_user/3` with `pq_public_key:` option
4. **Unseal operations**: Use `MetamorphicCrypto.Seal.unseal_from_user/4` — auto-detects legacy (v1) vs hybrid (v2) format
5. **Progressive re-seal**: On login, re-seal existing context keys (user_key, post_keys, conn_keys) under hybrid

### Key APIs

```elixir
# Generate PQ keypair (server-side, on login)
{pq_pk, pq_sk} = MetamorphicCrypto.Hybrid.generate_keypair()

# Seal with PQ (new operations)
{:ok, ct} = MetamorphicCrypto.Seal.seal_for_user(context_key, user_pk, pq_public_key: pq_pk)

# Unseal (auto-detects v1 legacy or v2 hybrid)
{:ok, key} = MetamorphicCrypto.Seal.unseal_from_user(ct, pk, sk, pq_secret_key: pq_sk)

# Check format
MetamorphicCrypto.Hybrid.hybrid_ciphertext?(ciphertext)  # true if v2
```

### Ciphertext Format

- **v1 (legacy)**: raw `crypto_box_seal` output (X25519 only) — no version prefix
- **v2 (hybrid)**: `0x02 || ML-KEM-768 ciphertext (1088 bytes) || X25519 ephemeral pk (32 bytes) || nonce (24 bytes) || secretbox ciphertext`

Old and new ciphertexts coexist seamlessly — `unseal_from_user` auto-detects.

---

## Phase 3: Full Zero-Knowledge with WASM (FUTURE)

Move encryption/decryption to the browser using the `metamorphic-crypto` Rust crate compiled to WASM.

### Architecture

```
metamorphic-crypto (Rust crate)
├── Compiles to WASM → browser (JS hooks encrypt/decrypt)
├── Compiles to NIF  → metamorphic_crypto Hex package (server-side)
└── Compiles to UniFFI → iOS/Android (native apps)
```

### What Changes

- New features encrypt entirely client-side (LiveView hooks + WASM)
- Server stores opaque ciphertext blobs (can't decrypt)
- `MetamorphicCrypto` NIF still useful for: test fixtures, migration helpers, server-provisioned keys

### Reference

See `docs/METAMORPHIC_ENCRYPTION_ARCHITECTURE_EXAMPLE.md` for the full ZK pattern (Metamorphic app).

---

## Dependency Chain

```
@noble/post-quantum (JS, browser-side PQ for Metamorphic web app)
         ↕ (same algorithms, different implementation)
metamorphic-crypto (Rust crate, the core)
    ├── WASM build (browser, same as @noble/post-quantum in function)
    └── NIF build → metamorphic_crypto (Hex package, used by Mosslet server)
```

### Upstream Monitoring

- **`@noble/post-quantum`** (paulmillr): v0.6.1 (Apr 2026), self-audited. ML-KEM is FIPS-203 final. Used by Metamorphic's browser client. Pure JS implementation.
- **`metamorphic-crypto`** (Rust crate): Our implementation of the same algorithms in Rust. Uses `ml-kem` crate (Rust Crypto group) for ML-KEM-768, which tracks FIPS-203 final.
- **`metamorphic_crypto`** (Hex): Elixir NIF wrapper around the Rust crate.

### What to Watch

| Concern | Status | Action Needed |
|---------|--------|---------------|
| ML-KEM-768 (FIPS-203) | **Final standard** (Aug 2024) | Stable. No changes expected. |
| Hybrid KEM combiner | Draft (`irtf-cfrg-concrete-hybrid-kems`) | Monitor for breaking changes to the combiner construction |
| `@noble/post-quantum` | v0.6.1, self-audited | Track releases for security fixes |
| `ml-kem` Rust crate | Stable, RustCrypto group | Track for FIPS-203 compliance updates |
| FN-DSA (FIPS-206) | **Not final** — don't use yet | Wait for finalization if we ever need PQ signatures |

### When to Update metamorphic-crypto

- If the hybrid KEM IETF draft has breaking changes to the combiner (SHA3-256 over both shared secrets)
- If `ml-kem` Rust crate releases a security fix
- If we want to bump security level (ML-KEM-1024 instead of 768)
- Updates to the Rust crate automatically flow to `metamorphic_crypto` Hex on next release

## Follow-up Tasks (Next Session)

1. **Publish `metamorphic-crypto` to crates.io** — merge PR #2, `cargo publish`
2. **Update `metamorphic_crypto` Hex package** — swap `path = "./metamorphic-crypto"` to `metamorphic-crypto = "0.2"` in Cargo.toml, remove vendored copy, expose Cat-5 NIF functions, release v0.2.0 to Hex
3. **Update Metamorphic app** — point WASM build at the crates.io dep instead of local copy
4. **Phase 2 in Mosslet** — add PQ fields to users table, progressive hybrid key migration on login using `MetamorphicCrypto.Seal.seal_for_user/3`

### Reference

- PR: https://github.com/moss-piglet/metamorphic-crypto/pull/2
- Standalone crate: `github.com/moss-piglet/metamorphic-crypto` (source of truth)
- Hex wrapper: `github.com/moss-piglet/metamorphic_crypto`
- Mosslet Dockerfile: `libsodium-dev` already removed, ready to deploy
