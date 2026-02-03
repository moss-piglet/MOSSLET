defmodule Mosslet.AI.TextModeration do
  @moduledoc """
  Content moderation using toxic-comment-model for privacy-first detection.
  Detects toxic content without sending data to external services.

  https://huggingface.co/martin-ha/toxic-comment-model
  """

  @hf_model_repo "martin-ha/toxic-comment-model"

  def load do
    {:ok, model_info} =
      Bumblebee.load_model(
        {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)},
        architecture: :for_sequence_classification
      )

    {:ok, tokenizer} =
      Bumblebee.load_tokenizer(
        {:hf, @hf_model_repo, offline: Application.fetch_env!(:bumblebee, :offline)}
      )

    {model_info, tokenizer}
  end

  def serving do
    {model_info, tokenizer} = load()

    Bumblebee.Text.text_classification(model_info, tokenizer,
      compile: [batch_size: 4, sequence_length: 256],
      defn_options: Mosslet.AI.Backend.defn_options(),
      top_k: nil
    )
  end
end
