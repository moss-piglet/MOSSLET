defmodule Mosslet.Workers.MosskeysPublishWorker do
  @moduledoc """
  Publishes one key-history entry's public key material to the mosskeys
  transparency log and records the anchored tree index.

  Replaces the old fire-and-forget `Task.start` publish: anchoring a user's
  key in the public log is what lets their connections' browsers detect a
  server key-substitution, so it must survive transient failures. Oban gives
  retries with backoff; the mosskeys append is idempotent on the content
  `dedup_key`, so a retry (or the daily backfill sweep) never duplicates a
  leaf — it returns the SAME tree index.

  Only PUBLIC material (public keys + the user id as the log label) crosses
  the wire. When `MOSSKEYS_NAMESPACE_TOKEN` is not configured (dev), the job
  discards itself quietly.
  """

  use Oban.Worker,
    queue: :mosskeys,
    max_attempts: 5,
    # Dedupe enqueue storms (e.g. genesis pushed on every login) within a
    # minute; the entry row itself is the durable source of truth.
    unique: [period: 60, keys: [:user_id, :seq]]

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Mosskeys

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "seq" => seq}}) do
    with {:ok, entry} <- fetch_entry(user_id, seq),
         {:ok, index} <- publish(entry) do
      {:ok, _} = Accounts.mark_key_history_entry_anchored(entry, index)
      :ok
    else
      # A missing entry or token can never succeed on retry — discard instead
      # of burning attempts. Transient failures keep Oban's retry-with-backoff.
      {:error, reason} when reason in [:not_found, :missing_token] ->
        {:discard, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_entry(user_id, seq) do
    case Accounts.get_key_history_entry(user_id, seq) do
      nil ->
        Logger.debug(
          "[MosskeysPublishWorker] no entry for user #{user_id} seq #{seq}, discarding"
        )

        {:error, :not_found}

      entry ->
        {:ok, entry}
    end
  end

  defp publish(entry) do
    case Mosskeys.publish_key(entry.user_id, entry.entry, entry.signing_public_key) do
      {:ok, index} ->
        {:ok, index}

      {:error, :missing_token} = error ->
        Logger.debug("[MosskeysPublishWorker] MOSSKEYS_NAMESPACE_TOKEN not set, discarding")
        error

      {:error, reason} = error ->
        Logger.warning(
          "[MosskeysPublishWorker] publish failed for user #{entry.user_id} seq #{entry.seq}: #{inspect(reason)}"
        )

        error
    end
  end
end
