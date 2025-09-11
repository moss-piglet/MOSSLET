defmodule MossletWeb.SidebarLayout do
  @moduledoc """
  A responsive layout with a left sidebar (main menu), as well as a drop down menu up the top right (user menu).

  Uses MossletWeb.SidebarMenu.sidebar_menu/1 to render the main menu (see docs for menu items data structure). The user menu is rendered using MossletWeb.UserDropdownMenu.user_dropdown_menu/1.

  Note that in order to utilise the collapsible sidebar feature, you must install the Alpine Persist plugin. See https://alpinejs.dev/plugins/persist for more information.
  """
  use MossletWeb, :verified_routes
  use Phoenix.Component, global_prefixes: ~w(x-)
  use PetalComponents

  import MossletWeb.SidebarMenu
  import MossletWeb.UserDropdownMenu

  alias Mosslet.Repo

  attr :collapsible, :boolean,
    default: false,
    doc:
      "The sidebar can be collapsed to display icon-only menu items. False by default. Requires the Alpine Persist plugin."

  attr :collapsed_only, :boolean,
    default: false,
    doc:
      "The sidebar is always collapsed and cannot be toggled otherwise. This makes the `:collapsible` and `:default_collapsed` options unnecessary."

  attr :default_collapsed, :boolean,
    default: false,
    doc:
      "The sidebar will render as collapsed by default, if it is not already set in localStorage. False by default. Requires `:collapsible` to be true."

  attr :current_page, :atom,
    required: true,
    doc: "The current page. This will be used to highlight the current page in the menu."

  attr :main_menu_items, :list,
    default: [],
    doc: "The items that will be displayed in the main menu in the sidebar."

  attr :user_menu_items, :list,
    default: [],
    doc: "The items that will be displayed in the user menu."

  attr :avatar_src, :string,
    default: nil,
    doc:
      "The src of the avatar image. If this is not present, the user's initials will be displayed."

  attr :current_user_name, :string,
    default: nil,
    doc: "The name of the current user. This will be displayed in the user menu."

  attr :sidebar_title, :string,
    default: nil,
    doc: "This will be displayed at the top of the sidebar."

  attr :home_path, :string,
    default: "/",
    doc:
      "The path to the home page. When a user clicks the logo, they will be taken to this path."

  attr :sidebar_width_class, :string,
    default: "w-64",
    doc: "The width of the sidebar when open on breakpoints below :lg."

  attr :sidebar_lg_width_class, :string,
    default: "lg:w-64",
    doc: "The width of the sidebar. Must have the lg: prefix."

  attr :sidebar_bg_class, :string, default: "bg-white dark:bg-gray-800"
  attr :sidebar_border_class, :string, default: "border-background-100 dark:border-gray-700"
  attr :header_bg_class, :string, default: "bg-background-50 dark:bg-gray-950"
  attr :header_border_class, :string, default: "border-background-100 dark:border-gray-700"
  slot :inner_block, required: true, doc: "The main content of the page."

  slot :adjacent,
    doc: "Render anything you like adjacent to the main sidebar div - like a flyout menu."

  slot :top_left,
    doc:
      "The top left bit of the header. You can use this to add things like a search bar or more menu items. Will disappear on mobile."

  slot :top_right,
    doc:
      "The top right bit of the header. You can use this to add things like a notification badge."

  slot :logo,
    doc: "Your logo. This will automatically sit within a link to the home_path attribute."

  slot :logo_icon,
    doc:
      "Your logo icon for display when the sidebar is collapsed. This will automatically sit within a link to the home_path attribute."

  slot :sidebar,
    doc:
      "Optionally add whatever you like to the sidebar. If main_menu_items is present, this will sit under that. Or you can leave main_menu_items as empty and create your own menu."

  def sidebar_layout(assigns) do
    ~H"""
    <div
      class="flex h-screen overflow-hidden dark:bg-gray-950"
      x-data={"{sidebarOpen: false, collapsedOnly: #{@collapsed_only}, isCollapsible: #{@collapsed_only || @collapsible}, #{x_persist_collapsed(assigns)}}"}
    >
      <div
        class={["transition-transform relative z-40"]}
        x-bind:class={"isCollapsed ? 'w-min lg:w-min' : '#{@sidebar_lg_width_class}'"}
      >
        <%= if render_slot(@adjacent) do %>
          {render_slot(@adjacent)}
        <% end %>

        <div
          x-show="sidebarOpen"
          x-transition:enter="transition-opacity ease-linear duration-300"
          x-transition:enter-start="opacity-0"
          x-transition:enter-end="opacity-100"
          x-transition:leave="transition-opacity ease-linear duration-300"
          x-transition:leave-start="opacity-100"
          x-transition:leave-end="opacity-0"
          class="fixed inset-0 bg-background-50/80 dark:bg-gray-950/80"
        >
        </div>

        <%!-- Collapse sidebar icon button, don't render for collapsed_only --%>
        <button
          :if={!@collapsed_only && @collapsible}
          class="absolute transition-colors -right-[12px] z-40 top-[51px] bg-white hover:bg-gray-50 dark:hover:bg-gray-900 dark:bg-gray-800 text-gray-700 hover:text-gray-900 dark:hover:text-gray-50 dark:text-gray-100 lg:flex hidden border border-gray-200 dark:border-gray-700 rounded-md w-[25px] h-[25px] justify-center items-center"
          x-bind:class="isCollapsed ? 'mb-1 mx-auto' : 'mb-0 ml-0.5'"
          @click="isCollapsed = !isCollapsed"
          x-cloak
        >
          <span class="sr-only">
            Collapse sidebar
          </span>
          <div class="flex flex-row -space-x-[4px] m-1">
            <.icon solid name={:chevron_left} class="w-3 h-3 fill-current" />
            <.icon solid name={:chevron_right} class="w-3 h-3 fill-current" />
          </div>
        </button>

        <div
          id="sidebar"
          class={[
            "absolute top-0 left-0 z-40 flex-shrink-0 h-screen p-4 overflow-y-auto transition-transform duration-200 ease-in-out transform border-r lg:static lg:left-auto lg:top-auto lg:translate-x-0 lg:overflow-y-auto no-scrollbar",
            @sidebar_bg_class,
            @sidebar_border_class
          ]}
          x-bind:class={"
          {
            '#{@sidebar_width_class}': sidebarOpen && !isCollapsed,
            '-translate-x-full': !sidebarOpen,
            'translate-x-0': sidebarOpen,
            'w-min': isCollapsed,
          }
          "}
          @click.away="sidebarOpen = false"
          @keydown.escape.window="sidebarOpen = false"
          x-cloak
        >
          <div
            x-bind:class="isCollapsible && isCollapsed ? 'flex-col-reverse lg:flex-row px-0' : 'pr-3 sm:px-2'"
            class="flex justify-between mb-8"
          >
            <%!-- Close sidebar on mobile --%>
            <button
              x-bind:class="isCollapsible && isCollapsed ? 'mx-auto' : ''"
              class="text-background-500 lg:hidden hover:text-background-400 dark:text-gray-400 dark:hover:text-gray-300"
              @click.stop="sidebarOpen = !sidebarOpen"
              aria-controls="sidebar"
              x-bind:aria-expanded="sidebarOpen"
            >
              <span class="sr-only">
                Close sidebar
              </span>
              <svg class="w-6 h-6 fill-current" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path d="M10.7 18.7l1.4-1.4L7.8 13H20v-2H7.8l4.3-4.3-1.4-1.4L4 12z" />
              </svg>
            </button>

            <.link x-show="!isCollapsed" navigate={@home_path} class="block">
              {render_slot(@logo)}
            </.link>

            <.link
              x-show="isCollapsed"
              x-bind:class="isCollapsible && isCollapsed ? 'mb-4 lg:mb-0' : ''"
              navigate={@home_path}
              class="block mx-auto"
            >
              {render_slot(@logo_icon)}
            </.link>
          </div>

          <div>
            <.sidebar_menu
              :if={@main_menu_items != []}
              menu_items={@main_menu_items}
              current_page={@current_page}
              title={@sidebar_title}
            />

            <%= if render_slot(@sidebar) do %>
              {render_slot(@sidebar)}
            <% end %>
          </div>
        </div>
      </div>

      <div class="relative flex flex-col flex-1 pb-32 overflow-x-hidden overflow-y-auto lg:pb-0 lg:overflow-x-auto">
        <header class={[
          "sticky top-0 z-30 border-b dark:lg:shadow-none dark:border-b lg:backdrop-filter backdrop-blur",
          @header_bg_class,
          @header_border_class
        ]}>
          <div class="px-4 sm:px-6 lg:px-8">
            <div class="flex items-center justify-between h-16 -mb-px">
              <div class="flex min-w-[68px]">
                <button
                  class="text-background-500 hover:text-background-600 dark:text-gray-400 dark:hover:text-gray-300 lg:hidden"
                  @click.stop="sidebarOpen = !sidebarOpen"
                  aria-controls="sidebar"
                  x-bind:aria-expanded="sidebarOpen"
                >
                  <span class="sr-only">
                    Open sidebar
                  </span>
                  <svg
                    class="w-6 h-6 fill-current"
                    viewBox="0 0 24 24"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <rect x="4" y="5" width="16" height="2" />
                    <rect x="4" y="11" width="16" height="2" />
                    <rect x="4" y="17" width="16" height="2" />
                  </svg>
                </button>

                <%= if render_slot(@top_left) do %>
                  <div class="hidden lg:block">
                    {render_slot(@top_left)}
                  </div>
                <% end %>
              </div>

              <div class="flex items-center gap-3">
                {render_slot(@top_right)}

                <.user_menu_dropdown
                  :if={@user_menu_items != []}
                  user_menu_items={@user_menu_items}
                  avatar_src={MossletWeb.Helpers.maybe_get_user_avatar(@current_user, @key)}
                  current_user_name={@current_user_name}
                />
              </div>
            </div>
          </div>
          <.beta_banner
            :if={@current_user}
            current_user={Repo.preload(@current_user, customer: :subscriptions)}
          />
        </header>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # We load Alpine state dynamically in this way because we need to persist the sidebar isCollapsed state
  # across page reloads when it's togglable. This requires the Alpine Persist plugin, and throws a JS error
  # if the plugin is missing, so this reduces that impact as much as possible.

  defp x_persist_collapsed(%{collapsed_only: true}), do: "isCollapsed: true"

  defp x_persist_collapsed(%{collapsible: true, default_collapsed: default_collapsed}),
    do: "isCollapsed: $persist(#{default_collapsed})"

  defp x_persist_collapsed(_), do: "isCollapsed: false"

  defp beta_banner(assigns) do
    ~H"""
    <div
      :if={!@current_user.customer}
      class="relative isolate flex z-10 items-center gap-x-6 overflow-hidden bg-gray-50 px-6 py-2.5 sm:px-3.5 sm:before:flex-1"
    >
      <div
        class="absolute left-[max(-7rem,calc(50%-52rem))] top-1/2 -z-10 -translate-y-1/2 transform-gpu blur-2xl"
        aria-hidden="true"
      >
        <div
          class="aspect-[577/310] w-[36.0625rem] bg-gradient-to-r from-[#22d3ee] to-[#34d399] opacity-30"
          style="clip-path: polygon(74.8% 41.9%, 97.2% 73.2%, 100% 34.9%, 92.5% 0.4%, 87.5% 0%, 75% 28.6%, 58.5% 54.6%, 50.1% 56.8%, 46.9% 44%, 48.3% 17.4%, 24.7% 53.9%, 0% 27.9%, 11.9% 74.2%, 24.9% 54.1%, 68.6% 100%, 74.8% 41.9%)"
        >
        </div>
      </div>
      <div
        class="absolute left-[max(45rem,calc(50%+8rem))] top-1/2 -z-10 -translate-y-1/2 transform-gpu blur-2xl"
        aria-hidden="true"
      >
        <div
          class="aspect-[577/310] w-[36.0625rem] bg-gradient-to-r from-[#22d3ee] to-[#34d399] opacity-30"
          style="clip-path: polygon(74.8% 41.9%, 97.2% 73.2%, 100% 34.9%, 92.5% 0.4%, 87.5% 0%, 75% 28.6%, 58.5% 54.6%, 50.1% 56.8%, 46.9% 44%, 48.3% 17.4%, 24.7% 53.9%, 0% 27.9%, 11.9% 74.2%, 24.9% 54.1%, 68.6% 100%, 74.8% 41.9%)"
        >
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-x-4 gap-y-2">
        <p class="text-sm/6 text-gray-900">
          <strong class="font-semibold">Special Price</strong><svg
            viewBox="0 0 2 2"
            class="mx-2 inline size-0.5 fill-current"
            aria-hidden="true"
          ><circle cx="1" cy="1" r="1" /></svg>Join us for 40% off while we're in beta and have privacy now for life.
        </p>
        <.link
          navigate={~p"/app/subscribe"}
          class="flex-none rounded-full bg-emerald-600 px-3.5 py-1 text-sm font-semibold text-white dark:text-white hover:text-white shadow-sm hover:bg-emerald-700 active:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
        >
          Pay once <span aria-hidden="true">&rarr;</span>
        </.link>
      </div>
      <div class="flex flex-1 justify-end"></div>
    </div>
    """
  end
end
