defmodule Mosslet.Workers.DatabaseBackupWorker do
  @moduledoc """
  Oban worker for scheduled database backups.

  Runs daily and creates a pg_dump backup, uploads to Tigris,
  and cleans up old backups according to retention policy.
  """
  use Oban.Worker, queue: :backups, max_attempts: 3

  alias Mosslet.Backups

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    backup_type = Map.get(args, "type", "scheduled")

    Logger.info("[DatabaseBackupWorker] Starting #{backup_type} backup")

    case Backups.perform_backup(backup_type) do
      {:ok, backup} ->
        Logger.info(
          "[DatabaseBackupWorker] Backup completed: #{backup.filename} (#{format_size(backup.size_bytes)})"
        )

        :ok

      {:error, reason} ->
        Logger.error("[DatabaseBackupWorker] Backup failed: #{reason}")
        {:error, reason}
    end
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  def enqueue_manual_backup do
    %{"type" => "manual"}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
