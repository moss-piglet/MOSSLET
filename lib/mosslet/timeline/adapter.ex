defmodule Mosslet.Timeline.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific timeline operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Thin Adapter Pattern

  Business logic (changesets, broadcasts, PubSub, cache invalidation) stays in
  the `Mosslet.Timeline` context. Adapters ONLY handle data access:
  - Repo calls for web
  - API + cache for native

  ## Implementation

  Web adapter (`Mosslet.Timeline.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Timeline.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data
  """

  alias Mosslet.Timeline.{
    Post,
    Reply,
    UserPost,
    UserPostReceipt,
    UserTimelinePreference,
    Bookmark,
    BookmarkCategory,
    PostReport,
    PostHide,
    ContentWarningCategory
  }

  alias Mosslet.Accounts.User
  alias Mosslet.Groups.Group

  # ===========================================================================
  # Post Read Operations
  # ===========================================================================

  @callback get_post(id :: String.t()) :: Post.t() | nil
  @callback get_post!(id :: String.t()) :: Post.t()
  @callback get_post_with_preloads(id :: String.t(), preloads :: list()) :: Post.t() | nil
  @callback preload_group(post :: Post.t()) :: Post.t()
  @callback get_all_posts(user :: User.t()) :: [Post.t()]
  @callback get_all_shared_posts(user_id :: String.t()) :: [UserPost.t()]
  @callback get_all_public_user_posts() :: [UserPost.t()]
  @callback get_profile_user_posts(user :: User.t()) :: [UserPost.t()]
  @callback get_expired_ephemeral_posts(current_time :: DateTime.t() | nil) :: [Post.t()]
  @callback get_user_ephemeral_posts(user :: User.t()) :: [Post.t()]

  # ===========================================================================
  # Post List Operations
  # ===========================================================================

  @callback list_posts(user :: User.t(), options :: map()) :: [Post.t()]
  @callback list_user_posts_for_sync(user :: User.t(), opts :: keyword()) :: [UserPost.t()]
  @callback list_shared_posts(user_id :: String.t(), current_user_id :: String.t(), options :: map()) :: [Post.t()]
  @callback list_public_posts(options :: map()) :: [Post.t()]
  @callback list_connection_posts_query(current_user :: User.t(), connection_user_ids :: [String.t()], options :: map()) :: [Post.t()]
  @callback list_group_posts_query(current_user :: User.t(), options :: map()) :: [Post.t()]
  @callback list_discover_posts_query(current_user :: User.t() | nil, options :: map()) :: [Post.t()]
  @callback list_user_own_posts_query(current_user :: User.t(), options :: map()) :: [Post.t()]
  @callback list_public_profile_posts(user :: User.t(), options :: map()) :: [Post.t()]
  @callback list_user_group_posts(group :: Group.t(), user :: User.t()) :: [Post.t()]
  @callback list_own_connection_posts(user :: User.t(), opts :: map()) :: [Post.t()]
  @callback unread_posts_query(current_user :: User.t()) :: [Post.t()]
  @callback fetch_timeline_posts_from_db_query(current_user :: User.t(), options :: map()) :: [Post.t()]
  @callback get_recently_active_users(time_window_minutes :: integer(), max_users :: integer()) :: [User.t()]

  # ===========================================================================
  # Post Count Operations
  # ===========================================================================

  @callback count_all_posts() :: non_neg_integer()
  @callback post_count(user :: User.t(), options :: map()) :: non_neg_integer()
  @callback shared_between_users_post_count(user_id :: String.t(), current_user_id :: String.t()) :: non_neg_integer()
  @callback timeline_post_count(current_user :: User.t(), options :: map()) :: non_neg_integer()
  @callback group_post_count(group :: Group.t()) :: non_neg_integer()
  @callback public_post_count_with_options(user :: User.t() | nil, options :: map()) :: non_neg_integer()
  @callback public_post_count(user :: User.t()) :: non_neg_integer()
  @callback count_user_own_posts(user :: User.t(), options :: map()) :: non_neg_integer()
  @callback count_user_group_posts(user :: User.t(), options :: map()) :: non_neg_integer()
  @callback count_user_connection_posts(current_user :: User.t(), connection_user_ids :: [String.t()], options :: map()) :: non_neg_integer()
  @callback count_unread_user_own_posts(user :: User.t(), options :: map()) :: non_neg_integer()
  @callback count_unread_bookmarked_posts(user :: User.t(), options :: map()) :: non_neg_integer()
  @callback count_unread_posts_for_user(user :: User.t()) :: non_neg_integer()
  @callback count_unread_connection_posts(current_user :: User.t(), connection_user_ids :: [String.t()], options :: map()) :: non_neg_integer()
  @callback count_group_posts(current_user :: User.t(), options :: map()) :: non_neg_integer()
  @callback count_unread_group_posts(current_user :: User.t(), options :: map()) :: non_neg_integer()
  @callback count_discover_posts(current_user :: User.t() | nil, options :: map()) :: non_neg_integer()
  @callback count_unread_discover_posts(current_user :: User.t(), options :: map()) :: non_neg_integer()

  # ===========================================================================
  # Post Write Operations (Thin - takes changesets/multis, executes transactions)
  # ===========================================================================

  @callback create_post_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback create_public_post_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback create_repost_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback create_targeted_share_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback update_post(changeset :: Ecto.Changeset.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback update_public_post(changeset :: Ecto.Changeset.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_post(post :: Post.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_group_post_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback inc_favs(post :: Post.t()) :: {:ok, Post.t()}
  @callback decr_favs(post :: Post.t()) :: {:ok, Post.t()}
  @callback inc_reposts(post :: Post.t()) :: {:ok, Post.t()}
  @callback update_post_fav(changeset :: Ecto.Changeset.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback update_post_repost(changeset :: Ecto.Changeset.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback update_post_shared_users(changeset :: Ecto.Changeset.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback update_post_shared_users_without_validation(changeset :: Ecto.Changeset.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}
  @callback remove_post_shared_user_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback share_post_with_user_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback remove_content_warning_from_post(changeset :: Ecto.Changeset.t()) :: {:ok, Post.t()} | {:error, Ecto.Changeset.t()}

  # ===========================================================================
  # UserPost Operations
  # ===========================================================================

  @callback get_user_post!(id :: String.t()) :: UserPost.t()
  @callback get_user_post_by_post_id_and_user_id!(post_id :: String.t(), user_id :: String.t()) :: UserPost.t()
  @callback get_user_post_by_post_id_and_user_id(post_id :: String.t(), user_id :: String.t()) :: UserPost.t() | nil
  @callback get_user_post(post :: Post.t(), user :: User.t()) :: UserPost.t() | nil
  @callback get_public_user_post(post :: Post.t()) :: UserPost.t() | nil
  @callback get_or_create_user_post_for_public_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback delete_user_post(user_post :: UserPost.t()) :: {:ok, UserPost.t()} | {:error, Ecto.Changeset.t()}
  @callback remove_self_from_shared_post_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}

  # ===========================================================================
  # UserPostReceipt Operations
  # ===========================================================================

  @callback get_user_post_receipt!(id :: String.t()) :: UserPostReceipt.t()
  @callback get_user_post_receipt(current_user :: User.t(), post :: Post.t()) :: UserPostReceipt.t() | nil
  @callback get_unread_post_for_user_and_post(post :: Post.t(), current_user :: User.t()) :: UserPostReceipt.t() | nil
  @callback create_or_update_user_post_receipt(user_post :: UserPost.t(), user :: User.t(), is_read? :: boolean()) :: {:ok, UserPostReceipt.t()} | {:error, Ecto.Changeset.t()}
  @callback update_user_post_receipt_read(id :: String.t()) :: {:ok, UserPostReceipt.t()} | {:error, :not_found | Ecto.Changeset.t()}
  @callback update_user_post_receipt_unread(id :: String.t()) :: {:ok, UserPostReceipt.t()} | {:error, :not_found | Ecto.Changeset.t()}

  # ===========================================================================
  # Reply Read Operations
  # ===========================================================================

  @callback get_reply(id :: String.t()) :: Reply.t() | nil
  @callback get_reply!(id :: String.t()) :: Reply.t()
  @callback list_replies(post :: Post.t(), options :: map()) :: [Reply.t()]
  @callback list_public_replies(post :: Post.t(), options :: map()) :: [Reply.t()]
  @callback first_reply(post :: Post.t(), options :: map()) :: Reply.t() | nil
  @callback first_public_reply(post :: Post.t(), options :: map()) :: Reply.t() | nil
  @callback get_nested_replies_for_post(post_id :: String.t(), options :: map()) :: [Reply.t()]
  @callback get_child_replies_for_reply(parent_reply_id :: String.t(), options :: map()) :: [Reply.t()]

  # ===========================================================================
  # Reply Count Operations
  # ===========================================================================

  @callback reply_count(post :: Post.t(), options :: map()) :: non_neg_integer()
  @callback public_reply_count(post :: Post.t(), options :: map()) :: non_neg_integer()
  @callback count_replies_for_post(post_id :: String.t(), options :: map()) :: non_neg_integer()
  @callback count_top_level_replies(post_id :: String.t(), options :: map()) :: non_neg_integer()
  @callback count_child_replies(parent_reply_id :: String.t(), options :: map()) :: non_neg_integer()
  @callback count_unread_replies_for_user(user :: User.t()) :: non_neg_integer()
  @callback count_unread_direct_replies_for_user(user :: User.t()) :: non_neg_integer()
  @callback count_unread_replies_by_post(user :: User.t()) :: map()
  @callback count_unread_direct_replies_by_post(user :: User.t()) :: map()
  @callback count_unread_replies_to_user_replies(user :: User.t()) :: non_neg_integer()
  @callback count_unread_nested_replies_by_parent(user :: User.t()) :: map()
  @callback count_unread_replies_to_user_replies_by_post(user :: User.t()) :: map()
  @callback count_unread_nested_replies_for_post(post_id :: String.t(), user_id :: String.t()) :: non_neg_integer()

  # ===========================================================================
  # Reply Write Operations
  # ===========================================================================

  @callback create_reply(changeset :: Ecto.Changeset.t()) :: {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}
  @callback update_reply(changeset :: Ecto.Changeset.t()) :: {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_reply(reply :: Reply.t()) :: {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}
  @callback inc_reply_favs(reply :: Reply.t()) :: {:ok, Reply.t()}
  @callback decr_reply_favs(reply :: Reply.t()) :: {:ok, Reply.t()}
  @callback update_reply_fav(changeset :: Ecto.Changeset.t()) :: {:ok, Reply.t()} | {:error, Ecto.Changeset.t()}
  @callback mark_nested_replies_read_for_parent(parent_reply_id :: String.t(), user_id :: String.t()) :: non_neg_integer()
  @callback mark_replies_read_for_post(post_id :: String.t(), user_id :: String.t()) :: non_neg_integer()
  @callback mark_direct_replies_read_for_post(post_id :: String.t(), user_id :: String.t(), now :: DateTime.t()) :: non_neg_integer()
  @callback mark_nested_replies_read_for_post(post_id :: String.t(), user_id :: String.t(), now :: DateTime.t()) :: non_neg_integer()
  @callback mark_top_level_replies_read_for_post(post_id :: String.t(), user_id :: String.t()) :: non_neg_integer()
  @callback mark_all_replies_read_for_user(user_id :: String.t()) :: non_neg_integer()
  @callback mark_all_direct_replies_read_for_user(user_id :: String.t(), now :: DateTime.t()) :: non_neg_integer()
  @callback mark_all_nested_replies_read_for_user(user_id :: String.t(), now :: DateTime.t()) :: non_neg_integer()

  # ===========================================================================
  # Bookmark Operations
  # ===========================================================================

  @callback get_bookmark(user :: User.t(), post :: Post.t()) :: Bookmark.t() | nil
  @callback bookmarked?(user :: User.t(), post :: Post.t()) :: boolean()
  @callback list_user_bookmarks(user :: User.t(), opts :: keyword()) :: [Bookmark.t()]
  @callback count_user_bookmarks(user :: User.t(), options :: map()) :: non_neg_integer()
  @callback create_bookmark(changeset :: Ecto.Changeset.t()) :: {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  @callback update_bookmark(changeset :: Ecto.Changeset.t()) :: {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_bookmark(bookmark :: Bookmark.t()) :: {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_post_bookmarks(post_id :: String.t()) :: {non_neg_integer(), nil}

  # ===========================================================================
  # Bookmark Category Operations
  # ===========================================================================

  @callback create_bookmark_category(changeset :: Ecto.Changeset.t()) :: {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}
  @callback update_bookmark_category(changeset :: Ecto.Changeset.t()) :: {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}
  @callback delete_bookmark_category(category :: BookmarkCategory.t()) :: {:ok, BookmarkCategory.t()} | {:error, Ecto.Changeset.t()}
  @callback list_user_bookmark_categories(user :: User.t()) :: [BookmarkCategory.t()]
  @callback get_user_bookmark_category(user :: User.t(), category_id :: String.t()) :: BookmarkCategory.t() | nil

  # ===========================================================================
  # Post Report Operations
  # ===========================================================================

  @callback get_post_report(id :: String.t()) :: PostReport.t() | nil
  @callback list_post_reports(opts :: keyword()) :: [PostReport.t()]
  @callback count_post_reports(opts :: keyword()) :: non_neg_integer()
  @callback report_post_transaction(multi :: Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), any(), map()}
  @callback update_post_report(changeset :: Ecto.Changeset.t()) :: {:ok, PostReport.t()} | {:error, Ecto.Changeset.t()}
  @callback get_reporter_statistics(reporter_id :: String.t()) :: map()
  @callback get_reported_user_statistics(reported_user_id :: String.t()) :: map()

  # ===========================================================================
  # Post Hide Operations
  # ===========================================================================

  @callback hide_post(changeset :: Ecto.Changeset.t()) :: {:ok, PostHide.t()} | {:error, Ecto.Changeset.t()}
  @callback unhide_post(user :: User.t(), post :: Post.t()) :: {:ok, PostHide.t()} | {:error, :not_found}
  @callback post_hidden?(user :: User.t(), post :: Post.t()) :: boolean()
  @callback list_hidden_posts(user :: User.t()) :: [PostHide.t()]

  # ===========================================================================
  # Content Warning Category Operations
  # ===========================================================================

  @callback create_system_content_warning_category(changeset :: Ecto.Changeset.t()) :: {:ok, ContentWarningCategory.t()} | {:error, Ecto.Changeset.t()}
  @callback create_user_content_warning_category(changeset :: Ecto.Changeset.t()) :: {:ok, ContentWarningCategory.t()} | {:error, Ecto.Changeset.t()}
  @callback list_content_warning_categories(user :: User.t()) :: [ContentWarningCategory.t()]
  @callback list_system_content_warning_categories() :: [ContentWarningCategory.t()]

  # ===========================================================================
  # Timeline Preference Operations
  # ===========================================================================

  @callback get_user_timeline_preference(user :: User.t()) :: UserTimelinePreference.t() | nil
  @callback upsert_user_timeline_preference(changeset :: Ecto.Changeset.t()) :: {:ok, UserTimelinePreference.t()} | {:error, Ecto.Changeset.t()}

  # ===========================================================================
  # Blocked User Operations
  # ===========================================================================

  @callback get_blocked_user_ids(user :: User.t()) :: [String.t()]
end
