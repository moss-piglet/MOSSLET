defmodule MossletWeb.ContentEditor do
  @moduledoc false
  use Phoenix.Component

  import PetalComponents.Alert
  import PetalComponents.Table

  alias PetalComponents.Field
  alias Mosslet.Extensions.MapExt

  attr :id, :any,
    default: nil,
    doc: "the id of the input. If not passed, it will be generated automatically from the field"

  attr :field, :any,
    doc:
      "the field to generate the input for. eg. `@form[:name]`. Needs to be a %Phoenix.HTML.FormField{}."

  attr :label, :string,
    doc:
      "the label for the input. If not passed, it will be generated automatically from the field"

  attr :help_text, :string, default: nil, doc: "context/help for your field"

  attr :wrapper_class, :any,
    # Stolen from pc-text-input, but adjusted for div and uses "focus-within" instead of "focus":
    default: [
      "block w-full border border-gray-300 rounded-md shadow-sm px-4 py-2",
      "focus-within:border-primary-500 focus-within:ring-2 focus-within:ring-offset-[-1px] focus-within:ring-primary-500",
      "dark:border-gray-600 dark:focus-within:border-primary-500",
      "sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed",
      "dark:bg-gray-800 dark:text-gray-300 dark:disabled:bg-gray-700",
      "focus-within:outline-none"
    ],
    doc: "the wrapper div classes"

  attr :class, :any,
    default:
      "min-h-32 prose dark:prose-invert prose-img:rounded-xl prose-pre:rounded-xl prose-img:mx-auto prose-a:text-primary-600 prose-a:dark:text-primary-300 max-w-none",
    doc: "the class to add to the input"

  attr :label_class, :any, default: nil, doc: "extra CSS for your label"

  attr :placeholder, :string, default: "A monkey loves to eat bananas"

  attr :name, :any,
    doc: "the name of the input. If not passed, it will be generated automatically from the field"

  attr :value, :any,
    doc:
      "the value of the input. If not passed, it will be generated automatically from the field"

  attr :errors, :list,
    default: [],
    doc:
      "a list of errors to display. If not passed, it will be generated automatically from the field. Format is a list of strings."

  attr :required, :boolean,
    default: false,
    doc: "is this field required? is passed to the input and adds an asterisk next to the label"

  attr :rest, :global,
    include:
      ~w(autocomplete autocorrect autocapitalize disabled form max maxlength min minlength list
    pattern placeholder readonly required size step value name multiple prompt default year month day hour minute second builder options layout cols rows wrap checked accept),
    doc: "All other props go on the input"

  def content_field(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(
      :errors,
      Enum.map(field.errors, &MossletWeb.CoreComponents.translate_error(&1))
    )
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> assign_new(:label, fn -> PhoenixHTMLHelpers.Form.humanize(field.field) end)
    |> content_field()
  end

  def content_field(assigns) do
    ~H"""
    <Field.field_wrapper errors={@errors} name={@name}>
      <Field.field_label required={@required} for={@id} class={@label_class}>
        {@label}
      </Field.field_label>
      <div
        id={"#{@id}_wrapper"}
        class={@wrapper_class}
        phx-hook="EditorJsHook"
        data-placeholder={@placeholder}
      >
        <input type="hidden" name={@name} value={@value} {@rest} />

        <div id="editorjs" phx-update="ignore" class={@class} />
      </div>

      <Field.field_error :for={msg <- @errors}>{msg}</Field.field_error>
      <Field.field_help_text help_text={@help_text} />
    </Field.field_wrapper>
    """
  end

  @doc """
  Renders editorjs output beautifully using Tailwind Typography classes.

      <.pretty_content json="{ blocks: [] }" />
  """

  attr :json, :string, required: true

  attr :prose_class, :any,
    default: [
      "prose dark:prose-invert max-w-full prose-img:rounded-xl prose-pre:rounded-xl",
      "prose-img:mx-auto prose-a:text-primary-600 prose-a:dark:text-primary-300"
    ]

  attr :class, :any, default: nil

  attr :rest, :global

  def pretty_content(assigns) do
    json_object = decode_json(assigns.json)

    assigns = assign(assigns, :has_content, has_content(json_object))

    ~H"""
    <div :if={@has_content} {@rest} class={join_classes(@prose_class, @class)}>
      <.content json={@json} />
    </div>
    """
  end

  @doc """
  Renders editorjs output to html.

      <.content json="{ blocks: [] }" />
  """

  attr :json, :string, required: true

  def content(assigns) do
    json_object = decode_json(assigns.json)

    blocks =
      case json_object do
        %{"blocks" => blocks} -> MapExt.atomize_keys(blocks)
        _ -> []
      end

    assigns = assign(assigns, :blocks, blocks)

    ~H"""
    <.block :for={block <- @blocks} block={block} />
    """
  end

  attr :block, :map, required: true

  defp block(%{block: %{type: "paragraph", data: %{text: text}}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"<p>{@text |> Phoenix.HTML.raw()}</p>"
  end

  defp block(%{block: %{type: "header", data: %{text: text, level: level}}} = assigns) do
    assigns =
      assigns
      |> assign(:level, level)
      |> assign(:text, text)

    ~H"""
    <.h level={@level}>
      {@text}
    </.h>
    """
  end

  defp block(%{block: %{type: "delimiter"}} = assigns) do
    ~H"""
    <p class="text-center text-2xl">* * *</p>
    """
  end

  defp block(%{block: %{type: "list", data: %{style: "ordered", items: items}}} = assigns) do
    assigns = assign(assigns, :items, items)

    ~H"""
    <ol>
      <li :for={item <- @items}>
        {item}
      </li>
    </ol>
    """
  end

  defp block(%{block: %{type: "list", data: %{style: "unordered", items: items}}} = assigns) do
    assigns = assign(assigns, :items, items)

    ~H"""
    <ul>
      <li :for={item <- @items}>
        {item |> Phoenix.HTML.raw()}
      </li>
    </ul>
    """
  end

  defp block(%{block: %{type: "quote", data: %{text: text, caption: caption}}} = assigns) do
    assigns =
      assigns
      |> assign(:text, text)
      |> assign(:caption, caption)

    ~H"""
    <blockquote>
      <div :if={@text && @text != ""}>
        {@text}
      </div>
      <div :if={@caption && @caption != ""}>
        {@caption}
      </div>
    </blockquote>
    """
  end

  defp block(
         %{
           block: %{
             type: "image",
             data: %{
               url: url,
               caption: caption,
               stretched: stretched,
               withBackground: with_background,
               withBorder: with_border
             }
           }
         } = assigns
       ) do
    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:caption, caption)
      |> assign(:stretched, stretched)
      |> assign(:with_background, with_background)
      |> assign(:with_border, with_border)

    ~H"""
    <div class={[
      "grid gap-2 my-8",
      @with_background && "bg-gray-200 dark:bg-gray-500 p-4",
      @stretched && "w-full"
    ]}>
      <img
        src={@url}
        class={[
          "m-0",
          if(@with_background, do: "object-scale-down", else: "object-contain"),
          @with_border && "border dark:border-gray-500"
        ]}
      />
      <div :if={@caption && @caption != ""} class="text-center">{@caption}</div>
    </div>
    """
  end

  defp block(%{block: %{type: "petalImage", data: %{url: url, caption: caption}}} = assigns) do
    assigns =
      assigns
      |> assign(:url, url)
      |> assign(:caption, caption)

    ~H"""
    <div :if={@url && @url !== ""} class="grid gap-2 my-8">
      <img src={@url} class="m-0 object-contain" />
      <div :if={@caption && @caption != ""} class="text-center">{@caption}</div>
    </div>
    """
  end

  defp block(%{block: %{type: "table", data: %{withHeadings: true, content: content}}} = assigns) do
    assigns =
      assigns
      |> assign(:headings, Enum.take(content, 1))
      |> assign(:items, Enum.drop(content, 1))

    ~H"""
    <.table class="not-prose">
      <.tr :for={cells <- @headings}>
        <.th :for={cell <- cells}>{cell}</.th>
      </.tr>

      <.tr :for={cells <- @items}>
        <.td :for={cell <- cells}>{cell}</.td>
      </.tr>
    </.table>
    """
  end

  defp block(%{block: %{type: "table", data: %{withHeadings: false, content: content}}} = assigns) do
    assigns = assign(assigns, :items, content)

    ~H"""
    <.table class="not-prose">
      <.tr :for={cells <- @items}>
        <.td :for={cell <- cells}>{cell}</.td>
      </.tr>
    </.table>
    """
  end

  defp block(%{block: %{type: "warning", data: %{title: title, message: message}}} = assigns) do
    assigns =
      assigns
      |> assign(:heading, title)
      |> assign(:message, message)

    ~H"""
    <.alert with_icon color="warning" heading={@heading} class="not-prose">{@message}</.alert>
    """
  end

  defp block(%{block: %{type: "code", data: %{code: code}}} = assigns) do
    assigns = assign(assigns, :code, code)

    ~H"<pre><code><%= @code %></code></pre>"
  end

  defp block(
         %{
           block: %{
             type: "embed",
             data: %{caption: caption, embed: embed, height: height, width: width}
           }
         } = assigns
       ) do
    assigns =
      assigns
      |> assign(:caption, caption)
      |> assign(:embed, embed)
      |> assign(:height, height)
      |> assign(:width, width)

    ~H"""
    <div class="grid gap-2 justify-items-center py-4">
      <iframe
        width={@width}
        height={@height}
        src={@embed}
        title={@caption}
        frameborder="0"
        allowfullscreen
      >
      </iframe>
      <p :if={@caption} class="text-xs my-0">{@caption}</p>
    </div>
    """
  end

  defp block(assigns) do
    ~H""
  end

  defp h(%{level: 1} = assigns), do: ~H"<h1>{render_slot(@inner_block)}</h1>"
  defp h(%{level: 2} = assigns), do: ~H"<h2>{render_slot(@inner_block)}</h2>"
  defp h(%{level: 3} = assigns), do: ~H"<h3>{render_slot(@inner_block)}</h3>"
  defp h(%{level: 4} = assigns), do: ~H"<h4>{render_slot(@inner_block)}</h4>"
  defp h(%{level: 5} = assigns), do: ~H"<h5>{render_slot(@inner_block)}</h5>"
  defp h(assigns), do: ~H"<h6>{render_slot(@inner_block)}</h6>"

  defp decode_json(json) do
    json =
      case json do
        nil -> "{}"
        "" -> "{}"
        _ -> json
      end

    Jason.decode!(json)
  end

  defp has_content(json_object), do: json_object["blocks"] && json_object["blocks"] != []

  defp join_classes(left, right) when is_nil(right), do: left
  defp join_classes(left, right) when is_nil(left), do: right

  defp join_classes(left, right) when is_bitstring(left) and is_bitstring(right),
    do: [left, right]

  defp join_classes(left, right) when is_list(left) and is_bitstring(right), do: left ++ [right]
  defp join_classes(left, right) when is_bitstring(left) and is_list(right), do: [left] ++ right
  defp join_classes(left, right) when is_list(left) and is_list(right), do: left ++ right
end
