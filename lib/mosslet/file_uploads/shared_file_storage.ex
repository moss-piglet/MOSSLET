defmodule Mosslet.FileUploads.SharedFileStorage do
  @moduledoc """
  Opaque-blob object storage for org-scoped ZK file sharing (Task #221, see
  `docs/ZK_FILE_SHARING_DESIGN.md` §5.4).

  Mirrors `ImageUploadWriter.upload_pre_encrypted_to_storage/1` — the browser
  encrypts the file bytes with a per-file `file_key` (NaCl secretbox) and sends
  the ALREADY-ENCRYPTED blob; the server `put_object`s the opaque bytes and
  never sees the `file_key` or the plaintext (invariants I2/I3).

  Stored under a dedicated `uploads/files/` prefix, with no content-type suffix
  (we deliberately don't expose MIME server-side — Q4). Reads go through a
  short-lived presigned GET URL.
  """

  alias Mosslet.Encrypted

  @folder "uploads/files"

  @doc """
  Stores an already-encrypted (opaque) blob and returns `{:ok, storage_path}`.

  The server never decrypts and never holds the `file_key`.
  """
  def put_encrypted_blob(encrypted_binary) when is_binary(encrypted_binary) do
    storage_key = Ecto.UUID.generate()
    file_path = "#{@folder}/#{storage_key}.bin"

    case put_object(file_path, encrypted_binary) do
      {:ok, :uploaded} -> {:ok, file_path}
      {:error, _} = error -> error
    end
  end

  @doc """
  Generates a short-lived presigned GET URL for an opaque blob. The browser
  fetches the ciphertext and decrypts it locally. Authorization (the requester
  holds a `UserSharedFile` row) is enforced by the context BEFORE this is called.
  """
  def presigned_url(storage_path) when is_binary(storage_path) do
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
      # 10 minutes — long enough to download, short enough to limit URL reuse.
      expires_in: 600
    ]

    ExAws.S3.presigned_url(config, :get, host_name, storage_path, options)
  end

  @doc """
  Fetches an opaque (already-encrypted) blob from object storage, SERVER-SIDE.

  Returns `{:ok, ciphertext_binary}` or `:error`. The bytes are the NaCl-secretbox
  ciphertext (under the per-file/per-org key) — the server never decrypts them; it
  only relays the opaque blob so the browser can deliver it inline and decrypt
  client-side (avoids a cross-origin presigned fetch / Tigris CORS — Task #349).
  Authorization is enforced by the caller BEFORE this runs.
  """
  def get_encrypted_blob(storage_path) when is_binary(storage_path) do
    bucket = Encrypted.Session.memories_bucket()

    case ExAws.S3.get_object(bucket, storage_path) |> ExAws.request() do
      {:ok, %{body: body}} when is_binary(body) -> {:ok, body}
      _ -> :error
    end
  end

  def get_encrypted_blob(_), do: :error

  @doc """
  Deletes an opaque blob (revocation — I5). Runs on the StorjTask supervisor so
  a slow object-store call never blocks the LiveView process.
  """
  def delete_blob(storage_path) when is_binary(storage_path) do
    bucket = Encrypted.Session.memories_bucket()

    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      case ExAws.S3.delete_object(bucket, storage_path) |> ExAws.request() do
        {:ok, _resp} -> {:ok, :deleted}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def delete_blob(nil), do: :ok

  defp put_object(file_path, data) do
    bucket = Encrypted.Session.memories_bucket()

    case ExAws.S3.put_object(bucket, file_path, data) |> ExAws.request() do
      {:ok, %{status_code: 200}} -> {:ok, :uploaded}
      {:ok, resp} -> {:error, "Upload failed: #{inspect(resp)}"}
      {:error, _} = error -> error
    end
  end
end
