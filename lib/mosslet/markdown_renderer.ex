defmodule Mosslet.MarkdownRenderer do
  @moduledoc """
  Renders markdown as HTML using MDEx with syntax highlighting.
  Uses MDEx's built-in sanitization (ammonia) for XSS protection.
  """

  @default_options [
    extension: [
      strikethrough: true,
      table: true,
      autolink: true,
      tasklist: true,
      superscript: true,
      footnotes: true
    ],
    parse: [
      smart: true,
      relaxed_autolinks: true
    ],
    render: [
      unsafe: true,
      hardbreaks: true
    ],
    syntax_highlight: [
      formatter: {:html_linked, []}
    ],
    sanitize: MDEx.Document.default_sanitize_options()
  ]

  def to_html(markdown \\ "", opts \\ [])

  def to_html(markdown, opts) when is_binary(markdown) do
    {normalize_headings_to, opts} = Keyword.pop(opts, :normalize_headings_to, nil)
    options = Keyword.merge(@default_options, opts)
    html = MDEx.to_html!(markdown, options)

    if normalize_headings_to do
      normalize_heading_levels(html, normalize_headings_to)
    else
      html
    end
  end

  def to_html(_markdown, _opts), do: ""

  def to_safe_html(content) when is_binary(content) do
    MDEx.safe_html(content)
  end

  def to_safe_html(_content), do: ""

  defp normalize_heading_levels(html, target_min_level) do
    heading_levels =
      Regex.scan(~r/<h([1-6])[^>]*>/i, html)
      |> Enum.map(fn [_, level] -> String.to_integer(level) end)

    if heading_levels == [] do
      html
    else
      min_level = Enum.min(heading_levels)
      shift = target_min_level - min_level

      if shift == 0 do
        html
      else
        Regex.replace(~r/<(\/?)h([1-6])([^>]*)>/i, html, fn _, slash, level, attrs ->
          new_level = String.to_integer(level) + shift
          new_level = max(1, min(new_level, 6))
          "<#{slash}h#{new_level}#{attrs}>"
        end)
      end
    end
  end
end
