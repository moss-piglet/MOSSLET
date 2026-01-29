defmodule Mosslet.Releases.Storage do
  @moduledoc """
  Handles uploading and managing desktop app releases in Tigris object storage.

  Release files are stored publicly (no encryption) for direct download.

  ## Environment Variables Required

    * `RELEASES_BUCKET` - The Tigris bucket name for releases (e.g., "mosslet-releases")
    * `AWS_ACCESS_KEY_ID` - Tigris access key
    * `AWS_SECRET_ACCESS_KEY` - Tigris secret key
    * `AWS_REGION` - Tigris region (e.g., "auto")
    * `AWS_HOST` - Tigris host (e.g., "fly.storage.tigris.dev")

  ## Usage

      # Upload a release file
      Mosslet.Releases.Storage.upload("0.17.0", "/path/to/Mosslet-0.17.0-macos.dmg")

      # List releases for a version
      Mosslet.Releases.Storage.list_version("0.17.0")

      # Get public URL
      Mosslet.Releases.Storage.public_url("0.17.0", "Mosslet-0.17.0-macos.dmg")
  """

  require Logger

  @doc """
  Uploads a release file to Tigris storage.

  Returns `{:ok, public_url}` on success.
  """
  @spec upload(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def upload(version, file_path) do
    filename = Path.basename(file_path)
    object_key = "v#{version}/#{filename}"

    with {:ok, data} <- File.read(file_path),
         :ok <- put_object(object_key, data, content_type(filename)) do
      url = public_url(version, filename)
      Logger.info("Uploaded release: #{url}")
      {:ok, url}
    end
  end

  @doc """
  Uploads all release artifacts from a directory for a given version.

  Returns a list of `{filename, {:ok, url} | {:error, reason}}` tuples.
  """
  @spec upload_all(String.t(), String.t()) :: [{String.t(), {:ok, String.t()} | {:error, term()}}]
  def upload_all(version, directory) do
    release_extensions = ~w(.dmg .zip .exe .AppImage .tar.gz)

    directory
    |> File.ls!()
    |> Enum.filter(fn file ->
      Enum.any?(release_extensions, &String.ends_with?(file, &1))
    end)
    |> Enum.map(fn filename ->
      file_path = Path.join(directory, filename)
      {filename, upload(version, file_path)}
    end)
  end

  @doc """
  Returns the public URL for a release file.
  """
  @spec public_url(String.t(), String.t()) :: String.t()
  def public_url(version, filename) do
    bucket = releases_bucket()
    host = s3_host()
    "https://#{bucket}.#{host}/v#{version}/#{filename}"
  end

  @doc """
  Returns the base URL for releases (used by download page).
  """
  @spec base_url() :: String.t()
  def base_url do
    bucket = releases_bucket()
    host = s3_host()
    "https://#{bucket}.#{host}"
  end

  @doc """
  Lists all files for a specific version.
  """
  @spec list_version(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_version(version) do
    bucket = releases_bucket()
    prefix = "v#{version}/"

    case ExAws.S3.list_objects(bucket, prefix: prefix) |> ExAws.request() do
      {:ok, %{body: %{contents: contents}}} ->
        files = Enum.map(contents, & &1.key)
        {:ok, files}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Deletes a release file.
  """
  @spec delete(String.t(), String.t()) :: :ok | {:error, term()}
  def delete(version, filename) do
    bucket = releases_bucket()
    object_key = "v#{version}/#{filename}"

    case ExAws.S3.delete_object(bucket, object_key) |> ExAws.request() do
      {:ok, %{status_code: 204}} -> :ok
      {:error, _} = error -> error
    end
  end

  defp put_object(object_key, data, content_type) do
    bucket = releases_bucket()

    opts = [
      content_type: content_type,
      acl: :public_read
    ]

    case ExAws.S3.put_object(bucket, object_key, data, opts) |> ExAws.request() do
      {:ok, %{status_code: 200}} -> :ok
      {:ok, resp} -> {:error, "Upload failed: #{inspect(resp)}"}
      {:error, _} = error -> error
    end
  end

  defp content_type(filename) do
    cond do
      String.ends_with?(filename, ".dmg") -> "application/x-apple-diskimage"
      String.ends_with?(filename, ".exe") -> "application/x-msdownload"
      String.ends_with?(filename, ".zip") -> "application/zip"
      String.ends_with?(filename, ".tar.gz") -> "application/gzip"
      String.ends_with?(filename, ".AppImage") -> "application/x-executable"
      true -> "application/octet-stream"
    end
  end

  defp releases_bucket do
    System.get_env("RELEASES_BUCKET") ||
      raise "RELEASES_BUCKET environment variable not set"
  end

  defp s3_host do
    System.get_env("AWS_HOST") ||
      raise "AWS_HOST environment variable not set"
  end
end
