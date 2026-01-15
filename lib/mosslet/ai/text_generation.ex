defmodule Mosslet.AI.TextGeneration do
  @moduledoc """
  SmolLM2-360M-Instruct for privacy-first text generation.
  A small, fast model suitable for journaling prompts and simple generation.

  https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct
  """

  @hf_model_repo "HuggingFaceTB/SmolLM2-360M-Instruct"

  def load do
    {:ok, model_info} =
      Bumblebee.load_model(
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

    generation_config = Bumblebee.configure(generation_config, max_new_tokens: 128)

    {model_info, tokenizer, generation_config}
  end

  def serving do
    {model_info, tokenizer, generation_config} = load()

    Bumblebee.Text.generation(model_info, tokenizer, generation_config,
      compile: [batch_size: 1, sequence_length: 512],
      defn_options: [compiler: EXLA],
      stream: false
    )
  end
end
