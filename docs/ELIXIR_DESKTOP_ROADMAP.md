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

- `lib/mosslet/repo/sqlite.ex` - SQLite Ecto repo
- `lib/mosslet/cache.ex` - Cache operations context
- `lib/mosslet/cache/cached_item.ex` - CachedItem schema
- `lib/mosslet/cache/sync_queue_item.ex` - SyncQueueItem schema
- `lib/mosslet/cache/local_setting.ex` - LocalSetting schema
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

- `lib/mosslet/sync.ex` - Sync GenServer with polling, queue processing, and status broadcasting
- `lib/mosslet/sync/conflict_resolver.ex` - Last-Write-Wins conflict resolution

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

### Phase 5: Context-Level Platform Routing 🚧 IN PROGRESS

**Goal:** Make contexts platform-aware so LiveViews work unchanged on both web and native.

**Architecture Decision:** Instead of wrapping `Mosslet.Repo` with a data gateway layer, we add platform checks at the **context level**. This preserves:

- `Fly.Repo` and `transaction_on_primary` patterns for web (multi-region writes)
- `Ecto.Multi` transaction handling
- All existing Repo usage in contexts

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

**Key Insight:** `Platform.native?()` returns `false` on Fly.io (no `MOSSLET_DESKTOP` env var), so the server always uses Repo directly. The API controllers already call context functions, which hit the real Postgres.

**Implementation Checklist:**

**Context Priority Matrix:**

| Context             | Repo Calls | Priority | Notes                    |
| ------------------- | ---------- | -------- | ------------------------ |
| `accounts.ex`       | 173        | CRITICAL | Auth, users, connections |
| `timeline.ex`       | 236        | HIGH     | Posts, feeds, reactions  |
| `groups.ex`         | 43         | MEDIUM   | Group management         |
| `group_messages.ex` | 15         | MEDIUM   | Group chat               |
| `messages.ex`       | 9          | MEDIUM   | Direct messages          |
| `orgs.ex`           | 25         | LOW      | Organization features    |
| `statuses.ex`       | 9          | LOW      | User statuses            |
| `logs.ex`           | 7          | SKIP     | Audit logs (server-only) |
| `memories.ex`       | 57         | SKIP     | Legacy - phasing out     |
| `conversations.ex`  | 9          | SKIP     | Legacy - phasing out     |

#### 5.1 Authentication & Session (Priority: CRITICAL) - `accounts.ex` - Adapter In progress

The Accounts context now uses a platform adapter pattern:

- `Mosslet.Accounts.Adapter` - Behaviour defining 50+ callbacks for all account operations
- `Mosslet.Accounts.Adapters.Web` - Direct Postgres access via Repo
- `Mosslet.Accounts.Adapters.Native` - API client + SQLite cache

**Implemented callbacks (50+):**

Authentication & Users:

- [x] `get_user_by_email_and_password/2` - Routes to `API.Client.login/2` on native
- [x] `register_user/2` - Routes to `API.Client.register/1` on native
- [x] `get_user!/1` and `get_user/1` - Fetch via API or cache on native
- [x] `get_user_by_email/1`, `get_user_by_username/1`
- [x] `get_user_by_session_token/1`, `generate_user_session_token/1`, `delete_user_session_token/1`
- [x] `get_user_with_preloads/1`, `get_user_from_profile_slug/1`, `get_user_from_profile_slug!/1`
- [x] `confirm_user/1`

User Connections:

- [x] `get_connection/1`, `get_connection!/1`
- [x] `get_user_connection/1`, `get_user_connection!/1`
- [x] `create_user_connection/2`, `update_user_connection/3`, `delete_user_connection/1`
- [x] `confirm_user_connection/3`
- [x] `filter_user_connections/2`, `filter_user_arrivals/2`
- [x] `list_user_connections_for_sync/2`
- [x] `get_all_user_connections/1`, `get_all_confirmed_user_connections/1`
- [x] `search_user_connections/2`
- [x] `has_user_connection?/2`, `has_confirmed_user_connection?/2`, `has_any_user_connections?/1`
- [x] `arrivals_count/1`, `list_user_arrivals_connections/2`
- [x] `delete_both_user_connections/1`
- [x] `get_user_by_username_for_connection/2`, `get_user_by_email_for_connection/2`
- [x] `get_both_user_connections_between_users!/2`
- [x] `get_user_connection_between_users/2`, `get_user_connection_between_users!/2`
- [x] `get_current_user_connection_between_users!/2`
- [x] `get_user_connection_for_user_group/2`, `get_user_connection_for_reply_shared_users/2`
- [x] `get_user_connection_from_shared_item/2`, `get_post_author_permissions_for_viewer/2`
- [x] `validate_users_in_connection/2`
- [x] `update_user_connection_label/3`, `update_user_connection_zen/3`, `update_user_connection_photos/3`
- [x] `preload_connection/1`

