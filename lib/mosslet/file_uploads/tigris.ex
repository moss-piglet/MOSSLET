defmodule Mosslet.FileUploads.Tigris do
  @moduledoc """
  Simple object storage operations for Tigris S3-compatible storage.

  This module handles only storage operations:
  - Uploading objects (with optional encryption)
  - Deleting objects
  - Generating presigned URLs

  All image processing (HEIC conversion, safety checks, resize, webp)
  is handled by `Mosslet.FileUploads.ImageUploadWriter` before upload.
  """

  alias Mosslet.Accounts
  alias Mosslet.Encrypted

  @folder "uploads/trix"

  @doc """
  Uploads a pre-processed file to Tigris storage.

  Expects the file at `tmp_path` to already be fully processed (WebP format).

  ## Options
    - `session` - Map with "user_token" and "key"
    - `storage_key` - Unique identifier for the file
    - `tmp_path` - Path to the processed file
    - `trix_key` - Encryption key for the file
    - `visibility` - :public or :private

  Returns `{:ok, presigned_url}` or `{:error, reason}`.
  """
  def upload(session, %{
        "storage_key" => storage_key,
        "tmp_path" => tmp_path,
        "trix_key" => trix_key,
        "visibility" => visibility
      }) do
    user = Accounts.get_user_by_session_token(session["user_token"])
    session_key = session["key"]

    file_path = "#{@folder}/#{storage_key}.webp"

    with {:ok, binary} <- File.read(tmp_path),
         {:ok, encrypted} <- encrypt_file(binary, user, trix_key, session_key, visibility),
         {:ok, _resp} <- put_object(file_path, encrypted) do
      {:ok, generate_presigned_url(file_path)}
    end
  end

  @doc """
  Deletes a file from Tigris storage.
  """
  def delete_file(storage_key) do
    file_path = "#{@folder}/#{storage_key}.webp"
    bucket = Encrypted.Session.memories_bucket()

    case ExAws.S3.delete_object(bucket, file_path) |> ExAws.request() do
      {:ok, %{status_code: 204}} -> :ok
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Generates a presigned URL for accessing a file.
  """
  def generate_presigned_url(file_path) do
    config = %{
      region: Encrypted.Session.s3_region(),
      access_key_id: Encrypted.Session.s3_access_key_id(),
      secret_access_key: Encrypted.Session.s3_secret_key_access()
    }

    bucket = Encrypted.Session.memories_bucket()
    s3_host = Encrypted.Session.s3_host()
    host_name = "https://#{bucket}.#{s3_host}"

    options = [
      virtual_host: true,
      bucket_as_host: true,
      expires_in: 600_000
    ]

    {:ok, url} = ExAws.S3.presigned_url(config, :get, host_name, file_path, options)
    url
  end

  defp put_object(file_path, data) do
    bucket = Encrypted.Session.memories_bucket()

    case ExAws.S3.put_object(bucket, file_path, data) |> ExAws.request() do
      {:ok, %{status_code: 200}} = resp -> resp
      {:ok, resp} -> {:error, "Upload failed: #{inspect(resp)}"}
      {:error, _} = error -> error
    end
  end

  defp encrypt_file(file, _user, trix_key, _session_key, _visibility) do
    encrypted = Encrypted.Utils.encrypt(%{key: trix_key, payload: file})
    {:ok, encrypted}
  end
end
