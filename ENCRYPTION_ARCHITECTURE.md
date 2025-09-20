# 🔐 Mosslet Encryption & Sharing Architecture Reference

## 📋 Overview

This document contains the complete encryption architecture and data sharing patterns for Mosslet. Use this as your reference when implementing any new features to ensure consistency with the existing security model.

**CRITICAL**: All new features MUST follow these patterns to maintain security and consistency.

## 🏗️ Architecture Principles

### Core Design Philosophy

Your encryption architecture is built on **public-key cryptography principles**:

1. **Each context (post, group, connection) gets its own unique key**
2. **Context key is encrypted with recipient's PUBLIC key**
3. **Recipients decrypt using their PRIVATE key**
4. **All content in that context uses the SAME context key**
5. **Private key persists through password changes!**

### 🔑 The Three-Layer Architecture

1. **User Table** - Personal encrypted data (encrypted with `user_key`)
2. **Connection Table** - Shared profile data (encrypted with `conn_key`)
3. **UserConnection Table** - Relationship-specific data (encrypted with connection-specific keys)

## 🔄 Data Sharing Patterns

### The Dual-Update Pattern (CRITICAL)

When a user updates profile information (username, email, avatar, status), your system updates BOTH:

1. **User record** - encrypted with `user_key` (personal access only)
2. **Connection record** - encrypted with `conn_key` (shared with connections)

**Evidence from User.ex:**

```elixir
# Example: encrypt_email_change/3
defp encrypt_email_change(changeset, opts, email) do
  changeset
  |> encrypt_connection_map_email_change(opts, email)  # ← Updates Connection table
  |> put_change(:email, encrypt_user_data(email, opts[:user], opts[:key]))  # ← Updates User table
end

# The connection_map updates flow to Connection table
defp encrypt_connection_map_email_change(changeset, opts, email) do
  # decrypt the user connection key
  {:ok, d_conn_key} =
    Encrypted.Users.Utils.decrypt_user_attrs_key(opts[:user].conn_key, opts[:user], opts[:key])

  c_encrypted_email = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: email})

  changeset
  |> put_change(:connection_map, %{
    c_email: c_encrypted_email,      # ← Encrypted with conn_key
    c_email_hash: email              # ← Hash for searching
  })
end
```

### How Data Sharing Works

1. **Personal Data Storage** (User table):

   ```elixir
   # User updates their email
   user.email ← encrypt(email, user_key)         # Only they can decrypt
   user.email_hash ← hash(email)                 # For searching
   ```

2. **Connection Sharing** (Connection table):

   ```elixir
   # Same email, encrypted for sharing
   connection.email ← encrypt(email, conn_key)   # Connections can decrypt
   connection.email_hash ← hash(email)          # For connection searching
   ```

3. **Access via UserConnection**:
   ```elixir
   # Connections access the data via user_connection.key
   user_connection.key ← encrypt(conn_key, recipient_public_key)  # Per-connection access
   ```

### Encryption Key Hierarchy

```
User Personal Data:    user_key → encrypt(data)     # Only user can decrypt
      ↓
Connection Sharing:    conn_key → encrypt(data)     # Shared with connections
      ↓
Per-Connection:       user_connection.key           # Per-relationship encryption
```

## 🔑 Post-Context Encryption Strategy

**CRITICAL FOR TIMELINE FEATURES**: All timeline-related content uses the existing `post_key` pattern:

### The Post-Context Flow

```elixir
# 1. POST CREATION:
post_key = Encrypted.Utils.generate_key()                    # New key per post
post.body = encrypt("My post content", post_key)             # Content encrypted
post.username = encrypt("john_doe", post_key)                # Username encrypted
post.avatar_url = encrypt("avatar_url", post_key)            # Avatar encrypted
post.user_post_map = %{temp_key: post_key}                   # Key stored temporarily

# 2. USER_POST CREATION (SHARING ACCESS):
# post_key gets encrypted for each user who should access the post
user_post.key = encrypt_for_user(post_key, recipient_public_key)  # Per-user access

# 3. ACCESS FLOW:
# Users decrypt post content via their user_post.key
decrypted_post_key = decrypt(user_post.key, user_private_key)
decrypted_content = decrypt(post.body, decrypted_post_key)
```

### Key Insights from Code Analysis

**From Post.ex:**

- `post_key` generated per post in `maybe_generate_post_key/3`
- ALL post content encrypted with same `post_key`: body, username, avatar_url, content_warning
- `user_post_map.temp_key` holds the post_key during creation
- Content warnings follow same encryption: `encrypt_content_warning_if_present/3`

