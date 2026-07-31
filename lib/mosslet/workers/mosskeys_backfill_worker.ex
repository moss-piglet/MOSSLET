defmodule Mosslet.Workers.MosskeysBackfillWorker do
  @moduledoc """
  Daily sweep that enqueues a `MosskeysPublishWorker` for every key-history
  entry not yet anchored in the mosskeys transparency log
  (`mosskeys_index IS NULL`), oldest first.

  This is the self-healing backstop for the publish path: it re-anchors entries
  whose publish job exhausted retries (e.g. a mosskeys outage) and heals any
  entries written while publishing was unavailable. Publishing is idempotent on
  the mosskeys content `dedup_key`, and already-anchored entries are excluded
  by the scan, so the sweep is cheap and safe to re-run.

  Skips quietly when `MOSSKEYS_NAMESPACE_TOKEN` is not configured (dev).
  """

  use Oban.Worker,
    queue: :mosskeys,
    max_attempts: 2,
    # One sweep at a time, cluster-wide, even if the cron fires while a
    # previous sweep is still draining the publish queue.
    unique: [period: 300]

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Workers.MosskeysPublishWorker

  @batch_size 500

  @impl Oban.Worker
  def perform(_job) do
    if token_configured?() do
      entries = Accounts.list_unanchored_key_history_entries(@batch_size)

      jobs =
        Enum.map(entries, fn entry ->
          MosskeysPublishWorker.new(%{user_id: entry.user_id, seq: entry.seq})
        end)

      Oban.insert_all(jobs)

      if entries != [] do
        Logger.info("[MosskeysBackfillWorker] enqueued #{length(entries)} unanchored entries")
      end

      # A full batch means more are waiting — re-enqueue ourselves immediately
      # (uniqueness dedupes within the period) rather than waiting a day.
      if length(entries) == @batch_size do
        %{}
        |> __MODULE__.new()
        |> Oban.insert()
      end

      :ok
    else
      Logger.debug("[MosskeysBackfillWorker] MOSSKEYS_NAMESPACE_TOKEN not set, skipping")
      :ok
    end
  end

  defp token_configured? do
    case System.get_env("MOSSKEYS_NAMESPACE_TOKEN") do
      token when is_binary(token) and token != "" -> true
      _ -> false
    end
  end
end
