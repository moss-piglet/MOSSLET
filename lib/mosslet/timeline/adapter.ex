defmodule Mosslet.Timeline.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific timeline operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Timeline.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Timeline.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the same pattern as `Mosslet.Accounts.Adapter`:
  - Business logic stays in the context (`Mosslet.Timeline`)
  - Adapters handle data access (database vs API)
  - Context orchestrates operations and broadcasts events
  """

  alias Mosslet.Accounts.User
  alias Mosslet.Groups.Group
  alias Mosslet.Timeline.{Post, Reply, UserPost, UserPostReceipt, Bookmark, BookmarkCategory}

  # =============================================================================
  # Post Getters
  # =============================================================================

  @callback get_post(id :: String.t()) :: Post.t() | nil
  @callback get_post!(id :: String.t()) :: Post.t()
  @callback get_post_with_preloads(id :: String.t()) :: Post.t() | nil
  @callback get_post_with_preloads!(id :: String.t()) :: Post.t()

  # =============================================================================
  # Reply Getters
  # =============================================================================

  @callback get_reply(id :: String.t()) :: Reply.t() | nil
  @callback get_reply!(id :: String.t()) :: Reply.t()
  @callback get_reply_with_preloads(id :: String.t()) :: Reply.t() | nil
  @callback get_reply_with_preloads!(id :: String.t()) :: Reply.t()

  # =============================================================================
  # UserPost Getters
  # =============================================================================

  @callback get_user_post(id :: String.t()) :: UserPost.t() | nil
  @callback get_user_post!(id :: String.t()) :: UserPost.t()
  @callback get_user_post_by_post_id_and_user_id(post_id :: String.t(), user_id :: String.t()) ::
              UserPost.t() | nil
  @callback get_user_post_by_post_id_and_user_id!(post_id :: String.t(), user_id :: String.t()) ::
              UserPost.t()

  # =============================================================================
  # UserPostReceipt Getters
  # =============================================================================

  @callback get_user_post_receipt(id :: String.t()) :: UserPostReceipt.t() | nil
  @callback get_user_post_receipt!(id :: String.t()) :: UserPostReceipt.t()

  # =============================================================================
  # Post Listing
  # =============================================================================

  @callback get_all_posts(user :: User.t()) :: [Post.t()]
  @callback get_all_shared_posts(user_id :: String.t()) :: [Post.t()]
  @callback list_user_posts_for_sync(user :: User.t(), opts :: keyword()) :: [UserPost.t()]
  @callback list_posts(user :: User.t(), options :: map()) :: [Post.t()]
  @callback list_shared_posts(
              user_id :: String.t(),
              current_user_id :: String.t(),
              options :: map()
            ) :: [Post.t()]
  @callback list_public_posts(user :: User.t() | nil, options :: map()) :: [Post.t()]
  @callback filter_timeline_posts(current_user :: User.t(), options :: map()) :: [Post.t()]
  @callback list_group_posts(group :: Group.t(), user :: User.t(), options :: map()) :: [Post.t()]

  # =============================================================================
  # Reply Listing
  # =============================================================================

  @callback list_replies(post :: Post.t(), options :: map()) :: [Reply.t()]
  @callback list_public_replies(post :: Post.t(), options :: map()) :: [Reply.t()]
  @callback list_nested_replies(parent_reply_id :: String.t(), options :: map()) :: [Reply.t()]
  @callback list_user_replies(user :: User.t(), options :: map()) :: [Reply.t()]

  # =============================================================================
  # Timeline Listing Functions (with caching support)
  # These are called by the context after caching logic; adapters handle DB/API access
  # =============================================================================

  @callback fetch_connection_posts(current_user :: User.t(), options :: map()) :: [Post.t()]
  @callback fetch_discover_posts(current_user :: User.t() | nil, options :: map()) :: [Post.t()]
  @callback fetch_user_own_posts(current_user :: User.t(), options :: map()) :: [Post.t()]
  @callback fetch_home_timeline(current_user :: User.t(), options :: map()) :: [Post.t()]
  @callback fetch_group_posts(current_user :: User.t(), options :: map()) :: [Post.t()]

  # =============================================================================
  # Profile Listing Functions
  # =============================================================================

  @callback list_public_profile_posts(
              user :: User.t(),
              viewer :: User.t() | nil,
              hidden_post_ids :: [String.t()],
              options :: map()
            ) :: [Post.t()]
  @callback list_profile_posts_visible_to(
              profile_user :: User.t(),
              viewer :: User.t(),
              options :: map()
            ) :: [Post.t()]
  @callback count_profile_posts_visible_to(profile_user :: User.t(), viewer :: User.t()) ::
              non_neg_integer()
  @callback list_user_group_posts(group :: Group.t(), user :: User.t()) :: [Post.t()]
  @callback list_own_connection_posts(user :: User.t(), opts :: map()) :: [Post.t()]

  # =============================================================================
  # Home Timeline Count Functions
  # =============================================================================

  @callback count_home_timeline(user :: User.t(), filter_prefs :: map()) :: non_neg_integer()
  @callback count_unread_home_timeline(user :: User.t(), filter_prefs :: map()) ::
              non_neg_integer()

  # =============================================================================
  # Utility Listing Functions
  # =============================================================================

  @callback first_reply(post :: Post.t(), options :: map()) :: Reply.t() | nil
  @callback first_public_reply(post :: Post.t(), options :: map()) :: Reply.t() | nil
  @callback unread_posts(current_user :: User.t()) :: [Post.t()]

  # =============================================================================
  # Post Count Functions
  # =============================================================================

  @callback count_all_posts() :: non_neg_integer()
  @callback post_count(user :: User.t(), options :: map()) :: non_neg_integer()
  @callback timeline_post_count(current_user :: User.t(), options :: map()) :: non_neg_integer()
  @callback public_post_count(user :: User.t()) :: non_neg_integer()
  @callback public_post_count_filtered(user :: User.t() | nil, options :: map()) ::
              non_neg_integer()
  @callback group_post_count(group :: Group.t()) :: non_neg_integer()
  @callback shared_between_users_post_count(user_id :: String.t(), current_user_id :: String.t()) ::
              non_neg_integer()
  @callback count_user_own_posts(user :: User.t(), filter_prefs :: map()) :: non_neg_integer()
  @callback count_user_group_posts(user :: User.t(), filter_prefs :: map()) :: non_neg_integer()
  @callback count_user_connection_posts(current_user :: User.t(), filter_prefs :: map()) ::
              non_neg_integer()
  @callback count_discover_posts(current_user :: User.t() | nil, filter_prefs :: map()) ::
              non_neg_integer()

  # =============================================================================
  # Unread Post Count Functions
  # =============================================================================

  @callback count_unread_posts_for_user(user :: User.t()) :: non_neg_integer()
  @callback count_unread_user_own_posts(user :: User.t(), filter_prefs :: map()) ::
              non_neg_integer()
  @callback count_unread_bookmarked_posts(user :: User.t(), filter_prefs :: map()) ::
              non_neg_integer()
  @callback count_unread_connection_posts(current_user :: User.t(), filter_prefs :: map()) ::
              non_neg_integer()
  @callback count_unread_group_posts(current_user :: User.t(), filter_prefs :: map()) ::
              non_neg_integer()
  @callback count_unread_discover_posts(current_user :: User.t(), filter_prefs :: map()) ::
              non_neg_integer()

  # =============================================================================
  # Reply Count Functions
  # =============================================================================

  @callback reply_count(post :: Post.t(), options :: map()) :: non_neg_integer()
  @callback public_reply_count(post :: Post.t(), options :: map()) :: non_neg_integer()
  @callback count_replies_for_post(post_id :: String.t(), options :: map()) :: non_neg_integer()
  @callback count_top_level_replies(post_id :: String.t(), options :: map()) :: non_neg_integer()
  @callback count_child_replies(parent_reply_id :: String.t(), options :: map()) ::
              non_neg_integer()
  @callback count_unread_replies_for_user(user :: User.t()) :: non_neg_integer()
  @callback count_unread_replies_by_post(user :: User.t()) :: map()
  @callback count_unread_replies_to_user_replies(user :: User.t()) :: non_neg_integer()
  @callback count_unread_nested_replies_by_parent(user :: User.t()) :: map()
  @callback count_unread_replies_to_user_replies_by_post(user :: User.t()) :: map()
  @callback count_unread_nested_replies_for_post(post_id :: String.t(), user_id :: String.t()) ::
              non_neg_integer()

  # =============================================================================
  # Bookmark Count Functions
  # =============================================================================

  @callback count_user_bookmarks(user :: User.t(), filter_prefs :: map()) :: non_neg_integer()

  # =============================================================================
  # Post CRUD Operations
  # =============================================================================

  @callback create_post(attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback update_post(post :: Post.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_post(post :: Post.t()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback remove_shared_user_and_add_to_removed(
              post :: Post.t(),
              attrs :: map(),
              opts :: keyword()
            ) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback remove_shared_user_and_add_to_removed(
              post :: Post.t(),
              attrs :: map(),
              opts :: keyword()
            ) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  # =============================================================================
  # Reply CRUD Operations
  # =============================================================================

  @callback create_reply(attrs :: map(), opts :: keyword()) ::
              {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}
  @callback update_reply(reply :: Reply.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_reply(reply :: Reply.t()) ::
              {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}

  # =============================================================================
  # UserPost CRUD Operations
  # =============================================================================

  @callback create_user_post(attrs :: map()) ::
              {:ok, UserPost.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_user_post(user_post :: UserPost.t()) ::
              {:ok, UserPost.t()} | {:error, Ecto.Changeset.t()}

  # =============================================================================
  # UserPostReceipt Operations
  # =============================================================================

  @callback create_user_post_receipt(attrs :: map()) ::
              {:ok, UserPostReceipt.t()} | {:error, Ecto.Changeset.t()}
  @callback update_user_post_receipt(receipt :: UserPostReceipt.t(), attrs :: map()) ::
              {:ok, UserPostReceipt.t()} | {:error, Ecto.Changeset.t()}
  @callback mark_post_as_read(user_post_id :: String.t(), user_id :: String.t()) ::
              {:ok, UserPostReceipt.t()} | {:error, any()}
  @callback mark_replies_read_for_post(post_id :: String.t(), user_id :: String.t()) ::
              non_neg_integer()
  @callback mark_all_replies_read_for_user(user_id :: String.t()) :: non_neg_integer()
  @callback mark_nested_replies_read_for_parent(
              parent_reply_id :: String.t(),
              user_id :: String.t()
            ) ::
              non_neg_integer()

  # =============================================================================
  # Bookmark Operations
  # =============================================================================

  @callback get_bookmark(id :: String.t()) :: Bookmark.t() | nil
  @callback get_bookmark!(id :: String.t()) :: Bookmark.t()
  @callback get_bookmark_by_post_and_user(post_id :: String.t(), user_id :: String.t()) ::
              Bookmark.t() | nil
  @callback list_user_bookmarks(user :: User.t(), options :: map()) :: [Bookmark.t()]
  @callback create_bookmark(attrs :: map()) ::
              {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_bookmark(bookmark :: Bookmark.t()) ::
              {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  @callback user_has_bookmarked?(user_id :: String.t(), post_id :: String.t()) :: boolean()

  # =============================================================================
  # BookmarkCategory Operations
  # =============================================================================

  @callback get_bookmark_category(id :: String.t()) :: BookmarkCategory.t() | nil
  @callback get_bookmark_category!(id :: String.t()) :: BookmarkCategory.t()
  @callback list_bookmark_categories(user :: User.t()) :: [BookmarkCategory.t()]
  @callback create_bookmark_category(attrs :: map()) ::
              {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}
  @callback update_bookmark_category(category :: BookmarkCategory.t(), attrs :: map()) ::
              {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_bookmark_category(category :: BookmarkCategory.t()) ::
              {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}

  # =============================================================================
  # Preload Functions
  # =============================================================================

  @callback preload_post(post :: Post.t(), preloads :: list()) :: Post.t()
  @callback preload_reply(reply :: Reply.t(), preloads :: list()) :: Reply.t()
  @callback preload_group(post :: Post.t()) :: Post.t()

  # =============================================================================
  # Query Execution (for complex queries built in context)
  # These allow the context to build queries and the adapter to execute them.
  # Web adapter uses Repo directly; Native adapter converts to API calls.
  # =============================================================================

  @callback execute_query(query :: Ecto.Queryable.t()) :: [struct()]
  @callback execute_count(query :: Ecto.Queryable.t()) :: non_neg_integer()
  @callback execute_one(query :: Ecto.Queryable.t()) :: struct() | nil
  @callback execute_exists?(query :: Ecto.Queryable.t()) :: boolean()

  # =============================================================================
  # Transaction Support (for multi-step operations)
  # =============================================================================

  @callback transaction(fun :: (-> any())) :: {:ok, any()} | {:error, any()}

  # =============================================================================
  # Low-Level Repo Operations
  # These allow the context to call repo operations through the adapter.
  # Web adapter delegates to Repo; Native adapter uses API/cache.
  # =============================================================================

  @callback repo_all(query :: Ecto.Queryable.t()) :: [struct()]
  @callback repo_all(query :: Ecto.Queryable.t(), opts :: keyword()) :: [struct()]
  @callback repo_one(query :: Ecto.Queryable.t()) :: struct() | nil
  @callback repo_one(query :: Ecto.Queryable.t(), opts :: keyword()) :: struct() | nil
  @callback repo_one!(query :: Ecto.Queryable.t()) :: struct()
  @callback repo_one!(query :: Ecto.Queryable.t(), opts :: keyword()) :: struct()
  @callback repo_aggregate(query :: Ecto.Queryable.t(), aggregate :: atom(), field :: atom()) ::
              term()
  @callback repo_aggregate(
              query :: Ecto.Queryable.t(),
              aggregate :: atom(),
              field :: atom(),
              opts :: keyword()
            ) :: term()
  @callback repo_exists?(query :: Ecto.Queryable.t()) :: boolean()
  @callback repo_preload(struct_or_structs :: struct() | [struct()], preloads :: list()) ::
              struct() | [struct()]
  @callback repo_preload(
              struct_or_structs :: struct() | [struct()],
              preloads :: list(),
              opts :: keyword()
            ) :: struct() | [struct()]
  @callback repo_insert(changeset :: Ecto.Changeset.t()) ::
              {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback repo_insert!(changeset :: Ecto.Changeset.t()) :: struct()
  @callback repo_update(changeset :: Ecto.Changeset.t()) ::
              {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback repo_update!(changeset :: Ecto.Changeset.t()) :: struct()
  @callback repo_delete(struct :: struct()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback repo_delete!(struct :: struct()) :: struct()
  @callback repo_delete_all(query :: Ecto.Queryable.t()) :: {non_neg_integer(), nil | [term()]}
  @callback repo_update_all(query :: Ecto.Queryable.t(), updates :: keyword()) ::
              {non_neg_integer(), nil | [term()]}
  @callback repo_transaction(fun :: (-> any())) :: {:ok, any()} | {:error, any()}
  @callback repo_get(schema :: module(), id :: term()) :: struct() | nil
  @callback repo_get!(schema :: module(), id :: term()) :: struct()
  @callback repo_get_by(schema :: module(), clauses :: keyword() | map()) :: struct() | nil
  @callback repo_get_by!(schema :: module(), clauses :: keyword() | map()) :: struct()
end