**From UserPost.ex:**

- `user_post.key` = `post_key` encrypted for each recipient's public key
- `encrypt_attrs/2` handles per-user encryption of the post_key
- Different encryption for public vs private posts (server vs user public keys)

## 🔐 Encryption Patterns by Content Type

### 1. Post-Related Content → Use existing `post_key`

**Rule**: All content related to a specific post uses the same `post_key`

```elixir
# ✅ POST-RELATED CONTENT (use existing post_key)
bookmark.notes = encrypt("My notes about this post", post_key)    # Same as post.body
reply.body = encrypt("My reply", post_key)                       # Same as post.body
post_report.details = encrypt("Report details", post_key)         # Same as post.body
```

**Benefits**:

- ✅ Consistent encryption across all post-related features
- ✅ Reuse existing key management and decryption flows
- ✅ Automatic access control via existing `user_post` relationships
- ✅ Natural data cleanup when posts are deleted

### 2. User-Specific Content → Use `user_key` with dual-update pattern

**Rule**: Personal user data that may be shared with connections

```elixir
# ✅ USER-SPECIFIC CONTENT (use user_key via connection_map pattern)
user.status_message = encrypt("My status", user_key)              # Personal status
bookmark_category.name = encrypt("Work", user_key)               # User's categories
```

### 3. Connection-Shared Content → Use `conn_key` via connection_map pattern

**Rule**: Data explicitly shared between connected users

```elixir
# ✅ CONNECTION-SHARED CONTENT (use conn_key via connection_map pattern)
connection.status_message = encrypt("My status", conn_key)        # Shared status
```

## 🏗️ The Public-Key Architecture Examples

### POST CONTEXT:

```elixir
post_key = generate_unique_key()                              # 1. Generate context key
post.body = encrypt("My content", post_key)                   # 2. Encrypt content with context key
# For each user who should access this post (including creator):
user_post.key = encrypt(post_key, user.public_key)           # 3. Encrypt context key with user's public key
# When user accesses:
decrypted_post_key = decrypt(user_post.key, user.private_key)  # 4. Decrypt context key with private key
decrypted_content = decrypt(post.body, decrypted_post_key)     # 5. Decrypt content with context key
```

### GROUP CONTEXT (same pattern):

```elixir
group_key = generate_unique_key()                             # 1. Generate group context key
group.name = encrypt("My Group", group_key)                   # 2. Encrypt with group key
user_group.key = encrypt(group_key, user.public_key)         # 3. Distribute to members
# Access: decrypt(user_group.key, user.private_key) → group_key → decrypt group content
```

### CONNECTION CONTEXT (same pattern):

```elixir
conn_key = generate_unique_key()                              # 1. Generate connection context key
connection.username = encrypt("My username", conn_key)        # 2. Encrypt with connection key
user_connection.key = encrypt(conn_key, user.public_key)     # 3. Share with connections
# Access: decrypt(user_connection.key, user.private_key) → conn_key → decrypt shared profile
```

## 🔄 How Password Changes Work Without Breaking Decryption

**The secret: Private key is separate from password!**

1. `user.key_pair["private"]` is encrypted with `user_key` (derived from password)
2. When password changes, private key gets re-encrypted with new `user_key`
3. All existing context keys (post_key, group_key, etc.) remain accessible
4. User can still decrypt all historical content

```elixir
# Password change flow:
old_password → old_user_key → decrypt(private_key)         # Get private key
new_password → new_user_key → encrypt(same_private_key)   # Re-encrypt same private key
# Result: Same private key, new password - all historical access preserved!

# Historical access preserved:
user_post.key → decrypt(private_key) → post_key → decrypt(post.body)  # Still works!
user_group.key → decrypt(private_key) → group_key → decrypt(group.name)  # Still works!
```

## 📋 Field Type Guidelines

### Double Encryption (Default for Sensitive Data)

```elixir
# DEFAULT: Double encryption for all sensitive user data (enacl + Cloak)
field :email, Mosslet.Encrypted.Binary          # Double encrypted: enacl + Cloak
field :body, Mosslet.Encrypted.Binary           # Double encrypted: enacl + Cloak
field :username, Mosslet.Encrypted.Binary       # Double encrypted: enacl + Cloak
field :content_warning, Mosslet.Encrypted.Binary # Double encrypted: enacl + Cloak
```

### Searchable Hashes

```elixir
# SEARCHABLE HASHES: For finding encrypted data
field :email_hash, Mosslet.Encrypted.HMAC       # Searchable hash (weak hashing for search)
field :username_hash, Mosslet.Encrypted.HMAC    # Searchable hash (weak hashing for search)
```

