defmodule Mosslet.Backups do
  @moduledoc """
  Context for managing database backups.

  Handles creating pg_dump backups, uploading to Tigris, and
  implementing smart retention (7 daily + 4 weekly).
  """
  import Ecto.Query

  alias Mosslet.Backups.DatabaseBackup
  alias Mosslet.Encrypted.Session
  alias Mosslet.Repo

  require Logger

  @backup_bucket_prefix "backups/db"
  @daily_retention 7
  @weekly_retention 4

  def list_backups(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    DatabaseBackup
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_backup!(id), do: Repo.get!(DatabaseBackup, id)

  def get_latest_backup do
    DatabaseBackup
    |> where([b], b.status == "completed")
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def create_backup(attrs) do
    %DatabaseBackup{}
    |> DatabaseBackup.changeset(attrs)
    |> Repo.insert()
  end

  def update_backup(%DatabaseBackup{} = backup, attrs) do
    backup
    |> DatabaseBackup.changeset(attrs)
    |> Repo.update()
  end

  def delete_backup(%DatabaseBackup{} = backup) do
    if backup.status == "completed" and backup.storage_key do
      delete_backup_from_storage(backup)
    end

    Repo.delete(backup)
  end

  def count_backups_by_status do
    DatabaseBackup
    |> group_by([b], b.status)
    |> select([b], {b.status, count(b.id)})
    |> Repo.all()
    |> Map.new()
  end

  def total_backup_size do
    DatabaseBackup
    |> where([b], b.status == "completed")
    |> select([b], sum(b.size_bytes))
    |> Repo.one() || 0
  end

  def perform_backup(type \\ "scheduled") do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic) |> String.slice(0, 15)
    filename = "mosslet_#{timestamp}.sql.gz"
    storage_key = "#{@backup_bucket_prefix}/#{filename}"

    {:ok, backup} =
      create_backup(%{
        filename: filename,
        storage_key: storage_key,
        size_bytes: 0,
        status: "in_progress",
        backup_type: type
      })

    case do_pg_dump_and_upload(storage_key) do
      {:ok, size_bytes} ->
        {:ok, updated_backup} =
          update_backup(backup, %{status: "completed", size_bytes: size_bytes})

        broadcast_backup_update(:backup_completed, updated_backup)
        cleanup_old_backups()
        {:ok, updated_backup}

      {:error, reason} ->
        {:ok, updated_backup} =
          update_backup(backup, %{status: "failed", error_message: reason})

        broadcast_backup_update(:backup_failed, updated_backup)
        {:error, reason}
    end
  end

  defp broadcast_backup_update(event, backup) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "backups", {event, backup})
  end

  defp do_pg_dump_and_upload(storage_key) do
    database_url = System.get_env("DATABASE_URL")

    if is_nil(database_url) do
      {:error, "DATABASE_URL not set"}
    else
      tmp_file = "/tmp/#{:erlang.unique_integer([:positive])}_backup.sql.gz"

      try do
        pg_dump_cmd = "pg_dump '#{database_url}' | gzip > #{tmp_file}"

        case System.cmd("sh", ["-c", pg_dump_cmd], stderr_to_stdout: true) do
          {_, 0} ->
            case File.stat(tmp_file) do
              {:ok, %{size: size}} when size > 0 ->
                upload_result = upload_to_tigris(tmp_file, storage_key)
                File.rm(tmp_file)

                case upload_result do
                  :ok -> {:ok, size}
                  {:error, reason} -> {:error, "Upload failed: #{inspect(reason)}"}
                end

              {:ok, %{size: 0}} ->
                File.rm(tmp_file)
                {:error, "pg_dump produced empty file"}

              {:error, reason} ->
                {:error, "Failed to read backup file: #{inspect(reason)}"}
            end

          {output, code} ->
            File.rm(tmp_file)
            {:error, "pg_dump failed (exit #{code}): #{output}"}
        end
      rescue
        e ->
          File.rm(tmp_file)
          {:error, "Exception: #{Exception.message(e)}"}
      end
    end
  end

  defp upload_to_tigris(file_path, storage_key) do
    bucket = Session.memories_bucket()
    data = File.read!(file_path)

    case ExAws.S3.put_object(bucket, storage_key, data, content_type: "application/gzip")
         |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def cleanup_old_backups do
    completed_backups =
      DatabaseBackup
      |> where([b], b.status == "completed")
      |> order_by(desc: :inserted_at)
      |> Repo.all()

    backups_to_keep = select_backups_to_keep(completed_backups)
    backups_to_delete = completed_backups -- backups_to_keep

    Enum.each(backups_to_delete, fn backup ->
      delete_backup_from_storage(backup)
      Repo.delete(backup)
    end)

    length(backups_to_delete)
  end

  defp select_backups_to_keep(backups) do
    now = DateTime.utc_now()

    daily_backups =
      backups
      |> Enum.filter(fn b ->
        DateTime.diff(now, b.inserted_at, :day) < @daily_retention
      end)
      |> Enum.take(@daily_retention)

    weekly_backups =
      backups
      |> Enum.filter(fn b ->
        day_of_week = Date.day_of_week(DateTime.to_date(b.inserted_at))
        day_of_week == 7 and DateTime.diff(now, b.inserted_at, :day) >= @daily_retention
      end)
      |> Enum.take(@weekly_retention)

    Enum.uniq(daily_backups ++ weekly_backups)
  end

  defp delete_backup_from_storage(%DatabaseBackup{storage_key: key}) do
    bucket = Session.memories_bucket()

    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _} ->
        Logger.info("[Backups] Deleted old backup from storage: #{key}")
        :ok

      {:error, reason} ->
        Logger.warning("[Backups] Failed to delete backup #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_download_url(%DatabaseBackup{storage_key: key}) do
    bucket = Session.memories_bucket()
    config = ExAws.Config.new(:s3)

    ExAws.S3.presigned_url(config, :get, bucket, key, expires_in: 3600)
  end
end
