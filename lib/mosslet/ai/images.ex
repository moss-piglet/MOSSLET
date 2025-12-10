defmodule Mosslet.AI.Images do
  @moduledoc """
  Functions for processing images with AI.
  """

  require Logger

  @doc """
  Classifies an image as either "normal"
  or "nsfw".
  """
  def check_for_safety(image) do
    with {:ok, resized} <- thumbnail_image(image),
         {:ok, flattened} <- flatten_image(resized),
         {:ok, srgb} <- to_srgb_image(flattened),
         {:ok, tensor} <- to_tensor(srgb),
         {:ok, label} <- classify_image(tensor) do
      case label do
        "normal" -> {:ok, image}
        "nsfw" -> {:nsfw, "Image is not safe for upload."}
        _ -> {:error, "Unknown classification label: #{label}"}
      end
    end
  end

  defp thumbnail_image(image) do
    case Image.thumbnail(image, "224x224") do
      {:ok, _} = result ->
        result

      {:error, reason} ->
        Logger.error("🖼️ Safety thumbnail failed: #{inspect(reason)}")
        {:error, "Failed to resize image for safety check"}
    end
  end

  defp flatten_image(image) do
    case Image.flatten(image) do
      {:ok, _} = result ->
        result

      {:error, reason} ->
        Logger.error("🖼️ Safety flatten failed: #{inspect(reason)}")
        {:error, "Failed to flatten image for safety check"}
    end
  end

  defp to_srgb_image(image) do
    case Image.to_colorspace(image, :srgb) do
      {:ok, _} = result ->
        result

      {:error, reason} ->
        Logger.error("🖼️ Safety srgb failed: #{inspect(reason)}")
        {:error, "Failed to convert colorspace for safety check"}
    end
  end

  defp to_tensor(image) do
    bands = Image.bands(image)

    Logger.info(
      "🖼️ to_tensor: bands=#{bands}, interpretation=#{inspect(Image.interpretation(image))}"
    )

    image =
      cond do
        bands == 4 ->
          case Image.split_alpha(image) do
            {:ok, rgb} -> rgb
            _ -> image
          end

        bands == 1 ->
          case Image.to_colorspace(image, :srgb) do
            {:ok, rgb} -> rgb
            _ -> image
          end

        bands == 3 ->
          image

        true ->
          Logger.warning("🖼️ Unexpected band count: #{bands}, attempting to extract RGB")

          case Vix.Vips.Operation.extract_band(image, 0, n: min(bands, 3)) do
            {:ok, rgb} -> rgb
            _ -> image
          end
      end

    Logger.info(
      "🖼️ to_tensor after processing: bands=#{Image.bands(image)}, format=#{inspect(Vix.Vips.Image.format(image))}"
    )

    with {:ok, memory_image} <- Vix.Vips.Image.copy_memory(image) do
      case Image.to_nx(memory_image,
             shape: :hwc,
             backend: Application.fetch_env!(:nx, :default_backend)
           ) do
        {:ok, _} = result ->
          result

        {:error, reason} ->
          Logger.error(
            "🖼️ Safety to_nx failed: #{inspect(reason)}, format=#{inspect(Vix.Vips.Image.format(image))}"
          )

          {:error, "Failed to convert image to tensor for safety check"}
      end
    else
      {:error, reason} ->
        Logger.error("🖼️ copy_memory failed: #{inspect(reason)}")
        {:error, "Failed to convert image to tensor for safety check"}
    end
  end

  defp classify_image(tensor) do
    case Nx.Serving.batched_run(NsfwImageDetection, tensor) do
      %{predictions: [%{label: label}]} ->
        {:ok, label}

      other ->
        Logger.error("🖼️ Safety classify failed: #{inspect(other)}")
        {:error, "Failed to classify image"}
    end
  end
end
