defmodule Mosslet.Timeline.ContentFilter do
  @moduledoc """
  Content filtering preference management system.

  Handles user filter preferences for keywords, content warnings, and user muting.
  All actual post filtering is now done at the database level in Timeline.ex for better performance.
  """

  alias Mosslet.Timeline.{Performance.TimelineCache, UserTimelinePreference}
  require Logger

  @doc """
  Updates user's content filter preferences.

  Expects plaintext data - encryption handled by schema.
  """
  def update_filter_preferences(user_id, updates, opts \\ []) do
    current_prefs = load_user_filter_preferences(user_id)
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
        current_prefs = load_user_filter_preferences(user_id)
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
      current_prefs = load_user_filter_preferences(user_id)
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
    current_prefs = load_user_filter_preferences(user_id)
    current_cw_settings = current_prefs.content_warnings || %{}

    new_setting = not Map.get(current_cw_settings, filter_type, false)
    new_cw_settings = Map.put(current_cw_settings, filter_type, new_setting)

    update_filter_preferences(user_id, %{content_warnings: new_cw_settings}, opts)
  end

  # Private functions for data persistence

  defp load_user_filter_preferences(user_id) do
    Logger.info("Loading user filter preferences for user #{user_id}")

    case Mosslet.Repo.get_by(UserTimelinePreference, user_id: user_id) do
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
      case Mosslet.Repo.get_by(UserTimelinePreference, user_id: user_id) do
        nil -> %UserTimelinePreference{user_id: user_id}
        existing -> existing
      end

    # Prepare data for schema encryption
    attrs = %{}

    # Keywords (StringList handles encoding/encryption automatically)
    attrs =
      if Map.has_key?(preferences, :keywords) do
        # StringList type accepts list directly, no need for JSON encoding
        keywords_list =
          if length(preferences.keywords) > 0 do
            preferences.keywords
          else
            []
          end

        Map.put(attrs, :mute_keywords, keywords_list)
      else
        attrs
      end

    # Muted users (still using manual encoding for now - could be converted to IntegerList later)
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
    changeset = UserTimelinePreference.changeset(prefs, attrs, opts)

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
