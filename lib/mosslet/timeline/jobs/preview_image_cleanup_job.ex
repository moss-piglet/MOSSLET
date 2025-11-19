defmodule Mosslet.Timeline.Jobs.PreviewImageCleanupJob do
  @moduledoc """
  Oban job for cleaning up URL preview images from Tigris storage when posts are deleted.

  🔐 PRIVACY COMPLIANT: Only stores non-sensitive metadata in job args.
  🎯 ETHICAL DESIGN: Ensures external preview images are properly cleaned up.

  SAFE JOB ARGS:
  - ✅ Post IDs (UUIDs - not sensitive)

  NEVER STORED IN JOBS:
  - ❌ Post content, usernames, emails
  - ❌ Encrypted data or keys
  - ❌ Personal user information

  USER AGENCY FIRST:
  - ✅ Cleans up preview images when posts are deleted
  - ✅ Prevents storage bloat
  - ✅ Maintains data integrity
  """

  use Oban.Worker, queue: :default, max_attempts: 3
  require Logger

  alias Mosslet.Extensions.URLPreviewImageProxy

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"post_id" => post_id}}) do
    Logger.debug("Cleaning up preview images for post: #{post_id}")

    case URLPreviewImageProxy.delete_preview_images_for_post(post_id) do
      :ok ->
        Logger.debug("Successfully deleted preview images for post: #{post_id}")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to delete preview images for post #{post_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Schedules cleanup of a URL preview image for a deleted post.
  🔐 PRIVACY: Only stores post_id (UUID - non-sensitive).
  """
  def schedule_cleanup(post_id) do
    %{"post_id" => post_id}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
