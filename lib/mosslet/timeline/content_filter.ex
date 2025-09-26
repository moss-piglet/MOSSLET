defmodule Mosslet.Timeline.ContentFilter do
  @moduledoc """
  Content filtering system for timeline posts.

  Provides keyword filtering, content warning management, and user muting
  functionality. Aligns with UserTimelinePreferences schema and integrates
  with Timeline functions for actual post filtering.
  """

  alias Mosslet.Timeline.{Performance.TimelineCache, UserTimelinePreferences}
  alias Mosslet.Encrypted.Users.Utils, as: EncryptionUtils
  require Logger

  @doc """
  Filters timeline posts based on user preferences.

  This is called from Timeline functions to apply content filtering.
  Expects decrypted filter preferences from LiveView or Timeline context.
  """
  def filter_timeline_posts(posts, user, filter_prefs \\ %{}) do
    Logger.info(
      "🔍 ContentFilter.filter_timeline_posts called with #{length(posts)} posts for user #{user.id}"
    )

    Logger.info("🔍 Filter preferences: #{inspect(filter_prefs)}")

    filtered_posts =
      posts
      |> filter_by_keywords(filter_prefs[:keywords] || [], user)
      |> filter_by_content_warnings(filter_prefs[:content_warnings] || %{})
      |> filter_by_muted_users(filter_prefs[:muted_users] || [])
      |> filter_by_reposts(filter_prefs[:hide_reposts] || false)

    Logger.info("🔍 Filtering result: #{length(posts)} -> #{length(filtered_posts)} posts")
    filtered_posts
  end

  @doc """
  Gets user's content filter preferences (with encrypted data).

  Returns preferences that need decryption by caller.
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

  Expects plaintext data - encryption handled by schema.
  """
  def update_filter_preferences(user_id, updates, opts \\ []) do
    current_prefs = get_user_filter_preferences(user_id)
    new_prefs = Map.merge(current_prefs, updates)

    case save_user_filter_preferences(user_id, new_prefs, opts) do
      :ok ->
        # Update cache with new preferences
        TimelineCache.cache_timeline_data(user_id, "content_filters", new_prefs)
        # Invalidate timeline caches since filtering changed
        invalidate_user_timeline_cache(user_id)
        {:ok, new_prefs}

      error ->
        error
    end
  end

  @doc """
  Adds a keyword to user's filter list.
  """
  def add_keyword_filter(user_id, keyword, current_keywords \\ [], opts \\ [])
      when is_binary(keyword) do
    keyword = String.trim(keyword) |> String.downcase()

    Logger.info("Adding keyword filter: #{keyword} for user #{user_id}")

    cond do
      keyword == "" ->
        {:error, :invalid_keyword}

      keyword not in current_keywords ->
        new_keywords = [keyword | current_keywords]
        Logger.info("New keywords list: #{inspect(new_keywords)}")
        update_filter_preferences(user_id, %{keywords: new_keywords}, opts)

      true ->
        Logger.info("Keyword already exists, skipping")
        current_prefs = get_user_filter_preferences(user_id)
        {:ok, current_prefs}
    end
  end

  @doc """
  Removes a keyword from user's filter list.
  """
  def remove_keyword_filter(user_id, keyword, current_keywords \\ [], opts \\ [])
      when is_binary(keyword) do
    keyword = String.trim(keyword) |> String.downcase()
    new_keywords = List.delete(current_keywords, keyword)
    update_filter_preferences(user_id, %{keywords: new_keywords}, opts)
  end

  @doc """
  Mutes a user by adding their user_id to the muted users list.
  """
  def mute_user(user_id, target_user_id, current_muted_users \\ [], opts \\ []) do
    Logger.info("Muting user #{target_user_id} for user #{user_id}")

    if target_user_id not in current_muted_users do
      new_muted_users = [target_user_id | current_muted_users]
      update_filter_preferences(user_id, %{muted_users: new_muted_users}, opts)
    else
      Logger.info("User already muted, skipping")
      current_prefs = get_user_filter_preferences(user_id)
      {:ok, current_prefs}
    end
  end

  @doc """
  Unmutes a user by removing their user_id from the muted users list.
  """
  def unmute_user(user_id, target_user_id, current_muted_users \\ [], opts \\ []) do
    Logger.info("Unmuting user #{target_user_id} for user #{user_id}")
    new_muted_users = List.delete(current_muted_users, target_user_id)
    update_filter_preferences(user_id, %{muted_users: new_muted_users}, opts)
  end

  @doc """
  Toggles content warning filter settings.
  """
  def toggle_content_warning_filter(user_id, filter_type, opts \\ []) do
    current_prefs = get_user_filter_preferences(user_id)
    current_cw_settings = current_prefs.content_warnings || %{}

    new_setting = not Map.get(current_cw_settings, filter_type, false)
    new_cw_settings = Map.put(current_cw_settings, filter_type, new_setting)

    update_filter_preferences(user_id, %{content_warnings: new_cw_settings}, opts)
  end

  @doc """
  Toggles repost hiding.
  """
  def toggle_repost_filter(user_id, opts \\ []) do
    current_prefs = get_user_filter_preferences(user_id)
    new_setting = not Map.get(current_prefs, :hide_reposts, false)
    update_filter_preferences(user_id, %{hide_reposts: new_setting}, opts)
  end

  # Private functions for filtering

  defp filter_by_keywords(posts, [], _user), do: posts

  defp filter_by_keywords(posts, keywords, user) do
    # Filter posts by content warning category (easier than decrypting post body)
    Logger.info("Filtering #{length(posts)} posts with #{length(keywords)} keyword filters")

    # Convert keywords to lowercase MapSet for O(1) lookup performance
    keyword_set = keywords |> Enum.map(&String.downcase/1) |> MapSet.new()

    Enum.filter(posts, fn post ->
      not post_content_warning_matches_keywords?(post, keyword_set, user)
    end)
  end

  # Check if post's content warning category matches any filter keywords
  # Uses hash-based exact matching for performance and to avoid decryption
  defp post_content_warning_matches_keywords?(post, keyword_set, _user) do
    Logger.info(
      "🔍 Checking post #{post.id} - content_warning?: #{post.content_warning?}, has category_hash?: #{not is_nil(post.content_warning_category_hash)}"
    )

    cond do
      # No content warning - doesn't match keyword filters
      not post.content_warning? or is_nil(post.content_warning_category_hash) ->
        Logger.info("📝 Post #{post.id} has no content warning or hash, skipping")
        false

      # Has content warning hash - check if it matches any keyword (O(1) lookup)
      true ->
        Logger.info(
          "🔎 Post #{post.id} has content warning hash: #{post.content_warning_category_hash}"
        )

        # Direct O(1) lookup in MapSet - much faster than Enum.any?
        match_found = MapSet.member?(keyword_set, post.content_warning_category_hash)

        Logger.info("✅ Post #{post.id} keyword match result: #{match_found}")
        match_found
    end
  end

  defp filter_by_content_warnings(posts, cw_settings) do
    hide_all = Map.get(cw_settings, :hide_all, false)

    if hide_all do
      Enum.filter(posts, fn post ->
        not Map.get(post, :content_warning?, false)
      end)
    else
      posts
    end
  end

  defp filter_by_muted_users(posts, []), do: posts

  defp filter_by_muted_users(posts, muted_user_ids) do
    Enum.filter(posts, fn post ->
      post.user_id not in muted_user_ids
    end)
  end

  defp filter_by_reposts(posts, false), do: posts

  defp filter_by_reposts(posts, true) do
    Enum.filter(posts, fn post ->
      not Map.get(post, :repost, false)
    end)
  end

  # Private functions for data persistence

  defp load_user_filter_preferences(user_id) do
    Logger.info("Loading user filter preferences for user #{user_id}")

    case Mosslet.Repo.get_by(UserTimelinePreferences, user_id: user_id) do
      nil ->
        Logger.info("No preferences found, returning defaults")

        %{
          keywords: [],
          muted_users: [],
          content_warnings: %{hide_all: false},
          hide_reposts: false,
          raw_preferences: nil
        }

      prefs ->
        Logger.info("Found preferences record")
        # Return structure that matches our filtering expectations
        # Decryption will be handled by LiveView with session key
        %{
          # Will be decrypted in LiveView
          keywords: [],
          # Will be decrypted in LiveView  
          muted_users: [],
          content_warnings: %{hide_all: prefs.hide_mature_content || false},
          hide_reposts: prefs.hide_reposts || false,
          # Include raw for LiveView decryption
          raw_preferences: prefs
        }
    end
  end

  defp save_user_filter_preferences(user_id, preferences, opts) do
    Logger.info("Saving filter preferences for user #{user_id}: #{inspect(preferences)}")

    # Get or create user timeline preferences
    prefs =
      case Mosslet.Repo.get_by(UserTimelinePreferences, user_id: user_id) do
        nil -> %UserTimelinePreferences{user_id: user_id}
        existing -> existing
      end

    # Prepare data for schema encryption
    attrs = %{}

    # Keywords (JSON encode for encryption)
    attrs =
      if Map.has_key?(preferences, :keywords) do
        keywords_json =
          if length(preferences.keywords) > 0 do
            Jason.encode!(preferences.keywords)
          else
            nil
          end

        Map.put(attrs, :mute_keywords, keywords_json)
      else
        attrs
      end

    # Muted users (JSON encode for encryption)
    attrs =
      if Map.has_key?(preferences, :muted_users) do
        muted_users_json =
          if length(preferences.muted_users) > 0 do
            Jason.encode!(preferences.muted_users)
          else
            nil
          end

        Map.put(attrs, :muted_users, muted_users_json)
      else
        attrs
      end

    # Content warning settings
    attrs =
      if Map.has_key?(preferences, :content_warnings) do
        Map.put(attrs, :hide_mature_content, preferences.content_warnings[:hide_all] || false)
      else
        attrs
      end

    # Repost settings
    attrs =
      if Map.has_key?(preferences, :hide_reposts) do
        Map.put(attrs, :hide_reposts, preferences.hide_reposts)
      else
        attrs
      end

    # Update preferences using schema encryption
    changeset = UserTimelinePreferences.changeset(prefs, attrs, opts)

    case Mosslet.Repo.transaction_on_primary(fn ->
           Mosslet.Repo.insert_or_update(changeset)
         end) do
      {:ok, {:ok, _updated_prefs}} ->
        Logger.info("Successfully saved filter preferences")
        :ok

      {:ok, {:error, changeset}} ->
        Logger.error("Failed to save filter preferences: #{inspect(changeset.errors)}")
        {:error, changeset}

      error ->
        Logger.error("Transaction failed: #{inspect(error)}")
        {:error, :transaction_failed}
    end
  end

  defp invalidate_user_timeline_cache(user_id) do
    TimelineCache.invalidate_timeline(user_id, :all)
  end
end
