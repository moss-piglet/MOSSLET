defmodule Mosslet.Security.KeyRotationWorkerJob do
  @moduledoc """
  Oban worker that processes batches of records for key rotation.

  This job:
  1. Fetches a batch of records from the specified schema
  2. Re-encrypts each record's encrypted fields
  3. Updates progress tracking
  4. Enqueues the next batch if more records remain

  Uses throttling to avoid overwhelming the database:
  - Processes records one at a time within a batch
  - Adds delay between batches via scheduled_at
  """
  use Oban.Worker, queue: :security, max_attempts: 5

  alias Mosslet.Security.KeyRotation
  alias Mosslet.Security.KeyRotationProgress
  alias Mosslet.Repo

  require Logger

  @batch_delay_seconds 5

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "progress_id" => progress_id,
          "schema_name" => schema_name,
          "batch_size" => batch_size,
          "after_id" => after_id
        }
      }) do
    progress = Repo.get(KeyRotationProgress, progress_id)

    cond do
      is_nil(progress) ->
        Logger.warning("[KeyRotationWorker] Progress record not found: #{progress_id}")
        :ok

      progress.status == "completed" ->
        Logger.info("[KeyRotationWorker] Rotation already completed: #{schema_name}")
        :ok

      progress.status == "failed" ->
        Logger.warning("[KeyRotationWorker] Rotation failed, not processing: #{schema_name}")
        :ok

      true ->
        process_batch(progress, schema_name, batch_size, after_id)
    end
  end

  defp process_batch(progress, schema_name, batch_size, after_id) do
    schema_module = resolve_schema_module(schema_name)

    if is_nil(schema_module) do
      Logger.error("[KeyRotationWorker] Unknown schema: #{schema_name}")
      KeyRotation.fail_rotation(progress.id, "Unknown schema: #{schema_name}")
      {:error, "Unknown schema"}
    else
      do_process_batch(progress, schema_module, batch_size, after_id)
    end
  end

  defp do_process_batch(progress, schema_module, batch_size, after_id) do
    case KeyRotation.start_rotation(progress.id) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end

    records = KeyRotation.fetch_batch(schema_module, batch_size, after_id)

    if Enum.empty?(records) do
      Logger.info("[KeyRotationWorker] No more records for #{progress.schema_name}")
      KeyRotation.update_progress(progress.id, 0, after_id)
      :ok
    else
      {processed_count, failed_count, last_id} = rotate_records(records, progress)

      case KeyRotation.update_progress(progress.id, processed_count, last_id, failed_count) do
        {:ok, updated_progress} ->
          if updated_progress.status != "completed" do
            enqueue_next_batch(updated_progress, batch_size, last_id)
          else
            Logger.info("[KeyRotationWorker] Completed rotation: #{progress.schema_name}")
          end

          :ok

        {:error, reason} ->
          Logger.error("[KeyRotationWorker] Failed to update progress: #{inspect(reason)}")
          {:error, reason}
      end
    end
  rescue
    e ->
      Logger.error("[KeyRotationWorker] Error processing batch: #{Exception.message(e)}")
      KeyRotation.fail_rotation(progress.id, Exception.message(e))
      {:error, e}
  end

  defp rotate_records(records, progress) do
    Enum.reduce(records, {0, 0, nil}, fn record, {processed, failed, _last_id} ->
      case KeyRotation.rotate_record(record) do
        {:ok, _} ->
          {processed + 1, failed, record.id}

        {:error, changeset} ->
          Logger.warning(
            "[KeyRotationWorker] Failed to rotate record #{record.id} in #{progress.schema_name}: #{inspect(changeset.errors)}"
          )

          {processed, failed + 1, record.id}
      end
    end)
  end

  defp enqueue_next_batch(progress, batch_size, last_id) do
    scheduled_at = DateTime.utc_now() |> DateTime.add(@batch_delay_seconds, :second)

    %{
      "progress_id" => progress.id,
      "schema_name" => progress.schema_name,
      "batch_size" => batch_size,
      "after_id" => last_id
    }
    |> __MODULE__.new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  defp resolve_schema_module(schema_name) do
    KeyRotation.encrypted_schemas()
    |> Enum.find_value(fn {module, _table} ->
      if inspect(module) == schema_name, do: module
    end)
  end
end
