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
    options = Keyword.merge(@default_options, opts)
    MDEx.to_html!(markdown, options)
  end

  def to_html(_markdown, _opts), do: ""

  def to_safe_html(content) when is_binary(content) do
    MDEx.safe_html(content)
  end

  def to_safe_html(_content), do: ""
end
