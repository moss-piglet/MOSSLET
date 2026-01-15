defmodule Mosslet.AI.Images do
  @moduledoc """
  Functions for processing images with AI.

  Image moderation strategy:
  - Public posts: Full vision model moderation (comprehensive check)
  - Private posts: Privacy-focused illegal content check with Bumblebee fallback

  Uses privacy-first providers via OpenRouter (Together AI).
  """

  require Logger

  alias Mosslet.AI.Config
  alias ReqLLM.Message.ContentPart

  @doc """
  Classifies an image as either "normal" or "nsfw" using Bumblebee.
  Used as a fallback when LLM moderation is unavailable.
  """
  def check_for_safety_bumblebee(image_binary) do
    with {:ok, image} <- Image.from_binary(image_binary),
         {:ok, resized} <- Image.thumbnail(image, "224x224"),
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
        "nsfw" -> {:nsfw, "Image flagged by safety check."}
        _ -> {:error, "There was an error trying to classify this image."}
      end
    else
      _ -> {:error, "There was an error trying to classify this image."}
    end
  end

  @doc """
  Privacy-focused safety check for private/non-public posts.
  Only blocks truly illegal content (CSAM, etc.) - minimal false positives.

  Uses LLM with Bumblebee as fallback if LLM is unavailable.
  The LLM check is designed to discard the image immediately and not store it.

  Accepts either a Vix.Vips.Image struct or raw binary data.
  """
  def check_for_safety(%Vix.Vips.Image{} = image) do
    case moderate_private_image(image, "image/webp") do
      {:ok, :approved} ->
        {:ok, image}

      {:error, :service_unavailable} ->
        Logger.warning("LLM moderation unavailable, falling back to Bumblebee")

        with {:ok, binary} <- Image.write(image, :memory, suffix: ".webp") do
          case check_for_safety_bumblebee(binary) do
            {:ok, _binary} -> {:ok, image}
            {:nsfw, message} -> {:nsfw, message}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, reason} -> {:error, "Failed to convert image: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:nsfw, reason}
    end
  end

  def check_for_safety(image_binary) when is_binary(image_binary) do
    case moderate_private_image_binary(image_binary, "image/webp") do
      {:ok, :approved} ->
        {:ok, image_binary}

      {:error, :service_unavailable} ->
        Logger.warning("LLM moderation unavailable, falling back to Bumblebee")
        check_for_safety_bumblebee(image_binary)

      {:error, reason} ->
        {:nsfw, reason}
    end
  end

  @doc """
  Privacy-focused moderation for private/non-public posts.
  Only checks for truly illegal content - respects user privacy.

  Takes an Image struct (vips image) and the mime type.
  """
  def moderate_private_image(image, mime_type) do
    with {:ok, resized} <- Image.thumbnail(image, "512x512"),
         {:ok, binary} <- Image.write(resized, :memory, suffix: mime_suffix(mime_type)) do
      moderate_private_image_binary(binary, mime_type)
    else
      {:error, reason} ->
        {:error, "Unable to verify image: #{inspect(reason)}"}
    end
  end

  @doc """
  Privacy-focused moderation for raw image binary.
  Only blocks illegal content - designed to minimize false positives.
  Returns {:error, :service_unavailable} if LLM cannot be reached (for fallback handling).
  """
  def moderate_private_image_binary(binary, mime_type) do
    system_prompt = """
    You are an image safety classifier. Analyze the image and determine if it contains illegal content.

    Respond with exactly one of:
    SAFE - if the image is legal
    ILLEGAL: [reason] - only if the image depicts child exploitation or non-consensual intimate content

    Default to SAFE unless you are certain the content is illegal.
    """

    content = [
      ContentPart.image(binary, mime_type),
      ContentPart.text("Classify this image.")
    ]

    message = %ReqLLM.Message{role: :user, content: content}

    case ReqLLM.generate_text(
           Config.vision_model(),
           [message],
           Config.vision_opts(system_prompt: system_prompt, receive_timeout: 15_000)
         ) do
      {:ok, response} ->
        result = ReqLLM.Response.text(response) |> String.trim()

        cond do
          String.starts_with?(result, "SAFE") ->
            {:ok, :approved}

          String.starts_with?(result, "ILLEGAL:") ->
            reason = String.replace_prefix(result, "ILLEGAL:", "") |> String.trim()
            {:error, reason}

          true ->
            {:ok, :approved}
        end

      {:error, %Req.TransportError{}} ->
        {:error, :service_unavailable}

      {:error, %Req.HTTPError{}} ->
        {:error, :service_unavailable}

      {:error, :timeout} ->
        {:error, :service_unavailable}

      {:error, reason} ->
        Logger.error("Private image moderation failed: #{inspect(reason)}")
        {:error, :service_unavailable}
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
    - Personal/private information visible (doxxing): license plates, home addresses, phone numbers, ID documents, credit cards

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

    case ReqLLM.generate_text(
           Config.vision_model(),
           [message],
           Config.vision_opts(system_prompt: system_prompt)
         ) do
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

  @ai_software_patterns [
    ~r/midjourney/i,
    ~r/stable.?diffusion/i,
    ~r/dall[·\-\s]?e/i,
    ~r/openai/i,
    ~r/leonardo\.ai/i,
    ~r/firefly/i,
    ~r/imagen/i,
    ~r/bing.?image.?creator/i,
    ~r/copilot/i,
    ~r/adobe.?ai/i,
    ~r/generative.?ai/i,
    ~r/flux/i,
    ~r/ideogram/i,
    ~r/playground.?ai/i,
    ~r/nightcafe/i,
    ~r/dreamstudio/i,
    ~r/runwayml/i,
    ~r/civitai/i,
    ~r/comfyui/i,
    ~r/automatic1111/i
  ]

  @ai_digital_source_types [
    "trainedAlgorithmicMedia",
    "compositeWithTrainedAlgorithmicMedia",
    "algorithmicMedia"
  ]

  @doc """
  Detects if an image has AI-generated metadata markers.
  Should be called BEFORE metadata is stripped.

  Returns `{:ok, ai_generated?}` where ai_generated? is true if AI markers found.

  Checks for:
  - IPTC DigitalSourceType (C2PA standard)
  - XMP AI generation markers
  - EXIF Software/UserComment fields mentioning AI tools
  """
  def detect_ai_generated(image) when is_struct(image, Vix.Vips.Image) do
    ai_generated? =
      check_xmp_for_ai(image) ||
        check_exif_for_ai(image) ||
        check_software_field(image)

    {:ok, ai_generated?}
  end

  def detect_ai_generated(binary) when is_binary(binary) do
    case Image.from_binary(binary) do
      {:ok, image} -> detect_ai_generated(image)
      {:error, _} -> {:ok, false}
    end
  end

  defp check_xmp_for_ai(image) do
    case Vix.Vips.Image.header_value_as_string(image, "xmp-data") do
      {:ok, xmp_blob} ->
        case Base.decode64(xmp_blob) do
          {:ok, xmp_binary} ->
            xmp_string = to_string(xmp_binary)

            Enum.any?(@ai_digital_source_types, &String.contains?(xmp_string, &1)) ||
              Enum.any?(@ai_software_patterns, &Regex.match?(&1, xmp_string))

          :error ->
            false
        end

      {:error, _} ->
        false
    end
  end

  defp check_exif_for_ai(image) do
    case Image.exif(image) do
      {:ok, exif} ->
        software = Map.get(exif, :software, "") || ""
        user_comment = Map.get(exif, :user_comment, "") || ""
        make = Map.get(exif, :make, "") || ""
        model = Map.get(exif, :model, "") || ""

        combined = Enum.join([software, user_comment, make, model], " ")
        Enum.any?(@ai_software_patterns, &Regex.match?(&1, combined))

      {:error, _} ->
        false
    end
  end

  defp check_software_field(image) do
    case Vix.Vips.Image.header_value_as_string(image, "software") do
      {:ok, software} ->
        Enum.any?(@ai_software_patterns, &Regex.match?(&1, software))

      {:error, _} ->
        false
    end
  end

  defp mime_suffix("image/jpeg"), do: ".jpg"
  defp mime_suffix("image/jpg"), do: ".jpg"
  defp mime_suffix("image/png"), do: ".png"
  defp mime_suffix("image/webp"), do: ".webp"
  defp mime_suffix("image/gif"), do: ".gif"
  defp mime_suffix(_), do: ".jpg"
end
