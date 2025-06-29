defmodule Mosslet.AI.Images do
  @moduledoc """
  Functions for processing images with AI.
  """

  @doc """
  Classifies an image as either "normal"
  or "nsfw".
  """
  def check_for_safety(image_binary) do
    %{predictions: [%{label: label}]} =
      with {:ok, resized} <- Image.thumbnail(image_binary, "224x224"),
           {:ok, flattened} <- Image.flatten(resized),
           {:ok, srgb} <- Image.to_colorspace(flattened, :srgb),
           {:ok, tensor} <-
             Image.to_nx(srgb,
               shape: :hwc,
               backend: Application.fetch_env!(:nx, :default_backend)
             ) do
        Nx.Serving.batched_run(NsfwImageDetection, tensor)
      end

    case label do
      "normal" ->
        {:ok, image_binary}

      "nsfw" ->
        {:nsfw, "Image is not safe for upload."}

      true ->
        {:error, "There was an error trying to classify this image."}
    end
  end
end