### Secure Hashes

```elixir
# SECURE HASHES: For passwords and sensitive authentication
field :password_hash, :string                   # Argon2 strong hashing (no search needed)
```

### Plaintext System Data

```elixir
# PLAINTEXT: Only for non-sensitive system data
field :color, Ecto.Enum                         # System data (colors, enums, etc.)
field :is_admin?, :boolean                      # System flags
field :inserted_at, :naive_datetime            # Timestamps
```

## 🔒 Distributed Database Write Pattern

**MANDATORY**: All database writes MUST use `Repo.transaction_on_primary/1` for distributed setup:

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

## 🏗️ Implementation Patterns

### For Post-Related Features (bookmarks, replies, reports)

```elixir
def create_bookmark(user, post, attrs) do
  # Get post_key using EXISTING mechanism
  user_post = Timeline.get_user_post(post, user)
  {:ok, post_key} = decrypt_user_attrs_key(user_post.key, user, session_key)

  %Bookmark{}
  |> Bookmark.changeset(attrs, post_key: post_key)  # Use post_key!
  |> put_assoc(:user, user)
  |> put_assoc(:post, post)
  |> Repo.transaction_on_primary(&Repo.insert/1)
end
```

### For User-Specific Features (status, categories)

```elixir
def update_user_status(user, attrs, opts) do
  user
  |> User.status_changeset(attrs, opts)  # Uses user_key + conn_key pattern
  |> Repo.transaction_on_primary(&Repo.update/1)
end
```

### Status System Implementation (Dual-Update Pattern)

```elixir
# Status update follows same pattern as email/username updates
def status_changeset(user, attrs, opts \\ []) do
  user
  |> cast(attrs, [:status, :status_message])
  |> validate_status(opts)
  |> encrypt_status_change(opts)  # ← Updates BOTH user and connection
end

defp encrypt_status_change(changeset, opts) do
  status_message = get_field(changeset, :status_message)

  changeset
  |> encrypt_connection_map_status_change(opts, status_message)  # ← Connection table
  |> put_change(:status_message, encrypt_user_data(status_message, opts[:user], opts[:key]))  # ← User table
end

defp encrypt_connection_map_status_change(changeset, opts, status_message) do
  {:ok, d_conn_key} =
    Encrypted.Users.Utils.decrypt_user_attrs_key(opts[:user].conn_key, opts[:user], opts[:key])

  c_encrypted_status = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: status_message})

  changeset
  |> put_change(:connection_map, %{
    c_status: get_field(changeset, :status),           # Status enum (plaintext)
    c_status_message: c_encrypted_status,              # Encrypted message
    c_status_message_hash: String.downcase(status_message),  # Hash for searching
    c_status_updated_at: NaiveDateTime.utc_now()
  })
end
```

## 🔐 Schema Design Guidelines

### ✅ Schemas Should ONLY Contain

1. **Field definitions** with proper encryption types
2. **Basic validation** in changeset functions
3. **Relationships** (belongs_to, has_many)
4. **Simple field encryption/decryption**

### ❌ Schemas Should NEVER Contain

1. **Business logic** (belongs in contexts)
2. **Database queries** (belongs in contexts)
3. **Complex validation** (belongs in contexts)
4. **PubSub broadcasting** (belongs in contexts)
5. **Cache management** (belongs in contexts)
6. **Transaction handling** (belongs in contexts)

### Schema Example (Correct Pattern)

```elixir
defmodule Mosslet.Timeline.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset

  # SCHEMA DEFINITION ONLY
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bookmarks" do
    # ENCRYPTED FIELDS (using post_key)
    field :notes, :binary                        # Encrypted with post_key

    # SEARCHABLE FIELDS
    field :notes_hash, Mosslet.Encrypted.HMAC   # For searching

    # RELATIONSHIPS
    belongs_to :user, User
    belongs_to :post, Post
    belongs_to :category, BookmarkCategory

    timestamps()
  end

  # SIMPLE CHANGESET ONLY
  def changeset(bookmark, attrs, opts \\ []) do
    bookmark
    |> cast(attrs, [:notes, :user_id, :post_id, :category_id])
    |> validate_required([:user_id, :post_id])
    |> encrypt_notes_with_post_key(opts)  # Simple encryption only
    |> unique_constraint([:user_id, :post_id])
  end

  # SIMPLE ENCRYPTION HELPER
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
```

### Context Example (Where Business Logic Goes)

