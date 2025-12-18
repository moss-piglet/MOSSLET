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
  """

  alias Mosslet.Accounts.{User, Connection}
  alias Mosslet.Timeline.{Post, Reply, UserPost, Bookmark, BookmarkCategory}

  @doc """
  Gets a post by ID.
  """
  @callback get_post(id :: String.t()) :: Post.t() | nil

  @doc """
  Gets a post by ID, raises if not found.
  """
  @callback get_post!(id :: String.t()) :: Post.t()

  @doc """
  Gets a post with nested replies preloaded.
  """
  @callback get_post_with_nested_replies(id :: String.t(), options :: map()) :: Post.t() | nil

  @doc """
  Gets a reply by ID.
  """
  @callback get_reply(id :: String.t()) :: Reply.t() | nil

  @doc """
  Gets a reply by ID, raises if not found.
  """
  @callback get_reply!(id :: String.t()) :: Reply.t()

  @doc """
  Creates a new post.
  Returns {:ok, connection, post} on success for group posts,
  {:ok, post} for non-group posts,
  or {:error, changeset} on failure.
  """
  @callback create_post(attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()}
              | {:ok, Connection.t(), Post.t()}
              | {:error, Ecto.Changeset.t()}

  @doc """
  Creates a public post.
  """
  @callback create_public_post(attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates an existing post.
  """
  @callback update_post(post :: Post.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates a public post.
  """
  @callback update_public_post(post :: Post.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes a post.
  """
  @callback delete_post(post :: Post.t(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes a group post.
  """
  @callback delete_group_post(post :: Post.t(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Creates a reply to a post.
  """
  @callback create_reply(attrs :: map(), opts :: keyword()) ::
              {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates a reply.
  """
  @callback update_reply(reply :: Reply.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes a reply.
  """
  @callback delete_reply(reply :: Reply.t(), opts :: keyword()) ::
              {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Lists posts for a user with pagination and filtering.
  """
  @callback list_posts(user :: User.t(), options :: map()) :: [Post.t()]

  @doc """
  Lists user posts for sync (native apps).
  """
  @callback list_user_posts_for_sync(user :: User.t(), opts :: keyword()) :: [Post.t()]

  @doc """
  Lists the user's own posts with pagination.
  """
  @callback list_user_own_posts(user :: User.t(), options :: map()) :: [Post.t()]

  @doc """
  Lists posts from user's connections with pagination.
  """
  @callback list_connection_posts(user :: User.t(), options :: map()) :: [Post.t()]

  @doc """
  Lists posts from user's groups with pagination.
  """
  @callback list_group_posts(user :: User.t(), options :: map()) :: [Post.t()]

  @doc """
  Lists discover/public posts with pagination.
  """
  @callback list_discover_posts(user :: User.t() | nil, options :: map()) :: [Post.t()]

  @doc """
  Filters timeline posts based on preferences and options.
  """
  @callback filter_timeline_posts(user :: User.t(), options :: map()) :: [Post.t()]

  @doc """
  Fetches timeline posts directly from database (bypasses cache).
  """
  @callback fetch_timeline_posts_from_db(user :: User.t(), options :: map()) :: [Post.t()]

  @doc """
  Lists replies for a post.
  """
  @callback list_replies(post :: Post.t(), options :: map()) :: [Reply.t()]

  @doc """
  Lists public replies for a public post.
  """
  @callback list_public_replies(post :: Post.t(), options :: map()) :: [Reply.t()]

  @doc """
  Gets nested replies for a post (threaded view).
  """
  @callback get_nested_replies_for_post(post_id :: String.t(), options :: map()) :: [Reply.t()]

  @doc """
  Gets child replies for a parent reply.
  """
  @callback get_child_replies_for_reply(parent_reply_id :: String.t(), options :: map()) ::
              [Reply.t()]

  @doc """
  Increments the favorites count on a post.
  """
  @callback inc_favs(post :: Post.t()) :: {integer(), nil | [Post.t()]}

  @doc """
  Decrements the favorites count on a post.
  """
  @callback decr_favs(post :: Post.t()) :: {integer(), nil | [Post.t()]}

  @doc """
  Increments the favorites count on a reply.
  """
  @callback inc_reply_favs(reply :: Reply.t()) :: {integer(), nil | [Reply.t()]}

  @doc """
  Decrements the favorites count on a reply.
  """
  @callback decr_reply_favs(reply :: Reply.t()) :: {integer(), nil | [Reply.t()]}

  @doc """
  Updates the favorite status on a post.
  """
  @callback update_post_fav(post :: Post.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates the favorite status on a reply.
  """
  @callback update_reply_fav(reply :: Reply.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Creates a bookmark for a post.
  """
  @callback create_bookmark(user :: User.t(), post :: Post.t(), attrs :: map()) ::
              {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t() | :already_bookmarked}

  @doc """
  Updates a bookmark.
  """
  @callback update_bookmark(bookmark :: Bookmark.t(), attrs :: map(), user :: User.t()) ::
              {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes a bookmark.
  """
  @callback delete_bookmark(bookmark :: Bookmark.t(), user :: User.t()) ::
              {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Gets a bookmark for a user and post.
  """
  @callback get_bookmark(user :: User.t(), post :: Post.t()) :: Bookmark.t() | nil

  @doc """
  Checks if a post is bookmarked by the user.
  """
  @callback bookmarked?(user :: User.t(), post :: Post.t()) :: boolean()

  @doc """
  Lists user's bookmarks with pagination.
  """
  @callback list_user_bookmarks(user :: User.t(), opts :: keyword()) :: [Bookmark.t()]

  @doc """
  Lists user's bookmark categories.
  """
  @callback list_user_bookmark_categories(user :: User.t()) :: [BookmarkCategory.t()]

  @doc """
  Creates a bookmark category.
  """
  @callback create_bookmark_category(user :: User.t(), attrs :: map()) ::
              {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates a bookmark category.
  """
  @callback update_bookmark_category(category :: BookmarkCategory.t(), attrs :: map()) ::
              {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes a bookmark category.
  """
  @callback delete_bookmark_category(category :: BookmarkCategory.t()) ::
              {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Gets a user's bookmark category by ID.
  """
  @callback get_user_bookmark_category(user :: User.t(), category_id :: String.t()) ::
              BookmarkCategory.t() | nil

  @doc """
  Counts all posts (admin function).
  """
  @callback count_all_posts() :: non_neg_integer()

  @doc """
  Counts a user's posts with optional filtering.
  """
  @callback post_count(user :: User.t(), options :: map()) :: non_neg_integer()

  @doc """
  Counts a user's own posts.
  """
  @callback count_user_own_posts(user :: User.t(), filter_prefs :: map()) :: non_neg_integer()

  @doc """
  Counts a user's group posts.
  """
  @callback count_user_group_posts(user :: User.t(), filter_prefs :: map()) :: non_neg_integer()

  @doc """
  Counts posts from user's connections.
  """
  @callback count_user_connection_posts(user :: User.t(), filter_prefs :: map()) ::
              non_neg_integer()

  @doc """
  Counts discover/public posts.
  """
  @callback count_discover_posts(user :: User.t() | nil, filter_prefs :: map()) ::
              non_neg_integer()

  @doc """
  Counts unread posts for the user.
  """
  @callback count_unread_posts_for_user(user :: User.t()) :: non_neg_integer()

  @doc """
  Counts unread replies for the user.
  """
  @callback count_unread_replies_for_user(user :: User.t()) :: non_neg_integer()

  @doc """
  Counts replies for a post.
  """
  @callback count_replies_for_post(post_id :: String.t(), options :: map()) :: non_neg_integer()

  @doc """
  Counts user's bookmarks.
  """
  @callback count_user_bookmarks(user :: User.t(), filter_prefs :: map()) :: non_neg_integer()

  @doc """
  Gets timeline data for a specific tab.
  """
  @callback get_timeline_data(user :: User.t(), tab :: atom(), options :: map()) :: map()

  @doc """
  Gets timeline counts for all tabs.
  """
  @callback get_timeline_counts(user :: User.t()) :: map()

  @doc """
  Gets user timeline preference.
  """
  @callback get_user_timeline_preference(user :: User.t()) :: any()

  @doc """
  Updates user timeline preference.
  """
  @callback update_user_timeline_preference(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, any()} | {:error, Ecto.Changeset.t()}

  @doc """
  Creates or updates a user post receipt (read status).
  """
  @callback create_or_update_user_post_receipt(
              user_post :: UserPost.t(),
              user :: User.t(),
              is_read? :: boolean()
            ) :: {:ok, any()} | {:error, any()}

  @doc """
  Gets a user post by post_id and user_id.
  """
  @callback get_user_post_by_post_id_and_user_id(post_id :: String.t(), user_id :: String.t()) ::
              UserPost.t() | nil

  @doc """
  Gets a user post by post_id and user_id, raises if not found.
  """
  @callback get_user_post_by_post_id_and_user_id!(post_id :: String.t(), user_id :: String.t()) ::
              UserPost.t()

  @doc """
  Shares a post with another user.
  """
  @callback share_post_with_user(
              post :: Post.t(),
              user_to_share_with :: User.t(),
              decrypted_post_key :: binary(),
              opts :: keyword()
            ) :: {:ok, Post.t()} | {:error, any()}

  @doc """
  Removes self from a shared post.
  """
  @callback remove_self_from_shared_post(user_post :: UserPost.t(), opts :: keyword()) ::
              {:ok, UserPost.t()} | {:error, any()}

  @doc """
  Deletes a user post.
  """
  @callback delete_user_post(user_post :: UserPost.t(), opts :: keyword()) ::
              {:ok, UserPost.t()} | {:error, any()}

  @doc """
  Gets blocked user IDs for filtering.
  """
  @callback get_blocked_user_ids(user :: User.t()) :: [String.t()]

  @doc """
  Hides a post for a user.
  """
  @callback hide_post(user :: User.t(), post :: Post.t(), attrs :: map()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Unhides a post for a user.
  """
  @callback unhide_post(user :: User.t(), post :: Post.t()) :: {:ok, any()} | {:error, any()}

  @doc """
  Checks if a post is hidden by the user.
  """
  @callback post_hidden?(user :: User.t(), post :: Post.t()) :: boolean()

  @doc """
  Reports a post.
  """
  @callback report_post(
              reporter :: User.t(),
              reported_user :: User.t(),
              post :: Post.t(),
              attrs :: map()
            ) :: {:ok, any()} | {:error, any()}

  @doc """
  Marks all top-level replies as read for a post.
  """
  @callback mark_top_level_replies_read_for_post(post_id :: String.t(), user_id :: String.t()) ::
              :ok

  @doc """
  Marks nested replies as read for a parent reply.
  """
  @callback mark_nested_replies_read_for_parent(
              parent_reply_id :: String.t(),
              user_id :: String.t()
            ) ::
              :ok

  @doc """
  Marks all replies as read for a user.
  """
  @callback mark_all_replies_read_for_user(user_id :: String.t()) :: :ok

  @doc """
  Preloads the group association for a post.
  """
  @callback preload_group(post :: Post.t()) :: Post.t()

  @doc """
  Changes a post (returns changeset for form rendering).
  """
  @callback change_post(post :: Post.t(), attrs :: map(), opts :: keyword()) :: Ecto.Changeset.t()

  @doc """
  Changes a reply (returns changeset for form rendering).
  """
  @callback change_reply(reply :: Reply.t(), attrs :: map(), opts :: keyword()) ::
              Ecto.Changeset.t()

  @doc """
  Increments the repost count on a post.
  """
  @callback inc_reposts(post :: Post.t()) :: {integer(), nil | [Post.t()]}

  @doc """
  Creates a public repost.
  """
  @callback create_public_repost(attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Creates a repost.
  """
  @callback create_repost(attrs :: map(), opts :: keyword()) ::
              {:ok, any()} | {:error, Ecto.Changeset.t()}

  @doc """
  Creates a targeted share to specific users.
  """
  @callback create_targeted_share(attrs :: map(), opts :: keyword()) ::
              {:ok, any()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates the shared users on a post.
  """
  @callback update_post_shared_users(post :: Post.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Removes a shared user from a post.
  """
  @callback remove_post_shared_user(post :: Post.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Gets or creates a user post for a public post.
  """
  @callback get_or_create_user_post_for_public(post :: Post.t(), user :: User.t()) ::
              {:ok, UserPost.t()} | {:error, any()}

  @doc """
  Gets a user post for a post and user.
  """
  @callback get_user_post(post :: Post.t(), user :: User.t()) :: UserPost.t() | nil

  @doc """
  Gets timeline preference changeset.
  """
  @callback change_user_timeline_preference(
              pref :: any(),
              attrs :: map(),
              opts :: keyword()
            ) :: Ecto.Changeset.t()

  @doc """
  Invalidates the timeline cache for a user.
  """
  @callback invalidate_timeline_cache_for_user(
              user_id :: String.t(),
              affecting_tabs :: list() | nil
            ) ::
              :ok

  @doc """
  Gets expired ephemeral posts for cleanup.
  """
  @callback get_expired_ephemeral_posts(current_time :: DateTime.t() | nil) :: [Post.t()]

  @doc """
  Gets all ephemeral posts for a user.
  """
  @callback get_user_ephemeral_posts(user :: User.t()) :: [Post.t()]
end
