defmodule MossletWeb.ComboBox do
  @moduledoc false
  use Phoenix.Component

  alias PetalComponents.Field

  @doc """
  A combo box is a select box that allows you to search for options. It uses the [Tom Select library](https://tom-select.js.org/) under the hood.

  ## Usage:

      ```heex
      <.combo_box
        label="Single"
        placeholder="Select an option.."
        options={@widget_category_options}
        field={@form[:widget_category_names]}
        help_text="You can select only one option"
      />

      <.combo_box
        label="Multiple"
        multiple
        options={@widget_category_options}
        field={@form[:widget_category_names]}
        help_text="You can select multiple options"
      />

      <.combo_box
        multiple
        create
        label="Create new options"
        options={@widget_category_options}
        field={@form[:widget_category_names]}
        help_text="You can create new options"
      />
      ```

  ## Remote data source

  If you want to use your live view as a remote data source, you can set the `remote_options_event_name` option, which is similar to a `phx-change` event. When a user starts typing this will trigger an event with the name you pass. You handle the event in your live veiw return a list of options. The event will be passed the search term as first argument.

      ```heex
      <.combo_box
        label="Remote single"
        placeholder="Select an option.."
        remote_options_event_name="combo_box_search"
        field={@form[:widget_category_names]}
        help_text="You can select only one option"
      />
      ```

      ```elixir
      # @impl true
      def handle_event("combo_box_search", payload, socket) do

        # `payload` will be a string ("some search term")

        # Do your search and turn the results into a list of maps with `text` and `value` keys
        results =
          Widget.search_widget_categories(payload)
          |> Enum.map(&%{text: &1.name, value: &1.name})

        # Make sure you return a map with a `results` key. The value of the `results` key must be a list of maps with `text` and `value` keys
        {:reply, %{results: results}, socket}
      end
      ```

  More docs on https://petal.build/components/combo-box.
  """

  attr(:field, :any,
    doc:
      "the field to generate the input for. eg. `@form[:name]`. Needs to be a %Phoenix.HTML.FormField{}."
  )

  attr(:class, :string, default: nil, doc: "the class to add to the input")
  attr(:wrapper_class, :string, default: nil, doc: "the wrapper div classes")

  attr(:options, :list,
    doc:
      ~s|A list of options. eg. ["Admin", "User"] (label and value will be the same) or if you want the value to be different from the label: ["Admin": "admin", "User": "user"]. We use https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2 underneath.|,
    default: []
  )

  attr(:multiple, :boolean, default: false, doc: "can multiple choices be selected?")
  attr(:create, :boolean, default: false, doc: "create new options on the fly?")
  attr(:help_text, :string, default: nil, doc: "context/help for your field")

  attr(:max_items, :integer,
    default: nil,
    doc: "The maximum number of items that can be selected"
  )

  attr(:remote_options_event_name, :string,
    default: nil,
    doc:
      "The event name to trigger when searching for remote options. That event must return a li"
  )

  attr(:remote_options_target, :string,
    default: nil,
    doc:
      ~s|the target of the call for remote options. Will default to the current live view. For a live component, pass `remove_options_target={@myself}` if the event is handled on the live component.|
  )

  attr(:remove_button_title, :string,
    default: "Remove this item",
    doc: "The title for the remove item button"
  )

  attr(:placeholder, :string, default: "Select an option...", doc: "The placeholder text")

  attr(:tom_select_plugins, :map,
    default: %{},
    doc:
      ~s|Which plugins should be activated? Pass a map that will be converted to a Javascript object via JSON. eg. `%{remove_button: %{title: "Remove!"}}`. See https://tom-select.js.org/plugins for available plugins.|
  )

  attr(:tom_select_options, :map,
    default: %{},
    doc:
      "Options to pass to Tom Select. Uses camel case. eg `%{maxOptions: 1000}`. See https://tom-select.js.org/docs for options."
  )

  attr(:id, :any,
    default: nil,
    doc: "the id of the input. If not passed, it will be generated automatically from the field"
  )

  attr(:name, :any,
    doc: "the name of the input. If not passed, it will be generated automatically from the field"
  )

  attr(:label, :string,
    doc:
      "the label for the input. If not passed, it will be generated automatically from the field"
  )

  attr(:value, :any,
    doc:
      "the value of the input. If not passed, it will be generated automatically from the field"
  )

  attr(:errors, :list,
    default: [],
    doc:
      "a list of errors to display. If not passed, it will be generated automatically from the field. Format is a list of strings."
  )

  attr(:tom_select_options_global_variable, :string,
    default: nil,
    doc:
      ~s|for when you want to manually pass the options to Tom Select. eg. inside some script tags: `window.myOptions = { render: {...}}`. And in your component:`tom_select_options_global_variable="myOptions"`. It will merge the options with the existing ones.|
  )

  attr(:rest, :global,
    include:
      ~w(autocomplete disabled form max maxlength min minlength list
    pattern placeholder readonly required size step value name multiple selected default year month day hour minute second builder options layout cols rows wrap checked accept),
    doc: "All other props go on the input"
  )

  def combo_box(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(
      :errors,
      Enum.map(field.errors, &MossletWeb.CoreComponents.translate_error(&1))
    )
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> assign_new(:label, fn -> PhoenixHTMLHelpers.Form.humanize(field.field) end)
    |> combo_box()
  end

  def combo_box(assigns) do
    tom_select_options =
      %{
        create: assigns.create,
        maxItems: assigns.max_items
      }
      |> Map.merge(assigns.tom_select_options)
      |> remove_nil_keys()

    # If multiple, then add the checkbox plugin by default
    tom_select_plugins =
      assigns.tom_select_plugins
      |> maybe_add_plugin(:checkbox_options, %{}, !!assigns.multiple)
      |> maybe_add_plugin(
        :remove_button,
        %{
          title: assigns.remove_button_title
        },
        true
      )
      |> remove_falsy_keys()

    maybe_multiple_name =
      if assigns.multiple,
        do: assigns.name <> "[]",
        else: assigns.name

    assigns =
      assigns
      |> assign_new(:id, fn -> "combo-box-#{:rand.uniform(10_000_000) + 1}" end)
      |> assign(:tom_select_options_json, Jason.encode!(tom_select_options))
      |> assign(:tom_select_plugins_json, Jason.encode!(tom_select_plugins))
      |> assign(:maybe_multiple_name, maybe_multiple_name)

    ~H"""
    <Field.field_wrapper errors={@errors} name={@name} class={@wrapper_class}>
      <div
        id={@id}
        phx-hook="ComboBoxHook"
        data-options={@tom_select_options_json}
        data-plugins={@tom_select_plugins_json}
        data-global-options={@tom_select_options_global_variable}
        data-remote-options-event-name={@remote_options_event_name}
        data-remote-options-target={@remote_options_target}
        class="relative mt-1"
      >
        <select class="hidden combo-box-latest" multiple={@multiple}>
          <option :if={@placeholder} value="">{@placeholder}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
        <input type="hidden" name={@name} value="" />

        <div phx-update="ignore" id={"#{@id}_wrapper"}>
          <Field.field_label for={"#{@id}_select"}>
            {@label}
          </Field.field_label>

          <div class="opacity-0 combo-box-wrapper">
            <select
              id={"#{@id}_select"}
              name={@maybe_multiple_name}
              class={[@class, "combo-box"]}
              multiple={@multiple}
              {@rest}
              placeholder={@placeholder}
            >
              <option :if={@placeholder} value="">{@placeholder}</option>
              {Phoenix.HTML.Form.options_for_select(@options, @value)}
            </select>
          </div>
        </div>
      </div>

      <Field.field_error :for={msg <- @errors}>{msg}</Field.field_error>
      <Field.field_help_text help_text={@help_text} />
    </Field.field_wrapper>
    """
  end

  defp maybe_add_plugin(plugins, _plugin, _value, false), do: plugins

  defp maybe_add_plugin(plugins, plugin, value, true) do
    Map.put_new(plugins, plugin, value)
  end

  defp remove_falsy_keys(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if value,
        do: Map.put_new(acc, key, value),
        else: acc
    end)
  end

  defp remove_nil_keys(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if value != nil,
        do: Map.put_new(acc, key, value),
        else: acc
    end)
  end
end
