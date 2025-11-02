defmodule Mosslet.Logs.Jobs.LogCleanupJob do
  @moduledoc """
  Oban job for cleaning up old logs to ensure privacy compliance.

  This job deletes logs older than 7 days and any logs containing sensitive metadata.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "cleanup_old_logs"}}) do
    Logger.info("Starting scheduled log cleanup...")

    try do
      # Delete logs older than 7 days
      {count, _} = Mosslet.Logs.delete_logs_older_than(7)

      # Also clean up any remaining sensitive logs (email metadata)
      {sensitive_count, _} = Mosslet.Logs.delete_sensitive_logs()

      Logger.info(
        "Log cleanup completed. Deleted #{count} old logs and #{sensitive_count} sensitive logs."
      )

      :ok
    rescue
      error ->
        Logger.error("Log cleanup failed: #{inspect(error)}")
        {:error, error}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("Unknown log cleanup job args: #{inspect(args)}")
    :ok
  end
end
