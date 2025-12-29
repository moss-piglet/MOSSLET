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
  attr :current_user_name, :string, default: nil
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :session_locked, :boolean, default: false
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
    current_user =
      case assigns[:current_scope] do
        %{user: user} -> user
        _ -> assigns[:current_user]
      end

    key =
      case assigns[:current_scope] do
        %{key: k} -> k
        _ -> assigns[:key]
      end

    assigns =
      assigns
      |> assign(:current_user, current_user)
      |> assign(:key, key)

    ~H"""
    <header
      x-data="{ isOpen: false }"
      x-effect="document.body.style.overflow = isOpen ? 'hidden' : ''"
      @keydown.escape.window="isOpen = false"
      @click.outside="isOpen = false"
      class={[
        "fixed top-0 left-0 z-30 w-full transition-all duration-300 ease-out",
        "lg:sticky backdrop-blur-md",
        "bg-white/95 dark:bg-slate-900/95",
        "border-b border-slate-200/60 dark:border-slate-700/60",
        "shadow-sm shadow-slate-900/5 dark:shadow-slate-900/10",
        @header_class
      ]}
    >
      <.liquid_container max_width="full">
        <div class="relative flex items-center justify-between h-16 lg:h-20">
          <%!-- Logo section with improved spacing --%>
          <div class="flex items-center flex-shrink-0">
            <.link
              href="/"
              class="group inline-flex items-center transition-all duration-300 ease-out hover:scale-105 focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2 rounded-lg"
            >
              <div class="relative overflow-hidden p-1 rounded-xl">
                <%!-- Liquid background effect matching footer --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/80 via-emerald-50/60 to-cyan-50/80 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-cyan-900/20 group-hover:opacity-100 rounded-xl">
                </div>
                <%!-- Shimmer effect matching footer --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/40 to-transparent dark:via-emerald-400/20 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full rounded-xl">
                </div>

                <div class="relative">
                  {render_slot(@logo)}
                </div>
              </div>
            </.link>
          </div>

          <%!-- Desktop navigation - absolutely centered on desktop --%>
          <nav
            aria-label="Main"
            class="hidden lg:flex lg:items-center lg:justify-center lg:absolute lg:left-1/2 lg:-translate-x-1/2"
          >
            <div class="flex items-center space-x-1">
              <.link
                :for={item <- @public_menu_items}
                href={item.path}
                class={[
                  "group relative px-4 py-2.5 rounded-xl text-sm font-medium transition-all duration-300 ease-out",
                  "text-slate-600 dark:text-slate-400",
                  "hover:text-emerald-600 dark:hover:text-emerald-400",
                  "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
                  "overflow-hidden "
                ]}
                method={if item[:method], do: item[:method], else: nil}
              >
                <%!-- Enhanced liquid background effect matching footer exactly --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/40 via-emerald-50/60 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15 group-hover:opacity-100 rounded-xl">
                </div>
                <%!-- Shimmer effect matching footer exactly --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full rounded-xl">
                </div>
                <span class="relative">{item.label}</span>
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
                current_scope={@current_scope}
                current_user_name={@current_user_name}
                avatar_src={@avatar_src}
              />
            </div>

            <%!-- Mobile menu toggle --%>
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

              <%!-- Subtle background effect --%>
              <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/30 via-emerald-50/40 to-cyan-50/30 dark:from-teal-900/10 dark:via-emerald-900/15 dark:to-cyan-900/10 hover:opacity-100 rounded-lg">
              </div>

              <%!-- Hamburger icon --%>
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
              <%!-- Close icon --%>
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
          class="lg:hidden max-h-[calc(100vh-4rem)] overflow-y-auto overscroll-contain"
          x-cloak
        >
          <div class="px-2 pt-2 pb-3 space-y-1 border-t border-slate-200/60 dark:border-slate-700/60">
            <%!-- Mobile navigation items with enhanced liquid effects --%>
            <.link
              :for={item <- @public_menu_footer_items}
              href={item.path}
              class="group relative flex items-center px-4 py-3 text-base font-medium text-slate-700 dark:text-slate-200 hover:text-emerald-600 dark:hover:text-emerald-400 rounded-lg transition-all duration-300 ease-out overflow-hidden"
              method={if item[:method], do: item[:method], else: nil}
            >
              <%!-- Enhanced liquid background effect matching footer exactly --%>
              <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/40 via-emerald-50/50 to-cyan-50/40 dark:from-teal-900/10 dark:via-emerald-900/15 dark:to-cyan-900/10 group-hover:opacity-100">
              </div>
              <%!-- Shimmer effect matching footer exactly --%>
              <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full">
              </div>
              <span class="relative">{item.label}</span>
            </.link>

            <%!-- Mobile authentication section for signed-out users (true guests only, not locked sessions) --%>
            <div
              :if={!(@current_scope && @current_scope.user)}
              class="pt-4 border-t border-slate-200/60 dark:border-slate-700/60 space-y-3"
            >
              <%!-- Guest user card matching desktop dropdown style --%>
              <div class={[
                "flex items-center px-4 py-3 rounded-xl",
                "bg-slate-50 dark:bg-slate-800/80",
                "ring-1 ring-slate-200/60 dark:ring-slate-700/60"
              ]}>
                <div class="relative flex-shrink-0">
                  <MossletWeb.CoreComponents.phx_avatar
                    src={@avatar_src}
                    class="h-10 w-10 rounded-xl object-cover ring-2 ring-white dark:ring-slate-600"
                    alt="Guest avatar"
                  />
                </div>
                <div class="ml-3 flex-1">
                  <div class="text-base font-semibold text-slate-900 dark:text-slate-100">
                    Guest
                  </div>
                  <div class="text-sm text-slate-500 dark:text-slate-400">
                    Sign in to continue
                  </div>
                </div>
              </div>

              <%!-- Sign In button using design system --%>
              <MossletWeb.DesignSystem.liquid_button
                navigate="/auth/sign_in"
                variant="primary"
                color="teal"
                icon="hero-arrow-right-on-rectangle"
                class="w-full justify-center"
              >
                Sign In
              </MossletWeb.DesignSystem.liquid_button>

              <%!-- Register button using design system --%>
              <MossletWeb.DesignSystem.liquid_button
                navigate="/auth/register"
                variant="secondary"
                color="teal"
                icon="hero-user-plus"
                class="w-full justify-center"
              >
                Create Account
              </MossletWeb.DesignSystem.liquid_button>
            </div>

            <%!-- Mobile user section for signed-in users --%>
            <div
              :if={@current_scope && @current_scope.user}
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
                  <div
                    :if={@current_scope && @current_scope.user && !@session_locked}
                    class="text-base font-semibold text-slate-900 dark:text-slate-100"
                  >
                    {@current_user_name}
                  </div>
                  <div
                    :if={@current_scope && @current_scope.user && @session_locked}
                    class="text-base font-semibold text-slate-900 dark:text-slate-100"
                  >
                    Online
                  </div>
                  <div class={[
                    "text-sm",
                    if(@session_locked,
                      do: "text-amber-600 dark:text-amber-400",
                      else: "text-emerald-500 dark:text-emerald-400"
                    )
                  ]}>
                    {if @session_locked, do: "Session locked", else: "Online"}
                  </div>
                </div>
              </div>

              <%!-- Mobile user menu items with full liquid effects --%>
              <.link
                :for={item <- @user_menu_items}
                href={item.path}
                class="group relative flex items-center px-4 py-2.5 text-sm font-medium text-slate-600 dark:text-slate-300 hover:text-emerald-600 dark:hover:text-emerald-400 rounded-lg transition-all duration-300 ease-out overflow-hidden"
                method={if item[:method], do: item[:method], else: nil}
              >
                <%!-- Enhanced liquid background effect matching other nav items --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/30 via-emerald-50/40 to-cyan-50/30 dark:from-teal-900/8 dark:via-emerald-900/12 dark:to-cyan-900/8 group-hover:opacity-100">
                </div>
                <%!-- Shimmer effect matching other nav items --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full">
                </div>
                <span class="relative">{item.label}</span>
              </.link>
            </div>
          </div>
        </div>
      </.liquid_container>
    </header>

    <%!-- Main content without header spacing since hero handles its own positioning --%>
    <main class="bg-white dark:bg-slate-950">
      {render_slot(@inner_block)}
    </main>

    <%!-- Footer with seamless liquid metal integration --%>
    <footer class="relative overflow-hidden">
      <%!-- Liquid Metal Background System matching hero design --%>
      <div class="absolute inset-0 bg-gradient-to-b from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-950 dark:to-slate-900">
      </div>

      <%!-- Subtle Liquid Background Accent --%>
      <div class="absolute inset-0 bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10">
      </div>

      <%!-- Seamless transition gradient from main content --%>
      <div class="absolute top-0 left-0 right-0 h-24 bg-gradient-to-b from-white via-slate-50/90 to-transparent dark:from-slate-950 dark:via-slate-900/90 dark:to-transparent">
      </div>

      <%!-- Decorative top border with enhanced liquid gradient --%>
      <div class="absolute top-0 left-0 right-0 h-px">
        <div class="h-full bg-gradient-to-r from-transparent via-teal-200/60 via-emerald-300/80 via-cyan-200/60 to-transparent dark:via-teal-700/40 dark:via-emerald-600/60 dark:via-cyan-700/40">
        </div>
      </div>

      <.liquid_container max_width={@max_width} class="relative">
        <.liquid_footer current_scope={@current_scope} />
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
          <%!-- Online indicator with improved positioning (only when user is signed in) --%>
          <div
            :if={@current_scope && @current_scope.user}
            class={[
              "absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full",
              "bg-gradient-to-br from-emerald-400 to-emerald-500",
              "ring-2 ring-white dark:ring-slate-800",
              "transition-all duration-300",
              "group-hover:scale-110 group-hover:from-emerald-300 group-hover:to-emerald-400"
            ]}
          >
            <%!-- Inner pulse dot --%>
            <div class="absolute inset-1 rounded-full bg-white/30 animate-ping"></div>
          </div>
        </div>

        <%!-- User name with better typography (hidden on small screens) --%>
        <div class="hidden lg:block relative flex-1 text-left">
          <div class="text-sm font-semibold text-slate-700 dark:text-slate-200 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors duration-200">
            {@current_user_name}
          </div>
          <div class="text-xs text-slate-500 dark:text-slate-400">
            {if @current_scope && @current_scope.user, do: "Online", else: "Guest"}
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
        x-transition:enter="transition ease-out duration-300 transform-gpu"
        x-transition:enter-start="opacity-0 -translate-y-1"
        x-transition:enter-end="opacity-100 translate-y-0"
        x-transition:leave="transition ease-in duration-200 transform-gpu"
        x-transition:leave-start="opacity-100 translate-y-0"
        x-transition:leave-end="opacity-0 -translate-y-1"
        class={[
          "absolute right-0 z-50 mt-3 w-48 origin-top-right overflow-hidden",
          "rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-md",
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
