defmodule MossletWeb.Markdown do
  @moduledoc """
  Uses Earmark. Supports Github Flavored Markdown. Syntax highlighting is not supported yet.
  """

  use Phoenix.Component

  @doc """
  Renders markdown beautifully using Tailwind Typography classes.

      <.pretty_markdown content="# My markdown" />
  """

  attr :content, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global

  def pretty_markdown(assigns) do
    ~H"""
    <div
      {@rest}
      class={[
        "prose dark:prose-invert prose-img:rounded-xl prose-img:mx-auto prose-a:text-primary-600 prose-a:dark:text-primary-300",
        @class
      ]}
    >
      <.markdown content={@content} />
    </div>
    """
  end

  @doc """
  Renders markdown to html.
  """

  attr :content, :string, required: true

  def markdown(assigns) do
    ~H"""
    {Mosslet.MarkdownRenderer.to_html(@content) |> Phoenix.HTML.raw()}
    """
  end
end
