defmodule MossletWeb.StackedLayout do
  @moduledoc """
  A responsive layout with a top navbar, as well as a drop down menu up the top right (user menu).

  The menu items use the same structure as what is used in `MossletWeb.SidebarMenu.nav_menu/1` - please read the docs for that function to get a sense of the data structure for menu items.

  The user menu is rendered using `MossletWeb.UserDropdownMenu.user_dropdown_menu/1`.
  """
  use Phoenix.Component, global_prefixes: ~w(x-)
  use PetalComponents

  import MossletWeb.UserDropdownMenu

  attr :current_page, :atom,
    required: true,
    doc: "The current page. This will be used to highlight the current page in the menu."

  attr :main_menu_items, :list,
    default: [],
    doc: "The items that will be displayed in the header."

  attr :user_menu_items, :list,
    default: [],
    doc: "The items that will be displayed in the user dropdown menu up top right."

  attr :avatar_src, :string,
    default: nil,
    doc:
      "The src of the avatar image. If this is not present, the user's initials will be displayed."

  attr :home_path, :string,
    default: "/",
    doc:
      "The path to the home page. When a user clicks the logo, they will be taken to this path."

  attr :current_user_name, :string,
    default: nil,
    doc: "The name of the current user. This will be displayed in the user menu."

  attr :container_max_width, :string,
    default: "lg",
    values: ["sm", "md", "lg", "xl", "full"],
    doc:
      "The max width of the container in the header. This should match your main content container."

  attr :hide_active_menu_item_border, :boolean,
    default: false,
    doc: "Whether or not to hide the border on the active menu item."

  attr :main_bg_class, :string,
    default: "bg-white dark:bg-gray-900",
    doc: "The background class for the main content area."

  attr :header_bg_class, :string,
    default: "bg-white dark:bg-gray-900",
    doc: "The background class for the header."

  attr :header_border_class, :string,
    default: "border-gray-200 dark:border-gray-700",
    doc: "The border class for the header."

  attr :sticky, :boolean,
    default: false,
    doc: "Whether or not the header should be sticky."

  slot :inner_block,
    doc: "The inner block of the layout. This is where you should put your content."

  slot :top_right,
    doc:
      "The top right of the header. This could be used for a color scheme switcher, for example."

  slot :top_right_mobile,
    doc:
      "The top right of the header visible on mobile. Used to avoid duplicate ID errors when rendering live components in the slot"

  slot :logo,
    required: true,
    doc:
      "A slot to render your logo in. This will be wrapped in a link to the home_path attribute."

  def stacked_layout(assigns) do
    ~H"""
    <div class={["h-screen overflow-y-auto", @main_bg_class]}>
      <div
        class={[
          "border-b",
          @header_bg_class,
          @header_border_class,
          @sticky && "top-0 z-50"
        ]}
        x-data="{mobileMenuOpen: false}"
      >
        <.container max_width={@container_max_width}>
          <div class="flex justify-between h-16 relative">
            <%!-- mobile menu --%>
            <div
              class={[
                "lg:hidden absolute w-screen top-[65px] -left-4",
                "bg-white dark:bg-gray-800 shadow-lg"
              ]}
              @click.away="mobileMenuOpen = false"
              x-cloak
              x-show="mobileMenuOpen"
              x-transition:enter="transition transform ease-out duration-100"
              x-transition:enter-start="transform opacity-0 scale-95"
              x-transition:enter-end="transform opacity-100 scale-100"
              x-transition:leave="transition ease-in duration-75"
              x-transition:leave-start="transform opacity-100 scale-100"
              x-transition:leave-end="transform opacity-0 scale-95"
            >
              <%= if menu_items_grouped?(@main_menu_items) do %>
                <div class="divide-y divide-gray-100 dark:divide-gray-700">
                  <%= for menu_group <- @main_menu_items do %>
                    <div class="pt-3 pb-3 first:pt-0">
                      <%= for menu_item <- menu_group.menu_items do %>
                        <.link
                          :if={menu_item[:path]}
                          navigate={menu_item.path}
                          class={mobile_menu_item_class(@current_page, menu_item[:name])}
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
                      :if={menu_item[:path]}
                      navigate={menu_item.path}
                      class={mobile_menu_item_class(@current_page, menu_item[:name])}
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
                        <MossletWeb.CoreComponents.phx_avatar
                          name={@current_user_name}
                          src={@avatar_src}
                          size="h-6 w-6"
                        />
                      <% else %>
                        <MossletWeb.CoreComponents.phx_avatar size="h-6 w-6" />
                      <% end %>
                    </div>
                    <div class="ml-3">
                      <div class="text-base font-medium text-gray-800 dark:text-gray-200">
                        {@current_user_name}
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center gap-3">
                    <%!-- Prefer @top_right_mobile to avoid duplicate live component IDs on the page (notification bell) --%>
                    <%= if @top_right_mobile do %>
                      {render_slot(@top_right_mobile)}
                    <% end %>
                    <%= if !@top_right_mobile && @top_right do %>
                      {render_slot(@top_right)}
                    <% end %>
                  </div>
                </div>

                <div class="mt-3 space-y-1">
                  <.a
                    :for={menu_item <- @user_menu_items}
                    link_type={if menu_item[:method], do: "a", else: "live_redirect"}
                    to={menu_item.path}
                    method={if menu_item[:method], do: menu_item[:method], else: nil}
                    label={menu_item.label}
                    class={mobile_menu_item_class(@current_page, menu_item[:name])}
                  />
                </div>
              </div>
            </div>

            <%!-- standard menu --%>
            <div class="flex">
              <.link navigate={@home_path} class="flex items-center justify-center">
                {render_slot(@logo)}
              </.link>
              <!-- For grouped menu items -->
              <%= if menu_items_grouped?(@main_menu_items) do %>
                <div class="hidden divide-x divide-gray-100 lg:flex dark:divide-gray-700">
                  <div :for={menu_group <- @main_menu_items} class="px-8 lg:flex lg:space-x-8">
                    <.main_menu_item
                      :for={menu_item <- menu_group.menu_items}
                      menu_item={menu_item}
                      current_page={@current_page}
                      hide_active_menu_item_border={@hide_active_menu_item_border}
                    />
                  </div>
                </div>
              <% else %>
                <div class="hidden lg:ml-6 lg:flex lg:space-x-8">
                  <.main_menu_item
                    :for={menu_item <- @main_menu_items}
                    menu_item={menu_item}
                    current_page={@current_page}
                    hide_active_menu_item_border={@hide_active_menu_item_border}
                  />
                </div>
              <% end %>
            </div>

            <div class="hidden gap-3 lg:ml-6 lg:flex lg:items-center">
              {render_slot(@top_right)}

              <%= if @user_menu_items != [] do %>
                <.user_menu_dropdown
                  user_menu_items={@user_menu_items}
                  avatar_src={@avatar_src}
                  current_user_name={@current_user_name}
                />
              <% end %>
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
                  x-cloak
                >
                  <.icon name="hero-bars-3" class="w-6 h-6" />
                </div>

                <div
                  class="w-6 h-6"
                  x-bind:class="{ 'block': mobileMenuOpen, 'hidden': !(mobileMenuOpen) }"
                  x-cloak
                >
                  <.icon name="hero-x-mark" class="w-6 h-6" />
                </div>
              </button>
            </div>
          </div>
        </.container>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp menu_items_grouped?(menu_items) do
    Enum.all?(menu_items, fn menu_item ->
      Map.has_key?(menu_item, :title)
    end)
  end

  attr :current_page, :string, required: true
  attr :menu_item, :map, required: true
  attr :hide_active_menu_item_border, :boolean, default: false

  def main_menu_item(assigns) do
    assigns =
      assign(assigns, :active?, nav_menu_item_active?(assigns.menu_item, assigns.current_page))

    ~H"""
    <.a
      :if={!@menu_item[:menu_items]}
      to={@menu_item[:path]}
      label={@menu_item.label}
      class={main_menu_item_class(@active?, @hide_active_menu_item_border)}
    />

    <div
      :if={@menu_item[:menu_items]}
      class={main_menu_item_class(@active?, @hide_active_menu_item_border) <> " relative"}
    >
      <.dropdown placement="right">
        <:trigger_element>
          <div class="inline-flex items-center justify-center w-full focus:outline-none">
            {@menu_item.label}
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 ml-1 -mr-1 text-gray-400 dark:text-gray-100"
            />
          </div>
        </:trigger_element>

        <.dropdown_menu_item
          :for={submenu_item <- @menu_item.menu_items}
          :if={submenu_item[:path]}
          label={submenu_item.label}
          to={submenu_item.path}
          link_type="live_redirect"
          class={dropdown_item_class(nav_menu_item_active?(submenu_item, @current_page))}
        />
      </.dropdown>
    </div>
    """
  end

  defp nav_menu_item_active?(menu_item, current_page) do
    menu_item[:name] == current_page ||
      Enum.any?(menu_item[:menu_items] || [], fn menu_item ->
        nav_menu_item_active?(menu_item, current_page)
      end)
  end

  defp dropdown_item_class(true), do: "bg-gray-100 dark:bg-gray-700"
  defp dropdown_item_class(false), do: ""

  defp main_menu_item_base_class(hide_active_menu_item_border),
    do:
      "#{if hide_active_menu_item_border, do: "", else: "border-b-2"} inline-flex items-center px-1 pt-1 text-sm font-medium leading-5 transition duration-150 ease-in-out"

  defp main_menu_item_class(true, hide_active_menu_item_border),
    do:
      main_menu_item_base_class(hide_active_menu_item_border) <>
        " border-primary-500 text-gray-900
        dark:text-gray-100 dark:focus:border-primary-300"

  defp main_menu_item_class(false, hide_active_menu_item_border),
    do:
      main_menu_item_base_class(hide_active_menu_item_border) <>
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
