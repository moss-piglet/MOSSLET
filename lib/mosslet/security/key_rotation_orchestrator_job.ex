defmodule Mosslet.Security.KeyRotationOrchestratorJob do
  @moduledoc """
  Oban job that orchestrates the key rotation process.

  This job:
  1. Checks if there are any pending/active rotations
  2. If stalled rotations exist, logs warnings
  3. Spawns worker jobs to process batches

  Schedule via Oban Cron (e.g., weekly monitoring):
  ```
  {"0 3 * * 0", Mosslet.Security.KeyRotationOrchestratorJob}
  ```
  """
  use Oban.Worker, queue: :security, max_attempts: 3

  alias Mosslet.Security.KeyRotation
  alias Mosslet.Security.KeyRotationWorkerJob

  require Logger

  @batch_size 100
  @stalled_threshold_minutes 60

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    action = Map.get(args, "action", "monitor")

    case action do
      "start_rotation" ->
        case Map.get(args, "from_tag") do
          nil -> start_rotation()
          from_tag -> start_rotation(from_tag)
        end

      "monitor" ->
        monitor_and_continue()

      "process_schema" ->
        schema_name = Map.fetch!(args, "schema_name")
        progress_id = Map.fetch!(args, "progress_id")
        process_schema(schema_name, progress_id)

      _ ->
        Logger.warning("[KeyRotationOrchestrator] Unknown action: #{action}")
        :ok
    end
  end

  defp start_rotation do
    Logger.info("[KeyRotationOrchestrator] Starting rotation from base key to new key")

    case KeyRotation.initiate_rotation() do
      {:ok, progress_records} ->
        Logger.info(
          "[KeyRotationOrchestrator] Created #{length(progress_records)} progress records"
        )

        enqueue_schema_jobs(progress_records)
        :ok

      {:error, :no_new_key_configured} ->
        Logger.warning("[KeyRotationOrchestrator] No CLOAK_KEY_NEW configured")
        :ok

      {:error, :same_cipher} ->
        Logger.warning("[KeyRotationOrchestrator] Cannot rotate to same cipher")
        :ok

      {:error, errors} ->
        Logger.error("[KeyRotationOrchestrator] Failed to initiate: #{inspect(errors)}")
        {:error, "Failed to initiate rotation"}
    end
  end

  defp start_rotation(from_tag) do
    Logger.info("[KeyRotationOrchestrator] Starting rotation from cipher: #{from_tag}")

    case KeyRotation.initiate_rotation(from_tag) do
      {:ok, progress_records} ->
        Logger.info(
          "[KeyRotationOrchestrator] Created #{length(progress_records)} progress records"
        )

        enqueue_schema_jobs(progress_records)
        :ok

      {:error, :same_cipher} ->
        Logger.warning("[KeyRotationOrchestrator] Cannot rotate to same cipher")
        :ok

      {:error, errors} ->
        Logger.error("[KeyRotationOrchestrator] Failed to initiate: #{inspect(errors)}")
        {:error, "Failed to initiate rotation"}
    end
  end

  defp monitor_and_continue do
    active_rotations = KeyRotation.list_active_rotations()

    if Enum.empty?(active_rotations) do
      Logger.debug("[KeyRotationOrchestrator] No active rotations")
      :ok
    else
      Logger.info("[KeyRotationOrchestrator] Found #{length(active_rotations)} active rotations")

      Enum.each(active_rotations, fn progress ->
        check_and_resume(progress)
      end)

      :ok
    end
  end

  defp check_and_resume(progress) do
    stalled_threshold =
      DateTime.utc_now()
      |> DateTime.add(-@stalled_threshold_minutes, :minute)

    is_stalled =
      progress.status == "in_progress" &&
        progress.updated_at &&
        DateTime.compare(progress.updated_at, stalled_threshold) == :lt

    cond do
      is_stalled ->
        Logger.warning(
          "[KeyRotationOrchestrator] Stalled rotation detected: #{progress.schema_name}"
        )

        enqueue_worker_job(progress)

      progress.status == "pending" ->
        Logger.info(
          "[KeyRotationOrchestrator] Resuming pending rotation: #{progress.schema_name}"
        )

        KeyRotation.start_rotation(progress.id)
        enqueue_worker_job(progress)

      progress.status == "in_progress" ->
        Logger.debug("[KeyRotationOrchestrator] Rotation in progress: #{progress.schema_name}")
        :ok
    end
  end

  defp enqueue_schema_jobs(progress_records) do
    Enum.each(progress_records, fn progress ->
      enqueue_worker_job(progress)
    end)
  end

  defp enqueue_worker_job(progress) do
    %{
      "progress_id" => progress.id,
      "schema_name" => progress.schema_name,
      "batch_size" => @batch_size,
      "after_id" => progress.last_processed_id
    }
    |> KeyRotationWorkerJob.new()
    |> Oban.insert()
  end

  defp process_schema(schema_name, progress_id) do
    enqueue_worker_job(%{id: progress_id, schema_name: schema_name, last_processed_id: nil})
    :ok
  end
end
