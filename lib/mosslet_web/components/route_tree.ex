defmodule MossletWeb.RouteTree do
  @moduledoc """
  Show's a list of your apps routes. Can copy the helper function for any route.

  Usage:
      <.route_tree router={YourAppWeb.Router} />
  """

  use Phoenix.Component
  use PetalComponents

  attr(:router, :any, doc: "Your application router module")

  def route_tree(assigns) do
    all_routes =
      assigns.router
      |> Phoenix.Router.routes()
      |> Enum.map(fn route -> Map.put(route, :path_list, split_path(route.path)) end)

    assigns = assign(assigns, all_routes: all_routes, sections: get_sections(all_routes))

    ~H"""
    <div class="flex flex-col gap-1 ml-[60px]">
      <%= for key <- @sections do %>
        <div class="mt-3 font-bold">{PhoenixHTMLHelpers.Form.humanize(key)}</div>
        <%= for route <- get_routes_by_key(key, @all_routes, @sections) do %>
          <.route route={route} />
        <% end %>
      <% end %>
    </div>
    """
  end

  attr(:route, :map)

  def route(assigns) do
    ~H"""
    <div
      class="relative flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-800"
      id={route_id(@route)}
      phx-hook="TippyHook"
      data-tippy-content={"Click to copy " <> get_route_helper(@route)}
    >
      <div
        class="flex items-center w-full gap-2 cursor-pointer"
        id={route_id(@route) <> "_copy_button"}
        phx-hook="ClipboardHook"
        data-content={get_route_helper(@route)}
      >
        <div class="absolute left-[-60px] w-[46px] flex justify-end">
          <.badge color={get_verb_color(get_verb(@route))} size="sm" label={get_verb(@route)} />
        </div>
        <div class="text-sm font-semibold">{@route.path}</div>
        <div class="">
          <.icon name="hero-arrow-long-right" class="h-4" />
        </div>
        <div class="text-sm">
          {get_module(@route)}
        </div>
        <div class="flex gap-3 text-sm text-gray-500 dark:text-gray-400">
          {get_action(@route)}
          <div class="before-copied"></div>
          <div class="hidden text-green-600 after-copied dark:text-green-300">Copied!</div>
        </div>
      </div>
    </div>
    """
  end

  defp get_sections(all_routes) do
    sections =
      all_routes
      |> Enum.map(&List.first(&1.path_list))
      |> Enum.uniq()
      |> Enum.filter(fn path ->
        Enum.find(all_routes, fn route ->
          length(route.path_list) > 1 && List.first(route.path_list) == path
        end)
      end)

    ["root" | sections]
  end

  defp split_path(path) do
    for segment <- String.split(path, "/"), segment != "", do: segment
  end

  defp route_id(route),
    do: "path_#{route.path}_#{route.verb}" |> String.replace("/", "_") |> String.replace(":", "_")

  defp get_routes_by_key("root", all_routes, sections) do
    # Here we find the routes that have only one path and no children.
    Enum.filter(all_routes, fn route ->
      !Enum.member?(sections, List.first(route.path_list))
    end)
  end

  defp get_routes_by_key(key, all_routes, _) do
    Enum.filter(all_routes, &(List.first(&1.path_list) == key))
  end

  defp get_verb(route) do
    is_live = route.plug |> Atom.to_string() |> String.contains?("Live")

    if is_live do
      :live
    else
      route.verb
    end
  end

  defp get_verb_color(verb) do
    case verb do
      :get -> "success"
      :live -> "warning"
      :post -> "info"
      :put -> "info"
      :delete -> "danger"
      _ -> "gray"
    end
  end

  defp get_module(%{metadata: %{log_module: module}}), do: format_module(module)
  defp get_module(%{plug: module}), do: format_module(module)

  defp get_action(%{plug_opts: plug_opts}) when is_binary(plug_opts) or is_atom(plug_opts) do
    string = "#{plug_opts}"

    if String.contains?(string, "Elixir.") do
      ""
    else
      ":#{string}"
    end
  end

  defp get_action(_), do: ""

  defp format_module(module) do
    String.replace(to_string(module), "Elixir.", "")
  end

  defp get_route_helper(%{helper: nil}), do: ""

  defp get_route_helper(route) do
    "~p\"" <> route.path <> "\""
  end
end
