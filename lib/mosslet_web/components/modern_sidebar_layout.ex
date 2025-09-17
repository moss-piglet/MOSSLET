defmodule MossletWeb.ModernSidebarLayout do
  @moduledoc """
  A modern, calm sidebar layout component with improved visual hierarchy.
  Designed to be responsive, accessible, and visually appealing on both mobile and desktop.
  """
  use MossletWeb, :verified_routes
  use Phoenix.Component

  import MossletWeb.ModernSidebarMenu
  import MossletWeb.Helpers

  alias Phoenix.LiveView.JS, as: JS
  alias Mosslet.Repo

  attr :current_page, :atom, required: true
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
    ~H"""
    <div
      class="min-h-screen bg-slate-50/50 dark:bg-slate-900"
      x-data="{ sidebarOpen: false }"
      x-bind:class="{ 'overflow-hidden h-screen': sidebarOpen }"
    >
      <%!-- Mobile sidebar backdrop --%>
      <div
        class="fixed inset-0 z-40 lg:hidden"
        x-show="sidebarOpen"
        x-transition:enter="transition-opacity ease-linear duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition-opacity ease-linear duration-200"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0"
        @click="sidebarOpen = false"
        x-cloak
        style="position: fixed !important; top: 0 !important; left: 0 !important; right: 0 !important; bottom: 0 !important; width: 100vw !important; height: 100vh !important;"
      >
        <div class="absolute inset-0 bg-slate-900/50 backdrop-blur-sm"></div>
      </div>

      <%!-- Desktop sidebar --%>
      <aside class="hidden lg:fixed lg:inset-y-0 lg:z-30 lg:flex lg:w-72 lg:flex-col">
        <div class={[
          "flex grow flex-col gap-y-6 overflow-y-auto px-6 pb-4",
          "bg-gradient-to-b from-white via-slate-50/50 to-slate-100/30",
          "dark:from-slate-800 dark:via-slate-800/80 dark:to-slate-900/60",
          "border-r border-slate-200/60 dark:border-slate-700/60",
          "backdrop-blur-sm"
        ]}>
          <%!-- Logo --%>
          <div class="flex h-16 shrink-0 items-center">
            <.link
              navigate={@home_path}
              class="group block transition-transform duration-300 ease-out hover:scale-105"
            >
              <div class="relative">
                {render_slot(@logo)}
                <div class="absolute inset-0 rounded-lg bg-gradient-to-br from-emerald-500/0 to-cyan-500/0 group-hover:from-emerald-500/5 group-hover:to-cyan-500/5 transition-all duration-300">
                </div>
              </div>
            </.link>
          </div>

          <%!-- Navigation --%>
          <nav class="flex flex-1 flex-col space-y-2">
            <.modern_sidebar_menu
              menu_items={@main_menu_items}
              current_page={@current_page}
              title={@sidebar_title}
            />
          </nav>
        </div>
      </aside>

      <%!-- Mobile sidebar --%>
      <div class="relative z-50 lg:hidden">
        <div
          class={[
            "fixed z-50 w-72 flex flex-col px-0 pb-4",
            "bg-gradient-to-b from-white via-slate-50/50 to-slate-100/30",
            "dark:from-slate-800 dark:via-slate-800/80 dark:to-slate-900/60",
            "border-r border-slate-200/60 dark:border-slate-700/60",
            "backdrop-blur-sm transition-transform duration-300 ease-out"
          ]}
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

          <nav class="flex-1 overflow-y-auto px-2 py-4 scrollbar-thin scrollbar-thumb-slate-300 dark:scrollbar-thumb-slate-600 scrollbar-track-transparent">
            <.modern_sidebar_menu
              menu_items={@main_menu_items}
              current_page={@current_page}
              title={@sidebar_title}
            />
          </nav>
        </div>
      </div>

      <%!-- Main content --%>
      <div class="lg:pl-72">
        <%!-- Top bar --%>
        <div class={[
          "sticky top-0 z-20 flex h-16 shrink-0 items-center gap-x-4 px-4 sm:gap-x-6 sm:px-6 lg:px-8",
          "border-b border-slate-200/60 dark:border-slate-700/60",
          "bg-gradient-to-r from-white/90 via-slate-50/80 to-white/90",
          "dark:from-slate-800/90 dark:via-slate-800/80 dark:to-slate-800/90",
          "backdrop-blur-md shadow-sm shadow-slate-900/5 dark:shadow-slate-900/20"
        ]}>
          <%!-- Mobile menu button --%>
          <button
            @click="sidebarOpen = !sidebarOpen"
            class={[
              "group p-2.5 lg:hidden rounded-lg transition-all duration-200 ease-out",
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
          <div class="h-6 w-px bg-slate-200 dark:bg-slate-700 lg:hidden" aria-hidden="true"></div>

          <%!-- Right side content --%>
          <div class="flex flex-1 gap-x-4 self-stretch lg:gap-x-6 justify-end">
            <div class="flex items-center gap-x-4 lg:gap-x-6">
              {render_slot(@top_right)}

              <%!-- User menu --%>
              <.modern_user_menu
                :if={@user_menu_items != []}
                user_menu_items={@user_menu_items}
                current_user={@current_user}
                key={@key}
              />
            </div>
          </div>
        </div>

        <%!-- Beta banner --%>
        <.modern_beta_banner :if={@current_user} current_user={@current_user} />

        <%!-- Page content --%>
        <main>
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  # Modern beta banner with improved styling
  defp modern_beta_banner(assigns) do
    ~H"""
    <div
      :if={!has_subscription?(@current_user)}
      class="relative isolate flex items-center gap-x-6 overflow-hidden bg-gradient-to-r from-emerald-50 to-cyan-50 dark:from-emerald-900/20 dark:to-cyan-900/20 px-6 py-2.5 sm:px-3.5"
    >
      <div
        class="absolute left-[max(-7rem,calc(50%-52rem))] top-1/2 -z-10 -translate-y-1/2 transform-gpu blur-2xl"
        aria-hidden="true"
      >
        <div
          class="aspect-[577/310] w-[36.0625rem] bg-gradient-to-r from-emerald-400 to-cyan-400 opacity-20"
          style="clip-path: polygon(74.8% 41.9%, 97.2% 73.2%, 100% 34.9%, 92.5% 0.4%, 87.5% 0%, 75% 28.6%, 58.5% 54.6%, 50.1% 56.8%, 46.9% 44%, 48.3% 17.4%, 24.7% 53.9%, 0% 27.9%, 11.9% 74.2%, 24.9% 54.1%, 68.6% 100%, 74.8% 41.9%)"
        >
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-x-4 gap-y-2">
        <p class="text-sm text-slate-900 dark:text-slate-100">
          <strong class="font-semibold">Special Beta Price</strong>
          <svg viewBox="0 0 2 2" class="mx-2 inline h-0.5 w-0.5 fill-current" aria-hidden="true">
            <circle cx="1" cy="1" r="1" />
          </svg>
          Join us for 40% off while we're in beta and have privacy now for life.
        </p>
        <.link
          navigate={~p"/app/subscribe"}
          class="flex-none rounded-full bg-emerald-600 px-3.5 py-1 text-sm font-semibold text-white shadow-sm hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 transition-colors"
        >
          Pay once <span aria-hidden="true">&rarr;</span>
        </.link>
      </div>
    </div>
    """
  end

  # Check if user has subscription
  defp has_subscription?(user) do
    case Repo.preload(user, customer: :subscriptions) do
      %{customer: customer} when not is_nil(customer) -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  # Modern user menu dropdown with liquid metal styling
  defp modern_user_menu(assigns) do
    ~H"""
    <div class="relative" x-data="{ open: false }" @click.away="open = false">
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

        <%!-- Shimmer effect on hover --%>
        <div class={[
          "absolute inset-0 opacity-0 transition-all duration-500",
          "bg-gradient-to-r from-transparent via-white/30 to-transparent",
          "dark:via-emerald-400/20",
          "group-hover:opacity-100 group-hover:translate-x-full transform -translate-x-full"
        ]}>
        </div>

        <div class="relative">
          <MossletWeb.CoreComponents.phx_avatar
            src={maybe_get_user_avatar(@current_user, @key)}
            class="h-8 w-8 rounded-full transition-all duration-300 ring-2 ring-white dark:ring-slate-600 group-hover:ring-emerald-300 dark:group-hover:ring-emerald-400 group-hover:shadow-md group-hover:shadow-emerald-500/30"
            alt="User avatar"
          />
          <%!-- Online indicator with pulse (only when user is signed in) --%>
          <div
            :if={@current_user}
            class={[
              "absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full",
              "bg-gradient-to-br from-emerald-400 to-emerald-500",
              "ring-2 ring-white dark:ring-slate-800",
              "animate-pulse group-hover:animate-bounce"
            ]}
          >
          </div>
        </div>
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
          "absolute right-0 z-50 mt-3 w-48 origin-top-right overflow-hidden",
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
