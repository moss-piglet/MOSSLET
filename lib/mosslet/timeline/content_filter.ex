defmodule Mosslet.Timeline.ContentFilter do
  @moduledoc """
  Content filtering system for timeline posts.

  Provides keyword filtering, content warning management, and user hiding
  functionality with encrypted data support and caching integration.
  """

  import Ecto.Query
  alias Mosslet.{Repo, Accounts}
  alias Mosslet.Timeline.{Post, Performance.TimelineCache, UserTimelinePreferences}
  alias Mosslet.Utils
  require Logger

  @doc """
  Filters timeline posts based on user preferences.

  Integrates with existing caching system for performance.
  """
  def filter_timeline_posts(posts, user, filter_options \\ %{}) do
    # Get user's filter preferences (cached for performance)
    filter_prefs = get_user_filter_preferences(user.id)

    posts
    |> filter_by_keywords(filter_prefs.keywords, user)
    |> filter_by_content_warnings(filter_prefs.content_warnings)
    |> filter_by_hidden_users(filter_prefs.hidden_users)
    |> apply_additional_filters(filter_options)
  end

  @doc """
  Gets user's content filter preferences with caching.
  """
  def get_user_filter_preferences(user_id) do
    case TimelineCache.get_timeline_data(user_id, "content_filters") do
      {:hit, cached_prefs} ->
        cached_prefs

      :miss ->
        prefs = load_user_filter_preferences(user_id)
        TimelineCache.cache_timeline_data(user_id, "content_filters", prefs)
        prefs
    end
  end

  @doc """
  Updates user's content filter preferences.
  """
  def update_filter_preferences(user_id, updates) do
    current_prefs = get_user_filter_preferences(user_id)
    new_prefs = Map.merge(current_prefs, updates)

    # Save to database/user preferences
    save_user_filter_preferences(user_id, new_prefs)

    # Update cache
    cache_key = "content_filters:#{user_id}"
    TimelineCache.cache_timeline_data(user_id, "content_filters", new_prefs)

    # Invalidate timeline caches since filtering changed
    invalidate_user_timeline_cache(user_id)

    {:ok, new_prefs}
  end

  @doc """
  Adds a keyword to user's filter list.
  """
  def add_keyword_filter(user_id, keyword) when is_binary(keyword) do
    keyword = String.trim(keyword) |> String.downcase()

    Logger.info("Adding keyword filter: #{keyword} for user #{user_id}")

    if keyword != "" do
      current_prefs = get_user_filter_preferences(user_id)
      current_keywords = current_prefs.keywords || []

      Logger.info("Current keywords: #{inspect(current_keywords)}")

      if keyword not in current_keywords do
        new_keywords = [keyword | current_keywords]
        Logger.info("New keywords list: #{inspect(new_keywords)}")

        result = update_filter_preferences(user_id, %{keywords: new_keywords})
        Logger.info("Update result: #{inspect(result)}")
        result
      else
        Logger.info("Keyword already exists, skipping")
        {:ok, current_prefs}
      end
    else
      {:error, :invalid_keyword}
    end
  end

  @doc """
  Removes a keyword from user's filter list.
  """
  def remove_keyword_filter(user_id, keyword) when is_binary(keyword) do
    keyword = String.trim(keyword) |> String.downcase()
    current_prefs = get_user_filter_preferences(user_id)
    current_keywords = current_prefs.keywords || []

    new_keywords = List.delete(current_keywords, keyword)
    update_filter_preferences(user_id, %{keywords: new_keywords})
  end

  @doc """
  Hides a user from the timeline.
  """
  def hide_user(user_id, target_user_id) do
    current_prefs = get_user_filter_preferences(user_id)
    current_hidden = current_prefs.hidden_users || []

    if target_user_id not in current_hidden do
      new_hidden = [target_user_id | current_hidden]
      update_filter_preferences(user_id, %{hidden_users: new_hidden})
    else
      {:ok, current_prefs}
    end
  end

  @doc """
  Unhides a user from the timeline.
  """
  def unhide_user(user_id, target_user_id) do
    current_prefs = get_user_filter_preferences(user_id)
    current_hidden = current_prefs.hidden_users || []

    new_hidden = List.delete(current_hidden, target_user_id)
    update_filter_preferences(user_id, %{hidden_users: new_hidden})
  end

  @doc """
  Toggles content warning filter settings.
  """
  def toggle_content_warning_filter(user_id, filter_type) do
    current_prefs = get_user_filter_preferences(user_id)
    current_cw_settings = current_prefs.content_warnings || %{}

    new_setting = not Map.get(current_cw_settings, filter_type, false)
    new_cw_settings = Map.put(current_cw_settings, filter_type, new_setting)

    update_filter_preferences(user_id, %{content_warnings: new_cw_settings})
  end

  # Private functions

  defp filter_by_keywords(posts, keywords, user) do
    if keywords && length(keywords) > 0 do
      Enum.filter(posts, fn post ->
        not post_contains_keywords?(post, keywords, user)
      end)
    else
      posts
    end
  end

  defp filter_by_content_warnings(posts, cw_settings) do
    hide_all = Map.get(cw_settings || %{}, :hide_all, false)

    if hide_all do
      Enum.filter(posts, fn post ->
        not post.content_warning?
      end)
    else
      posts
    end
  end

  defp filter_by_hidden_users(posts, hidden_users) do
    if hidden_users && length(hidden_users) > 0 do
      Enum.filter(posts, fn post ->
        post.user_id not in hidden_users
      end)
    else
      posts
    end
  end

  defp apply_additional_filters(posts, filter_options) do
    # Apply any additional filtering logic
    posts
  end

  defp post_contains_keywords?(post, keywords, user) do
    # Get decrypted content to check against keywords
    case get_decrypted_post_content(post, user) do
      {:ok, content} ->
        content_lower = String.downcase(content)

        Enum.any?(keywords, fn keyword ->
          String.contains?(content_lower, keyword)
        end)

      {:error, _} ->
        # If we can't decrypt, don't filter it out
        false
    end
  end

  defp get_decrypted_post_content(post, user) do
    try do
      # Use existing decryption logic from timeline
      post_key = get_post_key(post, user)

      if post_key do
        decrypted_content = Utils.decrypt(%{key: post_key, payload: post.body})
        {:ok, decrypted_content}
      else
        {:error, :no_key}
      end
    rescue
      _ -> {:error, :decryption_failed}
    end
  end

  defp get_post_key(post, user) do
    # Use existing post key logic from timeline helpers
    cond do
      post.visibility == "public" ->
        # Public posts - try to get from user_posts association
        case post.user_posts do
          [user_post | _] -> user_post.post_key
          _ -> nil
        end

      post.user_id == user.id ->
        # User's own post - use their encryption key
        case user.user_posts do
          [user_post | _] when user_post.post_id == post.id -> user_post.post_key
          _ -> nil
        end

      true ->
        # Connection/private post - get from user_posts where current user has access
        case Enum.find(post.user_posts, fn up -> up.user_id == user.id end) do
          %{post_key: post_key} -> post_key
          _ -> nil
        end
    end
  end

  defp load_user_filter_preferences(user_id) do
    Logger.info("Loading user filter preferences for user #{user_id}")

    case Repo.get_by(UserTimelinePreferences, user_id: user_id) do
      nil ->
        Logger.info("No preferences found, returning defaults")

        %{
          keywords: [],
          content_warnings: %{
            hide_all: false
          },
          hidden_users: []
        }

      prefs ->
        Logger.info("Found preferences record")

        # Decrypt keywords if they exist
        keywords =
          if prefs.mute_keywords do
            try do
              # Get the user and key for decryption
              user = Accounts.get_user!(user_id)
              # Decrypt using user's key - this follows the encryption architecture
              decrypted = Utils.decrypt(%{key: user.key, payload: prefs.mute_keywords})
              Jason.decode!(decrypted)
            rescue
              e ->
                Logger.error("Failed to decrypt mute keywords: #{inspect(e)}")
                []
            end
          else
            []
          end

        %{
          keywords: keywords,
          content_warnings: %{
            hide_all: prefs.hide_mature_content || false
          },
          hidden_users: []
        }
    end
  end

  defp save_user_filter_preferences(user_id, preferences) do
    Logger.info("Saving filter preferences for user #{user_id}: #{inspect(preferences)}")

    # Get or create user timeline preferences
    prefs =
      case Repo.get_by(UserTimelinePreferences, user_id: user_id) do
        nil -> %UserTimelinePreferences{user_id: user_id}
        existing -> existing
      end

    # Get user and key for encryption
    user = Accounts.get_user!(user_id)

    # Encrypt keywords using user's key (follows encryption architecture)
    encrypted_keywords =
      if length(preferences.keywords) > 0 do
        json_keywords = Jason.encode!(preferences.keywords)
        Utils.encrypt(%{key: user.key, payload: json_keywords})
      else
        nil
      end

    # Update preferences with encrypted data
    changeset =
      UserTimelinePreferences.changeset(
        prefs,
        %{
          mute_keywords: encrypted_keywords,
          hide_mature_content: preferences.content_warnings[:hide_all] || false
        },
        user: user,
        key: user.key
      )

    case Repo.insert_or_update(changeset) do
      {:ok, _updated_prefs} ->
        Logger.info("Successfully saved filter preferences")
        :ok

      {:error, changeset} ->
        Logger.error("Failed to save filter preferences: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp invalidate_user_timeline_cache(user_id) do
    # Invalidate all timeline-related caches for this user
    TimelineCache.invalidate_timeline(user_id, :all)
  end
end
