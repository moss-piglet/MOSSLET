# Elixir Desktop Migration Roadmap

## Overview

This document tracks the migration of Mosslet to support native desktop and mobile apps using [elixir-desktop](https://github.com/elixir-desktop/desktop), enabling **true zero-knowledge encryption** where all cryptographic operations happen on the user's device.

### Architecture Goals

| Platform           | Where enacl Runs | Database              | Zero-Knowledge?                    |
| ------------------ | ---------------- | --------------------- | ---------------------------------- |
| **Web**            | Fly.io server    | Postgres (remote)     | No (server sees plaintext briefly) |
| **Native Desktop** | User's device    | SQLite (local) + Sync | **Yes**                            |
| **Native Mobile**  | User's device    | SQLite (local) + Sync | **Yes**                            |

### Key Insight

Same Phoenix/LiveView codebase, different deployment modes. The enacl encryption happens wherever the BEAM runs—on Fly.io for web, on the user's device for native apps.

---

## Encryption Compatibility

### User Keys (Per-User E2E Encryption)

Each user has their own keypair stored in `user.key_pair`:

- `public` - Used by others to encrypt messages TO this user
- `private` - Encrypted with user's password-derived key, used to decrypt

**Cross-Platform Compatibility:** ✅ Works seamlessly

- User signs up on web → keypair generated, stored in Postgres
- User downloads native app → syncs keypair from server
- User enters password → derives key → decrypts private key locally
- All future encryption/decryption happens on device

### Server Keys (Public/Shared Data)

Used for data that needs server access (admin reports, connection profiles, etc.):

- `SERVER_PUBLIC_KEY` - Encrypt data server can access
- `SERVER_PRIVATE_KEY` - Server decrypts when needed

**Cross-Platform Compatibility:** ⚠️ Requires hybrid approach

| Data Type           | Web                 | Native App          | Solution                               |
| ------------------- | ------------------- | ------------------- | -------------------------------------- |
| Private messages    | Server encrypts     | Device encrypts     | User's keypair (compatible)            |
| Connection profiles | Server key          | Server key          | Keep using server key (sync encrypted) |
| Post reports        | Server key          | Server key          | Keep using server key                  |
| Group keys          | Server key fallback | Server key fallback | Keep for compatibility                 |

**Decision:** Data encrypted with server keys stays encrypted with server keys. Native apps sync this encrypted data and let the server handle it when needed (e.g., admin viewing reports).

---

## Web ↔ Native Account Compatibility

### Scenario: User creates account on web, then uses native app

```
1. User signs up on web (mosslet.com)
   └─► Postgres stores: user record, encrypted key_pair, key_hash

2. User downloads native app, enters email + password
   └─► App calls sync API: GET /api/sync/account
   └─► Server returns: encrypted key_pair, key_hash, user data

3. App stores in local SQLite
   └─► User enters password
   └─► App derives key from password (same algorithm)
   └─► App decrypts private key locally
   └─► User can now decrypt all their data!

4. Ongoing sync
   └─► New messages encrypted locally with recipient's public key
   └─► Synced to server as encrypted blobs
   └─► Server CANNOT read (no private keys)
```

### Scenario: User creates account on native app first

```
1. User signs up on native app
   └─► Keypair generated LOCALLY (true zero-knowledge!)
   └─► SQLite stores: user record, encrypted key_pair, key_hash

2. App syncs to server
   └─► POST /api/sync/account
   └─► Server stores encrypted data (cannot decrypt)

3. User later logs in on web
   └─► Server has encrypted private key
   └─► User enters password on web
   └─► Server derives key, decrypts private key
   └─► User can access messages (but server saw plaintext during this session)
```

**Key Point:** Users who ONLY use native apps achieve true zero-knowledge. Users who use web have server-side encryption (still encrypted at rest with Cloak, but server can access during session).

---

## Implementation Phases

### Phase 1: Platform Abstraction Layer

- [ ] Create `Mosslet.Platform` module for runtime detection
- [ ] Create `Mosslet.Platform.Repo` abstraction (Postgres vs SQLite)
- [ ] Create `Mosslet.Platform.Config` for environment-specific settings
- [ ] Add `:desktop` Mix environment/target

### Phase 2: Database Compatibility

- [ ] Add `{:ecto_sqlite3, "~> 0.12"}` dependency
- [ ] Create SQLite-compatible migrations (subset of full schema)
- [ ] Handle Postgres-specific features (jsonb, uuid, citext)
- [ ] Create `Mosslet.Repo.SQLite` module

### Phase 3: Sync API

- [ ] Design sync protocol (conflict resolution, versioning)
- [ ] Create `/api/sync/*` endpoints on server
- [ ] Implement `Mosslet.Sync` module for native apps
- [ ] Handle initial account sync (keypair, user data)
- [ ] Handle incremental data sync (messages, posts, etc.)

### Phase 4: Desktop App Setup

- [ ] Configure `Desktop.Endpoint` (conditional on platform)
- [ ] Add `Desktop.Auth` plug for native builds
- [ ] Create `Desktop.Window` configuration
- [ ] Update `application.ex` supervision tree for desktop mode
- [ ] Test on macOS, Windows, Linux

### Phase 5: Mobile App Setup

- [ ] Create iOS wrapper project (Xcode)
- [ ] Create Android wrapper project (Android Studio)
- [ ] Configure native WebView integration
- [ ] Handle app lifecycle events
- [ ] Test on iOS simulator and Android emulator

### Phase 6: Mobile Billing

- [ ] Create `Mosslet.Billing.Providers.AppleIAP` module
- [ ] Create `Mosslet.Billing.Providers.GooglePlay` module
- [ ] Add receipt validation endpoints
- [ ] Handle subscription sync across platforms
- [ ] Update billing UI for platform-specific flows

### Phase 7: Native Features

- [ ] Push notifications (APNs, FCM)
- [ ] Deep linking / Universal links
- [ ] Background sync
- [ ] Offline mode indicators
- [ ] Native file picker integration

### Phase 8: Packaging & Distribution

- [ ] macOS app signing and notarization
- [ ] Windows installer (NSIS)
- [ ] Linux packages (AppImage, deb, rpm)
- [ ] iOS App Store submission
- [ ] Android Play Store submission
- [ ] CI/CD for multi-platform builds

---

## Technical Details

### Server Keys Usage (Must Stay Server-Side)

Based on codebase analysis, server keys are used for:

```elixir
# lib/mosslet/encrypted/session.ex
def server_public_key, do: System.fetch_env!("SERVER_PUBLIC_KEY")
def server_private_key, do: System.fetch_env!("SERVER_PRIVATE_KEY")
```

Used in:

- `lib/mosslet/groups/user_group.ex` - Group key fallback encryption
- `lib/mosslet/accounts/connection.ex` - Connection profile encryption
- `lib/mosslet/timeline.ex` - Post reports (admin access)

**Strategy:** These stay encrypted with server keys. Native apps sync encrypted blobs; server handles decryption when admin access is needed.

### Cloak/Cloak Ecto (At-Rest Encryption)

Current setup adds a second encryption layer:

- `Mosslet.Vault` - AES-256-GCM encryption with `CLOAK_KEY`
- Used for searchable hashes and at-rest encryption in Postgres

**For Native Apps:**

- Local SQLite doesn't need Cloak (data already E2E encrypted)
- Cloak is a server-side protection layer
- Can optionally add device-level encryption (OS keychain)

### Conditional Endpoint Configuration

```elixir
# lib/mosslet_web/endpoint.ex (future)
defmodule MossletWeb.Endpoint do
  if Mosslet.Platform.native?() do
    use Desktop.Endpoint, otp_app: :mosslet
  else
    use Phoenix.Endpoint, otp_app: :mosslet
  end

  # ... rest of config

  if Mosslet.Platform.native?() do
    plug Desktop.Auth
  end
end
```

### Supervision Tree Changes (Native Mode)

Remove for native:

- `Fly.RPC`
- `Fly.Postgres.LSN.Supervisor`
- `DNSCluster`
- `Oban` (or run locally)
- `FLAME.Pool`

Add for native:

- `Desktop.Window`
- `Mosslet.Sync.Supervisor`

---

## Questions to Resolve

- [ ] Conflict resolution strategy when same data edited on multiple devices?
- [ ] How long to keep data on server for users who only use native apps?
- [ ] Should native-only users have option to NOT sync to server at all?
- [ ] Pricing strategy: same price across platforms despite Apple/Google 30% cut?

---

## Resources

- [elixir-desktop GitHub](https://github.com/elixir-desktop/desktop)
- [elixir-desktop example app](https://github.com/elixir-desktop/desktop-example-app)
- [ecto_sqlite3](https://github.com/elixir-sqlite/ecto_sqlite3)
- [Apple In-App Purchase docs](https://developer.apple.com/in-app-purchase/)
- [Google Play Billing](https://developer.android.com/google/play/billing)

---

_Last updated: 2025_
