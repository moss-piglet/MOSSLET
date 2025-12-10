defmodule Mosslet.AI.Images do
  @moduledoc """
  Functions for processing images with AI.
  """

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

      {:error, _reason} ->
        {:error, "Failed to resize image for safety check"}
    end
  end

  defp flatten_image(image) do
    case Image.flatten(image) do
      {:ok, _} = result ->
        result

      {:error, _reason} ->
        {:error, "Failed to flatten image for safety check"}
    end
  end

  defp to_srgb_image(image) do
    case Image.to_colorspace(image, :srgb) do
      {:ok, _} = result ->
        result

      {:error, _reason} ->
        {:error, "Failed to convert colorspace for safety check"}
    end
  end

  defp to_tensor(image) do
    bands = Image.bands(image)

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
          case Vix.Vips.Operation.extract_band(image, 0, n: min(bands, 3)) do
            {:ok, rgb} -> rgb
            _ -> image
          end
      end

    with {:ok, image} <- materialize_image(image),
         {:ok, memory_image} <- Vix.Vips.Image.copy_memory(image) do
      case Image.to_nx(memory_image,
             shape: :hwc,
             backend: Application.fetch_env!(:nx, :default_backend)
           ) do
        {:ok, _} = result ->
          result

        {:error, _reason} ->
          {:error, "Failed to convert image to tensor for safety check"}
      end
    else
      {:error, _reason} ->
        {:error, "Failed to convert image to tensor for safety check"}
    end
  end

  defp materialize_image(image) do
    with {:ok, png_binary} <- Image.write(image, :memory, suffix: ".png"),
         {:ok, materialized} <- Image.from_binary(png_binary) do
      {:ok, materialized}
    else
      {:error, _reason} ->
        {:ok, image}
    end
  end

  defp classify_image(tensor) do
    case Nx.Serving.batched_run(NsfwImageDetection, tensor) do
      %{predictions: [%{label: label}]} ->
        {:ok, label}

      _other ->
        {:error, "Failed to classify image"}
    end
  end
end
