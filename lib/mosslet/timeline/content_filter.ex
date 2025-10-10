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

    # IMPORTANT: For database operations, we should NOT pass encrypted data
    # The encrypted data should only be used for storage, not for filtering
    # Database filtering happens with decrypted data in the LiveView layer

    case save_user_filter_preferences(user_id, new_prefs, opts) do
      :ok ->
        # Update cache with new preferences (this should contain encrypted data for storage)
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

    if keyword not in current_keywords do
      new_keywords = [keyword | current_keywords]
      update_filter_preferences(user_id, %{keywords: new_keywords}, opts)
    else
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
    if target_user_id not in current_muted_users do
      new_muted_users = [target_user_id | current_muted_users]
      update_filter_preferences(user_id, %{muted_users: new_muted_users}, opts)
    else
      current_prefs = load_user_filter_preferences(user_id)
      {:ok, current_prefs}
    end
  end

  @doc """
  Unmutes a user by removing their user_id from the muted users list.
  """
  def unmute_user(user_id, target_user_id, current_muted_users \\ [], opts \\ []) do
    new_muted_users = List.delete(current_muted_users, target_user_id)
    update_filter_preferences(user_id, %{muted_users: new_muted_users}, opts)
  end

  @doc """
  Toggles content warning filter settings.
  """
  def toggle_content_warning_filter(user_id, filter_type, opts \\ []) do
    current_prefs = load_user_filter_preferences(user_id)
    # load_user_filter_preferences/1 always provides content_warnings key
    current_cw_settings = current_prefs.content_warnings

    new_setting = not Map.get(current_cw_settings, filter_type, false)
    new_cw_settings = Map.put(current_cw_settings, filter_type, new_setting)

    update_filter_preferences(user_id, %{content_warnings: new_cw_settings}, opts)
  end

  # Private functions for data persistence

  defp load_user_filter_preferences(user_id) do
    case Mosslet.Repo.get_by(UserTimelinePreference, user_id: user_id) do
      nil ->
        %{
          keywords: [],
          muted_users: [],
          content_warnings: %{hide_all: false, hide_mature: false},
          hide_reposts: false,
          raw_preferences: nil
        }

      prefs ->
        # Return structure that matches our filtering expectations
        # CRITICAL: Never return encrypted data here as it gets passed to database filters
        # The LiveView layer handles decryption separately
        %{
          # Always return empty arrays - encryption/decryption is handled in LiveView
          keywords: [],
          muted_users: [],
          content_warnings: %{
            hide_all: prefs.hide_content_warnings || false,
            hide_mature: prefs.hide_mature_content || false
          },
          hide_reposts: prefs.hide_reposts || false,
          # Include raw for LiveView decryption
          raw_preferences: prefs
        }
    end
  end

  defp save_user_filter_preferences(user_id, preferences, opts) do
    # Get or create user timeline preferences
    prefs =
      case Mosslet.Repo.get_by(UserTimelinePreference, user_id: user_id) do
        nil -> %UserTimelinePreference{user_id: user_id}
        existing -> existing
      end

    # Prepare data for schema encryption
    # CRITICAL FIX: Only update fields that are explicitly being changed
    # Preserve existing encrypted data for fields not being updated

    # Keywords - only update if preferences explicitly contains non-empty keywords
    keywords_list =
      if preferences[:keywords] && length(preferences[:keywords]) > 0 do
        preferences[:keywords]
      else
        # Preserve existing keywords, but decrypt them first since schema will re-encrypt
        if prefs.mute_keywords && length(prefs.mute_keywords) > 0 do
          user = opts[:user]
          key = opts[:key]

          if user && key do
            Enum.map(prefs.mute_keywords, fn encrypted_keyword ->
              Mosslet.Encrypted.Users.Utils.decrypt_user_data(encrypted_keyword, user, key)
            end)
            |> Enum.reject(&is_nil/1)
          else
            # If no user/key provided, return empty to avoid corruption
            []
          end
        else
          []
        end
      end

    # Muted users - only update if preferences explicitly contains muted users
    muted_users_list =
      if preferences[:muted_users] && length(preferences[:muted_users]) > 0 do
        preferences[:muted_users]
      else
        # Preserve existing muted users, but decrypt them first since schema will re-encrypt
        if prefs.muted_users && length(prefs.muted_users) > 0 do
          user = opts[:user]
          key = opts[:key]

          if user && key do
            Enum.map(prefs.muted_users, fn encrypted_user_id ->
              Mosslet.Encrypted.Users.Utils.decrypt_user_data(encrypted_user_id, user, key)
            end)
            |> Enum.reject(&is_nil/1)
          else
            # If no user/key provided, return empty to avoid corruption
            []
          end
        else
          []
        end
      end

    # Build attrs map with all preferences - now using separate fields
    attrs = %{
      mute_keywords: keywords_list,
      muted_users: muted_users_list,
      hide_content_warnings: preferences.content_warnings[:hide_all] || false,
      hide_mature_content: preferences.content_warnings[:hide_mature] || false,
      hide_reposts: preferences.hide_reposts
    }

    # Update preferences using schema encryption
    changeset = UserTimelinePreference.changeset(prefs, attrs, opts)

    case Mosslet.Repo.transaction_on_primary(fn ->
           Mosslet.Repo.insert_or_update(changeset)
         end) do
      {:ok, {:ok, _updated_prefs}} ->
        :ok

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      _error ->
        {:error, :transaction_failed}
    end
  end

  defp invalidate_user_timeline_cache(user_id) do
    TimelineCache.invalidate_timeline(user_id, :all)
  end
end
