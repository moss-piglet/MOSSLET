# 🚀 Complete Timeline Implementation Plan

## Performance + Functionality + UI Integration

## 📋 Overview

This plan implements the **complete functional timeline** by:

- ✅ **Connecting Existing Backend** - Your functional timeline logic already exists
- ✅ **Integrating Beautiful Design** - Connect your liquid metal components to real data
- ✅ **Adding Performance Optimizations** - Enhanced with caching and Broadway
- ✅ **Zero Breaking Changes** - All existing data structures remain intact
- ✅ **Production Safety** - Safe migration strategies for live users
- ✅ **Encryption-First Design** - All new features follow existing encryption patterns

**The Problem**: Your timeline template is currently a beautiful design mockup with static data, but your backend is fully functional! We need to connect them.

**The Solution**: Replace the mockup template with real data-driven components while maintaining the exact same beautiful design.

## 🔐 ENCRYPTION COMPLIANCE GUIDELINES

**CRITICAL**: All new features MUST follow your existing encryption patterns to maintain security and consistency.

### Your Current Encryption Pattern:

```elixir
# Searchable fields (use Cloak symmetric encryption + hashing)
field :email, Mosslet.Encrypted.Binary          # Encrypted content
field :email_hash, Mosslet.Encrypted.HMAC       # Searchable hash

# Non-searchable fields (use enacl/libsodium asymmetric encryption)  
field :body, :binary                            # Encrypted with user keys
field :username, :binary                        # Encrypted with user keys
```

### 🔒 DISTRIBUTED DATABASE WRITE PATTERN (CRITICAL):

**⚠️ MANDATORY**: All database writes MUST use `Repo.transaction_on_primary/1` for distributed setup:

```elixir
# ✅ CORRECT - All writes to primary database
case Repo.transaction_on_primary(fn ->
  %MySchema{}
  |> MySchema.changeset(attrs)
  |> Repo.insert()
end) do
  {:ok, {:ok, record}} -> {:ok, record}
  {:ok, {:error, changeset}} -> {:error, changeset}
  error -> error
end

# ❌ INCORRECT - Direct writes may go to read replicas
%MySchema{}
|> MySchema.changeset(attrs)
|> Repo.insert()
```

**Why this matters:**
- ✅ **Write consistency** - Ensures all writes go to primary database
- ✅ **Read replica safety** - Prevents write attempts on read-only replicas
- ✅ **Fly.io distribution** - Works correctly in distributed Fly.io setup
- ✅ **Data integrity** - Prevents split-brain scenarios

**Functions requiring transaction_on_primary:**
- `Repo.insert/1`, `Repo.update/1`, `Repo.delete/1`
- `Repo.insert_all/2`, `Repo.update_all/2`, `Repo.delete_all/1`
- Any function that modifies database state

**Functions that DON'T need it:**
- `Repo.get/2`, `Repo.all/1`, `Repo.one/1` (read operations)
- `Repo.exists?/1`, `Repo.aggregate/3` (read operations)

### 🔑 Post-Context Encryption Strategy (CRITICAL FOR TIMELINE FEATURES):

**⚠️ IMPORTANT**: All timeline-related content uses the existing `post_key` pattern:

