defmodule Mosslet.AI.OCR do
  @moduledoc """
  TrOCR for privacy-first handwritten text recognition.
  Extracts text from journal images without external API calls.

  https://huggingface.co/microsoft/trocr-small-handwritten
  """

  @hf_model_repo "microsoft/trocr-small-handwritten"

  def load do
    {:ok, model_info} =
      Bumblebee.load_model(
        {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)}
      )

    {:ok, featurizer} =
      Bumblebee.load_featurizer(
        {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)}
      )

    {:ok, tokenizer} =
      Bumblebee.load_tokenizer(
        {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)}
      )

    {:ok, generation_config} =
      Bumblebee.load_generation_config(
        {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)}
      )

    {model_info, featurizer, tokenizer, generation_config}
  end

  def serving do
    {model_info, featurizer, tokenizer, generation_config} = load()

    Bumblebee.Vision.image_to_text(model_info, featurizer, tokenizer, generation_config,
      compile: [batch_size: 1],
      defn_options: Mosslet.AI.Backend.defn_options()
    )
  end
end
