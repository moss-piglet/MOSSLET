defmodule MossletWeb.DataTable.Header do
  @moduledoc false
  use Phoenix.Component

  import PetalComponents.Dropdown
  import PetalComponents.Field
  import PetalComponents.Form
  import PetalComponents.Icon
  import PetalComponents.Link
  import PetalComponents.Table
  use Gettext, backend: MossletWeb.Gettext
  import Phoenix.HTML.Form

  def render(assigns) do
    index = order_index(assigns.meta.flop, assigns.column[:field])
    direction = order_direction(assigns.meta.flop.order_directions, index)

    assigns =
      assigns
      |> assign(:currently_ordered, index == 0)
      |> assign(:order_direction, direction)

    ~H"""
    <.th class={"align-top #{@column[:class] || ""}"}>
      <%= if @column[:sortable] && !@no_results? do %>
        <.a
          class={
              "flex items-center gap-3 #{if @currently_ordered, do: "text-gray-900 dark:text-white font-semibold", else: "text-gray-500 dark:text-gray-400"} #{if @column[:align_right], do: "justify-end", else: ""}"
            }
          to={order_link(@column, @meta, @currently_ordered, @order_direction, @base_url_params)}
          link_type="live_patch"
        >
          {get_label(@column)}
          <.icon
            outline
            name={
              if @currently_ordered && @order_direction == :desc,
                do: :chevron_down,
                else: :chevron_up
            }
            class="h-4"
          />
        </.a>
      <% else %>
        <div class={if @column[:align_right], do: "text-right whitespace-nowrap", else: ""}>
          {get_label(@column)}
        </div>
      <% end %>
      <%= if @column[:filterable] && (@filtered? || !@no_results?) do %>
        <.inputs_for :let={f2} field={@filter_form[:filters]}>
          <%= if input_value(f2, :field) == @column.field do %>
            <.field field={f2[:field]} type="hidden" />

            <div class="flex items-center gap-2 mt-2">
              <%= case @column[:type] do %>
                <% :integer -> %>
                  <.number_input
                    form={f2}
                    field={:value}
                    phx-debounce="200"
                    placeholder={get_filter_placeholder(input_value(f2, :op))}
                    class="!text-xs !py-1"
                  />
                <% :float -> %>
                  <.number_input
                    form={f2}
                    field={:value}
                    phx-debounce="200"
                    placeholder={get_filter_placeholder(input_value(f2, :op))}
                    class="!text-xs !py-1"
                    step={@column[:step] || 1}
                  />
                <% :boolean -> %>
                  <.select
                    form={f2}
                    field={:value}
                    options={[{"True", true}, {"False", false}]}
                    prompt="-"
                    class="!text-xs !py-1"
                    size="sm"
                  />
                <% :select -> %>
                  <.select
                    form={f2}
                    field={:value}
                    options={@column[:options]}
                    prompt={@column[:prompt] || "-"}
                    class="!text-xs !py-1"
                    size="sm"
                  />
                <% _ -> %>
                  <.search_input
                    form={f2}
                    field={:value}
                    phx-debounce="200"
                    placeholder={get_filter_placeholder(input_value(f2, :op))}
                    class="!text-xs !py-1"
                  />
              <% end %>

              <%= if length(@column[:filterable]) > 1 do %>
                <.dropdown>
                  <:trigger_element>
                    <div class="inline-flex items-center justify-center w-full align-middle focus:outline-none">
                      <.icon outline name={:funnel} class="w-4 h-4 text-gray-400 dark:text-gray-600" />
                      <.icon
                        solid
                        name={:chevron_down}
                        class="w-4 h-4 ml-1 -mr-1 text-gray-400 dark:text-gray-100"
                      />
                    </div>
                  </:trigger_element>
                  <div class="p-3 font-normal normal-case">
                    <.form_field
                      type="radio_group"
                      form={f2}
                      field={:op}
                      label="Operation"
                      options={@column.filterable |> Enum.map(&{get_filter_placeholder(&1), &1})}
                    />
                  </div>
                </.dropdown>
              <% else %>
                {PhoenixHTMLHelpers.Form.hidden_input(f2, :op)}
              <% end %>
            </div>
          <% end %>
        </.inputs_for>
      <% end %>
    </.th>
    """
  end

  defp get_label(column) do
    case column[:label] do
      nil ->
        PhoenixHTMLHelpers.Form.humanize(column.field)

      label ->
        label
    end
  end

  defp order_link(column, meta, currently_ordered, order_direction, base_url_params) do
    params =
      Map.merge(base_url_params, %{
        order_by: [column.field, column[:order_by_backup] || :inserted_at],
        order_directions:
          cond do
            currently_ordered && order_direction == :desc ->
              [:asc, :desc]

            currently_ordered && order_direction == :asc ->
              [:desc, :desc]

            true ->
              [:asc, :desc]
          end
      })

    MossletWeb.DataTable.build_url_query(meta, params)
  end

  defp order_index(%Flop{order_by: nil}, _), do: nil

  defp order_index(%Flop{order_by: order_by}, field) do
    Enum.find_index(order_by, &(&1 == field))
  end

  defp order_direction(_, nil), do: nil
  defp order_direction(nil, _), do: :asc
  defp order_direction(directions, index), do: Enum.at(directions, index)

  defp get_filter_placeholder(op) do
    op_map()[op]
  end

  # List of op options
  def op_map do
    %{
      ==: gettext("Equals"),
      !=: gettext("Not equal"),
      =~: gettext("Search (case insensitive)"),
      empty: gettext("Is empty"),
      not_empty: gettext("Not empty"),
      <=: gettext("Less than or equals"),
      <: gettext("Less than"),
      >=: gettext("Greater than or equals"),
      >: gettext("Greater than"),
      in: gettext("Search in"),
      contains: gettext("Contains"),
      like: gettext("Search (case sensitive)"),
      like_and: gettext("Search (case sensitive) (and)"),
      like_or: gettext("Search (case sensitive) (or)"),
      ilike: gettext("Search (case insensitive)"),
      ilike_and: gettext("Search (case insensitive) (and)"),
      ilike_or: gettext("Search (case insensitive) (or)")
    }
  end
end
