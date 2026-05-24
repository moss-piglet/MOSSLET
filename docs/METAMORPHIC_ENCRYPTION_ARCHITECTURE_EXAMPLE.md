# 🔐 Metamorphic Encryption Architecture

## Overview

Metamorphic is a **zero-knowledge, end-to-end encrypted** habit and self-improvement tracker. All user content is encrypted and decrypted **client-side** in the browser using an [open-source Rust crypto core](https://github.com/metamorphic/metamorphic-crypto) compiled to WebAssembly. The server **never** sees plaintext user data.

**Core guarantee**: The server stores only opaque ciphertext blobs and HMAC blind indexes. Even a full database breach reveals nothing about user habits, goals, reflections, or streaks. The plaintext email is never persisted — only a one-way HMAC hash (`email_hash`) and an E2E-encrypted blob (`encrypted_email`) are stored.

## Principles

1. All encryption/decryption happens **client-side** (Rust → WASM, loaded by browser)
2. Server stores **encrypted blobs** (binary) + **blind index hashes** (for lookups)
3. Each context (user, habit, family group) gets its own **symmetric key**
4. Symmetric keys are distributed via **asymmetric encryption** (NaCl box_seal)
5. User's private key survives password changes (re-encrypted with new session key)
6. Cloak (AES-256-GCM) adds a second at-rest encryption layer in Postgres
7. The API returns the same encrypted blobs — native clients decrypt on-device
8. The **raw password never touches sessionStorage** — only the Argon2id-derived session key
9. The crypto implementation is **open-source** and independently auditable (`#![forbid(unsafe_code)]`)

## Cryptographic Primitives

| Operation         | Algorithm                  | Implementation                   | Purpose                                    |
| ----------------- | -------------------------- | -------------------------------- | ------------------------------------------ |
| Symmetric encrypt | XSalsa20-Poly1305          | `metamorphic-crypto` (Rust/WASM) | Encrypt data with context key              |
| Symmetric decrypt | XSalsa20-Poly1305          | `metamorphic-crypto` (Rust/WASM) | Decrypt data with context key              |
| Hybrid seal       | ML-KEM-1024+X25519+XSalsa20 | `metamorphic-crypto` (Rust/WASM) | PQ-resistant key encryption (default, Cat-5)  |
| Hybrid open       | ML-KEM-1024+X25519+XSalsa20 | `metamorphic-crypto` (Rust/WASM) | PQ-resistant key decryption (auto-detects)    |
| Legacy seal       | X25519+XSalsa20            | `metamorphic-crypto` (Rust/WASM) | Encrypt key (legacy, pre-PQ migration)     |
| Legacy open       | X25519+XSalsa20            | `metamorphic-crypto` (Rust/WASM) | Decrypt key (legacy, pre-PQ migration)     |
| Key derivation    | Argon2id                   | `metamorphic-crypto` (Rust/WASM) | Derive session key from password           |
| Random key        | ---                        | `randombytes_buf`                | Generate context keys                      |
| Blind index       | HMAC-SHA512                | server-side `:crypto.mac`        | Case-insensitive email lookups             |

All ciphertext is stored as `nonce || ciphertext`, base64-encoded, then Cloak-wrapped for DB storage.

## Quantum Readiness

Metamorphic uses a **hybrid post-quantum KEM** (Key Encapsulation Mechanism) that combines classical X25519 with ML-KEM-768 (NIST FIPS 203). This follows the same approach as Signal (PQXDH), Apple iMessage (PQ3), and Chrome/TLS.

### What is quantum-resistant

- **All symmetric encryption** (XSalsa20-Poly1305, AES-256-GCM): quantum-resistant at 256-bit key lengths (~128-bit effective security via Grover's algorithm)
- **All key distribution** (for users with hybrid keys): sealed under ML-KEM-768 + X25519, resistant to both classical and quantum attacks
- **Password hashing** (Argon2id): not meaningfully threatened by known quantum algorithms
- **Blind indexes** (HMAC-SHA512): ~256-bit effective security post-quantum

### Hybrid scheme details

The hybrid KEM is provided by `@noble/post-quantum`'s `ml_kem768_x25519` module, which combines ML-KEM-768 and X25519 with a SHA3-256 combiner per the IETF `draft-irtf-cfrg-concrete-hybrid-kems` draft. Both shared secrets (from ML-KEM-768 and X25519) are concatenated with both ciphertexts and public keys, then hashed through SHA3-256 to derive the final shared secret. Both algorithms must be broken simultaneously to compromise a sealed key:

- If ML-KEM-768 is broken, X25519 still protects (classical security fallback)
- If X25519 is broken by a quantum computer, ML-KEM-768 still protects (PQ security)

### Version-tagged ciphertext format

```
Legacy (v1):  raw crypto_box_seal output (no version prefix)
Hybrid (v2):  0x02 || ML-KEM-768+X25519 cipherText || nonce || secretbox(plaintext, sharedSecret)
```

The `unsealFromUser` function auto-detects the format from the version tag byte, so existing legacy-sealed blobs continue to work without modification.

### Progressive migration for production users

Existing users without PQ keys are progressively migrated on their next login:

1. SessionKeyDeriver detects the user has no `encrypted_pq_private_key`
2. Client generates a hybrid ML-KEM-768+X25519 keypair
3. Client encrypts the hybrid private key with the session key
4. Client re-seals the `encrypted_user_key` under hybrid
5. Client pushes `pq_public_key`, `encrypted_pq_private_key`, and re-sealed `encrypted_user_key` to the server
6. All subsequent seal operations use hybrid

After PQ keypair generation, the server pushes all existing v1-sealed context keys
(habit keys, goal keys, reflection keys, event keys, group member keys) back to the
client. The client re-seals each one under the new hybrid KEM and pushes the updated
blobs back in a single batch. This ensures all context keys are quantum-resistant after
migration, not just the user key.

**Re-seal changes the wrapping, not the underlying symmetric key.** Each member's sealed
copy of a group key is independent (sealed to that member's public key), and the
underlying symmetric group key does not change during re-seal. This means group members
can migrate to hybrid at different times with no coordination — User A can re-seal their
copy while User B's copy remains v1-sealed until B logs in and migrates independently.

New registrations generate both X25519 and hybrid keypairs upfront.

### Library

- **`@noble/post-quantum`** v0.6.1 (vendored, 46KB minified ESM bundle)
- From the `noble` cryptography suite by Paul Miller (used by Protonmail, Metamask, ethers.js)
- The noble suite's core libraries (`@noble/hashes`, `@noble/curves`, `@noble/ciphers`) have been audited by Cure53; the `@noble/post-quantum` module builds on these audited dependencies and has undergone a self-audit with no major findings
- Internally uses SHA3-256, SHA3-512, SHAKE128, and SHAKE256 (Keccak family) as required by the FIPS 203 ML-KEM specification
- Pure TypeScript/JavaScript implementation of NIST FIPS 203 (ML-KEM), no WASM required

## Key Hierarchy

```
Password (never stored, never in sessionStorage)
  │
  ├─ Argon2id KDF ──► session_key (symmetric, derived at login before form submit)
  │                      │
  │                      ├─ Stored in sessionStorage (derived key only, never password)
  │                      │
  │                      └─ Encrypts: user's private key (secretbox)
  │
  └─ crypto_box_keypair ──► keypair (random public + private)
                               │
                               ├─ public_key → stored on server (users.public_key, Cloak-wrapped)
                               │
                               └─ private_key → encrypted with session_key
                                    stored as users.encrypted_private_key (Cloak-wrapped)

  ml_kem768_x25519.keygen ──► hybrid keypair (PQ + classical)
                               │
                               ├─ pq_public_key → stored on server (users.pq_public_key, Cloak-wrapped)
                               │
                               └─ pq_private_key → encrypted with session_key
                                    stored as users.encrypted_pq_private_key (Cloak-wrapped)
```

### Context Keys

```
user_key (symmetric, random 32 bytes)
  ├─ Encrypts: personal data (email, habits, reflections, streaks)
  └─ Distributed: sealForUser(user_key, public_key, pq_public_key) → users.encrypted_user_key
     (hybrid KEM when PQ keys available, legacy box_seal otherwise)

habit_key (symmetric, per-habit, random 32 bytes)
  ├─ Encrypts: habit name, description, check-in data
  └─ Distributed: sealForUser(habit_key, public_key, pq_public_key) → user_habits.encrypted_key

group_key (symmetric, per-family-group, random 32 bytes)
  ├─ Encrypts: shared goal names, group check-ins, accountability data, member nicknames
  └─ Distributed to each member: sealForUser(group_key, member.public_key, member.pq_public_key)
  └─ Rotated when members are added/removed
```

## Registration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    REGISTRATION (Browser)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User enters email + password                                │
│     RegistrationHook intercepts form submit (preventDefault)    │
│                                                                 │
│  2. Browser: generate salt (random 16 bytes)                    │
│     session_key = Argon2id(password, salt)                      │
│                                                                 │
│  3. Browser: keypair = crypto_box_keypair() (random)            │
│     encrypted_private_key = secretbox(private_key, session_key) │
│                                                                 │
│  4. Browser: user_key = generateKey() (random 32 bytes)         │
│     encrypted_user_key = box_seal(user_key, public_key)         │
│                                                                 │
│  5. Browser: encrypted_email = secretbox(email, user_key)       │
│     key_hash = salt + "$argon2id"                               │
│                                                                 │
│  6. Browser injects hidden fields, submits form                 │
│     Browser → Server: {                                         │
│       email (plaintext, transient — for confirmation email),    │
│       encrypted_email,                                          │
│       public_key,                                               │
│       encrypted_private_key,                                    │
│       encrypted_user_key,                                       │
│       key_hash,                                                 │
│       password (for Argon2 hashed_password on server)           │
│     }                                                           │
│                                                                 │
│  7. Server:                                                     │
│     - email_hash = HMAC-SHA512(downcase(email)) (blind index)   │
│     - Hashes password → hashed_password (Argon2, for auth)      │
│     - Stores encrypted blobs + public_key + email_hash          │
│     - Sends confirmation email using transient plaintext email  │
│     - Does NOT persist plaintext email (column removed)         │
│     - Cloak wraps all binary fields for at-rest encryption      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Note**: The server sees the plaintext email transiently during registration to send the confirmation email and compute the HMAC blind index. After the request completes, only `email_hash` (blind index) and `encrypted_email` (ciphertext) persist in the database. The plaintext `email` column has been removed.

## Login Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOGIN (Browser + Server)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User enters email + password                                │
│     LoginHook intercepts form submit (preventDefault)           │
│                                                                 │
│  2. Browser: POST /api/auth/salt { email }                      │
│     Server: looks up user by email_hash (HMAC blind index)      │
│     Server: returns real key_hash or timing-normalized fake hash │
│     Server → Browser: { key_hash } (contains salt)              │
│                                                                 │
│  3. Browser: parse salt from key_hash                           │
│     session_key = Argon2id(password, salt)                      │
│     sessionStorage._metamorphic_session_key_temp = session_key  │
│     (password is NEVER stored in sessionStorage)                │
│                                                                 │
│  4. Browser submits the original form (email + password)        │
│     Server: looks up user by email_hash, verifies password      │
│     Server: creates session token, redirects to /dashboard      │
│                                                                 │
│  5. /dashboard LiveView mounts with SessionKeyDeriver hook      │
│     SessionKeyDeriver reads from data attributes:               │
│     { public_key, encrypted_private_key, encrypted_user_key,    │
│       key_hash } — all base64-encoded                           │
│                                                                 │
│  6. Browser: reads session_key from sessionStorage (temp key)   │
│     private_key = secretbox_open(encrypted_private_key,         │
│                                  session_key)                   │
│     user_key = box_seal_open(encrypted_user_key,                │
│                              public_key, private_key)           │
│                                                                 │
│  7. Browser stores derived keys in sessionStorage:              │
│     _metamorphic_session_key (permanent)                        │
│     _metamorphic_private_key                                    │
│     _metamorphic_user_key                                       │
│     Removes _metamorphic_session_key_temp                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Persistent Key Cache (Browser Restart Survival)

Authentication (session cookie) and decryption (derived keys) are separate concerns. The remember-me cookie keeps the user authenticated server-side across browser restarts (14 days, reissued at 7 days). The persistent key cache keeps the client-side decryption keys available so the user doesn't have to re-enter their password.

This mirrors Proton's approach: the session token persists via cookie, and the derived key material persists via browser storage — but with an additional encryption layer using the Web Crypto API.

### Encryption at Rest (Web Crypto Wrapping)

The cached keys are **never stored as plaintext** in localStorage:

1. A **non-extractable AES-256-GCM `CryptoKey`** is generated via `crypto.subtle.generateKey()` with `extractable: false`
2. The `CryptoKey` object is stored in **IndexedDB** (the only browser storage that can hold `CryptoKey` objects)
3. The derived keys payload is **encrypted** with AES-256-GCM using this wrapping key, and the ciphertext + IV is stored in **localStorage**
4. On restore, the `CryptoKey` is loaded from IndexedDB and used to decrypt the localStorage ciphertext

**Why this is secure against physical/forensic extraction:**

- The `CryptoKey` is marked `extractable: false` — JavaScript cannot read the raw key material, it can only use the key for encrypt/decrypt operations via the Web Crypto API
- An adversary who copies the raw localStorage LevelDB files from disk gets only AES-256-GCM ciphertext
- The IndexedDB `CryptoKey` object is opaque — it cannot be serialized to raw bytes by any JS API
- Both Chrome and Firefox store non-extractable `CryptoKey` objects in browser-internal keystores that are not trivially extractable from the profile directory

**Graceful degradation:** If Web Crypto or IndexedDB is unavailable (e.g., some privacy-focused browsers), caching is silently skipped and the user falls back to the existing reauth flow (enter password on each restart).

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              PERSISTENT KEY CACHE (Browser, client-only)         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  On login / reauth (after keys are derived):                    │
│    1. Keys stored in sessionStorage (same as before)            │
│    2. Generate or retrieve non-extractable AES-256-GCM          │
│       CryptoKey from IndexedDB                                  │
│    3. Encrypt { sessionKey, privateKey, userKey, cachedAt }     │
│       with AES-256-GCM wrapping key                             │
│    4. Store { iv, ciphertext } in localStorage                  │
│       (skipped if user opted out via "Stay signed in" toggle)   │
│       (skipped if Web Crypto / IndexedDB unavailable)           │
│                                                                 │
│  On page load (SessionKeyDeriver hook):                         │
│    1. Check sessionStorage → keys present? Use them (fast path) │
│    2. Check sessionStorage temp key → derive & store (login)    │
│    3. Check localStorage cache → load CryptoKey from IndexedDB  │
│       → decrypt ciphertext → validate by trial decryption       │
│       of encrypted_private_key with cached sessionKey           │
│       → if valid: populate sessionStorage, proceed              │
│       → if invalid (password changed): clear cache, reauth     │
│    4. No keys anywhere → redirect to /users/reauthenticate      │
│                                                                 │
│  On logout:                                                     │
│    Clear sessionStorage, localStorage ciphertext, AND           │
│    IndexedDB wrapping key                                       │
│                                                                 │
│  On password change:                                            │
│    Clear localStorage cache + IndexedDB wrapping key            │
│                                                                 │
│  User opt-out ("Always require password"):                      │
│    _metamorphic_persist_keys = "never" in localStorage          │
│    Clears cache + wrapping key immediately                      │
│    Toggle in Settings → Security → "Stay signed in"             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Security Properties

| Property                      | Implementation                                                                      |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| Encrypted at rest             | AES-256-GCM ciphertext in localStorage; non-extractable wrapping key in IndexedDB   |
| Forensic extraction resistant | Raw localStorage files yield only ciphertext; CryptoKey material is non-extractable |
| Cleared on logout             | sessionStorage, localStorage ciphertext, and IndexedDB wrapping key all deleted     |
| Cleared on password change    | Old cached session key can no longer decrypt, cache + wrapping key cleared          |
| Validated on restore          | Trial decryption of encrypted_private_key ensures stale keys are rejected           |
| User can opt out              | "Stay signed in" toggle in Settings disables caching and clears existing cache      |
| Graceful degradation          | If Web Crypto / IndexedDB unavailable, caching silently skipped (reauth fallback)   |
| No server changes needed      | Purely client-side; server sees no difference                                       |

### Browser Storage Keys

| Storage      | Key                                        | Content                                                                |
| ------------ | ------------------------------------------ | ---------------------------------------------------------------------- |
| localStorage | `_metamorphic_key_cache`                   | JSON: `{ iv: number[], ct: number[] }` (AES-256-GCM encrypted payload) |
| localStorage | `_metamorphic_persist_keys`                | Preference: `"always"` (default) or `"never"` (opt-out)                |
| IndexedDB    | `wrapping_key` in `_metamorphic_crypto` DB | Non-extractable AES-256-GCM `CryptoKey` object                         |

### JS Module (`assets/js/crypto/key_cache.js`)

| Function                  | Async | Purpose                                                                          |
| ------------------------- | ----- | -------------------------------------------------------------------------------- |
| `cacheKeys(s, p, u)`      | yes   | Encrypt keys with wrapping CryptoKey, store ciphertext in localStorage           |
| `getCachedKeys()`         | yes   | Load wrapping key from IndexedDB, decrypt localStorage ciphertext                |
| `clearKeyCache()`         | no\*  | Remove localStorage ciphertext (sync) + IndexedDB wrapping key (fire-and-forget) |
| `isPersistDisabled()`     | no    | Check if user opted out                                                          |
| `setPersistPreference(v)` | no    | Set preference; clears cache if set to `"never"`                                 |
| `getPersistPreference()`  | no    | Read current preference (defaults to `"always"`)                                 |

\* `clearKeyCache` is designed to be callable from synchronous contexts (e.g., click handlers). The localStorage removal is synchronous; the IndexedDB deletion runs as a fire-and-forget background operation.

## Password Change Flow

```
Password changes do NOT break access to existing encrypted data:

1. Browser: derive OLD session_key from old password + existing salt
2. Browser: decrypt private_key with OLD session_key
3. Browser: generate NEW salt, derive NEW session_key from new password
4. Browser: re-encrypt SAME private_key with NEW session_key
5. Browser → Server: { new_encrypted_private_key, new_key_hash, new_password }
6. Server: update hashed_password, encrypted_private_key, key_hash

Result: Same private key, new password. All context keys remain accessible.
```

## Recovery Key Flow

The recovery key provides a safety net for users who forget their password. Without it, losing the password means permanently losing access to all encrypted data — by design (zero-knowledge).

### Recovery Key Setup (Authenticated, Settings page)

```
┌─────────────────────────────────────────────────────────────────┐
│              RECOVERY KEY SETUP (Browser, authenticated)         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Browser: decrypt private_key with current session_key       │
│                                                                 │
│  2. Browser: generate recovery_secret (32 random bytes)         │
│     Encode as base32: each byte → 2 base32 chars (64 total)   │
│     Format as human-readable key: 13 hyphen-separated groups   │
│     (twelve groups of 5 + one group of 4)                      │
│     Derive canonical secret by roundtripping through encoding  │
│                                                                 │
│  3. Browser: encrypted_recovery_private_key =                   │
│       secretbox(private_key, recovery_secret)                   │
│                                                                 │
│  4. Browser → Server (via LiveView push):                       │
│     { recovery_secret (raw), encrypted_recovery_private_key }   │
│                                                                 │
│  5. Server:                                                     │
│     recovery_key_hash = Argon2(recovery_secret)                 │
│     Store: recovery_key_hash, encrypted_recovery_private_key    │
│     Store: recovery_key_created_at                              │
│                                                                 │
│  6. User writes down the recovery key (shown once, never stored)│
│                                                                 │
│  Note: recovery_secret travels over the authenticated LiveView  │
│  WebSocket (TLS) — it is never stored client-side.              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Password Reset via Recovery Key (Unauthenticated)

```
┌─────────────────────────────────────────────────────────────────┐
│           PASSWORD RESET VIA RECOVERY KEY (Browser + Server)     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User enters email + recovery key on /users/recover-account  │
│                                                                 │
│  2. Browser: recovery_secret = recoveryKeyToSecret(recovery_key)│
│     Browser: POST /api/auth/recovery-data                       │
│       { email, recovery_key: recovery_secret }                  │
│     Server: looks up user by email_hash (HMAC blind index)      │
│     Server: verifies recovery_secret against recovery_key_hash  │
│     Server → Browser: {                                         │
│       encrypted_recovery_private_key,                           │
│       public_key,                                               │
│       encrypted_user_key                                        │
│     }                                                           │
│                                                                 │
│  3. Browser: private_key = secretbox_open(                      │
│       encrypted_recovery_private_key, recovery_secret)          │
│                                                                 │
│  4. User enters new password                                    │
│     Browser: new_salt = random, new_session_key = Argon2id(...)│
│     Browser: new_encrypted_private_key =                        │
│       secretbox(private_key, new_session_key)                   │
│     Browser: new_key_hash = new_salt + "$argon2id"              │
│                                                                 │
│  5. Browser → Server: {                                         │
│       email, recovery_secret (for re-verification),             │
│       new_password, new_encrypted_private_key, new_key_hash     │
│     }                                                           │
│     (User identified by email HMAC blind index — no client-     │
│      supplied user_id, preventing IDOR attacks)                  │
│                                                                 │
│  6. Server:                                                     │
│     - Looks up user by email_hash (HMAC blind index)            │
│     - Re-verifies recovery_secret against stored hash           │
│     - Hashes new password → hashed_password                     │
│     - Updates encrypted_private_key, key_hash                   │
│     - CLEARS recovery key fields (must regenerate)              │
│     - Invalidates all existing session tokens                   │
│     - Logs user in with new session                             │
│                                                                 │
│  Result: Same private key, new password. Recovery key consumed. │
│  User must set up a new recovery key in Settings.               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Recovery Key Database Fields

| Column                           | Type            | Encryption                    | Purpose                                    |
| -------------------------------- | --------------- | ----------------------------- | ------------------------------------------ |
| `recovery_key_hash`              | `:string`       | Argon2                        | Server-side recovery key verification      |
| `encrypted_recovery_private_key` | `:binary`       | Cloak (secretbox blob inside) | Private key encrypted with recovery secret |
| `recovery_key_created_at`        | `:utc_datetime` | —                             | When recovery key was set up               |

### Recovery Key Security Properties

| Property                        | Implementation                                                     |
| ------------------------------- | ------------------------------------------------------------------ |
| Recovery secret never stored    | Shown once to user, never in sessionStorage or database            |
| Server can't use recovery key   | Only the Argon2 hash is stored; encrypted blob requires raw secret |
| Recovery key is consumed on use | Fields cleared after successful reset; user must regenerate        |
| Timing-safe verification        | Argon2 hash comparison via `Argon2.verify_pass`                    |
| No client-supplied user ID      | Server looks up user by email HMAC blind index, preventing IDOR    |
| Rate-limited API (Postgres)     | Recovery endpoint: 3 req/min, Postgres-backed (cluster-safe)       |
| Timing-normalized verification  | `Argon2.no_user_verify()` on both user-not-found and wrong-key     |

## Reminder Labels (ZK Push Notifications)

Push notifications are traditionally a privacy compromise — the server must know what to display. Metamorphic solves this with a zero-knowledge approach that keeps notification text encrypted while still delivering personalized reminders.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│          ZK REMINDER LABELS (Client + Service Worker)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Two sources of notification text (both ZK):                    │
│                                                                 │
│  1. Auto-labels (primary path):                                 │
│     - Every time a habit/goal/event card decrypts on page       │
│       load, the decrypted name is cached in IndexedDB           │
│     - Service worker reads cached labels when push fires        │
│     - No crypto needed in SW — labels are already plaintext     │
│       in the local cache                                        │
│                                                                 │
│  2. Custom labels (user-written):                               │
│     - User types custom notification text (e.g. "🏃 Run 5K!")  │
│     - Client encrypts with user_key (secretbox)                 │
│     - Server stores encrypted_reminder_label blob               │
│     - Push payload includes the encrypted blob                  │
│     - SW decrypts using user_key from IndexedDB cache           │
│                                                                 │
│  Fallback chain:                                                │
│     Custom label → Auto-cached name → Generic text              │
│                                                                 │
│  Cache lifecycle:                                               │
│     - Populated: on every page load (card decrypt hooks)        │
│     - Cleared: on logout, password change, key cache clear      │
│     - Rebuilt: automatically on next page load after login      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Why user_key (not a separate key)

The `user_key` is the correct choice for encrypting reminder labels because:

1. **Already cached in IndexedDB** — part of the persistent key cache, accessible to the SW
2. **Stable across password changes** — the private key wrapper changes but user_key doesn't
3. **Stable across recovery** — recovery restores the same private key → unseals the same user_key
4. **Same sensitivity level** — reminder labels are equivalent to habit/goal names (same key encrypts both)
5. **PQ-protected at distribution** — user_key is sealed with hybrid ML-KEM-768+X25519

### Service Worker Decryption

The service worker reads from the same `_metamorphic_crypto` IndexedDB database used by the key cache. On push:

1. Read `reminder_labels` from IndexedDB → lookup by `habit_id`/`goal_id`/`event_id` from payload
2. If found: display personalized text (e.g. "⏰ Morning Meditation")
3. If not found: display generic text (e.g. "Time to check in on your habit!")

### Security Properties

| Property                     | Implementation                                                          |
| ---------------------------- | ----------------------------------------------------------------------- |
| Server never sees label text | Encrypted with user_key (XSalsa20-Poly1305) before leaving the browser  |
| Cloak at-rest protection     | encrypted_reminder_label is Cloak-wrapped in Postgres (AES-256-GCM)     |
| Labels cleared on logout     | IndexedDB `reminder_labels` key deleted alongside wrapping key          |
| Labels cleared on pwd change | Same cache lifecycle as all other derived keys                          |
| Survives browser restart     | IndexedDB persists across restarts (same as key cache)                  |
| Falls back gracefully        | Generic text if no cached label (new device, cleared storage, etc.)     |
| No crypto in SW (primary)    | Auto-labels are pre-decrypted plaintext cached locally — no WASM needed |

## Habit Data Encryption

### Creating a Habit

```
Browser:
  1. habit_key = generateKey()
  2. encrypted_name = secretbox("Exercise 3x/week", habit_key)
  3. encrypted_description = secretbox("Morning routine", habit_key)
  4. encrypted_cue = secretbox("After morning coffee", habit_key)  // optional
  5. user_encrypted_habit_key = box_seal(habit_key, user.public_key)
  6. Push to server: { encrypted_name, encrypted_description, encrypted_cue, user_encrypted_habit_key }

Server:
  - Stores encrypted blobs in habits table
  - Stores user_encrypted_habit_key in user_habits join table
  - Cloak wraps all binary fields
```

### Check-in / Streak Recording

```
Browser:
  1. Decrypt habit_key: box_seal_open(user_habit.encrypted_key, pk, sk)
  2. encrypted_check_in = secretbox(JSON.stringify({
       completed: true,
       timestamp: "2025-01-15T08:30:00Z"
     }), habit_key)
  3. Push to server: { habit_id, encrypted_check_in, date }

Server:
  - Stores encrypted check-in blob + plaintext date (for ordering/queries)
  - Date is stored in plaintext — it's metadata needed for streak calculation
  - The content of the check-in is always encrypted
```

### Reading Habits

```
Server → Browser:
  - Sends Cloak-unwrapped encrypted blobs + encrypted habit keys (base64)

Browser:
  1. private_key already in sessionStorage (derived at login)
  2. For each habit:
     habit_key = box_seal_open(user_habit.encrypted_key, public_key, private_key)
     name = secretbox_open(encrypted_name, habit_key)
     description = secretbox_open(encrypted_description, habit_key)
  3. For each check-in:
     data = JSON.parse(secretbox_open(encrypted_check_in, habit_key))
```

## Family/Group Encryption

Groups use the same context-key pattern as habits, but the key is distributed to multiple members.

### Creating a Group

```
Browser (creator):
  1. group_key = generateKey()
  2. encrypted_group_name = secretbox("Smith Family", group_key)
  3. For each member (including creator):
     member_encrypted_key = box_seal(group_key, member.public_key)
  4. Push to server: { encrypted_group_name, member_keys: [...] }
```

### Adding/Removing Members

```
Adding a member:
  1. Existing member decrypts group_key
  2. Re-encrypts group_key for new member: box_seal(group_key, new_member.public_key)
  3. Server validates encrypted key blob (valid base64, decoded size 80–2048 bytes)
  4. Server stores new group_member record with encrypted key

Removing a member:
  1. Delete the member's group_member record (they lose access to group_key)
  2. Rotate group_key:
     a. Generate new group_key
     b. Re-encrypt all shared goals with new key
     c. Re-encrypt new key for each remaining member
  3. This ensures the removed member can't decrypt future data
```

## Data Attributes (LiveView → Browser Bridge)

Encrypted keys are passed from LiveView to JS hooks via HTML data attributes on the `#session-key-deriver` element (rendered in `Layouts.app` for all authenticated pages):

| Attribute                    | Content                        | Source                       |
| ---------------------------- | ------------------------------ | ---------------------------- |
| `data-key-hash`              | Salt + algorithm params        | `user.key_hash`              |
| `data-public-key`            | User's public key (base64)     | `user.public_key`            |
| `data-encrypted-private-key` | Encrypted private key (base64) | `user.encrypted_private_key` |
| `data-encrypted-user-key`    | Encrypted user_key (base64)    | `user.encrypted_user_key`    |

Per-habit attributes on `HabitCardHook` elements:

| Attribute                    | Content                              | Source                        |
| ---------------------------- | ------------------------------------ | ----------------------------- |
| `data-encrypted-key`         | Encrypted habit context key (base64) | `user_habit.encrypted_key`    |
| `data-encrypted-name`        | Encrypted habit name (base64)        | `habit.encrypted_name`        |
| `data-encrypted-description` | Encrypted habit description (base64) | `habit.encrypted_description` |
| `data-encrypted-cue`         | Encrypted contextual cue (base64)    | `habit.encrypted_cue`         |

## Database Schema (Encrypted Fields)

### users

| Column                     | Type      | Encryption                    | Purpose                                             |
| -------------------------- | --------- | ----------------------------- | --------------------------------------------------- |
| `email_hash`               | `:binary` | HMAC-SHA512 (blind index)     | Email lookups (downcased before hashing)            |
| `encrypted_email`          | `:binary` | Cloak (secretbox blob inside) | E2E encrypted email                                 |
| `hashed_password`          | `:string` | Argon2                        | Server-side auth                                    |
| `public_key`               | `:binary` | Cloak                         | X25519 public key                                   |
| `encrypted_private_key`    | `:binary` | Cloak (secretbox blob inside) | X25519 private key encrypted with session_key       |
| `pq_public_key`            | `:binary` | Cloak                         | ML-KEM-768+X25519 hybrid encapsulation key          |
| `encrypted_pq_private_key` | `:binary` | Cloak (secretbox blob inside) | Hybrid decapsulation key encrypted with session_key |
| `encrypted_user_key`       | `:binary` | Cloak (hybrid or box_seal)    | user_key sealed with hybrid KEM or legacy box_seal  |
| `key_hash`                 | `:string` | ---                           | Salt + params for re-deriving session_key           |

**Note**: The plaintext `email` column has been removed. The `email` field exists only as a virtual field on the Ecto schema for transient validation. All lookups use `email_hash`.

### habits

| Column                  | Type                | Encryption                    | Purpose                               |
| ----------------------- | ------------------- | ----------------------------- | ------------------------------------- |
| `id`                    | `:binary_id` (UUID) | —                             | Primary key                           |
| `user_id`               | `:id`               | —                             | FK to users                           |
| `encrypted_name`        | `:binary`           | Cloak (secretbox blob inside) | Habit name                            |
| `encrypted_description` | `:binary`           | Cloak (secretbox blob inside) | Habit description                     |
| `encrypted_category`    | `:binary`           | Cloak (secretbox blob inside) | Category label                        |
| `encrypted_cue`         | `:binary`           | Cloak (secretbox blob inside) | Contextual cue ("After I…" / "When…") |
| `color`                 | `:string`           | —                             | UI color (not sensitive)              |
| `position`              | `:integer`          | —                             | Sort order                            |
| `archived`              | `:boolean`          | —                             | Archive flag                          |
| `frequency`             | `:string`           | —                             | "daily" or "weekly"                   |
| `group_id`              | `:binary_id` (UUID) | —                             | FK to groups (optional)               |

### user_habits

| Column          | Type                | Encryption                   | Purpose                           |
| --------------- | ------------------- | ---------------------------- | --------------------------------- |
| `id`            | `:binary_id` (UUID) | —                            | Primary key                       |
| `user_id`       | `:id`               | —                            | FK                                |
| `habit_id`      | `:binary_id`        | —                            | FK                                |
| `encrypted_key` | `:binary`           | Cloak (box_seal blob inside) | habit_key encrypted for this user |
| `role`          | `:string`           | —                            | "owner" or "member"               |

### check_ins

| Column           | Type                | Encryption                    | Purpose                                    |
| ---------------- | ------------------- | ----------------------------- | ------------------------------------------ |
| `id`             | `:binary_id` (UUID) | —                             | Primary key                                |
| `habit_id`       | `:binary_id`        | —                             | FK                                         |
| `user_id`        | `:id`               | —                             | FK                                         |
| `date`           | `:date`             | —                             | Plaintext date (needed for streak queries) |
| `encrypted_data` | `:binary`           | Cloak (secretbox blob inside) | Check-in details (completed, notes, mood)  |

### check_in_reactions

Reactions are plaintext metadata (emoji identifiers + user attribution). They contain no user-generated text content, so encryption is not required. Auto-deleted after 7 days by Oban cron worker.

| Column        | Type                | Encryption | Purpose                                          |
| ------------- | ------------------- | ---------- | ------------------------------------------------ |
| `id`          | `:binary_id` (UUID) | —          | Primary key                                      |
| `check_in_id` | `:binary_id`        | —          | FK to check_ins                                  |
| `user_id`     | `:id`               | —          | FK to users (who reacted)                        |
| `emoji`       | `:string`           | —          | Emoji identifier (fire, clap, heart, star, etc.) |
| `inserted_at` | `:utc_datetime`     | —          | When the reaction was created                    |
| `updated_at`  | `:utc_datetime`     | —          | Timestamp                                        |

**Constraints:** Unique on `(user_id, check_in_id)` — one reaction per user per check-in. Max 3 reactions per user per day (enforced application-side).

### reflections

Reflections use the same per-entry context-key pattern as habits: each reflection gets its own random 32-byte symmetric key, sealed to the owner's public key (hybrid PQ KEM when available, legacy `box_seal` otherwise) and stored on the `user_reflections` join table. The server only ever sees encrypted content, prompt, mood, and emotions, plus a plaintext date (for ordering and grouping). Mood values are drawn from a fixed 9-mood vocabulary (`Metamorphic.Reflections.Moods`); emotion tags are a JSON array of keys from a curated 44-emotion vocabulary (`Metamorphic.Reflections.Emotions`) with an enforced max of 5 tags per reflection — both are encrypted client-side with the per-reflection key before they ever reach the server.

| Column               | Type                | Encryption                    | Purpose                                               |
| -------------------- | ------------------- | ----------------------------- | ----------------------------------------------------- |
| `id`                 | `:binary_id` (UUID) | —                             | Primary key                                           |
| `user_id`            | `:id`               | —                             | FK to users                                           |
| `habit_id`           | `:binary_id` (UUID) | —                             | FK to habits (optional, for habit-linked reflections) |
| `encrypted_content`  | `:binary`           | Cloak (secretbox blob inside) | Reflection body                                       |
| `encrypted_prompt`   | `:binary`           | Cloak (secretbox blob inside) | Snapshot of the daily prompt                          |
| `encrypted_mood`     | `:binary`           | Cloak (secretbox blob inside) | Single mood key from the 9-mood vocabulary            |
| `encrypted_emotions` | `:binary`           | Cloak (secretbox blob inside) | JSON array of emotion keys (max 5)                    |
| `show_prompt`        | `:boolean`          | —                             | Whether to display the prompt with the entry          |
| `date`               | `:date`             | —                             | Plaintext date (ordering, pagination, grouping)       |
| `mood`               | `:string`           | —                             | Legacy plaintext mood; kept only for backfill         |

### user_reflections

| Column          | Type                | Encryption                      | Purpose                                |
| --------------- | ------------------- | ------------------------------- | -------------------------------------- |
| `id`            | `:binary_id` (UUID) | —                               | Primary key                            |
| `user_id`       | `:id`               | —                               | FK                                     |
| `reflection_id` | `:binary_id`        | —                               | FK                                     |
| `encrypted_key` | `:binary`           | Cloak (hybrid seal or box_seal) | reflection_key encrypted for this user |
| `role`          | `:string`           | —                               | "owner" (future: "member" for shared)  |

### goals

| Column                  | Type                | Encryption                    | Purpose                                      |
| ----------------------- | ------------------- | ----------------------------- | -------------------------------------------- |
| `id`                    | `:binary_id` (UUID) | —                             | Primary key                                  |
| `user_id`               | `:id`               | —                             | FK to users                                  |
| `encrypted_title`       | `:binary`           | Cloak (secretbox blob inside) | Goal title                                   |
| `encrypted_description` | `:binary`           | Cloak (secretbox blob inside) | Goal description                             |
| `encrypted_intention`   | `:binary`           | Cloak (secretbox blob inside) | "When → Then" when-then plan (JSON)          |
| `encrypted_obstacle`    | `:binary`           | Cloak (secretbox blob inside) | WOOP obstacle ("What might get in the way?") |
| `confidence`            | `:integer`          | —                             | Self-rated confidence 1–10 (not sensitive)   |
| `goal_type`             | `:string`           | —                             | "open", "numeric", or "date"                 |
| `target_value`          | `:integer`          | —                             | Numeric target (not sensitive)               |
| `current_value`         | `:integer`          | —                             | Current progress (not sensitive)             |
| `target_date`           | `:date`             | —                             | Target deadline (not sensitive)              |
| `status`                | `:string`           | —                             | "active", "completed", "paused", "abandoned" |
| `color`                 | `:string`           | —                             | UI color (not sensitive)                     |
| `auto_update`           | `:boolean`          | —                             | Auto-increment on linked habit check-in      |

### reminders / goal_reminders / event_reminders

All reminder tables store scheduling metadata (plaintext time, days, channels) plus an optional **encrypted reminder label** for personalized push notifications. The label is encrypted client-side with the user's symmetric `user_key` (XSalsa20-Poly1305), so the server never sees plaintext notification text.

When a reminder fires, the push payload includes the encrypted label blob. The service worker decrypts it using the `user_key` cached in IndexedDB and displays the personalized text. Falls back to generic text if the cache is unavailable (logged out, new device, etc.).

| Column                          | Type                | Encryption                    | Purpose                                 |
| ------------------------------- | ------------------- | ----------------------------- | --------------------------------------- |
| `id`                            | `:binary_id` (UUID) | —                             | Primary key                             |
| `user_id`                       | `:id`               | —                             | FK to users                             |
| `habit_id`/`goal_id`/`event_id` | `:binary_id`        | —                             | FK to associated item                   |
| `enabled`                       | `:boolean`          | —                             | Whether the reminder is active          |
| `time`                          | `:time`             | —                             | Local time to fire (5-min increments)   |
| `days`                          | `{:array, :string}` | —                             | Days of week to fire (mon, tue, ...)    |
| `channels`                      | `{:array, :string}` | —                             | Notification channels ("email", "push") |
| `encrypted_reminder_label`      | `:binary`           | Cloak (secretbox blob inside) | Optional personalized notification text |
| `last_sent_at`                  | `:utc_datetime`     | —                             | De-dupe guard (30-min window)           |

### journal_entries

Journal uses the same per-entry context-key pattern as habits: each entry gets its own random 32-byte symmetric key, which is sealed to the owner's public key (hybrid PQ KEM when available, legacy `box_seal` otherwise) and stored on the join table. The server only ever sees encrypted title, encrypted content, a plaintext date (for ordering/pagination), and a plaintext word count (for summary stats). Available on Personal+ tiers.

| Column              | Type                | Encryption                    | Purpose                                 |
| ------------------- | ------------------- | ----------------------------- | --------------------------------------- |
| `id`                | `:binary_id` (UUID) | —                             | Primary key                             |
| `user_id`           | `:id`               | —                             | FK to users                             |
| `encrypted_title`   | `:binary`           | Cloak (secretbox blob inside) | Entry title (optional)                  |
| `encrypted_content` | `:binary`           | Cloak (secretbox blob inside) | Entry body                              |
| `word_count`        | `:integer`          | —                             | Plaintext word count (summary metadata) |
| `date`              | `:date`             | —                             | Plaintext date (ordering, pagination)   |

### user_journal_entries

| Column             | Type                | Encryption                      | Purpose                               |
| ------------------ | ------------------- | ------------------------------- | ------------------------------------- |
| `id`               | `:binary_id` (UUID) | —                               | Primary key                           |
| `user_id`          | `:id`               | —                               | FK                                    |
| `journal_entry_id` | `:binary_id`        | —                               | FK                                    |
| `encrypted_key`    | `:binary`           | Cloak (hybrid seal or box_seal) | entry_key encrypted for this user     |
| `role`             | `:string`           | —                               | "owner" (future: "member" for shared) |

## Encryption Layers

```
Browser → Server → Database → Disk:

  Layer 1 (Client-side E2E):
    Browser: plaintext → NaCl secretbox(context_key) → base64 blob

  Layer 2 (Application at-rest):
    Server:  base64 blob → decode → Cloak AES-256-GCM → Postgres bytea

  Layer 3 (Infrastructure at-rest):
    Fly.io: Postgres bytea → LUKS full-disk encryption on storage volumes

  In transit:
    Browser ↔ Server: TLS
    Server ↔ Database: Fly.io private WireGuard network (encrypted)

Database → Server → Browser:

  Disk:    LUKS decrypt (transparent)
  Server:  Postgres bytea → Cloak AES-256-GCM decrypt → base64 encode → send to browser
  Browser: base64 blob → NaCl secretbox_open(context_key) → plaintext
```

### Infrastructure Encryption (Fly.io Managed Postgres)

The database runs on Fly.io's Managed Postgres, which provides additional encryption guarantees at the infrastructure level:

- **At-rest encryption**: All database storage volumes are encrypted using LUKS (Linux Unified Key Setup) block-level encryption
- **In-transit encryption**: All network traffic between the application and the database travels over Fly.io's private WireGuard mesh network, encrypted at the network layer
- **Automatic backups**: Managed Postgres includes automatic backups and recovery — backup contents inherit the same LUKS disk encryption
- **Network isolation**: The database is not accessible over the public internet; it runs within Fly.io's private network
- **SOC2 Type 2**: Fly.io maintains SOC2 Type 2 certification for their infrastructure security controls

This means your data has **three independent encryption layers** at rest: client-side E2E encryption (NaCl), application-level at-rest encryption (Cloak AES-256-GCM), and infrastructure-level disk encryption (LUKS). A database breach at any single layer reveals nothing without the keys from the other layers.

## JS Crypto Module (`assets/js/crypto/nacl.js`)

| JS Function                                 | NaCl Primitive                      | Purpose                                          |
| ------------------------------------------- | ----------------------------------- | ------------------------------------------------ |
| `generateKey()`                             | `randombytes(secretbox_KEYBYTES)`   | Generate context keys                            |
| `generateKeyPair()`                         | `crypto_box_keypair()`              | Generate public/private keypair                  |
| `generateSalt()`                            | `randombytes(pwhash_SALTBYTES)`     | Generate Argon2id salt                           |
| `deriveSessionKey(pwd, salt)`               | `crypto_pwhash(pwd, salt)`          | Derive session key from password                 |
| `encryptSecretboxString(pt, key)`           | `secretbox(msg, nonce, key)`        | Encrypt data with context key                    |
| `decryptSecretboxToString(ct, key)`         | `secretbox_open(ct, nonce, key)`    | Decrypt data with context key                    |
| `encryptPrivateKey(sk, sessionKey)`         | `secretbox(sk, nonce, key)`         | Encrypt private key for storage                  |
| `decryptPrivateKey(ct, sessionKey)`         | `secretbox_open(ct, nonce, key)`    | Decrypt private key with session key             |
| `sealForUser(pt, pk, pqPk)`                 | hybrid KEM or `box_seal`            | Encrypt key (hybrid PQ if PQ key available)      |
| `unsealFromUser(ct, pk, sk, pqSk)`          | hybrid KEM or `box_seal_open`       | Decrypt key (auto-detects format)                |
| `generateHybridKeyPair()`                   | `ml_kem768_x25519.keygen()`         | Generate hybrid PQ+X25519 keypair                |
| `boxSeal(pt, pk)`                           | `box_seal(msg, pk)`                 | Legacy: encrypt key for public key               |
| `boxSealOpen(ct, pk, sk)`                   | `box_seal_open(ct, pk, sk)`         | Legacy: decrypt key with private key             |
| `parseSaltFromKeyHash(keyHash)`             | —                                   | Extract salt from "salt$argon2id" format         |
| `generateRecoveryKey()`                     | `randombytes(32)` + base32          | Generate human-readable recovery key (13 groups) |
| `recoveryKeyToSecret(key)`                  | base32 decode                       | Re-derive raw secret from recovery key           |
| `encryptPrivateKeyForRecovery(sk, secret)`  | `secretbox(sk, nonce, secret)`      | Encrypt private key for recovery backup          |
| `decryptPrivateKeyWithRecovery(ct, secret)` | `secretbox_open(ct, nonce, secret)` | Decrypt private key with recovery secret         |

## JS Key Cache (`assets/js/crypto/key_cache.js`)

| JS Function               | Async | Purpose                                                               |
| ------------------------- | ----- | --------------------------------------------------------------------- |
| `cacheKeys(s, p, u, pq)`  | yes   | Encrypt keys (incl. PQ) with AES-256-GCM wrapping key → localStorage  |
| `getCachedKeys()`         | yes   | Load wrapping key from IndexedDB, decrypt localStorage → keys or null |
| `clearKeyCache()`         | no\*  | Remove localStorage ciphertext + IndexedDB wrapping key               |
| `isPersistDisabled()`     | no    | Check if user opted out of persistent caching                         |
| `setPersistPreference(v)` | no    | Set preference to `"always"` or `"never"` (clears cache if `"never"`) |
| `getPersistPreference()`  | no    | Read current preference (defaults to `"always"`)                      |

## JS Shared Helpers (`assets/js/crypto/session.js`)

| JS Function        | Purpose                                                                                 |
| ------------------ | --------------------------------------------------------------------------------------- |
| `getSessionKeys()` | Returns `{sessionKey, privateKey, userKey, pqPrivateKey}` from sessionStorage (or null) |
| `getPublicKey()`   | Reads user's X25519 public key from `#session-key-deriver` data attribute               |
| `getPqPublicKey()` | Reads user's hybrid PQ public key from `#session-key-deriver` (or null)                 |

## JS Hybrid PQ Module (`assets/js/crypto/hybrid.js`)

| JS Function               | Purpose                                                             |
| ------------------------- | ------------------------------------------------------------------- |
| `generateHybridKeyPair()` | Generate ML-KEM-768+X25519 keypair (returns base64 pub/secret keys) |
| `hybridSeal(pt, pqPk)`    | Version-tagged hybrid seal: KEM encap + secretbox                   |
| `hybridOpen(ct, pqSk)`    | Hybrid open: KEM decap + secretbox decrypt                          |
| `isHybridCiphertext(ct)`  | Detect version tag (0x02 = hybrid, else legacy)                     |

## JS Export Module (`assets/js/crypto/export.js`)

| JS Function            | Purpose                                                                          |
| ---------------------- | -------------------------------------------------------------------------------- |
| `decryptHabits()`      | Batch-unseal habit keys + decrypt name/description/category                      |
| `decryptCheckIns()`    | Decrypt check-in data using habit key cache                                      |
| `decryptReflections()` | Batch-unseal reflection keys + decrypt content/prompt                            |
| `decryptGoals()`       | Batch-unseal goal keys + decrypt title/description/intention + nested milestones |
| `decryptEvents()`      | Batch-unseal event keys + decrypt title/description                              |
| `decryptGroups()`      | Batch-unseal group keys + decrypt name/description + member nicknames            |
| `decryptAll()`         | Orchestrates all domain decryptors with progress callback                        |
| `habitsCsv()`, etc.    | Format decrypted data as CSV strings (one per domain)                            |

## JS Hooks

| Hook                   | Location                                | Purpose                                                                                                                                                                |
| ---------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RegistrationHook`     | Registration form                       | Generates keys, encrypts email, injects hidden fields                                                                                                                  |
| `LoginHook`            | Login form                              | Fetches salt via `/api/auth/salt`, derives session key via Argon2id KDF, stores derived key (not password) in sessionStorage                                           |
| `SessionKeyDeriver`    | `Layouts.app` (all authenticated pages) | Reads keys from sessionStorage → temp key → localStorage cache (fallback chain); decrypts and stores in sessionStorage                                                 |
| `HabitFormHook`        | New habit form                          | Generates habit_key, encrypts name/description, seals habit_key to user's public key; when group selected, seals key to each member                                    |
| `HabitCardHook`        | Each habit card                         | Decrypts habit name/description using unsealed habit_key, handles check-in encryption                                                                                  |
| `.RecoveryKeySetup`    | Settings recovery key modal (colocated) | Generates recovery key, encrypts private key backup, pushes to server                                                                                                  |
| `.AccountRecoveryHook` | Account recovery page (colocated)       | Verifies recovery key via API, decrypts private key, re-encrypts with new password                                                                                     |
| `.PersistKeysToggle`   | Settings security section (colocated)   | Reads/writes "Stay signed in" preference to localStorage via key_cache.js                                                                                              |
| `.DataExport`          | Settings data export card (colocated)   | Receives encrypted payload via push_event, batch-decrypts all domains client-side, packages as JSON/CSV zip, triggers download                                         |
| `.CalendarHighlight`   | Calendar grid wrapper (colocated)       | Hover/touch tooltip: reads encrypted event/habit/cycle data from `data-tooltip-*` attrs, unseals context keys, decrypts titles/descriptions client-side with LRU cache |

## Security Properties

| Property                           | Implementation                                                                                                                                                     |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Persistent key cache               | Derived keys encrypted (AES-256-GCM, non-extractable wrapping key) in localStorage; validated, clearable, opt-out available                                        |
| Password never in sessionStorage   | LoginHook derives session key before form submit via Argon2id KDF                                                                                                  |
| Email never stored plaintext       | Removed `email` column; only `email_hash` (HMAC) + `encrypted_email` (E2E) persist. Token `sent_to` also uses `sent_to_hash` (HMAC) + `encrypted_sent_to` (Cloak). |
| Zero-knowledge server              | Server sees only ciphertext blobs and blind indexes                                                                                                                |
| Forward secrecy on password change | Private key re-encrypted with new session key; all context keys remain accessible                                                                                  |
| Double encryption at rest          | NaCl E2E encryption + Cloak AES-256-GCM in Postgres                                                                                                                |
| Timing-safe lookups                | HMAC blind index for email; Argon2 no_user_verify for missing users                                                                                                |
| Recovery key never stored          | Only Argon2 hash stored; raw secret shown once to user, never persisted                                                                                            |
| Recovery key consumed on use       | Fields cleared after successful password reset; user must regenerate                                                                                               |
| Data export never touches server   | Server sends encrypted blobs via push_event; JS decrypts in browser and downloads locally                                                                          |

## Feature Gating & Encryption

Encryption is **universal** — it is NOT gated behind the paywall. Every tier gets full E2E encryption.

What's gated:

- **Free**: 5 habits, basic tracking, 30-day history
- **Personal**: Unlimited habits, full history, stats/charts, reminders, export
- **Family**: Everything in Personal + shared goals, group dashboard, invites
- **Lifetime**: One-time payment for Personal features forever

## API Considerations

The JSON API serves the same encrypted blobs as LiveView. Native clients (future mobile/desktop) decrypt on-device using the same libsodium primitives. The API never returns plaintext user content.

```
GET  /api/habits    → [{ encrypted_name, encrypted_key, ... }]
POST /api/habits    → { encrypted_name, encrypted_key, ... }
POST /api/check_ins → { habit_id, date, encrypted_data }
POST /api/check_ins/quick → { token } → { ok: true }  (quick check-in from push notification)
POST /api/auth/salt → { email } → { key_hash }  (for pre-login KDF)
POST /api/auth/recovery-data → { email, recovery_key } → { encrypted_recovery_private_key, public_key, ... }  (rate: 3/min, Postgres-backed)
```

### Quick Check-In from Push Notifications

The `/api/check_ins/quick` endpoint allows check-ins without client-side crypto. It accepts a one-time token generated by the ReminderWorker and delivered via the push payload. The service worker calls this endpoint when the user taps the "Check in" notification action.

**Security model:**

- Token: 32 random bytes (base64), stored in `quick_check_in_tokens` table
- Single-use: atomic `UPDATE ... WHERE used_at IS NULL RETURNING` prevents race-condition double-spend
- Time-limited: 30-minute expiry (`expires_at` field)
- Scoped: each token is bound to a specific `user_id` + `habit_id`
- Rate-limited: 10 req/min per IP (ETS-backed)
- No encryption needed: creates a check-in with `encrypted_data = nil` (metadata-only record — the existence IS the behavior data). User can enrich later client-side.
- Cleaned hourly by `TokenCleanupWorker` (Oban cron, `:maintenance` queue)

## Implementation Status

- [x] Crypto fields on users table (email_hash, encrypted_email, public_key, encrypted_private_key, encrypted_user_key, key_hash)
- [x] Plaintext email column removed — zero-knowledge email storage
- [x] HMAC blind index for email lookups (case-insensitive via downcase)
- [x] Cloak Vault (AES-256-GCM at-rest encryption)
- [x] JS crypto module (nacl.js) with libsodium-wrappers-sumo
- [x] Registration hook (client-side key generation, email encryption)
- [x] Login hook (pre-submit KDF — password never in sessionStorage)
- [x] SessionKeyDeriver hook (private key + user_key derivation)
- [x] SessionKeyDeriver wired into authenticated layout (all authenticated pages)
- [x] Habits schema + migration with encrypted fields
- [x] user_habits join table for key distribution
- [x] check_ins schema with encrypted data
- [x] JS habit encryption/decryption hooks (HabitFormHook, HabitCardHook)
- [x] /api/auth/salt endpoint for pre-login salt fetch
- [x] JS password change hook (re-encrypt private key)
- [x] Groups + group_members schemas (groups, group_members, group_invites tables)
- [x] Shared habits (group_id on habits, member key distribution via user_habits)
- [x] Shared goals (group_id on goals, member key distribution via user_goals)
- [x] JS group key management hooks (HabitFormHook seals to group members, GroupFormHook, KeyDistributor)
- [x] Recovery key setup (Settings page, client-side key generation, encrypted private key backup)
- [x] Password reset via recovery key (/users/recover-account, client-side re-encryption)
- [x] /api/auth/recovery-data endpoint for recovery key verification
- [x] Recovery key consumed on use (fields cleared, must regenerate)
- [x] Token `sent_to` replaced with `sent_to_hash` (HMAC) + `encrypted_sent_to` (Cloak) — no plaintext email in tokens
- [x] Data export — client-side batch decryption, JSON/CSV zip, zero-knowledge download
- [x] Shared crypto session helpers extracted (getSessionKeys/getPublicKey — 8 hook files DRY'd)
- [x] Persistent key cache (localStorage) — survives browser restarts (Proton-style)
- [x] "Stay signed in" toggle (Settings → Security) — opt-out clears cache
- [x] Hybrid post-quantum KEM (ML-KEM-768 + X25519 via @noble/post-quantum)
- [x] Version-tagged ciphertext (auto-detects legacy vs hybrid on open)
- [x] Progressive PQ migration for existing users (on next login)
- [x] PQ key fields on users table (pq_public_key, encrypted_pq_private_key)
- [x] Recovery key flow updated to backup/restore PQ private key
- [x] All resource hooks migrated to sealForUser/unsealFromUser
- [x] Quick check-in from push — token-based API endpoint (no crypto needed, metadata-only record)
- [x] Stripe subscriptions for tier gating
- [ ] JSON API controllers (same encrypted blobs)
