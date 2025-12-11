defmodule MossletWeb.TimelineImageDownloadController do
  use MossletWeb, :controller

  alias Mosslet.Timeline
  alias MossletWeb.Helpers

  require Logger

  def download_image(conn, %{"token" => token}) do
    case Phoenix.Token.verify(MossletWeb.Endpoint, "timeline_image_download", token, max_age: 60) do
      {:ok, %{"post_id" => post_id, "image_index" => image_index, "user_id" => user_id}} ->
        current_user = conn.assigns.current_user

        # Verify the user is authorized to make this download
        if current_user && current_user.id == user_id do
          case Timeline.get_post(post_id) do
            %Timeline.Post{} = post ->
              # Check download permissions using existing security logic
              if check_download_permission(post, current_user) do
                download_post_image(conn, post, image_index, current_user)
              else
                conn
                |> put_flash(
                  :error,
                  "You don't have permission to download images from this post"
                )
                |> redirect(to: ~p"/app/timeline")
              end

            nil ->
              conn
              |> put_flash(:error, "Post not found")
              |> redirect(to: ~p"/app/timeline")
          end
        else
          conn
          |> put_flash(:error, "Unauthorized access")
          |> redirect(to: ~p"/app/timeline")
        end

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid or expired download link")
        |> redirect(to: ~p"/app/timeline")
    end
  end

  def download_image(conn, _params) do
    conn
    |> put_flash(:error, "Invalid download request")
    |> redirect(to: ~p"/app/timeline")
  end

  # Private helper functions

  defp download_post_image(conn, post, image_index, current_user) do
    # Get the user's key from session
    key = get_session(conn, "key")

    case post.image_urls do
      urls when is_list(urls) and urls != [] ->
        case Enum.at(urls, image_index) do
          nil ->
            conn
            |> put_flash(:error, "Image not found")
            |> redirect(to: ~p"/app/timeline")

          encrypted_url ->
            # Decrypt the URL to get the S3 file path
            post_key = Helpers.get_post_key(post, current_user)

            file_path =
              Helpers.decr_item(encrypted_url, current_user, post_key, key, post, "body")

            case fetch_and_decrypt_image(file_path, post, current_user, post_key, key) do
              {:ok, binary_data, content_type, ext} ->
                filename = "timeline-image-#{image_index + 1}.#{ext}"

                # Use Phoenix's send_download for proper file download handling
                send_download(conn, {:binary, binary_data},
                  filename: filename,
                  content_type: content_type,
                  disposition: :attachment
                )

              {:error, reason} ->
                Logger.error("Failed to fetch and decrypt image: #{inspect(reason)}")

                conn
                |> put_flash(:error, "Failed to process image data")
                |> redirect(to: ~p"/app/timeline")
            end
        end

      _ ->
        conn
        |> put_flash(:error, "No images found for this post")
        |> redirect(to: ~p"/app/timeline")
    end
  end

  defp fetch_and_decrypt_image(file_path, post, current_user, post_key, key) do
    memories_bucket = Mosslet.Encrypted.Session.memories_bucket()
    webp_path = normalize_to_webp(file_path)
    original_ext = get_file_extension(file_path)

    case get_s3_object(memories_bucket, webp_path) do
      {:ok, %{body: encrypted_obj}} ->
        decrypt_image_data(encrypted_obj, current_user, post_key, key, post, "webp")

      {:error, _} ->
        case get_s3_object(memories_bucket, file_path) do
          {:ok, %{body: encrypted_obj}} ->
            decrypt_image_data(encrypted_obj, current_user, post_key, key, post, original_ext)

          {:error, error} ->
            Logger.error("Failed to fetch image from S3: #{inspect(error)}")
            {:error, error}
        end
    end
  end

  defp decrypt_image_data(encrypted_obj, current_user, post_key, key, post, ext) do
    case Helpers.decr_item(encrypted_obj, current_user, post_key, key, post, "body") do
      decrypted_data when is_binary(decrypted_data) ->
        {:ok, decrypted_data, get_content_type(ext), ext}

      nil ->
        Logger.error("Decryption returned nil")
        {:error, :decryption_returned_nil}

      other ->
        Logger.error("Decryption returned unexpected value: #{inspect(other)}")
        {:error, :decryption_failed}
    end
  end

  defp get_s3_object(bucket, file_path) do
    # Use the same S3 fetching logic as in the timeline
    case ExAws.S3.get_object(bucket, file_path) |> ExAws.request() do
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_to_webp(file_path) do
    base = Path.rootname(file_path)
    "#{base}.webp"
  end

  defp get_file_extension(file_path) do
    case Path.extname(file_path) do
      "." <> ext -> ext
      _ -> "webp"
    end
  end

  defp get_content_type(extension) do
    case String.downcase(extension) do
      "jpg" -> "image/jpeg"
      "jpeg" -> "image/jpeg"
      "png" -> "image/png"
      "gif" -> "image/gif"
      "webp" -> "image/webp"
      _ -> "image/webp"
    end
  end

  # Import the same permission check logic from Timeline LiveView
  defp check_download_permission(post, current_user) do
    cond do
      # User can always download their own post images
      post.user_id == current_user.id ->
        true

      # For shared posts, check if user has photos permission
      post.visibility in [:connections, :specific_users] ->
        case Mosslet.Accounts.get_post_author_permissions_for_viewer(post, current_user) do
          %{photos?: true} -> true
          _ -> false
        end

      # Public posts can be viewed but not downloaded unless there's a connection
      post.visibility == :public ->
        case Mosslet.Accounts.get_post_author_permissions_for_viewer(post, current_user) do
          %{photos?: true} -> true
          _ -> false
        end

      # Default: no download permission
      true ->
        false
    end
  end
end