```elixir
defmodule Mosslet.Timeline do
  # ALL BUSINESS LOGIC GOES HERE

  def create_bookmark(user, post, attrs \\ %{}) do
    # Get post_key using EXISTING mechanism
    user_post = get_user_post(post, user)
    {:ok, post_key} = decrypt_user_attrs_key(user_post.key, user, session_key)

    # Transaction handling in CONTEXT
    case Repo.transaction_on_primary(fn ->
      %Bookmark{}
      |> Bookmark.changeset(attrs, post_key: post_key)  # Schema just handles field encryption
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Ecto.Changeset.put_assoc(:post, post)
      |> Repo.insert()
    end) do
      {:ok, {:ok, bookmark}} ->
        # PubSub broadcasting in CONTEXT
        Phoenix.PubSub.broadcast(Mosslet.PubSub, "user:#{user.id}", {:bookmark_created, bookmark})
        {:ok, bookmark}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  # Cache management, complex queries, etc. ALL IN CONTEXT
end
```

## 💡 Why This Architecture is Ingenious

- ✅ **Unique Context Keys** - Each post/group/connection has different encryption key
- ✅ **Public-Key Distribution** - Context keys distributed via recipient public keys
- ✅ **Private-Key Access** - Users decrypt with their private key (never shared with server)
- ✅ **Password Change Resilience** - Private key persists through password changes!
- ✅ **Creator Access** - Post creator gets `user_post.key` too (can always access their own content)
- ✅ **Granular Access Control** - Add/remove access by adding/removing encrypted context keys
- ✅ **Zero Knowledge** - Server never has access to decrypted content or context keys
- ✅ **Forward Secrecy** - Compromise of one context doesn't affect others

## 📝 Implementation Checklist for New Features

When implementing any new feature, follow this checklist:

### 🔐 Encryption Planning

- [ ] **Identify content type**: Post-related, user-specific, or connection-shared?
- [ ] **Choose encryption pattern**: post_key, user_key+conn_key, or plaintext?
- [ ] **Plan key access**: How will users decrypt this content?

### 🏗️ Schema Design

- [ ] **Schema ONLY contains**: Field definitions, relationships, simple validation
- [ ] **Schema NEVER contains**: Business logic, queries, transactions, PubSub
- [ ] **Proper field types**: Encrypted.Binary vs HMAC vs plaintext vs Ecto.Enum

### 📊 Context Implementation

- [ ] **All business logic in context**: CRUD operations, validation, encryption
- [ ] **transaction_on_primary**: All database writes wrapped properly
- [ ] **PubSub broadcasting**: Real-time updates for relevant events
- [ ] **Error handling**: Proper pattern matching for transaction results

### 🔑 Encryption Implementation

- [ ] **Use existing patterns**: Follow post_key or dual-update patterns
- [ ] **Fail-safe encryption**: Operations fail if encryption fails (no plaintext storage)
- [ ] **Consistent key usage**: Same context uses same encryption key
- [ ] **Access control**: Leverage existing user_post/user_group/user_connection patterns

### 🧪 Testing & Validation

- [ ] **Test encryption/decryption**: Verify content can be encrypted and decrypted
- [ ] **Test access control**: Verify only authorized users can access content
- [ ] **Test edge cases**: Handle missing keys, invalid data, etc.
- [ ] **Test real-time updates**: Verify PubSub events work correctly

## 🚨 Critical Do's and Don'ts

### ✅ DO:

- Follow existing encryption patterns (post_key, user_key+conn_key)
- Put ALL business logic in contexts, NOT schemas
- Use `transaction_on_primary` for all database writes
- Broadcast PubSub events for real-time updates
- Test encryption/decryption thoroughly
- Use existing key lookup mechanisms (user_post.key, user_connection.key)

### ❌ DON'T:

- Create new encryption patterns without following existing architecture
- Put business logic, queries, or transactions in schemas
- Use direct Repo.insert/update without transaction_on_primary
- Skip PubSub broadcasting for user-visible changes
- Store sensitive data in plaintext "temporarily"
- Break existing key access patterns

## 🎯 Architecture Benefits

This encryption architecture provides:

- ✅ **Zero-knowledge privacy** - Server admins can't read user content
- ✅ **Granular access control** - Per-user, per-post, per-group access
- ✅ **Password change resilience** - Content accessible after password changes
- ✅ **Forward secrecy** - Compromise of one context doesn't affect others
- ✅ **Automatic cleanup** - Access revoked when relationships end
- ✅ **Performance optimization** - Cache encrypted data without privacy loss
- ✅ **Compliance ready** - Meets highest privacy and security standards

---

**Remember**: Always refer to this document when implementing new features to ensure consistency with Mosslet's security architecture!
