defmodule Mix.Tasks.Bumblebee.Download do
  @moduledoc """
  Downloads Bumblebee models for caching during Docker build.
  """
  use Mix.Task

  @shortdoc "Downloads Bumblebee models"
  def run(_args) do
    Application.ensure_all_started(:exla)
    Application.ensure_all_started(:bumblebee)

    Mix.shell().info("Downloading NSFW detection model...")
    Mosslet.AI.NsfwImageDetection.load()
    Mix.shell().info("Model downloaded successfully!")
  end
end
