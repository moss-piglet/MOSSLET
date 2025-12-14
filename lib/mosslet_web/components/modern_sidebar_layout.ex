defmodule MossletWeb.ModernSidebarLayout do
  @moduledoc """
  A modern, calm sidebar layout component with improved visual hierarchy.
  Designed to be responsive, accessible, and visually appealing on both mobile and desktop.
  """
  use MossletWeb, :verified_routes
  use Phoenix.Component, global_prefixes: ~w(x-)

  import MossletWeb.ModernSidebarMenu
  import MossletWeb.Helpers

  alias Phoenix.LiveView.JS, as: JS

  attr :current_page, :atom, required: true
  attr :sidebar_current_page, :atom, default: nil
  attr :current_user, :map, required: true
  attr :key, :string, required: true
  attr :main_menu_items, :list, default: []
  attr :user_menu_items, :list, default: []
  attr :sidebar_title, :string, default: nil
  attr :home_path, :string, default: "/"

  slot :inner_block, required: true
  slot :logo
  slot :logo_icon
  slot :top_right

  def modern_sidebar_layout(assigns) do
    assigns = assign_new(assigns, :sidebar_current_page, fn -> assigns.current_page end)

    ~H"""
    <div
      class="min-h-screen bg-slate-50/50 dark:bg-slate-900"
      x-data="{ sidebarOpen: false, sidebarCollapsed: localStorage.getItem('sidebarCollapsed') === 'true', scrollPos: 0 }"
      x-init="$watch('sidebarCollapsed', val => localStorage.setItem('sidebarCollapsed', val))"
      x-effect="if (sidebarOpen) { scrollPos = window.scrollY; document.body.style.overflow = 'hidden'; } else { document.body.style.overflow = ''; window.scrollTo(0, scrollPos); }"
      @keydown.escape.window="sidebarOpen = false"
    >
      <%!-- Mobile sidebar backdrop --%>
      <div
        class="fixed inset-0 z-[55] xl:hidden"
        x-show="sidebarOpen"
        x-transition:enter="transition-opacity ease-linear duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition-opacity ease-linear duration-200"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0"
        @click="sidebarOpen = false"
        x-cloak
      >
        <div class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"></div>
      </div>

      <%!-- Desktop sidebar --%>
      <aside
        class="hidden xl:fixed xl:inset-y-0 xl:z-30 xl:flex xl:flex-col xl:h-screen transition-all duration-300 ease-out"
        x-bind:class="sidebarCollapsed ? 'xl:w-20' : 'xl:w-72'"
      >
        <div
          class={[
            "flex flex-col h-full max-h-screen transition-[padding] duration-300 ease-out",
            "bg-gradient-to-b from-white via-slate-50/50 to-slate-100/30",
            "dark:from-slate-800 dark:via-slate-800/80 dark:to-slate-900/60",
            "border-r border-slate-200/60 dark:border-slate-700/60",
            "backdrop-blur-sm"
          ]}
          x-bind:class="sidebarCollapsed ? 'px-3' : 'px-6'"
        >
          <%!-- Logo --%>
          <div
            class="flex h-16 shrink-0 items-center"
            x-bind:class="sidebarCollapsed ? 'justify-center' : 'lg:px-4'"
          >
            <.link
              navigate={@home_path}
              class="group block transition-transform duration-300 ease-out hover:scale-105"
              x-show="!sidebarCollapsed"
              x-transition:enter="transition ease-out duration-200"
              x-transition:enter-start="opacity-0 scale-90"
              x-transition:enter-end="opacity-100 scale-100"
              x-transition:leave="transition ease-in duration-150"
              x-transition:leave-start="opacity-100 scale-100"
              x-transition:leave-end="opacity-0 scale-90"
            >
              <div class="relative">
                {render_slot(@logo)}
                <div class="absolute inset-0 rounded-lg bg-gradient-to-br from-emerald-500/0 to-cyan-500/0 group-hover:from-emerald-500/5 group-hover:to-cyan-500/5 transition-all duration-300">
                </div>
              </div>
            </.link>
            <.link
              navigate={@home_path}
              aria-label="Home"
              class="group block transition-transform duration-300 ease-out hover:scale-105"
              x-show="sidebarCollapsed"
              x-cloak
              x-transition:enter="transition ease-out duration-200"
              x-transition:enter-start="opacity-0 scale-90"
              x-transition:enter-end="opacity-100 scale-100"
              x-transition:leave="transition ease-in duration-150"
              x-transition:leave-start="opacity-100 scale-100"
              x-transition:leave-end="opacity-0 scale-90"
            >
              <div class="relative">
                {render_slot(@logo_icon)}
                <div class="absolute inset-0 rounded-lg bg-gradient-to-br from-emerald-500/0 to-cyan-500/0 group-hover:from-emerald-500/5 group-hover:to-cyan-500/5 transition-all duration-300">
                </div>
              </div>
            </.link>
          </div>

          <%!-- Navigation --%>
          <nav aria-label="Main navigation" class="flex-1 overflow-y-auto min-h-0 space-y-2">
            <.modern_sidebar_menu
              menu_items={@main_menu_items}
              current_page={@sidebar_current_page}
              title={@sidebar_title}
              collapsed={false}
            />
          </nav>

          <%!-- Collapse toggle button --%>
          <div class="shrink-0 pt-4 pb-4 border-t border-slate-200/40 dark:border-slate-700/40">
            <button
              @click="sidebarCollapsed = !sidebarCollapsed"
              class={[
                "group relative flex items-center justify-center w-full rounded-lg py-2.5 overflow-hidden",
                "transition-all duration-300 ease-out",
                "text-slate-500 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "hover:bg-gradient-to-r hover:from-teal-50/60 hover:via-emerald-50/80 hover:to-cyan-50/60",
                "dark:hover:from-teal-900/15 dark:hover:via-emerald-900/20 dark:hover:to-cyan-900/15",
                "hover:shadow-sm hover:shadow-emerald-500/10"
              ]}
            >
              <span class="sr-only">Toggle sidebar</span>
              <div class={[
                "absolute inset-0 opacity-0 transition-all duration-300 ease-out",
                "bg-gradient-to-r from-teal-50/40 via-emerald-50/60 to-cyan-50/40",
                "dark:from-teal-900/10 dark:via-emerald-900/15 dark:to-cyan-900/10",
                "group-hover:opacity-100"
              ]}>
              </div>
              <div
                class="relative flex items-center gap-x-2 transition-transform duration-300"
                x-bind:class="sidebarCollapsed ? 'rotate-180' : ''"
              >
                <MossletWeb.CoreComponents.phx_icon
                  name="hero-chevron-double-left"
                  class="w-5 h-5 transition-all duration-300 group-hover:scale-110"
                />
                <span
                  class="text-sm font-medium whitespace-nowrap"
                  x-show="!sidebarCollapsed"
                  x-transition:enter="transition ease-out duration-200"
                  x-transition:enter-start="opacity-0"
                  x-transition:enter-end="opacity-100"
                  x-transition:leave="transition ease-in duration-100"
                  x-transition:leave-start="opacity-100"
                  x-transition:leave-end="opacity-0"
                >
                  Collapse
                </span>
              </div>
            </button>
          </div>
        </div>
      </aside>

      <%!-- Mobile sidebar --%>
      <aside class="relative z-[60] xl:hidden" aria-label="Mobile sidebar">
        <div
          class={[
            "fixed z-[60] w-72 flex flex-col px-0 pb-4",
            "bg-gradient-to-b from-white via-slate-50/50 to-slate-100/30",
            "dark:from-slate-800 dark:via-slate-800/80 dark:to-slate-900/60",
            "border-r border-slate-200/60 dark:border-slate-700/60",
            "backdrop-blur-sm transition-transform duration-300 ease-out"
          ]}
          x-data="{ sidebarCollapsed: false }"
          x-show="sidebarOpen"
          x-transition:enter="transform transition ease-out duration-300"
          x-transition:enter-start="-translate-x-full opacity-90"
          x-transition:enter-end="translate-x-0 opacity-100"
          x-transition:leave="transform transition ease-in duration-250"
          x-transition:leave-start="translate-x-0 opacity-100"
          x-transition:leave-end="-translate-x-full opacity-90"
          x-cloak
          style="position: fixed !important; top: 0 !important; bottom: 0 !important; left: 0 !important; width: 18rem !important; height: 100vh !important;"
        >
          <div class="flex h-16 shrink-0 items-center justify-between px-6 border-b border-slate-200/30 dark:border-slate-700/30">
            <.link navigate={@home_path} class="block">
              {render_slot(@logo)}
            </.link>
            <button
              @click="sidebarOpen = false"
              class={[
                "group p-2 rounded-lg transition-all duration-200 ease-out",
                "text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200",
                "hover:bg-gradient-to-br hover:from-slate-100 hover:to-slate-50",
                "dark:hover:from-slate-700 dark:hover:to-slate-600",
                "hover:scale-105 active:scale-95"
              ]}
            >
              <span class="sr-only">Close sidebar</span>
              <MossletWeb.CoreComponents.phx_icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <nav
            aria-label="Mobile navigation"
            class="flex-1 overflow-y-auto px-2 py-4 scrollbar-thin scrollbar-thumb-slate-300 dark:scrollbar-thumb-slate-600 scrollbar-track-transparent"
          >
            <.modern_sidebar_menu
              menu_items={@main_menu_items}
              current_page={@sidebar_current_page}
              title={@sidebar_title}
            />
          </nav>
        </div>
      </aside>

      <%!-- Main content --%>
      <div
        class="transition-all duration-300 ease-out"
        x-bind:class="sidebarCollapsed ? 'xl:pl-20' : 'xl:pl-72'"
      >
        <%!-- Top bar --%>
        <header class={[
          "sticky top-0 z-50 flex h-16 shrink-0 items-center gap-x-4 px-4 sm:gap-x-6 sm:px-6 lg:px-8",
          "border-b border-slate-200/60 dark:border-slate-700/60",
          "bg-gradient-to-r from-white/90 via-slate-50/80 to-white/90",
          "dark:from-slate-800/90 dark:via-slate-800/80 dark:to-slate-800/90",
          "backdrop-blur-md shadow-md shadow-slate-900/5 dark:shadow-lg dark:shadow-black/40"
        ]}>
          <%!-- Mobile menu button --%>
          <button
            @click="sidebarOpen = !sidebarOpen"
            class={[
              "group p-2.5 xl:hidden rounded-lg transition-all duration-200 ease-out",
              "text-slate-700 dark:text-slate-200",
              "hover:bg-gradient-to-br hover:from-slate-100 hover:to-slate-50",
              "dark:hover:from-slate-700 dark:hover:to-slate-600",
              "hover:scale-105 active:scale-95 hover:shadow-md"
            ]}
          >
            <span class="sr-only">Open sidebar</span>
            <MossletWeb.CoreComponents.phx_icon name="hero-bars-3" class="w-5 h-5" />
          </button>

          <%!-- Separator --%>
          <div class="h-6 w-px bg-slate-200 dark:bg-slate-700 xl:hidden" aria-hidden="true"></div>

          <%!-- Right side content --%>
          <div class="flex flex-1 gap-x-4 self-stretch lg:gap-x-6 justify-end">
            <div class="flex items-center gap-x-4 lg:gap-x-6">
              {render_slot(@top_right)}

              <%!-- User menu --%>

              <.modern_user_menu
                :if={@user_menu_items != []}
                id={"modern-user-menu-#{@current_user.id}"}
                user_menu_items={@user_menu_items}
                current_user={@current_user}
                key={@key}
              />
            </div>
          </div>
        </header>

        <%!-- Page content --%>
        <main>
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  # Modern user menu dropdown with liquid metal styling
  defp modern_user_menu(assigns) do
    ~H"""
    <div
      class="relative"
      x-data="{ open: false }"
      @click.away="open = false"
      @keydown.escape.window="open = false"
      id="user-menu-dropdown"
    >
      <button
        @click="open = !open"
        class={[
          "group relative flex items-center gap-x-2 rounded-full p-1.5 overflow-hidden",
          "bg-gradient-to-br from-slate-50 via-white to-slate-100",
          "dark:from-slate-800 dark:via-slate-700 dark:to-slate-800",
          "ring-1 ring-slate-200/60 dark:ring-slate-600/40",
          "hover:ring-teal-300/60 dark:hover:ring-emerald-500/40",
          "hover:shadow-lg hover:shadow-emerald-500/20 dark:hover:shadow-emerald-400/10",
          "transition-all duration-300 ease-out hover:scale-105 active:scale-95",
          "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2"
        ]}
      >
        <span class="sr-only">Open user menu</span>

        <%!-- Enhanced liquid background effect --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/40 via-emerald-50/60 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15 group-hover:opacity-100 rounded-xl">
        </div>
        <%!-- Shimmer effect on hover (with proper clipping for rounded button) --%>
        <div class={[
          "absolute inset-0 opacity-0 transition-all duration-500 overflow-hidden rounded-full",
          "bg-gradient-to-r from-transparent via-white/30 to-transparent",
          "dark:via-gray-800/20",
          "group-hover:opacity-100 group-hover:translate-x-full transform -translate-x-full"
        ]}>
        </div>
        <MossletWeb.CoreComponents.phx_avatar
          src={maybe_get_user_avatar(@current_user, @key)}
          class="h-8 w-8 rounded-full transition-all duration-300 ring-2 ring-transparent group-hover:ring-emerald-300 dark:group-hover:ring-emerald-400 group-hover:shadow-md group-hover:shadow-emerald-500/30"
          alt="User avatar"
        />
      </button>

      <div
        x-show="open"
        x-transition:enter="transition ease-out duration-300 transform-gpu"
        x-transition:enter-start="opacity-0 -translate-y-1"
        x-transition:enter-end="opacity-100 translate-y-0"
        x-transition:leave="transition ease-in duration-200 transform-gpu"
        x-transition:leave-start="opacity-100 translate-y-0"
        x-transition:leave-end="opacity-0 -translate-y-1"
        class={[
          "absolute right-0 z-[60] mt-3 w-48 origin-top-right overflow-hidden",
          "rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
          "py-2 shadow-xl shadow-slate-900/15 dark:shadow-slate-900/30",
          "ring-1 ring-slate-200/60 dark:ring-slate-700/60",
          "border border-slate-100/60 dark:border-slate-600/40"
        ]}
        x-cloak
      >
        <.link
          :for={item <- @user_menu_items}
          {if item[:method], do: %{method: item[:method], href: item[:path]}, else: %{navigate: item[:path]}}
          class={[
            "group relative flex items-center px-4 py-2.5 text-sm font-medium overflow-hidden",
            "text-slate-700 dark:text-slate-200",
            "hover:bg-gradient-to-r hover:from-teal-50 hover:via-emerald-50 hover:to-cyan-50",
            "dark:hover:from-teal-900/30 dark:hover:via-emerald-900/20 dark:hover:to-cyan-900/30",
            "hover:text-emerald-700 dark:hover:text-emerald-300",
            "transition-all duration-200 ease-out transform-gpu",
            "hover:scale-105 active:scale-95",
            "first:rounded-t-lg last:rounded-b-lg"
          ]}
          phx-click={JS.toggle_attribute({"data-show", "false", "true"}, to: "#user-menu")}
        >
          <%!-- Menu item shimmer --%>
          <div class={[
            "absolute inset-0 opacity-0 transition-all duration-500",
            "bg-gradient-to-r from-transparent via-emerald-100/50 to-transparent",
            "dark:via-emerald-400/20",
            "group-hover:opacity-100 group-hover:translate-x-full transform -translate-x-full"
          ]}>
          </div>

          <span class="relative truncate">{item[:label]}</span>
          <MossletWeb.CoreComponents.phx_icon
            name="hero-arrow-top-right-on-square"
            class="relative ml-auto h-4 w-4 transition-all duration-200 opacity-0 group-hover:opacity-100 group-hover:scale-110 text-emerald-500 dark:text-emerald-400"
          />
        </.link>
      </div>
    </div>
    """
  end
end
