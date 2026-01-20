defmodule Mosslet.AI.FlameBumblebee do
  @moduledoc """
  FLAME-based Bumblebee inference for memory-intensive AI models.

  Offloads Bumblebee model inference to ephemeral Fly machines,
  preventing OOM crashes on the main 2GB app instances.

  Used as a fallback when OpenRouter API is unavailable.
  """

  require Logger

  @hf_model_repo "Falconsai/nsfw_image_detection"

  @doc """
  Classifies an image as "normal" or "nsfw" using Bumblebee on a FLAME runner.
  Returns {:ok, binary} for safe images, {:nsfw, reason} for unsafe, {:error, reason} on failure.
  """
  def check_nsfw(image_binary) when is_binary(image_binary) do
    case FLAME.call(Mosslet.FlameBumblebeePool, fn -> run_nsfw_classification(image_binary) end) do
      {:ok, _} = result ->
        result

      {:nsfw, _} = result ->
        result

      {:error, _} = result ->
        result

      {:exit, reason} ->
        Logger.error("FLAME Bumblebee NSFW check exited: #{inspect(reason)}")
        {:error, "NSFW detection unavailable"}
    end
  end

  defp run_nsfw_classification(image_binary) do
    with {:ok, {model_info, featurizer}} <- load_model(),
         {:ok, tensor} <- prepare_image(image_binary),
         {:ok, result} <- classify(model_info, featurizer, tensor, image_binary) do
      result
    end
  end

  defp load_model do
    offline = Application.get_env(:bumblebee, :offline, false)

    with {:ok, model_info} <- Bumblebee.load_model({:hf, @hf_model_repo, offline: offline}),
         {:ok, featurizer} <-
           Bumblebee.load_featurizer({:hf, @hf_model_repo, offline: offline},
             module: Bumblebee.Vision.VitFeaturizer
           ) do
      {:ok, {model_info, featurizer}}
    else
      error ->
        Logger.error("Failed to load Bumblebee model: #{inspect(error)}")
        {:error, "Model loading failed"}
    end
  end

  defp prepare_image(image_binary) do
    with {:ok, image} <- Image.from_binary(image_binary),
         {:ok, resized} <- Image.thumbnail(image, "224x224"),
         {:ok, flattened} <- Image.flatten(resized),
         {:ok, srgb} <- Image.to_colorspace(flattened, :srgb),
         {:ok, tensor} <-
           Image.to_nx(srgb,
             shape: :hwc,
             backend: Application.fetch_env!(:nx, :default_backend)
           ) do
      {:ok, tensor}
    else
      error ->
        Logger.error("Image preparation failed: #{inspect(error)}")
        {:error, "Image processing failed"}
    end
  end

  defp classify(model_info, featurizer, tensor, image_binary) do
    serving =
      Bumblebee.Vision.image_classification(model_info, featurizer,
        top_k: 1,
        compile: [batch_size: 1],
        defn_options: [compiler: EXLA]
      )

    case Nx.Serving.run(serving, tensor) do
      %{predictions: [%{label: "normal"}]} ->
        {:ok, {:ok, image_binary}}

      %{predictions: [%{label: "nsfw"}]} ->
        {:ok, {:nsfw, "Image flagged by safety check."}}

      _ ->
        {:ok, {:error, "Unable to classify image."}}
    end
  end
end
