defmodule Mosslet.Workers.KeyRotationWorker do
  @moduledoc """
  Oban worker for processing key rotation batches.

  Processes records in batches for a specific schema rotation.
  Re-enqueues itself until all records are processed.
  """
  use Oban.Worker, queue: :key_rotation, max_attempts: 3

  alias Mosslet.Security.KeyRotation
  alias Mosslet.Security.KeyRotationProgress
  alias Mosslet.Repo.Local, as: Repo

  require Logger

  @batch_size 100

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"progress_id" => progress_id}}) do
    progress = Repo.get(KeyRotationProgress, progress_id)

    cond do
      is_nil(progress) ->
        Logger.warning("[KeyRotationWorker] Progress record not found: #{progress_id}")
        :ok

      progress.status == "completed" ->
        Logger.info("[KeyRotationWorker] Rotation already completed for #{progress.schema_name}")
        :ok

      progress.status == "cancelled" ->
        Logger.info("[KeyRotationWorker] Rotation was cancelled for #{progress.schema_name}")
        :ok

      true ->
        process_batch(progress)
    end
  end

  defp process_batch(progress) do
    if progress.status == "pending" do
      KeyRotation.start_rotation(progress.id)
    end

    schema_module = Module.concat([progress.schema_name])
    records = KeyRotation.fetch_batch(schema_module, @batch_size, progress.last_processed_id)

    case records do
      [] ->
        KeyRotation.complete_rotation(progress.id)
        Logger.info("[KeyRotationWorker] Completed rotation for #{progress.schema_name}")
        :ok

      records ->
        {processed, failed, last_id} = process_records(records, progress.id)

        {:ok, updated_progress} =
          KeyRotation.update_progress(progress.id, processed, last_id, failed)

        if updated_progress.status != "completed" do
          schedule_next_batch(progress.id)
        end

        :ok
    end
  rescue
    error ->
      Logger.error("[KeyRotationWorker] Error processing batch: #{inspect(error)}")
      KeyRotation.fail_rotation(progress.id, Exception.message(error))
      {:error, error}
  end

  defp process_records(records, progress_id) do
    Enum.reduce(records, {0, 0, nil}, fn record, {processed, failed, _last_id} ->
      case KeyRotation.rotate_record(record) do
        {:ok, _} ->
          {processed + 1, failed, record.id}

        {:error, reason} ->
          Logger.warning(
            "[KeyRotationWorker] Failed to rotate record #{record.id}: #{inspect(reason)}"
          )

          KeyRotation.append_error(progress_id, "Record #{record.id}: #{inspect(reason)}")
          {processed, failed + 1, record.id}
      end
    end)
  end

  defp schedule_next_batch(progress_id) do
    %{progress_id: progress_id}
    |> __MODULE__.new(schedule_in: 1)
    |> Oban.insert()
  end

  @doc """
  Starts rotation jobs for all pending/in_progress rotations.
  """
  def enqueue_all_active do
    KeyRotation.list_active_rotations()
    |> Enum.map(fn progress ->
      %{progress_id: progress.id}
      |> __MODULE__.new()
      |> Oban.insert()
    end)
  end

  @doc """
  Starts a rotation job for a specific progress record.
  """
  def enqueue(progress_id) do
    %{progress_id: progress_id}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
