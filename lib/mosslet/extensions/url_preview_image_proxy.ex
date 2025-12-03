defmodule Mosslet.Extensions.URLPreviewImageProxy do
  @moduledoc """
  Handles fetching, encrypting, and storing preview images in Tigris storage.
  This allows us to proxy external preview images through our own infrastructure,
  maintaining encryption and improving security by avoiding direct external image loads.
  """

  alias Mosslet.Encrypted
  alias Mosslet.Extensions.URLPreviewSecurity

  @folder "url_previews"
  @max_image_size 5_242_880
  @url_expires_in 600_000

  @doc """
  Fetches an external preview image from the original URL (not data URL),
  resizes it for optimal display, encrypts it with the post_key,
  and stores it in Tigris storage. Returns a presigned URL for display.

  ## Parameters
    - original_image_url: The original external URL of the preview image (not data URL)
    - url_hash: Hash of the preview URL for unique storage path
    - post_key: The encryption key for the post
    - post_id: The ID of the post (used to organize storage by post)

  ## Returns
    - {:ok, presigned_url} on success
    - {:error, reason} on failure
  """
  def fetch_and_store_preview_image(original_image_url, url_hash, post_key, post_id) do
    with {:ok, image_binary} <- fetch_image(original_image_url),
         {:ok, resized_binary} <- resize_for_timeline(image_binary),
         {:ok, encrypted_image} <- encrypt_image(resized_binary, post_key),
         {:ok, file_path} <- upload_to_tigris(encrypted_image, url_hash, post_id),
         {:ok, presigned_url} <- generate_presigned_url(file_path) do
      {:ok, presigned_url}
    else
      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Deletes all preview images for a post from Tigris storage by deleting the post's subfolder.
  """
  def delete_preview_images_for_post(post_id) do
    memories_bucket = Encrypted.Session.memories_bucket()
    prefix = "#{@folder}/#{post_id}/"

    case list_objects_with_prefix(memories_bucket, prefix) do
      {:ok, objects} when is_list(objects) ->
        delete_objects(memories_bucket, objects)

      {:ok, []} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp list_objects_with_prefix(bucket, prefix) do
    case ExAws.S3.list_objects(bucket, prefix: prefix) |> ExAws.request() do
      {:ok, %{body: %{contents: contents}}} ->
        object_keys = Enum.map(contents, & &1.key)
        {:ok, object_keys}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_objects(_bucket, []), do: :ok

  defp delete_objects(bucket, objects) do
    results =
      Enum.map(objects, fn key ->
        ExAws.S3.delete_object(bucket, key) |> ExAws.request()
      end)

    if Enum.all?(results, fn
         {:ok, %{status_code: code}} when code in [204, 404] -> true
         _ -> false
       end) do
      :ok
    else
      {:error, :partial_delete_failure}
    end
  end

  @doc """
  Regenerate presigned URL for an existing encrypted preview image in Tigris.
  Used when presigned URLs expire (after ~1 week).
  """
  def regenerate_presigned_url(url_hash, post_id) do
    file_path = build_file_path(url_hash, post_id)

    case generate_presigned_url(file_path) do
      {:ok, presigned_url} -> {:ok, presigned_url}
      error -> error
    end
  end

  defp fetch_image(url) do
    with {:ok, validated_url} <- URLPreviewSecurity.validate_and_normalize_url(url) do
      case Req.get(validated_url,
             max_redirects: 5,
             retry: :transient,
             max_retries: 2,
             receive_timeout: 10_000,
             headers: [
               {"user-agent",
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
               {"accept", "image/webp,image/apng,image/*,*/*;q=0.8"},
               {"accept-language", "en-US,en;q=0.5"}
             ]
           ) do
        {:ok, %{status: 200, body: body}} when is_binary(body) ->
          if byte_size(body) <= @max_image_size do
            {:ok, body}
          else
            {:error, :image_too_large}
          end

        {:ok, %{status: _status}} ->
          {:error, :fetch_failed}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp resize_for_timeline(image_binary) do
    case Image.from_binary(image_binary) do
      {:ok, image} ->
        {:ok, resized} =
          Image.thumbnail(image, "400x400",
            resize: :down,
            crop: :none,
            intent: :perceptual
          )

        Image.write(resized, :memory, suffix: ".webp", webp: [quality: 75])

      {:error, _reason} = error ->
        error
    end
  rescue
    _error ->
      {:error, :resize_failed}
  end

  defp encrypt_image(image_binary, post_key) do
    encrypted_binary = Encrypted.Utils.encrypt(%{key: post_key, payload: image_binary})
    {:ok, encrypted_binary}
  end

  defp upload_to_tigris(encrypted_image, url_hash, post_id) do
    memories_bucket = Encrypted.Session.memories_bucket()
    file_path = build_file_path(url_hash, post_id)

    ExAws.S3.put_object(memories_bucket, file_path, encrypted_image)
    |> ExAws.request()
    |> case do
      {:ok, %{status_code: 200}} ->
        {:ok, file_path}

      {:error, _reason} ->
        {:error, :upload_failed}
    end
  end

  defp generate_presigned_url(file_path) do
    region = Encrypted.Session.s3_region()
    access_key_id = Encrypted.Session.s3_access_key_id()
    secret_access_key = Encrypted.Session.s3_secret_key_access()
    memories_bucket = Encrypted.Session.memories_bucket()
    s3_host = Encrypted.Session.s3_host()

    config = %{
      region: region,
      access_key_id: access_key_id,
      secret_access_key: secret_access_key
    }

    options = [
      virtual_host: true,
      bucket_as_host: true,
      expires_in: @url_expires_in
    ]

    host_name = "https://#{memories_bucket}.#{s3_host}"

    case ExAws.S3.presigned_url(config, :get, host_name, file_path, options) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_file_path(url_hash, post_id) do
    "#{@folder}/#{post_id}/#{url_hash}.enc"
  end
end
