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
  """
  attr :type, :string, default: "button"
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :variant, :string, default: "primary", values: ~w(primary secondary ghost)

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
          "bg-gradient-to-r from-transparent via-white/20 to-transparent",
          "group-hover:opacity-100 group-hover:translate-x-full -translate-x-full",
          "rounded-full overflow-hidden pointer-events-none"
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
          "bg-gradient-to-r from-transparent via-white/20 to-transparent",
          "group-hover:opacity-100 group-hover:translate-x-full -translate-x-full",
          "rounded-full overflow-hidden pointer-events-none"
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
                "relative w-full max-h-[90vh] h-auto flex flex-col overflow-hidden",
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

              <%!-- Content area with responsive scrolling --%>
              <div id={"#{@id}-content"} class="flex-1 overflow-y-auto p-4 sm:p-6">
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

  # Container max-width classes following design system breakpoints
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
            size="xs"
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

  # Private helper functions for badges
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
          <%!-- Floating gradient orbs for liquid metal effect --%>
          <div
            class="absolute left-1/2 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
            aria-hidden="true"
          >
            <div
              class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
              style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
            >
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
end
