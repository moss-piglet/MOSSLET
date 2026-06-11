defmodule Mosslet.Bluesky.ImportProcessor do
  @moduledoc """
  Processes Bluesky posts for import, including image downloads and moderation.

  Routes all content through the same moderation pipelines as regular posts:
  - Images: AI detection, private/public moderation, conversion to WebP
  - Text: Public moderation for public visibility posts

  This ensures consistent safety checks across all content sources.
  """

  require Logger

  alias Mosslet.AI.Images, as: AIImages
  alias Mosslet.Journal.AI, as: JournalAI
  alias Mosslet.FileUploads.ImageUploadWriter

  @max_dimension 2560
  @download_timeout 30_000

  @doc """
  Processes a Bluesky post for import, including images and text moderation.

  Returns `{:ok, processed_attrs}` with processed image URLs and AI flags,
  or `{:error, reason}` if moderation fails or content is blocked.

  Options:
    - `:visibility` - The target visibility (:public, :private, :connections)
    - `:post_key` - The encryption key for the post
  """
  def process_post(post_data, opts \\ []) do
    visibility = Keyword.get(opts, :visibility, :private)
    post_key = Keyword.get(opts, :post_key)

    text = get_in(post_data, [:record, :text]) || ""
    reply_ref = extract_reply_ref(post_data)
    mature_content = extract_mature_content(post_data)
    quote_url = extract_quote_url(post_data)

    with {:ok, _} <- moderate_text(text, visibility),
         {:ok, image_results} <- process_images(post_data, visibility, post_key) do
      {:ok,
       %{
         text: append_quote_attribution(text, quote_url),
         image_urls: Enum.map(image_results, & &1.url),
         image_alt_texts: Enum.map(image_results, &(&1.alt || "")),
         ai_generated: Enum.any?(image_results, & &1.ai_generated),
         mature_content: mature_content,
         quote_url: quote_url,
         reply_ref: reply_ref
       }}
    end
  end

  # Quote posts reference another post via a strongRef (uri/cid) inside
  # embed.record or embed.recordWithMedia.record. We don't fetch the quoted
  # post (privacy + rate limits); instead we surface a link to it so the
  # imported Mosslet post preserves the quote context.
  defp extract_quote_url(post_data) do
    embed = get_in(post_data, [:record, :embed]) || get_in(post_data, [:embed])

    quoted_uri =
      case embed do
        %{record: %{record: %{uri: uri}}} when is_binary(uri) -> uri
        %{record: %{uri: uri}} when is_binary(uri) -> uri
        _ -> nil
      end

    case quoted_uri do
      uri when is_binary(uri) -> Mosslet.Bluesky.Client.at_uri_to_web_url(uri)
      _ -> nil
    end
  end

  defp append_quote_attribution(text, nil), do: text

  defp append_quote_attribution(text, quote_url) do
    suffix = "↪ Quoting #{quote_url}"

    cond do
      String.contains?(text, quote_url) -> text
      String.trim(text) == "" -> suffix
      true -> text <> "\n\n" <> suffix
    end
  end

  defp extract_mature_content(post_data) do
    post_data
    |> get_in([:record, :labels])
    |> Mosslet.Bluesky.Labels.sensitive?()
  end

  defp extract_reply_ref(post_data) do
    case get_in(post_data, [:record, :reply]) do
      %{root: root, parent: parent} ->
        %{
          root_uri: root[:uri],
          root_cid: root[:cid],
          parent_uri: parent[:uri],
          parent_cid: parent[:cid]
        }

      _ ->
        nil
    end
  end

  defp moderate_text(text, visibility) when visibility in [:public, "public"] do
    case JournalAI.moderate_public_post(text) do
      {:ok, :approved} ->
        {:ok, :approved}

      {:error, reason} ->
        Logger.info("[BlueskyImport] Text blocked for public: #{reason}")
        {:error, {:text_moderation_failed, reason}}
    end
  end

  defp moderate_text(_text, _visibility), do: {:ok, :approved}

  defp process_images(post_data, visibility, post_key) do
    images = extract_images(post_data)

    if Enum.empty?(images) do
      {:ok, []}
    else
      images
      |> Enum.reduce_while({:ok, []}, fn image, {:ok, acc} ->
        case process_single_image(image, visibility, post_key) do
          {:ok, result} -> {:cont, {:ok, [result | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, results} -> {:ok, Enum.reverse(results)}
        {:error, _} = error -> error
      end
    end
  end

  defp extract_images(post_data) do
    embed = get_in(post_data, [:record, :embed]) || get_in(post_data, [:embed])

    case embed do
      %{images: images} when is_list(images) ->
        map_images(images)

      # Quote post with media: images live under recordWithMedia.media.images
      %{media: %{images: images}} when is_list(images) ->
        map_images(images)

      _ ->
        []
    end
  end

  defp map_images(images) do
    Enum.map(images, fn img ->
      %{
        url: img[:fullsize] || img[:thumb],
        alt: img[:alt]
      }
    end)
  end

  defp process_single_image(%{url: url} = image_info, visibility, post_key) when is_binary(url) do
    with {:ok, binary} <- download_image(url),
         {:ok, vips_image} <- load_image(binary),
         {:ok, ai_generated} <- AIImages.detect_ai_generated(vips_image),
         {:ok, _} <- moderate_image(vips_image, visibility),
         {:ok, processed_binary} <- process_and_convert(vips_image),
         {:ok, storage_path} <- upload_image(processed_binary, post_key) do
      {:ok,
       %{
         url: storage_path,
         alt: image_info[:alt],
         ai_generated: ai_generated
       }}
    else
      {:nsfw, reason} ->
        Logger.info("[BlueskyImport] Image blocked: #{reason}")
        {:error, {:image_moderation_failed, reason}}

      {:error, reason} ->
        Logger.warning("[BlueskyImport] Image processing failed: #{inspect(reason)}")
        {:error, {:image_processing_failed, reason}}
    end
  end

  defp process_single_image(_, _, _), do: {:error, :invalid_image_data}

  defp download_image(url) do
    case Req.get(url, receive_timeout: @download_timeout) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:download_failed, status}}

      {:error, reason} ->
        {:error, {:download_failed, reason}}
    end
  end

  defp load_image(binary) do
    mime_type = ExMarcel.MimeType.for({:string, binary})

    case mime_type do
      "image/gif" ->
        Image.from_binary(binary, pages: :all)

      "image/webp" ->
        case Image.from_binary(binary, pages: :all) do
          {:ok, image} -> {:ok, image}
          error -> error
        end

      _ ->
        Image.from_binary(binary)
    end
  end

  defp moderate_image(image, visibility) do
    with {:ok, image} <- run_private_moderation(image),
         :ok <- maybe_run_public_moderation(image, visibility) do
      {:ok, image}
    end
  end

  defp run_private_moderation(image) do
    case AIImages.moderate_private_image(image, "image/webp") do
      {:ok, :approved} ->
        {:ok, image}

      {:error, :service_unavailable} ->
        Logger.warning("[BlueskyImport] LLM moderation unavailable, falling back to Bumblebee")

        with {:ok, binary} <- Image.write(image, :memory, suffix: ".webp"),
             {:ok, _} <- AIImages.check_for_safety_bumblebee(binary) do
          {:ok, image}
        end

      {:error, reason} ->
        {:nsfw, reason}
    end
  end

  defp maybe_run_public_moderation(image, visibility)
       when visibility in [:public, "public"] do
    case AIImages.moderate_public_image(image, "image/webp") do
      {:ok, :approved} ->
        :ok

      {:error, reason} ->
        {:nsfw, "Image not suitable for public posts: #{reason}"}
    end
  end

  defp maybe_run_public_moderation(_image, _visibility), do: :ok

  defp process_and_convert(image) do
    pages = Image.pages(image)

    if pages > 1 do
      process_animated(image)
    else
      process_static(image)
    end
  end

  defp process_static(image) do
    with {:ok, {rotated, _flags}} <- Image.autorotate(image),
         {:ok, stripped} <- Image.remove_metadata(rotated),
         {:ok, resized} <- resize_if_needed(stripped),
         {:ok, srgb} <- {:ok, Image.to_colorspace!(resized, :srgb)},
         {:ok, binary} <- Image.write(srgb, :memory, suffix: ".webp", webp: [quality: 90]) do
      {:ok, binary}
    end
  end

  defp process_animated(image) do
    with {:ok, resized} <- resize_animated_if_needed(image),
         {:ok, binary} <-
           Image.write(resized, :memory, suffix: ".webp", webp: [quality: 90]) do
      {:ok, binary}
    end
  end

  defp resize_if_needed(image) do
    width = Image.width(image)
    height = Image.height(image)

    if width > @max_dimension or height > @max_dimension do
      Image.thumbnail(image, "#{@max_dimension}x#{@max_dimension}")
    else
      {:ok, image}
    end
  end

  defp resize_animated_if_needed(image) do
    width = Image.width(image)
    page_height = get_page_height(image) || Image.height(image) |> div(max(Image.pages(image), 1))

    if width > @max_dimension or page_height > @max_dimension do
      scale = min(@max_dimension / width, @max_dimension / page_height)
      Vix.Vips.Operation.resize(image, scale)
    else
      {:ok, image}
    end
  end

  defp get_page_height(image) do
    case Vix.Vips.Image.header_value(image, "page-height") do
      {:ok, page_height} -> page_height
      _ -> nil
    end
  end

  defp upload_image(binary, post_key) do
    ImageUploadWriter.upload_to_storage(binary, post_key)
  end
end