User Updates:

- [x] `update_user_profile/3`, `create_user_profile/3`, `delete_user_profile/2`
- [x] `update_user_name/3`, `update_user_username/3`
- [x] `update_user_visibility/3`
- [x] `update_user_password/4`, `reset_user_password/3`
- [x] `update_user_avatar/3`
- [x] `update_user_onboarding/3`, `update_user_onboarding_profile/3`
- [x] `update_user_notifications/3`
- [x] `update_user_tokens/2`
- [x] `update_user_email_notification_received_at/2`, `update_user_reply_notification_received_at/2`
- [x] `update_user_replies_seen_at/2`
- [x] `apply_user_email/4`, `check_if_can_change_user_email/3`, `update_user_email/4`

Blocking:

- [x] `block_user/4`, `unblock_user/2`, `user_blocked?/2`
- [x] `list_blocked_users/1`, `get_user_block/2`

Item Lookups:

- [x] `get_user_from_post/1`, `get_user_from_item/1`, `get_user_from_item!/1`
- [x] `get_connection_from_item/2`
- [x] `get_shared_user_by_username/2`

Admin & Stats:

- [x] `list_all_users/0`, `count_all_users/0`
- [x] `list_all_confirmed_users/0`, `count_all_confirmed_users/0`
- [x] `suspend_user/2`

Email & Password:

- [x] `deliver_user_reset_password_instructions/3`
- [x] `get_user_by_reset_password_token/1`
- [x] `deliver_user_confirmation_instructions/3`
- [x] `deliver_user_update_email_instructions/4`
- [x] `delete_user_account/4`, `delete_user_data/5`

Visibility Groups:

- [x] `create_visibility_group/3`, `update_visibility_group/4`, `delete_visibility_group/2`
- [x] `get_user_visibility_groups_with_connections/1`

TOTP / 2FA:

- [x] `two_factor_auth_enabled?/1`
- [x] `get_user_totp/1`
- [x] `change_user_totp/2`
- [x] `upsert_user_totp/2`
- [x] `regenerate_user_totp_backup_codes/1`
- [x] `delete_user_totp/1`
- [x] `validate_user_totp/2`

**Files created/modified:**

- `lib/mosslet/accounts/adapter.ex` - Behaviour with 50+ callbacks
- `lib/mosslet/accounts/adapters/web.ex` - Web adapter (direct Repo)
- `lib/mosslet/accounts/adapters/native.ex` - Native adapter (API + cache)
- `lib/mosslet/session/native.ex` - JWT token + session key storage (from Phase 3)

#### 5.2 Timeline & Posts (Priority: HIGH) - `timeline.ex`

The Timeline context now uses a platform adapter pattern:

- `Mosslet.Timeline.Adapter` - Behaviour defining 60+ callbacks for all timeline operations
- `Mosslet.Timeline.Adapters.Web` - Direct Postgres access via Repo
- `Mosslet.Timeline.Adapters.Native` - API client + SQLite cache

**Implemented callbacks (60+):**

Post CRUD:

- [x] `get_post/1`, `get_post!/1`, `get_post_with_nested_replies/2`
- [x] `create_post/2`, `create_public_post/2`
- [x] `update_post/3`, `update_public_post/3`
- [x] `delete_post/2`, `delete_group_post/2`

Reply Operations:

- [x] `get_reply/1`, `get_reply!/1`
- [x] `create_reply/2`, `update_reply/3`, `delete_reply/2`
- [x] `get_nested_replies_for_post/2`, `get_child_replies_for_reply/2`
- [x] `list_replies/2`, `list_public_replies/2`

Post Listings:

- [x] `list_posts/2`, `list_user_posts_for_sync/2`
- [x] `list_user_own_posts/2`, `list_connection_posts/2`
- [x] `list_group_posts/2`, `list_discover_posts/2`
- [x] `filter_timeline_posts/2`, `fetch_timeline_posts_from_db/2`

Favorites/Reactions:

- [x] `inc_favs/1`, `decr_favs/1`
- [x] `inc_reply_favs/1`, `decr_reply_favs/1`
- [x] `update_post_fav/3`, `update_reply_fav/3`

Bookmarks:

