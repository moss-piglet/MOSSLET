defmodule MossletWeb.ModernSidebarLayout do
  @moduledoc """
  A modern, calm sidebar layout component with improved visual hierarchy.
  Designed to be responsive, accessible, and visually appealing on both mobile and desktop.
  """
  use MossletWeb, :verified_routes
  use Phoenix.Component
  
  import MossletWeb.ModernSidebarMenu
  import MossletWeb.Helpers
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
    <div class="min-h-screen bg-slate-50/50 dark:bg-slate-900" x-data="{ sidebarOpen: false }">
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
      >
        <div class="absolute inset-0 bg-slate-900/50 backdrop-blur-sm"></div>
      </div>

      <%!-- Desktop sidebar --%>
      <aside class="hidden lg:fixed lg:inset-y-0 lg:z-30 lg:flex lg:w-64 lg:flex-col">
        <div class="flex grow flex-col gap-y-5 overflow-y-auto bg-white dark:bg-slate-800 border-r border-slate-200 dark:border-slate-700 px-6 pb-4">
          <%!-- Logo --%>
          <div class="flex h-16 shrink-0 items-center">
            <.link navigate={@home_path} class="block">
              {render_slot(@logo)}
            </.link>
          </div>
          
          <%!-- Navigation --%>
          <nav class="flex flex-1 flex-col">
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
          class="fixed inset-y-0 left-0 z-50 w-64 overflow-y-auto bg-white dark:bg-slate-800 border-r border-slate-200 dark:border-slate-700 px-6 pb-4 transition-transform duration-200 ease-in-out"
          x-show="sidebarOpen"
          x-transition:enter="transform transition ease-in-out duration-200"
          x-transition:enter-start="-translate-x-full"
          x-transition:enter-end="translate-x-0"
          x-transition:leave="transform transition ease-in-out duration-200"
          x-transition:leave-start="translate-x-0"
          x-transition:leave-end="-translate-x-full"
          x-cloak
        >
          <div class="flex h-16 shrink-0 items-center justify-between">
            <.link navigate={@home_path} class="block">
              {render_slot(@logo)}
            </.link>
            <button 
              @click="sidebarOpen = false"
              class="p-2 rounded-lg text-slate-500 hover:text-slate-700 hover:bg-slate-100 dark:text-slate-400 dark:hover:text-slate-200 dark:hover:bg-slate-700 transition-colors"
            >
              <span class="sr-only">Close sidebar</span>
              <MossletWeb.CoreComponents.phx_icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          
          <nav class="flex flex-1 flex-col mt-5">
            <.modern_sidebar_menu 
              menu_items={@main_menu_items}
              current_page={@current_page}
              title={@sidebar_title}
            />
          </nav>
        </div>
      </div>

      <%!-- Main content --%>
      <div class="lg:pl-64">
        <%!-- Top bar --%>
        <div class="sticky top-0 z-20 flex h-16 shrink-0 items-center gap-x-4 border-b border-slate-200 dark:border-slate-700 bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm px-4 shadow-sm sm:gap-x-6 sm:px-6 lg:px-8">
          <%!-- Mobile menu button --%>
          <button 
            @click="sidebarOpen = !sidebarOpen"
            class="p-2.5 text-slate-700 dark:text-slate-200 lg:hidden rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
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
      <div class="absolute left-[max(-7rem,calc(50%-52rem))] top-1/2 -z-10 -translate-y-1/2 transform-gpu blur-2xl" aria-hidden="true">
        <div 
          class="aspect-[577/310] w-[36.0625rem] bg-gradient-to-r from-emerald-400 to-cyan-400 opacity-20"
          style="clip-path: polygon(74.8% 41.9%, 97.2% 73.2%, 100% 34.9%, 92.5% 0.4%, 87.5% 0%, 75% 28.6%, 58.5% 54.6%, 50.1% 56.8%, 46.9% 44%, 48.3% 17.4%, 24.7% 53.9%, 0% 27.9%, 11.9% 74.2%, 24.9% 54.1%, 68.6% 100%, 74.8% 41.9%)"
        ></div>
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

  # Modern user menu dropdown
  defp modern_user_menu(assigns) do
    ~H"""
    <div class="relative" x-data="{ open: false }" @click.away="open = false">
      <button
        @click="open = !open"
        class="flex items-center gap-x-2 rounded-full bg-white dark:bg-slate-800 p-1.5 text-sm ring-1 ring-slate-200 dark:ring-slate-700 hover:ring-slate-300 dark:hover:ring-slate-600 transition-all"
      >
        <span class="sr-only">Open user menu</span>
        <MossletWeb.CoreComponents.phx_avatar 
          src={maybe_get_user_avatar(@current_user, @key)}
          size="h-8 w-8" 
          class="rounded-full"
          alt="User avatar"
        />
      </button>

      <div
        x-show="open"
        x-transition:enter="transition ease-out duration-100"
        x-transition:enter-start="transform opacity-0 scale-95"
        x-transition:enter-end="transform opacity-100 scale-100"
        x-transition:leave="transition ease-in duration-75"
        x-transition:leave-start="transform opacity-100 scale-100"
        x-transition:leave-end="transform opacity-0 scale-95"
        class="absolute right-0 z-10 mt-2 w-48 origin-top-right rounded-lg bg-white dark:bg-slate-800 py-1 shadow-lg ring-1 ring-slate-900/5 dark:ring-slate-700/50 focus:outline-none"
        x-cloak
      >
        <.link
          :for={item <- @user_menu_items}
          navigate={item[:path]}
          class="block px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
          @click="open = false"
        >
          {item[:label]}
        </.link>
      </div>
    </div>
    """
  end
end