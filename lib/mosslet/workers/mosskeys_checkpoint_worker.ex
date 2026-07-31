defmodule Mosslet.Workers.MosskeysCheckpointWorker do
  @moduledoc """
  Signs and publishes a checkpoint (signed tree head) for the mosslet
  namespace's mosskeys transparency log, on a cron (every 5 minutes).

  This is the anchor the whole verification UX stands on: a relying party can
  only verify an inclusion proof against a SIGNED checkpoint, so key publishes
  are not independently verifiable until a checkpoint covers them. The worker:

    1. Fetches the current tree head (`Mosslet.Mosskeys.request_checkpoint_head/0`
       — phase 1 of the client-signing handshake).
    2. Skips when the latest signed checkpoint already covers that size
       (nothing new appended since the last run).
    3. Signs the head LOCALLY with the namespace's checkpoint signing key
       (`MOSSKEYS_CHECKPOINT_SK`, a hybrid ML-DSA + Ed25519 composite secret
       key) via `MetamorphicLog.Checkpoint.sign_dual/5` — producing a dual-line
       C2SP note (hybrid + classical Ed25519) that both PQ-aware verifiers and
       stock C2SP witness software can verify.
    4. Publishes the note (phase 2). The mosskeys server VERIFIES the note
       against the namespace's public key and asserts it commits to the
       server's current head before persisting — the server never signs.

  The signing key stays on our side (BYOK): mosskeys holds only the namespace's
  public verifier key. Only public material (origin, size, root, signature)
  crosses the wire.

  Skips quietly when `MOSSKEYS_NAMESPACE_TOKEN` / `MOSSKEYS_CHECKPOINT_SK` are
  unset (dev) or when the log is still empty (nothing to checkpoint yet — the
  first publish job makes the first checkpoint possible).
  """

  use Oban.Worker,
    queue: :mosskeys,
    max_attempts: 3,
    priority: 2

  require Logger

  alias Mosslet.Mosskeys

  @impl Oban.Worker
  def perform(_job) do
    with :ok <- ensure_configured(),
         {:ok, head} <- fetch_head(),
         :ok <- ensure_tree_advanced(head),
         {:ok, note} <- sign_checkpoint(head),
         :ok <- publish(note, head) do
      Logger.info(
        "[MosskeysCheckpointWorker] signed + published checkpoint at size #{head.size} (origin=#{head.origin})"
      )

      :ok
    else
      :skip ->
        :ok

      {:discard, reason} ->
        {:discard, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ensure_configured do
    case {System.get_env("MOSSKEYS_NAMESPACE_TOKEN"), checkpoint_sk()} do
      {token, _sk} when token in [nil, ""] ->
        Logger.debug("[MosskeysCheckpointWorker] MOSSKEYS_NAMESPACE_TOKEN not set, skipping")
        :skip

      {_token, nil} ->
        Logger.debug("[MosskeysCheckpointWorker] MOSSKEYS_CHECKPOINT_SK not set, skipping")
        :skip

      {_token, _sk} ->
        :ok
    end
  end

  defp fetch_head do
    case Mosskeys.request_checkpoint_head() do
      {:ok, head} ->
        {:ok, head}

      {:error, 409} ->
        # Phase 1 conflicts only when the log is still empty — nothing to
        # checkpoint yet. The first key publish makes the first checkpoint
        # possible; the next cron tick picks it up.
        Logger.debug("[MosskeysCheckpointWorker] log is empty, nothing to checkpoint yet")
        :skip

      {:error, reason} ->
        Logger.warning("[MosskeysCheckpointWorker] head request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Sign only when the tree has entries the latest signed checkpoint does not
  # yet cover. With no checkpoint at all, every entry is uncovered.
  defp ensure_tree_advanced(head) do
    case Mosskeys.fetch_latest_checkpoint() do
      {:error, :not_found} ->
        :ok

      {:ok, %{size: size}} when is_integer(size) and size >= head.size ->
        Logger.debug(
          "[MosskeysCheckpointWorker] checkpoint already current at size #{size}, skipping"
        )

        :skip

      {:ok, _checkpoint} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "[MosskeysCheckpointWorker] latest-checkpoint fetch failed: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp sign_checkpoint(head) do
    case MetamorphicLog.Checkpoint.sign_dual(
           head.origin,
           head.size,
           head.root,
           head.name || head.origin,
           checkpoint_sk()
         ) do
      {:ok, note} ->
        {:ok, note}

      {:error, reason} ->
        # A signing failure means the configured key is malformed (or of the
        # wrong suite) — retrying cannot fix configuration. Discard loudly.
        Logger.error(
          "[MosskeysCheckpointWorker] checkpoint signing failed (check MOSSKEYS_CHECKPOINT_SK): #{inspect(reason)}"
        )

        {:discard, reason}
    end
  end

  defp publish(note, head) do
    case Mosskeys.publish_checkpoint(note) do
      :ok ->
        :ok

      {:error, 409} ->
        # The head advanced between phase 1 and phase 2 — the retry re-fetches
        # fresh material and re-signs, so this self-heals.
        Logger.info(
          "[MosskeysCheckpointWorker] head advanced past size #{head.size}, re-signing on retry"
        )

        {:error, :head_mismatch}

      {:error, reason} ->
        Logger.warning("[MosskeysCheckpointWorker] checkpoint publish failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp checkpoint_sk do
    case System.get_env("MOSSKEYS_CHECKPOINT_SK") do
      sk when is_binary(sk) and sk != "" -> sk
      _ -> nil
    end
  end
end
