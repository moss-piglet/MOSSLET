defmodule Mosslet.AI.PrivacyFirst do
  @moduledoc """
  Privacy-first AI module providing server-side fallback for client-side AI.

  Architecture:
  - Client-side: Transformers.js runs AI models in the browser (WebLLM)
  - Server fallback: Bumblebee models run on Fly.io when client can't handle it

  All processing happens locally - no data sent to external AI services.

  ## Available Models

  | Feature          | Client (WebLLM)           | Server (Bumblebee)           |
  |------------------|---------------------------|------------------------------|
  | Text Generation  | SmolLM2-360M-Instruct     | SmolLM2-360M-Instruct        |
  | Text Moderation  | toxic-bert                | toxic-bert                   |
  | Image NSFW       | nsfwjs                    | Falconsai/nsfw_image_detection |
  | OCR              | (browser OCR)             | TrOCR                        |
  """

  require Logger

  @toxic_threshold 0.7

  @doc """
  Generates text using the local SmolLM2 model.
  Used as server fallback when client-side generation fails.
  """
  def generate_text(prompt, opts \\ []) do
    max_tokens = Keyword.get(opts, :max_tokens, 128)

    formatted_prompt = format_prompt(prompt, opts)

    case Nx.Serving.batched_run(TextGeneration, formatted_prompt) do
      %{results: [%{text: text}]} ->
        cleaned = clean_generated_text(text, formatted_prompt)
        {:ok, %{text: cleaned, source: :server, tokens: max_tokens}}

      error ->
        Logger.error("Text generation failed: #{inspect(error)}")
        {:error, "Text generation unavailable"}
    end
  rescue
    e ->
      Logger.error("Text generation error: #{inspect(e)}")
      {:error, "Text generation unavailable"}
  end

  @doc """
  Moderates text for toxic content using local toxic-bert model.
  Returns whether content should be blocked.
  """
  def moderate_text(text) do
    case Nx.Serving.batched_run(TextModeration, text) do
      %{predictions: predictions} ->
        toxic_score = find_toxic_score(predictions)
        is_toxic = toxic_score > @toxic_threshold

        {:ok,
         %{
           is_toxic: is_toxic,
           score: toxic_score,
           predictions: predictions,
           source: :server
         }}

      error ->
        Logger.error("Text moderation failed: #{inspect(error)}")
        {:ok, %{is_toxic: false, score: 0, source: :server, error: "Moderation unavailable"}}
    end
  rescue
    e ->
      Logger.error("Text moderation error: #{inspect(e)}")
      {:ok, %{is_toxic: false, score: 0, source: :server}}
  end

  @doc """
  Checks if an image is NSFW using the Falconsai model.
  Uses existing NsfwImageDetection serving.
  """
  def check_image_nsfw(image_binary) when is_binary(image_binary) do
    with {:ok, image} <- Image.from_binary(image_binary),
         {:ok, resized} <- Image.thumbnail(image, "224x224"),
         {:ok, flattened} <- Image.flatten(resized),
         {:ok, srgb} <- Image.to_colorspace(flattened, :srgb),
         {:ok, tensor} <-
           Image.to_nx(srgb,
             shape: :hwc,
             backend: Application.fetch_env!(:nx, :default_backend)
           ) do
      case Nx.Serving.batched_run(NsfwImageDetection, tensor) do
        %{predictions: [%{label: label, score: score}]} ->
          is_nsfw = label == "nsfw"

          {:ok, %{is_nsfw: is_nsfw, label: label, score: score, source: :server}}

        error ->
          Logger.error("NSFW detection failed: #{inspect(error)}")
          {:error, "NSFW detection unavailable"}
      end
    else
      error ->
        Logger.error("Image processing failed: #{inspect(error)}")
        {:error, "Image processing failed"}
    end
  rescue
    e ->
      Logger.error("NSFW check error: #{inspect(e)}")
      {:error, "NSFW detection unavailable"}
  end

  @doc """
  Extracts text from an image using TrOCR.
  Designed for handwritten journal entries.
  """
  def extract_text_from_image(image_binary) when is_binary(image_binary) do
    with {:ok, image} <- Image.from_binary(image_binary),
         {:ok, resized} <- Image.thumbnail(image, "384x384"),
         {:ok, tensor} <-
           Image.to_nx(resized,
             shape: :hwc,
             backend: Application.fetch_env!(:nx, :default_backend)
           ) do
      case Nx.Serving.batched_run(OCR, tensor) do
        %{results: [%{text: text}]} ->
          cleaned = String.trim(text)

          if cleaned == "" do
            {:error, :no_text_found}
          else
            {:ok, %{text: cleaned, source: :server}}
          end

        error ->
          Logger.error("OCR failed: #{inspect(error)}")
          {:error, "OCR unavailable"}
      end
    else
      error ->
        Logger.error("Image processing for OCR failed: #{inspect(error)}")
        {:error, "Image processing failed"}
    end
  rescue
    e ->
      Logger.error("OCR error: #{inspect(e)}")
      {:error, "OCR unavailable"}
  end

  @doc """
  Handles server fallback requests from the client-side AI hook.
  Called via LiveView events.
  """
  def handle_fallback("moderate_text", %{"text" => text}) do
    {:ok, result} = moderate_text(text)
    result
  end

  def handle_fallback("generate_text", %{"prompt" => prompt} = params) do
    opts = [
      max_tokens: Map.get(params, "max_tokens", 128),
      system_prompt: Map.get(params, "system_prompt")
    ]

    case generate_text(prompt, opts) do
      {:ok, result} -> Map.put(result, :success, true)
      {:error, reason} -> %{success: false, error: reason}
    end
  end

  def handle_fallback("check_nsfw", %{"image_data" => image_data}) do
    binary =
      case image_data do
        "data:" <> _ -> decode_data_url(image_data)
        _ when is_binary(image_data) -> image_data
      end

    case check_image_nsfw(binary) do
      {:ok, result} -> Map.put(result, :success, true)
      {:error, reason} -> %{success: false, error: reason}
    end
  end

  def handle_fallback(action, _params) do
    Logger.warning("Unknown AI fallback action: #{action}")
    %{success: false, error: "Unknown action"}
  end

  defp format_prompt(prompt, opts) do
    system = Keyword.get(opts, :system_prompt)

    if system do
      "<|im_start|>system\n#{system}<|im_end|>\n<|im_start|>user\n#{prompt}<|im_end|>\n<|im_start|>assistant\n"
    else
      "<|im_start|>user\n#{prompt}<|im_end|>\n<|im_start|>assistant\n"
    end
  end

  defp clean_generated_text(text, prompt) do
    text
    |> String.replace(prompt, "")
    |> String.replace(~r/<\|im_end\|>.*$/s, "")
    |> String.trim()
  end

  defp find_toxic_score(predictions) do
    predictions
    |> Enum.find(fn %{label: label} -> String.downcase(label) == "toxic" end)
    |> case do
      %{score: score} -> score
      nil -> 0
    end
  end

  defp decode_data_url("data:" <> rest) do
    case String.split(rest, ",", parts: 2) do
      [_header, data] -> Base.decode64!(data)
      _ -> <<>>
    end
  end

  defp decode_data_url(_), do: <<>>
end