- [x] `create_bookmark/3`, `update_bookmark/3`, `delete_bookmark/2`
- [x] `get_bookmark/2`, `bookmarked?/2`
- [x] `list_user_bookmarks/2`, `list_user_bookmark_categories/1`
- [x] `create_bookmark_category/2`, `update_bookmark_category/2`, `delete_bookmark_category/1`
- [x] `get_user_bookmark_category/2`

Counts:

- [x] `count_all_posts/0`, `post_count/2`
- [x] `count_user_own_posts/2`, `count_user_group_posts/2`
- [x] `count_user_connection_posts/2`, `count_discover_posts/2`
- [x] `count_unread_posts_for_user/1`, `count_unread_replies_for_user/1`
- [x] `count_replies_for_post/2`, `count_user_bookmarks/2`

Timeline Data:

- [x] `get_timeline_data/3`, `get_timeline_counts/1`
- [x] `get_user_timeline_preference/1`, `update_user_timeline_preference/3`
- [x] `change_user_timeline_preference/3`

User Posts & Sharing:

- [x] `get_user_post_by_post_id_and_user_id/2`, `get_user_post_by_post_id_and_user_id!/2`
- [x] `share_post_with_user/4`, `remove_self_from_shared_post/2`
- [x] `delete_user_post/2`, `get_user_post/2`
- [x] `get_or_create_user_post_for_public/2`
- [x] `create_or_update_user_post_receipt/3`

Reposts & Sharing:

- [x] `inc_reposts/1`
- [x] `create_public_repost/2`, `create_repost/2`
- [x] `create_targeted_share/2`
- [x] `update_post_shared_users/3`, `remove_post_shared_user/3`

Misc:

- [x] `get_blocked_user_ids/1`
- [x] `hide_post/3`, `unhide_post/2`, `post_hidden?/2`
- [x] `report_post/4`
- [x] `mark_top_level_replies_read_for_post/2`, `mark_nested_replies_read_for_parent/2`
- [x] `mark_all_replies_read_for_user/1`
- [x] `preload_group/1`
- [x] `change_post/3`, `change_reply/3`
- [x] `invalidate_timeline_cache_for_user/2`
- [x] `get_expired_ephemeral_posts/1`, `get_user_ephemeral_posts/1`

**Files created/modified:**

- `lib/mosslet/timeline/adapter.ex` - Behaviour with 60+ callbacks
- `lib/mosslet/timeline/adapters/web.ex` - Web adapter (direct Repo)
- `lib/mosslet/timeline/adapters/native.ex` - Native adapter (API + cache)

#### 5.3 Groups - `groups.ex` (Priority: MEDIUM)

- [ ] Group CRUD operations - Route to API
- [ ] Group membership operations - Route to API
- [ ] Group queries - Fetch via API, cache locally

#### 5.4 Group Messages - `group_messages.ex` (Priority: MEDIUM)

- [ ] Group message CRUD - Route to API
- [ ] Group message queries - Fetch via API, cache locally

#### 5.5 Messages - `messages.ex` (Priority: MEDIUM)

- [ ] Direct message CRUD - Route to API

#### 5.6 Organizations - `orgs.ex` (Priority: LOW)

- [ ] Org CRUD operations - Route to API
- [ ] Org membership operations - Route to API

#### 5.7 Statuses - `statuses.ex` (Priority: LOW)

- [ ] Status CRUD - Route to API

#### 5.8 Skipped Contexts

The following contexts are **not** being updated for native platform routing:

- `logs.ex` - Audit logging is server-side only
- `memories.ex` - Legacy feature, being phased out
- `conversations.ex` - Legacy feature, being phased out

#### 5.9 API Endpoints Required

For each context above, corresponding API endpoints need to exist. Current API coverage:

**Existing:**

- Auth: login, register, refresh, logout, me ✅
- Sync: user, posts, connections, groups, full ✅
- Posts: CRUD ✅

**Existing (✅ Complete):**

- Auth: login, register, refresh, logout, me ✅
- Auth TOTP/2FA: status, setup, enable, disable, verify, backup-codes/regenerate ✅
- Auth Remember Me: remember-me/refresh ✅
- Sync: user, posts, connections, groups, full ✅
- Posts: CRUD ✅

**Need to add:**

- [ ] `PUT /api/users/profile` - Update user profile
- [ ] `PUT /api/users/email` - Change email
- [ ] `PUT /api/users/password` - Change password
- [ ] `POST /api/users/reset-password` - Request password reset
- [ ] Connections CRUD endpoints
- [ ] Groups CRUD endpoints
- [ ] Group messages CRUD endpoints
- [ ] Messages CRUD endpoints
- [ ] Statuses CRUD endpoints
- [ ] Orgs CRUD endpoints

