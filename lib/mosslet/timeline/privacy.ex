defmodule Mosslet.Timeline.Privacy do
  @moduledoc """
  Handles enhanced privacy controls for posts.

  Determines who should receive access to a post based on visibility settings.
  Integrates with the existing post_key -> user_post.key architecture.
  """
  import Ecto.Query, warn: false

  alias Mosslet.Accounts
  alias Mosslet.Timeline.Post

  @doc """
  Determines the list of users who should receive access to a post
  based on its visibility settings.

  Returns a list of users who should get user_post.key records.
  """
  def determine_post_recipients(post, creating_user) do
    case post.visibility do
      :public ->
        # Public posts - handle via existing public post logic
        # Don't create user_post records for public posts
        []

      :private ->
        # Private posts - only the creator
        [creating_user]

      :connections ->
        # All confirmed connections (existing logic)
        get_all_confirmed_connections(creating_user)

      :specific_groups ->
        # NEW - Only connections with matching tags
        get_connections_with_tags(creating_user, post.visibility_groups)

      :specific_users ->
        # NEW - Only specific users (must be connections)
        get_specific_confirmed_users(creating_user, post.visibility_users)
    end
  end

  @doc """
  Checks if a user should have access to a post based on privacy settings.
  Used for filtering timeline queries.
  """
  def user_can_access_post?(post, user) do
    cond do
      # Creator can always access their own posts
      post.user_id == user.id ->
        true

      # Public posts are accessible to everyone
      post.visibility == :public ->
        true

      # Private posts only accessible to creator
      post.visibility == :private ->
        false

      # Connection-based visibility
      post.visibility == :connections ->
        Accounts.has_confirmed_user_connection?(user, post.user_id)

      # Group-based visibility
      post.visibility == :specific_groups ->
        user_has_matching_connection_tags?(user, post.user_id, post.visibility_groups)

      # User-specific visibility
      post.visibility == :specific_users ->
        user.id in post.visibility_users &&
          Accounts.has_confirmed_user_connection?(user, post.user_id)

      true ->
        false
    end
  end

  @doc """
  Checks if a user can perform specific actions on a post.
  """
  def user_can_reply_to_post?(post, user) do
    cond do
      !post.allow_replies ->
        false

      post.require_follow_to_reply && !Accounts.has_confirmed_user_connection?(user, post.user_id) ->
        false

      true ->
        user_can_access_post?(post, user)
    end
  end

  def user_can_share_post?(post, user) do
    post.allow_shares && user_can_access_post?(post, user)
  end

  def user_can_bookmark_post?(post, user) do
    post.allow_bookmarks && user_can_access_post?(post, user)
  end

  @doc """
  Gets posts that should be auto-deleted based on expiration.
  """
  def get_expired_posts() do
    now = NaiveDateTime.utc_now()

    from(p in Post,
      where: not is_nil(p.expires_at) and p.expires_at <= ^now,
      preload: [:user_posts, :replies]
    )
    |> Mosslet.Repo.all()
  end

  @doc """
  Auto-deletes expired posts and related data.
  Should be called by a background job.
  """
  def cleanup_expired_posts() do
    expired_posts = get_expired_posts()

    case Mosslet.Repo.transaction_on_primary(fn ->
           for post <- expired_posts do
             # Delete the post - this will cascade delete user_posts, replies, bookmarks
             case Mosslet.Timeline.delete_post(post, post.user_id) do
               {:ok, _} ->
                 {:expired_post_deleted, post.id}

               {:error, reason} ->
                 {:error, post.id, reason}
             end
           end
         end) do
      {:ok, results} ->
        # Broadcast deletions for real-time updates
        for result <- results do
          case result do
            {:expired_post_deleted, post_id} ->
              Phoenix.PubSub.broadcast(
                Mosslet.PubSub,
                "posts",
                {:post_expired, post_id}
              )

            _ ->
              :ok
          end
        end

        {:ok, length(expired_posts)}

      error ->
        error
    end
  end

  # Private functions

  defp get_all_confirmed_connections(user) do
    Accounts.get_all_confirmed_user_connections(user.id)
    |> Enum.map(&get_connection_user/1)
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp get_connections_with_tags(user, tag_names) when is_list(tag_names) do
    # For now, return all connections since tags aren't implemented yet
    # TODO: Filter by tags when UserConnection.tags is added
    all_connections = get_all_confirmed_connections(user)

    # Future implementation:
    # all_connections
    # |> Enum.filter(fn connection ->
    #   connection.tags && Enum.any?(connection.tags, &(&1 in tag_names))
    # end)

    # For now, just return all connections to make it functional
    all_connections
  end

  defp get_specific_confirmed_users(user, user_ids) when is_list(user_ids) do
    # Get users by IDs, but only if they're confirmed connections
    confirmed_connection_ids =
      Accounts.get_all_confirmed_user_connections(user.id)
      |> Enum.map(& &1.reverse_user_id)

    # Filter to only include confirmed connections
    valid_user_ids = Enum.filter(user_ids, &(&1 in confirmed_connection_ids))

    if Enum.empty?(valid_user_ids) do
      []
    else
      from(u in Accounts.User, where: u.id in ^valid_user_ids)
      |> Mosslet.Repo.all()
    end
  end

  defp get_connection_user(user_connection) do
    # Get the other user in the connection relationship
    if user_connection.reverse_user_id do
      Accounts.get_user(user_connection.reverse_user_id)
    else
      nil
    end
  end

  defp user_has_matching_connection_tags?(user, other_user_id, _tag_names) do
    # For now, just check if they have a connection
    # TODO: Check if the connection has matching tags when implemented
    Accounts.has_confirmed_user_connection?(user, other_user_id)
  end
end
