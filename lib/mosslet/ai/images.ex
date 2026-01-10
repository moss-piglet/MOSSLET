defmodule Mosslet.AI.Images do
  @moduledoc """
  Functions for processing images with AI.
  """

  alias ReqLLM.Message.ContentPart

  @model "openrouter:openai/gpt-4o-mini"

  @doc """
  Classifies an image as either "normal"
  or "nsfw".
  """
  def check_for_safety(image_binary) do
    with {:ok, resized} <- Image.thumbnail(image_binary, "224x224"),
         {:ok, flattened} <- Image.flatten(resized),
         {:ok, srgb} <- Image.to_colorspace(flattened, :srgb),
         {:ok, tensor} <-
           Image.to_nx(srgb,
             shape: :hwc,
             backend: Application.fetch_env!(:nx, :default_backend)
           ),
         %{predictions: [%{label: label}]} <- Nx.Serving.batched_run(NsfwImageDetection, tensor) do
      case label do
        "normal" -> {:ok, image_binary}
        "nsfw" -> {:nsfw, "Image is not safe for upload."}
        _ -> {:error, "There was an error trying to classify this image."}
      end
    else
      _ -> {:error, "There was an error trying to classify this image."}
    end
  end

  @doc """
  Moderates an image for public posts. Returns {:ok, :approved} if image is appropriate,
  or {:error, reason} if image violates community guidelines.

  This is specifically for public posts where we want to maintain civil discourse.
  The check runs efficiently by analyzing a resized version of the image.
  Only genuinely harmful content is blocked.

  Takes an Image struct (vips image) and the mime type.
  """
  def moderate_public_image(image, mime_type) do
    with {:ok, resized} <- Image.thumbnail(image, "512x512"),
         {:ok, binary} <- Image.write(resized, :memory, suffix: mime_suffix(mime_type)) do
      moderate_public_image_binary(binary, mime_type)
    else
      {:error, reason} ->
        {:error, "Unable to verify image for public sharing: #{inspect(reason)}"}
    end
  end

  @doc """
  Moderates a raw image binary for public posts.
  """
  def moderate_public_image_binary(binary, mime_type) do
    system_prompt = """
    You are a content moderator for a social platform. Evaluate if this image is appropriate for PUBLIC sharing.

    ALLOW (respond with APPROVED):
    - Normal photos of people, places, things
    - Art and creative content
    - News and documentary images
    - Memes and humor
    - Screenshots and text images
    - Political imagery

    BLOCK (respond with BLOCKED and a brief reason):
    - Explicit sexual content or nudity
    - Graphic violence, gore, or disturbing imagery
    - Hate symbols or imagery targeting protected groups
    - Content promoting self-harm
    - Illegal content
    - Personal/private information visible (doxxing)

    Respond with ONLY one of these formats:
    APPROVED
    or
    BLOCKED: [brief reason in 10 words or less]

    Be lenient - when in doubt, approve. We value free expression.
    """

    content = [
      ContentPart.image(binary, mime_type),
      ContentPart.text("Is this image appropriate for public sharing?")
    ]

    message = %ReqLLM.Message{role: :user, content: content}

    case ReqLLM.generate_text(@model, [message], system_prompt: system_prompt) do
      {:ok, response} ->
        result = ReqLLM.Response.text(response) |> String.trim()

        cond do
          String.starts_with?(result, "APPROVED") ->
            {:ok, :approved}

          String.starts_with?(result, "BLOCKED:") ->
            reason = String.replace_prefix(result, "BLOCKED:", "") |> String.trim()
            {:error, reason}

          true ->
            {:ok, :approved}
        end

      {:error, reason} ->
        {:error, "Moderation service unavailable: #{inspect(reason)}"}
    end
  end

  defp mime_suffix("image/jpeg"), do: ".jpg"
  defp mime_suffix("image/jpg"), do: ".jpg"
  defp mime_suffix("image/png"), do: ".png"
  defp mime_suffix("image/webp"), do: ".webp"
  defp mime_suffix("image/gif"), do: ".gif"
  defp mime_suffix(_), do: ".jpg"
end