1. **Each post has a `post_key`** that encrypts ALL post-related content
2. **Users access via `user_post.key`** (post_key encrypted with user's public key)
3. **Same key encrypts**: `post.body`, `post.username`, `reply.body`, AND new features like `bookmark.notes`
4. **Automatic cleanup**: When post deleted → `user_posts` deleted → related bookmarks cascade delete
5. **Consistent decryption**: If user can decrypt the post, they can decrypt ALL related content

**Benefits:**
- ✅ Consistent encryption across all post-related features
- ✅ Reuse existing key management and decryption flows
- ✅ Automatic access control via existing `user_post` relationships
- ✅ Simplified key lifecycle (one key per post context)
- ✅ Natural data cleanup when posts are deleted

### Encryption Rules for New Timeline Features:

1. **Post-Related Content** → Use existing `post_key` (same as `post.body`)
   - Bookmark notes, reply content, post-specific moderation data
   - Encrypted with the post's existing key via `opts[:post_key]`
   - Automatic access control via `user_post` relationship
   - **Example**: `bookmark.notes` encrypted with same key as `post.body`

2. **User-Specific Searchable Content** → `Mosslet.Encrypted.Binary` + `Mosslet.Encrypted.HMAC`
   - Bookmark category names, content warning types
   - Cloak symmetric encryption + hash for searching
   - User-specific but searchable across their own data

3. **User-Generated Non-Post Content** → `:binary` fields + enacl encryption
   - User status messages, report reasons, block reasons
   - Encrypted with user-specific keys (not post keys)
   - Personal data not tied to specific posts

4. **System Data** → Plaintext (`:string`, `Ecto.Enum`, etc.)
   - Enums (status values, colors, etc.)
   - Foreign keys, timestamps
   - Non-sensitive system flags

### Implementation Pattern:

```elixir
# For Post-Related Content (use existing post_key):
def encrypt_with_post_key(changeset, field, opts) do
  if changeset.valid? && opts[:post_key] do
    content = get_field(changeset, field)
    if content && String.trim(content) != "" do
      # Use the SAME encryption as post.body - same post_key!
      encrypted_content = Mosslet.Encrypted.Utils.encrypt(%{key: opts[:post_key], payload: content})
      put_change(changeset, field, encrypted_content)
    else
      changeset
    end
  else
    changeset
  end
end

# For User-Specific Content (separate user keys):
def encrypt_user_content(changeset, field, user, key) do
  if changeset.valid? && user && key do
    content = get_field(changeset, field)
    if content && String.trim(content) != "" do
      user_key = generate_content_key()
      encrypted_content = Encrypted.Utils.encrypt(%{key: user_key, payload: content})
      put_change(changeset, field, encrypted_content)
    else
      changeset
    end
  else
    changeset
  end
end

# For Searchable Content (Cloak):
def encrypt_searchable_content(changeset, field, hash_field) do
  if changeset.valid? do
    content = get_field(changeset, field)
    if content && String.trim(content) != "" do
      changeset
      |> put_change(field, content)                    # Cloak encrypts automatically
      |> put_change(hash_field, String.downcase(content))  # Hash for searching
    else
      changeset
    end
  else
    changeset
  end
end
```

## 🏗️ STREAMLINED PLAN: Architecture → Performance → UI

You're absolutely right! Let's build the architecture to support all the design features first.

### Phase 1: Core Architecture & New Features (Weeks 1-2) 🔐

**Goal**: Build missing features shown in design mockup with encryption-first approach

### Phase 2: Performance Infrastructure (Week 3)

**Goal**: Add caching and Broadway with proper realtime handling

### Phase 3: Timeline UI Integration (Week 4)

**Goal**: Connect beautiful design to complete backend

**Smart Decision**: Skipping Fly.io-specific optimizations because:

- ✅ **Platform Independence** - Don't over-couple to one platform
- ✅ **Universal Performance** - These improvements help everywhere
- ✅ **Elixir's Natural Scaling** - Phoenix/OTP already handles distribution well
- ✅ **Future Flexibility** - Can optimize for any platform later

This approach gets you:

1. **Complete Feature Set** (Weeks 1-2) - All design mockup features working with full encryption
2. **High Performance** (Week 3) - Caching and concurrent processing
3. **Beautiful Functional UI** (Week 4) - Design connected to robust backend
4. **Platform Flexibility** - Optimized for performance, not vendor lock-in

---

# 🏗️ PHASE 1: CORE ARCHITECTURE (WEEKS 1-2) 🔐

## Implementation Status & Progress Tracking

### ✅ Completed Features:
- [x] **1.1 Bookmarks System** - ✅ **COMPLETE** (2025-09-20) **UPDATED**
  - [x] Database migration created and executed
  - [x] `Bookmark` schema with post_key encryption
  - [x] `BookmarkCategory` schema with Cloak encryption
  - [x] Timeline context functions (create, update, delete, list, count)
  - [x] **transaction_on_primary** implemented for all write operations
  - [x] PubSub broadcasting for real-time updates
  - [x] Encryption using existing post_key strategy
  - [x] Cascade deletion when posts are removed

- [x] **1.2 Content Moderation System** - ✅ **COMPLETE** (2025-09-20)
  - [x] Database migration created and executed (post_reports, user_blocks, post_hides)
  - [x] `PostReport` schema with enacl encryption for sensitive data
  - [x] `UserBlock` schema with user-key encryption
  - [x] `PostHide` schema with user-preference encryption
  - [x] **transaction_on_primary** implemented for all write operations
  - [x] Timeline context functions (report, block, hide, list, check)
  - [x] PubSub broadcasting for real-time moderation updates
  - [x] Admin functions for report management
  - [x] Timeline filtering integration (apply_moderation_filters)
  - [x] Tested and working: hide/unhide posts, block/unblock users

### 🔄 In Progress Features:

### ⏳ Pending Features:
- [ ] **1.3 Content Warnings System** (triangle exclamation button)
  - [ ] Content warning categories
  - [ ] Warning text encryption
  - [ ] UI toggle and display logic
- [ ] **1.4 User Status System**
  - [ ] Status enums (calm, active, busy, away)
  - [ ] Encrypted status messages
  - [ ] Auto-status based on activity
- [ ] **1.5 Enhanced Privacy Controls**
  - [ ] Granular visibility settings
  - [ ] Specific user/group targeting
  - [ ] Post expiration timestamps
- [ ] **1.6 Timeline Navigation System**
  - [ ] Multiple timeline views (Home, Connections, Groups, Bookmarks, Discover)
  - [ ] Tab-specific filtering logic
  - [ ] Real-time post counts per tab

---

## Missing Features Analysis

Based on your design mockup, here's what needs to be built with **encryption-first approach**:

### 1.1 Bookmarks System (Using Existing post_key Architecture) ✅ **COMPLETE**

**Current**: Only `favs_list` (likes) exists
**Needed**: Separate bookmarks system with categories

**🔑 CRITICAL DESIGN DECISION**: Use existing `post_key` encryption strategy for consistency:
- Bookmark notes encrypted with the SAME `post_key` as the associated post
- Reuse existing `user_post.key` lookup mechanism
- Automatic cleanup when post is deleted (cascades through user_posts)
- Same decryption flow as post content

**✅ IMPLEMENTATION COMPLETE** - All functionality working:
- ✅ Database tables created (`bookmarks`, `bookmark_categories`)
- ✅ Schemas implemented with proper encryption
- ✅ Context functions for CRUD operations
- ✅ PubSub broadcasting for real-time updates
- ✅ post_key encryption strategy implemented
- ✅ Ready for UI integration

<details>
<summary>View Implementation Details</summary>

```elixir
# Completed schema: lib/mosslet/timeline/bookmark.ex
defmodule Mosslet.Timeline.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.{Post, BookmarkCategory}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bookmarks" do
    # ENCRYPTED FIELDS (using SAME post_key as associated post)
    field :notes, :binary                        # Encrypted with post_key (same as post.body)
    
    # HASHED FIELDS (searchable - using Cloak since user-specific)
    field :notes_hash, Mosslet.Encrypted.HMAC   # For searching bookmark notes
    
    # FOREIGN KEYS (not encrypted)
    belongs_to :user, User                       # User who bookmarked
    belongs_to :post, Post                       # Post being bookmarked
    belongs_to :category, BookmarkCategory      # Optional categorization

    timestamps()
  end

  def changeset(bookmark, attrs, opts \\ []) do
    bookmark
    |> cast(attrs, [:notes, :user_id, :post_id, :category_id])
    |> validate_required([:user_id, :post_id])
    |> encrypt_notes_with_post_key(opts)  # Use EXISTING post_key!
    |> unique_constraint([:user_id, :post_id], name: :bookmarks_user_post_index)
  end

  # Use the SAME post_key that encrypts post.body
  defp encrypt_notes_with_post_key(changeset, opts) do
    if changeset.valid? && opts[:post_key] do
      notes = get_field(changeset, :notes)
      if notes && String.trim(notes) != "" do
        # Use SAME encryption as Post.body - same key!
        encrypted_notes = Mosslet.Encrypted.Utils.encrypt(%{key: opts[:post_key], payload: notes})

        changeset
        |> put_change(:notes, encrypted_notes)
        |> put_change(:notes_hash, String.downcase(notes))
      else
        changeset
      end
    else
      changeset
    end
  end
end

# New schema: lib/mosslet/timeline/bookmark_category.ex
defmodule Mosslet.Timeline.BookmarkCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.Bookmark

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bookmark_categories" do
    # ENCRYPTED FIELDS (user-specific categories - Cloak encryption)
    field :name, Mosslet.Encrypted.Binary       # Cloak encrypted (user-specific but searchable)
    field :name_hash, Mosslet.Encrypted.HMAC    # For searching categories
    field :description, Mosslet.Encrypted.Binary
    
    # PLAINTEXT FIELDS (system data, not sensitive)
    field :color, Ecto.Enum, values: [:emerald, :blue, :purple, :amber, :rose, :cyan]
    field :icon, :string                         # hero-icon name

    belongs_to :user, User
    has_many :bookmarks, Bookmark

    timestamps()
  end
end

# Context functions (using existing post_key pattern):
# In lib/mosslet/timeline.ex
def create_bookmark(user, post, attrs \\ %{}) do
  # Get post_key using EXISTING mechanism
  post_key = MossletWeb.Helpers.get_post_key(post, user)
  
  %Bookmark{}
  |> Bookmark.changeset(attrs, post_key: post_key)
  |> Ecto.Changeset.put_assoc(:user, user)
  |> Ecto.Changeset.put_assoc(:post, post)
  |> Repo.insert()
end

def decrypt_bookmark_notes(bookmark, user, key) do
  # Use SAME decryption flow as post.body
  post_key = MossletWeb.Helpers.get_post_key(bookmark.post, user)
  
  case Mosslet.Encrypted.Utils.decrypt(%{key: post_key, payload: bookmark.notes}) do
    {:ok, decrypted_notes} -> decrypted_notes
    _ -> "Unable to decrypt"
  end
end
```
</details>

### 1.2 Content Moderation System (Encryption-Compliant) ⏳ **PENDING**

**Current**: Basic visibility controls
**Needed**: Report, hide, and block functionality with three-dots menu

**Features to Implement:**
- [ ] Post reporting with encrypted reasons
- [ ] User blocking system
- [ ] Post hiding functionality  
- [ ] Admin moderation tools

<details>
<summary>View Implementation Plan</summary>

```elixir
# Planned schema: lib/mosslet/timeline/post_report.ex
defmodule Mosslet.Timeline.PostReport do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "post_reports" do
    # ENCRYPTED FIELDS (sensitive user data)
    field :reason, :binary                       # Report reason (enacl encrypted)
    field :details, :binary                      # Additional details (enacl encrypted)
    
    # HASHED FIELDS (for admin searching/filtering)
    field :reason_hash, Mosslet.Encrypted.HMAC  # For categorizing reports
    
    # PLAINTEXT FIELDS (system data)
    field :status, Ecto.Enum, values: [:pending, :reviewed, :resolved, :dismissed]
    field :severity, Ecto.Enum, values: [:low, :medium, :high, :critical]
    
    belongs_to :reporter, User                   # User who reported
    belongs_to :reported_user, User             # User being reported  
    belongs_to :post, Post                      # Post being reported

    timestamps()
  end
end

# New schema: lib/mosslet/accounts/user_block.ex
defmodule Mosslet.Accounts.UserBlock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_blocks" do
    # ENCRYPTED FIELDS (sensitive)
    field :reason, :binary                       # Why they blocked (enacl encrypted)
    
    # FOREIGN KEYS (not encrypted)
    belongs_to :blocker, User                    # User doing the blocking
    belongs_to :blocked, User                    # User being blocked

    timestamps()
  end
end

# New schema: lib/mosslet/timeline/post_hide.ex  
defmodule Mosslet.Timeline.PostHide do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "post_hides" do
    # ENCRYPTED FIELDS (user preference data)
    field :reason, :binary                       # Why they hid it (enacl encrypted)
    
    # FOREIGN KEYS
    belongs_to :user, User
    belongs_to :post, Post

    timestamps()
  end
end
```
</details>

### 1.3 Content Warnings System (Encryption-Compliant) ⏳ **PENDING**

**Current**: Basic post content
**Needed**: Content warning toggle (triangle exclamation button)

**Features to Implement:**
- [ ] Content warning categories (mental health, politics, etc.)
- [ ] Custom warning text encryption
- [ ] UI toggle in composer
- [ ] Warning display logic in timeline

<details>
<summary>View Implementation Plan</summary>

```elixir
# Planned additions to existing Post schema: lib/mosslet/timeline/post.ex
defmodule Mosslet.Timeline.Post do
  # ... existing fields ...

  # NEW CONTENT WARNING FIELDS
  # ENCRYPTED FIELDS (user-generated content)
  field :content_warning_text, :binary          # Custom warning text (enacl encrypted)
  
  # SEARCHABLE FIELDS (for filtering/searching)
  field :content_warning_category, Mosslet.Encrypted.Binary  # "mental_health", etc (Cloak encrypted)
  field :content_warning_hash, Mosslet.Encrypted.HMAC       # For searching by warning type
  
  # PLAINTEXT FIELDS (system flags)
  field :has_content_warning, :boolean, default: false      # Quick filter flag

  # ... rest of schema ...
end
```

    timestamps()
  end

  def changeset(bookmark, attrs, opts \\ []) do
    bookmark
    |> cast(attrs, [:notes, :user_id, :post_id, :category_id])
    |> validate_required([:user_id, :post_id])
    |> encrypt_notes(opts)
    |> unique_constraint([:user_id, :post_id], name: :bookmarks_user_post_index)
  end

  defp encrypt_notes(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      notes = get_field(changeset, :notes)
      if notes && String.trim(notes) != "" do
        key = Mosslet.Encrypted.Utils.generate_key()
        encrypted_notes = Mosslet.Encrypted.Utils.encrypt(%{key: key, payload: notes})

        changeset
        |> put_change(:notes, encrypted_notes)
        |> put_change(:notes_hash, String.downcase(notes))
      else
        changeset
      end
    else
      changeset
    end
  end
end

# New schema: lib/mosslet/timeline/bookmark_category.ex
defmodule Mosslet.Timeline.BookmarkCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.Bookmark

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bookmark_categories" do
    field :name, Mosslet.Encrypted.Binary
    field :name_hash, Mosslet.Encrypted.HMAC
    field :color, Ecto.Enum, values: [:emerald, :blue, :purple, :amber, :rose, :cyan]
    field :icon, :string  # hero-icon name
    field :description, Mosslet.Encrypted.Binary

    belongs_to :user, User
    has_many :bookmarks, Bookmark

    timestamps()
  end
end
```

### 1.2 Timeline Navigation System

**Current**: Single timeline view
**Needed**: Multiple timeline views (Home, Connections, Groups, Bookmarks, Discover)

```elixir
# New context: lib/mosslet/timeline/navigation.ex
defmodule Mosslet.Timeline.Navigation do
  @moduledoc """
  Handles different timeline views and filtering.
  """

  alias Mosslet.Timeline
  alias Mosslet.Accounts
  alias Mosslet.Groups

  def get_timeline_data(user, tab, options \\ %{}) do
    case tab do
      "home" -> get_home_timeline(user, options)
      "connections" -> get_connections_timeline(user, options)
      "groups" -> get_groups_timeline(user, options)
      "bookmarks" -> get_bookmarks_timeline(user, options)
      "discover" -> get_discover_timeline(user, options)
      _ -> get_home_timeline(user, options)
    end
  end

  def get_timeline_counts(user) do
    %{
      home: Timeline.timeline_post_count(user, %{}),
      connections: Timeline.connections_post_count(user),
      groups: Groups.user_groups_post_count(user),
      bookmarks: count_user_bookmarks(user),
      discover: 0  # Always fresh
    }
  end

  defp get_home_timeline(user, options) do
    # Your existing timeline logic - all posts user has access to
    Timeline.filter_timeline_posts(user, options)
  end

  defp get_connections_timeline(user, options) do
    # Only posts from direct connections
    Timeline.filter_connections_posts(user, options)
  end

  defp get_groups_timeline(user, options) do
    # Only posts from groups user belongs to
    Groups.filter_user_groups_posts(user, options)
  end

  defp get_bookmarks_timeline(user, options) do
    # User's bookmarked posts
    get_user_bookmarked_posts(user, options)
  end

  defp get_discover_timeline(user, options) do
    # Public posts, trending content, suggested connections
    Timeline.filter_discover_posts(user, options)
  end
end
```

### 1.3 User Status System

**Current**: Basic user model
**Needed**: Status indicators ("calm", "mindfully connected", etc.)

```elixir
# Add to existing User schema: lib/mosslet/accounts/user.ex
schema "users" do
  # ... existing fields ...

  # NEW - Status system
  field :status, Ecto.Enum,
    values: [:offline, :calm, :active, :busy, :away],
    default: :offline
  field :status_message, Mosslet.Encrypted.Binary
  field :status_updated_at, :naive_datetime
  field :auto_status, :boolean, default: true  # Auto-set based on activity

  # ... rest of schema ...
end

# New context: lib/mosslet/accounts/status.ex
defmodule Mosslet.Accounts.Status do
  @moduledoc """
  Handles user status and presence.
  """

  def update_user_status(user, status, message \\ nil) do
    attrs = %{
      status: status,
      status_updated_at: NaiveDateTime.utc_now()
    }

    attrs = if message do
      Map.put(attrs, :status_message, message)
    else
      attrs
    end

    Accounts.update_user(user, attrs)
  end

  def auto_update_status_from_activity(user) do
    if user.auto_status do
      last_activity = get_last_activity_time(user)
      new_status = determine_status_from_activity(last_activity)

      if new_status != user.status do
        update_user_status(user, new_status)
      end
    end
  end

  defp determine_status_from_activity(last_activity) do
    minutes_ago = NaiveDateTime.diff(NaiveDateTime.utc_now(), last_activity, :second) / 60

    cond do
      minutes_ago < 5 -> :active
      minutes_ago < 30 -> :calm  # Recently active but not actively posting
      minutes_ago < 120 -> :away
      true -> :offline
    end
  end
end
```

### 1.4 Enhanced Privacy Controls

**Current**: Basic visibility (public, private, connections)
**Needed**: More granular controls and UI

```elixir
# Add to Post schema: lib/mosslet/timeline/post.ex
schema "posts" do
  # ... existing fields ...

  # ENHANCED privacy controls
  field :visibility, Ecto.Enum,
    values: [:public, :private, :connections, :groups, :specific_users],
    default: :private
  field :visibility_groups, {:array, :binary_id}, default: []  # Specific groups
  field :visibility_users, {:array, :binary_id}, default: []   # Specific users
  field :allow_replies, :boolean, default: true
  field :allow_shares, :boolean, default: true
  field :expires_at, :naive_datetime  # Optional post expiration

  # ... rest of schema ...
end
```

## 🗄️ Database Migrations

```elixir
# priv/repo/migrations/add_bookmarks_system.exs
defmodule Mosslet.Repo.Migrations.AddBookmarksSystem do
  use Ecto.Migration

  def change do
    create table(:bookmark_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :binary
      add :name_hash, :binary
      add :color, :string
      add :icon, :string
      add :description, :binary
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create table(:bookmarks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :notes, :binary
      add :notes_hash, :binary
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :category_id, references(:bookmark_categories, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:bookmarks, [:user_id, :post_id], name: :bookmarks_user_post_index)
    create index(:bookmarks, [:user_id, :category_id])
    create index(:bookmark_categories, [:user_id])
  end
end

# priv/repo/migrations/add_user_status_system.exs
defmodule Mosslet.Repo.Migrations.AddUserStatusSystem do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :status, :string, default: "offline"
      add :status_message, :binary
      add :status_updated_at, :naive_datetime
      add :auto_status, :boolean, default: true
    end

    create index(:users, [:status])
    create index(:users, [:status_updated_at])
  end
end

# priv/repo/migrations/enhance_post_privacy.exs
defmodule Mosslet.Repo.Migrations.EnhancePostPrivacy do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :visibility_groups, {:array, :binary_id}, default: []
      add :visibility_users, {:array, :binary_id}, default: []
      add :allow_replies, :boolean, default: true
      add :allow_shares, :boolean, default: true
      add :expires_at, :naive_datetime
    end

    create index(:posts, [:expires_at])
    create index(:posts, [:visibility, :inserted_at])
  end
end
```

## ⚠️ CRITICAL: Cache Invalidation Strategy

**The Problem**: Caching can interfere with realtime PubSub updates if not handled correctly.

**The Solution**: Cache invalidation tied to PubSub events.

```elixir
# lib/mosslet/timeline/performance/realtime_cache.ex
defmodule Mosslet.Timeline.Performance.RealtimeCache do
  @moduledoc """
  Cache system that maintains realtime consistency with PubSub events.

  Strategy:
  1. Cache encrypted data for performance
  2. Listen to PubSub events for realtime updates
  3. Immediately invalidate cache when data changes
  4. LiveView gets fresh data instantly
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Subscribe to ALL timeline PubSub events
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "posts")
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "priv_posts:*")
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "conn_posts:*")
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "replies")

    {:ok, %{}}
  end

  # Handle post creation - invalidate relevant caches immediately
  def handle_info({:post_created, post}, state) do
    Logger.debug("Invalidating cache for new post: #{post.id}")

    # Invalidate timeline caches for all affected users
    invalidate_timeline_caches_for_post(post)

    # Broadcast cache invalidation to distributed nodes
    broadcast_cache_invalidation(:post_created, post.id)

    {:noreply, state}
  end

  # Handle post updates - invalidate specific post cache
  def handle_info({:post_updated, post}, state) do
    Logger.debug("Invalidating cache for updated post: #{post.id}")

    # Invalidate specific post cache
    Mosslet.Timeline.Performance.Cache.invalidate_post(post.id)

    # Invalidate user timeline caches
    invalidate_user_timeline_cache(post.user_id)

    broadcast_cache_invalidation(:post_updated, post.id)

    {:noreply, state}
  end

  # Handle post deletion - immediate invalidation
  def handle_info({:post_deleted, post}, state) do
    Logger.debug("Invalidating cache for deleted post: #{post.id}")

    # Remove from all caches immediately
    Mosslet.Timeline.Performance.Cache.invalidate_post(post.id)
    invalidate_timeline_caches_for_post(post)

    broadcast_cache_invalidation(:post_deleted, post.id)

    {:noreply, state}
  end

  # Handle likes/favs - immediate invalidation
  def handle_info({:post_updated_fav, post}, state) do
    # Invalidate post cache so new like count shows immediately
    Mosslet.Timeline.Performance.Cache.invalidate_post(post.id)

    broadcast_cache_invalidation(:post_fav_updated, post.id)

    {:noreply, state}
  end

  # PRIVATE functions

  defp invalidate_timeline_caches_for_post(post) do
    case post.visibility do
      :public ->
        # Invalidate public timeline cache
        Cachex.del(:mosslet_timeline_cache, "timeline:public")

      :private ->
        # Only invalidate the user's own timeline
        invalidate_user_timeline_cache(post.user_id)

      :connections ->
        # Invalidate timeline cache for all connected users
        connected_user_ids = get_connected_user_ids(post.user_id)
        Enum.each(connected_user_ids, &invalidate_user_timeline_cache/1)
    end
  end

  defp invalidate_user_timeline_cache(user_id) do
    Cachex.del(:mosslet_timeline_cache, "timeline:user:#{user_id}")
  end

  defp get_connected_user_ids(user_id) do
    # Get list of users connected to this user
    Mosslet.Accounts.get_confirmed_user_connections(user_id)
    |> Enum.map(& &1.reverse_user_id)
  end

  defp broadcast_cache_invalidation(event, post_id) do
    # Broadcast to other nodes in distributed setup
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "cache_invalidation",
      {event, post_id, System.system_time(:millisecond)}
    )
  end
end
```

**How It Works:**

1. **Cache Normal Reads** - Fast encrypted data retrieval
2. **Listen to PubSub** - Every cache invalidation service listens to timeline events
3. **Immediate Invalidation** - When post created/updated/deleted, cache invalidated instantly
4. **LiveView Gets Fresh Data** - Next request pulls fresh data from DB
5. **Zero Lag** - Users see updates in realtime, cache doesn't interfere

**Example Flow:**

```
1. User A creates post → PubSub broadcasts :post_created
2. Cache service hears event → Invalidates relevant timeline caches
3. User B's LiveView gets PubSub event → Requests fresh timeline
4. Cache miss → Fresh data from DB → User B sees new post immediately
5. Fresh data gets cached for next request
```

**Current Flow (DO NOT CHANGE):**

```
User Data → Asymmetric Encryption (User Keys) → Symmetric Encryption (Server Keys) → Database
          ↓
     Deterministic Hashes for Searchable Fields (email_hash, username_hash, etc.)
```

**Performance Improvements (NON-BREAKING):**

- ✅ **Encrypted Caching Layer** - Cache encrypted data + metadata (avoid repeated DB queries)
- ✅ **Fast Decryption** - Leverage enacl/libsodium speed for on-demand decryption
- ✅ **Batch Operations** - Fetch multiple encrypted items, decrypt concurrently
- ✅ **Smart Invalidation** - Cache invalidation on data updates
- ✅ **Progressive Loading** - Load encrypted thumbnails first, decrypt on-demand

---

# 🎨 PHASE 0: FUNCTIONAL TIMELINE (WEEK 1)

## Current State Analysis

**✅ What You Have:**

- Complete functional backend in `TimelineLive.Index`
- Beautiful liquid metal design system components
- Full encryption/decryption pipeline working
- PubSub realtime updates working
- Post creation, editing, deletion working

**❌ What's Missing:**

- Template is static mockup instead of real data
- Design components not connected to backend
- No real post display from database
- No functional composer connected to backend

## 🔧 Phase 0 Implementation

### 0.1 Replace Static Template with Functional Components

**File**: `lib/mosslet_web/live/timeline_live/index.html.heex`

```heex
<.layout current_page={:timeline} current_user={@current_user} key={@key} type="sidebar">
  <%!-- Functional Timeline Implementation --%>

  <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-teal-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">

    <%!-- Timeline header with real user data --%>
    <div class="relative px-4 sm:px-6 lg:px-8 pt-8 pb-6">
      <div class="mx-auto max-w-2xl text-center">
        <MossletWeb.DesignSystem.liquid_timeline_header
          user_name={@current_user.username || "User"}
          status="calm"
          status_message="Mindfully connected"
        />
      </div>
    </div>

    <MossletWeb.DesignSystem.liquid_container max_width="lg" class="space-y-4">

      <%!-- Realtime indicator (show when new posts available) --%>
      <MossletWeb.DesignSystem.liquid_timeline_realtime_indicator
        :if={assigns[:new_posts_count] && @new_posts_count > 0}
        new_posts_count={@new_posts_count}
        phx-click="load_new_posts"
      />

      <%!-- Timeline navigation tabs --%>
      <div class="bg-white/60 dark:bg-slate-800/60 backdrop-blur-md rounded-2xl border border-slate-200/40 dark:border-slate-700/40 shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 p-2">
        <MossletWeb.DesignSystem.liquid_timeline_tabs
          tabs={[
            %{key: "home", label: "Home", count: @post_count || 0},
            %{key: "connections", label: "Connections", count: 0},
            %{key: "groups", label: "Groups", count: 0},
            %{key: "bookmarks", label: "Bookmarks", count: 0},
            %{key: "discover", label: "Discover"}
          ]}
          active_tab="home"
        />
      </div>

      <%!-- FUNCTIONAL COMPOSER - Connected to real backend --%>
      <div class="relative">
        <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/10 via-teal-500/5 to-emerald-500/10 rounded-2xl blur-xl"></div>

        <%!-- Real functional form --%>
        <.form
          for={@post_form}
          id="timeline-post-form"
          phx-submit="save_post"
          phx-change="validate_post"
          class="relative"
        >
          <MossletWeb.DesignSystem.liquid_timeline_composer_enhanced
            user_name={@current_user.username || "User"}
            user_avatar={@current_user.avatar_url}
            placeholder="Share something meaningful with your community..."
            character_limit={500}
            privacy_level={@selector || "private"}
            class="relative"
          />

          <%!-- Hidden form fields for real data --%>
          <.input type="hidden" field={@post_form[:user_id]} value={@current_user.id} />
          <.input type="hidden" field={@post_form[:visibility]} value={@selector || "private"} />

          <%!-- Textarea for post content (styled to match design) --%>
          <div class="mt-4">
            <.input
              field={@post_form[:body]}
              type="textarea"
              placeholder="What's on your mind?"
              rows="3"
              class="w-full resize-none border-0 bg-transparent text-slate-900 dark:text-slate-100 placeholder:text-slate-500 dark:placeholder:text-slate-400 text-lg leading-relaxed focus:outline-none focus:ring-0"
            />

            <%!-- Error display --%>
            <.error :for={msg <- Enum.map(@post_form[:body].errors, &translate_error/1)}>
              {msg}
            </.error>
          </div>

          <%!-- Form actions row --%>
          <div class="flex items-center justify-between pt-4 border-t border-slate-200/50 dark:border-slate-700/50">
            <div class="flex items-center gap-2">
              <%!-- Media upload buttons (design preserved) --%>
              <button type="button" class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group">
                <.icon name="hero-photo" class="h-5 w-5 transition-transform duration-200 group-hover:scale-110" />
              </button>
              <button type="button" class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group">
                <.icon name="hero-face-smile" class="h-5 w-5 transition-transform duration-200 group-hover:scale-110" />
              </button>
            </div>

            <div class="flex items-center gap-3">
              <%!-- Privacy selector --%>
              <select
                name="selector"
                phx-change="set_visibility"
                class="px-3 py-1.5 rounded-full text-sm bg-slate-100/80 dark:bg-slate-700/80 backdrop-blur-sm border border-slate-200/60 dark:border-slate-600/60 text-slate-700 dark:text-slate-200"
              >
                <option value="private" selected={@selector == "private"}>Private</option>
                <option value="connections" selected={@selector == "connections"}>Connections</option>
                <option value="public" selected={@selector == "public"}>Public</option>
              </select>

              <%!-- Submit button --%>
              <.button
                type="submit"
                disabled={!@post_form.source.valid? || @uploads_in_progress}
                class="flex-shrink-0 inline-flex items-center justify-center gap-2 px-6 py-3 text-sm font-semibold rounded-xl bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg hover:scale-105 hover:shadow-xl hover:shadow-emerald-500/25 transition-all duration-200 ease-out disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
              >
                {if @uploads_in_progress, do: "Posting...", else: "Share thoughtfully"}
              </.button>
            </div>
          </div>
        </.form>
      </div>

      <%!-- REAL POSTS STREAM - Connected to database --%>
      <div id="timeline-posts" phx-update="stream" class="space-y-4">
        <div
          :for={{id, post} <- @streams.posts}
          id={id}
          class="group relative transition-all duration-300 ease-out"
        >
          <%!-- Decrypt post data for display --%>
          <%
            decrypted_post = decrypt_post_for_display(post, @current_user, @key)
            user = get_post_user(post)
          %>

          <%!-- Real post card with actual data --%>
          <MossletWeb.DesignSystem.liquid_timeline_post
            user_name={decrypted_post.username}
            user_handle={"@#{decrypted_post.username}"}
            user_avatar={decrypted_post.avatar_url}
            timestamp={relative_time(post.inserted_at)}
            content={decrypted_post.body}
            images={decrypt_image_urls(post.image_urls, @current_user, @key)}
            stats={%{
              replies: length(post.replies || []),
              shares: post.reposts_count || 0,
              likes: post.favs_count || 0
            }}
            verified={user && user.confirmed_at != nil}
            class="shadow-xl shadow-slate-900/8 dark:shadow-slate-900/25 hover:shadow-2xl hover:shadow-slate-900/12 dark:hover:shadow-slate-900/35"

            <%!-- Real action handlers --%>
            post_id={post.id}
            phx-click-like="fav"
            phx-click-unlike="unfav"
            phx-click-reply="reply"
            phx-click-share="repost"
            phx-click-edit="edit_post"
            phx-click-delete="delete_post"
            current_user_id={@current_user.id}
            user_has_liked={@current_user.id in (post.favs_list || [])}
            user_has_shared={@current_user.id in (post.reposts_list || [])}
          />
        </div>
      </div>

      <%!-- Real infinite scroll with actual remaining count --%>
      <MossletWeb.DesignSystem.liquid_timeline_scroll_indicator
        :if={has_more_posts?(@streams.posts, @post_count)}
        remaining_count={calculate_remaining_posts(@streams.posts, @post_count)}
        load_count={10}
        loading={assigns[:loading_more] || false}
        phx-click="load_more_posts"
      />

      <%!-- End of feed message --%>
      <div :if={!has_more_posts?(@streams.posts, @post_count)} class="text-center py-12">
        <div class="inline-flex flex-col items-center gap-4 px-8 py-6 rounded-2xl bg-gradient-to-br from-emerald-50/40 via-teal-50/30 to-cyan-50/40 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-cyan-900/10 border border-emerald-200/40 dark:border-emerald-700/30">
          <.icon name="hero-heart" class="h-8 w-8 text-emerald-500" />
          <div class="text-center">
            <p class="text-sm font-medium text-emerald-700 dark:text-emerald-300 mb-1">
              You're all caught up!
            </p>
            <p class="text-xs text-slate-600 dark:text-slate-400 max-w-xs">
              Time to step away and enjoy the real world. Your community will be here when you return.
            </p>
          </div>
        </div>
      </div>

    </MossletWeb.DesignSystem.liquid_container>
  </div>
</.layout>
```

### 0.2 Add Helper Functions to LiveView

**File**: `lib/mosslet_web/live/timeline_live/index.ex` (ADD TO EXISTING)

```elixir
# Add these helper functions to your existing LiveView

# Add to mount function
def mount(_params, _session, socket) do
  # ... existing code ...

  socket =
    socket
    |> assign(:post_form, to_form(changeset))
    # ... existing assigns ...

    # NEW - Add these assigns for functional timeline
    |> assign(:new_posts_count, 0)
    |> assign(:loading_more, false)
    |> assign(:selector, "private")  # Default privacy level
    |> stream(:posts, [])

  {:ok, assign(socket, page_title: "Timeline")}
end

# Add new event handlers for form functionality
def handle_event("set_visibility", %{"selector" => visibility}, socket) do
  socket = assign(socket, :selector, visibility)
  {:noreply, socket}
end

def handle_event("load_more_posts", _params, socket) do
  if !socket.assigns.loading_more do
    socket = assign(socket, :loading_more, true)

    # Use your existing pagination logic
    current_posts_count = length(socket.assigns.streams.posts)
    options = %{
      post_page: div(current_posts_count, @post_per_page_default) + 1,
      post_per_page: @post_per_page_default,
      filter: socket.assigns.filter,
      current_user_id: socket.assigns.current_user.id
    }

    new_posts = Timeline.filter_timeline_posts(socket.assigns.current_user, options)

    socket =
      socket
      |> assign(:loading_more, false)
      |> stream(:posts, new_posts)

    {:noreply, socket}
  else
    {:noreply, socket}
  end
end

def handle_event("load_new_posts", _params, socket) do
  # Reload timeline to show new posts
  {:noreply, push_patch(socket, to: socket.assigns.return_url)}
end

# Helper functions for template
defp decrypt_post_for_display(post, current_user, key) do
  # Use your existing decryption logic
  user_post = Timeline.get_user_post(post, current_user)
  post_key = if user_post && user_post.key do
    case Encrypted.Users.Utils.decrypt_user_attrs_key(user_post.key, current_user, key) do
      {:ok, decrypted_key} -> decrypted_key
      _ -> nil
    end
  end

  if post_key do
    %{
      username: decrypt_field(post.username, post_key),
      body: decrypt_field(post.body, post_key),
      avatar_url: decrypt_field(post.avatar_url, post_key)
    }
  else
    %{username: "Loading...", body: "Loading...", avatar_url: nil}
  end
end

defp get_post_user(post) do
  # Get user from preloaded association or fetch
  post.user || Accounts.get_user(post.user_id)
end

defp decrypt_field(nil, _key), do: nil
defp decrypt_field(encrypted_field, key) do
  case Encrypted.Utils.decrypt(%{key: key, payload: encrypted_field}) do
    {:ok, decrypted} -> decrypted
    _ -> "Error decrypting"
  end
end

defp decrypt_image_urls(nil, _user, _key), do: []
defp decrypt_image_urls([], _user, _key), do: []
defp decrypt_image_urls(encrypted_urls, user, key) when is_list(encrypted_urls) do
  # Use your existing image decryption logic
  encrypted_urls
  |> Enum.map(fn encrypted_url ->
    # Your existing image URL decryption logic here
    case decrypt_image_url(encrypted_url, user, key) do
      {:ok, url} -> url
      _ -> nil
    end
  end)
  |> Enum.filter(&(!is_nil(&1)))
end

defp has_more_posts?(posts_stream, total_count) do
  current_count = length(posts_stream)
  current_count < total_count
end

defp calculate_remaining_posts(posts_stream, total_count) do
  total_count - length(posts_stream)
end

defp relative_time(datetime) do
  # Simple relative time formatting
  now = NaiveDateTime.utc_now()
  diff = NaiveDateTime.diff(now, datetime, :second)

  cond do
    diff < 60 -> "#{diff}s ago"
    diff < 3600 -> "#{div(diff, 60)}m ago"
    diff < 86400 -> "#{div(diff, 3600)}h ago"
    true -> "#{div(diff, 86400)}d ago"
  end
end
```

### 0.3 Enhance Design System Components for Real Data

**File**: `lib/mosslet_web/components/design_system.ex` (UPDATE EXISTING COMPONENTS)

```elixir
# Update the liquid_timeline_post component to handle real actions

def liquid_timeline_post(assigns) do
  assigns = assign_new(assigns, :post_id, fn -> nil end)
  assigns = assign_new(assigns, :current_user_id, fn -> nil end)
  assigns = assign_new(assigns, :user_has_liked, fn -> false end)
  assigns = assign_new(assigns, :user_has_shared, fn -> false end)

  ~H"""
  <article class={[
    "group relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
    "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
    "border border-slate-200/60 dark:border-slate-700/60",
    "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
    "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
    "hover:border-slate-300/60 dark:hover:border-slate-600/60",
    "transform-gpu will-change-transform",
    @class
  ]}>
    <%!-- Background effects... (existing design) --%>

    <div class="relative p-6">
      <%!-- User header... (existing design) --%>

      <%!-- Post content... (existing design) --%>

      <%!-- Images... (existing design) --%>

      <%!-- REAL ACTION BUTTONS --%>
      <div class="flex items-center justify-between pt-3 border-t border-slate-200/50 dark:border-slate-700/50">
        <div class="flex items-center gap-1">
          <%!-- Reply button --%>
          <button
            :if={@post_id}
            phx-click={@"phx-click-reply"}
            phx-value-id={@post_id}
            class="group/action relative flex items-center gap-2 px-3 py-2 rounded-xl transition-all duration-200 ease-out active:scale-95 focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2 text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400"
          >
            <.phx_icon name="hero-chat-bubble-oval-left" class="relative h-4 w-4 transition-transform duration-200 ease-out group-hover/action:scale-110" />
            <span :if={@stats.replies > 0} class="relative text-sm font-medium">{@stats.replies}</span>
          </button>

          <%!-- Share/Repost button --%>
          <button
            :if={@post_id}
            phx-click={@"phx-click-share"}
            phx-value-id={@post_id}
            class={[
              "group/action relative flex items-center gap-2 px-3 py-2 rounded-xl transition-all duration-200 ease-out active:scale-95 focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
              if(@user_has_shared, do: "text-emerald-600 dark:text-emerald-400", else: "text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400")
            ]}
          >
            <.phx_icon name="hero-arrow-path" class="relative h-4 w-4 transition-transform duration-200 ease-out group-hover/action:scale-110" />
            <span :if={@stats.shares > 0} class="relative text-sm font-medium">{@stats.shares}</span>
          </button>

          <%!-- Like button --%>
          <button
            :if={@post_id}
            phx-click={if(@user_has_liked, do: @"phx-click-unlike", else: @"phx-click-like")}
            phx-value-id={@post_id}
            class={[
              "group/action relative flex items-center gap-2 px-3 py-2 rounded-xl transition-all duration-200 ease-out active:scale-95 focus:outline-none focus:ring-2 focus:ring-rose-500/50 focus:ring-offset-2",
              if(@user_has_liked, do: "text-rose-600 dark:text-rose-400", else: "text-slate-400 hover:text-rose-600 dark:hover:text-rose-400")
            ]}
          >
            <.phx_icon
              name={if(@user_has_liked, do: "hero-heart-solid", else: "hero-heart")}
              class="relative h-4 w-4 transition-transform duration-200 ease-out group-hover/action:scale-110"
            />
            <span :if={@stats.likes > 0} class="relative text-sm font-medium">{@stats.likes}</span>
          </button>
        </div>

        <%!-- Bookmark button --%>
        <button class="p-2 rounded-lg text-slate-400 hover:text-amber-600 dark:hover:text-amber-400 hover:bg-amber-50/50 dark:hover:bg-amber-900/20 transition-all duration-200 ease-out group/bookmark active:scale-95 focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:ring-offset-2">
          <.phx_icon name="hero-bookmark" class="h-5 w-5 transition-transform duration-200 group-hover/bookmark:scale-110" />
        </button>
      </div>
    </div>
  </article>
  """
end
```

## 🎯 Phase 0 Deliverables

**After Week 1, you'll have:**

- ✅ **Functional Timeline** - Real posts from database displayed beautifully
- ✅ **Working Composer** - Users can create posts with your exact design
- ✅ **Real Interactions** - Like, share, reply buttons work
- ✅ **Infinite Scroll** - Load more posts functionality
- ✅ **Realtime Updates** - New posts appear in real-time
- ✅ **Same Beautiful Design** - Zero visual changes, just connected to data

**What Users Will See:**

- Timeline that actually works with their real data
- Ability to create and interact with posts
- Real-time updates when others post
- Beautiful liquid metal design maintained perfectly

This gets your timeline from "beautiful mockup" to "fully functional social platform" in just one week, then we can add the performance optimizations in subsequent phases!

---

# 🚀 REMAINING PHASES (Performance & Scale)

## Phase 1: Performance Foundation (Week 2)

[Previous encrypted caching implementation details...]

## Phase 2: Broadway Pipeline (Week 3)

[Previous Broadway implementation details...]

## Phase 3: Advanced Features (Week 4)

[Previous realtime and optimistic UI details...]

## Phase 4: Fly.io Optimization (Week 5)

[Previous Fly.io distribution details...]

---

This plan gets you a **working timeline immediately** (Phase 0) then adds performance and scale optimizations. Your users will have a functional social platform right away!
