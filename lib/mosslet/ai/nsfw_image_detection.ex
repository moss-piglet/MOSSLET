defmodule Mosslet.AI.NsfwImageDetection do
  @moduledoc """
  Define the NsfwImageDetection model for nsfw image detection.

  - https://huggingface.co/Falconsai/nsfw_image_detection
  """

  @hf_model_repo "Falconsai/nsfw_image_detection"

  def load() do
    {:ok, model_info} =
      Bumblebee.load_model(
        {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)}
      )

    {:ok, featurizer} =
      Bumblebee.load_featurizer(
        {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)},
        module: Bumblebee.Vision.VitFeaturizer
      )

    {model_info, featurizer}
  end

  def serving() do
    # NOTE: After the model is downloaded, you can toggle to `offline: true` to
    #       only use the locally cached files and not reach out to HF at all.
    # we do this in ENV variables
    # nsfw =
    #  {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)}

    {model_info, featurizer} = load()

    Bumblebee.Vision.image_classification(model_info, featurizer,
      top_k: 1,
      compile: [batch_size: 4],
      defn_options: [compiler: EXLA]
    )

    # {:ok, model_info} = Bumblebee.load_model(nsfw)

    # {:ok, featurizer} =
    #  Bumblebee.load_featurizer({:hf, "Falconsai/nsfw_image_detection"},
    #    module: Bumblebee.Vision.VitFeaturizer
    #  )

    # Bumblebee.Vision.image_classification(model_info, featurizer,
    #  top_k: 1,
    #  compile: [batch_size: 20],
    #  defn_options: [compiler: EXLA]
    # )
  end
end
