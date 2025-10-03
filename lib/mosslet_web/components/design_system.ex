defmodule MossletWeb.DesignSystem do
  @moduledoc """
  Reusable components following the Mosslet Design System.

  This module provides consistent implementations of common UI patterns
  using our liquid metal aesthetic with teal-to-emerald gradients.

  See DESIGN_SYSTEM.md for detailed guidelines and principles.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  # Import Phoenix.LiveView.JS for modal functionality
  alias Phoenix.LiveView.JS

  # Import phx_input from CoreComponents
  import MossletWeb.CoreComponents, only: [phx_input: 1]

  # Import helper functions
  import MossletWeb.Helpers,
    only: [
      contains_html?: 1,
      decr: 3,
      html_block: 1,
      photos?: 1,
      user_name: 2,
      maybe_get_user_avatar: 2,
      decr_item: 6,
      get_post_key: 2,
      show_avatar?: 1,
      maybe_get_avatar_src: 4,
      get_uconn_for_shared_item: 2
    ]

  # Custom modal functions that prevent scroll jumping and ensure viewport positioning
  defp liquid_show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.remove_class("hidden", to: "##{id}-container")
    |> JS.add_class("opacity-100 translate-y-0 sm:scale-100", to: "##{id}-container")
    |> JS.remove_class("opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
      to: "##{id}-container"
    )
    |> JS.add_class("overflow-hidden", to: "body")
    # Ensure any stale modals are cleaned up
    |> JS.dispatch("phx:cleanup-stale-modals", detail: %{current_id: id})
    # Move modal to body to escape stacking context
    |> JS.dispatch("phx:modal-to-body", to: "##{id}")
  end

  defp liquid_hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.add_class("opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
      to: "##{id}-container"
    )
    |> JS.remove_class("opacity-100 translate-y-0 sm:scale-100", to: "##{id}-container")
    |> JS.add_class("hidden", to: "##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Primary button with liquid metal styling.

  ## Examples

      <.liquid_button>Save Changes</.liquid_button>
      <.liquid_button size="sm" icon="hero-plus">Add Item</.liquid_button>
      <.liquid_button variant="secondary">Cancel</.liquid_button>
      <.liquid_button shimmer="page">Button on page background</.liquid_button>
  """
  attr :type, :string, default: "button"
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :variant, :string, default: "primary", values: ~w(primary secondary ghost)
  attr :shimmer, :string, default: "card", values: ~w(card page)

  attr :color, :string,
    default: "teal",
    values: ~w(teal emerald blue purple amber rose cyan indigo slate)

  attr :icon, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :class, :any, default: ""
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-submit data-tippy-content phx-hook id)
  slot :inner_block, required: true

  def liquid_button(assigns) do
    # Determine if this should be a link or button
    is_link = assigns[:href] || assigns[:navigate] || assigns[:patch]

    assigns = assign(assigns, :is_link, is_link)

    ~H"""
    <.link
      :if={@is_link}
      href={@href}
      navigate={@navigate}
      patch={@patch}
      class={
        [
          # Base styles
          "group relative inline-flex items-center justify-center gap-2 font-semibold",
          "transition-all duration-200 ease-out transform-gpu will-change-transform",
          "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
          "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100",

          # Size variants
          button_size_classes(@size),

          # Style variants
          button_variant_classes(@variant, @color),

          # Custom classes
          @class
        ]
      }
      {@rest}
    >
      <%!-- Shimmer effect for primary buttons --%>
      <div
        :if={@variant == "primary"}
        class={[
          "absolute inset-0 opacity-0 transition-all duration-500 ease-out transform-gpu",
          "group-hover:opacity-100 group-hover:translate-x-full -translate-x-full",
          "rounded-full overflow-hidden pointer-events-none",
          shimmer_classes(@shimmer)
        ]}
      >
      </div>

      <.phx_icon
        :if={@icon}
        name={@icon}
        class={[
          "h-4 w-4 relative z-10 transition-transform duration-200 ease-out",
          icon_animation_classes(@icon)
        ]}
      />
      <span class="relative z-10">{render_slot(@inner_block)}</span>
    </.link>

    <button
      :if={!@is_link}
      type={@type}
      disabled={@disabled}
      class={
        [
          # Base styles
          "group relative inline-flex items-center justify-center gap-2 font-semibold",
          "transition-all duration-200 ease-out transform-gpu will-change-transform",
          "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
          "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100",

          # Size variants
          button_size_classes(@size),

          # Style variants
          button_variant_classes(@variant, @color),

          # Custom classes
          @class
        ]
      }
      {@rest}
    >
      <%!-- Shimmer effect for primary buttons --%>
      <div
        :if={@variant == "primary"}
        class={[
          "absolute inset-0 opacity-0 transition-all duration-500 ease-out transform-gpu",
          "group-hover:opacity-100 group-hover:translate-x-full -translate-x-full",
          "rounded-full overflow-hidden pointer-events-none",
          shimmer_classes(@shimmer)
        ]}
      >
      </div>

      <.phx_icon
        :if={@icon}
        name={@icon}
        class={[
          "h-4 w-4 relative z-10 transition-transform duration-200 ease-out",
          icon_animation_classes(@icon)
        ]}
      />
      <span class="relative z-10">{render_slot(@inner_block)}</span>
    </button>
    """
  end

  @doc """
  Liquid metal card container.

  ## Examples

      <.liquid_card>
        <:title>Card Title</:title>
        Card content goes here
      </.liquid_card>
  """
  attr :class, :any, default: ""
  attr :padding, :string, default: "md", values: ~w(sm md lg)
  slot :title
  slot :inner_block, required: true

  def liquid_card(assigns) do
    ~H"""
    <div class={
      [
        # Base card styling
        "relative rounded-xl overflow-hidden",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30",

        # Padding variants
        card_padding_classes(@padding),

        # Custom classes
        @class
      ]
    }>
      <div
        :if={render_slot(@title)}
        class="mb-4 pb-3 border-b border-slate-200/60 dark:border-slate-700/60"
      >
        <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
          {render_slot(@title)}
        </h3>
      </div>

      <div class="relative">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Modern footer component with liquid metal styling.

  ## Examples

      <.liquid_footer current_user={@current_user} />
  """
  attr :current_user, :map, default: nil
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_footer(assigns) do
    ~H"""
    <%!-- Main footer content with seamless integration --%>
    <div class="relative px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <%!-- Logo section with enhanced liquid styling --%>
        <div class="flex justify-center mb-12">
          <.link
            href="/"
            class="group inline-flex items-center transition-all duration-300 ease-out hover:scale-105 focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2 rounded-xl p-3"
          >
            <%!-- Enhanced logo container with liquid background --%>
            <div class="relative overflow-hidden rounded-xl">
              <%!-- Liquid background effect --%>
              <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/80 via-emerald-50/60 to-cyan-50/80 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-cyan-900/20 group-hover:opacity-100">
              </div>
              <%!-- Shimmer effect --%>
              <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/40 to-transparent dark:via-emerald-400/20 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full">
              </div>

              <MossletWeb.CoreComponents.logo class="relative h-14 w-auto" />
            </div>
          </.link>
        </div>

        <%!-- Navigation links with enhanced liquid styling and improved mobile layout --%>
        <nav class="mb-16">
          <div class="flex flex-wrap justify-center gap-2 sm:gap-3 max-w-4xl mx-auto">
            <.link
              :for={item <- footer_menu_items(@current_user)}
              href={item.path}
              class={[
                "group relative px-4 py-2.5 sm:px-6 sm:py-3 rounded-xl text-sm font-medium transition-all duration-300 ease-out",
                "text-slate-600 dark:text-slate-400",
                "hover:text-emerald-600 dark:hover:text-emerald-400",
                "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
                "overflow-hidden backdrop-blur-sm flex-shrink-0",
                "min-w-0 text-center whitespace-nowrap"
              ]}
              method={if item[:method], do: item[:method], else: nil}
            >
              <%!-- Enhanced liquid background effect --%>
              <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/40 via-emerald-50/60 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15 group-hover:opacity-100 rounded-xl">
              </div>
              <%!-- Shimmer effect --%>
              <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full rounded-xl">
              </div>
              <span class="relative">{item.label}</span>
            </.link>
          </div>
        </nav>

        <%!-- Enhanced divider with liquid gradient --%>
        <div class="mb-12">
          <div class="h-px bg-gradient-to-r from-transparent via-teal-200/40 via-emerald-300/60 via-cyan-200/40 to-transparent dark:via-teal-700/30 dark:via-emerald-600/40 dark:via-cyan-700/30">
          </div>
        </div>

        <%!-- Bottom section with improved layout --%>
        <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-8">
          <%!-- Social links with enhanced styling --%>
          <div class="flex items-center justify-center lg:justify-start gap-4">
            <.footer_social_link
              href={~p"/terms#terms_and_conditions"}
              navigate={true}
              aria_label="MOSSLET Terms and Conditions"
              tooltip="MOSSLET Terms and Conditions"
            >
              <MossletWeb.CoreComponents.phx_icon name="hero-document-text" class="h-5 w-5" />
            </.footer_social_link>

            <.footer_social_link
              href="https://podcast.mosslet.com"
              external={true}
              aria_label="MOSSLET Podcast"
              tooltip="MOSSLET Podcast"
            >
              <svg
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18.75a6 6 0 0 0 6-6v-1.5m-6 7.5a6 6 0 0 1-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 0 1-3-3V4.5a3 3 0 1 1 6 0v8.25a3 3 0 0 1-3 3Z"
                />
              </svg>
            </.footer_social_link>

            <.footer_social_link
              href="https://github.com/moss-piglet/mosslet"
              external={true}
              aria_label="MOSSLET on GitHub"
              tooltip="MOSSLET open source code on GitHub"
            >
              <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z" />
              </svg>
            </.footer_social_link>
          </div>

          <%!-- Copyright and climate info with better typography --%>
          <div class="text-center lg:text-right">
            <p class="text-sm text-slate-600 dark:text-slate-400 font-medium">
              Copyright © {DateTime.utc_now().year} Moss Piglet Corporation.
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-500 mt-1">
              A Public Benefit company. All rights reserved.
            </p>
            <.link
              href="https://climate.stripe.com/0YsHsR"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 mt-3 text-xs text-slate-500 dark:text-slate-500 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors duration-200 group"
            >
              <span>1% of purchases contributed to Stripe Climate</span>
              <img
                src={~p"/images/landing_page/Stripe Climate Badge.svg"}
                class="h-4 w-4 transition-transform duration-200 group-hover:scale-110"
                alt="Stripe Climate"
              />
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Footer social link component with liquid styling
  defp footer_social_link(assigns) do
    assigns = assign_new(assigns, :navigate, fn -> false end)
    assigns = assign_new(assigns, :external, fn -> false end)
    assigns = assign_new(assigns, :tooltip, fn -> nil end)

    assigns =
      assign_new(assigns, :id, fn ->
        # Generate a unique ID based on the href/content
        href_hash =
          :crypto.hash(:md5, assigns[:href] || "") |> Base.encode16() |> String.slice(0, 8)

        "footer-social-#{href_hash}"
      end)

    ~H"""
    <.link
      {if @navigate, do: %{navigate: @href}, else: if(@external, do: %{href: @href, target: "_blank", rel: "noopener noreferrer"}, else: %{href: @href})}
      id={if @tooltip, do: @id, else: nil}
      class={[
        "group relative p-2.5 rounded-xl overflow-hidden transition-all duration-300 ease-out",
        "text-slate-500 dark:text-slate-400",
        "hover:text-emerald-600 dark:hover:text-emerald-400",
        "hover:scale-110 active:scale-95",
        "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2"
      ]}
      aria-label={@aria_label}
      data-tippy-content={@tooltip}
      phx-hook={if @tooltip, do: "TippyHook", else: nil}
    >
      <%!-- Liquid background effect --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50 via-emerald-50 to-cyan-50 dark:from-teal-900/20 dark:via-emerald-900/25 dark:to-cyan-900/20 group-hover:opacity-100 rounded-xl">
      </div>
      <%!-- Icon content --%>
      <div class="relative">
        {render_slot(@inner_block)}
      </div>
    </.link>
    """
  end

  # Helper function for footer menu items
  defp footer_menu_items(current_user) do
    base_items = [
      %{path: "/about", label: "About"},
      %{path: "/myob", label: "MYOB"},
      %{path: "/blog", label: "Blog"},
      %{path: "/features", label: "Features"},
      %{path: "/in-the-know", label: "Huh?"},
      %{path: "/pricing", label: "Pricing"},
      %{path: "/privacy", label: "Privacy"},
      %{path: "/support", label: "Support"},
      %{path: "/faq", label: "FAQ"}
    ]

    # Add conditional items based on user state
    if current_user do
      base_items
    else
      base_items
    end
  end

  @doc """
  Modern modal component with liquid metal styling.

  ## Examples

      <.liquid_modal id="my-modal" show={@show_modal}>
        <:title>Modal Title</:title>
        Modal content goes here
      </.liquid_modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :size, :string, default: "md", values: ~w(sm md lg xl)
  attr :on_cancel, JS, default: %JS{}
  attr :class, :any, default: ""
  slot :title
  slot :inner_block, required: true

  def liquid_modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && liquid_show_modal(@id)}
      phx-remove={liquid_hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="fixed top-0 left-0 w-screen h-screen z-[60] hidden"
      style="position: fixed !important;"
      phx-hook="ModalPortal"
      data-modal-type="liquid-modal"
    >
      <%!-- Backdrop with liquid metal blur effect --%>
      <div
        id={"#{@id}-bg"}
        class={[
          "fixed top-0 left-0 right-0 bottom-0 z-40 transition-all duration-300 ease-out",
          "bg-gradient-to-br from-slate-900/60 via-slate-800/80 to-slate-900/60",
          "dark:from-slate-950/80 dark:via-slate-900/90 dark:to-slate-950/80",
          "backdrop-blur-md"
        ]}
        aria-hidden="true"
        style="position: fixed !important; top: 0 !important; left: 0 !important; right: 0 !important; bottom: 0 !important;"
      />

      <%!-- Modal container with proper z-index --%>
      <div
        class="fixed top-0 left-0 right-0 bottom-0 z-50 flex items-center justify-center p-2 sm:p-4 lg:p-6"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        style="position: fixed !important; top: 0 !important; left: 0 !important; right: 0 !important; bottom: 0 !important;"
      >
        <div class="flex min-h-full items-center justify-center p-2 sm:p-4 lg:p-6">
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class={
              [
                "relative w-full max-h-[95vh] min-h-0 flex flex-col overflow-hidden",
                "transform-gpu transition-all duration-300 ease-out",
                "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95 hidden",
                "rounded-xl sm:rounded-2xl",
                "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
                "border border-slate-200/60 dark:border-slate-700/60",
                "shadow-2xl shadow-slate-900/25 dark:shadow-slate-900/50",
                "ring-1 ring-slate-200/20 dark:ring-slate-700/30",

                # Size variants with mobile-first approach
                modal_size_classes(@size),

                # Custom classes
                @class
              ]
            }
          >
            <%!-- Subtle liquid background gradient --%>
            <div class="absolute inset-0 bg-gradient-to-br from-teal-50/30 via-emerald-50/20 to-cyan-50/30 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10">
            </div>

            <%!-- Close button with mobile-friendly positioning --%>
            <div class="absolute top-2 right-2 sm:top-4 sm:right-4 z-10">
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class={
                  [
                    "group relative p-2 sm:p-2 rounded-lg sm:rounded-xl overflow-hidden transition-all duration-200 ease-out",
                    "bg-slate-100/80 hover:bg-slate-200/80 dark:bg-slate-700/80 dark:hover:bg-slate-600/80",
                    "text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200",
                    "border border-slate-200/60 dark:border-slate-600/60",
                    "hover:border-slate-300/80 dark:hover:border-slate-500/80",
                    "shadow-sm hover:shadow-md transition-shadow duration-200",
                    "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
                    "hover:scale-110 active:scale-95",
                    # Better mobile touch handling
                    "touch-manipulation"
                  ]
                }
                aria-label="Close modal"
              >
                <%!-- Subtle shimmer on hover --%>
                <div class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300 bg-gradient-to-r from-transparent via-white/30 to-transparent dark:via-emerald-400/20 transform group-hover:translate-x-full -translate-x-full">
                </div>
                <.phx_icon name="hero-x-mark" class="relative h-5 w-5 sm:h-5 sm:w-5" />
              </button>
            </div>

            <%!-- Modal content --%>
            <div class="relative">
              <%!-- Title section with mobile optimization --%>
              <div
                :if={render_slot(@title)}
                class="flex-shrink-0 px-4 sm:px-6 pt-4 sm:pt-6 pb-3 sm:pb-4 border-b border-slate-200/60 dark:border-slate-700/60"
              >
                <h2
                  id={"#{@id}-title"}
                  class="text-lg sm:text-xl font-semibold text-slate-900 dark:text-slate-100 pr-12"
                >
                  {render_slot(@title)}
                </h2>
              </div>

              <%!-- Content area with responsive scrolling - prevent horizontal scroll --%>
              <div id={"#{@id}-content"} class="flex-1 overflow-y-auto overflow-x-hidden p-4 sm:p-6">
                {render_slot(@inner_block)}
              </div>
            </div>
          </.focus_wrap>
        </div>
      </div>
    </div>
    """
  end

  attr :max_width, :string, default: "lg", values: ~w(sm md lg xl full)
  attr :class, :any, default: ""
  attr :no_padding_on_mobile, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def liquid_container(assigns) do
    ~H"""
    <div
      class={
        [
          # Base container styling
          "mx-auto w-full",

          # Max width variants
          container_max_width_classes(@max_width),

          # Responsive padding
          container_padding_classes(@no_padding_on_mobile),

          # Custom classes
          @class
        ]
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Navigation row with liquid metal hover effects.

  ## Examples

      <.liquid_nav_item href="/profile" icon="hero-user" active={@current_page == :profile}>
        Profile
      </.liquid_nav_item>
  """
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :icon, :string, default: nil
  attr :active, :boolean, default: false
  attr :mobile_full_width, :boolean, default: false
  attr :class, :any, default: ""
  slot :inner_block, required: true

  def liquid_nav_item(assigns) do
    ~H"""
    <.link
      href={@href}
      navigate={@navigate}
      patch={@patch}
      class={
        [
          # Base navigation styling
          "group relative flex items-center gap-x-3 text-sm font-medium",
          "transition-all duration-200 ease-out will-change-transform transform-gpu",
          "overflow-hidden backdrop-blur-sm",
          "hover:translate-x-1 active:translate-x-0",

          # Responsive padding
          if(@mobile_full_width,
            do: "px-6 py-4 lg:px-4 lg:py-3 lg:rounded-lg",
            else: "px-4 py-3 rounded-lg"
          ),

          # Active/inactive states
          nav_item_classes(@active),

          # Custom classes
          @class
        ]
      }
    >
      <%!-- Liquid background effect --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-300 ease-out transform-gpu",
        "bg-gradient-to-r from-teal-50/60 via-emerald-50/80 to-cyan-50/60",
        "dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15",
        "group-hover:opacity-100"
      ]}>
      </div>

      <%!-- Shimmer effect --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-500 ease-out transform-gpu",
        "bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent",
        "dark:via-emerald-400/15",
        "group-hover:opacity-100 group-hover:translate-x-full -translate-x-full"
      ]}>
      </div>

      <%!-- Icon with liquid styling --%>
      <div
        :if={@icon}
        class={[
          "relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden",
          "transition-all duration-200 ease-out transform-gpu",
          if(@active,
            do: [
              "bg-gradient-to-br from-teal-500 to-emerald-600 text-white",
              "shadow-md shadow-emerald-500/30"
            ],
            else: [
              "bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100",
              "dark:from-slate-700 dark:via-slate-600 dark:to-slate-700",
              "text-slate-600 dark:text-slate-300",
              "group-hover:from-teal-100 group-hover:via-emerald-50 group-hover:to-cyan-100",
              "dark:group-hover:from-teal-900/30 dark:group-hover:via-emerald-900/25 dark:group-hover:to-cyan-900/30",
              "group-hover:text-emerald-600 dark:group-hover:text-emerald-400"
            ]
          )
        ]}
      >
        <.phx_icon name={@icon} class="h-4 w-4 relative" />
      </div>

      <span class={[
        "relative flex-1 truncate transition-colors duration-200",
        "group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
      ]}>
        {render_slot(@inner_block)}
      </span>

      <%!-- Desktop row indicator --%>
      <div
        :if={!@mobile_full_width}
        class={[
          "relative w-1 h-8 rounded-full transition-all duration-200 transform-gpu",
          "opacity-0 group-hover:opacity-100",
          "bg-gradient-to-b from-teal-400 to-emerald-500",
          "shadow-sm shadow-emerald-500/50"
        ]}
      >
      </div>

      <%!-- Mobile edge indicator --%>
      <div
        :if={@mobile_full_width}
        class={[
          "absolute right-0 top-0 bottom-0 w-1 transition-all duration-200 transform-gpu",
          "lg:hidden opacity-0 group-hover:opacity-100",
          "bg-gradient-to-b from-teal-400 to-emerald-500"
        ]}
      >
      </div>
    </.link>
    """
  end

  # Private helper functions

  defp button_size_classes("sm"), do: "px-3 py-1.5 text-xs rounded-lg"
  defp button_size_classes("md"), do: "px-6 py-3 text-sm rounded-xl"
  defp button_size_classes("lg"), do: "px-8 py-4 text-base rounded-xl"

  defp button_variant_classes("primary", color) do
    gradient_classes = gradient_for_color(color)

    [
      "#{gradient_classes} text-white shadow-lg",
      "hover:scale-105 hover:shadow-xl hover:shadow-#{primary_color_for(color)}-500/25",
      "focus-visible:outline-#{primary_color_for(color)}-600"
    ]
  end

  defp button_variant_classes("secondary", color) do
    [
      "bg-gradient-to-br from-slate-100 to-slate-200 text-slate-700",
      "dark:from-slate-700 dark:to-slate-600 dark:text-slate-200",
      "border border-slate-300 dark:border-slate-600",
      "hover:from-#{color}-100 hover:to-#{secondary_color_for(color)}-100 hover:text-#{color}-700",
      "dark:hover:from-#{color}-900/30 dark:hover:to-#{secondary_color_for(color)}-900/30 dark:hover:text-#{color}-300",
      "hover:border-#{color}-300 dark:hover:border-#{color}-600",
      "focus-visible:outline-slate-600"
    ]
  end

  defp button_variant_classes("ghost", color) do
    [
      "text-slate-600 dark:text-slate-300",
      "hover:bg-#{color}-50 dark:hover:bg-#{color}-900/20",
      "hover:text-#{color}-700 dark:hover:text-#{color}-300",
      "focus-visible:outline-slate-600"
    ]
  end

  # Color gradient mappings
  defp gradient_for_color("teal"), do: "bg-gradient-to-r from-teal-500 to-emerald-500"
  defp gradient_for_color("emerald"), do: "bg-gradient-to-r from-emerald-500 to-teal-500"
  defp gradient_for_color("blue"), do: "bg-gradient-to-r from-blue-500 to-cyan-500"
  defp gradient_for_color("purple"), do: "bg-gradient-to-r from-purple-500 to-violet-500"
  defp gradient_for_color("amber"), do: "bg-gradient-to-r from-amber-500 to-orange-500"
  defp gradient_for_color("rose"), do: "bg-gradient-to-r from-rose-500 to-pink-500"
  defp gradient_for_color("cyan"), do: "bg-gradient-to-r from-cyan-500 to-teal-500"
  defp gradient_for_color("indigo"), do: "bg-gradient-to-r from-indigo-500 to-blue-500"
  defp gradient_for_color("slate"), do: "bg-gradient-to-r from-slate-500 to-slate-600"
  # fallback
  defp gradient_for_color(_), do: "bg-gradient-to-r from-teal-500 to-emerald-500"

  # Primary color for each variant (for shadows, focus, etc.)
  defp primary_color_for("teal"), do: "emerald"
  defp primary_color_for("emerald"), do: "teal"
  defp primary_color_for("blue"), do: "cyan"
  defp primary_color_for("purple"), do: "violet"
  defp primary_color_for("amber"), do: "orange"
  defp primary_color_for("rose"), do: "pink"
  defp primary_color_for("cyan"), do: "teal"
  defp primary_color_for("indigo"), do: "blue"
  defp primary_color_for("slate"), do: "slate"
  # fallback
  defp primary_color_for(_), do: "emerald"

  # Secondary color for gradients and hover states
  defp secondary_color_for("teal"), do: "emerald"
  defp secondary_color_for("emerald"), do: "teal"
  defp secondary_color_for("blue"), do: "cyan"
  defp secondary_color_for("purple"), do: "violet"
  defp secondary_color_for("amber"), do: "orange"
  defp secondary_color_for("rose"), do: "pink"
  defp secondary_color_for("cyan"), do: "teal"
  defp secondary_color_for("indigo"), do: "blue"
  defp secondary_color_for("slate"), do: "slate"
  # fallback
  defp secondary_color_for(_), do: "emerald"

  defp card_padding_classes("sm"), do: "p-4"
  defp card_padding_classes("md"), do: "p-6"
  defp card_padding_classes("lg"), do: "p-8"

  # Shimmer effect classes based on background context
  defp shimmer_classes("card") do
    [
      "bg-gradient-to-r from-transparent via-white/30 to-transparent",
      "dark:bg-gradient-to-r dark:from-transparent dark:via-slate-800/40 dark:to-transparent"
    ]
  end

  defp shimmer_classes("page") do
    [
      "bg-gradient-to-r from-transparent via-white/30 to-transparent",
      "dark:bg-gradient-to-r dark:from-transparent dark:via-slate-900/40 dark:to-transparent"
    ]
  end

  # fallback
  defp shimmer_classes(_), do: shimmer_classes("card")
  defp container_max_width_classes("sm"), do: "max-w-screen-sm"
  defp container_max_width_classes("md"), do: "max-w-screen-md"
  defp container_max_width_classes("lg"), do: "max-w-screen-lg"
  defp container_max_width_classes("xl"), do: "max-w-screen-xl"
  defp container_max_width_classes("full"), do: "max-w-full"
  # fallback
  defp container_max_width_classes(_), do: "max-w-screen-lg"

  # Container padding classes following design system spacing
  defp container_padding_classes(true), do: "px-0 sm:px-6 lg:px-8"
  defp container_padding_classes(false), do: "px-4 sm:px-6 lg:px-8"

  defp nav_item_classes(true) do
    [
      "bg-gradient-to-r from-teal-50/80 via-emerald-50/90 to-cyan-50/70 text-emerald-700",
      "dark:from-teal-900/25 dark:via-emerald-900/35 dark:to-cyan-900/20 dark:text-emerald-300",
      "border-l-2 border-l-emerald-500 dark:border-l-emerald-400",
      "border-y border-r border-emerald-200/50 dark:border-emerald-700/30"
    ]
  end

  defp nav_item_classes(false) do
    [
      "text-slate-600 hover:text-emerald-700 border-l-2 border-l-transparent",
      "dark:text-slate-300 dark:hover:text-emerald-300",
      "hover:border-l-emerald-400 dark:hover:border-l-emerald-500",
      "border-y border-r border-transparent"
    ]
  end

  @doc """
  Liquid metal pricing card component.

  ## Examples

      <.liquid_pricing_card
        title="Personal"
        price="$59"
        period="/once"
        badge="Lifetime"
        description="Own your privacy forever"
        cta_text="Get Started"
        cta_href="/auth/register"
        features={["Feature 1", "Feature 2"]}
      />
  """
  attr :title, :string, required: true
  attr :price, :string, required: true
  attr :period, :string, default: ""
  attr :badge, :string, default: nil
  attr :save_badge, :string, default: nil
  attr :save_tooltip, :string, default: nil
  attr :description, :string, required: true
  attr :note, :string, default: nil
  attr :cta_text, :string, required: true
  attr :cta_href, :string, required: true
  attr :cta_icon, :string, default: nil
  attr :featured, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :features, :list, default: []
  attr :class, :any, default: ""

  def liquid_pricing_card(assigns) do
    ~H"""
    <div class={[
      "relative rounded-2xl overflow-hidden",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30",
      "p-8 sm:p-10 transition-all duration-300 ease-out",
      if(@featured, do: "ring-2 ring-emerald-500/50 scale-105", else: ""),
      if(@disabled, do: "opacity-60", else: "hover:scale-105"),
      @class
    ]}>
      <%!-- Enhanced liquid background for featured cards --%>
      <div
        :if={@featured}
        class="absolute inset-0 bg-gradient-to-br from-teal-50/30 via-emerald-50/20 to-cyan-50/30 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10"
      >
      </div>

      <%!-- Header with title and badge --%>
      <div class="relative flex justify-between items-start mb-4">
        <h3 class="text-base font-semibold leading-7 text-emerald-600 dark:text-emerald-400">
          {@title}
        </h3>
        <.liquid_badge
          :if={@badge}
          variant={if(@disabled, do: "soft", else: "outline")}
          color={if(@disabled, do: "slate", else: "emerald")}
          size="sm"
        >
          {@badge}
        </.liquid_badge>
      </div>

      <%!-- Price section --%>
      <div class="relative mb-6">
        <div class="flex items-baseline gap-x-2">
          <span class="text-5xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
            {@price}
          </span>
          <span :if={@period != ""} class="text-lg text-slate-500 font-medium">{@period}</span>
          <.liquid_badge
            :if={@save_badge && !@disabled}
            id={"save-badge-#{String.downcase(@title)}"}
            variant="soft"
            color="amber"
            size="sm"
            class="ml-2"
            data-tippy-content={@save_tooltip}
            phx-hook={if @save_tooltip, do: "TippyHook", else: nil}
          >
            {@save_badge}
          </.liquid_badge>
        </div>
      </div>

      <%!-- Description --%>
      <p class="relative text-base leading-7 text-slate-600 dark:text-slate-400 mb-6">
        {@description}
        <small :if={@note} class="block mt-2 text-slate-500">{@note}</small>
      </p>

      <%!-- Features list --%>
      <ul
        :if={length(@features) > 0}
        role="list"
        class="relative space-y-3 text-sm leading-6 text-slate-600 dark:text-slate-400 mb-8"
      >
        <li :for={feature <- @features} class="flex gap-x-3">
          <.phx_icon
            name="hero-check"
            class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
          />
          <span>{feature}</span>
        </li>
      </ul>

      <%!-- CTA Button --%>
      <div class="relative">
        <.liquid_button
          href={@cta_href}
          size="lg"
          class="w-full justify-center"
          disabled={@disabled}
          color={if(@featured, do: "teal", else: "blue")}
          variant={if(@featured, do: "primary", else: "secondary")}
          icon={@cta_icon}
        >
          {@cta_text}
        </.liquid_button>
      </div>
    </div>
    """
  end

  @doc """
  Liquid metal comparison table component.

  ## Examples

      <.liquid_comparison_table />
  """
  attr :class, :any, default: ""

  def liquid_comparison_table(assigns) do
    ~H"""
    <div class={[
      "relative rounded-2xl overflow-hidden",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30",
      "p-6 sm:p-8",
      @class
    ]}>
      <%!-- Subtle liquid background --%>
      <div class="absolute inset-0 bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/5 dark:via-emerald-900/3 dark:to-cyan-900/5">
      </div>

      <div class="relative">
        <%!-- Table header --%>
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-white sm:text-3xl">
            How
            <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              MOSSLET
            </span>
            Compares
          </h3>
          <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
            We don't spy on or monetize your personal data
          </p>
        </div>

        <%!-- Responsive table wrapper --%>
        <div class="overflow-x-auto">
          <table class="w-full text-left">
            <thead class="border-b border-slate-200/60 dark:border-slate-700/60">
              <tr>
                <th class="py-3 pr-4 pl-2 font-semibold text-slate-900 dark:text-slate-100 text-sm sm:text-base">
                  Platform
                </th>
                <th class="hidden sm:table-cell py-3 px-2 font-semibold text-slate-900 dark:text-slate-100 text-sm">
                  Tracking
                </th>
                <th class="py-3 px-2 font-semibold text-slate-900 dark:text-slate-100 text-sm text-right">
                  Price/Year
                </th>
                <th class="hidden md:table-cell py-3 pl-2 font-semibold text-slate-900 dark:text-slate-100 text-sm">
                  Privacy
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-200/40 dark:divide-slate-700/40">
              <%!-- MOSSLET Row (Featured) --%>
              <tr class="bg-gradient-to-r from-emerald-50/30 to-teal-50/30 dark:from-emerald-900/10 dark:to-teal-900/10">
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/logo.svg"}
                      alt="MOSSLET logo"
                      class="h-10 w-10 object-contain"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">MOSSLET</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">
                        Moss Piglet Corporation, PBC
                      </div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="minimal">
                    Minimal***
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm font-semibold text-slate-900 dark:text-slate-100">$59 once</div>
                  <div class="text-xs text-emerald-600 dark:text-emerald-400">Lifetime</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="solid" color="emerald" size="sm">
                    Excellent
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- Facebook Row --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/facebook_logo.svg"}
                      alt="Facebook logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">Facebook</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">
                        Meta Platforms, Inc.
                      </div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="extensive">
                    Extensive
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-500 line-through">"Free"</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">~$700/yr</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="rose" size="sm">
                    Poor
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- Instagram Row --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/instagram_logo.png"}
                      alt="Instagram logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">Instagram</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">
                        Meta Platforms, Inc.
                      </div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="extensive">
                    Extensive
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-500 line-through">"Free"</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">~$700/yr</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="rose" size="sm">
                    Poor
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- Twitter/X Row --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/twitter_x_logo.png"}
                      alt="X (Twitter) logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">X (Twitter)</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">X Corp.</div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="extensive">
                    Extensive
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-900 dark:text-slate-100">$96-192/yr*</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">+ data value</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="rose" size="sm">
                    Poor
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- TikTok Row --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/tiktok_logo.png"}
                      alt="TikTok logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">TikTok</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">ByteDance</div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="extensive">
                    Extensive
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-500 line-through">"Free"</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">~$700/yr</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="rose" size="sm">
                    Poor
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- Bluesky Row --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/bluesky_logo.png"}
                      alt="Bluesky logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">Bluesky</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">
                        Bluesky Social, PBC
                      </div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="limited">
                    Limited
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-500 line-through">"Free"</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">~$700/yr</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="amber" size="sm">
                    Limited
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- LinkedIn Row --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/linkedin_logo.png"}
                      alt="LinkedIn logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">LinkedIn</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">
                        Microsoft Corporation
                      </div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="extensive">
                    Extensive
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-900 dark:text-slate-100">$60-120/yr*</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">+ data value</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="rose" size="sm">
                    Poor
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- Reddit Row --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/reddit_logo.svg"}
                      alt="Reddit logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">Reddit</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">Reddit Inc.</div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="extensive">
                    Extensive
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-900 dark:text-slate-100">$50-100/yr*</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">+ data value</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="rose" size="sm">
                    Poor
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- Signal Row (Good privacy) --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/signal_logo.png"}
                      alt="Signal logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">Signal</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">
                        Signal Technology Foundation
                      </div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="minimal">
                    Minimal***
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-900 dark:text-slate-100">Free</div>
                  <div class="text-xs text-emerald-600 dark:text-emerald-400">Donations</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="solid" color="emerald" size="sm">
                    Excellent
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- Mastodon Row (Decentralized, good privacy) --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/mastodon_logo.png"}
                      alt="Mastodon logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">Mastodon</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">Mastodon gGmbH</div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="orange">
                    Varies
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-900 dark:text-slate-100">Free**</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">Instance costs</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="orange" size="sm">
                    Varies
                  </.liquid_badge>
                </td>
              </tr>

              <%!-- Kin Social Row --%>
              <tr>
                <td class="py-4 pr-4 pl-2">
                  <div class="flex items-center gap-x-3">
                    <img
                      src={~p"/images/landing_page/kin_logo.png"}
                      alt="Kin Social logo"
                      class="h-10 w-10 object-contain rounded-lg"
                    />
                    <div>
                      <div class="font-semibold text-slate-900 dark:text-slate-100">Kin Social</div>
                      <div class="text-xs text-slate-600 dark:text-slate-400">
                        Todos Media Limited
                      </div>
                    </div>
                  </div>
                </td>
                <td class="hidden sm:table-cell py-4 px-2">
                  <.liquid_tracking_indicator status="extensive">
                    Extensive
                  </.liquid_tracking_indicator>
                </td>
                <td class="py-4 px-2 text-right">
                  <div class="text-sm text-slate-500 line-through">"Free"</div>
                  <div class="text-xs text-slate-600 dark:text-slate-400">~$700/yr</div>
                </td>
                <td class="hidden md:table-cell py-4 pl-2">
                  <.liquid_badge variant="soft" color="rose" size="sm">
                    Poor
                  </.liquid_badge>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Footer note --%>
        <div class="mt-6 text-center space-y-2">
          <p class="text-xs text-slate-500 dark:text-slate-500">
            * Also offers "free" tier (~$700/yr data cost)
          </p>
          <p class="text-xs text-slate-500 dark:text-slate-500">
            ** Premium features available ($500/month)
          </p>
          <p class="text-xs text-slate-500 dark:text-slate-500">
            *** Collects minimal operational data necessary for service functionality:
            MOSSLET (encrypted payment info, security logs), Signal (phone numbers for messaging)
          </p>
          <p class="text-sm text-slate-600 dark:text-slate-400">
            Data value estimates based on research by
            <a
              href="https://proton.me/blog/what-is-your-data-worth"
              target="_blank"
              rel="noopener noreferrer"
              class="text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500 underline"
            >
              Proton
            </a>
            and industry analysis.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Liquid metal badge component with various styles and colors.

  ## Examples

      <.liquid_badge>Default</.liquid_badge>
      <.liquid_badge variant="soft" color="emerald">Success</.liquid_badge>
      <.liquid_badge variant="outline" color="amber">Warning</.liquid_badge>
      <.liquid_badge variant="solid" color="rose">Error</.liquid_badge>
  """
  attr :variant, :string, default: "soft", values: ~w(soft solid outline)

  attr :color, :string,
    default: "slate",
    values: ~w(slate teal emerald blue cyan purple violet amber orange rose pink indigo)

  attr :size, :string, default: "sm", values: ~w(xs sm md lg)
  attr :class, :any, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def liquid_badge(assigns) do
    ~H"""
    <span
      class={
        [
          "inline-flex items-center font-medium transition-all duration-200 ease-out",

          # Size variants
          badge_size_classes(@size),

          # Style variants with liquid metal effects
          badge_variant_classes(@variant, @color),

          # Custom classes
          @class
        ]
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Liquid metal checkbox component with enhanced styling.

  ## Examples

      <.liquid_checkbox field={@form[:accept_terms]} label="I accept the terms" />
      <.liquid_checkbox field={@form[:newsletter]} label="Subscribe to newsletter" help="Get weekly updates" />
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :help, :string, default: nil
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_checkbox(assigns) do
    # Extract field information
    value = assigns.field.value
    assigns = assign(assigns, :checked, value == true or value == "true" or value == "on")
    assigns = assign(assigns, :id, assigns.field.id)
    assigns = assign(assigns, :name, assigns.field.name)
    assigns = assign(assigns, :value, assigns.field.value)

    # Check for errors
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []
    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error(&1)))

    ~H"""
    <div phx-feedback-for={@name} class={["space-y-2", @class]}>
      <div class="group relative overflow-hidden rounded-xl p-3 -m-3 transition-all duration-200 ease-out hover:bg-slate-50 dark:hover:bg-slate-800/50">
        <%!-- Enhanced liquid background effect on hover and focus --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-hover:opacity-100 group-focus-within:opacity-100 rounded-xl">
        </div>

        <%!-- Enhanced shimmer effect on hover and focus --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-focus-within:opacity-100 group-hover:translate-x-full group-focus-within:translate-x-full -translate-x-full rounded-xl">
        </div>

        <%!-- Focus ring with liquid metal styling --%>
        <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
        </div>

        <%!-- Secondary focus ring for better definition --%>
        <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
        </div>

        <div class="relative flex items-start gap-4">
          <%!-- Checkbox input with enhanced liquid styling --%>
          <div class="relative flex-shrink-0 pt-0.5">
            <input type="hidden" name={@name} value="false" />
            <input
              type="checkbox"
              id={@id}
              name={@name}
              value="true"
              checked={@checked}
              class={[
                "h-5 w-5 rounded-lg border-2 transition-all duration-200 ease-out transform-gpu cursor-pointer",
                "bg-slate-50 dark:bg-slate-900 text-emerald-600 dark:text-emerald-400",
                "border-slate-300 dark:border-slate-600",
                "hover:border-emerald-400 dark:hover:border-emerald-500 hover:bg-emerald-50 dark:hover:bg-emerald-900/20",
                "focus:border-emerald-500 dark:focus:border-emerald-400",
                "focus:outline-none focus:ring-0",
                "checked:border-emerald-600 dark:checked:border-emerald-400 checked:bg-emerald-600 dark:checked:bg-emerald-500",
                "shadow-sm hover:shadow-md focus:shadow-lg focus:shadow-emerald-500/10",
                "disabled:opacity-50 disabled:cursor-not-allowed",
                @errors != [] && "border-rose-400 focus:border-rose-400 hover:border-rose-500"
              ]}
              }
              {@rest}
            />
          </div>

          <%!-- Label and help text --%>
          <div class="flex-1 min-w-0">
            <label
              for={@id}
              class="block text-sm font-medium text-slate-900 dark:text-slate-100 cursor-pointer leading-relaxed group-hover:text-emerald-700 dark:group-hover:text-emerald-300 transition-colors duration-200 ease-out"
            >
              {@label}
            </label>
            <p
              :if={@help}
              class="mt-1 text-sm text-slate-500 dark:text-slate-500 leading-relaxed"
            >
              {@help}
            </p>
          </div>
        </div>
      </div>

      <%!-- Error messages --%>
      <div :if={@errors != []} class="ml-9">
        <p :for={error <- @errors} class="text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Liquid metal textarea component with enhanced styling.

  ## Examples

      <.liquid_textarea field={@form[:description]} label="Description" />
      <.liquid_textarea field={@form[:bio]} label="About you" placeholder="Tell us about yourself..." />
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :value, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :help, :string, default: nil
  attr :rows, :integer, default: 4
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_textarea(assigns) do
    # Extract field information
    assigns = assign(assigns, :id, assigns.field.id)
    assigns = assign(assigns, :name, assigns.field.name)
    # Use provided value or fallback to field value
    assigns = assign(assigns, :textarea_value, assigns.value || assigns.field.value || "")

    # Check for errors
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []
    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error(&1)))

    ~H"""
    <div phx-feedback-for={@name} class={["space-y-3", @class]}>
      <%!-- Label --%>
      <label
        for={@id}
        class="block text-sm font-medium text-slate-900 dark:text-slate-100 transition-colors duration-200 ease-out"
      >
        {@label}
      </label>

      <%!-- Textarea container with liquid effects and proper focus ring --%>
      <div class="group relative">
        <%!-- Enhanced liquid background effect on focus --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl">
        </div>

        <%!-- Enhanced shimmer effect on focus --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
        </div>

        <%!-- Focus ring with liquid metal styling --%>
        <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
        </div>

        <%!-- Secondary focus ring for better definition --%>
        <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
        </div>

        <%!-- Textarea input with enhanced contrast --%>
        <textarea
          id={@id}
          name={@name}
          rows={@rows}
          placeholder={@placeholder}
          class={[
            "relative block w-full rounded-xl px-4 py-3 text-slate-900 dark:text-slate-100",
            "bg-slate-50 dark:bg-slate-900 placeholder:text-slate-500 dark:placeholder:text-slate-400",
            "border-2 border-slate-200 dark:border-slate-700",
            "hover:border-slate-300 dark:hover:border-slate-600",
            "focus:border-emerald-500 dark:focus:border-emerald-400",
            "focus:outline-none focus:ring-0",
            "resize-none transition-all duration-200 ease-out",
            "sm:text-sm sm:leading-6",
            "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
            "focus:bg-white dark:focus:bg-slate-800",
            @errors != [] && "border-rose-400 focus:border-rose-400"
          ]}
          {@rest}
        ><%= Phoenix.HTML.Form.normalize_value("textarea", @textarea_value) %></textarea>
      </div>

      <%!-- Help text --%>
      <p
        :if={@help}
        class="text-sm text-slate-500 dark:text-slate-500 leading-relaxed"
      >
        {@help}
      </p>

      <%!-- Error messages --%>
      <div :if={@errors != []} class="space-y-1">
        <p :for={error <- @errors} class="text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </div>
    """
  end

  defp translate_error({msg, opts}) do
    # Use gettext for translation if available
    if count = opts[:count] do
      Gettext.dngettext(MossletWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MossletWeb.Gettext, "errors", msg, opts)
    end
  end

  defp translate_error(msg), do: msg

  @doc """
  Liquid metal text input component with enhanced styling.

  ## Examples

      <.liquid_input field={@form[:email]} label="Email" type="email" />
      <.liquid_input field={@form[:password]} label="Password" type="password" />
      <.liquid_input field={@form[:name]} label="Full Name" placeholder="Enter your name..." />
      <.liquid_input field={@form[:id]} type="hidden" value="123" />
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :type, :string, default: "text"
  attr :value, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :help, :string, default: nil
  attr :required, :boolean, default: false
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_input(assigns) do
    # Extract field information
    assigns = assign(assigns, :id, assigns.field.id)
    assigns = assign(assigns, :name, assigns.field.name)
    # Use provided value or fallback to field value
    assigns = assign(assigns, :input_value, assigns.value || assigns.field.value || "")

    # Check for errors
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []
    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error(&1)))

    ~H"""
    <div phx-feedback-for={@name} class={["space-y-3", @class]}>
      <%!-- Label --%>
      <label
        for={@id}
        class="block text-sm font-medium text-slate-900 dark:text-slate-100 transition-colors duration-200 ease-out"
      >
        {@label}
        <span :if={@required} class="text-rose-500 ml-1">*</span>
      </label>

      <%!-- Input container with liquid effects and proper focus ring --%>
      <div class="group relative">
        <%!-- Enhanced liquid background effect on focus --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl">
        </div>

        <%!-- Enhanced shimmer effect on focus --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
        </div>

        <%!-- Focus ring with liquid metal styling --%>
        <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
        </div>

        <%!-- Secondary focus ring for better definition --%>
        <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
        </div>

        <%!-- Input field with enhanced contrast --%>
        <input
          type={@type}
          id={@id}
          name={@name}
          value={@input_value}
          placeholder={@placeholder}
          required={@required}
          class={[
            "relative block w-full rounded-xl px-4 py-3 text-slate-900 dark:text-slate-100",
            "bg-slate-50 dark:bg-slate-900 placeholder:text-slate-500 dark:placeholder:text-slate-400",
            "border-2 border-slate-200 dark:border-slate-700",
            "hover:border-slate-300 dark:hover:border-slate-600",
            "focus:border-emerald-500 dark:focus:border-emerald-400",
            "focus:outline-none focus:ring-0",
            "transition-all duration-200 ease-out",
            "sm:text-sm sm:leading-6",
            "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
            "focus:bg-white dark:focus:bg-slate-800",
            @errors != [] && "border-rose-400 focus:border-rose-400"
          ]}
          {@rest}
        />
      </div>

      <%!-- Help text --%>
      <p
        :if={@help}
        class="text-sm text-slate-500 dark:text-slate-500 leading-relaxed"
      >
        {@help}
      </p>

      <%!-- Error messages --%>
      <div :if={@errors != []} class="space-y-1">
        <p :for={error <- @errors} class="text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Liquid metal select component with enhanced styling.

  ## Examples

      <.liquid_select field={@form[:country]} label="Country" options={["US", "CA", "UK"]} />
      <.liquid_select field={@form[:category]} label="Category" options={@categories} prompt="Choose a category" />
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :prompt, :string, default: nil
  attr :help, :string, default: nil
  attr :required, :boolean, default: false
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_select(assigns) do
    # Extract field information
    assigns = assign(assigns, :id, assigns.field.id)
    assigns = assign(assigns, :name, assigns.field.name)
    assigns = assign(assigns, :value, assigns.field.value)

    # Check for errors
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []
    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error(&1)))

    ~H"""
    <div phx-feedback-for={@name} class={["space-y-3", @class]}>
      <%!-- Label --%>
      <label
        for={@id}
        class="block text-sm font-medium text-slate-900 dark:text-slate-100 transition-colors duration-200 ease-out"
      >
        {@label}
        <span :if={@required} class="text-rose-500 ml-1">*</span>
      </label>

      <%!-- Select container with liquid effects and proper focus ring --%>
      <div class="group relative">
        <%!-- Enhanced liquid background effect on focus --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl">
        </div>

        <%!-- Enhanced shimmer effect on focus --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
        </div>

        <%!-- Focus ring with liquid metal styling --%>
        <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
        </div>

        <%!-- Secondary focus ring for better definition --%>
        <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
        </div>

        <%!-- Select field with enhanced contrast --%>
        <select
          id={@id}
          name={@name}
          class={[
            "relative block w-full rounded-xl px-4 py-3 pr-10 text-slate-900 dark:text-slate-100",
            "bg-slate-50 dark:bg-slate-900",
            "border-2 border-slate-200 dark:border-slate-700",
            "hover:border-slate-300 dark:hover:border-slate-600",
            "focus:border-emerald-500 dark:focus:border-emerald-400",
            "focus:outline-none focus:ring-0",
            "transition-all duration-200 ease-out",
            "sm:text-sm sm:leading-6",
            "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
            "focus:bg-white dark:focus:bg-slate-800",
            "appearance-none cursor-pointer",
            @errors != [] && "border-rose-400 focus:border-rose-400"
          ]}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          <option :for={option <- @options} value={option} selected={option == @value}>
            {if is_atom(option), do: String.capitalize(to_string(option)), else: option}
          </option>
        </select>

        <%!-- Custom dropdown arrow with liquid styling --%>
        <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
          <svg
            class="h-5 w-5 text-slate-400 dark:text-slate-500 group-focus-within:text-emerald-500 dark:group-focus-within:text-emerald-400 transition-colors duration-200"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
      </div>

      <%!-- Help text --%>
      <p
        :if={@help}
        class="text-sm text-slate-500 dark:text-slate-500 leading-relaxed"
      >
        {@help}
      </p>

      <%!-- Error messages --%>
      <div :if={@errors != []} class="space-y-1">
        <p :for={error <- @errors} class="text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Custom liquid metal textarea component with amber color scheme for content warnings.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :placeholder, :string, default: ""
  attr :rows, :integer, default: 3
  attr :maxlength, :integer, default: nil
  attr :help, :string, default: nil
  attr :required, :boolean, default: false
  attr :color, :string, default: "amber"
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_textarea_custom(assigns) do
    # Extract field information
    assigns = assign(assigns, :id, assigns.field.id)
    assigns = assign(assigns, :name, assigns.field.name)
    # Use provided value or fallback to field value
    assigns = assign(assigns, :textarea_value, assigns.field.value || "")

    # Check for errors
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []
    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error(&1)))

    # Color-specific classes
    assigns = assign(assigns, :focus_colors, get_custom_focus_colors(assigns.color))

    ~H"""
    <div phx-feedback-for={@name} class={["space-y-3", @class]}>
      <%!-- Label --%>
      <label
        for={@id}
        class={[
          "block text-xs font-medium transition-colors duration-200 ease-out",
          @focus_colors.label
        ]}
      >
        {@label}
        <span :if={@required} class="text-rose-500 ml-1">*</span>
      </label>

      <%!-- Textarea container with custom color liquid effects --%>
      <div class="group relative">
        <%!-- Enhanced liquid background effect on focus --%>
        <div class={[
          "absolute inset-0 opacity-0 transition-all duration-300 ease-out group-focus-within:opacity-100 rounded-xl",
          @focus_colors.background
        ]}>
        </div>

        <%!-- Enhanced shimmer effect on focus --%>
        <div class={[
          "absolute inset-0 opacity-0 transition-all duration-700 ease-out group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl",
          @focus_colors.shimmer
        ]}>
        </div>

        <%!-- Focus ring with custom color --%>
        <div class={[
          "absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl group-focus-within:opacity-100 blur-sm",
          @focus_colors.focus_ring
        ]}>
        </div>

        <%!-- Secondary focus ring for better definition --%>
        <div class={[
          "absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 group-focus-within:opacity-100",
          @focus_colors.focus_border
        ]}>
        </div>

        <%!-- Textarea input with enhanced contrast --%>
        <textarea
          id={@id}
          name={@name}
          rows={@rows}
          maxlength={@maxlength}
          placeholder={@placeholder}
          class={[
            "relative block w-full rounded-xl px-4 py-3 text-slate-900 dark:text-slate-100",
            "bg-white dark:bg-slate-800 placeholder:text-slate-500 dark:placeholder:text-slate-400",
            @focus_colors.border,
            @focus_colors.hover_border,
            @focus_colors.focus_border_input,
            "focus:outline-none focus:ring-0",
            "resize-none transition-all duration-200 ease-out",
            "sm:text-sm sm:leading-6",
            "shadow-sm focus:shadow-lg",
            @focus_colors.focus_shadow,
            "focus:bg-white dark:focus:bg-slate-800",
            @errors != [] && "border-rose-400 focus:border-rose-400"
          ]}
          {@rest}
        ><%= Phoenix.HTML.Form.normalize_value("textarea", @textarea_value) %></textarea>
      </div>

      <%!-- Help text --%>
      <p
        :if={@help}
        class="text-sm text-slate-500 dark:text-slate-500 leading-relaxed"
      >
        {@help}
      </p>

      <%!-- Error messages --%>
      <div :if={@errors != []} class="space-y-1">
        <p :for={error <- @errors} class="text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Custom liquid metal select component with amber color scheme for content warnings.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :prompt, :string, default: nil
  attr :help, :string, default: nil
  attr :required, :boolean, default: false
  attr :color, :string, default: "amber"
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_select_custom(assigns) do
    # Extract field information
    assigns = assign(assigns, :id, assigns.field.id)
    assigns = assign(assigns, :name, assigns.field.name)
    assigns = assign(assigns, :value, assigns.field.value)

    # Check for errors
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []
    assigns = assign(assigns, :errors, Enum.map(errors, &translate_error(&1)))

    # Color-specific classes
    assigns = assign(assigns, :focus_colors, get_custom_focus_colors(assigns.color))

    ~H"""
    <div phx-feedback-for={@name} class={["space-y-3", @class]}>
      <%!-- Label --%>
      <label
        for={@id}
        class={[
          "block text-xs font-medium transition-colors duration-200 ease-out",
          @focus_colors.label
        ]}
      >
        {@label}
        <span :if={@required} class="text-rose-500 ml-1">*</span>
      </label>

      <%!-- Select container with custom color liquid effects --%>
      <div class="group relative">
        <%!-- Enhanced liquid background effect on focus --%>
        <div class={[
          "absolute inset-0 opacity-0 transition-all duration-300 ease-out group-focus-within:opacity-100 rounded-xl",
          @focus_colors.background
        ]}>
        </div>

        <%!-- Enhanced shimmer effect on focus --%>
        <div class={[
          "absolute inset-0 opacity-0 transition-all duration-700 ease-out group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl",
          @focus_colors.shimmer
        ]}>
        </div>

        <%!-- Focus ring with custom color --%>
        <div class={[
          "absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl group-focus-within:opacity-100 blur-sm",
          @focus_colors.focus_ring
        ]}>
        </div>

        <%!-- Secondary focus ring for better definition --%>
        <div class={[
          "absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 group-focus-within:opacity-100",
          @focus_colors.focus_border
        ]}>
        </div>

        <%!-- Select field with enhanced contrast --%>
        <select
          id={@id}
          name={@name}
          class={[
            "relative block w-full rounded-xl px-4 py-3 pr-10 text-slate-900 dark:text-slate-100",
            "bg-white dark:bg-slate-800",
            @focus_colors.border,
            @focus_colors.hover_border,
            @focus_colors.focus_border_input,
            "focus:outline-none focus:ring-0",
            "transition-all duration-200 ease-out",
            "sm:text-sm sm:leading-6",
            "shadow-sm focus:shadow-lg",
            @focus_colors.focus_shadow,
            "focus:bg-white dark:focus:bg-slate-800",
            "appearance-none cursor-pointer",
            @errors != [] && "border-rose-400 focus:border-rose-400"
          ]}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          <option :for={{label, value} <- @options} value={value} selected={value == @value}>
            {label}
          </option>
        </select>

        <%!-- Custom dropdown arrow with color-specific styling --%>
        <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
          <svg
            class={[
              "h-5 w-5 transition-colors duration-200",
              @focus_colors.arrow
            ]}
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
      </div>

      <%!-- Help text --%>
      <p
        :if={@help}
        class="text-sm text-slate-500 dark:text-slate-500 leading-relaxed"
      >
        {@help}
      </p>

      <%!-- Error messages --%>
      <div :if={@errors != []} class="space-y-1">
        <p :for={error <- @errors} class="text-sm text-rose-600 dark:text-rose-400">
          {error}
        </p>
      </div>
    </div>
    """
  end

  # Helper function to get custom focus colors for different color schemes
  defp get_custom_focus_colors("amber") do
    %{
      label: "text-amber-700 dark:text-amber-300",
      background:
        "bg-gradient-to-br from-amber-50/30 via-orange-50/40 to-amber-50/30 dark:from-amber-900/15 dark:via-orange-900/20 dark:to-amber-900/15",
      shimmer:
        "bg-gradient-to-r from-transparent via-amber-200/30 to-transparent dark:via-amber-400/15",
      focus_ring:
        "bg-gradient-to-r from-amber-500 via-orange-500 to-amber-500 dark:from-amber-400 dark:via-orange-400 dark:to-amber-400",
      focus_border: "border-amber-500 dark:border-amber-400",
      border: "border-2 border-amber-200 dark:border-amber-700",
      hover_border: "hover:border-amber-300 dark:hover:border-amber-600",
      focus_border_input: "focus:border-amber-500 dark:focus:border-amber-400",
      focus_shadow: "focus:shadow-amber-500/10",
      arrow:
        "text-slate-400 dark:text-slate-500 group-focus-within:text-amber-500 dark:group-focus-within:text-amber-400"
    }
  end

  defp get_custom_focus_colors("emerald") do
    %{
      label: "text-slate-900 dark:text-slate-100",
      background:
        "bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15",
      shimmer:
        "bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15",
      focus_ring:
        "bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400",
      focus_border: "border-emerald-500 dark:border-emerald-400",
      border: "border-2 border-slate-200 dark:border-slate-700",
      hover_border: "hover:border-slate-300 dark:hover:border-slate-600",
      focus_border_input: "focus:border-emerald-500 dark:focus:border-emerald-400",
      focus_shadow: "focus:shadow-emerald-500/10",
      arrow:
        "text-slate-400 dark:text-slate-500 group-focus-within:text-emerald-500 dark:group-focus-within:text-emerald-400"
    }
  end

  defp get_custom_focus_colors("teal") do
    %{
      label: "text-slate-900 dark:text-slate-100",
      background:
        "bg-gradient-to-br from-teal-50/30 via-teal-50/40 to-teal-50/30 dark:from-teal-900/15 dark:via-teal-900/20 dark:to-teal-900/15",
      shimmer:
        "bg-gradient-to-r from-transparent via-teal-200/30 to-transparent dark:via-teal-400/15",
      focus_ring:
        "bg-gradient-to-r from-teal-500 via-teal-500 to-teal-500 dark:from-teal-400 dark:via-teal-400 dark:to-teal-400",
      focus_border: "border-teal-500 dark:border-teal-400",
      border: "border-2 border-slate-200 dark:border-slate-700",
      hover_border: "hover:border-slate-300 dark:hover:border-slate-600",
      focus_border_input: "focus:border-teal-500 dark:focus:border-teal-400",
      focus_shadow: "focus:shadow-teal-500/10",
      arrow:
        "text-slate-400 dark:text-slate-500 group-focus-within:text-teal-500 dark:group-focus-within:text-teal-400"
    }
  end

  # Fallback to emerald for unknown colors
  defp get_custom_focus_colors(_), do: get_custom_focus_colors("emerald")

  # Private helper functions for badges
  defp badge_size_classes("xs"), do: "px-2 py-0.5 text-xs rounded-md"
  defp badge_size_classes("sm"), do: "px-2.5 py-0.5 text-xs rounded-lg"
  defp badge_size_classes("md"), do: "px-3 py-1 text-sm rounded-lg"
  defp badge_size_classes("lg"), do: "px-4 py-1.5 text-base rounded-xl"

  defp badge_variant_classes("soft", color) do
    [
      "bg-gradient-to-r shadow-sm",
      badge_soft_color_classes(color)
    ]
  end

  defp badge_variant_classes("solid", color) do
    [
      "text-white shadow-sm",
      badge_solid_color_classes(color)
    ]
  end

  defp badge_variant_classes("outline", color) do
    [
      "border-2 bg-white dark:bg-slate-800 shadow-sm",
      badge_outline_color_classes(color)
    ]
  end

  # Soft variant color classes with liquid metal gradients (improved contrast)
  defp badge_soft_color_classes("slate"),
    do:
      "from-slate-100 to-slate-200 text-slate-800 dark:from-slate-700 dark:to-slate-600 dark:text-slate-200 border border-slate-300 dark:border-slate-600"

  defp badge_soft_color_classes("teal"),
    do:
      "from-teal-100 to-emerald-200 text-teal-800 dark:from-teal-800 dark:to-emerald-700 dark:text-teal-200 border border-teal-300 dark:border-teal-600"

  defp badge_soft_color_classes("emerald"),
    do:
      "from-emerald-100 to-teal-200 text-emerald-800 dark:from-emerald-800 dark:to-teal-700 dark:text-emerald-200 border border-emerald-300 dark:border-emerald-600"

  defp badge_soft_color_classes("blue"),
    do:
      "from-blue-100 to-cyan-200 text-blue-800 dark:from-blue-800 dark:to-cyan-700 dark:text-blue-200 border border-blue-300 dark:border-blue-600"

  defp badge_soft_color_classes("cyan"),
    do:
      "from-cyan-100 to-blue-200 text-cyan-800 dark:from-cyan-800 dark:to-blue-700 dark:text-cyan-200 border border-cyan-300 dark:border-cyan-600"

  defp badge_soft_color_classes("purple"),
    do:
      "from-purple-100 to-violet-200 text-purple-800 dark:from-purple-800 dark:to-violet-700 dark:text-purple-200 border border-purple-300 dark:border-purple-600"

  defp badge_soft_color_classes("violet"),
    do:
      "from-violet-100 to-purple-200 text-violet-800 dark:from-violet-800 dark:to-purple-700 dark:text-violet-200 border border-violet-300 dark:border-violet-600"

  defp badge_soft_color_classes("amber"),
    do:
      "from-amber-100 to-yellow-200 text-amber-800 dark:from-amber-800 dark:to-yellow-700 dark:text-amber-200 border border-amber-300 dark:border-amber-600"

  defp badge_soft_color_classes("orange"),
    do:
      "from-orange-100 to-red-200 text-orange-800 dark:from-orange-800 dark:to-red-700 dark:text-orange-200 border border-orange-300 dark:border-orange-600"

  defp badge_soft_color_classes("rose"),
    do:
      "from-rose-100 to-pink-200 text-rose-800 dark:from-rose-800 dark:to-pink-700 dark:text-rose-200 border border-rose-300 dark:border-rose-600"

  defp badge_soft_color_classes("pink"),
    do:
      "from-pink-100 to-rose-200 text-pink-800 dark:from-pink-800 dark:to-rose-700 dark:text-pink-200 border border-pink-300 dark:border-pink-600"

  defp badge_soft_color_classes("indigo"),
    do:
      "from-indigo-100 to-blue-200 text-indigo-800 dark:from-indigo-800 dark:to-blue-700 dark:text-indigo-200 border border-indigo-300 dark:border-indigo-600"

  # Solid variant color classes with liquid metal gradients
  defp badge_solid_color_classes("slate"), do: "bg-gradient-to-r from-slate-500 to-slate-600"
  defp badge_solid_color_classes("teal"), do: "bg-gradient-to-r from-teal-500 to-emerald-500"
  defp badge_solid_color_classes("emerald"), do: "bg-gradient-to-r from-emerald-500 to-teal-500"
  defp badge_solid_color_classes("blue"), do: "bg-gradient-to-r from-blue-500 to-cyan-500"
  defp badge_solid_color_classes("cyan"), do: "bg-gradient-to-r from-cyan-500 to-blue-500"
  defp badge_solid_color_classes("purple"), do: "bg-gradient-to-r from-purple-500 to-violet-500"
  defp badge_solid_color_classes("violet"), do: "bg-gradient-to-r from-violet-500 to-purple-500"
  defp badge_solid_color_classes("amber"), do: "bg-gradient-to-r from-amber-500 to-orange-500"
  defp badge_solid_color_classes("orange"), do: "bg-gradient-to-r from-orange-500 to-amber-500"
  defp badge_solid_color_classes("rose"), do: "bg-gradient-to-r from-rose-500 to-pink-500"
  defp badge_solid_color_classes("pink"), do: "bg-gradient-to-r from-pink-500 to-rose-500"
  defp badge_solid_color_classes("indigo"), do: "bg-gradient-to-r from-indigo-500 to-blue-500"

  # Outline variant color classes
  defp badge_outline_color_classes("slate"),
    do: "border-slate-300 text-slate-700 dark:border-slate-600 dark:text-slate-300"

  defp badge_outline_color_classes("teal"),
    do: "border-teal-300 text-teal-700 dark:border-teal-600 dark:text-teal-300"

  defp badge_outline_color_classes("emerald"),
    do: "border-emerald-300 text-emerald-700 dark:border-emerald-600 dark:text-emerald-300"

  defp badge_outline_color_classes("blue"),
    do: "border-blue-300 text-blue-700 dark:border-blue-600 dark:text-blue-300"

  defp badge_outline_color_classes("cyan"),
    do: "border-cyan-300 text-cyan-700 dark:border-cyan-600 dark:text-cyan-300"

  defp badge_outline_color_classes("purple"),
    do: "border-purple-300 text-purple-700 dark:border-purple-600 dark:text-purple-300"

  defp badge_outline_color_classes("violet"),
    do: "border-violet-300 text-violet-700 dark:border-violet-600 dark:text-violet-300"

  defp badge_outline_color_classes("amber"),
    do: "border-amber-300 text-amber-700 dark:border-amber-600 dark:text-amber-300"

  defp badge_outline_color_classes("orange"),
    do: "border-orange-300 text-orange-700 dark:border-orange-600 dark:text-orange-300"

  defp badge_outline_color_classes("rose"),
    do: "border-rose-300 text-rose-700 dark:border-rose-600 dark:text-rose-300"

  defp badge_outline_color_classes("pink"),
    do: "border-pink-300 text-pink-700 dark:border-pink-600 dark:text-pink-300"

  defp badge_outline_color_classes("indigo"),
    do: "border-indigo-300 text-indigo-700 dark:border-indigo-600 dark:text-indigo-300"

  # Import the phx_icon component
  defp phx_icon(assigns) do
    MossletWeb.CoreComponents.phx_icon(assigns)
  end

  # Icon animation patterns based on icon semantics
  defp icon_animation_classes("hero-arrow-right"), do: "group-hover:translate-x-1"
  defp icon_animation_classes("hero-arrow-left"), do: "group-hover:-translate-x-1"
  defp icon_animation_classes("hero-arrow-up"), do: "group-hover:-translate-y-1"
  defp icon_animation_classes("hero-arrow-down"), do: "group-hover:translate-y-1"

  defp icon_animation_classes("hero-paper-airplane"),
    do: "group-hover:translate-x-1 group-hover:-translate-y-0.5"

  defp icon_animation_classes("hero-plus"), do: "group-hover:scale-110"
  defp icon_animation_classes("hero-trash"), do: "group-hover:scale-110"
  defp icon_animation_classes("hero-shield-check"), do: "group-hover:scale-110"
  defp icon_animation_classes("hero-user-plus"), do: "group-hover:scale-110"
  defp icon_animation_classes("hero-key"), do: "group-hover:scale-110"
  defp icon_animation_classes("hero-arrow-left-on-rectangle"), do: "group-hover:-translate-x-1"
  # Default for other icons
  defp icon_animation_classes(_), do: "group-hover:scale-105"

  # Modal size classes with mobile-first responsive approach
  defp modal_size_classes("sm"), do: "w-full max-w-sm sm:max-w-md"
  defp modal_size_classes("md"), do: "w-full max-w-lg sm:max-w-xl"
  defp modal_size_classes("lg"), do: "w-full max-w-xl sm:max-w-2xl lg:max-w-3xl"
  defp modal_size_classes("xl"), do: "w-full max-w-2xl sm:max-w-3xl lg:max-w-5xl"
  # fallback
  defp modal_size_classes(_), do: "w-full max-w-lg sm:max-w-xl"

  @doc """
  Liquid metal tracking indicator component for privacy/tracking status.

  ## Examples

      <.liquid_tracking_indicator status="minimal">Minimal</.liquid_tracking_indicator>
      <.liquid_tracking_indicator status="extensive">Extensive</.liquid_tracking_indicator>
      <.liquid_tracking_indicator status="varies">Varies</.liquid_tracking_indicator>
      <.liquid_tracking_indicator status="none">None</.liquid_tracking_indicator>
  """
  attr :status, :string,
    required: true,
    values: ~w(none minimal extensive varies active moderate purple orange limited)

  attr :class, :any, default: ""
  attr :size, :string, default: "sm", values: ~w(xs sm md)
  slot :inner_block, required: true

  def liquid_tracking_indicator(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-x-2",
      @class
    ]}>
      <div class={[
        "relative overflow-hidden transition-all duration-300 ease-out transform-gpu",
        tracking_indicator_size_classes(@size),
        tracking_indicator_bg_classes(@status)
      ]}>
        <%!-- Liquid background gradient --%>
        <div class={[
          "absolute inset-0 transition-all duration-500 ease-out",
          tracking_indicator_liquid_bg_classes(@status)
        ]}>
        </div>

        <%!-- Shimmer effect for active indicators --%>
        <div
          :if={@status in ["extensive", "active"]}
          class={[
            "absolute inset-0 transition-all duration-1000 ease-out animate-pulse",
            tracking_indicator_shimmer_classes(@status)
          ]}
        >
        </div>

        <%!-- Status dot --%>
        <div class={[
          "relative rounded-full transition-all duration-200 ease-out",
          tracking_indicator_dot_size_classes(@size),
          tracking_indicator_dot_classes(@status)
        ]}>
        </div>
      </div>

      <span class={[
        "font-medium transition-all duration-200 ease-out",
        tracking_indicator_text_size_classes(@size),
        tracking_indicator_text_classes(@status)
      ]}>
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  # Size classes for the indicator container
  defp tracking_indicator_size_classes("xs"), do: "flex-none rounded-full w-4 h-4 p-0.5"
  defp tracking_indicator_size_classes("sm"), do: "flex-none rounded-full w-5 h-5 p-1"
  defp tracking_indicator_size_classes("md"), do: "flex-none rounded-full w-6 h-6 p-1.5"

  # Background classes for the indicator container
  defp tracking_indicator_bg_classes("none"), do: "bg-emerald-500/20"
  defp tracking_indicator_bg_classes("minimal"), do: "bg-emerald-500/20"
  defp tracking_indicator_bg_classes("extensive"), do: "bg-rose-500/20"
  defp tracking_indicator_bg_classes("active"), do: "bg-rose-500/20"
  defp tracking_indicator_bg_classes("varies"), do: "bg-amber-500/20"
  defp tracking_indicator_bg_classes("moderate"), do: "bg-amber-500/20"
  defp tracking_indicator_bg_classes("purple"), do: "bg-purple-500/20"
  defp tracking_indicator_bg_classes("orange"), do: "bg-orange-500/20"
  defp tracking_indicator_bg_classes("limited"), do: "bg-amber-500/20"

  # Liquid background gradients
  defp tracking_indicator_liquid_bg_classes("none"),
    do:
      "bg-gradient-to-br from-emerald-50/60 via-teal-50/80 to-emerald-50/60 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15"

  defp tracking_indicator_liquid_bg_classes("minimal"),
    do:
      "bg-gradient-to-br from-emerald-50/60 via-teal-50/80 to-emerald-50/60 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15"

  defp tracking_indicator_liquid_bg_classes("extensive"),
    do:
      "bg-gradient-to-br from-rose-50/60 via-pink-50/80 to-rose-50/60 dark:from-rose-900/15 dark:via-pink-900/20 dark:to-rose-900/15"

  defp tracking_indicator_liquid_bg_classes("active"),
    do:
      "bg-gradient-to-br from-rose-50/60 via-pink-50/80 to-rose-50/60 dark:from-rose-900/15 dark:via-pink-900/20 dark:to-rose-900/15"

  defp tracking_indicator_liquid_bg_classes("varies"),
    do:
      "bg-gradient-to-br from-amber-50/60 via-orange-50/80 to-amber-50/60 dark:from-amber-900/15 dark:via-orange-900/20 dark:to-amber-900/15"

  defp tracking_indicator_liquid_bg_classes("moderate"),
    do:
      "bg-gradient-to-br from-amber-50/60 via-orange-50/80 to-amber-50/60 dark:from-amber-900/15 dark:via-orange-900/20 dark:to-amber-900/15"

  defp tracking_indicator_liquid_bg_classes("orange"),
    do:
      "bg-gradient-to-br from-orange-50/60 via-amber-50/80 to-orange-50/60 dark:from-orange-900/15 dark:via-amber-900/20 dark:to-orange-900/15"

  defp tracking_indicator_liquid_bg_classes("limited"),
    do:
      "bg-gradient-to-br from-amber-50/60 via-yellow-50/80 to-amber-50/60 dark:from-amber-900/15 dark:via-yellow-900/20 dark:to-amber-900/15"

  defp tracking_indicator_liquid_bg_classes("purple"),
    do:
      "bg-gradient-to-br from-purple-50/60 via-violet-50/80 to-purple-50/60 dark:from-purple-900/15 dark:via-violet-900/20 dark:to-purple-900/15"

  # Shimmer effects for animated indicators
  defp tracking_indicator_shimmer_classes("extensive"),
    do: "bg-gradient-to-r from-transparent via-rose-200/40 to-transparent dark:via-rose-400/20"

  defp tracking_indicator_shimmer_classes("active"),
    do: "bg-gradient-to-r from-transparent via-rose-200/40 to-transparent dark:via-rose-400/20"

  defp tracking_indicator_shimmer_classes(_), do: ""

  # Dot size classes
  defp tracking_indicator_dot_size_classes("xs"), do: "h-2 w-2"
  defp tracking_indicator_dot_size_classes("sm"), do: "h-2 w-2"
  defp tracking_indicator_dot_size_classes("md"), do: "h-3 w-3"

  # Dot color classes with liquid metal gradients
  defp tracking_indicator_dot_classes("none"),
    do: "bg-gradient-to-br from-emerald-400 to-teal-500"

  defp tracking_indicator_dot_classes("minimal"),
    do: "bg-gradient-to-br from-emerald-400 to-teal-500"

  defp tracking_indicator_dot_classes("extensive"),
    do: "bg-gradient-to-br from-rose-400 to-pink-500"

  defp tracking_indicator_dot_classes("active"), do: "bg-gradient-to-br from-rose-400 to-pink-500"

  defp tracking_indicator_dot_classes("varies"),
    do: "bg-gradient-to-br from-amber-400 to-orange-500"

  defp tracking_indicator_dot_classes("moderate"),
    do: "bg-gradient-to-br from-amber-400 to-orange-500"

  defp tracking_indicator_dot_classes("purple"),
    do: "bg-gradient-to-br from-purple-400 to-violet-500"

  defp tracking_indicator_dot_classes("orange"),
    do: "bg-gradient-to-br from-orange-400 to-amber-500"

  defp tracking_indicator_dot_classes("limited"),
    do: "bg-gradient-to-br from-amber-400 to-yellow-500"

  # Text size classes
  defp tracking_indicator_text_size_classes("xs"), do: "text-xs"
  defp tracking_indicator_text_size_classes("sm"), do: "text-sm"
  defp tracking_indicator_text_size_classes("md"), do: "text-base"

  # Text color classes
  defp tracking_indicator_text_classes("none"), do: "text-emerald-600 dark:text-emerald-400"
  defp tracking_indicator_text_classes("minimal"), do: "text-emerald-600 dark:text-emerald-400"
  defp tracking_indicator_text_classes("extensive"), do: "text-rose-600 dark:text-rose-400"
  defp tracking_indicator_text_classes("active"), do: "text-rose-600 dark:text-rose-400"
  defp tracking_indicator_text_classes("varies"), do: "text-amber-600 dark:text-amber-400"
  defp tracking_indicator_text_classes("moderate"), do: "text-amber-600 dark:text-amber-400"
  defp tracking_indicator_text_classes("purple"), do: "text-purple-600 dark:text-purple-400"
  defp tracking_indicator_text_classes("orange"), do: "text-orange-600 dark:text-orange-400"
  defp tracking_indicator_text_classes("limited"), do: "text-amber-600 dark:text-amber-400"

  @doc """
  Liquid metal avatar component with enhanced styling and status indicators.

  ## Examples

      <.liquid_avatar src="/path/to/avatar.jpg" name="John Doe" size="md" />
      <.liquid_avatar src="/path/to/avatar.jpg" name="Jane" size="lg" status="online" />
      <.liquid_avatar name="Anonymous" size="sm" verified={true} />
  """
  attr :src, :string, default: nil
  attr :name, :string, required: true
  attr :size, :string, default: "md", values: ~w(xs sm md lg xl)
  attr :status, :string, default: "offline", values: ~w(online calm away busy offline)
  attr :verified, :boolean, default: false
  attr :class, :any, default: ""
  attr :clickable, :boolean, default: false
  attr :rest, :global

  def liquid_avatar(assigns) do
    assigns = assign(assigns, :avatar_url, assigns.src || "/images/logo.svg")

    ~H"""
    <div
      class={[
        "relative flex-shrink-0",
        avatar_container_size_classes(@size),
        if(@clickable, do: "cursor-pointer group", else: ""),
        @class
      ]}
      {@rest}
    >
      <%!-- Main avatar container with liquid styling --%>
      <div class={[
        "relative overflow-hidden transition-all duration-300 ease-out transform-gpu",
        avatar_size_classes(@size),
        "rounded-xl",
        if(@clickable, do: "group-hover:scale-105 group-active:scale-95", else: "")
      ]}>
        <%!-- Liquid background gradient --%>
        <div class={[
          "absolute inset-0 transition-all duration-300 ease-out",
          "bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100",
          "dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40",
          if(@clickable,
            do:
              "group-hover:from-teal-200 group-hover:via-emerald-100 group-hover:to-cyan-200 dark:group-hover:from-teal-800/50 dark:group-hover:via-emerald-800/40 dark:group-hover:to-cyan-800/50",
            else: ""
          )
        ]}>
        </div>

        <%!-- Shimmer effect on hover (if clickable) --%>
        <div
          :if={@clickable}
          class={[
            "absolute inset-0 opacity-0 transition-all duration-500 ease-out",
            "bg-gradient-to-r from-transparent via-emerald-200/40 to-transparent",
            "dark:via-emerald-400/20",
            "group-hover:opacity-100 group-hover:translate-x-full -translate-x-full"
          ]}
        >
        </div>

        <%!-- Avatar image --%>
        <img
          src={@avatar_url}
          alt={"#{@name} avatar"}
          class="relative w-full h-full object-cover"
          loading="lazy"
        />

        <%!-- Verified badge --%>
        <div
          :if={@verified}
          class={[
            "absolute -bottom-0.5 -right-0.5 rounded-full p-1",
            "bg-white dark:bg-slate-800 border-2 border-white dark:border-slate-800",
            "shadow-lg"
          ]}
        >
          <.phx_icon
            name="hero-check-badge"
            class="h-3 w-3 text-emerald-500"
          />
        </div>
      </div>

      <%!-- Status indicator --%>
      <div
        :if={@status && @status != "offline"}
        class={[
          "absolute -bottom-0.5 -right-0.5 rounded-full p-1",
          "bg-white dark:bg-slate-800 border-2 border-white dark:border-slate-800",
          "shadow-lg"
        ]}
      >
        <div class={[
          "rounded-full transition-all duration-300 ease-out",
          avatar_status_size_classes(@size),
          avatar_status_color_classes(@status)
        ]}>
          <%!-- Pulse animation for online/calm status --%>
          <div
            :if={@status in ["online", "calm"]}
            class={[
              "absolute inset-0 rounded-full animate-ping opacity-75",
              avatar_status_ping_classes(@status)
            ]}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline infinite scroll indicator with transparency about remaining content.
  Simple, elegant design that shows exactly what will happen on click.
  """
  attr :remaining_count, :integer, default: 0
  attr :load_count, :integer, default: 10
  attr :loading, :boolean, default: false
  attr :tab_color, :string, default: "slate"
  attr :class, :any, default: ""
  attr :rest, :global, include: ~w(phx-click)

  def liquid_timeline_scroll_indicator(assigns) do
    # Define color variants based on tab
    assigns =
      assign(assigns, :color_classes, get_tab_color_classes(assigns.tab_color))

    ~H"""
    <div class={[
      "text-center py-8",
      @class
    ]}>
      <%!-- Loading state --%>
      <div
        :if={@loading}
        class="inline-flex items-center gap-3 px-6 py-3 rounded-xl bg-slate-50/80 dark:bg-slate-800/80 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 text-slate-600 dark:text-slate-400"
      >
        <div class={["w-2 h-2 rounded-full animate-pulse", @color_classes.indicator]}></div>
        <span class="text-sm font-medium">Loading more posts...</span>
      </div>

      <%!-- Load more button with tab-specific colors and clickable --%>
      <button
        :if={!@loading && @remaining_count > 0}
        class={[
          "inline-flex items-center gap-3 px-6 py-3 rounded-xl backdrop-blur-sm transition-all duration-200 ease-out cursor-pointer group text-sm font-medium",
          @color_classes.button
        ]}
        {@rest}
      >
        <div class={["w-2 h-2 rounded-full animate-pulse", @color_classes.indicator]}></div>
        <span>
          Load {@load_count} more posts ({@remaining_count} remaining)
        </span>
      </button>
    </div>
    """
  end

  # Helper function to get tab color for the load more button
  def get_tab_color(active_tab) do
    case active_tab do
      "home" -> "emerald"
      # This maps to blue-cyan gradient
      "connections" -> "teal"
      # This maps to purple-violet gradient
      "groups" -> "blue"
      # This maps to amber-orange gradient
      "bookmarks" -> "purple"
      # This maps to indigo-blue gradient
      "discover" -> "orange"
      _ -> "slate"
    end
  end

  # Helper function to get color classes for different tabs
  def get_tab_color_classes(tab_color) do
    case tab_color do
      "emerald" ->
        %{
          button:
            "bg-gradient-to-r from-emerald-500 to-teal-500 text-white shadow-md hover:from-emerald-600 hover:to-teal-600",
          indicator: "bg-white/80"
        }

      "teal" ->
        %{
          button:
            "bg-gradient-to-r from-blue-500 to-cyan-500 text-white shadow-md hover:from-blue-600 hover:to-cyan-600",
          indicator: "bg-white/80"
        }

      "blue" ->
        %{
          button:
            "bg-gradient-to-r from-purple-500 to-violet-500 text-white shadow-md hover:from-purple-600 hover:to-violet-600",
          indicator: "bg-white/80"
        }

      "purple" ->
        %{
          button:
            "bg-gradient-to-r from-amber-500 to-orange-500 text-white shadow-md hover:from-amber-600 hover:to-orange-600",
          indicator: "bg-white/80"
        }

      "orange" ->
        %{
          button:
            "bg-gradient-to-r from-indigo-500 to-blue-500 text-white shadow-md hover:from-indigo-600 hover:to-blue-600",
          indicator: "bg-white/80"
        }

      _ ->
        %{
          button:
            "bg-slate-50/80 dark:bg-slate-800/80 border-slate-200/60 dark:border-slate-700/60 text-slate-600 dark:text-slate-400 hover:bg-slate-100/80 dark:hover:bg-slate-700/80",
          indicator: "bg-gradient-to-r from-slate-400 to-slate-500"
        }
    end
  end

  @doc """
  Timeline realtime update indicator for PubSub notifications.
  Positioned below the topbar to avoid mobile sidebar collision.
  """
  attr :new_posts_count, :integer, default: 0
  attr :active_tab, :string, default: "home"
  attr :class, :any, default: ""

  def liquid_timeline_realtime_indicator(assigns) do
    # Define tab-specific icons and colors
    assigns = assign(assigns, :tab_icon, get_tab_icon(assigns.active_tab))

    assigns =
      assign(assigns, :color_classes, get_tab_color_classes(get_tab_color(assigns.active_tab)))

    ~H"""
    <div
      :if={@new_posts_count > 0}
      id="timeline-realtime-indicator"
      class={[
        "sticky top-20 z-20 text-center mb-4",
        @class
      ]}
    >
      <button
        class={[
          "group inline-flex items-center gap-3 px-4 py-2.5 rounded-full shadow-lg hover:shadow-xl transition-all duration-200 ease-out hover:scale-105 focus:outline-none focus:ring-2 focus:ring-offset-2",
          @color_classes.button
        ]}
        phx-click="scroll_to_top"
        title="Scroll to top of page"
      >
        <%!-- Gentle pulse indicator --%>
        <div class="relative">
          <div class={["w-2 h-2 rounded-full", @color_classes.indicator]}></div>
          <div class={[
            "absolute inset-0 w-2 h-2 rounded-full animate-ping opacity-75",
            @color_classes.indicator
          ]}>
          </div>
        </div>

        <%!-- Tab-specific icon --%>
        <.phx_icon
          name={@tab_icon}
          class="h-4 w-4 opacity-90"
        />

        <span class="text-sm font-medium">
          {@new_posts_count} unread post{if(@new_posts_count == 1, do: "", else: "s")}
        </span>
      </button>
    </div>
    """
  end

  # Helper function to get tab-specific icons
  defp get_tab_icon(tab) do
    case tab do
      "home" -> "hero-home"
      "connections" -> "hero-user-group"
      "groups" -> "hero-squares-2x2"
      "bookmarks" -> "hero-bookmark"
      "discover" -> "hero-globe-alt"
      _ -> "hero-home"
    end
  end

  @doc """
  Timeline composer with enhanced liquid metal avatar and calm design focus.
  """
  attr :user_name, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :placeholder, :string, default: "What's on your mind?"
  attr :character_limit, :integer, default: 500
  attr :privacy_level, :string, default: "connections", values: ~w(public connections private)
  attr :selector, :string, default: "connections"
  attr :form, :any, required: true
  attr :uploads, :any, default: nil
  attr :class, :any, default: ""
  attr :privacy_controls_expanded, :boolean, default: false
  attr :content_warning_enabled?, :boolean, default: false

  def liquid_timeline_composer_enhanced(assigns) do
    ~H"""
    <div class={[
      "relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
      "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
      "focus-within:border-emerald-500/60 dark:focus-within:border-emerald-400/60",
      "focus-within:shadow-xl focus-within:shadow-emerald-500/10",
      @class
    ]}>
      <%!-- Liquid background on focus --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/20 via-teal-50/10 to-cyan-50/20 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-cyan-900/10 focus-within:opacity-100">
      </div>

      <div class="relative p-6">
        <%!-- User section with enhanced liquid avatar --%>
        <div class="flex items-start gap-4 mb-4">
          <%!-- Enhanced liquid metal avatar --%>
          <.liquid_avatar
            src={@user_avatar}
            name={@user_name}
            size="md"
            status="calm"
          />

          <%!-- Compose area with character counter --%>
          <div class="flex-1 min-w-0">
            <div class="relative group">
              <%!-- Hidden fields required for post creation --%>
              <.phx_input
                field={@form[:user_id]}
                type="hidden"
                name={@form[:user_id].name}
                value={@form[:user_id].value}
              />
              <.phx_input
                field={@form[:username]}
                type="hidden"
                name={@form[:username].name}
                value={@form[:username].value}
              />
              <.phx_input
                field={@form[:visibility]}
                type="hidden"
                name={@form[:visibility].name}
                value={@selector}
              />

              <%!-- Custom textarea without phx_input wrapper to maintain our styling --%>
              <textarea
                id="new-timeline-composer-textarea"
                name={@form[:body].name}
                placeholder={@placeholder}
                rows="3"
                maxlength={@character_limit}
                class="w-full resize-none border-0 bg-transparent text-slate-900 dark:text-slate-100 placeholder:text-slate-500 dark:placeholder:text-slate-400 text-lg leading-relaxed focus:outline-none focus:ring-0"
                phx-hook="CharacterCounter"
                phx-debounce="500"
                data-limit={@character_limit}
                value={@form[:body].value}
              >{@form[:body].value}</textarea>

              <%!-- Character counter (shows when textarea has content) --%>
              <div
                class={[
                  "absolute bottom-2 right-2 transition-all duration-300 ease-out",
                  (@form[:body].value && String.trim(@form[:body].value) != "" && "opacity-100") ||
                    "opacity-0"
                ]}
                id={"char-counter-#{@character_limit}"}
              >
                <span class="text-xs text-slate-500 dark:text-slate-400 bg-white/95 dark:bg-slate-800/95 px-3 py-1.5 rounded-full backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg">
                  <span class="js-char-count">{String.length(@form[:body].value || "")}</span>/{@character_limit}
                </span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Photo upload preview section --%>
        <.liquid_photo_upload_preview :if={@uploads} uploads={@uploads} class="" />

        <%!-- Actions row with responsive layout --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between pt-4 border-t border-slate-200/50 dark:border-slate-700/50 gap-3 sm:gap-0">
          <%!-- Media and formatting actions --%>
          <div class="flex items-center gap-2">
            <%!-- Photo upload button --%>
            <label
              for={@uploads.photos.ref}
              id="photo-upload-trigger"
              class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group cursor-pointer"
              phx-hook="TippyHook"
              data-tippy-content="Add photos (JPG, PNG up to 10MB each)"
            >
              <.phx_icon
                name="hero-photo"
                class="h-5 w-5 transition-transform duration-200 group-hover:scale-110"
              />
            </label>

            <%!-- Hidden file input for photo uploads --%>
            <.live_file_input
              upload={@uploads.photos}
              class="hidden"
              accept="image/*"
            />

            <button
              id="liquid-timeline-composer-emoji-button"
              type="button"
              class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group"
              phx-hook="ComposerEmojiPicker"
              title="Add emoji"
            >
              <.phx_icon
                name="hero-face-smile"
                class="h-5 w-5 transition-transform duration-200 group-hover:scale-110"
              />
            </button>
            <%!-- Content warning toggle --%>
            <button
              id={
                if @content_warning_enabled?,
                  do: "remove-content-warning-composer-button",
                  else: "add-content-warning-composer-button"
              }
              type="button"
              class={[
                "p-2 rounded-lg transition-all duration-200 ease-out group",
                if(@content_warning_enabled?,
                  do:
                    "text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-900/30 border border-teal-200 dark:border-teal-700",
                  else:
                    "text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-teal-50/50 dark:hover:bg-teal-900/20"
                )
              ]}
              phx-hook="TippyHook"
              data-tippy-content={
                if @content_warning_enabled?,
                  do: "Remove content warning",
                  else: "Add content warning"
              }
              phx-click="composer_toggle_content_warning"
            >
              <.phx_icon
                name={
                  if @content_warning_enabled?, do: "hero-hand-raised-solid", else: "hero-hand-raised"
                }
                class={[
                  "h-5 w-5 transition-transform duration-200 group-hover:scale-110",
                  @content_warning_enabled? && "fill-current"
                ]}
              />
            </button>
          </div>

          <%!-- Privacy controls and post button with mobile-first layout --%>
          <div class="flex items-center justify-between sm:justify-end gap-3">
            <%!-- Hidden field for form data integrity --%>
            <input
              type="hidden"
              name={@form[:visibility].name}
              value={@selector}
              id="privacy-hidden-field"
            />

            <%!-- Enhanced privacy selector with progressive disclosure --%>
            <div
              id={"privacy-selector-#{@selector}"}
              class={[
                "relative inline-flex items-center gap-2 px-3 py-2.5 rounded-full text-sm",
                "bg-slate-100/80 dark:bg-slate-700/80 backdrop-blur-sm",
                "border border-slate-200/60 dark:border-slate-600/60",
                "hover:bg-slate-200/80 dark:hover:bg-slate-600/80",
                "transition-all duration-200 ease-out cursor-pointer group"
              ]}
              phx-click="toggle_privacy_controls"
              phx-hook="TippyHook"
              data-tippy-content="Click to expand privacy controls"
            >
              <.phx_icon
                name={privacy_icon(@selector)}
                class="h-4 w-4 text-slate-600 dark:text-slate-300 flex-shrink-0"
              />
              <span class="font-medium text-slate-700 dark:text-slate-200 privacy-label">
                {privacy_label(@selector)}
              </span>
              <%!-- Chevron indicates expandable --%>
              <.phx_icon
                name={if @privacy_controls_expanded, do: "hero-chevron-up", else: "hero-chevron-down"}
                class="h-3 w-3 text-slate-500 dark:text-slate-400 transition-transform duration-200 group-hover:scale-110"
              />
            </div>

            <%!-- Post button that submits the form --%>
            <.liquid_button
              size="md"
              type="submit"
              class="flex-shrink-0"
              phx-disable-with="Sharing..."
              disabled={true}
            >
              Share thoughtfully
            </.liquid_button>
          </div>
        </div>

        <%!-- Enhanced Privacy Controls Section (conditionally shown) --%>
        <%= if @privacy_controls_expanded do %>
          <div class="mt-4 animate-in slide-in-from-top-2 duration-300 ease-out">
            <.liquid_enhanced_privacy_controls
              form={@form}
              selector={@selector}
            />
          </div>
        <% end %>

        <%!-- Content Warning Section (conditionally shown) --%>
        <%= if @content_warning_enabled? do %>
          <div class="mt-4 p-4 rounded-xl bg-teal-50/50 dark:bg-teal-900/20 border border-teal-200/60 dark:border-teal-700/50">
            <div class="flex items-center gap-2 mb-3">
              <.phx_icon
                name="hero-hand-raised"
                class="h-4 w-4 text-teal-600 dark:text-teal-400"
              />
              <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
                Content Warning
              </span>
            </div>

            <div class="space-y-4">
              <%!-- Content warning text input using liquid metal component --%>
              <div class="relative">
                <%!-- Custom textarea matching main composer pattern exactly --%>
                <label
                  for={@form[:content_warning].id}
                  class="block text-xs font-medium text-teal-700 dark:text-teal-300 mb-2"
                >
                  Warning description
                </label>

                <div class="group relative">
                  <%!-- Liquid effects --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/30 via-orange-50/40 to-teal-50/30 dark:from-teal-900/15 dark:via-orange-900/20 dark:to-teal-900/15 group-focus-within:opacity-100 rounded-xl">
                  </div>
                  <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-teal-200/30 to-transparent dark:via-teal-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
                  </div>
                  <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-orange-500 to-teal-500 dark:from-teal-400 dark:via-orange-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
                  </div>
                  <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-teal-500 dark:border-teal-400 group-focus-within:opacity-100">
                  </div>

                  <%!-- Textarea with proper hook setup --%>
                  <textarea
                    id="content-warning-textarea"
                    name={@form[:content_warning].name}
                    placeholder="e.g., Discussion of mental health, sensitive content..."
                    rows="2"
                    maxlength="100"
                    class="w-full resize-none border-0 bg-transparent text-slate-900 dark:text-slate-100 placeholder:text-teal-600/70 dark:placeholder:text-teal-400/70 text-sm leading-relaxed focus:outline-none focus:ring-0 relative block rounded-xl px-4 py-3 bg-white dark:bg-slate-800 border-2 border-teal-200 dark:border-teal-700 hover:border-teal-300 dark:hover:border-teal-600 focus:border-teal-500 dark:focus:border-teal-400 transition-all duration-200 ease-out shadow-sm focus:shadow-lg focus:shadow-teal-500/10"
                    phx-hook="CharacterCounter"
                    phx-debounce="300"
                    data-limit="100"
                    value={@form[:content_warning].value}
                  >{@form[:content_warning].value}</textarea>
                </div>

                <%!-- Character counter with liquid metal styling --%>
                <%!-- Character counter with unique ID matching main composer pattern --%>
                <div
                  class={[
                    "absolute bottom-2 right-2 transition-all duration-300 ease-out",
                    (@form[:content_warning].value && String.trim(@form[:content_warning].value) != "" &&
                       "opacity-100") ||
                      "opacity-0"
                  ]}
                  id="char-counter-100"
                >
                  <span class="text-xs text-teal-600 dark:text-teal-400 bg-teal-50/95 dark:bg-teal-900/95 px-3 py-1.5 rounded-full backdrop-blur-sm border border-teal-200/60 dark:border-teal-700/60 shadow-lg">
                    <span class="js-char-count">{String.length(@form[:content_warning].value || "")}</span>/100
                  </span>
                </div>
              </div>

              <%!-- Content warning category dropdown using liquid metal component --%>
              <.liquid_select_custom
                field={@form[:content_warning_category]}
                label="Category (optional)"
                prompt="Select category..."
                color="teal"
                class="text-sm"
                options={[
                  {"Mental Health", "mental_health"},
                  {"Violence", "violence"},
                  {"Substance Use", "substance_use"},
                  {"Politics", "politics"},
                  {"Personal/Sensitive", "personal"},
                  {"Other", "other"}
                ]}
              />
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Privacy level selector for posts with responsive design.
  Now keeps full text and chevron on both mobile and desktop since we have good responsive spacing.
  """
  attr :selected, :string, default: "connections"
  attr :compact, :boolean, default: false
  attr :class, :any, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-privacy)

  def liquid_privacy_selector(assigns) do
    ~H"""
    <div
      id={"privacy-selector-#{@selected}"}
      class={[
        "relative inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
        "bg-slate-100/80 dark:bg-slate-700/80 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-600/60",
        "hover:bg-slate-200/80 dark:hover:bg-slate-600/80",
        "transition-all duration-200 ease-out cursor-pointer",
        @class
      ]}
      phx-hook="TippyHook"
      data-tippy-content="Click to toggle privacy level"
      {@rest}
    >
      <.phx_icon
        name={privacy_icon(@selected)}
        class="h-4 w-4 text-slate-600 dark:text-slate-300 flex-shrink-0"
      />
      <%!-- Keep text but remove chevron for cleaner toggle UI --%>
      <span class="font-medium text-slate-700 dark:text-slate-200">
        {privacy_label(@selected)}
      </span>
    </div>
    """
  end

  # Privacy helper functions
  # Helper function to humanize upload errors
  defp humanize_upload_error(:too_large), do: "File is too large (max 5MB)"
  defp humanize_upload_error(:too_many_files), do: "Too many files (max 4 photos)"
  defp humanize_upload_error(:not_accepted), do: "File type not supported (JPG, PNG only)"
  defp humanize_upload_error(error), do: "Upload error: #{error}"

  @doc """
  Liquid metal photo gallery component for timeline posts.
  Integrates with existing TrixContentPostHook and encrypted image system.
  """
  attr :post, :any, required: true
  attr :current_user, :any, required: true
  attr :class, :any, default: ""

  def liquid_post_photo_gallery(assigns) do
    ~H"""
    <div
      :if={photos?(@post.image_urls)}
      class={[
        "mt-4 overflow-hidden rounded-xl border border-slate-200/60 dark:border-slate-700/60",
        "bg-gradient-to-br from-slate-50/50 to-slate-100/30 dark:from-slate-800/50 dark:to-slate-900/30",
        @class
      ]}
    >
      <%!-- Photo gallery header --%>
      <div class="flex items-center justify-between p-3 border-b border-slate-200/50 dark:border-slate-700/50">
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-photo" class="h-4 w-4 text-slate-600 dark:text-slate-400" />
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {length(@post.image_urls)} {if length(@post.image_urls) == 1, do: "photo", else: "photos"}
          </span>
        </div>

        <%!-- Show photos button integrated with existing hook system --%>
        <button
          id={"post-#{@post.id}-show-photos-#{@current_user.id}"}
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-100 dark:hover:bg-emerald-900/40 hover:scale-105 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
          phx-click={
            JS.dispatch("mosslet:show-post-photos-#{@post.id}",
              to: "#post-body-#{@post.id}",
              detail: %{post_id: @post.id, user_id: @current_user.id}
            )
          }
          phx-hook="TippyHook"
          data-tippy-content="Decrypt and display photos"
        >
          <.phx_icon name="hero-eye" class="h-4 w-4" /> View photos
        </button>
      </div>

      <%!-- Photos will be decrypted and displayed here by TrixContentPostHook --%>
      <div
        id={"post-body-#{@post.id}"}
        phx-hook="TrixContentPostHook"
        class="photos-container p-3"
      >
        <%!-- Placeholder while photos load --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          <div
            :for={_image_url <- @post.image_urls}
            class="aspect-square bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-800 rounded-lg flex items-center justify-center animate-pulse"
          >
            <.phx_icon name="hero-photo" class="h-8 w-8 text-slate-400 dark:text-slate-500" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Enhanced photo upload preview with liquid metal styling for the composer.
  """
  attr :uploads, :any, required: true
  attr :class, :any, default: ""

  def liquid_photo_upload_preview(assigns) do
    ~H"""
    <div
      :if={@uploads && @uploads.photos && length(@uploads.photos.entries) > 0}
      class={[
        "mt-4 p-4 rounded-xl border border-slate-200/60 dark:border-slate-700/60",
        "bg-gradient-to-br from-emerald-50/30 to-teal-50/20 dark:from-emerald-900/10 dark:to-teal-900/5",
        @class
      ]}
    >
      <%!-- Upload preview header --%>
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <.phx_icon
            name="hero-cloud-arrow-up"
            class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
          />
          <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
            {length(@uploads.photos.entries)} {if length(@uploads.photos.entries) == 1,
              do: "photo",
              else: "photos"} ready
          </span>
        </div>

        <%!-- Progress indicator --%>
        <div class="text-xs text-emerald-600 dark:text-emerald-400 font-medium">
          {if Enum.all?(@uploads.photos.entries, &(&1.progress == 100)),
            do: "✓ Ready",
            else: "Uploading..."}
        </div>
      </div>

      <%!-- Photo preview grid --%>
      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
        <%= for entry <- @uploads.photos.entries do %>
          <div class="relative group overflow-hidden rounded-lg border border-emerald-200/60 dark:border-emerald-700/60 bg-white dark:bg-slate-800">
            <%!-- Photo preview --%>
            <.live_img_preview
              entry={entry}
              class="w-full h-24 object-cover transition-all duration-200 group-hover:scale-105"
            />

            <%!-- Upload progress overlay --%>
            <div
              :if={entry.progress < 100}
              class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent flex items-end justify-center pb-2"
            >
              <div class="text-center">
                <div class="w-6 h-6 border-2 border-white border-t-transparent rounded-full animate-spin mb-1 mx-auto">
                </div>
                <div class="text-xs text-white font-medium">{entry.progress}%</div>
              </div>
            </div>

            <%!-- Success indicator --%>
            <div
              :if={entry.progress == 100}
              class="absolute top-1 left-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center"
            >
              <.phx_icon name="hero-check" class="h-3 w-3 text-white" />
            </div>

            <%!-- Remove button --%>
            <button
              type="button"
              id={"remove-photo-#{entry.ref}"}
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              class="absolute top-1 right-1 w-6 h-6 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all duration-200 hover:scale-110"
              phx-hook="TippyHook"
              data-tippy-content="Remove photo"
            >
              <.phx_icon name="hero-x-mark" class="h-3 w-3" />
            </button>

            <%!-- Upload errors --%>
            <div
              :if={length(upload_errors(@uploads.photos, entry)) > 0}
              class="absolute inset-0 bg-red-500/90 flex items-center justify-center p-2"
            >
              <div class="text-center">
                <.phx_icon name="hero-exclamation-triangle" class="h-5 w-5 text-white mx-auto mb-1" />
                <div class="text-xs text-white font-medium">
                  <%= for error <- upload_errors(@uploads.photos, entry) do %>
                    <div>{humanize_upload_error(error)}</div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Upload errors for the upload config itself --%>
      <div
        :if={length(upload_errors(@uploads.photos)) > 0}
        class="mt-3 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg"
      >
        <div class="flex items-start gap-2">
          <.phx_icon
            name="hero-exclamation-triangle"
            class="h-4 w-4 text-red-600 dark:text-red-400 mt-0.5 flex-shrink-0"
          />
          <div class="text-sm text-red-700 dark:text-red-300">
            <%= for error <- upload_errors(@uploads.photos) do %>
              <div>{humanize_upload_error(error)}</div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp privacy_icon("public"), do: "hero-globe-alt"
  defp privacy_icon("connections"), do: "hero-user-group"
  defp privacy_icon("private"), do: "hero-lock-closed"

  defp privacy_label("public"), do: "Public"
  defp privacy_label("connections"), do: "Connections"
  defp privacy_label("private"), do: "Private"

  # Avatar size helper functions
  defp avatar_container_size_classes("xs"), do: "w-6 h-6"
  defp avatar_container_size_classes("sm"), do: "w-8 h-8"
  defp avatar_container_size_classes("md"), do: "w-12 h-12"
  defp avatar_container_size_classes("lg"), do: "w-16 h-16"
  defp avatar_container_size_classes("xl"), do: "w-20 h-20"

  defp avatar_size_classes("xs"), do: "w-6 h-6"
  defp avatar_size_classes("sm"), do: "w-8 h-8"
  defp avatar_size_classes("md"), do: "w-12 h-12"
  defp avatar_size_classes("lg"), do: "w-16 h-16"
  defp avatar_size_classes("xl"), do: "w-20 h-20"

  defp avatar_status_size_classes("xs"), do: "w-1.5 h-1.5"
  defp avatar_status_size_classes("sm"), do: "w-2 h-2"
  defp avatar_status_size_classes("md"), do: "w-2.5 h-2.5"
  defp avatar_status_size_classes("lg"), do: "w-3 h-3"
  defp avatar_status_size_classes("xl"), do: "w-3.5 h-3.5"

  defp avatar_status_color_classes("online"), do: "bg-emerald-500"
  defp avatar_status_color_classes("calm"), do: "bg-gradient-to-br from-teal-400 to-emerald-500"
  defp avatar_status_color_classes("away"), do: "bg-amber-500"
  defp avatar_status_color_classes("busy"), do: "bg-rose-500"
  defp avatar_status_color_classes("offline"), do: "bg-slate-400"
  defp avatar_status_color_classes(_), do: "bg-slate-400"

  defp avatar_status_ping_classes("online"), do: "bg-emerald-400"
  defp avatar_status_ping_classes("calm"), do: "bg-teal-400"
  defp avatar_status_ping_classes(_), do: ""

  # Helper function to get or create a reply form for a specific post

  @doc """
  Liquid metal timeline post card with calm, privacy-focused design.

  ## Examples

      <.liquid_timeline_post
        user_name="Jane Doe"
        user_handle="@jane"
        user_avatar="/images/avatars/jane.jpg"
        timestamp="2 hours ago"
        content="This is a thoughtful post about connecting with others..."
        images={["/uploads/image1.jpg", "/uploads/image2.jpg"]}
        stats={%{replies: 3, shares: 1, likes: 12}}
      />
  """
  attr :user_name, :string, required: true
  attr :user_handle, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :timestamp, :string, required: true
  attr :content, :string, required: true
  attr :images, :list, default: []
  attr :stats, :map, default: %{}
  attr :verified, :boolean, default: false
  attr :current_user_id, :string, required: true
  attr :liked, :boolean, default: false
  attr :bookmarked, :boolean, default: false
  attr :can_repost, :boolean, default: false
  attr :post, :map, required: true
  attr :post_id, :string, default: nil
  attr :current_user, :map, required: true
  attr :key, :string, default: nil
  attr :is_repost, :boolean, default: false
  # New: unread state
  attr :unread?, :boolean, default: false
  attr :class, :any, default: ""
  # Content warning
  attr :content_warning?, :boolean, default: false
  attr :content_warning, :string, default: nil
  attr :content_warning_category, :string, default: nil
  # Report modal state
  attr :show_report_modal?, :boolean, default: false

  def liquid_timeline_post(assigns) do
    ~H"""
    <article
      id={"timeline-card-#{@post.id}"}
      class={
        [
          "group relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
          "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
          "border border-slate-200/60 dark:border-slate-700/60",
          "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
          "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
          "hover:border-slate-300/60 dark:hover:border-slate-600/60",
          "transform-gpu will-change-transform",
          # Remove enhanced styling for reposts - just use the label
          # No special ring or border for reposts to avoid confusion with unread posts
          "",
          # Enhanced glow effect for unread posts - teal/cyan glow to distinguish from reposts
          if(@unread?,
            do:
              "ring-2 ring-teal-400/40 dark:ring-cyan-500/50 shadow-lg shadow-teal-500/25 dark:shadow-cyan-400/30 border-teal-200/60 dark:border-cyan-700/60",
            else: ""
          ),
          @class
        ]
      }
    >
      <%!-- Enhanced liquid background on hover with subtle styling --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-500 ease-out",
        "group-hover:opacity-100",
        "bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10"
      ]}>
      </div>

      <%!-- Post content --%>
      <div class="relative p-6">
        <%!-- Enhanced repost indicator badge with better visual hierarchy --%>
        <div
          :if={@is_repost}
          class="flex items-center gap-2 mb-4 px-3 py-2 bg-gradient-to-r from-emerald-50/80 via-teal-50/60 to-emerald-50/80 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30 rounded-xl border border-emerald-200/50 dark:border-emerald-700/40 shadow-sm shadow-emerald-500/10 dark:shadow-emerald-400/15"
        >
          <.phx_icon
            name="hero-arrow-path"
            class="h-4 w-4 text-emerald-600 dark:text-emerald-400 flex-shrink-0"
          />
          <span class="text-sm font-semibold text-emerald-700 dark:text-emerald-300">
            Reposted
          </span>
          <%!-- Optional: Add subtle pulse animation --%>
          <div class="w-1.5 h-1.5 bg-emerald-500 dark:bg-emerald-400 rounded-full animate-pulse ml-auto">
          </div>
        </div>
        <%!-- User header --%>
        <div class="flex items-start gap-4 mb-4">
          <%!-- Enhanced liquid metal avatar --%>
          <.liquid_avatar
            src={@user_avatar}
            name={@user_name}
            size="md"
            verified={@verified}
            clickable={true}
          />

          <%!-- User info --%>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate">
                {@user_name}
              </h3>
              <.phx_icon
                :if={@verified}
                name="hero-check-badge"
                class="h-5 w-5 text-emerald-500 flex-shrink-0"
              />
              <%!-- Visibility badge moved inline with user name for better hierarchy --%>
              <.liquid_badge
                variant="soft"
                color={visibility_badge_color(@post.visibility)}
                size="sm"
                class="ml-2"
              >
                {visibility_badge_text(@post.visibility)}
              </.liquid_badge>
            </div>
            <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
              <span class="truncate">{@user_handle}</span>
              <span class="text-slate-400 dark:text-slate-500">•</span>
              <time class="flex-shrink-0">{@timestamp}</time>
            </div>
          </div>

          <%!-- Post menu with liquid dropdown - show for both owned and other posts --%>
          <.liquid_dropdown
            :if={@current_user_id == @post.user_id or @current_user_id != @post.user_id}
            id={"post-menu-#{@post.id}"}
            trigger_class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100/50 dark:hover:bg-slate-700/50 transition-all duration-200 ease-out"
            placement="bottom-end"
          >
            <:trigger>
              <.phx_icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
            </:trigger>

            <%!-- Own post actions --%>
            <:item
              :if={@current_user_id == @post.user_id}
              phx_click="delete_post"
              phx_value_id={@post.id}
              data_confirm="Are you sure you want to delete this post?"
              color="red"
            >
              <.phx_icon name="hero-trash" class="h-4 w-4" /> Delete Post
            </:item>

            <%!-- Other user's post actions --%>
            <:item
              :if={@current_user_id != @post.user_id}
              phx_click="report_post"
              phx_value_id={@post.id}
              color="amber"
            >
              <.phx_icon name="hero-flag" class="h-4 w-4" /> Report Post
            </:item>

            <:item
              :if={@current_user_id != @post.user_id}
              phx_click="block_user"
              phx_value_id={@post.user_id}
              phx_value_user_name={@user_name}
              phx_value_item_id={@post.id}
              color="red"
            >
              <.phx_icon name="hero-no-symbol" class="h-4 w-4" /> Block Author
            </:item>
          </.liquid_dropdown>
        </div>

        <%!-- Content Warning Display (if post has content warning) --%>
        <%= if @content_warning? && @content_warning do %>
          <div
            class="mb-4 p-4 rounded-xl bg-teal-50/50 dark:bg-teal-900/20 border border-teal-200/60 dark:border-teal-700/50"
            id={"content-warning-#{@post.id}"}
          >
            <div class="flex items-center gap-2 mb-3">
              <.phx_icon
                name="hero-hand-raised"
                class="h-4 w-4 text-teal-600 dark:text-teal-400"
              />
              <span class="text-sm font-semibold text-teal-700 dark:text-teal-300">
                Please Note
              </span>
              <%= if @content_warning_category do %>
                <span class="text-xs px-2 py-1 rounded-full bg-teal-100 dark:bg-teal-800/50 text-teal-700 dark:text-teal-300 border border-teal-200 dark:border-teal-700">
                  {format_content_warning_category(@content_warning_category)}
                </span>
              <% end %>
            </div>
            <p class="text-sm text-teal-700 dark:text-teal-300 mb-3">
              {@content_warning}
            </p>
            <button
              id={"content-warning-button-#{@post.id}"}
              class="w-full px-4 py-2 text-sm font-medium text-teal-700 dark:text-teal-300 bg-teal-100/50 dark:bg-teal-800/30 hover:bg-teal-200/50 dark:hover:bg-teal-700/30 border border-teal-200 dark:border-teal-700 rounded-lg transition-all duration-200 ease-out"
              phx-hook="ContentWarningHook"
              data-post-id={@post.id}
            >
              <span class="toggle-text">Show content</span>
            </button>
          </div>
          <%!-- Post content (initially hidden if content warning) --%>
          <div class="mb-4 hidden content-warning-hidden" id={"post-content-#{@post.id}"}>
            <%!-- Legacy posts with HTML (sanitized and rendered) --%>
            <p
              :if={contains_html?(@content)}
              class="text-slate-900 dark:text-slate-100 leading-relaxed whitespace-pre-wrap text-base"
            >
              {html_block(@content)}
            </p>

            <%!-- Modern posts with plain text (escaped automatically by HEEx) --%>
            <p
              :if={!contains_html?(@content)}
              class="text-slate-900 dark:text-slate-100 leading-relaxed whitespace-pre-wrap text-base"
            >
              {@content}
            </p>

            <%!-- Images with enhanced encrypted display system --%>
            <div :if={@post && photos?(@post.image_urls)} class="mb-4">
              <.liquid_post_photo_gallery post={@post} current_user={@current_user} class="" />
            </div>
          </div>
        <% else %>
          <%!-- Post content (normal display when no content warning) --%>
          <div class="mb-4">
            <%!-- Legacy posts with HTML (sanitized and rendered) --%>
            <p
              :if={contains_html?(@content)}
              class="text-slate-900 dark:text-slate-100 leading-relaxed whitespace-pre-wrap text-base"
            >
              {html_block(@content)}
            </p>

            <%!-- Modern posts with plain text (escaped automatically by HEEx) --%>
            <p
              :if={!contains_html?(@content)}
              class="text-slate-900 dark:text-slate-100 leading-relaxed whitespace-pre-wrap text-base"
            >
              {@content}
            </p>

            <%!-- Images with enhanced encrypted display system --%>
            <div :if={@post && photos?(@post.image_urls)} class="mb-4">
              <.liquid_post_photo_gallery post={@post} current_user={@current_user} class="" />
            </div>
          </div>
        <% end %>

        <%!-- Engagement actions (calm and minimal) with semantic colors --%>
        <div class="flex items-center justify-between pt-3 border-t border-slate-200/50 dark:border-slate-700/50">
          <%!-- Action buttons with semantic color coding --%>
          <div class="flex items-center gap-1">
            <%!-- Read/Unread toggle action button (moved to left section) --%>
            <button
              id={
                if @unread?,
                  do: "mark-read-button-#{@post_id}",
                  else: "mark-as-unread-button-#{@post_id}"
              }
              class={[
                "p-2 rounded-lg transition-all duration-200 ease-out group/read active:scale-95 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2",
                if(@unread?,
                  do: "text-teal-600 dark:text-cyan-400 bg-teal-50/50 dark:bg-teal-900/20",
                  else:
                    "text-slate-400 hover:text-teal-600 dark:hover:text-cyan-400 hover:bg-teal-50/50 dark:hover:bg-teal-900/20"
                )
              ]}
              phx-hook="TippyHook"
              data-tippy-content={if @unread?, do: "Mark post as read.", else: "Mark post as unread."}
              phx-click="toggle-read-status"
              phx-value-id={@post_id}
            >
              <.phx_icon
                name={if @unread?, do: "hero-eye-solid", else: "hero-eye-slash"}
                class="h-5 w-5 transition-transform duration-200 group-hover/read:scale-110"
              />
              <span class="sr-only">{if @unread?, do: "Mark as read", else: "Mark as unread"}</span>
            </button>

            <.liquid_timeline_action
              icon="hero-chat-bubble-oval-left"
              count={Map.get(@stats, :replies, 0)}
              label="Reply"
              color="emerald"
              phx-click={
                JS.toggle(to: "#reply-composer-#{@post_id}")
                |> JS.toggle(to: "#reply-thread-#{@post_id}")
                |> JS.toggle_class("ring-2 ring-emerald-300", to: "#timeline-card-#{@post_id}")
                |> JS.toggle_class("hero-chat-bubble-oval-left-solid",
                  to: "#reply-button-#{@post_id} [class*='hero-chat-bubble-oval-left']"
                )
                |> JS.toggle_class("hero-chat-bubble-oval-left",
                  to: "#reply-button-#{@post_id} [class*='hero-chat-bubble-oval-left']"
                )
                |> JS.toggle_attribute({"data-composer-open", "true", "false"},
                  to: "#reply-button-#{@post_id}"
                )
              }
              id={"reply-button-#{@post_id}"}
              data-composer-open="false"
              phx-hook="TippyHook"
              data-tippy-content="Toggle reply composer"
            />
            <.liquid_timeline_action
              :if={@can_repost}
              icon="hero-arrow-path"
              id={"new-repost-button-#{@post.id}"}
              count={Map.get(@stats, :shares, 0)}
              label="Share"
              color="emerald"
              phx-hook="TippyHook"
              data-tippy-content="Repost this post"
              phx-click="repost"
              phx-value-id={@post_id}
              phx-value-body={@content}
              phx-value-username={@user_handle}
            />
            <.liquid_timeline_action
              :if={!@can_repost && @post.id == @current_user.id}
              icon="hero-arrow-path"
              id={"cannot-repost-button-#{@post.id}"}
              count={Map.get(@stats, :shares, 0)}
              label="Share"
              color="emerald"
              phx-hook="TippyHook"
              data-tippy-content="You cannot repost your own post"
              phx-click={nil}
              phx-value-id={nil}
              phx-value-body={nil}
              phx-value-username={nil}
            />
            <.liquid_timeline_action
              :if={!@can_repost && @post.id != @current_user.id}
              icon="hero-arrow-path"
              id={"cannot-repost-button-#{@post.id}"}
              count={Map.get(@stats, :shares, 0)}
              label="Share"
              color="emerald"
              phx-hook="TippyHook"
              data-tippy-content="You already reposted this"
              phx-click={nil}
              phx-value-id={nil}
              phx-value-body={nil}
              phx-value-username={nil}
            />
            <.liquid_timeline_action
              id={
                if @liked,
                  do: "hero-heart-solid-button-#{@post_id}",
                  else: "hero-heart-button=#{@post_id}"
              }
              icon={if @liked, do: "hero-heart-solid", else: "hero-heart"}
              count={Map.get(@stats, :likes, 0)}
              label={if @liked, do: "Unlike", else: "Like"}
              color="rose"
              active={@liked}
              phx-hook="TippyHook"
              data-tippy-content={if @liked, do: "Remove love", else: "Show love"}
              phx-click={if @liked, do: "unfav", else: "fav"}
              phx-value-id={@post_id}
            />
          </div>

          <%!-- Enhanced bookmark action with amber semantic color (matches Bookmarks tab) --%>
          <button
            class={[
              "p-2 rounded-lg transition-all duration-200 ease-out group/bookmark active:scale-95 focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:ring-offset-2",
              if(@bookmarked,
                do: "text-amber-600 dark:text-amber-400 bg-amber-50/50 dark:bg-amber-900/20",
                else:
                  "text-slate-400 hover:text-amber-600 dark:hover:text-amber-400 hover:bg-amber-50/50 dark:hover:bg-amber-900/20"
              )
            ]}
            phx-click="bookmark_post"
            phx-value-id={@post_id}
          >
            <.phx_icon
              name={if @bookmarked, do: "hero-bookmark-solid", else: "hero-bookmark"}
              class="h-5 w-5 transition-transform duration-200 group-hover/bookmark:scale-110"
            />
            <span class="sr-only">Bookmark this post</span>
          </button>
        </div>
      </div>
    </article>

    <%!-- Collapsible reply composer LiveComponent (hidden by default, toggled by JS) --%>
    <.live_component
      module={MossletWeb.TimelineLive.ReplyComposerComponent}
      id={"reply-composer-#{@post.id}"}
      post_id={@post.id}
      visibility={@post.visibility}
      current_user={@current_user}
      user_name={user_name(@current_user, @key) || "You"}
      user_avatar={
        if show_avatar?(@current_user),
          do: maybe_get_user_avatar(@current_user, @key) || "/images/logo.svg",
          else: "/images/logo.svg"
      }
      character_limit={280}
      username={decr(@current_user.username, @current_user, @key)}
      key={@key}
      class=""
    />

    <%!-- Collapsible reply thread (uses existing liquid components) --%>
    <.liquid_collapsible_reply_thread
      post_id={@post.id}
      replies={@post.replies || []}
      reply_count={Map.get(@stats, :replies, 0)}
      show={true}
      current_user={@current_user}
      key={@key}
      class="mt-3"
    />
    """
  end

  # Helper functions for post visibility badges
  defp visibility_badge_color(visibility) do
    case visibility do
      :private -> "slate"
      :connections -> "emerald"
      :public -> "blue"
      :specific_groups -> "purple"
      :specific_users -> "amber"
      _ -> "slate"
    end
  end

  defp visibility_badge_text(visibility) do
    case visibility do
      :private -> "Private"
      :connections -> "Connections"
      :public -> "Public"
      :specific_groups -> "Groups"
      :specific_users -> "Specific"
      _ -> "Private"
    end
  end

  @doc """
  Timeline post images with smart layout based on count.
  """
  attr :images, :list, required: true
  attr :class, :any, default: ""

  def liquid_timeline_images(assigns) do
    assigns = assign(assigns, :image_count, length(assigns.images))

    ~H"""
    <div class={[
      "relative rounded-xl overflow-hidden",
      "border border-slate-200/60 dark:border-slate-700/60",
      @class
    ]}>
      <%!-- Single image --%>
      <img
        :if={@image_count == 1}
        src={hd(@images)}
        alt="Post image"
        class="w-full max-h-96 object-cover transition-transform duration-300 ease-out hover:scale-105"
      />

      <%!-- Two images side by side --%>
      <div :if={@image_count == 2} class="grid grid-cols-2 gap-1">
        <img
          :for={image <- @images}
          src={image}
          alt="Post image"
          class="aspect-square object-cover transition-transform duration-300 ease-out hover:scale-105"
        />
      </div>

      <%!-- Three images: 1 large, 2 small --%>
      <div :if={@image_count == 3} class="grid grid-cols-2 gap-1 h-64">
        <img
          src={Enum.at(@images, 0)}
          alt="Post image"
          class="row-span-2 w-full h-full object-cover transition-transform duration-300 ease-out hover:scale-105"
        />
        <div class="grid grid-rows-2 gap-1">
          <img
            :for={image <- Enum.slice(@images, 1, 2)}
            src={image}
            alt="Post image"
            class="w-full h-full object-cover transition-transform duration-300 ease-out hover:scale-105"
          />
        </div>
      </div>

      <%!-- Four or more images: 2x2 grid with overflow indicator --%>
      <div :if={@image_count >= 4} class="grid grid-cols-2 gap-1 h-64">
        <img
          :for={{image, index} <- Enum.with_index(Enum.slice(@images, 0, 3))}
          src={image}
          alt="Post image"
          class="aspect-square object-cover transition-transform duration-300 ease-out hover:scale-105"
        />
        <div class="relative">
          <img
            src={Enum.at(@images, 3)}
            alt="Post image"
            class="aspect-square object-cover transition-transform duration-300 ease-out hover:scale-105"
          />
          <%!-- Overlay for additional images --%>
          <div
            :if={@image_count > 4}
            class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center transition-all duration-200 ease-out hover:bg-slate-900/40"
          >
            <span class="text-white font-semibold text-lg">
              +{@image_count - 4}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline action button (reply, share, like, bookmark) with calm interaction design.
  """
  attr :icon, :string, required: true
  attr :count, :integer, default: 0
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :color, :string, default: "slate", values: ~w(slate emerald amber rose)
  attr :class, :any, default: ""
  attr :post_id, :string, default: nil
  attr :current_user_id, :string, default: nil

  attr :rest, :global,
    include:
      ~w(phx-click phx-value-id phx-value-url data-confirm id data-composer-open phx-hook data-tippy-content)

  def liquid_timeline_action(assigns) do
    ~H"""
    <button
      class={[
        "group/action relative flex items-center gap-2 px-3 py-2 rounded-xl",
        "transition-all duration-200 ease-out active:scale-95",
        "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
        timeline_action_classes(@active, @color),
        @class
      ]}
      {@rest}
    >
      <%!-- Subtle liquid background on hover --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-300 ease-out rounded-xl",
        "group-hover/action:opacity-100",
        timeline_action_bg_classes(@color)
      ]}>
      </div>

      <%!-- Single icon with conditional state --%>
      <.phx_icon
        name={@icon}
        class="relative h-4 w-4 transition-all duration-200 ease-out group-hover/action:scale-110 reply-icon-outline"
      />

      <span :if={@count > 0} class="relative text-sm font-medium">
        {@count}
      </span>
      <span class="sr-only">{@label}</span>
    </button>
    """
  end

  @doc """
  Timeline compose/new post component with calm, focused design.
  """
  attr :user_name, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :placeholder, :string, default: "What's on your mind?"
  attr :class, :any, default: ""

  def liquid_timeline_composer(assigns) do
    ~H"""
    <div class={[
      "relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
      "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
      "focus-within:border-emerald-500/60 dark:focus-within:border-emerald-400/60",
      "focus-within:shadow-xl focus-within:shadow-emerald-500/10",
      @class
    ]}>
      <%!-- Liquid background on focus --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/20 via-teal-50/10 to-cyan-50/20 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-cyan-900/10 focus-within:opacity-100">
      </div>

      <div class="relative p-6">
        <%!-- User section --%>
        <div class="flex items-start gap-4 mb-4">
          <%!-- Avatar --%>
          <div class="relative flex-shrink-0">
            <div class="relative overflow-hidden rounded-xl">
              <div class="absolute inset-0 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/30 dark:via-emerald-900/20 dark:to-cyan-900/30">
              </div>
              <img
                src={@user_avatar || "/images/default-avatar.svg"}
                alt={"#{@user_name} avatar"}
                class="relative h-12 w-12 object-cover"
              />
            </div>
          </div>

          <%!-- Compose area --%>
          <div class="flex-1 min-w-0">
            <textarea
              placeholder={@placeholder}
              rows="3"
              class="w-full resize-none border-0 bg-transparent text-slate-900 dark:text-slate-100 placeholder:text-slate-500 dark:placeholder:text-slate-400 text-lg leading-relaxed focus:outline-none focus:ring-0"
            ></textarea>
          </div>
        </div>

        <%!-- Actions row --%>
        <div class="flex items-center justify-between pt-4 border-t border-slate-200/50 dark:border-slate-700/50">
          <%!-- Media actions --%>
          <div class="flex items-center gap-2">
            <button class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out">
              <.phx_icon name="hero-photo" class="h-5 w-5" />
            </button>
            <button class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out">
              <.phx_icon name="hero-face-smile" class="h-5 w-5" />
            </button>
          </div>

          <%!-- Privacy indicator and post button --%>
          <div class="flex items-center gap-3">
            <%!-- Privacy indicator --%>
            <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
              <.phx_icon name="hero-lock-closed" class="h-4 w-4" />
              <span>Private</span>
            </div>

            <%!-- Post button --%>
            <.liquid_button size="sm" disabled>
              Share
            </.liquid_button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline status indicator showing online/calm status.
  """
  attr :status, :string, default: "calm", values: ~w(online calm away busy)
  attr :message, :string, default: nil
  attr :class, :any, default: ""

  def liquid_timeline_status(assigns) do
    ~H"""
    <div class={[
      "inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
      "border transition-all duration-200 ease-out",
      timeline_status_classes(@status),
      @class
    ]}>
      <%!-- Status indicator --%>
      <div class={[
        "relative flex-shrink-0 rounded-full transition-all duration-300 ease-out",
        timeline_status_dot_size(@status),
        timeline_status_dot_classes(@status)
      ]}>
        <%!-- Pulse animation for certain statuses --%>
        <div
          :if={@status in ["online", "calm"]}
          class={[
            "absolute inset-0 rounded-full animate-ping opacity-75",
            timeline_status_ping_classes(@status)
          ]}
        >
        </div>
      </div>

      <span class="font-medium">
        {@message || String.capitalize(@status)}
      </span>
    </div>
    """
  end

  @doc """
  Timeline filter/tab component for switching views with enhanced desktop and mobile design.
  Improved colors for semantic meaning and visual hierarchy while remaining calm.
  """
  attr :tabs, :list, required: true
  attr :active_tab, :string, required: true
  attr :class, :any, default: ""

  def liquid_timeline_tabs(assigns) do
    ~H"""
    <div class={[
      "relative rounded-xl overflow-hidden",
      "bg-slate-100/80 dark:bg-slate-800/80 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "p-1",
      @class
    ]}>
      <%!-- Enhanced mobile and desktop layout --%>
      <div class="flex items-center gap-1 overflow-x-auto scrollbar-hide md:overflow-x-visible md:grid md:grid-cols-5">
        <button
          :for={tab <- @tabs}
          class={
            [
              "relative flex-shrink-0 flex items-center justify-center gap-1.5 sm:gap-2 transition-all duration-200 ease-out",
              "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
              "whitespace-nowrap",
              # Mobile: more compact, desktop: proper padding
              "px-2 py-2 sm:px-3 md:px-4 md:py-2.5 text-xs sm:text-sm font-medium rounded-lg",
              # Semantic colors for different tab types
              timeline_tab_classes(tab.key, tab.key == @active_tab)
            ]
          }
          phx-click="switch_tab"
          phx-value-tab={tab.key}
        >
          <%!-- Active tab enhanced liquid background --%>
          <div
            :if={tab.key == @active_tab}
            class={[
              "absolute inset-0 rounded-lg transition-all duration-300 ease-out",
              timeline_tab_active_bg(tab.key)
            ]}
          >
          </div>

          <%!-- Tab icon for mobile and semantic clarity --%>
          <.phx_icon
            :if={tab_icon(tab.key)}
            name={tab_icon(tab.key)}
            class="h-3 w-3 sm:h-4 sm:w-4 flex-shrink-0 relative z-10"
          />

          <%!-- Tab label (responsive sizing) --%>
          <span class="relative z-10 text-xs sm:text-sm truncate">
            {tab.label}
          </span>

          <%!-- Main count badge (simplified) we hide this for now as it's much more relaxing (and the total remaining is in the load more button) --%>
          <%!--
          <span
            :if={tab[:count]}
            class={[
              "relative z-10 flex-shrink-0 px-1 sm:px-1.5 py-0.5 text-xs rounded-full font-medium",
              timeline_tab_count_classes(tab.key, tab.key == @active_tab)
            ]}
          >
            {tab.count}
          </span>
          --%>

          <%!-- Floating unread indicator badge (positioned absolutely in top-right) --%>
          <span
            :if={tab[:unread] && tab.unread > 0}
            class={[
              "absolute -top-1 -right-1 z-20",
              "flex items-center justify-center",
              "min-w-[1.25rem] h-5 px-1.5 text-xs font-bold rounded-full",
              "bg-gradient-to-r from-teal-400 to-cyan-400 text-white",
              "shadow-lg shadow-teal-500/50 dark:shadow-cyan-400/40",
              "ring-2 ring-white dark:ring-slate-800",
              "animate-pulse",
              "transform scale-90 hover:scale-100 transition-transform duration-200"
            ]}
            data-tooltip="Unread posts"
          >
            {tab.unread}
          </span>
        </button>
      </div>

      <%!-- Enhanced scroll indicators for mobile (subtle but clear) --%>
      <div class="absolute left-0 top-0 bottom-0 w-3 bg-gradient-to-r from-slate-100/90 to-transparent dark:from-slate-800/90 pointer-events-none md:hidden">
      </div>
      <div class="absolute right-0 top-0 bottom-0 w-3 bg-gradient-to-l from-slate-100/90 to-transparent dark:from-slate-800/90 pointer-events-none md:hidden">
      </div>

      <%!-- Subtle scroll hint for mobile --%>
      <div class="absolute -bottom-5 right-2 md:hidden">
        <div class="flex items-center gap-1 text-xs text-slate-400 dark:text-slate-500">
          <.phx_icon name="hero-arrows-pointing-out" class="h-3 w-3" />
          <span>scroll</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline header with calm, meaningful messaging about community and privacy.
  """
  attr :user_name, :string, required: true
  attr :status, :string, default: "calm"
  attr :status_message, :string, default: nil
  attr :class, :any, default: ""

  def liquid_timeline_header(assigns) do
    ~H"""
    <div class={[
      "relative p-6 text-center",
      @class
    ]}>
      <%!-- Meaningful header about community and privacy --%>
      <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 dark:text-slate-100 mb-2">
        {@user_name}'s
        <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          community
        </span>
      </h1>

      <p class="text-slate-600 dark:text-slate-400 mb-4">
        Share thoughtfully in your private, peaceful space
      </p>

      <%!-- Status indicator --%>
      <div class="flex justify-center">
        <.liquid_timeline_status status={@status} message={@status_message} />
      </div>
    </div>
    """
  end

  # Helper function for tab icons (mobile optimization)
  defp tab_icon("home"), do: "hero-home"
  defp tab_icon("connections"), do: "hero-user-group"
  defp tab_icon("groups"), do: "hero-users"
  defp tab_icon("bookmarks"), do: "hero-bookmark"
  defp tab_icon("discover"), do: "hero-magnifying-glass"
  defp tab_icon(_), do: nil

  # Semantic colors for different tab types (calm but meaningful)
  defp timeline_tab_classes("home", true) do
    [
      "bg-gradient-to-r from-emerald-500 to-teal-500 text-white shadow-md",
      "hover:from-emerald-600 hover:to-teal-600"
    ]
  end

  defp timeline_tab_classes("connections", true) do
    [
      "bg-gradient-to-r from-blue-500 to-cyan-500 text-white shadow-md",
      "hover:from-blue-600 hover:to-cyan-600"
    ]
  end

  defp timeline_tab_classes("groups", true) do
    [
      "bg-gradient-to-r from-purple-500 to-violet-500 text-white shadow-md",
      "hover:from-purple-600 hover:to-violet-600"
    ]
  end

  defp timeline_tab_classes("bookmarks", true) do
    [
      "bg-gradient-to-r from-amber-500 to-orange-500 text-white shadow-md",
      "hover:from-amber-600 hover:to-orange-600"
    ]
  end

  defp timeline_tab_classes("discover", true) do
    [
      "bg-gradient-to-r from-indigo-500 to-blue-500 text-white shadow-md",
      "hover:from-indigo-600 hover:to-blue-600"
    ]
  end

  # Inactive states with subtle semantic tinting
  defp timeline_tab_classes("home", false) do
    [
      "text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300",
      "hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20"
    ]
  end

  defp timeline_tab_classes("connections", false) do
    [
      "text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300",
      "hover:bg-blue-50/50 dark:hover:bg-blue-900/20"
    ]
  end

  defp timeline_tab_classes("groups", false) do
    [
      "text-purple-600 dark:text-purple-400 hover:text-purple-700 dark:hover:text-purple-300",
      "hover:bg-purple-50/50 dark:hover:bg-purple-900/20"
    ]
  end

  defp timeline_tab_classes("bookmarks", false) do
    [
      "text-amber-600 dark:text-amber-400 hover:text-amber-700 dark:hover:text-amber-300",
      "hover:bg-amber-50/50 dark:hover:bg-amber-900/20"
    ]
  end

  defp timeline_tab_classes("discover", false) do
    [
      "text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300",
      "hover:bg-indigo-50/50 dark:hover:bg-indigo-900/20"
    ]
  end

  # Fallback
  defp timeline_tab_classes(_, true) do
    [
      "bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100",
      "shadow-md border border-slate-200/60 dark:border-slate-600/60"
    ]
  end

  defp timeline_tab_classes(_, false) do
    [
      "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100",
      "hover:bg-white/50 dark:hover:bg-slate-700/50"
    ]
  end

  # Active tab background gradients for semantic meaning
  defp timeline_tab_active_bg("home"),
    do:
      "bg-gradient-to-r from-emerald-50/40 via-teal-50/30 to-emerald-50/40 dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-emerald-900/20"

  defp timeline_tab_active_bg("connections"),
    do:
      "bg-gradient-to-r from-blue-50/40 via-cyan-50/30 to-blue-50/40 dark:from-blue-900/20 dark:via-cyan-900/15 dark:to-blue-900/20"

  defp timeline_tab_active_bg("groups"),
    do:
      "bg-gradient-to-r from-purple-50/40 via-violet-50/30 to-purple-50/40 dark:from-purple-900/20 dark:via-violet-900/15 dark:to-purple-900/20"

  defp timeline_tab_active_bg("bookmarks"),
    do:
      "bg-gradient-to-r from-amber-50/40 via-orange-50/30 to-amber-50/40 dark:from-amber-900/20 dark:via-orange-900/15 dark:to-amber-900/20"

  defp timeline_tab_active_bg("discover"),
    do:
      "bg-gradient-to-r from-indigo-50/40 via-blue-50/30 to-indigo-50/40 dark:from-indigo-900/20 dark:via-blue-900/15 dark:to-indigo-900/20"

  defp timeline_tab_active_bg(_),
    do:
      "bg-gradient-to-r from-teal-50/30 via-emerald-50/20 to-cyan-50/30 dark:from-teal-900/20 dark:via-emerald-900/10 dark:to-cyan-900/20"

  # Count badge colors to match tab semantics
  # Unused for now because that is a calmer UX
  # defp timeline_tab_count_classes("home", true),
  #  do: "bg-emerald-100 dark:bg-emerald-800 text-emerald-800 dark:text-emerald-200"

  # defp timeline_tab_count_classes("connections", true),
  #  do: "bg-blue-100 dark:bg-blue-800 text-blue-800 dark:text-blue-200"

  # defp timeline_tab_count_classes("groups", true),
  #  do: "bg-purple-100 dark:bg-purple-800 text-purple-800 dark:text-purple-200"

  # defp timeline_tab_count_classes("bookmarks", true),
  #  do: "bg-amber-100 dark:bg-amber-800 text-amber-800 dark:text-amber-200"

  # defp timeline_tab_count_classes("discover", true),
  #  do: "bg-indigo-100 dark:bg-indigo-800 text-indigo-800 dark:text-indigo-200"

  # defp timeline_tab_count_classes(_, false),
  #  do: "bg-slate-200 dark:bg-slate-600 text-slate-600 dark:text-slate-300"

  # defp timeline_tab_count_classes(_, true),
  #  do: "bg-slate-200 dark:bg-slate-600 text-slate-600 dark:text-slate-300"

  # Helper functions for timeline action components

  # Action button color and state classes
  defp timeline_action_classes(false, "slate") do
    [
      "text-slate-500 dark:text-slate-400",
      "hover:text-emerald-600 dark:hover:text-emerald-400"
    ]
  end

  defp timeline_action_classes(false, "emerald") do
    [
      "text-slate-500 dark:text-slate-400",
      "hover:text-emerald-600 dark:hover:text-emerald-400"
    ]
  end

  defp timeline_action_classes(false, "amber") do
    [
      "text-slate-500 dark:text-slate-400",
      "hover:text-amber-600 dark:hover:text-amber-400"
    ]
  end

  defp timeline_action_classes(false, "rose") do
    [
      "text-slate-500 dark:text-slate-400",
      "hover:text-rose-600 dark:hover:text-rose-400"
    ]
  end

  # Active states
  defp timeline_action_classes(true, "emerald") do
    [
      "text-emerald-600 dark:text-emerald-400",
      "bg-emerald-50/50 dark:bg-emerald-900/20"
    ]
  end

  defp timeline_action_classes(true, "amber") do
    [
      "text-amber-600 dark:text-amber-400",
      "bg-amber-50/50 dark:bg-amber-900/20"
    ]
  end

  defp timeline_action_classes(true, "rose") do
    [
      "text-rose-600 dark:text-rose-400",
      "bg-rose-50/50 dark:bg-rose-900/20"
    ]
  end

  defp timeline_action_classes(true, _) do
    [
      "text-emerald-600 dark:text-emerald-400",
      "bg-emerald-50/50 dark:bg-emerald-900/20"
    ]
  end

  # Background hover effects for different actions
  defp timeline_action_bg_classes("emerald") do
    "bg-gradient-to-r from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15"
  end

  defp timeline_action_bg_classes("amber") do
    "bg-gradient-to-r from-amber-50/30 via-yellow-50/40 to-amber-50/30 dark:from-amber-900/15 dark:via-yellow-900/20 dark:to-amber-900/15"
  end

  defp timeline_action_bg_classes("rose") do
    "bg-gradient-to-r from-rose-50/30 via-pink-50/40 to-rose-50/30 dark:from-rose-900/15 dark:via-pink-900/20 dark:to-rose-900/15"
  end

  defp timeline_action_bg_classes(_) do
    "bg-gradient-to-r from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15"
  end

  # Helper functions for timeline components

  # Timeline status styling
  defp timeline_status_classes("online") do
    [
      "bg-emerald-50/80 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300",
      "border-emerald-200/60 dark:border-emerald-700/60"
    ]
  end

  defp timeline_status_classes("calm") do
    [
      "bg-teal-50/80 dark:bg-teal-900/20 text-teal-700 dark:text-teal-300",
      "border-teal-200/60 dark:border-teal-700/60"
    ]
  end

  defp timeline_status_classes("away") do
    [
      "bg-amber-50/80 dark:bg-amber-900/20 text-amber-700 dark:text-amber-300",
      "border-amber-200/60 dark:border-amber-700/60"
    ]
  end

  defp timeline_status_classes("busy") do
    [
      "bg-rose-50/80 dark:bg-rose-900/20 text-rose-700 dark:text-rose-300",
      "border-rose-200/60 dark:border-rose-700/60"
    ]
  end

  defp timeline_status_dot_size("online"), do: "w-2 h-2"
  defp timeline_status_dot_size("calm"), do: "w-2.5 h-2.5"
  defp timeline_status_dot_size("away"), do: "w-2 h-2"
  defp timeline_status_dot_size("busy"), do: "w-2 h-2"

  defp timeline_status_dot_classes("online"), do: "bg-emerald-500"
  defp timeline_status_dot_classes("calm"), do: "bg-gradient-to-br from-teal-400 to-emerald-500"
  defp timeline_status_dot_classes("away"), do: "bg-amber-500"
  defp timeline_status_dot_classes("busy"), do: "bg-rose-500"

  defp timeline_status_ping_classes("online"), do: "bg-emerald-400"
  defp timeline_status_ping_classes("calm"), do: "bg-teal-400"
  defp timeline_status_ping_classes(_), do: ""

  @doc """
  Simple liquid metal FAQ component following our design system.

  ## Examples

      <.liquid_faq_simple
        title="Frequently Asked Questions"
        subtitle="Get the answers you need"
        description="Everything you need to know about our service."
        sections={[
          %{
            title: "General",
            questions: [
              %{q: "What is this?", a: "This is a great service."}
            ]
          }
        ]}
      />
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :description, :string, default: nil
  attr :sections, :list, default: []
  attr :class, :any, default: ""

  def liquid_faq_simple(assigns) do
    ~H"""
    <div class={[
      "min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10",
      @class
    ]}>
      <main class="isolate">
        <%!-- Hero section with gradient orbs but cleaner background --%>
        <div class="relative isolate">
          <%!-- Floating gradient orbs for liquid metal effect - responsive and contained --%>
          <div
            class="absolute inset-0 -z-10 overflow-hidden"
            aria-hidden="true"
          >
            <div class="absolute left-1/2 top-0 -translate-x-1/2 lg:translate-x-6 xl:translate-x-12 transform-gpu blur-3xl">
              <div
                class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] xl:w-[45rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
              >
              </div>
            </div>
          </div>

          <div class="overflow-hidden">
            <div class="mx-auto max-w-7xl px-6 pb-32 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
              <div class="mx-auto max-w-2xl text-center">
                <%!-- Enhanced hero title with liquid metal styling matching other pages --%>
                <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                  {@title}
                </h1>

                <%!-- Enhanced subtitle --%>
                <p
                  :if={@subtitle}
                  class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out"
                >
                  {@subtitle}
                </p>

                <%!-- Description --%>
                <p
                  :if={@description}
                  class="mt-6 text-base leading-7 text-slate-600 dark:text-slate-400"
                >
                  {@description}
                </p>

                <%!-- Decorative accent line matching other pages --%>
                <div class="mt-8 flex justify-center">
                  <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- FAQ sections with enhanced styling --%>
        <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8 pb-24">
          <div class="mx-auto max-w-4xl">
            <div :for={section <- @sections} class="mb-16 last:mb-0">
              <%!-- Section container with liquid styling --%>
              <div class="group relative overflow-hidden rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 transition-all duration-300 ease-out">
                <%!-- Liquid background effects --%>
                <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 group-hover:opacity-100">
                </div>

                <%!-- Card border with liquid accent --%>
                <div class="absolute inset-0 rounded-xl ring-1 transition-all duration-300 ease-out ring-slate-200/60 dark:ring-slate-700/60 group-hover:ring-emerald-500/30 dark:group-hover:ring-emerald-400/30">
                </div>

                <%!-- Content --%>
                <div class="relative p-8">
                  <%!-- Section title with enhanced styling --%>
                  <h2 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 mb-8 bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent">
                    {section.title}
                  </h2>

                  <%!-- Questions with improved spacing and styling --%>
                  <dl class="space-y-8">
                    <div
                      :for={qa <- section.questions}
                      class="group/question border-l-4 border-transparent transition-all duration-200 ease-out hover:border-emerald-400 hover:pl-4"
                    >
                      <dt class="text-lg font-semibold leading-7 text-slate-900 dark:text-slate-100 group-hover/question:text-emerald-600 dark:group-hover/question:text-emerald-400 transition-colors duration-200">
                        {qa.q}
                      </dt>
                      <dd class="mt-2 text-base leading-7 text-slate-600 dark:text-slate-400 group-hover/question:text-slate-700 dark:group-hover/question:text-slate-300 transition-colors duration-200">
                        {qa.a}
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>

            <%!-- Contact section matching support page style --%>
            <div class="mt-16">
              <div class="group relative overflow-hidden rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 transition-all duration-300 ease-out transform-gpu will-change-transform hover:scale-[1.02] hover:shadow-2xl hover:shadow-emerald-500/10">
                <%!-- Liquid background effects --%>
                <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 group-hover:opacity-100">
                </div>

                <%!-- Shimmer effect --%>
                <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full">
                </div>

                <%!-- Card border with liquid accent --%>
                <div class="absolute inset-0 rounded-xl ring-1 transition-all duration-300 ease-out ring-slate-200/60 dark:ring-slate-700/60 group-hover:ring-emerald-500/30 dark:group-hover:ring-emerald-400/30">
                </div>

                <%!-- Content --%>
                <div class="relative p-8 text-center">
                  <div class="mb-4">
                    <span class="inline-flex px-3 py-1.5 rounded-full text-xs font-medium tracking-wide uppercase bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-800 dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-200 border border-teal-300/60 dark:border-teal-600/60">
                      Need more help?
                    </span>
                  </div>

                  <h3 class="mb-4 text-xl lg:text-2xl font-bold leading-tight text-slate-900 dark:text-slate-100 transition-all duration-200 ease-out group-hover:text-emerald-700 dark:group-hover:text-emerald-300">
                    <.link
                      href="mailto:support@mosslet.com"
                      class="relative"
                    >
                      Contact our support team <%!-- Subtle underline effect --%>
                      <div class="absolute bottom-0 left-1/2 h-0.5 w-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-400 to-emerald-400 group-hover:w-full group-hover:left-0">
                      </div>
                    </.link>
                  </h3>

                  <p class="text-base leading-7 text-slate-600 dark:text-slate-400 max-w-md mx-auto">
                    Can't find what you're looking for? Reach out to our human support team at
                    <.link
                      href="mailto:support@mosslet.com"
                      class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 transition-colors duration-200"
                    >
                      support@mosslet.com
                    </.link>
                    . We're real people who actually want to help.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  @doc """
  Liquid metal banner notification component.

  ## Examples

      <.liquid_banner type="warning" icon="hero-exclamation-triangle">
        <:title>Important notice</:title>
        This is a warning message.
      </.liquid_banner>

      <.liquid_banner type="info" icon="hero-information-circle">
        <:title>Information</:title>
        This is an informational message.
      </.liquid_banner>
  """
  attr :type, :string, default: "info", values: ~w(info warning error success)
  attr :icon, :string, default: nil
  attr :class, :any, default: ""
  slot :title
  slot :inner_block, required: true

  def liquid_banner(assigns) do
    ~H"""
    <div class={[
      "relative overflow-hidden rounded-xl backdrop-blur-sm p-6",
      "border shadow-lg transition-all duration-300 ease-out",
      banner_type_classes(@type),
      @class
    ]}>
      <%!-- Liquid background shimmer effect --%>
      <div class="absolute inset-0 opacity-30">
        <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent transform -skew-x-12 -translate-x-full animate-[shimmer_3s_ease-in-out_infinite]">
        </div>
      </div>

      <%!-- Banner content --%>
      <div class="relative flex items-start gap-4">
        <%!-- Icon --%>
        <div :if={@icon} class="flex-shrink-0">
          <.phx_icon name={@icon} class={["h-6 w-6", banner_icon_classes(@type)]} />
        </div>

        <%!-- Content --%>
        <div class="flex-1 min-w-0">
          <%!-- Title --%>
          <div :if={render_slot(@title)} class="mb-2">
            <h3 class={["font-medium", banner_title_classes(@type)]}>
              {render_slot(@title)}
            </h3>
          </div>

          <%!-- Message content --%>
          <div class={["text-sm leading-relaxed", banner_content_classes(@type)]}>
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Banner styling helpers
  defp banner_type_classes("warning") do
    [
      "bg-amber-50/95 dark:bg-amber-900/20",
      "border-amber-200/60 dark:border-amber-800/30",
      "shadow-amber-500/10 dark:shadow-amber-900/20"
    ]
  end

  defp banner_type_classes("error") do
    [
      "bg-red-50/95 dark:bg-red-900/20",
      "border-red-200/60 dark:border-red-800/30",
      "shadow-red-500/10 dark:shadow-red-900/20"
    ]
  end

  defp banner_type_classes("success") do
    [
      "bg-emerald-50/95 dark:bg-emerald-900/20",
      "border-emerald-200/60 dark:border-emerald-800/30",
      "shadow-emerald-500/10 dark:shadow-emerald-900/20"
    ]
  end

  defp banner_type_classes("info") do
    [
      "bg-blue-50/95 dark:bg-blue-900/20",
      "border-blue-200/60 dark:border-blue-800/30",
      "shadow-blue-500/10 dark:shadow-blue-900/20"
    ]
  end

  defp banner_icon_classes("warning"), do: "text-amber-600 dark:text-amber-400"
  defp banner_icon_classes("error"), do: "text-red-600 dark:text-red-400"
  defp banner_icon_classes("success"), do: "text-emerald-600 dark:text-emerald-400"
  defp banner_icon_classes("info"), do: "text-blue-600 dark:text-blue-400"

  defp banner_title_classes("warning"), do: "text-amber-800 dark:text-amber-200"
  defp banner_title_classes("error"), do: "text-red-800 dark:text-red-200"
  defp banner_title_classes("success"), do: "text-emerald-800 dark:text-emerald-200"
  defp banner_title_classes("info"), do: "text-blue-800 dark:text-blue-200"

  defp banner_content_classes("warning"), do: "text-amber-700 dark:text-amber-300"
  defp banner_content_classes("error"), do: "text-red-700 dark:text-red-300"
  defp banner_content_classes("success"), do: "text-emerald-700 dark:text-emerald-300"
  defp banner_content_classes("info"), do: "text-blue-700 dark:text-blue-300"

  @doc """
  A liquid-styled dropdown menu component.

  ## Examples

      <.liquid_dropdown
        id="post-menu-123"
        trigger_class="p-2 rounded-lg text-slate-400 hover:text-slate-600"
        placement="bottom-end"
      >
        <:trigger>
          <.phx_icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
        </:trigger>
        <:item phx-click="delete_post" phx-value-id="123" color="red">
          <.phx_icon name="hero-trash" class="h-4 w-4" />
          Delete Post
        </:item>
      </.liquid_dropdown>
  """
  attr :id, :string, required: true
  attr :trigger_class, :string, default: ""

  attr :placement, :string,
    default: "bottom-end",
    values: ~w(bottom-start bottom-end top-start top-end)

  attr :class, :string, default: ""

  slot :trigger, required: true

  slot :item do
    attr :color, :string, values: ~w(slate gray red emerald blue amber purple rose)
    attr :phx_click, :string
    attr :phx_value_id, :string
    attr :phx_value_username, :string
    attr :phx_value_user_name, :string
    attr :phx_value_item_id, :string
    attr :phx_value_reply_id, :string
    attr :phx_value_reported_user_id, :string
    attr :href, :string
    attr :data_confirm, :string
  end

  def liquid_dropdown(assigns) do
    ~H"""
    <div class={["relative", @class]} phx-click-away={JS.hide(to: "##{@id}-menu")}>
      <%!-- Trigger button --%>
      <button
        type="button"
        phx-click={JS.toggle(to: "##{@id}-menu")}
        class={[
          "relative transition-all duration-200 ease-out",
          "hover:bg-slate-100/50 dark:hover:bg-slate-700/50",
          @trigger_class
        ]}
        aria-expanded="false"
        aria-haspopup="true"
      >
        {render_slot(@trigger)}
      </button>

      <%!-- Dropdown menu --%>
      <div
        id={"#{@id}-menu"}
        class={[
          "absolute z-[100] mt-2 w-48 origin-top-right hidden",
          "rounded-xl border border-slate-200/60 dark:border-slate-700/60",
          "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
          "shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30",
          "transition-all duration-200 ease-out",
          "ring-1 ring-slate-200/60 dark:ring-slate-700/60",
          placement_classes(@placement)
        ]}
        role="menu"
        aria-orientation="vertical"
      >
        <%!-- Liquid background effect --%>
        <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 opacity-50">
        </div>

        <div class="relative py-2">
          <div
            :for={item <- @item}
            class={[
              "group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer",
              "hover:bg-slate-100/80 dark:hover:bg-slate-700/80",
              "first:rounded-t-lg last:rounded-b-lg",
              item_color_classes(item[:color] || "slate")
            ]}
            role="menuitem"
            phx-click={item[:phx_click]}
            phx-value-id={item[:phx_value_id]}
            phx-value-username={item[:phx_value_username]}
            phx-value-user-name={item[:phx_value_user_name]}
            phx-value-item-id={item[:phx_value_item_id]}
            phx-value-reply-id={item[:phx_value_reply_id]}
            phx-value-reported-user-id={item[:phx_value_reported_user_id]}
            {if item[:href], do: ["phx-click": "navigate", "phx-value-href": item[:href]], else: []}
            data-confirm={item[:data_confirm]}
          >
            {render_slot(item)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp placement_classes("bottom-start"), do: "left-0"
  defp placement_classes("bottom-end"), do: "right-0"
  defp placement_classes("top-start"), do: "left-0 bottom-full mb-2"
  defp placement_classes("top-end"), do: "right-0 bottom-full mb-2"
  defp placement_classes(_), do: "right-0"

  defp item_color_classes("red") do
    "text-rose-700 dark:text-rose-300 hover:text-rose-800 dark:hover:text-rose-200 hover:bg-rose-50/80 dark:hover:bg-rose-900/40"
  end

  defp item_color_classes("emerald") do
    "text-emerald-700 dark:text-emerald-300 hover:text-emerald-800 dark:hover:text-emerald-200 hover:bg-emerald-50/80 dark:hover:bg-emerald-900/40"
  end

  defp item_color_classes("blue") do
    "text-blue-700 dark:text-blue-300 hover:text-blue-800 dark:hover:text-blue-200 hover:bg-blue-50/80 dark:hover:bg-blue-900/40"
  end

  defp item_color_classes("amber") do
    "text-amber-700 dark:text-amber-300 hover:text-amber-800 dark:hover:text-amber-200 hover:bg-amber-50/80 dark:hover:bg-amber-900/40"
  end

  defp item_color_classes("rose") do
    "text-rose-700 dark:text-rose-300 hover:text-rose-800 dark:hover:text-rose-200 hover:bg-rose-50/80 dark:hover:bg-rose-900/40"
  end

  defp item_color_classes(_) do
    "text-slate-700 dark:text-slate-300 hover:text-slate-800 dark:hover:text-slate-200"
  end

  @doc """
  Collapsible reply thread display component.

  ## Examples

      <.liquid_collapsible_reply_thread
        post_id={@post.id}
        replies={@post.replies || []}
        reply_count={Map.get(@stats, :replies, 0)}
        show={true}
        current_user={@current_user}
        key={@key}
        class="mt-3"
      />
  """
  attr :post_id, :string, required: true
  attr :replies, :list, default: []
  attr :show, :boolean, default: false
  attr :current_user, :map, required: true
  attr :key, :string, default: nil
  attr :reply_count, :integer, default: 0
  attr :class, :any, default: ""

  def liquid_collapsible_reply_thread(assigns) do
    ~H"""
    <div
      id={"reply-thread-#{@post_id}"}
      class={[
        "transition-all duration-300 ease-out hidden",
        @class
      ]}
    >
      <div class="pt-4 border-t border-slate-200/50 dark:border-slate-700/50">
        <%!-- Thread header --%>
        <div class="flex items-center gap-2 mb-4 pl-4">
          <div class="w-6 h-px bg-gradient-to-r from-emerald-300 to-teal-300 dark:from-emerald-600 dark:to-teal-600">
          </div>
          <.phx_icon
            name="hero-chat-bubble-left-ellipsis"
            class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
          />
          <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
            {if @reply_count == 1, do: "1 reply", else: "#{@reply_count} replies"}
          </span>
        </div>

        <%!-- Reply list with proper nested threading (only top-level replies) --%>
        <div class="space-y-4 pl-4 sm:pl-6 relative">
          <%!-- Main thread connection line --%>
          <div class="absolute left-0 sm:left-2 top-0 bottom-0 w-px bg-gradient-to-b from-emerald-300/60 via-teal-400/40 to-transparent dark:from-emerald-400/60 dark:via-teal-500/40">
          </div>

          <%!-- Render only top-level replies (those without a parent) --%>
          <div :for={reply <- filter_top_level_replies(@replies)} class="reply-item relative">
            <%!-- Individual reply connection --%>
            <div class="absolute -left-4 sm:-left-6 top-6 w-3 sm:w-4 h-px bg-gradient-to-r from-emerald-300/60 to-transparent dark:from-emerald-400/60">
            </div>

            <.liquid_nested_reply_item
              reply={reply}
              current_user={@current_user}
              key={@key}
              depth={0}
              max_depth={3}
              post_id={@post_id}
            />
          </div>

          <%!-- Load more replies if needed --%>
          <div :if={@reply_count > length(@replies)} class="pt-2">
            <.liquid_button
              variant="ghost"
              size="sm"
              color="emerald"
              phx-click="load_more_replies"
              phx-value-id={@post_id}
              class="text-emerald-600 dark:text-emerald-400"
            >
              Load {min(@reply_count - length(@replies), 5)} more replies
            </.liquid_button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Nested reply item with recursive rendering for threading.
  """
  attr :reply, :map, required: true
  attr :current_user, :map, required: true
  attr :key, :string, default: nil
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 3
  attr :post_id, :string, default: nil
  attr :class, :any, default: ""

  def liquid_nested_reply_item(assigns) do
    ~H"""
    <div class={[
      "nested-reply-container",
      @class
    ]}>
      <%!-- Render the current reply --%>
      <.liquid_reply_item
        reply={@reply}
        current_user={@current_user}
        key={@key}
        depth={@depth}
        post_id={@post_id}
      />

      <%!-- Render nested child replies with improved visual hierarchy --%>
      <div
        :if={@depth < @max_depth and has_child_replies?(@reply)}
        class={
          [
            "nested-children mt-3 relative",
            # Increase indentation for deeper nesting
            if(@depth == 0, do: "ml-6 sm:ml-8", else: "ml-4 sm:ml-6"),
            # Add visual separator for nested levels
            "border-l-2 border-emerald-200/40 dark:border-emerald-700/40 pl-4 sm:pl-6"
          ]
        }
      >
        <%!-- Enhanced nested thread connection --%>
        <div class="absolute -left-0.5 top-0 bottom-0 w-0.5 bg-gradient-to-b from-emerald-300/60 via-teal-400/40 to-transparent dark:from-emerald-400/60 dark:via-teal-500/40">
        </div>

        <%!-- Child replies with better spacing --%>
        <div class="space-y-3">
          <div :for={child_reply <- get_child_replies(@reply)} class="nested-reply-item relative">
            <%!-- Connection line to child --%>
            <div class="absolute -left-4 sm:-left-6 top-6 w-3 sm:w-4 h-px bg-gradient-to-r from-emerald-300/50 to-transparent dark:from-emerald-400/50">
            </div>

            <.liquid_nested_reply_item
              reply={child_reply}
              current_user={@current_user}
              key={@key}
              depth={@depth + 1}
              max_depth={@max_depth}
              post_id={@post_id}
            />
          </div>
        </div>
      </div>

      <%!-- Show "Load more replies" for deeply nested threads --%>
      <div
        :if={@depth >= @max_depth and has_child_replies?(@reply)}
        class="ml-4 sm:ml-6 mt-2"
      >
        <.liquid_button
          variant="ghost"
          size="sm"
          color="emerald"
          class="text-xs text-emerald-600 dark:text-emerald-400"
        >
          View {length(get_child_replies(@reply))} more replies
        </.liquid_button>
      </div>

      <%!-- Nested reply composer LiveComponent (hidden by default, toggled by JS) --%>
      <div
        :if={@current_user}
        id={"nested-composer-#{@reply.id}"}
        class="ml-4 sm:ml-6 mt-3 hidden"
        phx-hook="HideNestedReplyComposer"
      >
        <.live_component
          module={MossletWeb.TimelineLive.NestedReplyComposerComponent}
          id={"nested-composer-component-#{@reply.id}"}
          parent_reply={@reply}
          post_id={@post_id}
          current_user={@current_user}
          key={Map.get(assigns, :key)}
          author_name={get_reply_author_name(@reply, @current_user, Map.get(assigns, :key))}
          class=""
        />
      </div>
    </div>
    """
  end

  @doc """
  Individual reply item with liquid styling (updated for nesting support).
  """
  attr :reply, :map, required: true
  attr :current_user, :map, required: true
  attr :key, :string, default: nil
  attr :depth, :integer, default: 0
  attr :post_id, :string, default: nil
  attr :class, :any, default: ""

  def liquid_reply_item(assigns) do
    ~H"""
    <div class={[
      "relative rounded-xl transition-all duration-200 ease-out",
      reply_background_classes(@depth),
      reply_border_classes(@depth),
      reply_hover_classes(@depth),
      "shadow-sm hover:shadow-md dark:shadow-slate-900/20",
      @class
    ]}>
      <%!-- Depth-aware reply accent --%>
      <div class={[
        "absolute left-0 top-0 bottom-0 rounded-r-full",
        reply_accent_classes(@depth)
      ]}>
      </div>

      <div class={[
        "p-4 sm:p-4",
        reply_padding_classes(@depth)
      ]}>
        <div class="flex items-start gap-3">
          <%!-- Reply author avatar (small) --%>
          <.liquid_avatar
            src={get_reply_author_avatar(@reply, @current_user, @key)}
            name={get_reply_author_name(@reply, @current_user, @key)}
            size="sm"
            class="flex-shrink-0 mt-0.5"
          />

          <div class="flex-1 min-w-0">
            <%!-- Reply header --%>
            <div class="flex items-center gap-2 mb-2">
              <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                {get_reply_author_name(@reply, @current_user, @key)}
              </span>
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {format_reply_timestamp(@reply.inserted_at)}
              </span>
            </div>

            <%!-- Reply content --%>
            <div class="text-sm text-slate-800 dark:text-slate-200 leading-relaxed">
              {get_decrypted_reply_content(@reply, @current_user, @key)}
            </div>

            <%!-- Reply actions (mobile-optimized) --%>
            <div class="flex items-center justify-between mt-3 sm:mt-2">
              <div class="flex items-center gap-3 sm:gap-4">
                <.liquid_timeline_action
                  id={
                    if @current_user.id in @reply.favs_list,
                      do: "hero-heart-solid-reply-button-#{@reply.id}",
                      else: "hero-heart-reply-button-#{@reply.id}"
                  }
                  icon={
                    if @current_user.id in @reply.favs_list,
                      do: "hero-heart-solid",
                      else: "hero-heart"
                  }
                  count={@reply.favs_count}
                  label={if @current_user.id in @reply.favs_list, do: "Unlike", else: "Love"}
                  color="rose"
                  active={@current_user.id in @reply.favs_list}
                  phx-click={
                    if @current_user.id in @reply.favs_list, do: "unfav_reply", else: "fav_reply"
                  }
                  phx-value-id={@reply.id}
                  phx-hook="TippyHook"
                  data-tippy-content={
                    if @current_user.id in @reply.favs_list, do: "Remove love", else: "Show love"
                  }
                  class="text-xs sm:scale-75 sm:origin-left min-h-[44px] sm:min-h-0"
                />
                <button
                  id={"reply-button-#{@reply.id}"}
                  phx-click={
                    JS.toggle(to: "#nested-composer-#{@reply.id}")
                    |> JS.toggle_class("text-emerald-600 dark:text-emerald-400",
                      to: "#reply-button-#{@reply.id}"
                    )
                    |> JS.toggle_attribute({"data-composer-open", "true", "false"},
                      to: "#reply-button-#{@reply.id}"
                    )
                  }
                  data-composer-open="false"
                  class="min-h-[44px] sm:min-h-0 px-3 py-2 sm:px-0 sm:py-0 text-xs text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors duration-200 rounded-lg sm:rounded-none focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-1"
                  phx-hook="TippyHook"
                  data-tippy-content="Reply to this comment"
                >
                  <.phx_icon name="hero-arrow-uturn-left" class="h-3 w-3 mr-1 inline" /> Reply
                </button>
              </div>

              <%!-- Reply dropdown menu (only show if user has permissions) --%>
              <div
                :if={
                  can_manage_reply?(@reply, @current_user, @post_id) or
                    can_moderate_reply?(@reply, @current_user)
                }
                class="flex-shrink-0 relative z-10"
              >
                <.liquid_dropdown
                  id={"reply-#{@reply.id}-dropdown"}
                  placement="top-end"
                  trigger_class="p-2 rounded-lg hover:bg-slate-100/50 dark:hover:bg-slate-700/50 transition-colors duration-200"
                  class=""
                >
                  <:trigger>
                    <.phx_icon
                      name="hero-ellipsis-horizontal"
                      class="h-4 w-4 text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300"
                    />
                  </:trigger>

                  <%!-- Report option (for others' replies) --%>
                  <:item
                    :if={
                      can_moderate_reply?(@reply, @current_user) and
                        @reply.user_id != @current_user.id
                    }
                    color="amber"
                    phx_click="report_reply"
                    phx_value_id={@reply.id}
                    phx_value_reported_user_id={@reply.user_id}
                  >
                    <.phx_icon name="hero-flag" class="h-4 w-4" />
                    <span>Report Reply</span>
                  </:item>

                  <%!-- Block option (for others' replies) --%>
                  <:item
                    :if={
                      can_moderate_reply?(@reply, @current_user) and
                        @reply.user_id != @current_user.id
                    }
                    color="rose"
                    phx_click="block_user_from_reply"
                    phx_value_id={@reply.user_id}
                    phx_value_user_name={get_reply_author_name(@reply, @current_user, @key)}
                    phx_value_reply_id={@reply.id}
                  >
                    <.phx_icon name="hero-no-symbol" class="h-4 w-4" />
                    <span>Block Author</span>
                  </:item>

                  <%!-- Delete option for reply owner or post owner --%>
                  <:item
                    :if={can_manage_reply?(@reply, @current_user, @post_id)}
                    color="rose"
                    phx_click="delete_reply"
                    phx_value_id={@reply.id}
                    data_confirm="Are you sure you want to delete this reply?"
                  >
                    <.phx_icon name="hero-trash" class="h-4 w-4" />
                    <span>Delete Reply</span>
                  </:item>
                </.liquid_dropdown>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for reply data extraction
  def get_reply_author_name(reply, current_user, key) do
    cond do
      reply.user_id == current_user.id ->
        # Current user's own reply - use their name
        case user_name(current_user, key) do
          name when is_binary(name) -> name
          # Graceful fallback for decryption issues
          :failed_verification -> "You"
          _ -> "You"
        end

      true ->
        # Other user's reply - decrypt their username from reply
        # Replies store username encrypted with same post_key as the post content
        case get_reply_post_key(reply, current_user) do
          {:ok, post_key} ->
            case decr_item(reply.username, current_user, post_key, key, reply, "username") do
              name when is_binary(name) -> name
              :failed_verification -> "Private Author"
              _ -> "Private Author"
            end

          _ ->
            "Private Author"
        end
    end
  end

  defp get_reply_author_avatar(reply, current_user, key) do
    cond do
      reply.user_id == current_user.id ->
        # Current user's own reply - use their avatar
        if show_avatar?(current_user),
          do: maybe_get_user_avatar(current_user, key) || "/images/logo.svg",
          else: "/images/logo.svg"

      true ->
        # Other user's reply
        user_connection = get_uconn_for_shared_item(reply, current_user)

        if show_avatar?(user_connection) do
          case maybe_get_avatar_src(reply, current_user, key, []) do
            avatar when is_binary(avatar) and avatar != "" -> avatar
            _ -> "/images/logo.svg"
          end
        else
          "/images/logo.svg"
        end
    end
  end

  defp get_decrypted_reply_content(reply, current_user, key) do
    case get_reply_post_key(reply, current_user) do
      {:ok, post_key} ->
        case decr_item(reply.body, current_user, post_key, key, reply, "body") do
          content when is_binary(content) -> content
          :failed_verification -> "[Could not decrypt reply]"
          _ -> "[Could not decrypt reply]"
        end

      _ ->
        "[Could not decrypt reply]"
    end
  end

  # Helper to get the post_key for a reply (same as the post it belongs to)
  def get_reply_post_key(reply, current_user) do
    # Get the post this reply belongs to with user_posts preloaded
    post = Mosslet.Repo.preload(reply, post: :user_posts).post

    # Use the existing get_post_key helper function
    case get_post_key(post, current_user) do
      encrypted_post_key when is_binary(encrypted_post_key) ->
        {:ok, encrypted_post_key}

      _ ->
        {:error, :no_access}
    end
  end

  # Helper function to check if user can manage a reply (delete)
  # Post owners can delete any replies to their posts
  # Reply owners can delete their own replies
  defp can_manage_reply?(reply, current_user, post_id) do
    # Reply owner can always delete their own reply
    if reply.user_id == current_user.id do
      true
    else
      # Check if current user owns the post this reply belongs to
      case Mosslet.Timeline.get_post(post_id) do
        %{user_id: post_user_id} -> post_user_id == current_user.id
        _ -> false
      end
    end
  end

  # Helper function to check if user can moderate a reply (report/block)
  # Any user can report/block others' replies (but not their own)
  defp can_moderate_reply?(reply, current_user) do
    reply.user_id != current_user.id
  end

  # Format content warning category for display
  defp format_content_warning_category(category) when is_binary(category) do
    case category do
      "mental_health" -> "Mental Health"
      "violence" -> "Violence"
      "substance_use" -> "Substance Use"
      "politics" -> "Politics"
      "personal" -> "Personal/Sensitive"
      "other" -> "Other"
      _ -> String.capitalize(category)
    end
  end

  defp format_content_warning_category(_), do: "Sensitive Content"

  defp format_reply_timestamp(timestamp) do
    # Use same formatting as posts for consistency
    case timestamp do
      %NaiveDateTime{} ->
        # Import the format_post_timestamp function or use a simple relative time
        relative_time = NaiveDateTime.diff(NaiveDateTime.utc_now(), timestamp)

        cond do
          relative_time < 60 -> "now"
          relative_time < 3600 -> "#{div(relative_time, 60)}m"
          relative_time < 86400 -> "#{div(relative_time, 3600)}h"
          relative_time < 2_592_000 -> "#{div(relative_time, 86400)}d"
          true -> "#{div(relative_time, 2_592_000)}mo"
        end

      _ ->
        "Unknown time"
    end
  end

  # Helper functions for depth-based reply styling
  defp reply_background_classes(depth) do
    case depth do
      0 -> "bg-white/70 dark:bg-slate-800/70 backdrop-blur-sm"
      1 -> "bg-white/60 dark:bg-slate-800/60 backdrop-blur-sm"
      2 -> "bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm"
      _ -> "bg-white/40 dark:bg-slate-800/40 backdrop-blur-sm"
    end
  end

  defp reply_border_classes(depth) do
    case depth do
      0 -> "border border-slate-200/50 dark:border-slate-700/50"
      1 -> "border border-slate-200/40 dark:border-slate-700/40"
      2 -> "border border-slate-200/30 dark:border-slate-700/30"
      _ -> "border border-slate-200/20 dark:border-slate-700/20"
    end
  end

  defp reply_hover_classes(depth) do
    case depth do
      0 ->
        "hover:border-emerald-200/70 dark:hover:border-emerald-700/70 hover:bg-emerald-50/40 dark:hover:bg-emerald-900/15"

      1 ->
        "hover:border-emerald-200/60 dark:hover:border-emerald-700/60 hover:bg-emerald-50/30 dark:hover:bg-emerald-900/12"

      2 ->
        "hover:border-emerald-200/50 dark:hover:border-emerald-700/50 hover:bg-emerald-50/20 dark:hover:bg-emerald-900/10"

      _ ->
        "hover:border-emerald-200/40 dark:hover:border-emerald-700/40 hover:bg-emerald-50/15 dark:hover:bg-emerald-900/8"
    end
  end

  defp reply_accent_classes(depth) do
    case depth do
      0 ->
        "w-1 bg-gradient-to-b from-emerald-400/80 via-teal-400/60 to-emerald-300/40 dark:from-emerald-500/80 dark:via-teal-500/60 dark:to-emerald-400/40"

      1 ->
        "w-0.5 bg-gradient-to-b from-teal-400/70 via-emerald-400/50 to-teal-300/30 dark:from-teal-500/70 dark:via-emerald-500/50 dark:to-teal-400/30"

      2 ->
        "w-0.5 bg-gradient-to-b from-cyan-400/60 via-teal-400/40 to-cyan-300/20 dark:from-cyan-500/60 dark:via-teal-500/40 dark:to-cyan-400/20"

      _ ->
        "w-px bg-gradient-to-b from-slate-400/50 via-slate-300/30 to-transparent dark:from-slate-500/50 dark:via-slate-400/30"
    end
  end

  defp reply_padding_classes(depth) do
    case depth do
      0 -> "pl-5 sm:pl-6"
      1 -> "pl-4 sm:pl-5"
      2 -> "pl-3 sm:pl-4"
      _ -> "pl-2 sm:pl-3"
    end
  end

  # Filter to show only top-level replies (not nested replies)
  defp filter_top_level_replies(replies) do
    Enum.filter(replies, fn reply ->
      # Top-level replies have no parent_reply_id
      is_nil(reply.parent_reply_id)
    end)
  end

  # Helper functions to safely handle child_replies association
  defp has_child_replies?(reply) do
    case Map.get(reply, :child_replies) do
      %Ecto.Association.NotLoaded{} -> false
      nil -> false
      [] -> false
      list when is_list(list) -> length(list) > 0
      _ -> false
    end
  end

  defp get_child_replies(reply) do
    case Map.get(reply, :child_replies) do
      %Ecto.Association.NotLoaded{} -> []
      nil -> []
      list when is_list(list) -> list
      _ -> []
    end
  end

  @doc """
  Nested reply composer for replying to specific replies
  """
  attr :form, :map, required: true
  attr :parent_reply, :map, required: true
  attr :post, :map, required: true
  attr :author_name, :string, required: true
  attr :current_user, :map, required: true
  attr :class, :any, default: ""

  def liquid_nested_reply_composer(assigns) do
    ~H"""
    <div class={[
      "nested-reply-composer relative",
      "bg-gradient-to-br from-emerald-50/80 via-teal-50/60 to-cyan-50/40",
      "dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-cyan-900/10",
      "border border-emerald-200/60 dark:border-emerald-700/40",
      "rounded-xl p-4 backdrop-blur-sm",
      "shadow-sm hover:shadow-md transition-all duration-200",
      @class
    ]}>
      <%!-- Reply context header --%>
      <div class="flex items-center gap-2 mb-3 pb-2 border-b border-emerald-200/40 dark:border-emerald-700/30">
        <.phx_icon
          name="hero-arrow-uturn-left"
          class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
        />
        <span class="text-sm text-emerald-700 dark:text-emerald-300 font-medium">
          Replying to {"@#{@author_name}"}
        </span>
        <button
          phx-click="cancel_nested_reply"
          class="ml-auto p-1 rounded-lg hover:bg-emerald-100 dark:hover:bg-emerald-800/50 text-emerald-600 dark:text-emerald-400 transition-colors duration-200"
        >
          <.phx_icon name="hero-x-mark" class="h-4 w-4" />
        </button>
      </div>

      <%!-- Nested reply form --%>
      <.form
        for={@form}
        id="nested-reply-form"
        phx-submit="submit_nested_reply"
        phx-change="validate_nested_reply"
        class="space-y-3"
      >
        <%!-- Hidden fields --%>
        <input type="hidden" name="nested_reply[parent_reply_id]" value={@parent_reply.id} />
        <input type="hidden" name="nested_reply[post_id]" value={@post.id} />
        <input type="hidden" name="nested_reply[visibility]" value={@post.visibility} />

        <%!-- Reply textarea --%>
        <div class="relative">
          <.phx_input
            field={@form[:body]}
            type="textarea"
            placeholder="Write your reply..."
            rows="3"
            class="resize-none border-emerald-200/60 dark:border-emerald-700/40 focus:border-emerald-400 dark:focus:border-emerald-500 focus:ring-emerald-500/30 bg-white/80 dark:bg-slate-800/80"
          />
        </div>

        <%!-- Action buttons --%>
        <div class="flex items-center justify-between pt-2">
          <div class="flex items-center gap-2 text-xs text-emerald-600 dark:text-emerald-400">
            <.phx_icon name="hero-lock-closed" class="h-3 w-3" />
            <span>Reply will be {String.capitalize(to_string(@post.visibility))}</span>
          </div>

          <div class="flex items-center gap-2">
            <.liquid_button
              type="button"
              variant="ghost"
              size="sm"
              color="slate"
              phx-click="cancel_nested_reply"
              class="text-xs"
            >
              Cancel
            </.liquid_button>

            <.liquid_button
              type="submit"
              size="sm"
              color="emerald"
              class="text-xs px-4"
            >
              <.phx_icon name="hero-paper-airplane" class="h-3 w-3 mr-1" /> Reply
            </.liquid_button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @doc """
  A liquid metal report post modal for content moderation.

  ## Examples

      <.liquid_report_modal
        show={@show_report_modal}
        post_id={@reported_post_id}
        reported_user_id={@reported_user_id}
        on_close="close_report_modal"
      />
  """
  attr :show, :boolean, default: false
  attr :post_id, :string, required: true
  attr :reported_user_id, :string, required: true
  attr :on_close, :string, default: "close_report_modal"
  attr :class, :any, default: ""

  def liquid_report_modal(assigns) do
    ~H"""
    <.liquid_modal
      :if={@show}
      id="report-post-modal"
      show={@show}
      on_cancel={JS.push(@on_close)}
      size="lg"
    >
      <:title>
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30">
            <.phx_icon name="hero-flag" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
          </div>
          <div>
            <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              Report this post
            </h3>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Help us keep the community safe
            </p>
          </div>
        </div>
      </:title>

      <div class="space-y-6">
        <.form
          for={%{}}
          as={:report}
          phx-submit="submit_report"
          phx-change="validate_report"
          id="report-form"
          class="space-y-6"
        >
          <input type="hidden" name="report[post_id]" value={@post_id} />
          <input type="hidden" name="report[reported_user_id]" value={@reported_user_id} />

          <%!-- Report type selection --%>
          <div class="space-y-3">
            <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
              What's the issue?
            </label>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[report_type]"
                  value="harassment"
                  class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Harassment</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Threats, bullying, or abuse
                  </div>
                </div>
              </label>

              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[report_type]"
                  value="spam"
                  class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Spam</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Unwanted or repetitive content
                  </div>
                </div>
              </label>

              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[report_type]"
                  value="content"
                  class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">
                    Inappropriate Content
                  </div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Violates community guidelines
                  </div>
                </div>
              </label>

              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[report_type]"
                  value="other"
                  class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Other</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Something else
                  </div>
                </div>
              </label>
            </div>
          </div>

          <%!-- Severity selection --%>
          <div class="space-y-3">
            <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
              How serious is this issue?
            </label>
            <div class="flex flex-wrap gap-2">
              <label class="flex items-center px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-full hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[severity]"
                  value="low"
                  class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">Minor</span>
              </label>
              <label class="flex items-center px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-full hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[severity]"
                  value="medium"
                  class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">Moderate</span>
              </label>
              <label class="flex items-center px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-full hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[severity]"
                  value="high"
                  class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">Serious</span>
              </label>
              <label class="flex items-center px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-full hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="report[severity]"
                  value="critical"
                  class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-slate-300 dark:border-slate-600"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">Critical</span>
              </label>
            </div>
          </div>

          <%!-- Reason field --%>
          <div class="space-y-2">
            <label
              for="report_reason"
              class="block text-sm font-medium text-slate-900 dark:text-slate-100"
            >
              Brief reason
            </label>
            <input
              type="text"
              name="report[reason]"
              id="report_reason"
              class="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all duration-200"
              placeholder="Why are you reporting this post?"
              maxlength="100"
            />
          </div>

          <%!-- Details field --%>
          <div class="space-y-2">
            <label
              for="report_details"
              class="block text-sm font-medium text-slate-900 dark:text-slate-100"
            >
              Additional details (optional)
            </label>
            <textarea
              name="report[details]"
              id="report_details"
              rows="3"
              class="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all duration-200 resize-none"
              placeholder="Provide any additional context that might help our moderation team..."
              maxlength="1000"
            ></textarea>
          </div>

          <%!-- Privacy notice --%>
          <div class="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700">
            <div class="flex gap-3">
              <.phx_icon
                name="hero-shield-check"
                class="h-5 w-5 text-slate-600 dark:text-slate-400 flex-shrink-0 mt-0.5"
              />
              <div class="text-sm text-slate-700 dark:text-slate-300">
                <p class="font-medium mb-1">Your report is confidential</p>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  The reported user won't know who submitted this report. We'll review it according to our community guidelines and take appropriate action.
                </p>
              </div>
            </div>
          </div>

          <%!-- Action buttons --%>
          <div class="flex justify-end gap-3 pt-2">
            <.liquid_button
              type="button"
              variant="ghost"
              color="slate"
              phx-click={@on_close}
            >
              Cancel
            </.liquid_button>
            <.liquid_button
              type="submit"
              color="amber"
              icon="hero-flag"
            >
              Submit Report
            </.liquid_button>
          </div>
        </.form>
      </div>
    </.liquid_modal>
    """
  end

  @doc """
  A liquid metal block user modal for user management.

  ## Examples

      <.liquid_block_modal
        show={@show_block_modal}
        user_id={@blocked_user_id}
        user_name={@blocked_user_name}
        on_close="close_block_modal"
      />
  """
  attr :show, :boolean, default: false
  attr :user_id, :string, required: true
  attr :user_name, :string, required: true
  attr :on_close, :string, default: "close_block_modal"
  attr :class, :any, default: ""

  def liquid_block_modal(assigns) do
    ~H"""
    <.liquid_modal
      :if={@show}
      id="block-user-modal"
      show={@show}
      on_cancel={JS.push(@on_close)}
      size="md"
    >
      <:title>
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-xl bg-gradient-to-br from-rose-100 to-rose-100 dark:from-rose-900/30 dark:to-rose-900/30">
            <.phx_icon name="hero-no-symbol" class="h-5 w-5 text-rose-600 dark:text-rose-400" />
          </div>
          <div>
            <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              Block {@user_name}
            </h3>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              They won't be able to interact with you
            </p>
          </div>
        </div>
      </:title>

      <div class="space-y-6">
        <.form
          for={%{}}
          as={:block}
          phx-submit="submit_block"
          phx-change="validate_block"
          id="block-form"
          class="space-y-6"
        >
          <input type="hidden" name="block[blocked_id]" value={@user_id} />

          <%!-- Block type selection --%>
          <div class="space-y-3">
            <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
              What would you like to block?
            </label>
            <div class="space-y-2">
              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="block[block_type]"
                  value="full"
                  checked="checked"
                  class="mt-1 h-4 w-4 text-rose-600 focus:ring-rose-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Everything</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Block all posts, replies, and interactions from this user
                  </div>
                </div>
              </label>

              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="block[block_type]"
                  value="posts_only"
                  class="mt-1 h-4 w-4 text-rose-600 focus:ring-rose-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Posts only</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Hide their posts but allow replies to your content
                  </div>
                </div>
              </label>

              <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                <input
                  type="radio"
                  name="block[block_type]"
                  value="replies_only"
                  class="mt-1 h-4 w-4 text-rose-600 focus:ring-rose-500 border-slate-300 dark:border-slate-600"
                />
                <div class="ml-3">
                  <div class="font-medium text-slate-900 dark:text-slate-100">Replies only</div>
                  <div class="text-sm text-slate-600 dark:text-slate-400">
                    Block replies but still see their posts
                  </div>
                </div>
              </label>
            </div>
          </div>

          <%!-- Reason field --%>
          <div class="space-y-2">
            <label
              for="block_reason"
              class="block text-sm font-medium text-slate-900 dark:text-slate-100"
            >
              Reason for blocking (optional)
            </label>
            <input
              type="text"
              name="block[reason]"
              id="block_reason"
              class="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-rose-500 focus:border-rose-500 transition-all duration-200"
              placeholder="Why are you blocking this user?"
              maxlength="200"
            />
          </div>

          <%!-- What happens notice --%>
          <div class="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700">
            <div class="flex gap-3">
              <.phx_icon
                name="hero-information-circle"
                class="h-5 w-5 text-slate-600 dark:text-slate-400 flex-shrink-0 mt-0.5"
              />
              <div class="text-sm text-slate-700 dark:text-slate-300">
                <p class="font-medium mb-1">What happens when you block someone:</p>
                <ul class="text-slate-600 dark:text-slate-400 space-y-1">
                  <li>• They won't be notified that you blocked them</li>
                  <li>• You won't see their content in your timeline</li>
                  <li>• They won't be able to interact with your posts</li>
                  <li>• You can unblock them anytime from your settings</li>
                </ul>
              </div>
            </div>
          </div>

          <%!-- Action buttons --%>
          <div class="flex justify-end gap-3 pt-2">
            <.liquid_button
              type="button"
              variant="ghost"
              color="slate"
              phx-click={@on_close}
            >
              Cancel
            </.liquid_button>
            <.liquid_button
              type="submit"
              color="rose"
              icon="hero-no-symbol"
            >
              Block Author
            </.liquid_button>
          </div>
        </.form>
      </div>
    </.liquid_modal>
    """
  end

  @doc """
  Compact liquid filter select for admin interfaces.
  Follows the same liquid metal design patterns as liquid_select but optimized for filter forms.
  """
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :options, :list, required: true
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_filter_select(assigns) do
    ~H"""
    <div class={["group relative", @class]}>
      <%!-- Enhanced liquid background effect on focus (matching main liquid_select) --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl pointer-events-none">
      </div>

      <%!-- Enhanced shimmer effect on focus (matching main liquid_select) --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl pointer-events-none">
      </div>

      <%!-- Focus ring with liquid metal styling (matching main liquid_select) --%>
      <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm pointer-events-none">
      </div>

      <%!-- Secondary focus ring for better definition (matching main liquid_select) --%>
      <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100 pointer-events-none">
      </div>

      <%!-- Select field with enhanced contrast (matching main liquid_select styling) --%>
      <select
        name={@name}
        class={[
          "relative z-10 block w-full rounded-xl px-4 py-3 pr-10 text-slate-900 dark:text-slate-100",
          "bg-slate-50 dark:bg-slate-900",
          "border-2 border-slate-200 dark:border-slate-700",
          "hover:border-slate-300 dark:hover:border-slate-600",
          "focus:border-emerald-500 dark:focus:border-emerald-400",
          "focus:outline-none focus:ring-0",
          "transition-all duration-200 ease-out",
          "sm:text-sm sm:leading-6",
          "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
          "focus:bg-white dark:focus:bg-slate-800",
          "appearance-none cursor-pointer",
          "bg-no-repeat bg-right",
          "[background-image:none]"
        ]}
        {@rest}
      >
        <option :for={{value, label} <- @options} value={value} selected={value == @value}>
          {label}
        </option>
      </select>

      <%!-- Custom dropdown arrow with liquid styling (matching main liquid_select) --%>
      <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none z-20">
        <svg
          class="h-5 w-5 text-slate-400 dark:text-slate-500 group-focus-within:text-emerald-500 dark:group-focus-within:text-emerald-400 transition-colors duration-200"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fill-rule="evenodd"
            d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
            clip-rule="evenodd"
          />
        </svg>
      </div>
    </div>
    """
  end

  @doc """
  Enhanced privacy controls component for composer with progressive disclosure.
  Follows existing patterns like content warning section with emerald theming.
  """
  attr :form, :any, required: true
  attr :selector, :string, required: true
  attr :class, :any, default: ""

  def liquid_enhanced_privacy_controls(assigns) do
    ~H"""
    <div class={[
      "p-4 rounded-xl border transition-all duration-300 ease-out",
      "bg-emerald-50/50 dark:bg-emerald-900/20",
      "border-emerald-200/60 dark:border-emerald-700/50",
      @class
    ]}>
      <div class="flex items-center gap-2 mb-4">
        <.phx_icon
          name="hero-shield-check"
          class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
        />
        <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
          Privacy Controls
        </span>
      </div>

      <div class="space-y-4">
        <%!-- Quick Visibility Options (Level 2) --%>
        <div class="space-y-3">
          <h5 class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Who can see this?
          </h5>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
            <%!-- Private Option --%>
            <.liquid_privacy_radio_option
              name="visibility"
              value="private"
              current_value={@selector}
              icon="hero-lock-closed"
              label="Private"
              description="Only you"
            />

            <%!-- Connections Option --%>
            <.liquid_privacy_radio_option
              name="visibility"
              value="connections"
              current_value={@selector}
              icon="hero-user-group"
              label="Connections"
              description="Your network"
            />

            <%!-- Public Option --%>
            <.liquid_privacy_radio_option
              name="visibility"
              value="public"
              current_value={@selector}
              icon="hero-globe-alt"
              label="Public"
              description="Everyone"
            />
          </div>
        </div>

        <%!-- Interaction Controls (Level 2) --%>
        <div class="space-y-3">
          <h5 class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Interaction Controls
          </h5>

          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <%!-- Allow Replies --%>
            <.liquid_checkbox
              field={@form[:allow_replies]}
              label="Replies"
              help="Others can reply"
            />

            <%!-- Allow Shares --%>
            <.liquid_checkbox
              field={@form[:allow_shares]}
              label="Sharing"
              help="Others can repost"
            />

            <%!-- Allow Bookmarks --%>
            <.liquid_checkbox
              field={@form[:allow_bookmarks]}
              label="Bookmarks"
              help="Others can save"
            />

            <%!-- Require Connection to Reply --%>
            <.liquid_checkbox
              field={@form[:require_follow_to_reply]}
              label="Connections only"
              help="Must be connected to reply"
            />
          </div>
        </div>

        <%!-- Additional Controls (Level 2) --%>
        <div class="space-y-3">
          <h5 class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Additional Options
          </h5>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <%!-- Mature Content --%>
            <.liquid_checkbox
              field={@form[:mature_content]}
              label="Mature content"
              help="Mark as sensitive"
            />

            <%!-- Temporary Post --%>
            <.liquid_checkbox
              field={@form[:is_ephemeral]}
              label="Temporary post"
              help="Auto-delete after time limit"
            />
          </div>

          <%!-- Expiration Controls (when ephemeral is enabled) --%>
          <div
            :if={@form[:is_ephemeral].value}
            class="mt-3 p-3 rounded-lg bg-amber-50/50 dark:bg-amber-900/20 border border-amber-200/60 dark:border-amber-700/30"
          >
            <.liquid_select_custom
              field={@form[:expires_at]}
              label="Delete after"
              prompt="Select timeframe..."
              color="amber"
              class="text-sm"
              options={[
                {"1 hour", "1_hour"},
                {"6 hours", "6_hours"},
                {"24 hours", "24_hours"},
                {"7 days", "7_days"},
                {"30 days", "30_days"}
              ]}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Radio option component for privacy selection.
  Follows existing liquid metal patterns with compact design for composer.
  """
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :current_value, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true

  def liquid_privacy_radio_option(assigns) do
    assigns = assign(assigns, :checked, assigns.value == assigns.current_value)

    ~H"""
    <label class={[
      "group relative cursor-pointer overflow-hidden rounded-lg p-3 transition-all duration-200 ease-out",
      "border-2 hover:scale-[1.02] focus-within:scale-[1.02]",
      if(@checked,
        do: "border-emerald-300 dark:border-emerald-600 bg-emerald-50/50 dark:bg-emerald-900/20",
        else:
          "border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800/50 hover:border-emerald-200 dark:hover:border-emerald-700"
      )
    ]}>
      <%!-- Liquid background effect --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-300 ease-out",
        "bg-gradient-to-br from-emerald-50/30 via-emerald-100/20 to-emerald-50/30",
        "dark:from-emerald-900/15 dark:via-emerald-800/10 dark:to-emerald-900/15",
        if(@checked, do: "opacity-100 group-hover:opacity-100", else: "group-hover:opacity-100")
      ]}>
      </div>

      <%!-- Shimmer effect --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-500 ease-out",
        "bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent",
        "dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full"
      ]}>
      </div>

      <div class="relative flex flex-col items-center text-center gap-2">
        <%!-- Radio input --%>
        <input
          type="radio"
          name={@name}
          value={@value}
          checked={@checked}
          class="sr-only"
          phx-click="update_privacy_visibility"
          phx-value-visibility={@value}
        />

        <%!-- Icon --%>
        <div class={[
          "p-2 rounded-lg transition-all duration-200 ease-out",
          if(@checked,
            do: "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400",
            else:
              "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400 group-hover:bg-emerald-100 dark:group-hover:bg-emerald-900/30 group-hover:text-emerald-600 dark:group-hover:text-emerald-400"
          )
        ]}>
          <.phx_icon name={@icon} class="h-4 w-4" />
        </div>

        <%!-- Label --%>
        <div>
          <div class={[
            "text-sm font-medium transition-colors duration-200 ease-out",
            if(@checked,
              do: "text-emerald-700 dark:text-emerald-300",
              else:
                "text-slate-900 dark:text-slate-100 group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
            )
          ]}>
            {@label}
          </div>
          <div class={[
            "text-xs transition-colors duration-200 ease-out",
            if(@checked,
              do: "text-emerald-600 dark:text-emerald-400",
              else: "text-slate-500 dark:text-slate-400"
            )
          ]}>
            {@description}
          </div>
        </div>
      </div>
    </label>
    """
  end
end
