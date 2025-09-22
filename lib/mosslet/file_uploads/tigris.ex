defmodule Mosslet.FileUploads.Tigris do
  @moduledoc false
  require Logger
  alias Mosslet.Accounts
  alias Mosslet.Encrypted

  @folder "uploads/trix"

  def upload(session, %{
        "Content-Type" => content_type,
        "storage_key" => storage_key,
        "file" => %Plug.Upload{path: tmp_path} = _upload,
        "trix_key" => trix_key
      }) do
    region = Encrypted.Session.s3_region()
    access_key_id = Encrypted.Session.s3_access_key_id()
    secret_key_access = Encrypted.Session.s3_secret_key_access()
    memories_bucket = Encrypted.Session.memories_bucket()
    s3_host = Encrypted.Session.s3_host()

    user = Accounts.get_user_by_session_token(session["user_token"])
    Logger.info("📷 TIGRIS: get_user_by_session_token returned: #{inspect(user)}")
    Logger.info("📷 TIGRIS: session user_token was: #{inspect(session["user_token"])}")
    file_ext = ext(content_type)
    file_key = get_file_key(storage_key)
    file_path = "#{@folder}/#{file_key}.#{file_ext}"
    session_key = session["key"]

    # the trix_key is generated/set in the trix_uploads_controller
    case process_file(tmp_path, file_ext, user, trix_key, session_key) do
      {:ok, e_file} ->
        ExAws.S3.put_object(memories_bucket, file_path, e_file)
        |> ExAws.request()
        |> case do
          {:ok, %{status_code: 200} = _response} ->
            config = %{
              region: region,
              access_key_id: access_key_id,
              secret_access_key: secret_key_access
            }

            options = [
              virtual_host: true,
              bucket_as_host: true,
              # just less than 1 week (604,800)
              expires_in: 600_000
            ]

            # "https://#{memories_bucket}.#{s3_region}.#{s3_host}"
            # our s3_region is "auto" so we leave it out
            host_name = "https://#{memories_bucket}.#{s3_host}"

            {:ok, presigned_url} =
              generate_tigris_presigned_url(
                config,
                :get,
                host_name,
                file_path,
                options
              )

            {:ok, presigned_url}

          _ = _response ->
            {:error, "Unable to upload file, please try again later."}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete_file(file_url, content_type) do
    file_key = get_file_key(file_url)
    path_to_delete = "#{@folder}/#{file_key}.#{ext(content_type)}"
    memories_bucket = Encrypted.Session.memories_bucket()

    case ExAws.S3.delete_object(memories_bucket, path_to_delete) |> ExAws.request() do
      {:ok, %{status_code: 204} = _response} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp process_file(tmp_path, file_ext, user, trix_key, session_key) do
    # Check the mime_type to avoid malicious file naming
    mime_type = ExMarcel.MimeType.for({:path, tmp_path})

    cond do
      mime_type in ["image/jpeg", "image/jpg", "image/png"] ->
        with {:ok, binary} <-
               Image.open!(tmp_path)
               |> check_for_safety(),
             {:ok, file} <-
               Image.write(binary, :memory, suffix: ".#{file_ext}"),
             {:ok, e_file} <- encrypt_file(file, user, trix_key, session_key) do
          {:ok, e_file}
        else
          {:postpone, {:nsfw, message}} ->
            {:error, {:nsfw, message}}

          {:error, message} ->
            {:error, {:error, message}}
        end

      true ->
        {:error, "Unknown error, please try again or contact support."}
    end
  end

  defp generate_tigris_presigned_url(config, request_type, host_name, object_key, options) do
    ExAws.S3.presigned_url(
      config,
      request_type,
      host_name,
      object_key,
      options
    )
  end

  defp get_file_key(url) do
    url |> String.split("/") |> List.last()
  end

  defp ext(content_type) do
    [ext | _] = MIME.extensions(content_type)
    ext
  end

  defp check_for_safety(binary) do
    case Mosslet.AI.Images.check_for_safety(binary) do
      {:ok, binary} ->
        {:ok, binary}

      {:nsfw, message} ->
        {:postpone, {:nsfw, message}}
    end
  end

  # the trix_key stays encrypted on the client
  # and is passed back and forth encrypted,
  # so we we need to decrypt it before using
  # it to encrypt the file
  defp encrypt_file(file, user, trix_key, session_key) do
    {:ok, d_trix_key} =
      Encrypted.Users.Utils.decrypt_user_attrs_key(
        trix_key,
        user,
        session_key
      )

    encrypted_file = Encrypted.Utils.encrypt(%{key: d_trix_key, payload: file})

    {:ok, encrypted_file}
  end
end
