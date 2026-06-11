defmodule Mosslet.Bluesky.Labels do
  @moduledoc """
  Maps between Mosslet content-warning state and AT Protocol self-labels.

  AT Protocol expresses post-level sensitivity via self-labels embedded in the
  record under `com.atproto.label.defs#selfLabels`. The recognized values are
  `sexual`, `nudity`, `porn`, and `graphic-media`.

  ## Zero-knowledge boundary

  Mosslet content-warning *category* text is end-to-end encrypted and must never
  leave the platform. Only the coarse, non-identifying sensitivity signal
  crosses to Bluesky:

    * A post flagged `mature_content` (or carrying a content warning) exports a
      single conservative `graphic-media` self-label.

  We deliberately do **not** attempt to infer `sexual`/`nudity`/`porn` from the
  encrypted category, since that would require reading private text and Mosslet
  has no equivalent adult-content taxonomy. `graphic-media` is the safe default
  that signals "this is sensitive, blur it" to Bluesky clients.
  """

  @self_labels_type "com.atproto.label.defs#selfLabels"

  # Conservative default applied to any sensitive Mosslet post on export.
  @default_export_label "graphic-media"

  # AT Protocol self-label values that indicate sensitive content on import.
  @sensitive_vals MapSet.new(~w(sexual nudity porn graphic-media))

  @doc """
  Builds the AT Protocol self-labels object for a post being exported, or `nil`
  when the post carries no sensitivity signal.

  Pass the post's `mature_content` boolean and `content_warning?` flag.

      iex> Mosslet.Bluesky.Labels.self_labels_for_export(true, false)
      %{"$type" => "com.atproto.label.defs#selfLabels",
        "values" => [%{"val" => "graphic-media"}]}

      iex> Mosslet.Bluesky.Labels.self_labels_for_export(false, false)
      nil
  """
  @spec self_labels_for_export(boolean(), boolean()) :: map() | nil
  def self_labels_for_export(mature_content?, content_warning?) do
    if mature_content? || content_warning? do
      %{
        "$type" => @self_labels_type,
        "values" => [%{"val" => @default_export_label}]
      }
    else
      nil
    end
  end

  @doc """
  Returns `true` when an imported record's `labels` contain any sensitive
  AT Protocol self-label value.

  Accepts the (atomized) `labels` map from a fetched record. Tolerates missing
  or malformed label data by returning `false`.

      iex> labels = %{values: [%{val: "graphic-media"}]}
      iex> Mosslet.Bluesky.Labels.sensitive?(labels)
      true

      iex> Mosslet.Bluesky.Labels.sensitive?(nil)
      false
  """
  @spec sensitive?(map() | nil) :: boolean()
  def sensitive?(labels) do
    labels
    |> extract_values()
    |> Enum.any?(fn val -> MapSet.member?(@sensitive_vals, val) end)
  end

  defp extract_values(%{values: values}) when is_list(values), do: collect_vals(values)
  defp extract_values(%{"values" => values}) when is_list(values), do: collect_vals(values)
  defp extract_values(_), do: []

  defp collect_vals(values) do
    values
    |> Enum.map(fn
      %{val: val} when is_binary(val) -> val
      %{"val" => val} when is_binary(val) -> val
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end
