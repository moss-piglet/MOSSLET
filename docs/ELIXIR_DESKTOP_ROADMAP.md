# Elixir Desktop Migration Roadmap

## Overview

This document tracks the migration of Mosslet to support native desktop and mobile apps using [elixir-desktop](https://github.com/elixir-desktop/desktop), enabling **true zero-knowledge encryption** where all cryptographic operations happen on the user's device.

### Architecture Goals

| Platform           | Where enacl Runs | Primary Database  | Local Cache    | Zero-Knowledge?                    |
| ------------------ | ---------------- | ----------------- | -------------- | ---------------------------------- |
| **Web**            | Fly.io server    | Postgres (Fly.io) | Browser cache  | No (server sees plaintext briefly) |
| **Native Desktop** | User's device    | Postgres (Fly.io) | SQLite (local) | **Yes**                            |
| **Native Mobile**  | User's device    | Postgres (Fly.io) | SQLite (local) | **Yes**                            |

### Key Insight

Same Phoenix/LiveView codebase, different deployment modes. The enacl encryption happens wherever the BEAM runs—on Fly.io for web, on the user's device for native apps. **All platforms use the same cloud database as the source of truth.**

---

## Critical Architecture Decision: Single Source of Truth

### Why Cloud Database (Not Local SQLite) for User Data

We use **two layers of encryption**:

1. **Cloak (symmetric AES-256-GCM)** - Server-side at-rest encryption using `CLOAK_KEY`

   - Encrypts data in Postgres before storage
   - Protects against database-level breaches
   - Key is per-environment (different in dev/staging/prod)

2. **Enacl (asymmetric)** - User-side E2E encryption
   - Data encrypted with user's public key
   - Only decryptable with user's private key (protected by their password)
   - This encrypted blob is what's stored in the Cloak-encrypted field

**The Problem with Local SQLite for User Data:**

```
❌ WRONG: Separate databases with different Cloak keys

Web App (Fly.io):
  User data → Enacl encrypt → Cloak encrypt (CLOAK_KEY_PROD) → Postgres

Desktop App (Local):
  User data → Enacl encrypt → Cloak encrypt (CLOAK_KEY_LOCAL) → SQLite

Result: Data encrypted on desktop CAN'T be read on web (different Cloak keys!)
```

**The Correct Architecture:**

```
✅ CORRECT: Single cloud database, local cache only

Web App:
  Browser → Phoenix API → Fly.io Postgres (Cloak + Enacl encrypted)
                              ↓
  User's session decrypts enacl layer with password-derived key

Desktop App:
  Desktop → Phoenix API → Same Fly.io Postgres (same encrypted data)
                              ↓
  User's session decrypts enacl layer locally (true zero-knowledge!)

Local SQLite is ONLY for:
  - Offline cache of encrypted blobs
  - Sync queue for pending changes
  - Local-only preferences/settings
```

### How Zero-Knowledge Works with Cloud DB

The server stores data that is **double-encrypted**:

1. Cloak layer (server can decrypt for storage operations)
2. Enacl layer inside (server CANNOT decrypt - no user's private key)

When a user reads data:

- Server decrypts Cloak layer, returns enacl-encrypted blob
- User's device decrypts enacl layer with their password-derived session key

**For Desktop/Mobile:**

- The enacl decryption happens ON DEVICE
- Server only ever sees the enacl-encrypted blob
- True zero-knowledge for the actual content!

---

## Encryption Compatibility

> **See also:** `ENCRYPTION_ARCHITECTURE.md` for the complete encryption reference.

### Two-Layer Encryption System

**All sensitive data uses BOTH encryption layers:**

| Layer                  | Technology     | Purpose                                        | Where It Happens                |
| ---------------------- | -------------- | ---------------------------------------------- | ------------------------------- |
| **Enacl (Asymmetric)** | NaCl/libsodium | E2E encryption - protects content from server  | Device (native) or Server (web) |
| **Cloak (Symmetric)**  | AES-256-GCM    | At-rest encryption - protects DB from breaches | Always on Server (Fly.io)       |

The enacl-encrypted blob gets wrapped in Cloak encryption when stored. This happens automatically via our `Encrypted.Binary`, `Encrypted.Map`, etc. schema field types.

### User Keys (Per-User E2E Encryption)

Each user has their own keypair stored in `user.key_pair`:

- `public` - Used by others to encrypt messages TO this user
- `private` - Encrypted with user's password-derived key

**Cross-Platform Compatibility:** ✅ Works seamlessly

- User signs up (web or native) → keypair generated
- Keypair stored in cloud Postgres (Cloak at-rest, private key also enacl encrypted)
- User enters password on ANY device → derives same session key → decrypts private key
- All encryption/decryption of content uses this keypair

### Server Keys (Public/Shared Data)

Used for data that needs server access:

- `SERVER_PUBLIC_KEY` - Encrypt data server can access
- `SERVER_PRIVATE_KEY` - Server decrypts when needed

**Cross-Platform Compatibility:** ✅ Works (server handles server-key operations)

| Data Type              | Enacl Encrypted With             | Who Decrypts Enacl                          | Cloak At-Rest |
| ---------------------- | -------------------------------- | ------------------------------------------- | ------------- |
| Private posts/messages | Recipient's public key           | Recipient's device (native) or server (web) | ✅ Server     |
| Public posts           | Server's public key              | Server (to serve to anyone)                 | ✅ Server     |
| Connection profiles    | Server's public key              | Server                                      | ✅ Server     |
| Post reports           | Server's public key              | Server (admin access)                       | ✅ Server     |
| Group content          | Group key → member's public keys | Members' devices/server                     | ✅ Server     |
| User profile data      | User's public key (via user_key) | User's device/server                        | ✅ Server     |

### How Native Apps Achieve Zero-Knowledge

```
WEB USER (server sees plaintext briefly during session):
  Postgres → Cloak decrypt (server) → Enacl decrypt (server) → User sees content

NATIVE USER (server never sees plaintext):
  Postgres → Cloak decrypt (server) → API returns enacl blob → Device decrypts → User sees content
```

The **same double-encrypted data** works for both platforms - the difference is WHERE the enacl decryption happens. Native apps decrypt on-device, achieving true zero-knowledge.

---

## Web ↔ Native Account Compatibility

### Scenario: User creates account on web, then uses native app

```
1. User signs up on web (mosslet.com)
   └─► Postgres stores: user record, encrypted key_pair, key_hash
   └─► Cloak encrypts at rest, enacl layer protects private key

2. User downloads native app, enters email + password
   └─► App authenticates via API (same auth flow)
   └─► App receives: encrypted key_pair, key_hash, user data
   └─► (Data still has enacl encryption intact)

3. On device
   └─► User's password derives session key (same algorithm everywhere)
   └─► App decrypts private key LOCALLY
   └─► User can now decrypt all their data ON DEVICE!

4. Reading/Writing data
   └─► All CRUD operations go to cloud Postgres via API
   └─► Enacl encryption/decryption happens on device
   └─► Server only sees encrypted blobs
   └─► Local SQLite caches encrypted blobs for offline viewing
```

### Scenario: User creates account on native app first

```
1. User signs up on native app
   └─► Keypair generated LOCALLY (true zero-knowledge!)
   └─► App calls registration API
   └─► Server stores encrypted keypair in Postgres

2. Data operations
   └─► User creates content, encrypted locally with their keys
   └─► Encrypted data sent to server via API
   └─► Server stores (Cloak layer added) - cannot read content

3. User later logs in on web
   └─► Server returns encrypted data
   └─► Web app decrypts with user's password
   └─► (Web decryption happens server-side, so not zero-knowledge for web)
```

**Key Point:** Users on native apps achieve true zero-knowledge. The same data works on web too, just with server-side decryption (the "server" is the client device when native, desktop/phone, and the "server" is in the cloud when on the web). While the server has temporary access to plaintext before encrypting with people's asymmetric encryption (or decrypting to serve in the browser), we don't log or send that plaintext anywhere — it is garbage collected and cleared from memory by Elixir/BEAM.

---

## Implementation Phases

### Phase 1: Platform Abstraction Layer ✅ COMPLETE

- [x] Create `Mosslet.Platform` module for runtime detection
- [x] Create `Mosslet.Platform.Config` for environment-specific settings
- [x] Add `:desktop` Mix environment/target (`config/desktop.exs`)
- [x] Test platform detection in dev

### Phase 2: Local Cache Database ✅ COMPLETE

**Goal:** SQLite for offline cache and sync queue ONLY - not for user data storage.

- [x] Add `{:ecto_sqlite3, "~> 0.22"}` dependency
- [x] Create `Mosslet.Repo.SQLite` module (cache-only repo) - `lib/mosslet/repo/sqlite.ex`
- [x] Design cache schema:
  - `Mosslet.Cache.CachedItem` - Stores encrypted blobs for offline viewing
  - `Mosslet.Cache.SyncQueueItem` - Queues pending changes when offline
  - `Mosslet.Cache.LocalSetting` - Device-specific settings
- [x] Create SQLite migrations for cache tables - `priv/repo_sqlite/migrations/`
- [x] Implement `Mosslet.Cache` module for local cache operations - `lib/mosslet/cache.ex`

**Files created:**

- `lib_native/mosslet/repo/sqlite.ex` - SQLite Ecto repo
- `lib_native/mosslet/cache.ex` - Cache operations context
- `lib_native/mosslet/cache/cached_item.ex` - CachedItem schema
- `lib_native/mosslet/cache/sync_queue_item.ex` - SyncQueueItem schema
- `lib_native/mosslet/cache/local_setting.ex` - LocalSetting schema
- `priv/repo_sqlite/migrations/20250120000001_create_cache_tables.exs` - Migration

### Phase 2.5: Device Keychain Cache Encryption ✅ COMPLETE

**Goal:** Add Cloak-style symmetric encryption layer for local cache to provide defense-in-depth and quantum-resistance at rest.

**Why:** While enacl already protects cached data, adding a device-specific AES-256-GCM layer provides:

- Defense-in-depth (two layers to break)
- Post-quantum resistance for data at rest (AES is quantum-resistant)
- Consistency with cloud architecture (both use Cloak-style wrapping)

**Architecture:**

```
Cloud (current):     Content → Enacl → Cloak (CLOAK_KEY) → Postgres
Native (proposed):   Content → Enacl → Cloak (device keychain key) → SQLite
```

**Key Management:**

- Each device generates its own unique AES-256 key on first run
- Key stored in OS-native secure storage (never synced between devices):
  - macOS: Keychain Services (`kSecAttrSynchronizable = false`)
  - Windows: DPAPI / Credential Manager
  - Linux: Secret Service API (libsecret)
  - iOS: Keychain (device-only, not iCloud)
  - Android: Keystore
- No admin rotation needed - key is device-local, disposable with device
- New device = fresh cache from cloud sync (no data loss)

**Completed:**

- [x] Create `Mosslet.Platform.Security` module for device keychain operations
- [x] Create `Mosslet.Vault.Native` module for device-specific Cloak vault
- [x] Create `Mosslet.Encrypted.Native.*` types (Binary, Map, Integer, HMAC, etc.)
- [x] Update cache schemas to use `Encrypted.Native.Binary` for sensitive fields
- [x] Add platform-specific keychain adapters (stub for now, implement per-platform later)

**Files created:**

- `lib/mosslet/platform/security.ex` - Device keychain operations (encryption key + HMAC secret)
- `lib/mosslet/vault/native.ex` - Native Cloak vault using device keychain key
- `lib/mosslet/encrypted/native/binary.ex` - Native encrypted binary type
- `lib/mosslet/encrypted/native/map.ex` - Native encrypted map type
- `lib/mosslet/encrypted/native/hmac.ex` - Native HMAC using device keychain secret
- `lib/mosslet/encrypted/native/*.ex` - All other Native encrypted types

**Security Properties:**

- Device theft: Attacker needs OS credentials + user password to read cached data
- Quantum attack: AES-256 layer provides post-quantum resistance
- Cache is disposable: Cloud sync rebuilds it on any new device
- No key rotation complexity: Device keys are independent, never transmitted

### Phase 3: API Client for Desktop ✅ COMPLETE

**Goal:** Desktop app communicates with cloud server via API (like a mobile app would).

- [x] Create `Mosslet.API.Client` module for HTTP requests to Fly.io server
- [x] Create `Mosslet.API.Token` module for JWT token generation/verification
- [x] Create API authentication endpoints on server (`MossletWeb.API.AuthController`)
- [x] Create sync endpoints on server (`MossletWeb.API.SyncController`)
- [x] Add API routes with `:api` and `:api_auth` pipelines
- [x] Add `MossletWeb.Plugs.APIAuth` for JWT bearer token authentication
- [x] Add `MossletWeb.API.FallbackController` for error handling
- [x] Add sync query functions to contexts (`list_user_posts_for_sync`, etc.)
- [x] Create `MossletWeb.API.PostController` for post CRUD operations
- [x] Write API tests

**Files created:**

- `lib/mosslet/api/token.ex` - JWT token generation/verification (HS256)
- `lib/mosslet/api/client.ex` - HTTP client using Req for native apps
- `lib/mosslet_web/plugs/api_auth.ex` - JWT bearer token authentication plug
- `lib/mosslet_web/controllers/api/auth_controller.ex` - Login/register/refresh endpoints
- `lib/mosslet_web/controllers/api/sync_controller.ex` - User/posts/connections/groups sync
- `lib/mosslet_web/controllers/api/post_controller.ex` - Post CRUD operations
- `lib/mosslet_web/controllers/api/fallback_controller.ex` - Error response formatting

**Test files created:**

- `test/mosslet_web/controllers/api/auth_controller_test.exs`
- `test/mosslet_web/controllers/api/sync_controller_test.exs`
- `test/mosslet_web/controllers/api/post_controller_test.exs`

**API Endpoints:**

Public (no auth required):

- `POST /api/auth/login` - Authenticate with email/password, returns JWT + encrypted user data
  - If 2FA enabled, returns `{totp_required: true, totp_token: "..."}` instead
  - Supports `remember_me: true` to get long-lived remember_me_token
  - Supports `totp_code` param to complete 2FA in single request
- `POST /api/auth/register` - Register new user, returns JWT + encrypted user data
  - Supports `remember_me: true` to get long-lived remember_me_token
- `POST /api/auth/totp/verify` - Complete 2FA login with totp_token + code
- `POST /api/auth/remember-me/refresh` - Get fresh access token using remember_me_token (no password needed)

Authenticated (requires Bearer token):

- `POST /api/auth/refresh` - Refresh JWT token
- `POST /api/auth/logout` - Logout (revokes remember_me_token if provided)
- `GET /api/auth/me` - Get current user data
- `GET /api/auth/totp/status` - Check if 2FA is enabled and backup codes remaining
- `POST /api/auth/totp/setup` - Get TOTP secret and otpauth URL for QR code
- `POST /api/auth/totp/enable` - Enable 2FA with secret + code, returns backup codes
- `POST /api/auth/totp/disable` - Disable 2FA (requires password or TOTP code)
- `POST /api/auth/totp/backup-codes/regenerate` - Regenerate backup codes (requires TOTP code)
- `GET /api/sync/user` - Sync user data
- `GET /api/sync/posts?since=timestamp&limit=50` - Sync posts (encrypted blobs)
- `GET /api/sync/connections?since=timestamp` - Sync connections
- `GET /api/sync/groups?since=timestamp` - Sync groups
- `GET /api/sync/full?since=timestamp` - Full sync (user, posts, connections, groups)
- `GET /api/posts` - List user's posts
- `GET /api/posts/:id` - Get a specific post
- `POST /api/posts` - Create a new post
- `PUT /api/posts/:id` - Update a post
- `DELETE /api/posts/:id` - Delete a post

**TOTP/2FA Flow for Native Clients:**

```
1. Client: POST /api/auth/login {email, password}
2. Server: {totp_required: true, totp_token: "eyJ..."} (if 2FA enabled)
3. Client: Prompt user for TOTP code
4. Client: POST /api/auth/totp/verify {totp_token, code}
5. Server: {token: "eyJ...", user: {...}, remember_me_token: "eyJ..."} (if remember_me requested)
```

**Remember Me Flow for Native Clients:**

```
1. Client: Store remember_me_token securely (Keychain/Keystore)
2. On app launch: POST /api/auth/remember-me/refresh {remember_me_token}
3. Server: Validates token against DB session, returns fresh access token
4. If expired/revoked: Client prompts for password again
```

**Code Examples:**

```elixir
# Native app login
{:ok, %{token: token, user: user}} = Mosslet.API.Client.login("email@example.com", "password")

# Sync posts since last sync
{:ok, %{posts: posts, synced_at: synced_at}} = Mosslet.API.Client.fetch_posts(token, since: last_sync)

# Full sync for new device
{:ok, sync_data} = Mosslet.API.Client.full_sync(token)

# Create a post
{:ok, post} = Mosslet.API.Client.create_post(token, %{post: %{body: "Hello", visibility: "private"}})
```

### Phase 4: Sync & Offline Support ✅ COMPLETE

**Goal:** Seamless offline experience with background sync.

- [x] Implement `Mosslet.Sync` GenServer
- [x] Implement conflict resolution strategy (`Mosslet.Sync.ConflictResolver`)
- [x] Add online/offline detection with exponential backoff
- [x] Sync status broadcasting via PubSub for UI integration

**Files created:**

- `lib_native/mosslet/sync.ex` - Sync GenServer with polling, queue processing, and status broadcasting
- `lib_native/mosslet/sync/conflict_resolver.ex` - Last-Write-Wins conflict resolution
- `lib_native/mosslet/sync/connectivity.ex` - Online/offline detection with health checks

**Features implemented:**

- Periodic sync polling (5 minute intervals)
- Exponential backoff for failed syncs (30s → 10min max)
- Health check connectivity monitoring (10s intervals)
- Push pending changes from sync queue before pulling updates
- Pull updates from server since last sync
- Cache sync data locally (posts, connections, groups)
- Automatic cleanup of completed sync items (24 hours)
- PubSub broadcasting of sync status for LiveView integration
- `subscribe_and_get_status/0` helper for LiveViews

**Conflict Resolution Strategy:**

- Last-Write-Wins (LWW) with server timestamp as authoritative source
- Server wins ties (canonical time)
- Deleted resources are handled gracefully
- Local cache updated to match server state after resolution

### Phase 5: Context-Level Platform Routing ✅ COMPLETE

**Goal:** Make contexts platform-aware so LiveViews work unchanged on both web and native.

**Architecture Decision: Thin Adapters**

We use a **thin adapter pattern** where:

1. **Business logic stays in the context** (e.g., `accounts.ex`) - changesets, validations, broadcasts, multi-step operations
2. **Adapters only handle data access** - Repo calls for web, API+cache for native
3. **Context orchestrates** - calls adapter for data, then applies business logic
4. **Same function names** - adapters use the same function names as the context (different signatures)

This avoids duplicating complex business logic across adapters and keeps a single source of truth.

```
CONTEXT (accounts.ex)
---------------------
def update_user_name(user, attrs, opts) do
  # 1. Build changeset (business logic)
  changeset = User.name_changeset(user, attrs, opts)
  c_attrs = changeset.changes.connection_map

  # 2. Delegate data persistence to adapter (SAME function name)
  case adapter().update_user_name(user, conn, changeset, c_attrs) do
    {:ok, user, conn} ->
      # 3. Post-persistence business logic
      Groups.maybe_update_name_for_user_groups(user, ...)
      broadcast_connection(conn, :uconn_name_updated)
      {:ok, user}
    {:error, changeset} -> {:error, changeset}
  end
end

WEB ADAPTER (thin)                    NATIVE ADAPTER (thin)
------------------                    --------------------
def update_user_name(                 def update_user_name(
  user, conn, changeset,                user, conn, changeset,
  c_attrs) do                           c_attrs) do

  Ecto.Multi.new()                      if Sync.online?() do
  |> Multi.update(:user,..)               API.Client.update_name(...)
  |> Multi.update(:conn,..)             else
  |> Repo.transaction_on_                 Cache.queue_for_sync(...)
       primary()                        end
end                                   end
```

**Why Thin Adapters?**

| Approach                   | Pros                        | Cons                                        |
| -------------------------- | --------------------------- | ------------------------------------------- |
| **Full copy to adapters**  | Clear separation            | Duplicates business logic, hard to maintain |
| **Thin adapters (chosen)** | Single source of truth, DRY | Adapter callbacks are more granular         |

**Adapter Callback Categories:**

1. **Simple CRUD** - `get_user/1`, `get_connection/1`, etc. (adapter handles fully)
2. **Queries** - `filter_user_connections/2`, `search_user_connections/2` (adapter handles fully)
3. **Writes with business logic** - `update_user_name/3`, `confirm_user_connection/3` (context orchestrates, adapter persists)

**How It Works:**

```
DESKTOP APP                              FLY.IO SERVER
───────────────────────────────────────────────────────────────────────
LiveView calls
  Accounts.get_user_by_email_and_password(email, password)
    ↓
  Platform.native?() == true
    ↓
  API.Client.login(email, password)  →   POST /api/auth/login
                                               ↓
                                          AuthController.login()
                                               ↓
                                          Accounts.get_user_by_email_and_password()
                                               ↓
                                          Platform.native?() == false (on server!)
                                               ↓
                                          Repo.get_by(User, email_hash: email)
                                               ↓
                                          Returns user via JSON API
                                               ↓
  ←  JSON response with user + token
    ↓
  Return user struct to LiveView
```

**Key Insight:** `Platform.native?()` returns `false` on Fly.io (no `MOSSLET_NATIVE` env var), so the server always uses Repo directly. The API controllers already call context functions, which hit the real Postgres.

**Implementation Checklist:**

**Context Priority Matrix:**

| Context                 | Repo Calls | Priority     | Status      | Notes                        |
| ----------------------- | ---------- | ------------ | ----------- | ---------------------------- |
| ~~`accounts.ex`~~       | ~~173~~    | ~~CRITICAL~~ | ✅ COMPLETE | ~~Auth, users, connections~~ |
| ~~`timeline.ex`~~       | ~~236~~    | ~~HIGH~~     | ✅ COMPLETE | ~~Posts, feeds, reactions~~  |
| ~~`groups.ex`~~         | ~~43~~     | ~~MEDIUM~~   | ✅ COMPLETE | ~~Group management~~         |
| ~~`group_messages.ex`~~ | ~~15~~     | ~~MEDIUM~~   | ✅ COMPLETE | ~~Group chat~~               |
| ~~`messages.ex`~~       | ~~9~~      | ~~MEDIUM~~   | ✅ COMPLETE | ~~Direct messages~~          |
| ~~`journal.ex`~~        | ~~--~~     | ~~MEDIUM~~   | ✅ COMPLETE | ~~Journal entries (E2E)~~    |
| ~~`orgs.ex`~~           | ~~25~~     | ~~LOW~~      | ✅ COMPLETE | ~~Organization features~~    |
| ~~`statuses.ex`~~       | ~~9~~      | ~~LOW~~      | ✅ COMPLETE | ~~User statuses~~            |
| ~~`logs.ex`~~           | ~~7~~      | ~~LOW~~      | ✅ COMPLETE | ~~Audit logs~~               |
| ~~`memories.ex`~~       | ~~57~~     | ~~LOW~~      | ✅ COMPLETE | ~~Legacy - phasing out~~     |
| ~~`conversations.ex`~~  | ~~9~~      | ~~LOW~~      | ✅ COMPLETE | ~~Legacy - phasing out~~     |

---

### Native Code Directory Pattern: `lib_native/`

**Why `lib_native/`?**

Native-only code (SQLite repos, native adapters, sync modules, cache) must be compiled only when building for desktop/mobile targets. Placing this code in `lib_native/` allows us to:

1. **Conditionally include compilation paths** - The `mix.exs` adds `lib_native` to `elixirc_paths` only for the `:desktop` Mix environment
2. **Avoid loading native dependencies on web** - SQLite, Desktop, and other native deps don't load on Fly.io
3. **Clear separation** - Easy to identify what code is native-only vs shared

**Directory Structure:**

```
lib_native/
├── mosslet/
│   ├── accounts/adapters/native.ex      # Native adapter for accounts
│   ├── cache.ex                          # SQLite cache operations
│   ├── cache/
│   │   ├── cached_item.ex               # CachedItem schema (SQLite)
│   │   ├── local_setting.ex             # LocalSetting schema (SQLite)
│   │   └── sync_queue_item.ex           # SyncQueueItem schema (SQLite)
│   ├── conversations/adapters/native.ex # Native adapter for conversations
│   ├── group_messages/adapters/native.ex
│   ├── groups/adapters/native.ex
│   ├── journal/adapters/native.ex       # Native adapter for journal
│   ├── logs/adapters/native.ex
│   ├── memories/adapters/native.ex
│   ├── messages/adapters/native.ex
│   ├── orgs/adapters/native.ex
│   ├── repo/sqlite.ex                   # SQLite Ecto repo
│   ├── statuses/adapters/native.ex
│   ├── sync.ex                          # Sync GenServer
│   ├── sync/
│   │   ├── conflict_resolver.ex         # LWW conflict resolution
│   │   └── connectivity.ex              # Online/offline detection
│   └── timeline/adapters/native.ex
```

**mix.exs Configuration:**

```elixir
defp elixirc_paths(:desktop), do: ["lib", "lib_native"]
defp elixirc_paths(_), do: ["lib"]
```

**Adapter Loading Pattern:**

The adapter behaviour modules in `lib/` reference the native adapter by module name. At runtime, `Platform.native?()` determines which adapter to use:

```elixir
# lib/mosslet/accounts/adapter.ex
defmodule Mosslet.Accounts.Adapter do
  def impl do
    if Mosslet.Platform.native?() do
      Mosslet.Accounts.Adapters.Native  # Lives in lib_native/
    else
      Mosslet.Accounts.Adapters.Web     # Lives in lib/
    end
  end
end
```

The web adapter in `lib/` is always compiled. The native adapter in `lib_native/` is only compiled for desktop builds, preventing any native-only dependencies from being loaded on web deployments.

#### 5.1 Authentication & Session (Priority: CRITICAL) - `accounts.ex` - ✅ COMPLETE

**Status:** Thin adapter pattern implemented. Business logic lives in `accounts.ex`, adapters handle data access only.

**Current Implementation:**

- ✅ `accounts.ex` (~2500 lines) - Contains all business logic (changesets, broadcasts, multi-step operations)
- ✅ `web.ex` (~1700 lines) - Repo calls + query logic (larger due to many query functions)
- ✅ `native.ex` (~2200 lines) - API + cache calls (larger due to zero-knowledge decryption for `delete_user_data`)

**Why adapters are larger than 200-300 lines:**

1. **Query functions** - Functions like `filter_user_connections/2`, `search_user_connections/2` require platform-specific query logic
2. **Native-specific decryption** - `delete_user_data` in native.ex includes ~150 lines of URL decryption logic that MUST run on-device (zero-knowledge requirement)
3. **Deserialization helpers** - Native adapter needs JSON→struct conversion for API responses

**Architecture Pattern (working as designed):**

| Function Type               | accounts.ex                                                                 | web.ex                      | native.ex                                             |
| --------------------------- | --------------------------------------------------------------------------- | --------------------------- | ----------------------------------------------------- |
| `update_user_name`          | Builds changeset, calls adapter, handles Groups/profile updates, broadcasts | Ecto.Multi (~20 lines)      | API call (~25 lines)                                  |
| `update_user_profile`       | Profile preview jobs, broadcasts                                            | Repo.update (~10 lines)     | API call (~15 lines)                                  |
| `delete_user_data`          | Password validation, orchestration                                          | Repo deletes + URL cleanup  | API calls + **on-device URL decryption** (~150 lines) |
| `get_user/1`                | Delegates to adapter                                                        | `Repo.get(User, id)`        | Cache + API fallback                                  |
| `filter_user_connections/2` | Delegates to adapter                                                        | Full Ecto query (~30 lines) | Cache filtering (~20 lines)                           |

**Zero-Knowledge Exception:**
The `delete_user_data` function in `native.ex` legitimately contains more logic because:

- URLs must be decrypted **on-device** before deletion (server never sees plaintext URLs)
- This is core to the zero-knowledge architecture - not duplicated business logic

**Example - Thin Adapter Pattern in Action:**

```elixir
# accounts.ex - ALL business logic here
def update_user_name(user, attrs, opts) do
  changeset = User.name_changeset(user, attrs, opts)
  conn = adapter().get_connection!(user.connection.id)
  c_attrs = Map.get(changeset.changes, :connection_map, %{})

  case adapter().update_user_name(user, conn, changeset, c_attrs) do
    {:ok, updated_user, updated_conn} ->
      # Business logic stays in context
      Groups.maybe_update_name_for_user_groups(...)
      maybe_update_profile(...)
      broadcast_connection(updated_conn, :uconn_name_updated)
      {:ok, updated_user}
    {:error, changeset} -> {:error, changeset}
  end
end

# web.ex - ONLY Ecto.Multi
def update_user_name(_user, conn, changeset, c_attrs) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:update_user, changeset)
  |> Ecto.Multi.update(:update_connection, Connection.update_name_changeset(conn, c_attrs))
  |> Repo.transaction_on_primary()
  |> case do
    {:ok, %{update_user: user, update_connection: conn}} -> {:ok, user, conn}
    {:error, _, changeset, _} -> {:error, changeset}
  end
end

# native.ex - ONLY API call
def update_user_name(_user, _conn, changeset, c_attrs) do
  if Sync.online?() do
    name = Ecto.Changeset.get_field(changeset, :name)
    case Client.update_user_name(token, %{name: name, connection_map: c_attrs}) do
      {:ok, %{user: user_data}} -> {:ok, deserialize_user(user_data), ...}
      {:error, reason} -> {:error, reason}
    end
  else
    Cache.queue_for_sync("user", "update_name", ...)
    {:error, "Offline - queued for sync"}
  end
end
```

end

```

**Files to modify:**

- `lib/mosslet/accounts.ex` - Move business logic back from adapters
- `lib/mosslet/accounts/adapter.ex` - Simplify to thin data-access callbacks
- `lib/mosslet/accounts/adapters/web.ex` - Reduce to ~200-300 lines of Repo calls
**Files created:**

- `lib/mosslet/accounts/adapter.ex` - Behaviour with 80+ callbacks
- `lib/mosslet/accounts/adapters/web.ex` - Web adapter (Repo calls + queries)
- `lib_native/mosslet/accounts/adapters/native.ex` - Native adapter (API + cache + zero-knowledge decryption)
- `lib/mosslet/session/native.ex` - JWT token + session key storage (from Phase 3)

#### 5.2 Timeline & Posts (Priority: HIGH) - `timeline.ex` - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. All functions delegated to adapters.

**Target State:**
- `timeline.ex` contains all business logic (changesets, broadcasts, PubSub, cache invalidation)
- `web.ex` contains Repo calls + query logic + filter helpers
- `native.ex` contains API/cache calls + any zero-knowledge decryption needed

**Files created:**

- `lib/mosslet/timeline/adapter.ex` - Behaviour definition with 130+ callbacks
- `lib/mosslet/timeline/adapters/web.ex` - Web adapter (Repo calls + filtering, ~2200 lines)
- `lib_native/mosslet/timeline/adapters/native.ex` - Native adapter (API + cache, ~1600 lines)

**Completed Functions (delegated to adapters):**

Basic Getters (18 functions) - ✅ COMPLETE:
- `get_post/1`, `get_post!/1`, `get_post_with_preloads/1`, `get_post_with_preloads!/1`
- `get_reply/1`, `get_reply!/1`, `get_reply_with_preloads/1`, `get_reply_with_preloads!/1`
- `get_user_post/1`, `get_user_post!/1`, `get_user_post_receipt/1`, `get_user_post_receipt!/1`
- `get_user_post_by_post_id_and_user_id/2`, `get_user_post_by_post_id_and_user_id!/2`
- `get_all_posts/1`, `get_all_shared_posts/1`
- `list_user_posts_for_sync/2`, `preload_group/1`

Bookmark Getters (6 functions) - ✅ COMPLETE:
- `get_bookmark/1`, `get_bookmark!/1`
- `get_bookmark_by_post_and_user/2`
- `get_bookmark_category/1`, `get_bookmark_category!/1`
- `user_has_bookmarked?/2`

All Count Functions (31 functions) - ✅ COMPLETE:
- Simple counts: `count_all_posts/0`, `post_count/2`, `shared_between_users_post_count/2`, `timeline_post_count/2`, `reply_count/2`, `public_reply_count/2`, `group_post_count/1`, `public_post_count_filtered/2`, `public_post_count/1`
- Filtered counts: `count_user_own_posts/2`, `count_user_group_posts/2`, `count_user_connection_posts/2`, `count_group_posts/2`, `count_discover_posts/2`
- Unread counts: `count_unread_posts_for_user/1`, `count_unread_user_own_posts/2`, `count_unread_bookmarked_posts/2`, `count_unread_connection_posts/2`, `count_unread_group_posts/2`, `count_unread_discover_posts/2`
- Reply counts: `count_replies_for_post/2`, `count_top_level_replies/2`, `count_child_replies/2`, `count_unread_replies_for_user/1`, `count_unread_replies_by_post/1`, `count_unread_replies_to_user_replies/1`, `count_unread_nested_replies_by_parent/1`, `count_unread_replies_to_user_replies_by_post/1`, `count_unread_nested_replies_for_post/2`
- Bookmark count: `count_user_bookmarks/2`
- Home timeline counts: `count_home_timeline/2`, `count_unread_home_timeline/2`

Timeline Listings with Caching (5 functions) - ✅ COMPLETE:
- `list_connection_posts/2` → `fetch_connection_posts/2`
- `list_discover_posts/2` → `fetch_discover_posts/2`
- `list_user_own_posts/2` → `fetch_user_own_posts/2`
- `list_home_timeline/2` → `fetch_home_timeline/2`
- `list_group_posts/2` → `fetch_group_posts/2`

Profile Listings (5 functions) - ✅ COMPLETE:
- `list_public_profile_posts/4`
- `list_profile_posts_visible_to/3`
- `count_profile_posts_visible_to/2`
- `list_user_group_posts/2`
- `list_own_connection_posts/2`

Utility Listings (3 functions) - ✅ COMPLETE:
- `first_reply/2`
- `first_public_reply/2`
- `unread_posts/1`

Other Listings (10 functions) - ✅ COMPLETE:
- `list_posts/2`, `list_replies/2`, `list_shared_posts/3`
- `list_public_posts/1`, `list_public_replies/2`
- `list_user_bookmarks/2`, `list_bookmark_categories/1`
- `filter_timeline_posts/2`, `list_nested_replies/2`, `list_user_replies/2`

Mark Read Operations (5 functions) - ✅ COMPLETE:
- `mark_replies_read_for_post/2`
- `mark_all_replies_read_for_user/1`
- `mark_nested_replies_read_for_parent/2`
- `mark_top_level_replies_read_for_post/2`
- `mark_post_as_read/2`

Bookmark Category CRUD (3 functions) - ✅ COMPLETE:
- `create_bookmark_category/2`
- `update_bookmark_category/2`
- `delete_bookmark_category/1`

Basic CRUD Callbacks (14 functions) - ✅ COMPLETE:
- Post: `create_post/2`, `update_post/3`, `delete_post/1`
- Reply: `create_reply/2`, `update_reply/3`, `delete_reply/1`
- UserPost: `create_user_post/1`, `delete_user_post/1`
- UserPostReceipt: `create_user_post_receipt/1`, `update_user_post_receipt/2`
- Bookmark: `create_bookmark/1`, `delete_bookmark/1`
- Preloads: `preload_post/2`, `preload_reply/2`

Query Execution (4 functions) - ✅ COMPLETE:
- `execute_query/1`, `execute_count/1`, `execute_one/1`, `execute_exists?/1`

Transaction Support (1 function) - ✅ COMPLETE:
- `transaction/1`

Repo Wrappers (21 functions) - ✅ COMPLETE:
- `repo_all/1`, `repo_all/2`, `repo_one/1`, `repo_one/2`, `repo_one!/1`, `repo_one!/2`
- `repo_aggregate/3`, `repo_aggregate/4`, `repo_exists?/1`
- `repo_preload/2`, `repo_preload/3`
- `repo_insert/1`, `repo_insert!/1`, `repo_update/1`, `repo_update!/1`
- `repo_delete/1`, `repo_delete!/1`, `repo_delete_all/1`, `repo_update_all/2`
- `repo_transaction/1`, `repo_get/2`, `repo_get!/2`, `repo_get_by/2`, `repo_get_by!/2`

Note: Complex CRUD operations (like `create_public_post`, `create_repost`, etc.) use `Ecto.Multi` transactions with business logic (broadcasts, cache invalidation, multiple related records). These remain in timeline.ex and use `Repo.transaction_on_primary()`. For native apps, these will call comprehensive API endpoints that handle the full operation server-side.

**Tests:** All 9 timeline tests pass ✅
- Additional counts: `count_user_own_posts/3`, `count_user_group_posts/3`, `count_user_connection_posts/3`, `count_group_posts/3`, `count_discover_posts/3`, `count_unread_*` functions
- Reply counts: `count_replies_for_post/3`, `count_top_level_replies/3`, `count_child_replies/3`, `count_unread_nested_replies_for_post/3`
- Bookmark: `count_user_bookmarks/3`
- Listings: `list_posts/3`, `list_replies/3`, `list_shared_posts/4`, `list_public_posts/2`, `list_public_replies/3`, `list_user_bookmarks/3`, `list_bookmark_categories/2`
- Mark read: `mark_replies_read_for_post/3`, `mark_all_replies_read_for_user/2`, `mark_nested_replies_read_for_parent/3`
- Bookmark category: `create_bookmark_category/2`, `update_bookmark_category/3`, `delete_bookmark_category/2`
- CRUD: `create_post/2`, `update_post/3`, `delete_post/2`, `create_reply/2`, `update_reply/3`, `delete_reply/2`
- And many more helper functions for bookmarks, user_posts, receipts

**Tests:** All 9 timeline tests pass ✅

#### 5.3 Groups - `groups.ex` (Priority: MEDIUM) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. All functions delegated to adapters.

**Files created:**

- `lib/mosslet/groups/adapter.ex` - Behaviour definition with 25+ callbacks
- `lib/mosslet/groups/adapters/web.ex` - Web adapter (Repo calls, ~380 lines)
- `lib_native/mosslet/groups/adapters/native.ex` - Native adapter (API + cache, ~520 lines)

**Completed Functions (delegated to adapters):**

Group Getters (2 functions):
- `get_group/1`, `get_group!/1`

Group Listings (7 functions):
- `list_groups/2`, `list_unconfirmed_groups/2`, `list_public_groups/3`
- `public_group_count/2`, `filter_groups_with_users/3`
- `group_count/1`, `group_count_confirmed/1`

UserGroup Getters (4 functions):
- `get_user_group/1`, `get_user_group!/1`, `get_user_group_with_user!/1`
- `get_user_group_for_group_and_user/2`

UserGroup Listings (4 functions):
- `list_user_groups/0`, `list_user_groups/1` (by group)
- `list_user_groups_for_user/1`, `list_user_groups_for_sync/2`

CRUD Operations (9 functions):
- Group: `create_group/5`, `update_group_multi/4`, `delete_group/1`
- UserGroup: `create_user_group/2`, `update_user_group/3`, `delete_user_group/1`
- `join_group_confirm/1`, `update_user_group_role/2`

Block Operations (6 functions):
- `list_blocked_users/1`, `user_blocked?/2`
- `get_group_block/2`, `get_group_block!/1`
- `block_member_multi/2`, `delete_group_block/1`

Utility Functions (2 functions):
- `validate_owner_count/1`, `repo_preload/2`

**Tests:** All 8 groups tests pass ✅

#### 5.4 Group Messages - `group_messages.ex` (Priority: MEDIUM) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. All functions delegated to adapters.

**Files created:**

- `lib/mosslet/group_messages/adapter.ex` - Behaviour definition with 10 callbacks
- `lib/mosslet/group_messages/adapters/web.ex` - Web adapter (Repo calls, ~90 lines)
- `lib_native/mosslet/group_messages/adapters/native.ex` - Native adapter (API + cache, ~280 lines)

**Completed Functions (delegated to adapters):**

Message Getters (2 functions):
- `get_message!/1`, `last_user_message_for_group/2`

Message Listings (3 functions):
- `list_groups/0`, `last_ten_messages_for/1`, `get_previous_n_messages/3`

CRUD Operations (3 functions):
- `create_message/2`, `update_message/2`, `delete_message/1`

Utility Functions (2 functions):
- `preload_message_sender/1`, `get_message_count_for_group/1`

**Note:** Business logic (PubSub broadcasts) stays in context, adapters handle data access only.

#### 5.5 Messages - `messages.ex` (Priority: MEDIUM) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. All functions delegated to adapters.

**Files created:**

- `lib/mosslet/messages/adapter.ex` - Behaviour definition with 6 callbacks
- `lib/mosslet/messages/adapters/web.ex` - Web adapter (Repo calls, ~80 lines)
- `lib_native/mosslet/messages/adapters/native.ex` - Native adapter (API + cache, ~230 lines)

**Completed Functions (delegated to adapters):**

Message Listings (1 function):
- `list_messages/1`

Message Getters (2 functions):
- `get_message!/2`, `get_last_message!/1`

CRUD Operations (3 functions):
- `create_message/2`, `update_message/2`, `delete_message/1`

**Note:** `change_message/2` and `db_messages_to_langchain_messages/1` are pure functions that stay in the context.

#### 5.6 Organizations - `orgs.ex` (Priority: LOW) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. All functions delegated to adapters.

**Files created:**

- `lib/mosslet/orgs/adapter.ex` - Behaviour definition with 17 callbacks
- `lib/mosslet/orgs/adapters/web.ex` - Web adapter (Repo calls, ~140 lines)
- `lib_native/mosslet/orgs/adapters/native.ex` - Native adapter (API + cache, ~420 lines)

**Completed Functions (delegated to adapters):**

Org Operations (6 functions):
- `list_orgs/0`, `list_orgs/1` (by user)
- `get_org!/1`, `get_org!/2` (by user + slug), `get_org_by_id/1`
- `create_org/2`, `update_org/2`, `delete_org/1`

Membership Operations (5 functions):
- `list_members_by_org/1`
- `get_membership!/1`, `get_membership!/2`
- `update_membership/2`, `delete_membership/1`

Invitation Operations (6 functions):
- `get_invitation_by_org!/2`, `create_invitation/2`, `delete_invitation!/1`
- `list_invitations_by_user/1`, `accept_invitation!/2`, `reject_invitation!/2`

Utility (1 function):
- `sync_user_invitations/1`

**Note:** `change_org/2`, `change_membership/2`, `build_invitation/2`, and `membership_roles/0` are pure functions that stay in the context.

#### 5.7 Statuses - `statuses.ex` (Priority: LOW) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. Data access functions delegated to adapters.

**Files created:**

- `lib/mosslet/statuses/adapter.ex` - Behaviour definition with 5 callbacks
- `lib/mosslet/statuses/adapters/web.ex` - Web adapter (Repo calls, ~110 lines)
- `lib_native/mosslet/statuses/adapters/native.ex` - Native adapter (API + cache, ~140 lines)

**Completed Functions (delegated to adapters):**

Status Update Operations (3 functions):
- `update_user_status_multi/3` - Multi-update for user + connection status
- `update_user_status_visibility/2` - Update visibility settings
- `update_connection_status_visibility/2` - Update connection visibility

Activity Operations (1 function):
- `update_user_activity/2` - Track user activity timestamps

Utility (1 function):
- `preload_connection/1` - Load connection association

**Note:** Complex privacy/visibility logic (encryption, presence checks, status access controls) stays in the context as it involves encryption that must happen on-device for native apps.

#### 5.8 Logs - `logs.ex` (Priority: LOW) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. All data access functions delegated to adapters.

**Files created:**

- `lib/mosslet/logs/adapter.ex` - Behaviour definition with 7 callbacks
- `lib/mosslet/logs/adapters/web.ex` - Web adapter (Repo calls, ~60 lines)
- `lib_native/mosslet/logs/adapters/native.ex` - Native adapter (API calls, ~100 lines)

**Completed Functions (delegated to adapters):**

Log Operations (7 functions):
- `get/1` - Get a log by ID
- `create/1` - Create a new log entry
- `exists?/1` - Check if a log matching params exists
- `get_last_log_of_user/1` - Get user's most recent log
- `delete_logs_older_than/1` - Delete old logs (cleanup)
- `delete_sensitive_logs/0` - Delete logs with PII
- `delete_user_logs/1` - Delete all logs for a user (GDPR)

**Note:** Logs are primarily server-side for audit/analytics. Native apps send log events via API; most query operations return empty/nil for native platform since logs are not cached locally.

#### 5.9 Memories - `memories.ex` (Priority: LOW) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. Legacy feature with full adapter support during transition period.

**Files created:**

- `lib/mosslet/memories/adapter.ex` - Behaviour definition with 40+ callbacks
- `lib/mosslet/memories/adapters/web.ex` - Web adapter (Repo calls, ~400 lines)
- `lib_native/mosslet/memories/adapters/native.ex` - Native adapter (API + cache, ~500 lines)

**Completed Functions (delegated to adapters):**

Memory Getters (2 functions):
- `get_memory!/1`, `get_memory/1`

Count Functions (11 functions):
- `memory_count/1`, `shared_with_user_memory_count/1`, `timeline_memory_count/1`
- `shared_between_users_memory_count/2`, `public_memory_count/1`, `group_memory_count/1`
- `remark_count/1`, `get_total_storage/1`, `count_all_memories/0`
- `get_remarks_*_count/1` (5 mood-specific counts)

Listing Functions (6 functions):
- `list_memories/2`, `filter_timeline_memories/2`, `filter_memories_shared_with_current_user/2`
- `list_public_memories/2`, `list_group_memories/2`, `list_remarks/2`

CRUD Operations (8 functions):
- Memory: `create_memory_multi/4`, `update_memory_multi/4`, `blur_memory_multi/2`, `delete_memory/1`
- Fav: `update_memory_fav/1`, `inc_favs/1`, `decr_favs/1`
- Remark: `create_remark/1`, `delete_remark/1`

Utility Functions (8 functions):
- `preload/1`, `get_remark!/1`, `get_remark/1`
- `last_ten_remarks_for/1`, `last_user_remark_for_memory/2`, `get_previous_n_remarks/3`
- `preload_remark_user/1`, `get_public_user_memory/1`, `get_user_memory/2`

**Note:** Memories is a legacy feature being phased out. This adapter implementation provides platform support during the transition period.

#### 5.10 Conversations - `conversations.ex` (Priority: LOW) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. Legacy feature with full adapter support during transition period.

**Files created:**

- `lib/mosslet/conversations/adapter.ex` - Behaviour definition with 6 callbacks
- `lib/mosslet/conversations/adapters/web.ex` - Web adapter (Repo calls, ~70 lines)
- `lib_native/mosslet/conversations/adapters/native.ex` - Native adapter (API + cache, ~180 lines)

**Completed Functions (delegated to adapters):**

Conversation Operations (6 functions):
- `load_conversations/1` - List user's conversations
- `get_conversation!/2` - Get a conversation by ID
- `total_conversation_tokens/2` - Calculate total tokens for a conversation
- `create_conversation/1` - Create a new conversation
- `update_conversation/3` - Update a conversation
- `delete_conversation/2` - Delete a conversation

**Note:** Conversations is a legacy AI chat feature being phased out. This adapter implementation provides platform support during the transition period. The native adapter includes SQLite caching for offline viewing of conversation history.

#### 5.11 Journal - `journal.ex` (Priority: MEDIUM) - ✅ COMPLETE

**Status:** Adapter pattern implementation complete. Full platform support for journal entries.

**Files created:**

- `lib/mosslet/journal/adapter.ex` - Behaviour definition with journal callbacks
- `lib/mosslet/journal/adapters/web.ex` - Web adapter (Repo calls)
- `lib_native/mosslet/journal/adapters/native.ex` - Native adapter (API + cache)

**Note:** Journal entries are end-to-end encrypted per-user, making this a key feature for the zero-knowledge native app experience.

#### 5.11 API Endpoints Required ✅ COMPLETE

For each context above, corresponding API endpoints now exist. Full API coverage:

**All Endpoints Implemented:**

- Auth: login, register, refresh, logout, me ✅
- Auth TOTP/2FA: status, setup, enable, disable, verify, backup-codes/regenerate ✅
- Auth Remember Me: remember-me/refresh ✅
- Sync: user, posts, connections, groups, full ✅
- Posts: CRUD ✅
- Users: profile, email, password, visibility, avatar, notifications, onboarding, blocked ✅
- Connections: CRUD, label, zen, photos, confirm, arrivals ✅
- Statuses: status, visibility, activity tracking ✅
- Groups: CRUD, join, members, blocks ✅
- Group Messages: CRUD, previous messages, count ✅
- Organizations: CRUD, members, memberships, invitations ✅
- Conversations: CRUD, token-count (legacy) ✅
- Messages: CRUD (legacy) ✅

**Files created:**

- `lib/mosslet_web/controllers/api/group_controller.ex` - Groups CRUD + membership + blocks
- `lib/mosslet_web/controllers/api/group_message_controller.ex` - Group chat messages
- `lib/mosslet_web/controllers/api/org_controller.ex` - Organizations + memberships + invitations
- `lib/mosslet_web/controllers/api/conversation_controller.ex` - AI conversations (legacy)
- `lib/mosslet_web/controllers/api/message_controller.ex` - Conversation messages (legacy)

**Test files created:**

- `test/mosslet_web/controllers/api/group_controller_test.exs`
- `test/mosslet_web/controllers/api/org_controller_test.exs`
- `test/mosslet_web/controllers/api/conversation_controller_test.exs`

**API Routes added to router.ex:**

Groups:
- `GET /api/groups` - List user's groups
- `GET /api/groups/unconfirmed` - List unconfirmed groups
- `GET /api/groups/public` - List public groups
- `GET /api/groups/count` - Get group counts
- `GET /api/groups/filter-with-users` - Filter groups with specific users
- `GET /api/groups/:id` - Get specific group
- `POST /api/groups` - Create group
- `PUT /api/groups/:id` - Update group
- `DELETE /api/groups/:id` - Delete group
- `POST /api/groups/:id/join` - Join public group
- `GET /api/groups/:group_id/members` - List group members
- `GET /api/groups/:group_id/blocks` - List blocked users
- `GET /api/groups/:group_id/blocks/check` - Check if user blocked
- `POST /api/groups/:group_id/blocks` - Block user
- `DELETE /api/groups/:group_id/blocks/:id` - Unblock user

UserGroups:
- `POST /api/user-groups` - Create membership
- `GET /api/user-groups/:id` - Get membership
- `PUT /api/user-groups/:id` - Update membership
- `PUT /api/user-groups/role` - Update role
- `DELETE /api/user-groups/:id` - Delete membership
- `POST /api/user-groups/:id/confirm` - Confirm membership

Group Messages:
- `GET /api/groups/:group_id/messages` - List messages
- `GET /api/groups/:group_id/messages/last-user-message` - Get last user message
- `GET /api/groups/:group_id/messages/count` - Get message count
- `GET /api/groups/:group_id/messages/previous` - Get previous messages
- `POST /api/group-messages` - Create message
- `GET /api/group-messages/:id` - Get message
- `PUT /api/group-messages/:id` - Update message
- `DELETE /api/group-messages/:id` - Delete message

Organizations:
- `GET /api/orgs` - List orgs
- `GET /api/orgs/mine` - List user's orgs
- `GET /api/orgs/by-id/:id` - Get org by ID
- `GET /api/orgs/:id` - Get org by slug
- `POST /api/orgs` - Create org
- `PUT /api/orgs/:id` - Update org
- `DELETE /api/orgs/:id` - Delete org
- `GET /api/orgs/:org_id/members` - List members
- `GET /api/orgs/:org_id/invitations/:id` - Get invitation
- `POST /api/orgs/:org_id/invitations` - Create invitation

Org Memberships:
- `GET /api/org-memberships/:id` - Get membership
- `PUT /api/org-memberships/:id` - Update membership
- `DELETE /api/org-memberships/:id` - Delete membership

Org Invitations:
- `GET /api/org-invitations/mine` - List user's invitations
- `DELETE /api/org-invitations/:id` - Delete invitation
- `POST /api/org-invitations/:id/accept` - Accept invitation
- `POST /api/org-invitations/:id/reject` - Reject invitation

Conversations (legacy):
- `GET /api/conversations` - List conversations
- `GET /api/conversations/:id` - Get conversation
- `GET /api/conversations/:id/token-count` - Get token count
- `POST /api/conversations` - Create conversation
- `PUT /api/conversations/:id` - Update conversation
- `DELETE /api/conversations/:id` - Delete conversation

Messages (legacy):
- `GET /api/conversations/:conversation_id/messages` - List messages
- `GET /api/conversations/:conversation_id/messages/last` - Get last message
- `GET /api/conversations/:conversation_id/messages/:id` - Get message
- `POST /api/conversations/:conversation_id/messages` - Create message
- `PUT /api/conversations/:conversation_id/messages/:id` - Update message
- `DELETE /api/conversations/:conversation_id/messages/:id` - Delete message

#### 5.12 Caching Strategy ✅ COMPLETE

**Status:** Caching strategy fully implemented across all native adapters.

**Completed:**

- [x] After successful API reads, cache data in SQLite via `Mosslet.Cache`
- [x] On API failure (offline), fall back to cached data
- [x] On writes, queue in `SyncQueueItem` if offline, sync later
- [x] Sync GenServer extended to handle all resource types

**Implementation Details:**

All native adapters follow a consistent pattern:

1. **Read operations:** Try API first → cache result → fall back to cache on failure
2. **Write operations:** If online, make API call; if offline, queue for sync via `Cache.queue_for_sync/4`
3. **Sync GenServer:** Processes queued items when connectivity is restored

**Sync GenServer Resource Types Supported:**

| Resource Type | Actions |
|---------------|---------|
| `post` | create, update, delete |
| `reply` | create, update, delete, mark_read_for_post, mark_all_read, mark_nested_read |
| `receipt` | mark_read |
| `user_connection` | create, update, update_label, update_zen, update_photos, delete |
| `user` | update_name, update_username, update_visibility, update_onboarding, update_notifications, update_tokens, create_visibility_group, update_visibility_group |
| `group` | create, update, delete |
| `user_group` | create, update, delete |
| `group_message` | create, update, delete |
| `memory` | create, update, delete |
| `remark` | create, delete |
| `conversation` | create, update, delete |
| `message` | update, delete |
| `org` | update |
| `status` | update |

**Caching Patterns by Adapter:**

| Adapter | Cache Operations | Pattern |
|---------|------------------|---------|
| `accounts` | 62 | Full caching + queue_for_sync |
| `timeline` | 13 | Timeline tabs cached, posts cached |
| `groups` | 26 | with_fallback_to_cache helper |
| `memories` | 9 | Cache on read, queue writes |
| `journal` | 10 | Books + entries cached per-user |
| `orgs` | 6 | Orgs cached, queue writes |
| `group_messages` | 9 | Messages cached per-group |
| `messages` | 7 | Conversation messages cached |
| `conversations` | 12 | Conversations cached per-user |
| `statuses` | 1 | Minimal (real-time data) |
| `logs` | 0 | Server-side only (intentional) |

**Files modified:**

- `lib_native/mosslet/sync.ex` - Extended sync handlers for all resource types
- `PUT /api/connections/:id` - Update connection profile

### Phase 5.5: Desktop Window & Auth Setup ✅ COMPLETE

The desktop-specific infrastructure is already in place:

- [x] `application.ex` supervision tree handles `native_children()` vs `web_children()`
- [x] `MossletWeb.Plugs.DesktopAuth` wraps `Desktop.Auth` for WebView token validation
- [x] `MossletWeb.Desktop.Window` configuration exists
- [x] `config/desktop.exs` configures desktop environment

### Phase 6: Mobile App Setup ✅ COMPLETE

**Status:** iOS and Android wrapper projects created with WebView integration.

- [x] Create iOS wrapper project (Xcode)
- [x] Create Android wrapper project (Android Studio)
- [x] Configure native WebView integration
- [x] Handle app lifecycle events
- [ ] Test on iOS simulator and Android emulator (requires building Erlang release)

**iOS Project Structure (`native/ios/`):**

```

native/ios/
├── Mosslet.xcodeproj/ # Xcode project
└── Mosslet/
├── AppDelegate.swift # App lifecycle, Erlang startup
├── MainViewController.swift # WKWebView container
├── LoadingViewController.swift # Launch screen
├── JsonBridge.swift # JS ↔ Swift via webkit.messageHandlers
├── Bridge.swift # Erlang runtime bridge
├── Keychain.swift # iOS Keychain wrapper
├── Assets.xcassets/ # App icons, colors
├── Base.lproj/LaunchScreen.storyboard
├── Info.plist
└── Mosslet.entitlements

```

**Android Project Structure (`native/android/`):**

```

native/android/
├── app/
│ ├── src/main/
│ │ ├── java/com/mosslet/app/
│ │ │ ├── MossletApplication.kt # Application class
│ │ │ ├── MainActivity.kt # WebView activity
│ │ │ ├── Bridge.kt # Erlang runtime bridge
│ │ │ ├── JsonBridge.kt # JS ↔ Kotlin via @JavascriptInterface
│ │ │ └── SecureStorage.kt # Android Keystore wrapper
│ │ ├── res/ # Layouts, themes, colors
│ │ └── AndroidManifest.xml
│ ├── build.gradle
│ └── proguard-rules.pro
├── build.gradle
├── settings.gradle
└── gradle.properties

````

**Unified JavaScript Bridge (`assets/js/mobile_native.js`):**

```javascript
// Works across iOS and Android
MobileNative.isNative()      // true on native apps
MobileNative.getPlatform()   // 'ios' | 'android' | 'web'
MobileNative.openURL(url)    // Open external URL
MobileNative.share(text)     // Native share sheet
MobileNative.haptic(style)   // Haptic feedback
````

**Features Implemented:**

| Feature                | iOS                      | Android                |
| ---------------------- | ------------------------ | ---------------------- |
| WebView container      | WKWebView                | WebView                |
| JS bridge              | `webkit.messageHandlers` | `@JavascriptInterface` |
| Secure storage         | Keychain                 | Android Keystore       |
| Safe area insets       | CSS variables            | CSS variables          |
| App lifecycle events   | ✅                       | ✅                     |
| External link handling | ✅                       | ✅                     |
| Share sheet            | ✅                       | ✅                     |
| Haptic feedback        | ✅                       | ✅                     |
| WebView debugging      | Safari DevTools          | Chrome DevTools        |

**Next Steps:**

1. Build Erlang release for iOS/Android targets
2. Integrate release into native projects
3. Test on simulators/emulators
4. Configure app signing for distribution

### Phase 7: Mobile Billing ✅ COMPLETE

**Status:** Full mobile billing infrastructure implemented for iOS and Android.

- [x] Create `Mosslet.Billing.Providers.AppleIAP` module
- [x] Create `Mosslet.Billing.Providers.GooglePlay` module
- [x] Create `Mosslet.Billing.Providers.MobileIAP` shared utilities
- [x] Add receipt validation endpoints
- [x] Handle subscription sync across platforms
- [x] Add webhook endpoints for Apple/Google server notifications
- [x] Add restore purchases endpoint for app reinstalls

**Files created:**

- `lib/mosslet/billing/providers/apple_iap.ex` - Apple App Store Server API v2 integration
- `lib/mosslet/billing/providers/google_play.ex` - Google Play Developer API integration
- `lib/mosslet/billing/providers/mobile_iap.ex` - Shared utilities (product mapping, receipt processing)
- `lib/mosslet_web/controllers/api/billing_controller.ex` - Mobile billing API endpoints
- `lib/mosslet_web/controllers/api/webhooks_controller.ex` - Apple/Google webhook handlers
- `test/mosslet_web/controllers/api/billing_controller_test.exs` - Tests

**API Endpoints:**

Authenticated (requires Bearer token):

- `POST /api/billing/apple/validate` - Validate Apple IAP purchase (StoreKit 2 transactionId)
- `POST /api/billing/google/validate` - Validate Google Play purchase (productId + purchaseToken)
- `GET /api/billing/subscription` - Get current subscription status
- `GET /api/billing/products` - Get available products with mobile product IDs
- `POST /api/billing/restore` - Restore purchases after reinstall/new device

Webhooks (server-to-server, no auth):

- `POST /api/webhooks/apple` - Apple App Store Server Notifications V2
- `POST /api/webhooks/google-play` - Google Play Real-time Developer Notifications (RTDN)

**Configuration Required:**

```elixir
# config/runtime.exs
config :mosslet, Mosslet.Billing.Providers.AppleIAP,
  bundle_id: "com.mosslet.app",
  issuer_id: System.get_env("APPLE_ISSUER_ID"),
  key_id: System.get_env("APPLE_KEY_ID"),
  private_key: System.get_env("APPLE_PRIVATE_KEY"),
  environment: :production  # or :sandbox

config :mosslet, Mosslet.Billing.Providers.GooglePlay,
  package_name: "com.mosslet.app",
  service_account_json: System.get_env("GOOGLE_SERVICE_ACCOUNT_JSON")
  # OR provide credentials directly:
  # client_email: System.get_env("GOOGLE_CLIENT_EMAIL"),
  # private_key: System.get_env("GOOGLE_PRIVATE_KEY")

config :mosslet, :mobile_product_mapping, %{
  "com.mosslet.personal.monthly" => "personal-monthly",
  "com.mosslet.personal.yearly" => "personal-yearly",
  "com.mosslet.personal.lifetime" => "personal-lifetime"
}
```

**Mobile App Flow:**

1. User purchases in native app (StoreKit 2 / Google Play Billing)
2. App receives transaction/purchase token
3. App calls `/api/billing/apple/validate` or `/api/billing/google/validate`
4. Server validates with Apple/Google, creates/updates subscription
5. Server returns subscription status to app
6. Apple/Google send renewal/cancellation webhooks for ongoing subscription management

**Note:** The existing web UI (`SubscribeLive`) handles Stripe checkout for web users. Native apps bypass this and use native purchase UIs provided by Apple/Google, then validate via the API endpoints

### Phase 8: Native Features

**Status:** In progress

- [x] Push notifications (APNs, FCM) - ✅ COMPLETE
  - `Mosslet.Notifications.Push` context with zero-knowledge design
  - `Mosslet.Notifications.Push.APNs` - Apple Push Notification service (HTTP/2 + JWT)
  - `Mosslet.Notifications.Push.FCM` - Firebase Cloud Messaging (HTTP v1 + OAuth)
  - `Mosslet.Notifications.DeviceToken` schema with encrypted storage
  - `MossletWeb.API.DeviceController` - API endpoints for token registration
  - Database migration for `device_tokens` table
  - `PushNotificationHook` - JavaScript hook for native push integration with proper cleanup
  - `MobileNative.push` - JS bridge for iOS/Android push APIs
  - ✅ iOS client integration complete:
    - `AppDelegate.swift` - APNs delegate, `UNUserNotificationCenterDelegate`
    - `JsonBridge.swift` - Push permission/token bridge to WebView
    - `Info.plist` - `UIBackgroundModes` includes `remote-notification`
    - `Mosslet.entitlements` - `aps-environment` configured
  - ✅ Android client integration complete:
    - `PushNotificationService.kt` - `FirebaseMessagingService` with `onNewToken`/`onMessageReceived`
    - `JsonBridge.kt` - Permission request handling, FCM token registration
    - `MainActivity.kt` - Permission result handling, notification tap intents
    - `MossletApplication.kt` - Notification channel creation
    - Firebase dependencies added to `build.gradle`
    - ProGuard rules for Firebase
  - See `native/PUSH_NOTIFICATION_SETUP.md` for configuration guide
- [x] Deep linking / Universal links - ✅ COMPLETE
  - `Mosslet.DeepLink` - URL parsing, route resolution, and link generation
  - `MossletWeb.WellKnownController` - Serves `apple-app-site-association` and `assetlinks.json`
  - `DeepLinkHook` - JavaScript hook for deep link navigation integration
  - `MobileNative.deepLink` - JS bridge for deep link handling
  - iOS: Universal Links + custom `mosslet://` scheme support
    - Updated `Mosslet.entitlements` with `applinks:mosslet.com` and `webcredentials:mosslet.com`
    - Updated `Info.plist` with `CFBundleURLTypes` for custom scheme
    - `AppDelegate.swift` handles `application(_:continue:restorationHandler:)` for Universal Links
    - `AppDelegate.swift` handles `application(_:open:options:)` for custom scheme
    - `JsonBridge.swift` notifies WebView of incoming deep links
  - Android: App Links + custom `mosslet://` scheme support
    - Updated `AndroidManifest.xml` with `android:autoVerify="true"` intent filters for `mosslet.com`
    - `MainActivity.kt` handles `onNewIntent` for deep link processing
    - Supports HTTPS links with pathPrefix: `/app`, `/profile`, `/invite`, `/group`, `/post`
  - **Supported Routes:**
    - Profiles: `/profile/:slug`
    - Posts: `/app/posts/:id`, `/post/:id`
    - Groups: `/app/groups/:id`, `/group/:id`
    - Invites: `/invite/:token`, `/invite/group/:token`
    - Email confirmation: `/users/settings/confirm-email/:token`
    - Settings: `/app/users/edit-*`
    - Timeline: `/app/timeline`, `/app/timeline/connections`, `/app/timeline/groups`, `/app/timeline/discover`
    - Journal: `/app/journal`, `/app/journal/new`, `/app/journal/books`
  - **Configuration Required:**
    - iOS: Replace `TEAM_ID` in `WellKnownController` with actual Apple Team ID
    - Android: Replace `SHA256_FINGERPRINT` with app signing certificate fingerprint
- [x] Background sync - ✅ COMPLETE
  - `Mosslet.Sync` GenServer enhanced with app state awareness (foreground/background)
  - `BackgroundSyncHook` - JavaScript hook for app lifecycle and network events
  - `MobileNative.lifecycle` - JS API for app state management
  - `MobileNative.sync` - JS API for sync control
  - `MobileNative.network` - JS API for network status
  - `MossletWeb.SyncHelpers` - Enhanced LiveView helpers for background sync events
  - iOS: Background Fetch support via `performFetchWithCompletionHandler`
  - iOS: App lifecycle events notify WebView of state changes
  - Android: WorkManager `BackgroundSyncWorker` for periodic background sync
  - Android: App lifecycle events via `onResume`/`onPause`
  - **Sync Intervals:**
    - Active (foreground): 5 minute intervals
    - Background/Inactive: 15 minute intervals
    - Health checks: 10s (active), 1m (background)
  - **Automatic sync triggers:**
    - App becomes active (foreground)
    - Network connectivity restored
    - OS background fetch (iOS/Android)
- [x] Offline mode indicators
  - `MossletWeb.DesignSystem.sync_status_indicator/1` - Compact status pill
  - `MossletWeb.DesignSystem.offline_banner/1` - Full-width offline banner
  - `MossletWeb.SyncHelpers` - LiveView helpers for sync status subscription
  - `SyncStatusHook` - JavaScript hook for real-time status updates
  - Integrated into app layout (shows banner when offline)
- [x] Native file picker integration - **SKIPPED** (Phoenix LiveView `live_file_input` works in WebViews, no native integration needed)

### Phase 9: Packaging & Distribution

**Status:** In Progress

#### 9.1 Build Erlang/OTP for Mobile Targets ⏳ IN PROGRESS

The elixir-desktop project requires cross-compiled Erlang/OTP for each target platform.

**Prerequisites:**

- Xcode (for iOS)
- Android NDK (for Android)
- Docker (optional, for reproducible builds)

**iOS Build Steps:**

- [ ] Set up iOS build environment (Xcode Command Line Tools)
- [ ] Clone `elixir-desktop/otp_build` repository
- [ ] Build OTP for iOS Simulator (arm64 + x86_64)
- [ ] Build OTP for iOS Device (arm64)
- [ ] Create universal xcframework

**Android Build Steps:**

- [ ] Set up Android NDK (r25+)
- [ ] Build OTP for Android arm64-v8a
- [ ] Build OTP for Android armeabi-v7a (optional, older devices)
- [ ] Build OTP for Android x86_64 (emulator)

**Build Automation:** ✅ COMPLETE

- [x] `scripts/build_mobile.sh` - Main build orchestration script
- [x] `scripts/package_ios.sh` - Package release for iOS bundle
- [x] `scripts/package_android.sh` - Package release for Android assets
- [x] `native/MOBILE_BUILD_GUIDE.md` - Comprehensive build documentation
- [x] `.github/workflows/mobile-build.yml` - CI/CD for automated builds

**Resources:**

- [otp_build repository](https://github.com/nickvander/otp_build) - Scripts for cross-compiling OTP
- [elixir-desktop iOS example](https://github.com/nickvander/ios-elixir-example)
- [elixir-desktop Android example](https://github.com/nickvander/android-elixir-example)

#### 9.2 Create Release Configurations ✅ COMPLETE

- [x] Configure `mix release` for mobile target in `mix.exs`
- [x] Configure release for iOS (strip debug, optimize for size)
- [x] Configure release for Android (strip debug, optimize for size)
- [x] Set up asset compilation for releases

#### 9.3 Integrate Releases with Native Projects ✅ COMPLETE

**iOS:**

- [x] Updated `Bridge.swift` to start Erlang VM with proper environment
- [x] Configure app to extract and run BEAM files
- [x] Bundle compiled BEAM files and assets via `package_ios.sh`
- [ ] Test on iOS Simulator (requires OTP build)

**Android:**

- [x] Updated `Bridge.kt` to start Erlang VM with proper environment
- [x] Configure app to extract release from assets
- [x] Bundle compiled BEAM files and assets via `package_android.sh`
- [ ] Test on Android Emulator (requires OTP build)

#### 9.4 Desktop Packaging ⏳ IN PROGRESS

**Status:** Desktop wrapper projects and build infrastructure to be created.

**Overview:** Desktop apps use the same elixir-desktop architecture as mobile, but with simpler native wrappers since we can use wxWidgets (cross-platform) or platform-specific WebView wrappers.

##### 9.4.1 macOS Desktop App

**Project Structure (`native/macos/`):**

```
native/macos/
├── Mosslet.xcodeproj/           # Xcode project
└── Mosslet/
    ├── AppDelegate.swift         # App lifecycle, Erlang startup
    ├── MainWindowController.swift # WKWebView window controller
    ├── Bridge.swift              # Erlang runtime bridge (reuse from iOS)
    ├── JsonBridge.swift          # JS ↔ Swift via webkit.messageHandlers
    ├── Keychain.swift            # macOS Keychain wrapper
    ├── MenuBuilder.swift         # Native macOS menu bar
    ├── Preferences.swift         # System preferences integration
    ├── Assets.xcassets/          # App icons
    ├── Info.plist
    ├── Mosslet.entitlements
    └── Mosslet-Bridging-Header.h # For Erlang NIF integration
```

**Implementation Checklist:**

- [ ] Create Xcode macOS project with WKWebView
- [ ] Port `Bridge.swift` from iOS (Erlang VM startup)
- [ ] Port `JsonBridge.swift` from iOS (JS ↔ Native bridge)
- [ ] Implement `MenuBuilder.swift` for native menu bar
  - File menu (New Window, Close, Quit)
  - Edit menu (Undo, Redo, Cut, Copy, Paste, Select All)
  - View menu (Zoom, Fullscreen)
  - Window menu (Minimize, Bring All to Front)
  - Help menu (About, Documentation)
- [ ] Implement `Keychain.swift` for secure credential storage
- [ ] Configure window sizing and resizing (min 900x600, remember last size)
- [ ] Add Dock icon and badge support
- [ ] Add Touch Bar support (optional)
- [ ] Configure sandboxing entitlements:
  - `com.apple.security.network.client` (API access)
  - `com.apple.security.files.user-selected.read-write` (file uploads)

**Signing & Notarization:**

- [ ] Apple Developer Program enrollment ($99/year)
- [ ] Create Developer ID Application certificate
- [ ] Configure Hardened Runtime entitlements
- [ ] Set up notarization workflow via `xcrun notarytool`
- [ ] Create DMG installer with background image and Applications shortcut

**Distribution:**

- [ ] DMG direct download (from mosslet.com)
- [ ] Mac App Store submission (optional)
- [ ] Sparkle auto-update framework integration

##### 9.4.2 Windows Desktop App

**Project Structure (`native/windows/`):**

```
native/windows/
├── Mosslet.sln                   # Visual Studio solution
├── Mosslet/
│   ├── Mosslet.csproj            # C# WPF project
│   ├── App.xaml                  # Application entry
│   ├── App.xaml.cs
│   ├── MainWindow.xaml           # WebView2 window
│   ├── MainWindow.xaml.cs
│   ├── Bridge.cs                 # Erlang runtime bridge
│   ├── JsonBridge.cs             # JS ↔ C# via WebView2 messaging
│   ├── SecureStorage.cs          # DPAPI credential storage
│   ├── SingleInstance.cs         # Single instance enforcement
│   └── Properties/
│       ├── AssemblyInfo.cs
│       └── Resources.resx
├── Installer/
│   ├── installer.nsi             # NSIS installer script
│   └── banner.bmp
└── README.md
```

**Implementation Checklist:**

- [ ] Create .NET 8 WPF project with WebView2
- [ ] Implement `Bridge.cs` for Erlang VM startup
- [ ] Implement `JsonBridge.cs` for JS ↔ Native messaging
- [ ] Implement `SecureStorage.cs` using Windows DPAPI
- [ ] Configure window chrome (custom title bar optional)
- [ ] Add system tray icon support
- [ ] Implement single instance check via Mutex
- [ ] Add jump list items (New Window, Settings)

**Installer (NSIS):**

- [ ] Create NSIS installer script
- [ ] Configure Start Menu shortcuts
- [ ] Configure Desktop shortcut (optional)
- [ ] Add uninstaller with proper registry cleanup
- [ ] Create portable ZIP distribution

**Code Signing:**

- [ ] Obtain EV Code Signing Certificate (~$300-500/year)
- [ ] Configure SignTool in build process
- [ ] Submit for SmartScreen reputation (first runs)

**Distribution:**

- [ ] Direct download installer (.exe)
- [ ] Portable ZIP (no admin required)
- [ ] Microsoft Store (MSIX package, optional)
- [ ] WinGet package manifest

##### 9.4.3 Linux Desktop App

**Project Structure (`native/linux/`):**

```
native/linux/
├── src/
│   ├── main.c                    # GTK4 + WebKitGTK entry point
│   ├── bridge.c                  # Erlang runtime bridge
│   ├── bridge.h
│   ├── json_bridge.c             # JS ↔ C via WebKit messaging
│   ├── json_bridge.h
│   ├── secure_storage.c          # libsecret integration
│   └── secure_storage.h
├── resources/
│   ├── mosslet.desktop           # Desktop entry
│   ├── mosslet.appdata.xml       # AppStream metadata
│   └── icons/
│       ├── 16x16/mosslet.png
│       ├── 32x32/mosslet.png
│       ├── 48x48/mosslet.png
│       ├── 128x128/mosslet.png
│       ├── 256x256/mosslet.png
│       └── scalable/mosslet.svg
├── packaging/
│   ├── appimage/
│   │   └── AppDir/               # AppImage structure
│   ├── deb/
│   │   └── DEBIAN/control
│   ├── rpm/
│   │   └── mosslet.spec
│   └── flatpak/
│       └── com.mosslet.Mosslet.yml
├── meson.build                   # Meson build system
└── README.md
```

**Implementation Checklist:**

- [ ] Create GTK4 + WebKitGTK application
- [ ] Implement `bridge.c` for Erlang VM startup
- [ ] Implement `json_bridge.c` for JS ↔ Native messaging
- [ ] Implement `secure_storage.c` using libsecret (Secret Service API)
- [ ] Configure XDG desktop integration (icons, mime types)
- [ ] Add system tray/indicator support (libappindicator)
- [ ] Support both X11 and Wayland

**Packaging Formats:**

- [ ] **AppImage** (universal, no dependencies)
  - Bundle all dependencies
  - Configure `appimagetool`
  - Add `AppRun` entry script
- [ ] **Flatpak** (sandboxed, Flathub distribution)
  - Create Flatpak manifest
  - Configure permissions (network, files)
  - Submit to Flathub
- [ ] **Deb** (Debian/Ubuntu)
  - Create control file with dependencies
  - Post-install scripts for icon cache
- [ ] **RPM** (Fedora/RHEL)
  - Create spec file
  - Configure for Copr or direct download
- [ ] **AUR** (Arch Linux)
  - Create PKGBUILD
  - Submit to AUR

**Distribution:**

- [ ] Flathub (primary)
- [ ] AppImage direct download
- [ ] PPA for Ubuntu (optional)
- [ ] Copr for Fedora (optional)

##### 9.4.4 Desktop Build Scripts

**Files to create:**

- [ ] `scripts/build_desktop.sh` - Main desktop build orchestration
- [ ] `scripts/package_macos.sh` - Package release for macOS app bundle
- [ ] `scripts/package_windows.sh` - Package release for Windows
- [ ] `scripts/package_linux.sh` - Package release for Linux formats
- [ ] `native/DESKTOP_BUILD_GUIDE.md` - Comprehensive desktop build docs

**`scripts/build_desktop.sh` implementation:**

```bash
#!/bin/bash
# Build script for Mosslet desktop apps
# Usage: ./scripts/build_desktop.sh {macos|windows|linux|all} [--release]

PLATFORM="${1:-all}"
BUILD_TYPE="${2:-debug}"

case $PLATFORM in
    macos)   build_macos ;;
    windows) build_windows ;;
    linux)   build_linux ;;
    all)     build_macos; build_windows; build_linux ;;
esac
```

##### 9.4.5 Desktop-Specific Features

| Feature           | macOS                    | Windows               | Linux                |
| ----------------- | ------------------------ | --------------------- | -------------------- |
| WebView           | WKWebView                | WebView2              | WebKitGTK            |
| Secure Storage    | Keychain                 | DPAPI                 | libsecret            |
| Notifications     | UNUserNotificationCenter | ToastNotification     | libnotify            |
| System Tray       | NSStatusItem             | NotifyIcon            | AppIndicator         |
| Auto-Update       | Sparkle                  | WinSparkle / built-in | AppImage updates     |
| Global Shortcuts  | NSEvent                  | RegisterHotKey        | X11/Wayland specific |
| File Associations | Info.plist UTIs          | Registry              | .desktop mimetypes   |

##### 9.4.6 Desktop OTP Build

Unlike mobile, desktop OTP can use prebuilt binaries or compile from source:

**macOS:**

- Use Homebrew: `brew install erlang` (development)
- Bundle prebuilt OTP for distribution
- Universal binary (arm64 + x86_64) for Apple Silicon + Intel

**Windows:**

- Use official Erlang installer (development)
- Bundle prebuilt OTP for distribution
- x64 architecture only (modern Windows)

**Linux:**

- Use system package manager (development)
- Bundle in AppImage/Flatpak for distribution
- x86_64 architecture (primary), aarch64 (Raspberry Pi, etc.)

#### 9.5 App Store Submission

- [ ] iOS App Store submission
  - [ ] App Store Connect setup
  - [ ] Screenshots and metadata
  - [ ] Privacy policy and data handling declarations
  - [ ] TestFlight beta testing
- [ ] Android Play Store submission
  - [ ] Google Play Console setup
  - [ ] Screenshots and metadata
  - [ ] Privacy policy
  - [ ] Internal/closed testing track

#### 9.6 CI/CD Pipeline ✅ COMPLETE

- [x] GitHub Actions workflow for multi-platform builds (`.github/workflows/mobile-build.yml`)
- [x] Automated OTP caching for faster builds
- [x] Automated deployment to TestFlight (when secrets configured)
- [x] Automated deployment to Play Store internal track (when secrets configured)
- [ ] Automated testing on simulators/emulators

#### 9.7 Unified Build System ⏳ PENDING

**Goal:** Single `mix build.native` task that builds all native apps across all platforms.

##### Mix Task Implementation

**File: `lib/mix/tasks/build/native.ex`**

```elixir
defmodule Mix.Tasks.Build.Native do
  @moduledoc """
  Build native apps for all platforms.

  ## Usage

      # Build all platforms (current host only)
      mix build.native

      # Build specific platform(s)
      mix build.native --platform ios
      mix build.native --platform android
      mix build.native --platform macos
      mix build.native --platform windows
      mix build.native --platform linux

      # Build multiple platforms
      mix build.native --platform ios --platform android

      # Build with release optimization
      mix build.native --release

      # Build all mobile
      mix build.native --mobile

      # Build all desktop
      mix build.native --desktop

  ## Options

      --platform, -p   Target platform(s): ios, android, macos, windows, linux
      --release, -r    Build optimized release (default: debug)
      --mobile, -m     Build all mobile platforms (ios + android)
      --desktop, -d    Build all desktop platforms (macos + windows + linux)
      --all, -a        Build all platforms
      --parallel       Build platforms in parallel (requires more resources)
      --skip-otp       Skip OTP build check (use cached)
      --clean          Clean build artifacts before building
      --output DIR     Output directory (default: _build/native)

  ## Environment Variables

      OTP_BUILD_DIR       Path to otp_build repo (default: ~/otp_build)
      ANDROID_NDK_HOME    Android NDK path
      ANDROID_SDK_ROOT    Android SDK path
  """

  use Mix.Task

  @shortdoc "Build native apps for mobile and desktop"

  @switches [
    platform: [:string, :keep],
    release: :boolean,
    mobile: :boolean,
    desktop: :boolean,
    all: :boolean,
    parallel: :boolean,
    skip_otp: :boolean,
    clean: :boolean,
    output: :string
  ]

  @aliases [p: :platform, r: :release, m: :mobile, d: :desktop, a: :all]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    platforms = resolve_platforms(opts)
    build_type = if opts[:release], do: :release, else: :debug

    Mix.shell().info("Building native apps for: #{Enum.join(platforms, ", ")}")
    Mix.shell().info("Build type: #{build_type}")

    if opts[:clean], do: clean_build()

    if opts[:parallel] do
      build_parallel(platforms, build_type, opts)
    else
      build_sequential(platforms, build_type, opts)
    end

    Mix.shell().info("\\n✅ Build complete!")
    print_artifacts(platforms, opts)
  end

  defp resolve_platforms(opts) do
    cond do
      opts[:all] -> [:ios, :android, :macos, :windows, :linux]
      opts[:mobile] -> [:ios, :android]
      opts[:desktop] -> [:macos, :windows, :linux]
      opts[:platform] -> Keyword.get_values(opts, :platform) |> Enum.map(&String.to_existing_atom/1)
      true -> detect_host_platforms()
    end
  end

  defp detect_host_platforms do
    case :os.type() do
      {:unix, :darwin} -> [:macos, :ios]
      {:unix, _} -> [:linux]
      {:win32, _} -> [:windows]
    end
  end

  # ... implementation continues
end
```

##### Build Scripts Structure

```
scripts/
├── build_native.sh          # Main entry point (calls mix task)
├── build_mobile.sh          # Mobile-specific (existing) ✅
├── build_desktop.sh         # Desktop-specific (new)
├── package_ios.sh           # iOS packaging (existing) ✅
├── package_android.sh       # Android packaging (existing) ✅
├── package_macos.sh         # macOS packaging (new)
├── package_windows.sh       # Windows packaging (new)
├── package_linux.sh         # Linux packaging (new)
├── notarize_macos.sh        # macOS notarization
├── sign_windows.sh          # Windows code signing
└── ci/
    ├── build_all.sh         # CI full build
    ├── build_matrix.sh      # Matrix build helper
    └── upload_artifacts.sh  # Upload to distribution
```

##### CI/CD Integration

**File: `.github/workflows/native-build.yml`**

```yaml
name: Build Native Apps

on:
  push:
    tags: ["v*"]
  workflow_dispatch:
    inputs:
      platforms:
        description: "Platforms to build (comma-separated: ios,android,macos,windows,linux)"
        default: "all"
      release:
        description: "Build release version"
        type: boolean
        default: true

jobs:
  build-mobile:
    strategy:
      matrix:
        include:
          - platform: ios
            os: macos-latest
          - platform: android
            os: ubuntu-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: "27.0"
          elixir-version: "1.17"
      - name: Build ${{ matrix.platform }}
        run: mix build.native --platform ${{ matrix.platform }} --release

  build-desktop:
    strategy:
      matrix:
        include:
          - platform: macos
            os: macos-latest
          - platform: windows
            os: windows-latest
          - platform: linux
            os: ubuntu-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: "27.0"
          elixir-version: "1.17"
      - name: Build ${{ matrix.platform }}
        run: mix build.native --platform ${{ matrix.platform }} --release
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: mosslet-${{ matrix.platform }}
          path: _build/native/${{ matrix.platform }}/

  release:
    needs: [build-mobile, build-desktop]
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')
    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            mosslet-ios/*.ipa
            mosslet-android/*.apk
            mosslet-android/*.aab
            mosslet-macos/*.dmg
            mosslet-windows/*.exe
            mosslet-linux/*.AppImage
```

##### Output Structure

```
_build/native/
├── ios/
│   ├── Mosslet.ipa              # App Store / Ad-hoc
│   └── Mosslet.xcarchive/       # Xcode archive
├── android/
│   ├── mosslet-debug.apk        # Debug APK
│   ├── mosslet-release.apk      # Release APK
│   └── mosslet-release.aab      # Play Store bundle
├── macos/
│   ├── Mosslet.app/             # App bundle
│   ├── Mosslet.dmg              # Installer
│   └── Mosslet.zip              # Notarized zip
├── windows/
│   ├── Mosslet-Setup.exe        # NSIS installer
│   ├── Mosslet-Portable.zip     # Portable version
│   └── Mosslet.msix             # Store package
└── linux/
    ├── Mosslet.AppImage         # Universal package
    ├── mosslet_1.0.0_amd64.deb  # Debian package
    ├── mosslet-1.0.0.x86_64.rpm # RPM package
    └── mosslet.flatpak          # Flatpak bundle
```

##### Implementation Checklist

- [ ] Create `lib/mix/tasks/build/native.ex` Mix task
- [ ] Create `lib/mix/tasks/build/ios.ex` iOS-specific task
- [ ] Create `lib/mix/tasks/build/android.ex` Android-specific task
- [ ] Create `lib/mix/tasks/build/macos.ex` macOS-specific task
- [ ] Create `lib/mix/tasks/build/windows.ex` Windows-specific task
- [ ] Create `lib/mix/tasks/build/linux.ex` Linux-specific task
- [ ] Create `scripts/build_desktop.sh` shell script
- [ ] Create `scripts/package_macos.sh` packaging script
- [ ] Create `scripts/package_windows.sh` packaging script
- [ ] Create `scripts/package_linux.sh` packaging script
- [ ] Create `scripts/notarize_macos.sh` notarization script
- [ ] Create `scripts/sign_windows.sh` code signing script
- [ ] Update `.github/workflows/` with unified CI/CD
- [ ] Create `native/DESKTOP_BUILD_GUIDE.md` documentation
- [ ] Add progress indicators and build summaries
- [ ] Add build caching for faster incremental builds
- [ ] Add build validation (check dependencies, tools, signing certs)

##### Quick Start Commands

After implementation, developers can use:

```bash
# Build everything for current platform
mix build.native

# Build all mobile apps
mix build.native --mobile --release

# Build all desktop apps
mix build.native --desktop --release

# Build everything (requires CI or multi-machine setup)
mix build.native --all --release

# Build specific platform
mix build.native -p macos -r

# Clean and rebuild
mix build.native --clean --release

# Parallel build (faster, more resources)
mix build.native --all --parallel --release
```

---

## Technical Details

### Data Flow Diagram

```

┌─────────────────────────────────────────────────────────────────────────┐
│ DESKTOP/MOBILE APP │
│ │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────────┐ │
│ │ LiveView │───►│ Enacl │───►│ Encrypted Payload │ │
│ │ UI │◄───│ Encrypt/ │◄───│ (ready for server) │ │
│ │ │ │ Decrypt │ │ │ │
│ └─────────────┘ └─────────────┘ └──────────────┬──────────────┘ │
│ │ │ │
│ ▼ ▼ │
│ ┌─────────────┐ ┌─────────────────┐ │
│ │ SQLite │ ◄─── Cache encrypted ────────│ API Client │ │
│ │ Cache │ blobs for offline │ (Req) │ │
│ └─────────────┘ └────────┬────────┘ │
│ │ │
└────────────────────────────────────────────────────────┼────────────────┘
│
HTTPS/WSS
│
┌────────────────────────────────────────────────────────┼────────────────┐
│ FLY.IO SERVER │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Phoenix API Endpoints │ │
│ │ /api/auth/login /api/sync/\* /api/posts /api/messages │ │
│ └──────────────────────────────────┬──────────────────────────────┘ │
│ │ │
│ ▼ │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│ │ Cloak Vault │───►│ Postgres │───►│ Encrypted at │ │
│ │ (CLOAK_KEY) │◄───│ (Fly.io) │◄───│ Rest Storage │ │
│ └─────────────────┘ └─────────────────┘ └─────────────────┘ │
│ │
│ Server sees: Cloak layer (can decrypt) + Enacl layer (CANNOT decrypt) │
│ Server stores: Double-encrypted data │
└─────────────────────────────────────────────────────────────────────────┘

```

### Cloak/Cloak Ecto (At-Rest Encryption)

Current setup in `lib/mosslet/vault.ex`:

- `Mosslet.Vault` - AES-256-GCM encryption with `CLOAK_KEY`
- Used for searchable hashes and at-rest encryption in Postgres
- Supports key rotation via `CLOAK_KEY_NEW` and `CLOAK_KEY_RETIRED`

**For Native Apps:**

- `Mosslet.Vault.Native` - AES-256-GCM encryption with `Security.get_or_create_device_key/0`
- Used for searchable hashes (if any) and at-rest encryption of SQLite cache
- Does not require key rotation as per-device keychain storage is used and cache gets resynced from server upon new key

### Server Keys Usage

Based on codebase analysis, server keys (`SERVER_PUBLIC_KEY`, `SERVER_PRIVATE_KEY`) are used for:

- `lib/mosslet/groups/user_group.ex` - Group key fallback encryption
- `lib/mosslet/accounts/connection.ex` - Connection profile encryption
- `lib/mosslet/timeline.ex` - Post reports (admin access)

**Strategy:** These operations happen server-side. Native apps send requests, server handles server-key encryption/decryption.

### Repo Strategy

**Web Platform (unchanged):**

```elixir
defmodule Mosslet.Repo do
  use Fly.Repo, local_repo: Mosslet.Repo.Local
  # Writes go to primary region, reads from replicas
  # transaction_on_primary/1 ensures writes hit primary
end
```

**Native Platform:**

```elixir
# SQLite is for LOCAL CACHE ONLY - not for user data storage!
defmodule Mosslet.Repo.SQLite do
  use Ecto.Repo, otp_app: :mosslet, adapter: Ecto.Adapters.SQLite3
end
```

**Context-Level Platform Routing Pattern:**

```elixir
defmodule Mosslet.Accounts do
  alias Mosslet.{Platform, API.Client, Cache}

  def get_user_by_email_and_password(email, password) do
    if Platform.native?() do
      # Native: Call API, get user + JWT token
      case Client.login(email, password) do
        {:ok, %{user: user_data, token: token}} ->
          # Store token for subsequent requests
          Mosslet.Session.Native.store_token(token)
          # Reconstruct user struct from API response
          deserialize_user(user_data)

        {:error, _} ->
          nil
      end
    else
      # Web: Direct Repo access (existing code)
      user = Repo.get_by(User, email_hash: email)
      if User.valid_password?(user, password), do: user
    end
  end

  def get_user(id) do
    if Platform.native?() do
      # Try cache first for offline support
      case Cache.get_cached_item("user", id) do
        %{encrypted_data: data} when not is_nil(data) ->
          # Return cached if offline
          if Mosslet.Sync.online?() do
            fetch_and_cache_user(id)
          else
            deserialize_cached_user(data)
          end

        nil ->
          fetch_and_cache_user(id)
      end
    else
      Repo.get(User, id)
    end
  end

  defp fetch_and_cache_user(id) do
    token = Mosslet.Session.Native.get_token()

    case Client.me(token) do
      {:ok, %{user: user_data}} ->
        user = deserialize_user(user_data)
        Cache.cache_item("user", id, Jason.encode!(user_data))
        user

      {:error, _} ->
        # Offline fallback
        case Cache.get_cached_item("user", id) do
          %{encrypted_data: data} -> deserialize_cached_user(data)
          nil -> nil
        end
    end
  end
end
```

**Caching Flow:**

```
READ (native):
  Context function called
    ↓
  Platform.native?() == true
    ↓
  Check Cache.get_cached_item()
    ↓
  If online: API.Client.fetch() → Update cache → Return struct
  If offline: Return cached data (may be stale)

WRITE (native):
  Context function called
    ↓
  Platform.native?() == true
    ↓
  If online: API.Client.create/update/delete() → Cache result → Return
  If offline: Cache.queue_for_sync() → Return optimistic result
    ↓
  Mosslet.Sync processes queue when back online
```

---

## Agent Implementation Guide

When implementing Phase 2-4, follow this order:

### Step 2.1: Create SQLite Repo

```bash
# File: lib/mosslet/repo/sqlite.ex
```

Create a minimal SQLite repo for cache tables only. Reference `config/desktop.exs` for configuration.

### Step 2.2: Create Cache Migrations

```bash
# Run: mix ecto.gen.migration create_cache_tables --migrations-path priv/repo_sqlite/migrations
```

Create tables: `cached_items`, `sync_queue`, `local_settings`

### Step 2.3: Create Cache Module

```bash
# File: lib/mosslet/cache.ex
```

Implement functions to store/retrieve encrypted blobs from SQLite.

### Step 3.1: Create API Routes

Add `/api` scope to router with authentication pipeline.

### Step 3.2: Create API Controllers

Start with `AuthController` for login/register, then `SyncController` for data sync.

### Step 3.3: Create API Client

```bash
# File: lib/mosslet/api/client.ex
```

Use `Req` library for HTTP requests. Configure base URL from `Application.get_env(:mosslet, :api_base_url)`.

### Step 4.1: Create Sync GenServer

```bash
# File: lib/mosslet/sync.ex
```

Implement polling sync with exponential backoff for failures.

---

## Questions to Resolve

- [ ] Conflict resolution: Currently planning Last-Write-Wins. Need to decide if user review of conflicts is needed.
- [ ] Cache expiration: How long to keep cached data? Implement LRU eviction?
- [ ] Offline duration: How much data to cache for offline? Last N days? Size limit?
- [ ] API rate limiting: Protect sync endpoints from abuse
- [ ] Pricing strategy: Same price across platforms despite Apple/Google 30% cut?

---

## Resources

- [elixir-desktop GitHub](https://github.com/elixir-desktop/desktop)
- [elixir-desktop example app](https://github.com/elixir-desktop/desktop-example-app)
- [ecto_sqlite3](https://github.com/elixir-sqlite/ecto_sqlite3)
- [Req HTTP Client](https://hexdocs.pm/req)
- [Apple In-App Purchase docs](https://developer.apple.com/in-app-purchase/)
- [Google Play Billing](https://developer.android.com/google/play/billing)

**Desktop-specific:**

- [WKWebView (macOS)](https://developer.apple.com/documentation/webkit/wkwebview)
- [WebView2 (Windows)](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)
- [WebKitGTK (Linux)](https://webkitgtk.org/)
- [Sparkle (macOS auto-update)](https://sparkle-project.org/)
- [NSIS Installer](https://nsis.sourceforge.io/)
- [AppImage](https://appimage.org/)
- [Flatpak](https://flatpak.org/)

---

_Last updated: 2025-01-21 (Phase 9.4 expanded with detailed desktop implementation tasks for macOS, Windows, and Linux. Phase 9.7 added for unified `mix build.native` task. Next step: create desktop wrapper projects and build scripts.)_
