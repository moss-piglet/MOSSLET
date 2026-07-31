defmodule Mosslet.Workers.MosskeysCheckpointWorker do
  @moduledoc """
  Oban worker that publishes a signed checkpoint to the mosskeys transparency log.

  Two-phase protocol:
    1. Request the current tree head from mosskeys (`POST /log/checkpoints`)
    2. Sign it locally with the checkpoint signing key
    3. Publish the signed note (`POST /log/checkpoints`)

  The signing step requires `MOSSKEYS_CHECKPOINT_SK` to be configured and a
  checkpoint-signing module (e.g. `MetamorphicLog.Checkpoint.sign_dual`) to be
  available — until then, the worker logs the head data and skips gracefully.

  Configured as a cron job in Oban config when the signing key is available.
  """

  use Oban.Worker,
    queue: :mosskeys_checkpoint,
    max_attempts: 3,
    priority: 2

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    case check_token() do
      {:ok, _} ->
        case Mosslet.Mosskeys.request_checkpoint_head() do
          {:ok, head} ->
            maybe_log_head(head)
            :ok

          {:error, reason} ->
            Logger.warning("[MosskeysCheckpointWorker] head request failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :missing_token} ->
        Logger.debug("[MosskeysCheckpointWorker] MOSSKEYS_NAMESPACE_TOKEN not set, skipping")
        :ok
    end
  end

  defp check_token do
    case System.fetch_env("MOSSKEYS_NAMESPACE_TOKEN") do
      {:ok, t} when t != "" -> {:ok, true}
      _ -> {:error, :missing_token}
    end
  end

  defp maybe_log_head(head) do
    if System.get_env("MOSSKEYS_CHECKPOINT_SK") do
      Logger.info(
        "[MosskeysCheckpointWorker] MOSSKEYS_CHECKPOINT_SK set — " <>
          "would sign checkpoint at size #{head.size}, origin=#{head.origin}"
      )
    else
      Logger.debug("[MosskeysCheckpointWorker] MOSSKEYS_CHECKPOINT_SK not set, skipping signing")
    end
  end
end
