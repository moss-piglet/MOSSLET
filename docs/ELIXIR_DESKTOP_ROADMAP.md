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
- `POST /api/auth/register` - Register new user, returns JWT + encrypted user data

Authenticated (requires Bearer token):

- `POST /api/auth/refresh` - Refresh JWT token
- `POST /api/auth/logout` - Logout (client-side token invalidation)
- `GET /api/auth/me` - Get current user data
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

### Phase 5: Desktop App Setup

- [ ] Configure `Desktop.Endpoint` (conditional on platform)
- [ ] Update `application.ex` supervision tree for desktop mode:

  ```elixir
  def start(_type, _args) do
    children = common_children() ++ platform_children()
    opts = [strategy: :one_for_one, name: Mosslet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp common_children do
    [
      MossletWeb.Telemetry,
      {Phoenix.PubSub, name: Mosslet.PubSub},
      MossletWeb.Endpoint
    ]
  end

  defp platform_children do
    if Mosslet.Platform.native?() do
      [
        Mosslet.Repo.SQLite,      # Local cache only
        Mosslet.Sync,             # Sync with cloud
        Mosslet.Sync.Queue,       # Process pending changes
        Desktop.Window            # Native window
      ]
    else
      [
        Mosslet.Repo.Local,       # Postgres (cloud)
        {Oban, Application.fetch_env!(:mosslet, Oban)},
        # ... other server-side services
      ]
    end
  end
  ```

- [ ] Add `Desktop.Auth` plug for native builds
- [ ] Create `Desktop.Window` configuration
- [ ] Test on macOS, Windows, Linux

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

```elixir
# For web (current)
defmodule Mosslet.Repo do
  use Fly.Repo, local_repo: Mosslet.Repo.Local
  # Writes go to primary, reads from replicas
end

# For desktop/mobile
defmodule Mosslet.Repo.SQLite do
  use Ecto.Repo, otp_app: :mosslet, adapter: Ecto.Adapters.SQLite3
  # LOCAL CACHE ONLY - not for user data!
end

# Desktop data access pattern
defmodule Mosslet.Desktop.Data do
  @moduledoc """
  Data access for desktop apps. Routes through API to cloud.
  """

  def get_posts(user, session_key) do
    # 1. Check cache for offline support
    # 2. Fetch from API if online
    # 3. Decrypt enacl layer locally
    # 4. Return to UI
  end

  def create_post(user, session_key, content) do
    # 1. Encrypt content locally with enacl
    # 2. Queue for sync if offline, or send immediately
    # 3. Server stores (adds Cloak layer)
  end
end
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

_Last updated: 2025-12-17 (Phase 4 completed)_
