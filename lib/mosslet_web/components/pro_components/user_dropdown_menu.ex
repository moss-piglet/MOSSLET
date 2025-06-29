defmodule MossletWeb.UserDropdownMenu do
  @moduledoc """
  Deprecated. Moved to Petal Components
  """

  use Phoenix.Component

  import PetalComponents.Dropdown
  import PetalComponents.Icon

  attr :user_menu_items, :list,
    doc: "list of maps with keys :path, :icon (atom), :label, :method (atom)"

  attr :current_user_name, :string, doc: "the current signed in user's name"
  attr :avatar_src, :string, default: nil, doc: "the current signed in user's avatar image src"

  def user_menu_dropdown(%{user_menu_items: nil}), do: nil
  def user_menu_dropdown(%{user_menu_items: []}), do: nil

  def user_menu_dropdown(assigns) do
    ~H"""
    <.dropdown
      menu_items_wrapper_class="bg-background-50 dark:bg-gray-800 shadow-md dark:shadow-emerald-500/50"
      class="relative"
    >
      <:trigger_element>
        <div class="inline-flex items-center justify-center w-full align-middle focus:outline-none cursor-pointer">
          <%= if @current_user_name || @avatar_src do %>
            <MossletWeb.CoreComponents.phx_avatar
              name={@current_user_name}
              src={@avatar_src}
              size="size-8"
              text_size="2xl"
            />
          <% else %>
            <MossletWeb.CoreComponents.phx_avatar size="size-8" />
          <% end %>

          <.icon
            name="hero-chevron-down-mini"
            class="w-4 h-4 ml-1 mr-1 text-background-400 dark:text-background-100"
          />
        </div>
      </:trigger_element>
      <%= for menu_item <- @user_menu_items do %>
        <.dropdown_menu_item
          link_type={if menu_item[:method], do: "a", else: "live_redirect"}
          method={if menu_item[:method], do: menu_item[:method], else: nil}
          to={menu_item.path}
          class="text-background-700 dark:text-gray-400 hover:bg-background-200 dark:hover:bg-gray-900"
        >
          <%= if is_binary(menu_item.icon) do %>
            <.icon name={menu_item.icon} class="w-5 h-5 text-background-700 dark:text-gray-400" />
          <% end %>

          <%= if is_function(menu_item.icon) do %>
            {Phoenix.LiveView.TagEngine.component(
              menu_item.icon,
              [class: "w-5 h-5 text-background-700 dark:text-gray-400"],
              {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
            )}
          <% end %>

          {menu_item.label}
        </.dropdown_menu_item>
      <% end %>
    </.dropdown>
    """
  end
end
