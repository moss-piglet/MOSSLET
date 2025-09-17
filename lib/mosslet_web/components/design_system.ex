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
  attr :color, :string, default: "teal", values: ~w(teal blue purple amber rose cyan indigo)
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
          "relative inline-flex items-center justify-center gap-2 font-semibold",
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
          "group-hover:opacity-100 hover:opacity-100 hover:translate-x-full -translate-x-full",
          "rounded-full"
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
          "relative inline-flex items-center justify-center gap-2 font-semibold",
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
          "group-hover:opacity-100 hover:opacity-100 hover:translate-x-full -translate-x-full",
          "rounded-full"
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
      "hover:bg-gradient-to-r hover:from-#{color}-50 hover:to-#{secondary_color_for(color)}-50",
      "dark:hover:from-#{color}-900/20 dark:hover:to-#{secondary_color_for(color)}-900/20",
      "hover:text-#{color}-700 dark:hover:text-#{color}-300",
      "focus-visible:outline-slate-600"
    ]
  end

  # Color gradient mappings
  defp gradient_for_color("teal"), do: "bg-gradient-to-r from-teal-500 to-emerald-500"
  defp gradient_for_color("blue"), do: "bg-gradient-to-r from-blue-500 to-cyan-500"
  defp gradient_for_color("purple"), do: "bg-gradient-to-r from-purple-500 to-violet-500"
  defp gradient_for_color("amber"), do: "bg-gradient-to-r from-amber-500 to-orange-500"
  defp gradient_for_color("rose"), do: "bg-gradient-to-r from-rose-500 to-pink-500"
  defp gradient_for_color("cyan"), do: "bg-gradient-to-r from-cyan-500 to-teal-500"
  defp gradient_for_color("indigo"), do: "bg-gradient-to-r from-indigo-500 to-blue-500"
  # fallback
  defp gradient_for_color(_), do: "bg-gradient-to-r from-teal-500 to-emerald-500"

  # Primary color for each variant (for shadows, focus, etc.)
  defp primary_color_for("teal"), do: "emerald"
  defp primary_color_for("blue"), do: "cyan"
  defp primary_color_for("purple"), do: "violet"
  defp primary_color_for("amber"), do: "orange"
  defp primary_color_for("rose"), do: "pink"
  defp primary_color_for("cyan"), do: "teal"
  defp primary_color_for("indigo"), do: "blue"
  # fallback
  defp primary_color_for(_), do: "emerald"

  # Secondary color for gradients and hover states
  defp secondary_color_for("teal"), do: "emerald"
  defp secondary_color_for("blue"), do: "cyan"
  defp secondary_color_for("purple"), do: "violet"
  defp secondary_color_for("amber"), do: "orange"
  defp secondary_color_for("rose"), do: "pink"
  defp secondary_color_for("cyan"), do: "teal"
  defp secondary_color_for("indigo"), do: "blue"
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
end
