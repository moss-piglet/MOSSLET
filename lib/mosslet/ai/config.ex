defmodule Mosslet.AI.Config do
  @moduledoc """
  Centralized AI configuration for privacy-first LLM usage.

  Uses privacy-respecting providers via OpenRouter:
  - No training on data
  - No request logging
  - Data collection denied via provider preferences

  All requests include privacy headers via openrouter_provider preferences.
  """

  @vision_model "openrouter:openai/gpt-4o-mini"
  @text_model "openrouter:qwen/qwen3-30b-a3b-instruct-2507"

  @privacy_opts [
    provider_options: [
      openrouter_provider: %{
        data_collection: "deny"
      }
    ]
  ]

  def vision_model, do: @vision_model
  def text_model, do: @text_model

  def privacy_opts, do: @privacy_opts

  def vision_opts(additional_opts \\ []) do
    Keyword.merge(@privacy_opts, additional_opts)
  end

  def text_opts(additional_opts \\ []) do
    Keyword.merge(@privacy_opts, additional_opts)
  end
end
