defmodule Mosslet.FileUploads.TempStorage do
  @moduledoc """
  Manages temporary file storage for upload processing.

  Uses a persistent volume in production (/data/uploads_temp) to avoid
  filling up the system temp directory, and falls back to System.tmp_dir!
  in development.

  Provides periodic cleanup of orphaned temp files older than 1 hour.
  """

  use GenServer
  require Logger

  @cleanup_interval :timer.minutes(15)
  @max_file_age_seconds 3600

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def base_dir do
    case Application.get_env(:mosslet, :upload_temp_dir) do
      nil -> System.tmp_dir!()
      dir -> dir
    end
  end

  def temp_dir(subdir) do
    path = Path.join(base_dir(), subdir)
    File.mkdir_p!(path)
    path
  end

  def temp_path(subdir, prefix) do
    dir = temp_dir(subdir)
    filename = "#{prefix}_#{:erlang.unique_integer([:positive])}.tmp"
    Path.join(dir, filename)
  end

  def cleanup(path) when is_binary(path) do
    case File.rm(path) do
      :ok ->
        :ok

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to cleanup temp file #{path}: #{inspect(reason)}")
        :ok
    end
  end

  def cleanup(nil), do: :ok

  @impl true
  def init(_opts) do
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup_orphans, state) do
    cleanup_orphan_files()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_orphans, @cleanup_interval)
  end

  defp cleanup_orphan_files do
    base = base_dir()
    cutoff = System.os_time(:second) - @max_file_age_seconds

    subdirs = ["journal_ocr", "image_processing", "avatar_uploads", "timeline_uploads"]

    Enum.each(subdirs, fn subdir ->
      dir = Path.join(base, subdir)

      if File.dir?(dir) do
        case File.ls(dir) do
          {:ok, files} ->
            Enum.each(files, fn file ->
              path = Path.join(dir, file)
              cleanup_if_old(path, cutoff)
            end)

          {:error, _} ->
            :ok
        end
      end
    end)
  end

  defp cleanup_if_old(path, cutoff) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} when mtime < cutoff ->
        Logger.info("Cleaning up orphaned temp file: #{path}")
        File.rm(path)

      _ ->
        :ok
    end
  end
end
