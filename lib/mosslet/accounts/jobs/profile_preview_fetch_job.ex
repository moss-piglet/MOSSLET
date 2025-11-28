defmodule Mosslet.Accounts.Jobs.ProfilePreviewFetchJob do
  @moduledoc """
  Oban job for asynchronously fetching and caching website URL preview images
  when a profile's website URL changes.

  🔐 PRIVACY COMPLIANT: Only stores non-sensitive metadata in job args.
  🎯 ETHICAL DESIGN: Fetches preview images in the background to improve UX.

  SAFE JOB ARGS:
  - ✅ Connection IDs (UUIDs - not sensitive)

  NEVER STORED IN JOBS:
  - ❌ Profile content, usernames, emails
  - ❌ Encrypted data or keys
  - ❌ Personal user information

  This job:
  1. Fetches the connection and its profile
  2. Decrypts the website_url and profile_key based on visibility
  3. Calls URLPreviewServer.fetch_and_cache to fetch and store the preview image
  """

  use Oban.Worker, queue: :default, max_attempts: 3
  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Extensions.URLPreviewServer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"connection_id" => connection_id}}) do
    Logger.debug("Fetching preview image for profile: #{connection_id}")

    with {:ok, connection} <- get_connection(connection_id),
         {:ok, website_url, profile_key} <- decrypt_profile_data(connection),
         :ok <- fetch_and_cache_preview(website_url, profile_key, connection_id) do
      Logger.debug("Successfully cached preview image for profile: #{connection_id}")
      :ok
    else
      {:error, :no_profile} ->
        Logger.debug("No profile found for connection: #{connection_id}")
        :ok

      {:error, :no_website_url} ->
        Logger.debug("No website URL for profile: #{connection_id}")
        :ok

      {:error, :no_profile_key} ->
        Logger.warning("No profile key for profile: #{connection_id}")
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch preview image for profile #{connection_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Schedules fetching of URL preview image for a profile.
  🔐 PRIVACY: Only stores connection_id (UUID - non-sensitive).
  """
  def schedule_fetch(connection_id) do
    %{"connection_id" => connection_id}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  defp get_connection(connection_id) do
    case Accounts.get_connection(connection_id) do
      nil -> {:error, :connection_not_found}
      connection -> {:ok, connection}
    end
  end

  defp decrypt_profile_data(connection) do
    profile = connection.profile

    cond do
      is_nil(profile) ->
        {:error, :no_profile}

      is_nil(profile.website_url) || profile.website_url == "" ->
        {:error, :no_website_url}

      is_nil(profile.profile_key) ->
        {:error, :no_profile_key}

      true ->
        decrypt_based_on_visibility(profile)
    end
  end

  defp decrypt_based_on_visibility(profile) do
    case profile.visibility do
      :public ->
        decrypt_public_profile(profile)

      _other ->
        {:error, :non_public_profile}
    end
  end

  defp decrypt_public_profile(profile) do
    profile_key = Encrypted.Users.Utils.decrypt_public_item_key(profile.profile_key)

    case profile_key do
      nil ->
        {:error, :decrypt_failed}

      key ->
        case Encrypted.Utils.decrypt(%{key: key, payload: profile.website_url}) do
          {:ok, website_url} ->
            {:ok, website_url, key}

          {:error, _reason} ->
            {:error, :decrypt_failed}
        end
    end
  end

  defp fetch_and_cache_preview(website_url, profile_key, connection_id) do
    url_hash =
      :crypto.hash(:sha3_256, "#{website_url}-#{connection_id}") |> Base.encode16(case: :lower)

    case URLPreviewServer.fetch_and_cache(website_url, url_hash, profile_key,
           profile_key: connection_id,
           timeout: 30_000
         ) do
      {:ok, _encrypted_preview} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
