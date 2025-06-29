defmodule MossletWeb.DataTable do
  @moduledoc """
  Render your data with ease. Uses Flop under the hood: https://github.com/woylie/flop

  ## Installation

  Add deps:

  ```elixir
  {:money, "~> 1.12"},
  {:petal_components, "~> 1.0"},
  ```

  ## Example
      # In a Live View
      defmodule MyAppWeb.PostLive.Index do
        use MyAppWeb, :live_view

        import MyAppWeb.DataTable

        alias MyApp.Widgets
        alias MyApp.Widgets.Widget

        @impl true
        def mount(_params, _session, socket) do
          {:ok, assign(socket)}
        end

        @impl true
        def handle_params(params, _url, socket) do
          starting_query = Mosslet.Widgets.Widget

          flop_opts = [
            default_limit: 10,
            default_order: %{
              order_by: [:views, :title],
              order_directions: [:desc, :asc]
            }
          ]

          socket =
            case Flop.validate_and_run(starting_query, params, flop_opts) do
              {:ok, {items, meta}} ->
                assign(socket, %{
                  items: items,
                  meta: meta
                })

              _ ->
                push_navigate(socket, to: ~p"/components/data-table")
            end

          {:noreply, socket}
        end

        @impl true
        def handle_event("update_filters", %{"filters" => filter_params}, socket) do
          query_params = build_filter_params(socket.assigns.meta, filter_params)
          # Remove backslash on the next line
          {:noreply, push_patch(socket, to: ~p"/posts?\#{query_params}")}
        end

        @impl true
        def handle_event("delete", %{"id" => id} = params, socket) do
          post = Posts.get_post!(id)
          {:ok, _} = Posts.delete_post(post)

          case Flop.validate_and_run(Post, params, for: Post) do
            {:ok, {posts, meta}} ->
              socket =
                socket
                |> put_flash(:info, "Post deleted")
                |> assign(posts: posts, meta: meta)

              {:noreply, socket}

            _ ->
              {:noreply, push_navigate(socket, to: ~p"/posts")}
          end
        end

        @impl true
        def handle_event("close_modal", _, socket) do
          {:noreply, push_patch(socket, to: current_index_path(socket))}
        end

        defp assign_posts(socket, params) do
          case Posts.filter_posts(params) do
            {:ok, {posts, meta}} ->
              assign(socket, %{
                posts: posts,
                meta: meta
              })

            _ ->
              push_navigate(socket, to: ~p"/posts")
          end
        end
      end

      # In your template:
      <.data_table :if={@index_params} meta={@meta} items={@posts}>
        <:if_empty>No posts found</:if_empty>
        <:col field={:title} sortable />
        <:col field={:height} sortable type={:integer}  />
        <:col
          field={:category}
          sortable
          filterable={[:==]}
          type={:select}
          options={[
            {"Option 1", "option_1"},
            {"Option 2", "option_2"}
          ]}
          prompt="Select a category"
        />
        <:col label="Actions" :let={post} align_right>
          <.button
            color="primary"
            variant="outline"
            size="xs"
            link_type="live_redirect"
            label="Show"
            to={~p"/posts/\#{post}"}
          />
        </:col>
      </.data_table>

  ## <:col> attributes:
  ### Sortable (default: false)
    <:col field={:name} sortable />

  ### Filterable
  You can filter your columns by using the `filterable` property.
      <:col field={:name} filterable={:==} />

  Represents valid filter operators.
  | Operator        | Value               | WHERE clause                                            |
  | :-------------- | :------------------ | ------------------------------------------------------- |
  | `:==`           | `"Salicaceae"`      | `WHERE column = 'Salicaceae'`                           |
  | `:!=`           | `"Salicaceae"`      | `WHERE column != 'Salicaceae'`                          |
  | `:=~`           | `"cyth"`            | `WHERE column ILIKE '%cyth%'`                           |
  | `:empty`        | `true`              | `WHERE (column IS NULL) = true`                         |
  | `:empty`        | `false`             | `WHERE (column IS NULL) = false`                        |
  | `:not_empty`    | `true`              | `WHERE (column IS NOT NULL) = true`                     |
  | `:not_empty`    | `false`             | `WHERE (column IS NOT NULL) = false`                    |
  | `:<=`           | `10`                | `WHERE column <= 10`                                    |
  | `:<`            | `10`                | `WHERE column < 10`                                     |
  | `:>=`           | `10`                | `WHERE column >= 10`                                    |
  | `:>`            | `10`                | `WHERE column > 10`                                     |
  | `:in`           | `["pear", "plum"]`  | `WHERE column = ANY('pear', 'plum')`                    |
  | `:not_in`       | `["pear", "plum"]`  | `WHERE column = NOT IN('pear', 'plum')`                 |
  | `:contains`     | `"pear"`            | `WHERE 'pear' = ANY(column)`                            |
  | `:not_contains` | `"pear"`            | `WHERE 'pear' = NOT IN(column)`                         |
  | `:like`         | `"cyth"`            | `WHERE column LIKE '%cyth%'`                            |
  | `:not_like`     | `"cyth"`            | `WHERE column NOT LIKE '%cyth%'`                        |
  | `:like_and`     | `["Rubi", "Rosa"]`  | `WHERE column LIKE '%Rubi%' AND column LIKE '%Rosa%'`   |
  | `:like_and`     | `"Rubi Rosa"`       | `WHERE column LIKE '%Rubi%' AND column LIKE '%Rosa%'`   |
  | `:like_or`      | `["Rubi", "Rosa"]`  | `WHERE column LIKE '%Rubi%' OR column LIKE '%Rosa%'`    |
  | `:like_or`      | `"Rubi Rosa"`       | `WHERE column LIKE '%Rubi%' OR column LIKE '%Rosa%'`    |
  | `:ilike`        | `"cyth"`            | `WHERE column ILIKE '%cyth%'`                           |
  | `:not_ilike`    | `"cyth"`            | `WHERE column NOT ILIKE '%cyth%'`                       |
  | `:ilike_and`    | `["Rubi", "Rosa"]`  | `WHERE column ILIKE '%Rubi%' AND column ILIKE '%Rosa%'` |
  | `:ilike_and`    | `"Rubi Rosa"`       | `WHERE column ILIKE '%Rubi%' AND column ILIKE '%Rosa%'` |
  | `:ilike_or`     | `["Rubi", "Rosa"]`  | `WHERE column ILIKE '%Rubi%' OR column ILIKE '%Rosa%'`  |
  | `:ilike_or`     | `"Rubi Rosa"`       | `WHERE column ILIKE '%Rubi%' OR column ILIKE '%Rosa%'`  |

  ### Renderer
  The type of cell that will be rendered. eg:

      <:col field={:name} sortable renderer={:plaintext} />
      <:col field={:inserted_at} renderer={:date} date_format={YYYY} />

  Renderer options:
    :plaintext (for strings) *default
    :checkbox (for booleans)
    :date paired with optional param date_format: "%Y" - s<% https://hexdocs.pm/elixir/1.15.4/Calendar.html#strftime/3 %>
    :datetime paired with optional param date_format: "%Y"
    :money paired with optional currency: "USD" (for money)

  ## Query options for Flop

  You can pass query options for Flop with the query_opts keyword, https://hexdocs.pm/flop/Flop.html#types, e.g.
      Flop.validate_and_run(User, query_params, max_limit: 100)

  ## Compound & join fields

  For these you will need to use https://hexdocs.pm/flop/Flop.Schema.html.

  Follow the instructions on setting up the `@derive` bit in your schema file. For join fields,
  make sure your `ecto_query` has a join in it. You have to name the join field too. Eg:

      # In your model
      @derive {
        Flop.Schema,
        filterable: [:field_from_joined_table],
        sortable: [:field_from_joined_table],
        join_fields: [field_from_joined_table: {:some_other_table, :field_name}]
      }

      # The ecto_query called by your Live View:
      query = from(m in __MODULE__,
        join: u in assoc(m, :some_other_table),
        as: :some_other_table,
        preload: [:some_other_table])

      Flop.validate_and_run(query, params, for: __MODULE__)

      # Now you can do a col with that field
      <:col field={:field_from_joined_table} let={something}>
        <%= something.some_other_table.field_name %>
      </:col>

  ### TODO
  - Can order_by joined table fields (e.g. customer.user.name)
  - Date picker for filters
  """
  use Phoenix.Component

  import PetalComponents.Pagination
  import PetalComponents.Table
  use Gettext, backend: MossletWeb.Gettext

  alias MossletWeb.DataTable.Cell
  alias MossletWeb.DataTable.Filter
  alias MossletWeb.DataTable.FilterSet
  alias MossletWeb.DataTable.Header

  @defaults [
    page_size_options: [10, 20, 50]
  ]

  attr :meta, Flop.Meta, required: true
  attr :items, :list, required: true
  attr :page_size_options, :list, required: false
  attr :base_url_params, :map, required: false
  attr :phx_hook, :string, required: false
  attr :class, :string, default: nil, doc: "CSS class to add to the table"

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
    attr :field, :atom
    attr :sortable, :boolean
    attr :filterable, :list
    attr :date_format, :string
    attr :order_by_backup, :atom

    attr :type, :atom,
      values: [:integer, :float, :boolean, :select],
      doc: "What type of filter do you want this to be?"

    attr :step, :float
    attr :options, :list, doc: "If type is select, what are the options?"
    attr :prompt, :string, doc: "If type is select, what is the prompt? Defaults to '-'"

    attr :renderer, :atom,
      values: [:plaintext, :checkbox, :date, :datetime, :money],
      doc: "How do you want your value to be rendered?"

    attr :align_right, :boolean, doc: "Aligns the column to the right"
  end

  slot :if_empty, required: false

  def data_table(assigns) do
    filter_changeset = build_filter_changeset(assigns.col, assigns.meta.flop)
    assigns = assign(assigns, :filter_changeset, filter_changeset)

    assigns =
      assigns
      |> assign(:filtered?, Enum.any?(assigns.meta.flop.filters, fn x -> x.value end))
      |> assign_new(:filter_changeset, fn ->
        filter_set = %FilterSet{}

        FilterSet.changeset(filter_set)
      end)
      |> assign_new(:page_sizes, fn ->
        assigns[:page_size_options] || Keyword.get(@defaults, :page_size_options)
      end)
      |> assign_new(:base_url_params, fn -> %{} end)
      |> assign_new(:phx_hook, fn -> nil end)

    ~H"""
    <div class={@class}>
      <.form
        :let={filter_form}
        id="data-table-filter-form"
        for={@filter_changeset}
        as={:filters}
        phx-change="update_filters"
        phx-submit="update_filters"
        phx-hook={@phx_hook}
      >
        <.table class="overflow-visible">
          <thead>
            <.tr>
              <%= for col <- @col do %>
                <Header.render
                  column={col}
                  meta={@meta}
                  filter_form={filter_form}
                  no_results?={@items == []}
                  filtered?={@filtered?}
                  base_url_params={@base_url_params}
                />
              <% end %>
            </.tr>
          </thead>
          <tbody>
            <%= if @items == [] do %>
              <.tr>
                <.td colspan={length(@col)}>
                  {if @if_empty, do: render_slot(@if_empty), else: "No results"}
                </.td>
              </.tr>
            <% end %>

            <.tr :for={item <- @items}>
              <.td
                :for={col <- @col}
                class={"#{if col[:align_right], do: "text-right", else: ""} #{col[:class]}"}
              >
                <%= if col[:inner_block] do %>
                  {render_slot(col, item)}
                <% else %>
                  <Cell.render column={col} item={item} />
                <% end %>
              </.td>
            </.tr>
          </tbody>
        </.table>
      </.form>

      <div :if={@items != []} class="flex items-center justify-between mt-5">
        <div class="text-sm text-gray-600 dark:text-gray-400">
          <div>
            {gettext("Showing")} {get_first_item_index(@meta)}-{get_last_item_index(@meta)} {gettext(
              "of"
            )} {@meta.total_count} {gettext("rows")}
          </div>
          <div :if={@page_sizes != []} class="flex gap-2">
            <div>{gettext("Rows per page")}:</div>

            <%= for page_size <- @page_sizes do %>
              <%= if @meta.page_size == page_size do %>
                <div class="font-semibold">{page_size}</div>
              <% else %>
                <.link
                  patch={
                    build_url_query(
                      @meta,
                      Map.merge(@base_url_params, %{page_size: page_size, page: 1})
                    )
                  }
                  class="block text-emerald-600 dark:text-emerald-400"
                >
                  {page_size}
                </.link>
              <% end %>
            <% end %>
          </div>
        </div>

        <%= if @meta.total_pages > 1 do %>
          <.pagination
            link_type="live_patch"
            class="my-5"
            path={
              build_url_query(@meta, Map.merge(@base_url_params, %{page: ":page"}))
              |> String.replace("%3Apage", ":page")
            }
            current_page={@meta.current_page}
            total_pages={@meta.total_pages}
          />
        <% end %>
      </div>
    </div>
    """
  end

  def build_url_query(meta, query_params) do
    params = build_params(meta, query_params)

    "?" <> Plug.Conn.Query.encode(params)
  end

  defp get_first_item_index(meta) do
    if meta.current_page == 1 do
      1
    else
      (meta.current_page - 1) * meta.page_size + 1
    end
  end

  defp get_last_item_index(meta) do
    if meta.current_page == meta.total_pages do
      meta.total_count
    else
      meta.current_page * meta.page_size
    end
  end

  defp to_query(%Flop{filters: filters} = flop, opts) do
    filter_map =
      filters
      |> Enum.filter(fn filter -> filter.value != nil end)
      |> Stream.with_index()
      |> Map.new(fn {filter, index} ->
        {index, Map.from_struct(filter)}
      end)

    default_limit = Flop.get_option(:default_limit, opts)
    default_order = Flop.get_option(:default_order, opts)

    []
    |> maybe_put(:offset, flop.offset, 0)
    |> maybe_put(:page, flop.page, 1)
    |> maybe_put(:after, flop.after)
    |> maybe_put(:before, flop.before)
    |> maybe_put(:page_size, flop.page_size, default_limit)
    |> maybe_put(:limit, flop.limit, default_limit)
    |> maybe_put(:first, flop.first, default_limit)
    |> maybe_put(:last, flop.last, default_limit)
    |> maybe_put_order_params(flop, default_order)
    |> maybe_put(:filters, filter_map)
  end

  @spec maybe_put(keyword, atom, any, any) :: keyword
  defp maybe_put(params, key, value, default \\ nil)
  defp maybe_put(keywords, _, nil, _), do: keywords
  defp maybe_put(keywords, _, [], _), do: keywords
  defp maybe_put(keywords, _, map, _) when map == %{}, do: keywords

  # It's not enough to avoid setting (initially), we need to remove any existing value
  defp maybe_put(keywords, key, val, val), do: Keyword.delete(keywords, key)

  defp maybe_put(keywords, key, value, _), do: Keyword.put(keywords, key, value)

  # Puts the order params of a into a keyword list only if they don't match the
  # defaults passed as the last argument.
  defp maybe_put_order_params(
         params,
         %{order_by: order_by, order_directions: order_directions},
         %{
           order_by: order_by,
           order_directions: order_directions
         }
       ),
       do: params

  defp maybe_put_order_params(
         params,
         %{order_by: order_by, order_directions: order_directions},
         _
       ) do
    params
    |> maybe_put(:order_by, order_by)
    |> maybe_put(:order_directions, order_directions)
  end

  defp build_filter_changeset(columns, flop) do
    filters =
      Enum.reduce(columns, [], fn col, acc ->
        if col[:filterable] do
          default_op = List.first(col.filterable)
          flop_filter = Enum.find(flop.filters, &(&1.field == col.field))

          filter = %Filter{
            field: col.field,
            op: (flop_filter && flop_filter.op) || default_op,
            value: (flop_filter && flop_filter.value) || nil
          }

          [filter | acc]
        else
          acc
        end
      end)

    filter_set = %FilterSet{filters: filters}
    FilterSet.changeset(filter_set)
  end

  defp build_params(%{flop: flop, opts: opts}, query_params) do
    params =
      Keyword.new(query_params, fn {k, v} ->
        k = if Kernel.is_bitstring(k), do: String.to_atom(k), else: k

        {k, v}
      end)

    flop_params = to_query(flop, opts)

    params ++ flop_params
  end

  @doc """
  Use this to build a query when the filters have changed. Pass a flop and the params from the "update_filters" event.

  Usage:
      def handle_event("update_filters", %{filters => filter_params}, socket) do
        query_params = build_filter_params(socket.assigns.flop, filter_params)
        {:noreply, push_patch(socket, to: ~p"/admin/users?\#{query_params}")}
      end
  """
  def build_filter_params(meta, filter_params \\ %{}) do
    meta
    |> build_params(filter_params)
    |> Keyword.put(:page, "1")
  end

  def build_filter_params(meta, base_url_params, filter_params) do
    params = Map.merge(base_url_params, filter_params)

    build_filter_params(meta, params)
  end

  @doc """
  Wrapper around Flop.validate_and_run/3
  """
  def search(queryable, flop_or_params, opts \\ []) do
    Flop.validate_and_run!(queryable, flop_or_params, opts)
  end
end
