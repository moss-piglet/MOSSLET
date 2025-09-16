defmodule MossletWeb.PublicLayout do
  @moduledoc """
  Modern public layout for landing, about, pricing pages.
  Updated to use our design system instead of Petal Components.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes
  alias MossletWeb.DesignSystem

  # Import our liquid container and footer components
  defp liquid_container(assigns) do
    DesignSystem.liquid_container(assigns)
  end

  defp liquid_footer(assigns) do
    DesignSystem.liquid_footer(assigns)
  end

  attr :current_page, :atom, required: true
  attr :public_menu_items, :list, default: []
  attr :user_menu_items, :list, default: []
  attr :avatar_src, :string, default: nil
  attr :current_user_name, :string, default: "nil"
  attr :current_user, :map, default: nil
  attr :copyright_text, :string, default: "Moss Piglet Corporation, All Rights Reserved."
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]
  attr :header_class, :string, default: ""
  attr :twitter_url, :string, default: nil
  attr :github_url, :string, default: nil
  attr :discord_url, :string, default: nil
  slot(:inner_block)
  slot(:top_right)
  slot(:logo)

  def mosslet_public_layout(assigns) do
    ~H"""
    <header
      x-data="{ isOpen: false }"
      x-init="window.makeHeaderTranslucentOnScroll && window.makeHeaderTranslucentOnScroll()"
      class={[
        "fixed top-0 left-0 z-30 w-full transition-all duration-300 ease-out",
        "lg:sticky backdrop-blur-md",
        "bg-white/95 dark:bg-slate-900/95",
        "border-b border-slate-200/60 dark:border-slate-700/60",
        "shadow-sm shadow-slate-900/5 dark:shadow-slate-900/10",
        @header_class
      ]}
    >
      <.liquid_container max_width={@max_width}>
        <div class="flex items-center justify-between h-16 lg:h-20">
          <%!-- Logo section with improved spacing --%>
          <div class="flex items-center flex-shrink-0">
            <.link
              href="/"
              class="group inline-flex items-center transition-all duration-300 ease-out hover:scale-105 focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2 rounded-lg"
            >
              <div class="relative p-1">
                {render_slot(@logo)}
                <%!-- Subtle hover glow with better positioning --%>
                <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-emerald-500/0 to-cyan-500/0 group-hover:from-emerald-500/10 group-hover:to-cyan-500/10 transition-all duration-300">
                </div>
              </div>
            </.link>
          </div>

          <%!-- Desktop navigation with improved spacing --%>
          <nav class="hidden lg:flex lg:items-center lg:justify-center flex-1 max-w-3xl mx-8">
            <div class="flex items-center space-x-1">
              <.link
                :for={item <- @public_menu_items}
                href={item.path}
                class={[
                  "relative group px-4 py-2.5 rounded-lg font-medium text-sm transition-all duration-300 ease-out",
                  "text-slate-700 dark:text-slate-200",
                  "hover:text-emerald-600 dark:hover:text-emerald-400",
                  "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
                  "overflow-hidden"
                ]}
                method={if item[:method], do: item[:method], else: nil}
              >
                <%!-- Subtle liquid background effect --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/50 via-emerald-50/60 to-cyan-50/50 dark:from-teal-900/10 dark:via-emerald-900/15 dark:to-cyan-900/10 group-hover:opacity-100 rounded-lg">
                </div>
                <span class="relative font-medium">{item.label}</span>
              </.link>
            </div>
          </nav>

          <%!-- Right side content with better organization --%>
          <div class="flex items-center gap-3 flex-shrink-0">
            <%!-- Top right slot content --%>
            <div class="flex items-center gap-2">
              {render_slot(@top_right)}
            </div>

            <%!-- Desktop user menu with improved styling --%>
            <div class="hidden lg:block">
              <.modern_user_dropdown
                :if={@user_menu_items != []}
                user_menu_items={@user_menu_items}
                current_user={@current_user}
                current_user_name={@current_user_name}
                avatar_src={@avatar_src}
              />
            </div>
            
    <!-- Mobile menu toggle -->
            <button
              @click="isOpen = !isOpen"
              class={[
                "lg:hidden p-2.5 rounded-lg transition-all duration-300 ease-out",
                "text-slate-600 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-100",
                "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
                "overflow-hidden relative"
              ]}
            >
              <span class="sr-only">Toggle menu</span>
              
    <!-- Subtle background effect -->
              <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/30 via-emerald-50/40 to-cyan-50/30 dark:from-teal-900/10 dark:via-emerald-900/15 dark:to-cyan-900/10 hover:opacity-100 rounded-lg">
              </div>
              
    <!-- Hamburger icon -->
              <svg
                x-show="!isOpen"
                class="relative w-6 h-6 transition-opacity duration-300 ease-out"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
                />
              </svg>
              <!-- Close icon -->
              <svg
                x-show="isOpen"
                class="relative w-6 h-6 transition-opacity duration-300 ease-out"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                x-cloak
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        <%!-- Mobile menu --%>
        <div
          x-show="isOpen"
          x-transition:enter="transition ease-out duration-200"
          x-transition:enter-start="opacity-0 transform -translate-y-2"
          x-transition:enter-end="opacity-100 transform translate-y-0"
          x-transition:leave="transition ease-in duration-150"
          x-transition:leave-start="opacity-100 transform translate-y-0"
          x-transition:leave-end="opacity-0 transform -translate-y-2"
          class="lg:hidden"
          x-cloak
        >
          <div class="px-2 pt-2 pb-3 space-y-1 border-t border-slate-200/60 dark:border-slate-700/60">
            <%!-- Mobile navigation items --%>
            <.link
              :for={item <- @public_menu_items}
              href={item.path}
              class="group relative flex items-center px-4 py-3 text-base font-medium text-slate-700 dark:text-slate-200 hover:text-emerald-600 dark:hover:text-emerald-400 rounded-lg transition-all duration-300 ease-out overflow-hidden"
              method={if item[:method], do: item[:method], else: nil}
            >
              <%!-- Subtle liquid background effect --%>
              <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/40 via-emerald-50/50 to-cyan-50/40 dark:from-teal-900/10 dark:via-emerald-900/15 dark:to-cyan-900/10 group-hover:opacity-100">
              </div>
              <span class="relative">{item.label}</span>
            </.link>

            <%!-- Mobile user section --%>
            <div
              :if={@current_user_name && @current_user_name != "nil"}
              class="pt-4 border-t border-slate-200/60 dark:border-slate-700/60"
            >
              <div class="flex items-center px-4 py-3 bg-gradient-to-r from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-xl mb-2">
                <div class="flex-shrink-0">
                  <MossletWeb.CoreComponents.phx_avatar
                    src={@avatar_src}
                    class="h-10 w-10 rounded-xl object-cover ring-2 ring-white dark:ring-slate-600"
                    alt="User avatar"
                  />
                </div>
                <div class="ml-3">
                  <div class="text-base font-semibold text-slate-900 dark:text-slate-100">
                    {@current_user_name}
                  </div>
                  <div class="text-sm text-slate-500 dark:text-slate-400">
                    Online
                  </div>
                </div>
              </div>

              <%!-- Mobile user menu items --%>
              <.link
                :for={item <- @user_menu_items}
                href={item.path}
                class="group relative flex items-center px-4 py-2.5 text-sm font-medium text-slate-600 dark:text-slate-300 hover:text-emerald-600 dark:hover:text-emerald-400 rounded-lg transition-all duration-300 ease-out overflow-hidden"
                method={if item[:method], do: item[:method], else: nil}
              >
                <%!-- Subtle liquid background effect --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/30 via-emerald-50/40 to-cyan-50/30 dark:from-teal-900/8 dark:via-emerald-900/12 dark:to-cyan-900/8 group-hover:opacity-100">
                </div>
                <span class="relative">{item.label}</span>
              </.link>
            </div>
          </div>
        </div>
      </.liquid_container>
    </header>

    <%!-- Main content with proper spacing --%>
    <div class="bg-white dark:bg-slate-950 pt-16 lg:pt-20">
      {render_slot(@inner_block)}
    </div>

    <!-- Footer -->
    <footer class="bg-white dark:bg-slate-950">
      <.liquid_container max_width={@max_width}>
        <.liquid_footer current_user={@current_user} />
      </.liquid_container>
    </footer>
    """
  end

  # Modern user dropdown component with improved avatar styling
  defp modern_user_dropdown(assigns) do
    ~H"""
    <div class="relative" x-data="{ open: false }" @click.away="open = false">
      <button
        @click="open = !open"
        class={[
          "group relative flex items-center gap-x-3 rounded-xl p-2 overflow-hidden",
          "bg-gradient-to-br from-white via-slate-50 to-white",
          "dark:from-slate-800 dark:via-slate-700 dark:to-slate-800",
          "ring-1 ring-slate-200/60 dark:ring-slate-600/40",
          "hover:ring-emerald-300/60 dark:hover:ring-emerald-500/40",
          "hover:shadow-lg hover:shadow-emerald-500/20 dark:hover:shadow-emerald-400/10",
          "transition-all duration-300 ease-out hover:scale-105 active:scale-95",
          "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2"
        ]}
      >
        <span class="sr-only">Open user menu</span>

        <%!-- Shimmer effect on hover --%>
        <div class={[
          "absolute inset-0 opacity-0 transition-all duration-500",
          "bg-gradient-to-r from-transparent via-white/40 to-transparent",
          "dark:via-emerald-400/20",
          "group-hover:opacity-100 group-hover:translate-x-full transform -translate-x-full rounded-xl"
        ]}>
        </div>

        <%!-- Avatar with improved styling --%>
        <div class="relative flex-shrink-0">
          <MossletWeb.CoreComponents.phx_avatar
            src={@avatar_src}
            class={[
              "h-10 w-10 rounded-xl object-cover transition-all duration-300",
              "ring-2 ring-white dark:ring-slate-600",
              "group-hover:ring-emerald-300 dark:group-hover:ring-emerald-400",
              "group-hover:shadow-lg group-hover:shadow-emerald-500/30",
              "group-hover:scale-105"
            ]}
            alt="User avatar"
          />
          <%!-- Online indicator with improved positioning --%>
          <div class={[
            "absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full",
            "bg-gradient-to-br from-emerald-400 to-emerald-500",
            "ring-2 ring-white dark:ring-slate-800",
            "transition-all duration-300",
            "group-hover:scale-110 group-hover:from-emerald-300 group-hover:to-emerald-400"
          ]}>
            <%!-- Inner pulse dot --%>
            <div class="absolute inset-1 rounded-full bg-white/30 animate-ping"></div>
          </div>
        </div>

        <%!-- User name with better typography (hidden on small screens) --%>
        <div class="hidden xl:block relative flex-1 text-left">
          <div class="text-sm font-semibold text-slate-700 dark:text-slate-200 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors duration-200">
            {@current_user_name}
          </div>
          <div class="text-xs text-slate-500 dark:text-slate-400">
            Online
          </div>
        </div>

        <%!-- Chevron icon --%>
        <MossletWeb.CoreComponents.phx_icon
          name="hero-chevron-down"
          class="relative h-4 w-4 text-slate-400 dark:text-slate-500 group-hover:text-emerald-500 transition-all duration-200 group-hover:rotate-180"
        />
      </button>

      <div
        x-show="open"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="transform opacity-0 scale-95 -translate-y-2"
        x-transition:enter-end="transform opacity-100 scale-100 translate-y-0"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="transform opacity-100 scale-100 translate-y-0"
        x-transition:leave-end="transform opacity-0 scale-95 -translate-y-2"
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
            "transition-all duration-200 ease-out",
            "first:rounded-t-lg last:rounded-b-lg"
          ]}
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
