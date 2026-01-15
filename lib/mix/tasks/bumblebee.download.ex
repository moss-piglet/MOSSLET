defmodule Mix.Tasks.Bumblebee.Download do
  @moduledoc """
  Downloads Bumblebee models for caching during Docker build.

  This ensures models are pre-downloaded and available offline in production.

  ## Models Downloaded

  - Falconsai/nsfw_image_detection - NSFW image classification
  - martin-ha/toxic-comment-model - Text moderation
  """
  use Mix.Task

  @shortdoc "Downloads Bumblebee models for privacy-first AI"

  @models [
    {"NSFW detection (Falconsai)", Mosslet.AI.NsfwImageDetection},
    {"Text moderation (toxic-bert)", Mosslet.AI.TextModeration}
  ]

  def run(args) do
    Application.ensure_all_started(:exla)
    Application.ensure_all_started(:bumblebee)

    models_to_download =
      case args do
        [] -> @models
        ["--only" | names] -> filter_models(names)
        _ -> @models
      end

    total = length(models_to_download)

    Enum.with_index(models_to_download, 1)
    |> Enum.each(fn {{name, module}, index} ->
      Mix.shell().info("[#{index}/#{total}] Downloading #{name}...")

      try do
        module.load()
        Mix.shell().info("  ✓ #{name} downloaded successfully")
      rescue
        e ->
          Mix.shell().error("  ✗ Failed to download #{name}: #{Exception.message(e)}")
      end
    end)

    Mix.shell().info("\nAll models downloaded!")
  end

  defp filter_models(names) do
    name_set = MapSet.new(names)

    @models
    |> Enum.filter(fn {name, _module} ->
      Enum.any?(name_set, &String.contains?(String.downcase(name), String.downcase(&1)))
    end)
  end
end
