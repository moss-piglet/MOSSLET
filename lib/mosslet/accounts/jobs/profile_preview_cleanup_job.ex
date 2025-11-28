defmodule Mosslet.Accounts.Jobs.ProfilePreviewCleanupJob do
  @moduledoc """
  Oban job for cleaning up URL preview images from Tigris storage when profile
  website URLs change or profiles/accounts are deleted.

  🔐 PRIVACY COMPLIANT: Only stores non-sensitive metadata in job args.
  🎯 ETHICAL DESIGN: Ensures external preview images are properly cleaned up.

  SAFE JOB ARGS:
  - ✅ Connection IDs (UUIDs - not sensitive)

  NEVER STORED IN JOBS:
  - ❌ Profile content, usernames, emails
  - ❌ Encrypted data or keys
  - ❌ Personal user information

  USER AGENCY FIRST:
  - ✅ Cleans up preview images when website_url changes
  - ✅ Cleans up preview images when profiles are deleted
  - ✅ Cleans up preview images when accounts are deleted
  - ✅ Prevents storage bloat
  - ✅ Maintains data integrity
  """

  use Oban.Worker, queue: :default, max_attempts: 3
  require Logger

  alias Mosslet.Extensions.URLPreviewImageProxy

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"connection_id" => connection_id}}) do
    Logger.debug("Cleaning up preview images for profile: #{connection_id}")

    case URLPreviewImageProxy.delete_preview_images_for_post(connection_id) do
      :ok ->
        Logger.debug("Successfully deleted preview images for profile: #{connection_id}")
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to delete preview images for profile #{connection_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Schedules cleanup of URL preview images for a profile.
  🔐 PRIVACY: Only stores connection_id (UUID - non-sensitive).
  """
  def schedule_cleanup(connection_id) do
    %{"connection_id" => connection_id}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
