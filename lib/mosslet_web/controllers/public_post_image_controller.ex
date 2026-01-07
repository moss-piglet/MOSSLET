defmodule MossletWeb.PublicPostImageController do
  use MossletWeb, :controller

  alias Mosslet.Timeline
  alias Mosslet.Encrypted

  require Logger

  @cache_max_age 86400

  def show(conn, %{"post_id" => post_id, "index" => index_str}) do
    with {index, ""} <- Integer.parse(index_str),
         %Timeline.Post{visibility: :public} = post <- Timeline.get_post_with_preloads(post_id),
         {:ok, post_key} <- get_public_post_key(post),
         {:ok, image_path} <- get_decrypted_image_path(post, index, post_key),
         {:ok, image_binary, content_type} <- fetch_and_decrypt_image(image_path, post_key) do
      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("cache-control", "public, max-age=#{@cache_max_age}")
      |> send_resp(200, image_binary)
    else
      nil ->
        send_resp(conn, 404, "Post not found")

      %Timeline.Post{} ->
        send_resp(conn, 403, "Post is not public")

      {:error, :no_key} ->
        send_resp(conn, 404, "Image not available")

      {:error, :index_out_of_bounds} ->
        send_resp(conn, 404, "Image not found")

      {:error, :decryption_failed} ->
        Logger.error("Failed to decrypt public post image for post #{post_id}")
        send_resp(conn, 500, "Failed to process image")

      {:error, :fetch_failed} ->
        Logger.error("Failed to fetch public post image from storage for post #{post_id}")
        send_resp(conn, 500, "Failed to fetch image")

      :error ->
        send_resp(conn, 400, "Invalid index")
    end
  end

  def show(conn, _params) do
    send_resp(conn, 400, "Bad request")
  end

  defp get_public_post_key(post) do
    encrypted_key = get_post_key(post)

    case Encrypted.Users.Utils.decrypt_public_item_key(encrypted_key) do
      post_key when is_binary(post_key) -> {:ok, post_key}
      _ -> {:error, :no_key}
    end
  end

  defp get_post_key(post) do
    Enum.at(post.user_posts, 0).key
  end

  defp get_decrypted_image_path(post, index, post_key) do
    case post.image_urls do
      urls when is_list(urls) and length(urls) > index ->
        encrypted_url = Enum.at(urls, index)

        case Encrypted.Utils.decrypt(%{key: post_key, payload: encrypted_url}) do
          {:ok, path} -> {:ok, path}
          _ -> {:error, :decryption_failed}
        end

      _ ->
        {:error, :index_out_of_bounds}
    end
  end

  defp fetch_and_decrypt_image(file_path, post_key) do
    memories_bucket = Encrypted.Session.memories_bucket()
    webp_path = normalize_to_webp(file_path)

    case get_s3_object(memories_bucket, webp_path) do
      {:ok, %{body: encrypted_obj}} ->
        decrypt_image_data(encrypted_obj, post_key, "image/webp")

      {:error, _} ->
        case get_s3_object(memories_bucket, file_path) do
          {:ok, %{body: encrypted_obj}} ->
            content_type = get_content_type(file_path)
            decrypt_image_data(encrypted_obj, post_key, content_type)

          {:error, _} ->
            {:error, :fetch_failed}
        end
    end
  end

  defp decrypt_image_data(encrypted_obj, post_key, content_type) do
    case Encrypted.Utils.decrypt(%{key: post_key, payload: encrypted_obj}) do
      {:ok, decrypted} -> {:ok, decrypted, content_type}
      _ -> {:error, :decryption_failed}
    end
  end

  defp get_s3_object(bucket, file_path) do
    case ExAws.S3.get_object(bucket, file_path) |> ExAws.request() do
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_to_webp(file_path) do
    base = Path.rootname(file_path)
    "#{base}.webp"
  end

  defp get_content_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      _ -> "image/webp"
    end
  end
end
