# Desktop App Testing Guide

This guide walks you through manually testing the Mosslet desktop app before release.

## Prerequisites

1. **Elixir and Erlang installed** with wxWidgets support

   - On macOS: `brew install wxwidgets` (ensure Erlang was compiled with wx support)
   - On Linux: `sudo apt-get install libwxgtk3.0-gtk3-dev` or equivalent
   - On Windows: wxWidgets included with Erlang installer

2. **Dependencies installed**

   ```bash
   mix deps.get
   ```

3. **Cloud server running** (or use staging)
   - The desktop app connects to `https://mosslet.com/api` for data sync
   - For local testing, update `config/desktop.exs` to point to localhost

## Running the Desktop App

### Quick Start

```bash
# Set environment variable and run
MOSSLET_DESKTOP=true iex -S mix

# If encountering issues with above command try:
MOSSLET_DESKTOP=true mix compile --force && MOSSLET_DESKTOP=true iex -S mix
```

Or create a script:

```bash
#!/bin/bash
export MOSSLET_DESKTOP=true
iex -S mix
```

### What Happens on Launch

1. Platform detection (`Mosslet.Platform.native?()`) returns `true`
2. SQLite cache repo starts (local cache only)
3. Native Cloak vault initializes with device keychain key
4. Sync GenServer starts for background sync
5. Phoenix endpoint starts on random port (`:port 0`)
6. Desktop window opens with embedded WebView

## Test Checklist

### 1. Window Basics

- [ ] **Window opens** with title "Mosslet"
- [ ] **Initial size** is approximately 1200x800 pixels
- [ ] **Minimum size** prevents shrinking below 800x600
- [ ] **Icon** displays in dock/taskbar (uses `priv/static/images/icon.png`)

### 2. Menu Bar (macOS/Linux/Windows)

Test each menu item:

**Mosslet Menu:**

- [ ] "About Mosslet" shows notification with app description
- [ ] "Settings..." navigates to `/app/users/edit-details`
- [ ] "Quit Mosslet" closes the application

**File Menu:**

- [ ] "Home" navigates to `/`
- [ ] "Sync Now" triggers immediate sync (check logs)

**Help Menu:**

- [ ] "Mosslet Support" opens `https://mosslet.com/support` in external browser
- [ ] "Check for Updates..." opens `https://mosslet.com/updates` in external browser

### 3. Authentication Flow

- [ ] **Login page** loads correctly
- [ ] **Login with existing account** works
- [ ] **Registration** creates new account via API
- [ ] **Password input** is secure (not visible)
- [ ] **Auth token** persists across app restarts

### 4. Data Sync

- [ ] **Initial sync** pulls user data on first login
- [ ] **Posts load** from cloud database
- [ ] **Create post** syncs to cloud immediately (or queues if offline)
- [ ] **Edit post** syncs changes
- [ ] **Delete post** syncs deletion
- [ ] **Offline indicator** shows when disconnected

### 5. Offline Mode

To test offline:

1. Log in and let initial sync complete
2. Disconnect network (turn off WiFi/unplug ethernet)
3. Verify:
   - [ ] Previously loaded content still visible
   - [ ] App indicates offline status
   - [ ] Can compose new posts (queued)
   - [ ] Can navigate cached pages
4. Reconnect network
5. Verify:
   - [ ] Queued changes sync automatically
   - [ ] Sync status updates to "synced"

### 6. Desktop Auth Security

- [ ] **Local-only access**: External requests to the random port should fail
- [ ] **Desktop token**: Required for all requests in native mode
- [ ] **No cross-origin access**: Browser cannot connect to desktop app port

### 7. Platform-Specific Testing

#### macOS

- [ ] App runs on Apple Silicon (arm64)
- [ ] App runs on Intel (x86_64)
- [ ] Menu bar integrates with system menu
- [ ] Native notifications work

#### Windows

- [ ] App runs on Windows 10+
- [ ] System tray icon works
- [ ] Native notifications work

#### Linux

- [ ] App runs on common distros (Ubuntu, Fedora)
- [ ] GTK integration works
- [ ] Desktop notifications work

## Debugging

### View Logs

```bash
# Logs output to console when running with iex -S mix
MOSSLET_DESKTOP=true iex -S mix

# In IEx, check sync status
Mosslet.Sync.get_status()
```

### Check Platform Detection

```elixir
Mosslet.Platform.native?()
# => true

Mosslet.Platform.platform_type()
# => :macos, :windows, or :linux
```

### Check Cache Database

```elixir
# SQLite database location
Mosslet.Platform.Config.sqlite_database_path()

# Query cache
Mosslet.Repo.SQLite.all(Mosslet.Cache.CachedItem)
```

### Check Sync Queue

```elixir
# Pending items
Mosslet.Cache.list_pending_sync_items()

# Force sync
Mosslet.Sync.sync_now()
```

## Known Issues / Limitations

1. **wxWidgets dependency**: Must be installed system-wide
2. **Erlang requirement**: Erlang must be compiled with wx support
3. **First run**: Initial sync can take time with large accounts
4. **Offline duration**: Cache size not limited (future: LRU eviction)

## Building for Distribution

### macOS App Bundle

```bash
# Create release
MIX_ENV=prod MOSSLET_DESKTOP=true mix release

# Package as .app (requires additional tooling)
# See elixir-desktop packaging docs
```

### Windows Installer

```bash
# Create release
MIX_ENV=prod MOSSLET_DESKTOP=true mix release

# Package with NSIS or similar
```

### Linux AppImage

```bash
# Create release
MIX_ENV=prod MOSSLET_DESKTOP=true mix release

# Package as AppImage
```

## API Configuration

The desktop app uses these API endpoints (configured in `config/desktop.exs`):

| Endpoint                  | Purpose               |
| ------------------------- | --------------------- |
| `POST /api/auth/login`    | User authentication   |
| `POST /api/auth/register` | New user registration |
| `POST /api/auth/refresh`  | Token refresh         |
| `GET /api/sync/full`      | Full data sync        |
| `GET /api/sync/posts`     | Incremental post sync |
| `POST /api/posts`         | Create post           |
| `PUT /api/posts/:id`      | Update post           |
| `DELETE /api/posts/:id`   | Delete post           |

## Test Report Template

Copy and fill out when testing:

```
Desktop App Test Report
=======================
Date: YYYY-MM-DD
Tester: Name
Platform: macOS/Windows/Linux
OS Version:
Erlang/OTP:
Elixir:

Results:
- [ ] Window opens correctly
- [ ] Menu bar works
- [ ] Login works
- [ ] Data syncs
- [ ] Offline mode works
- [ ] All platform-specific features work

Issues Found:
1.
2.

Notes:

```