#### 5.10 Caching Strategy

- [ ] After successful API reads, cache data in SQLite via `Mosslet.Cache`
- [ ] On API failure (offline), fall back to cached data
- [ ] On writes, queue in `SyncQueueItem` if offline, sync later

**Files to modify:**

- `lib/mosslet/accounts.ex` - Add platform routing to auth functions
- `lib/mosslet/timeline.ex` - Add platform routing to post functions
- `lib/mosslet/api/client.ex` - Add any missing CRUD endpoints
- `lib/mosslet_web/user_auth.ex` - Handle native token auth
- `lib/mosslet/session/native.ex` (new) - Native session/token management

**API Endpoints to add:**

- `PUT /api/users/profile` - Update user profile
- `PUT /api/users/email` - Change email
- `PUT /api/users/password` - Change password
- `POST /api/users/reset-password` - Request password reset
- `PUT /api/connections/:id` - Update connection profile

### Phase 5.5: Desktop Window & Auth Setup ✅ COMPLETE

The desktop-specific infrastructure is already in place:

- [x] `application.ex` supervision tree handles `native_children()` vs `web_children()`
- [x] `MossletWeb.Plugs.DesktopAuth` wraps `Desktop.Auth` for WebView token validation
- [x] `MossletWeb.Desktop.Window` configuration exists
- [x] `config/desktop.exs` configures desktop environment

### Phase 6: Mobile App Setup

- [ ] Create iOS wrapper project (Xcode)
- [ ] Create Android wrapper project (Android Studio)
- [ ] Configure native WebView integration
- [ ] Handle app lifecycle events
- [ ] Test on iOS simulator and Android emulator

### Phase 7: Mobile Billing

- [ ] Create `Mosslet.Billing.Providers.AppleIAP` module
- [ ] Create `Mosslet.Billing.Providers.GooglePlay` module
- [ ] Add receipt validation endpoints
- [ ] Handle subscription sync across platforms
- [ ] Update billing UI for platform-specific flows

### Phase 8: Native Features

- [ ] Push notifications (APNs, FCM)
- [ ] Deep linking / Universal links
- [ ] Background sync
- [ ] Offline mode indicators
- [ ] Native file picker integration

### Phase 9: Packaging & Distribution

- [ ] macOS app signing and notarization
- [ ] Windows installer (NSIS)
- [ ] Linux packages (AppImage, deb, rpm)
- [ ] iOS App Store submission
- [ ] Android Play Store submission
- [ ] CI/CD for multi-platform builds

---

## Technical Details

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           DESKTOP/MOBILE APP                            │
│                                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────┐ │
│  │   LiveView  │───►│   Enacl     │───►│  Encrypted Payload          │ │
│  │     UI      │◄───│ Encrypt/    │◄───│  (ready for server)         │ │
│  │             │    │ Decrypt     │    │                             │ │
│  └─────────────┘    └─────────────┘    └──────────────┬──────────────┘ │
│         │                                              │                │
│         ▼                                              ▼                │
│  ┌─────────────┐                              ┌─────────────────┐      │
│  │   SQLite    │ ◄─── Cache encrypted ────────│  API Client     │      │
│  │   Cache     │      blobs for offline       │  (Req)          │      │
│  └─────────────┘                              └────────┬────────┘      │
│                                                        │                │
└────────────────────────────────────────────────────────┼────────────────┘
                                                         │
                                                    HTTPS/WSS
                                                         │
┌────────────────────────────────────────────────────────┼────────────────┐
│                        FLY.IO SERVER                   │                │
│                                                        ▼                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     Phoenix API Endpoints                        │   │
│  │   /api/auth/login  /api/sync/*  /api/posts  /api/messages       │   │
│  └──────────────────────────────────┬──────────────────────────────┘   │
│                                     │                                   │
│                                     ▼                                   │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    │
│  │   Cloak Vault   │───►│    Postgres     │───►│  Encrypted at   │    │
│  │   (CLOAK_KEY)   │◄───│    (Fly.io)     │◄───│  Rest Storage   │    │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘    │
│                                                                         │
│  Server sees: Cloak layer (can decrypt) + Enacl layer (CANNOT decrypt) │
│  Server stores: Double-encrypted data                                   │
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

---

_Last updated: 2025-01-22 (Phase 5.2 Timeline adapters complete)_
