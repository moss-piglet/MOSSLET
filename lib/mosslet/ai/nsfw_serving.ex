defmodule Mosslet.AI.NsfwServing do
  @moduledoc """
  Supervised Nx.Serving for NSFW image detection.

  This module starts a supervised Nx.Serving process that caches the loaded model,
  enabling efficient batched inference on FLAME runners.
  """

  def child_spec(_opts) do
    serving = Mosslet.AI.NsfwImageDetection.serving()

    %{
      id: __MODULE__,
      start: {Nx.Serving, :start_link, [[name: __MODULE__, serving: serving]]},
      shutdown: 30_000
    }
  end
end
