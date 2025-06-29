defmodule MossletWeb.Navbar do
  @moduledoc """
  A responsive navbar that contains a main menu and dropdown menu (user menu)
  """
  use Phoenix.Component

  import MossletWeb.CoreComponents, only: [phx_avatar: 1]
  import PetalComponents.{Container, Link}
  import MossletWeb.UserDropdownMenu

  attr :current_page, :atom, required: true
  attr :main_menu_items, :list, default: []
  attr :user_menu_items, :list, default: []
  attr :current_user_name, :string, default: nil
  attr :avatar_src, :string, default: nil
  attr :class, :string, default: ""
  attr :home_path, :string, default: "/"
  attr :container_max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]
  slot(:inner_block)
  slot(:top_right)
  slot(:logo)

  def navbar(assigns) do
    ~H"""
    <div class={"bg-white dark:bg-gray-800 shadow #{@class}"} x-data="{mobileMenuOpen: false}">
      <.container max_width={@container_max_width}>
        <div class="flex justify-between h-16">
          <div class="flex">
            <.link navigate={@home_path}>
              {render_slot(@logo)}
            </.link>

            <%= if get_in(@main_menu_items, [Access.at(0), :menu_items]) do %>
              <div class="hidden divide-x divide-gray-100 lg:flex dark:divide-gray-700">
                <%= for menu_group <- @main_menu_items do %>
                  <div class="px-8 lg:flex lg:space-x-8">
                    <%= for menu_item <- menu_group.menu_items do %>
                      <.a
                        to={menu_item.path}
                        label={menu_item.label}
                        class={main_menu_item_class(@current_page, menu_item.name)}
                      />
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="hidden lg:ml-6 lg:flex lg:space-x-8">
                <%= for menu_item <- @main_menu_items do %>
                  <.a
                    to={menu_item.path}
                    label={menu_item.label}
                    class={main_menu_item_class(@current_page, menu_item.name)}
                  />
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="hidden gap-3 lg:ml-6 lg:flex lg:items-center">
            {render_slot(@top_right)}

            <.user_menu_dropdown
              user_menu_items={@user_menu_items}
              avatar_src={@avatar_src}
              current_user_name={@current_user_name}
            />
          </div>

          <div class="flex items-center -mr-2 lg:hidden">
            <button
              type="button"
              class="inline-flex items-center justify-center p-2 text-gray-400 rounded-md dark:text-gray-600 hover:text-gray-500 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500"
              aria-controls="mobile-menu"
              @click="mobileMenuOpen = !mobileMenuOpen"
              x-bind:aria-expanded="mobileMenuOpen.toString()"
            >
              <span class="sr-only">
                Open main menu
              </span>

              <div
                class="w-6 h-6"
                x-bind:class="{ 'hidden': mobileMenuOpen, 'block': !(mobileMenuOpen) }"
              >
                <MossletWeb.CoreComponents.phx_icon name="hero-bars-3" class="w-6 h-6" />
              </div>

              <div
                class="w-6 h-6"
                x-bind:class="{ 'block': mobileMenuOpen, 'hidden': !(mobileMenuOpen) }"
              >
                <MossletWeb.CoreComponents.phx_icon name="hero-x-mark" class="w-6 h-6" />
              </div>
            </button>
          </div>
        </div>
      </.container>

      <div
        class="lg:hidden"
        x-cloak="true"
        x-show="mobileMenuOpen"
        x-transition:enter="transition transform ease-out duration-100"
        x-transition:enter-start="transform opacity-0 scale-95"
        x-transition:enter-end="transform opacity-100 scale-100"
        x-transition:leave="transition ease-in duration-75"
        x-transition:leave-start="transform opacity-100 scale-100"
        x-transition:leave-end="transform opacity-0 scale-95"
      >
        <%= if get_in(@main_menu_items, [Access.at(0), :menu_items]) do %>
          <div class="divide-y divide-gray-100 dark:divide-gray-700">
            <%= for menu_group <- @main_menu_items do %>
              <div class="pt-3 pb-3 first:pt-0">
                <%= for menu_item <- menu_group.menu_items do %>
                  <.link
                    navigate={menu_item.path}
                    class={mobile_menu_item_class(@current_page, menu_item.name)}
                  >
                    {menu_item.label}
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="pt-2 pb-3 space-y-1">
            <%= for menu_item <- @main_menu_items do %>
              <.link
                navigate={menu_item.path}
                class={mobile_menu_item_class(@current_page, menu_item.name)}
              >
                {menu_item.label}
              </.link>
            <% end %>
          </div>
        <% end %>
        <div class="pt-4 pb-3 border-t border-gray-200 dark:border-gray-700">
          <div class="flex items-center justify-between px-4">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <%= if @current_user_name || @avatar_src do %>
                  <.phx_avatar name={@current_user_name} src={@avatar_src} size="size-6" />
                <% else %>
                  <.phx_avatar size="size-6" />
                <% end %>
              </div>
              <div class="ml-3">
                <div class="text-base font-medium text-gray-800 dark:text-gray-200">
                  {@current_user_name}
                </div>
              </div>
            </div>

            <div class="flex items-center gap-3">
              <%= if @top_right do %>
                {render_slot(@top_right)}
              <% end %>
            </div>
          </div>

          <div class="mt-3 space-y-1">
            <%= for menu_item <- @user_menu_items do %>
              <.a
                link_type={if menu_item[:method], do: "a", else: "live_redirect"}
                to={menu_item.path}
                method={if menu_item[:method], do: menu_item[:method], else: nil}
                label={menu_item.label}
                class={mobile_menu_item_class(@current_page, menu_item.name)}
              />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp main_menu_item_base_class,
    do:
      "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium leading-5 transition duration-150 ease-in-out"

  defp main_menu_item_class(page, page),
    do: main_menu_item_base_class() <> " border-primary-500 text-gray-900
      dark:text-gray-100 dark:focus:border-primary-300"

  defp main_menu_item_class(_, _),
    do:
      main_menu_item_base_class() <>
        " border-transparent text-gray-500
      hover:text-gray-700 hover:border-gray-300
      dark:focus:border-gray-700 dark:hover:text-gray-300 dark:focus:text-gray-300 dark:hover:border-gray-700 dark:text-gray-400"

  defp mobile_menu_item_class(page, page),
    do:
      "block py-2 pl-3 pr-4 text-base font-medium text-primary-700 border-l-4 border-primary-500 bg-primary-50 dark:text-primary-300 dark:bg-primary-700"

  defp mobile_menu_item_class(_, _),
    do:
      "block py-2 pl-3 pr-4 text-base font-medium text-gray-500 border-l-4 border-transparent hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:bg-gray-800 dark:hover:bg-gray-700 dark:hover:border-gray-700 dark:hover:text-gray-300"
end
