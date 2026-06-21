defmodule MossletWeb.DesignSystem do
  @moduledoc """
  Reusable components following the Mosslet Design System.

  This module provides consistent implementations of common UI patterns
  using our liquid metal aesthetic with teal-to-emerald gradients.

  See DESIGN_SYSTEM.md for detailed guidelines and principles.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  # Import components (phx_icon is delegated via local defp)

  # Import helper functions
  import MossletWeb.Helpers,
    only: [
      user_name: 2
    ]

  # Import StatusHelpers for consistent status message handling
  import MossletWeb.Helpers.StatusHelpers,
    only: [
      get_status_fallback_message: 1
    ]

  alias Mosslet.Accounts.Scope
  alias Phoenix.LiveView.JS

  @doc """
  Extracts current_user and key from current_scope assign for backwards compatibility.

  Components should accept `current_scope` and use this helper to derive user/key.
  This allows gradual migration from passing `current_user` + `key` separately
  to passing just `current_scope`.

  ## Example

      def my_component(assigns) do
        assigns = assign_scope_fields(assigns)
        # Now @current_user and @key are available in the template
      end
  """
  def assign_scope_fields(assigns) do
    assigns
    |> assign_new(:current_user, fn ->
      case assigns[:current_scope] do
        %Scope{user: user} -> user
        _ -> assigns[:current_user]
      end
    end)
    |> assign_new(:key, fn ->
      case assigns[:current_scope] do
        %Scope{key: key} -> key
        _ -> assigns[:key]
      end
    end)
  end

  # Custom modal functions that prevent scroll jumping and ensure viewport positioning
  def liquid_show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def liquid_hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
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
    values: ~w(teal emerald blue purple amber rose pink cyan indigo slate orange)

  attr :icon, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :class, :any, default: ""
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :patch, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-submit data-tippy-content phx-hook id rel target)
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
          "group relative overflow-hidden inline-flex items-center justify-center gap-2 font-semibold",
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
      class={[
        "group relative overflow-hidden inline-flex items-center justify-center gap-2 font-semibold",
        "transition-all duration-200 ease-out transform-gpu will-change-transform",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
        "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100",
        "phx-submit-loading:opacity-80 phx-submit-loading:cursor-wait",
        "phx-click-loading:opacity-80 phx-click-loading:cursor-wait phx-click-loading:scale-95",
        button_size_classes(@size),
        button_variant_classes(@variant, @color),
        @class
      ]}
      {@rest}
    >
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

      <svg
        class="hidden phx-submit-loading:inline-block phx-click-loading:inline-block h-4 w-4 animate-spin relative z-10 mr-1"
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
      >
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
        </circle>
        <path
          class="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        >
        </path>
      </svg>

      <.phx_icon
        :if={@icon}
        name={@icon}
        class={[
          "h-4 w-4 relative z-10 transition-transform duration-200 ease-out phx-submit-loading:hidden phx-click-loading:hidden",
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
  attr :padding, :string, default: "md", values: ~w(none sm md lg)
  attr :heading_level, :integer, default: 2, values: 1..6
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
        <.dynamic_heading
          level={@heading_level}
          class="text-lg font-semibold text-slate-900 dark:text-slate-100"
        >
          {render_slot(@title)}
        </.dynamic_heading>
      </div>

      <div class="relative">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :level, :integer, required: true
  attr :class, :any, default: ""
  slot :inner_block, required: true

  defp dynamic_heading(%{level: 1} = assigns) do
    ~H"""
    <h1 class={@class}>{render_slot(@inner_block)}</h1>
    """
  end

  defp dynamic_heading(%{level: 2} = assigns) do
    ~H"""
    <h2 class={@class}>{render_slot(@inner_block)}</h2>
    """
  end

  defp dynamic_heading(%{level: 3} = assigns) do
    ~H"""
    <h3 class={@class}>{render_slot(@inner_block)}</h3>
    """
  end

  defp dynamic_heading(%{level: 4} = assigns) do
    ~H"""
    <h4 class={@class}>{render_slot(@inner_block)}</h4>
    """
  end

  defp dynamic_heading(%{level: 5} = assigns) do
    ~H"""
    <h5 class={@class}>{render_slot(@inner_block)}</h5>
    """
  end

  defp dynamic_heading(%{level: 6} = assigns) do
    ~H"""
    <h6 class={@class}>{render_slot(@inner_block)}</h6>
    """
  end

  @doc """
  Modern footer component with liquid metal styling.

  ## Examples

      <.liquid_footer current_scope={@current_scope} />
  """
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
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

        <%!-- Navigation links organized into grouped columns --%>
        <nav class="mb-16">
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-8 max-w-4xl mx-auto">
            <%!-- Company Column --%>
            <div class="space-y-3">
              <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 uppercase tracking-wider">
                Company
              </h3>
              <ul class="space-y-2">
                <.footer_link href="/about" label="About" />
                <.footer_link href="/blog" label="Blog" />
                <.footer_link href="/press" label="Press" />
                <.footer_link href="/updates" label="Updates" />
              </ul>
            </div>

            <%!-- Product Column --%>
            <div class="space-y-3">
              <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 uppercase tracking-wider">
                Product
              </h3>
              <ul class="space-y-2">
                <.footer_link href="/features" label="Features" />
                <.footer_link href="/pricing" label="Pricing" />
                <.footer_link href="/family-plan" label="Family" />
                <.footer_link href="/business-plan" label="Business" />
                <.footer_link href="/discover" label="Discover" />
              </ul>
            </div>

            <%!-- Resources Column --%>
            <div class="space-y-3">
              <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 uppercase tracking-wider">
                Resources
              </h3>
              <ul class="space-y-2">
                <%!-- <.footer_link href="/download" label="Download" /> --%>
                <.footer_link href="/faq" label="FAQ" />
                <.footer_link href="/support" label="Support" />
                <.footer_link href="/safety" label="Safety" />
                <.footer_link href="/referrals" label="Referrals" />
              </ul>
            </div>

            <%!-- Legal Column --%>
            <div class="space-y-3">
              <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 uppercase tracking-wider">
                Legal
              </h3>
              <ul class="space-y-2">
                <.footer_link href="/privacy" label="Privacy" />
                <.footer_link href="/terms" label="Terms" />
              </ul>
            </div>
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
              href={~p"/terms"}
              external={false}
              aria_label="MOSSLET terms and conditions"
              tooltip="MOSSLET terms and conditions"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="h-5 w-5"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"
                />
              </svg>
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
            <div class="flex items-center justify-center lg:justify-end gap-4 mt-3">
              <.link
                href="https://climate.stripe.com/0YsHsR"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-2 text-xs text-slate-500 dark:text-slate-500 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors duration-200 group"
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

  defp footer_link(assigns) do
    ~H"""
    <li>
      <.link
        href={@href}
        class="group relative text-sm text-slate-600 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors duration-200"
      >
        {@label}
      </.link>
    </li>
    """
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
  attr :modal_portal, :boolean, default: true
  slot :title
  slot :inner_block, required: true

  def liquid_modal(assigns) do
    ~H"""
    <.portal :if={@modal_portal && @show} id={"#{@id}-portal"} target="body">
      <.liquid_modal_content {assigns} />
    </.portal>

    <.liquid_modal_content :if={!@modal_portal && @show} {assigns} />
    """
  end

  defp liquid_modal_content(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && liquid_show_modal(@id)}
      phx-remove={liquid_hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="fixed top-0 left-0 w-screen h-screen z-[60] hidden"
      style="position: fixed !important;"
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
        class="fixed top-0 left-0 right-0 bottom-0 z-50 flex items-center justify-center p-1 sm:p-4 lg:p-6"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        style="position: fixed !important; top: 0 !important; left: 0 !important; right: 0 !important; bottom: 0 !important;"
      >
        <div class="flex min-h-full items-center justify-center p-1 sm:p-4 lg:p-6">
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class={
              [
                "relative w-full max-h-[90dvh] sm:max-h-[95vh] min-h-0 flex flex-col overflow-y-auto",
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
  attr :section_padding, :boolean, default: false
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

          # Section padding for marketing pages
          @section_padding && "py-12 md:py-16 lg:py-20",

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
  defp gradient_for_color("pink"), do: "bg-gradient-to-r from-pink-500 to-fuchsia-500"
  defp gradient_for_color("cyan"), do: "bg-gradient-to-r from-cyan-500 to-teal-500"
  defp gradient_for_color("indigo"), do: "bg-gradient-to-r from-indigo-500 to-blue-500"
  defp gradient_for_color("slate"), do: "bg-gradient-to-r from-slate-500 to-slate-600"
  defp gradient_for_color("orange"), do: "bg-gradient-to-r from-orange-500 to-amber-500"
  # fallback
  defp gradient_for_color(_), do: "bg-gradient-to-r from-teal-500 to-emerald-500"

  # Primary color for each variant (for shadows, focus, etc.)
  defp primary_color_for("teal"), do: "emerald"
  defp primary_color_for("emerald"), do: "teal"
  defp primary_color_for("blue"), do: "cyan"
  defp primary_color_for("purple"), do: "violet"
  defp primary_color_for("amber"), do: "orange"
  defp primary_color_for("rose"), do: "pink"
  defp primary_color_for("pink"), do: "fuchsia"
  defp primary_color_for("cyan"), do: "teal"
  defp primary_color_for("indigo"), do: "blue"
  defp primary_color_for("slate"), do: "slate"
  defp primary_color_for("orange"), do: "amber"
  # fallback
  defp primary_color_for(_), do: "emerald"

  # Secondary color for gradients and hover states
  defp secondary_color_for("teal"), do: "emerald"
  defp secondary_color_for("emerald"), do: "teal"
  defp secondary_color_for("blue"), do: "cyan"
  defp secondary_color_for("purple"), do: "violet"
  defp secondary_color_for("amber"), do: "orange"
  defp secondary_color_for("rose"), do: "pink"
  defp secondary_color_for("pink"), do: "fuchsia"
  defp secondary_color_for("cyan"), do: "teal"
  defp secondary_color_for("indigo"), do: "blue"
  defp secondary_color_for("slate"), do: "slate"
  defp secondary_color_for("orange"), do: "amber"
  # fallback
  defp secondary_color_for(_), do: "emerald"

  defp card_padding_classes("none"), do: "p-0"
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
  attr :note_disclosure, :string, default: nil
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
        <h2 class="text-base font-semibold leading-7 text-emerald-700 dark:text-emerald-400">
          {@title}
        </h2>
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
          <span :if={@period != ""} class="text-lg text-slate-600 dark:text-slate-400 font-medium">
            {@period}
          </span>
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
        <small :if={@note && !@note_disclosure} class="block mt-2 text-slate-500">{@note}</small>
        <small
          :if={@note && @note_disclosure}
          id={"note-disclosure-#{String.downcase(@title)}"}
          class="block mt-2 text-slate-500 cursor-help group transition-colors duration-200 hover:text-emerald-600 dark:hover:text-emerald-400"
          phx-hook="TippyHook"
          data-tippy-content={@note_disclosure}
          data-tippy-theme="light"
          data-tippy-placement="bottom"
          data-tippy-maxWidth="400"
          data-tippy-interactive="true"
        >
          {@note}
          <.phx_icon
            name="hero-information-circle"
            class="inline-block h-3 w-3 ml-1 opacity-60 group-hover:opacity-100 transition-opacity duration-200 align-middle -mt-0.5"
          />
        </small>
      </p>

      <%!-- Features list --%>
      <ul
        :if={@features != []}
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
                  <div class="inline-block">
                    <div class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                      From $40/yr
                    </div>
                    <div class="text-xs text-emerald-600 dark:text-emerald-400">
                      Or lifetime
                    </div>
                  </div>
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
            *** Collects minimal operational data necessary for service functionality
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
      <div class="group relative overflow-hidden rounded-xl p-3 transition-all duration-200 ease-out hover:bg-emerald-50 dark:hover:bg-emerald-900/20">
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
              class="mt-1 text-sm text-slate-600 dark:text-slate-400 leading-relaxed"
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
        class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed"
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
  attr :phx_debounce, :string, default: nil
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
          phx-debounce={if @phx_debounce, do: @phx_debounce}
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
        class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed"
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
            "appearance-none cursor-pointer bg-none",
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
        class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed"
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
        class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed"
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
  attr :aria_label, :string, default: nil
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

    # Compute effective aria-label for accessibility
    assigns =
      assign(
        assigns,
        :effective_aria_label,
        assigns.aria_label || if(assigns.label == "", do: assigns.prompt, else: nil)
      )

    ~H"""
    <div phx-feedback-for={@name} class={["space-y-3", @class]}>
      <%!-- Label --%>
      <label
        :if={@label != ""}
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
          aria-label={@effective_aria_label}
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
            "appearance-none cursor-pointer bg-none",
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
        class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed"
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

  defp badge_soft_color_classes("zinc"),
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
  defp badge_solid_color_classes("zinc"), do: "bg-gradient-to-r from-slate-500 to-slate-600"
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

  defp badge_outline_color_classes("zinc"),
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
  defp modal_size_classes("sm"), do: "w-full min-w-[280px] sm:min-w-[384px] max-w-sm sm:max-w-md"
  defp modal_size_classes("md"), do: "w-full min-w-[320px] sm:min-w-[512px] max-w-lg sm:max-w-xl"

  defp modal_size_classes("lg"),
    do:
      "w-full min-w-[320px] sm:min-w-[640px] lg:min-w-[768px] max-w-xl sm:max-w-2xl lg:max-w-3xl"

  defp modal_size_classes("xl"),
    do:
      "w-full min-w-[320px] sm:min-w-[768px] lg:min-w-[1024px] max-w-2xl sm:max-w-3xl lg:max-w-5xl"

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

  Supports two modes:
  - **Classic mode**: Pass `src` with a data URL or path (server-decrypted avatar)
  - **ZK mode**: Pass `encrypted_avatar_data` (map with `:encrypted_blob_b64` and `:sealed_key`)
    to render with the `DecryptAvatar` hook for browser-side decryption. Requires a unique `id`.

  ## Examples

      <.liquid_avatar src="/path/to/avatar.jpg" name="John Doe" size="md" />
      <.liquid_avatar src="/path/to/avatar.jpg" name="Jane" size="lg" status="online" />
      <.liquid_avatar name="Anonymous" size="sm" verified={true} />
      <.liquid_avatar encrypted_avatar_data={get_encrypted_avatar_data(@user, @key)} id="my-avatar" name="John" />
  """
  attr :src, :string, default: nil
  attr :name, :string, required: true
  attr :size, :string, default: "md", values: ~w(xs sm md lg xl xxl)
  attr :status, :string, default: "offline", values: ~w(online calm active away busy offline)
  attr :status_message, :string, default: nil
  attr :verified, :boolean, default: false
  attr :class, :any, default: ""
  attr :clickable, :boolean, default: false
  attr :user_id, :string, default: nil, doc: "user_id for targeting status updates via JS"

  attr :id, :string,
    default: nil,
    doc: "Unique identifier for this avatar context (e.g., post ID)"

  attr :show_status, :boolean,
    default: true,
    doc: "Whether to show the status indicator (based on privacy settings)"

  attr :alt_text, :string,
    default: nil,
    doc: "Custom alt text for the avatar image (e.g., decrypted avatar_alt_text)"

  attr :encrypted_avatar_data, :map,
    default: nil,
    doc: "ZK mode: map with :encrypted_blob_b64 and :sealed_key for browser-side decryption"

  attr :encrypted_status_data, :map,
    default: nil,
    doc:
      "ZK mode: map with :encrypted_status_message and :sealed_key for browser-side status message decryption"

  attr :rest, :global

  def liquid_avatar(assigns) do
    zk_mode? = not is_nil(assigns.encrypted_avatar_data)

    assigns =
      assigns
      |> assign(:zk_mode?, zk_mode?)
      |> assign(:avatar_url, if(zk_mode?, do: nil, else: assigns.src || "/images/logo.svg"))
      |> assign(:computed_alt, assigns.alt_text || "#{assigns.name} avatar")

    ~H"""
    <div
      class={[
        "relative flex-shrink-0 group/avatar",
        avatar_container_size_classes(@size),
        if(@clickable, do: "cursor-pointer", else: ""),
        @class
      ]}
      {@rest}
      data-user-id={@user_id}
    >
      <%!-- Main avatar container with liquid styling --%>
      <div class={[
        "relative overflow-hidden transition-all duration-300 ease-out transform-gpu",
        avatar_size_classes(@size),
        "rounded-xl",
        if(@clickable,
          do: "group-hover/avatar:scale-105 group-active/avatar:scale-95",
          else: "group-hover/avatar:scale-[1.02]"
        )
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

        <%!-- Shimmer effect on hover (always enabled for status avatars) --%>
        <div class={[
          "absolute inset-0 opacity-0 transition-all duration-500 ease-out",
          "bg-gradient-to-r from-transparent via-emerald-200/40 to-transparent",
          "dark:via-emerald-400/20",
          "group-hover/avatar:opacity-100 group-hover/avatar:translate-x-full -translate-x-full"
        ]}>
        </div>

        <%!-- Avatar image: ZK mode (browser-side decryption) or classic mode --%>
        <img
          :if={@zk_mode?}
          id={"zk-avatar-#{@id}"}
          phx-hook="DecryptAvatar"
          data-encrypted-blob={@encrypted_avatar_data[:encrypted_blob_b64]}
          data-sealed-key={@encrypted_avatar_data[:sealed_key]}
          alt={@computed_alt}
          class="relative w-full h-full object-cover"
          loading="lazy"
        />
        <img
          :if={!@zk_mode?}
          src={@avatar_url}
          alt={@computed_alt}
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

      <%!-- Status indicator with enhanced status message card (triggers on avatar hover) --%>
      <div :if={not is_nil(@status) and @show_status}>
        <MossletWeb.DesignSystem.liquid_user_status_indicator
          id={"avatar-status-#{@id}-#{@status}"}
          status={@status}
          animate={true}
          class=""
        />

        <%!-- Enhanced status message card --%>
        <.liquid_status_message_card
          id={"status-card-#{@id}-#{@status}"}
          status={@status}
          message={@status_message}
          encrypted_status_data={@encrypted_status_data}
          position="right"
          class=""
        />
      </div>
    </div>
    """
  end

  defp humanize_upload_error(:too_large, _max_size), do: "File is too large (max 10MB)"

  defp humanize_upload_error(:too_many_files, max_entries),
    do: "Too many files (max #{max_entries} photos)"

  defp humanize_upload_error(:not_accepted, _rest),
    do: "File type not supported (GIF, JPG, PNG, WEBP, HEIC/HEIF only)"

  defp humanize_upload_error(error, _rest), do: "Upload error: #{error}"

  @doc """
  Liquid avatar upload component with detailed progress feedback.
  Shows processing stages (receiving, converting, resizing, checking safety, encrypting, uploading).
  """
  attr :upload, :map, required: true
  attr :upload_stage, :any, default: nil
  attr :current_avatar_src, :string, default: nil
  attr :user, :map, required: true
  attr :encryption_key, :string, required: true
  attr :url, :string, default: nil
  attr :on_delete, :string, default: nil
  attr :class, :any, default: nil
  attr :alt_text, :string, default: nil
  attr :crop, :map, default: nil
  attr :preview_data_url, :string, default: nil

  attr :encrypted_avatar_data, :map,
    default: nil,
    doc: "ZK mode: encrypted avatar data for browser-side decryption"

  def liquid_avatar_upload(assigns) do
    ~H"""
    <div class={["space-y-4", @class]}>
      <div class="flex flex-col sm:flex-row items-start sm:items-center gap-6">
        <div class="flex items-center gap-4 shrink-0">
          <div class="relative shrink-0">
            <.liquid_avatar
              src={@current_avatar_src}
              name={user_name(@user, @encryption_key) || "User"}
              size="xl"
              status={to_string(@user.status || "offline")}
              user_id={@user.id}
              show_status={false}
              encrypted_avatar_data={@encrypted_avatar_data}
              id={"avatar-upload-preview-#{@user.id}"}
            />
            <button
              :if={(@current_avatar_src || @encrypted_avatar_data) && @on_delete}
              type="button"
              id="delete-avatar-button"
              phx-click={@on_delete}
              data-confirm="Are you sure you want to remove your avatar?"
              class="absolute -top-1 -right-1 w-7 h-7 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-lg transition-all duration-200 hover:scale-110"
              phx-hook="TippyHook"
              data-tippy-content="Remove avatar"
              aria-label="Remove avatar"
            >
              <.phx_icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </div>

          <%= if Enum.any?(@upload.entries) || @preview_data_url do %>
            <div class="flex items-center gap-3 shrink-0">
              <.phx_icon
                name="hero-arrow-right"
                class="h-5 w-5 text-slate-400 dark:text-slate-500 shrink-0"
              />
              <%= if Enum.any?(@upload.entries) do %>
                <%= for entry <- @upload.entries do %>
                  <div class="relative shrink-0">
                    <div
                      id={"avatar-preview-wrap-#{entry.ref}"}
                      class={[
                        "w-20 h-20 rounded-xl overflow-hidden",
                        "border-2 transition-all duration-300",
                        avatar_upload_border_class(@upload_stage)
                      ]}
                    >
                      <%= if @preview_data_url do %>
                        <img
                          src={@preview_data_url}
                          class="w-full h-full object-cover"
                          alt={@alt_text || "Avatar preview"}
                        />
                      <% else %>
                        <.live_img_preview
                          entry={entry}
                          class="w-full h-full object-cover"
                          alt={@alt_text || "Avatar preview"}
                        />
                      <% end %>
                    </div>
                    <div
                      :if={is_processing?(@upload_stage)}
                      class="absolute inset-0 rounded-xl bg-black/50 flex items-center justify-center"
                    >
                      <div class="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin">
                      </div>
                    </div>
                    <button
                      :if={!is_processing?(@upload_stage)}
                      type="button"
                      id={"cancel-avatar-upload-#{entry.ref}"}
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="absolute -top-1 -right-1 w-6 h-6 bg-slate-700/80 hover:bg-slate-700 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                      phx-hook="TippyHook"
                      data-tippy-content="Cancel"
                      aria-label="Cancel upload"
                    >
                      <.phx_icon name="hero-x-mark" class="h-3 w-3" />
                    </button>
                    <div
                      :if={!is_processing?(@upload_stage)}
                      class="absolute bottom-1 left-1 right-1 z-10 flex items-center justify-between"
                    >
                      <button
                        type="button"
                        id={"edit-alt-avatar-#{entry.ref}"}
                        phx-click="open_avatar_alt_text_modal"
                        phx-value-ref={entry.ref}
                        aria-label="Edit alt text"
                        class={[
                          "px-1.5 py-0.5 rounded text-[10px] font-bold flex items-center gap-0.5",
                          "transition-all duration-200 hover:scale-105",
                          if(@alt_text && @alt_text != "",
                            do: "bg-emerald-500 text-white",
                            else: "bg-slate-800 text-white hover:bg-slate-700"
                          )
                        ]}
                        phx-hook="TippyHook"
                        data-tippy-content={
                          if(@alt_text && @alt_text != "",
                            do: "Edit alt text: #{String.slice(@alt_text || "", 0..30)}...",
                            else: "Add alt text for accessibility"
                          )
                        }
                      >
                        <.phx_icon
                          :if={!(@alt_text && @alt_text != "")}
                          name="hero-plus"
                          class="h-2.5 w-2.5"
                        /> ALT
                      </button>

                      <button
                        type="button"
                        id={"edit-avatar-#{entry.ref}"}
                        phx-click="open_avatar_edit_modal"
                        phx-value-ref={entry.ref}
                        aria-label="Edit image"
                        class={[
                          "w-6 h-5 rounded flex items-center justify-center",
                          "transition-all duration-200 hover:scale-105",
                          if(@crop && @crop != %{},
                            do: "bg-sky-500 text-white",
                            else: "bg-slate-800 text-white hover:bg-slate-700"
                          )
                        ]}
                        phx-hook="TippyHook"
                        data-tippy-content={
                          if(@crop && @crop != %{},
                            do: "Edit crop",
                            else: "Crop image"
                          )
                        }
                      >
                        <.phx_icon name="hero-pencil" class="h-3 w-3" />
                      </button>
                    </div>
                  </div>
                <% end %>
              <% else %>
                <div class="relative shrink-0">
                  <div
                    id="phx-preview-standalone"
                    class={[
                      "w-20 h-20 rounded-xl overflow-hidden",
                      "border-2 transition-all duration-300",
                      avatar_upload_border_class(@upload_stage)
                    ]}
                  >
                    <img
                      src={@preview_data_url}
                      class="w-full h-full object-cover"
                      alt={@alt_text || "Avatar preview"}
                    />
                  </div>
                  <div
                    :if={is_processing?(@upload_stage)}
                    class="absolute inset-0 rounded-xl bg-black/50 flex items-center justify-center"
                  >
                    <div class="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin">
                    </div>
                  </div>
                  <button
                    :if={!is_processing?(@upload_stage)}
                    type="button"
                    id="cancel-avatar-upload-standalone"
                    phx-click="clear_avatar_preview"
                    class="absolute -top-1 -right-1 w-6 h-6 bg-slate-700/80 hover:bg-slate-700 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                    phx-hook="TippyHook"
                    data-tippy-content="Cancel"
                    aria-label="Cancel"
                  >
                    <.phx_icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="flex-1 min-w-0">
          <label
            for={@upload.ref}
            class={[
              "inline-flex items-center gap-2 px-4 py-2.5 rounded-xl cursor-pointer",
              "bg-slate-100 dark:bg-slate-700/80",
              "border border-slate-200/60 dark:border-slate-600/60",
              "hover:bg-slate-200/80 dark:hover:bg-slate-600/80",
              "transition-all duration-200 ease-out",
              "text-sm font-medium text-slate-700 dark:text-slate-200"
            ]}
          >
            <.phx_icon name="hero-photo" class="h-4 w-4" />
            <span>Choose photo</span>
          </label>
          <.live_file_input upload={@upload} class="hidden" />
          <p class="mt-2 text-xs text-slate-500 dark:text-slate-400">
            {Enum.join(@upload.acceptable_exts, ", ")}
          </p>
        </div>
      </div>

      <%= if Enum.any?(@upload.entries) || is_processing?(@upload_stage) do %>
        <.liquid_avatar_upload_progress
          upload={@upload}
          upload_stage={@upload_stage}
        />
      <% end %>

      <%= for entry <- @upload.entries do %>
        <%= for err <- upload_errors(@upload, entry) do %>
          <div class="p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl">
            <div class="flex items-center gap-2 text-sm text-red-700 dark:text-red-300">
              <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
              <span>{humanize_upload_error(err, @upload.max_entries)}</span>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :upload, :map, required: true
  attr :upload_stage, :any, default: nil

  def liquid_avatar_upload_progress(assigns) do
    stages = [
      {:receiving, "Receiving", "hero-arrow-down-tray"},
      {:converting, "Converting", "hero-arrows-right-left"},
      {:resizing, "Resizing", "hero-arrows-pointing-in"},
      {:checking, "Safety check", "hero-shield-check"},
      {:encrypting, "Encrypting", "hero-lock-closed"},
      {:uploading, "Uploading", "hero-cloud-arrow-up"}
    ]

    assigns = assign(assigns, :stages, stages)

    ~H"""
    <div class={[
      "p-4 rounded-xl border",
      "bg-gradient-to-br from-slate-50/80 to-slate-100/60 dark:from-slate-800/60 dark:to-slate-800/40",
      "border-slate-200/60 dark:border-slate-700/60"
    ]}>
      <div class="flex items-center gap-2 mb-4">
        <.phx_icon
          name="hero-cog-6-tooth"
          class="h-4 w-4 text-emerald-600 dark:text-emerald-400 animate-spin"
        />
        <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
          Processing your avatar
        </span>
      </div>

      <div class="space-y-2">
        <%= for {stage_key, stage_label, stage_icon} <- @stages do %>
          <% status = get_stage_status(@upload_stage, stage_key) %>
          <div class={[
            "flex items-center gap-3 px-3 py-2 rounded-lg transition-all duration-300",
            stage_status_bg_class(status)
          ]}>
            <div class={[
              "w-6 h-6 rounded-full flex items-center justify-center transition-all duration-300",
              stage_status_icon_class(status)
            ]}>
              <%= case status do %>
                <% :completed -> %>
                  <.phx_icon name="hero-check" class="h-3.5 w-3.5 text-white" />
                <% :active -> %>
                  <div class="w-3 h-3 border-2 border-emerald-600 border-t-transparent rounded-full animate-spin">
                  </div>
                <% :pending -> %>
                  <.phx_icon name={stage_icon} class="h-3.5 w-3.5 text-slate-400 dark:text-slate-500" />
                <% :error -> %>
                  <.phx_icon name="hero-x-mark" class="h-3.5 w-3.5 text-white" />
              <% end %>
            </div>

            <span class={[
              "text-sm font-medium transition-all duration-300",
              stage_status_text_class(status)
            ]}>
              {stage_label}
            </span>

            <%= if status == :active do %>
              <div class="ml-auto flex items-center gap-2">
                <div class="w-16 h-1.5 bg-slate-200 dark:bg-slate-600 rounded-full overflow-hidden">
                  <div class="h-full bg-emerald-500 rounded-full animate-pulse w-2/3"></div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if is_upload_error?(@upload_stage) do %>
        <div class="mt-4 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
          <div class="flex items-center gap-2 text-sm text-red-700 dark:text-red-300">
            <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
            <span>{get_upload_error_message(@upload_stage)}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp avatar_upload_border_class(nil), do: "border-slate-200 dark:border-slate-600"
  defp avatar_upload_border_class({:error, _}), do: "border-red-400 dark:border-red-500"
  defp avatar_upload_border_class({:ready, _}), do: "border-emerald-400 dark:border-emerald-500"

  defp avatar_upload_border_class(_),
    do: "border-emerald-400/50 dark:border-emerald-500/50 animate-pulse"

  defp is_processing?(nil), do: false
  defp is_processing?({:ready, _}), do: false
  defp is_processing?({:error, _}), do: false
  defp is_processing?(_), do: true

  defp is_upload_error?({:error, _}), do: true
  defp is_upload_error?(_), do: false

  defp get_upload_error_message({:error, {:nsfw, msg}}), do: msg
  defp get_upload_error_message({:error, msg}) when is_binary(msg), do: msg
  defp get_upload_error_message({:error, _}), do: "Upload failed. Please try again."
  defp get_upload_error_message(_), do: ""

  defp get_stage_status(nil, _stage_key), do: :pending
  defp get_stage_status({:error, _}, _stage_key), do: :error

  defp get_stage_status({current_stage, _progress}, stage_key) do
    stage_order = [:receiving, :converting, :resizing, :checking, :encrypting, :uploading, :ready]
    current_idx = Enum.find_index(stage_order, &(&1 == current_stage)) || 0
    stage_idx = Enum.find_index(stage_order, &(&1 == stage_key)) || 0

    cond do
      current_stage == :ready -> :completed
      stage_idx < current_idx -> :completed
      stage_idx == current_idx -> :active
      true -> :pending
    end
  end

  defp stage_status_bg_class(:completed), do: "bg-emerald-50/80 dark:bg-emerald-900/20"
  defp stage_status_bg_class(:active), do: "bg-emerald-100/80 dark:bg-emerald-900/30"
  defp stage_status_bg_class(:error), do: "bg-red-50/80 dark:bg-red-900/20"
  defp stage_status_bg_class(:pending), do: "bg-transparent"

  defp stage_status_icon_class(:completed), do: "bg-emerald-500"
  defp stage_status_icon_class(:active), do: "bg-emerald-100 dark:bg-emerald-900/50"
  defp stage_status_icon_class(:error), do: "bg-red-500"
  defp stage_status_icon_class(:pending), do: "bg-slate-100 dark:bg-slate-700"

  defp stage_status_text_class(:completed), do: "text-emerald-700 dark:text-emerald-300"
  defp stage_status_text_class(:active), do: "text-emerald-700 dark:text-emerald-300"
  defp stage_status_text_class(:error), do: "text-red-700 dark:text-red-300"
  defp stage_status_text_class(:pending), do: "text-slate-500 dark:text-slate-400"

  # Avatar size helper functions
  defp avatar_container_size_classes("xs"), do: "w-6 h-6"
  defp avatar_container_size_classes("sm"), do: "w-8 h-8"
  defp avatar_container_size_classes("md"), do: "w-12 h-12"
  defp avatar_container_size_classes("lg"), do: "w-16 h-16"
  defp avatar_container_size_classes("xl"), do: "w-20 h-20"
  defp avatar_container_size_classes("xxl"), do: "w-32 h-32"

  defp avatar_size_classes("xs"), do: "w-6 h-6"
  defp avatar_size_classes("sm"), do: "w-8 h-8"
  defp avatar_size_classes("md"), do: "w-12 h-12"
  defp avatar_size_classes("lg"), do: "w-16 h-16"
  defp avatar_size_classes("xl"), do: "w-20 h-20"
  defp avatar_size_classes("xxl"), do: "w-32 h-32"

  @doc """
  Liquid metal tooltip component with premium styling.
  Perfect for showing status messages and rich content on hover.
  """
  attr :content, :string, required: true
  attr :position, :string, default: "top", values: ~w(top bottom left right)
  attr :class, :any, default: ""
  attr :id, :string, required: true, doc: "a unique id required for the tooltip to display"

  slot :inner_block, required: true

  def liquid_tooltip(assigns) do
    ~H"""
    <div id={@id} class={["relative group", @class]}>
      {render_slot(@inner_block)}

      <%!-- Liquid metal tooltip --%>
      <div class={[
        "absolute z-50 opacity-0 invisible group-hover:opacity-100 group-hover:visible",
        "transition-all duration-300 ease-out transform group-hover:scale-100 scale-95",
        "px-3 py-2 text-sm font-medium text-white",
        "bg-gradient-to-br from-slate-800 via-slate-700 to-slate-800",
        "dark:from-slate-900 dark:via-slate-800 dark:to-slate-900",
        "rounded-xl shadow-xl border border-slate-600/50 dark:border-slate-700/50",
        "backdrop-blur-sm whitespace-nowrap",
        "before:absolute before:w-2 before:h-2 before:bg-slate-800 dark:before:bg-slate-900",
        "before:border-l before:border-t before:border-slate-600/50 dark:before:border-slate-700/50",
        "before:rotate-45 before:transform",
        tooltip_position_classes(@position)
      ]}>
        <%!-- Liquid shimmer effect --%>
        <div class="absolute inset-0 rounded-xl bg-gradient-to-r from-transparent via-teal-400/10 to-transparent animate-pulse opacity-60">
        </div>

        <%!-- Content --%>
        <div class="relative z-10">
          {@content}
        </div>
      </div>
    </div>
    """
  end

  defp tooltip_position_classes("top") do
    [
      "-top-2 left-1/2 transform -translate-x-1/2 -translate-y-full",
      "before:top-full before:left-1/2 before:-translate-x-1/2 before:-mt-1"
    ]
  end

  defp tooltip_position_classes("bottom") do
    [
      "-bottom-2 left-1/2 transform -translate-x-1/2 translate-y-full",
      "before:bottom-full before:left-1/2 before:-translate-x-1/2 before:-mb-1 before:rotate-[225deg]"
    ]
  end

  defp tooltip_position_classes("left") do
    [
      "top-1/2 -left-2 transform -translate-y-1/2 -translate-x-full",
      "before:left-full before:top-1/2 before:-translate-y-1/2 before:-ml-1 before:rotate-[135deg]"
    ]
  end

  defp tooltip_position_classes("right") do
    [
      "top-1/2 -right-2 transform -translate-y-1/2 translate-x-full",
      "before:right-full before:top-1/2 before:-translate-y-1/2 before:-mr-1 before:rotate-[-45deg]"
    ]
  end

  @doc """
  User status indicator for timeline posts and avatars.
  Shows a small dot indicating user's current status.
  """
  attr :status, :string, required: true
  attr :online, :boolean, default: false
  attr :animate, :boolean, default: false
  attr :class, :any, default: ""
  attr :id, :string, default: nil

  def liquid_user_status_indicator(assigns) do
    ~H"""
    <div
      class={[
        "absolute -bottom-0.5 -right-0.5 rounded-full ring-2 ring-white dark:ring-slate-800 z-10",
        timeline_status_dot_size(@status),
        timeline_status_dot_classes(@status),
        @class
      ]}
      data-status-indicator="true"
    >
      <%!-- Pulse animation for active statuses --%>
      <div
        :if={@animate and @status in ["online", "calm", "active", "busy", "away"]}
        class={[
          "absolute inset-0 rounded-full animate-ping opacity-75",
          timeline_status_ping_classes(@status)
        ]}
      >
      </div>
    </div>
    """
  end

  @doc """
  Status selector component for user settings.
  Beautiful grid of status options with liquid metal styling.
  """
  attr :current_status, :string, required: true
  attr :phx_click, :string, default: "set_status"
  attr :class, :any, default: ""

  def liquid_status_selector(assigns) do
    ~H"""
    <div class={["space-y-4", @class]}>
      <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
        Your Status
      </label>

      <%!-- Status options with visual hierarchy --%>
      <div class="grid grid-cols-2 sm:grid-cols-5 gap-3">
        <button
          :for={status <- ["offline", "calm", "active", "busy", "away"]}
          type="button"
          class={[
            "group relative flex flex-col items-center justify-center p-4 rounded-xl border-2 transition-all duration-200 ease-out",
            "hover:scale-105 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2",
            status_selector_classes(status, @current_status)
          ]}
          phx-click={@phx_click}
          phx-value-status={status}
        >
          <%!-- Status dot --%>
          <div class={[
            "relative rounded-full mb-2 transition-all duration-300 ease-out group-hover:scale-110",
            timeline_status_dot_size(status),
            timeline_status_dot_classes(status)
          ]}>
            <%!-- Pulse animation for active statuses --%>
            <div
              :if={status in ["calm", "active"] and @current_status == status}
              class={[
                "absolute inset-0 rounded-full animate-ping opacity-75",
                timeline_status_ping_classes(status)
              ]}
            >
            </div>
          </div>

          <%!-- Status label --%>
          <span class="text-xs font-medium group-hover:text-slate-900 dark:group-hover:text-slate-100 transition-colors duration-200">
            {String.capitalize(status)}
          </span>
        </button>
      </div>
    </div>
    """
  end

  # Helper function for status selector button classes
  defp status_selector_classes(status, current_status) when status == current_status do
    case status do
      "offline" ->
        [
          "bg-slate-100 dark:bg-slate-700 border-slate-300 dark:border-slate-500",
          "text-slate-700 dark:text-slate-200 shadow-md ring-2 ring-slate-300/50 dark:ring-slate-500/50"
        ]

      "calm" ->
        [
          "bg-gradient-to-br from-teal-50 to-emerald-50 dark:from-teal-900/30 dark:to-emerald-900/30",
          "border-teal-300 dark:border-teal-600 text-teal-700 dark:text-teal-300 shadow-md shadow-teal-500/20"
        ]

      "active" ->
        [
          "bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-emerald-900/30 dark:to-teal-900/30",
          "border-emerald-300 dark:border-emerald-600 text-emerald-700 dark:text-emerald-300 shadow-md shadow-emerald-500/20"
        ]

      "busy" ->
        [
          "bg-gradient-to-br from-rose-50 to-pink-50 dark:from-rose-900/30 dark:to-pink-900/30",
          "border-rose-300 dark:border-rose-600 text-rose-700 dark:text-rose-300 shadow-md shadow-rose-500/20"
        ]

      "away" ->
        [
          "bg-gradient-to-br from-amber-50 to-orange-50 dark:from-amber-900/30 dark:to-orange-900/30",
          "border-amber-300 dark:border-amber-600 text-amber-700 dark:text-amber-300 shadow-md shadow-amber-500/20"
        ]
    end
  end

  defp status_selector_classes(_status, _current_status) do
    [
      "bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700",
      "text-slate-600 dark:text-slate-400 hover:border-teal-300 dark:hover:border-teal-600",
      "hover:text-teal-700 dark:hover:text-teal-300 hover:bg-teal-50/50 dark:hover:bg-teal-900/20"
    ]
  end

  @doc """
  Enhanced status message card that slides out from status indicators.

  Displays status information in a beautiful liquid metal card that appears on hover.
  Perfect for showing rich status context without cluttering the UI.

  ## Examples

      <.liquid_status_message_card status="calm" message="Working on some cool features!" />
      <.liquid_status_message_card status="busy" message="In a meeting" />
      <.liquid_status_message_card status="away" />
  """
  attr :status, :string, required: true, values: ~w(offline calm active busy away)
  attr :message, :string, default: nil
  attr :position, :string, default: "right", values: ~w(left right top bottom)
  attr :class, :any, default: ""
  attr :id, :string, required: true

  attr :encrypted_status_data, :map,
    default: nil,
    doc: "ZK mode: map with :encrypted_status_message and :sealed_key for browser-side decryption"

  def liquid_status_message_card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "absolute z-30 opacity-0 pointer-events-none transition-all duration-400 ease-out",
        "group-hover/avatar:opacity-100 group-hover/avatar:pointer-events-auto",
        status_card_position_classes(@position),
        @class
      ]}
      data-status-message="true"
    >
      <%!-- DecryptStatusMessage hook for browser-side ZK decryption --%>
      <div
        :if={@encrypted_status_data}
        id={"decrypt-status-#{@id}"}
        phx-hook="DecryptStatusMessage"
        phx-update="ignore"
        data-encrypted-status-message={@encrypted_status_data[:encrypted_status_message]}
        data-sealed-key={@encrypted_status_data[:sealed_key]}
        data-target-id={@id}
        class="hidden"
      >
      </div>

      <%!-- Connecting line --%>
      <div class={[
        "absolute bg-gradient-to-r from-teal-400/60 to-transparent",
        status_card_line_classes(@position)
      ]}>
      </div>

      <%!-- Status message card --%>
      <div class="relative rounded-2xl overflow-hidden
                  bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm
                  border border-slate-200/60 dark:border-slate-700/60
                  shadow-xl shadow-slate-900/10 dark:shadow-slate-900/20
                  p-4 min-w-64 max-w-80">
        <%!-- Liquid background --%>
        <div class={[
          "absolute inset-0",
          status_card_liquid_bg_classes(@status)
        ]}>
        </div>

        <%!-- Shimmer effect --%>
        <div class="absolute inset-0 bg-gradient-to-r from-transparent
                    via-emerald-200/30 dark:via-emerald-400/15 to-transparent
                    -translate-x-full group-hover/avatar:translate-x-full
                    transition-transform duration-1000 ease-out">
        </div>

        <%!-- Content --%>
        <div class="relative">
          <%!-- Status header --%>
          <div class="flex items-center gap-2 mb-2">
            <%!-- Status dot with same colors as the main indicator --%>
            <div
              class={[
                "w-2.5 h-2.5 rounded-full flex-shrink-0",
                timeline_status_dot_classes(@status)
              ]}
              data-status-dot="true"
            >
            </div>
            <span
              class="text-sm font-semibold text-slate-700 dark:text-slate-200"
              data-status-header="true"
            >
              {status_display_name(@status)}
            </span>
          </div>

          <%!-- Custom message (server-rendered or placeholder for ZK decrypt) --%>
          <div
            :if={(@message && String.trim(@message) != "") || @encrypted_status_data}
            class={[
              "text-sm text-slate-600 dark:text-slate-300 leading-relaxed",
              if(@encrypted_status_data && !@message, do: "animate-pulse", else: "")
            ]}
            data-status-message-content="true"
          >
            {if @message && String.trim(@message) != "", do: @message, else: "\u00A0"}
          </div>

          <%!-- Default message if no custom message and no ZK data --%>
          <div
            :if={(!@message || String.trim(@message) == "") && !@encrypted_status_data}
            class="text-xs text-slate-500 dark:text-slate-400"
            data-status-message-content="true"
          >
            {default_status_message(@status)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Position classes for the status card
  defp status_card_position_classes("right") do
    "top-0 left-full ml-2 translate-x-2 group-hover/avatar:translate-x-0"
  end

  defp status_card_position_classes("left") do
    "top-0 right-full mr-2 -translate-x-2 group-hover/avatar:translate-x-0"
  end

  defp status_card_position_classes("top") do
    "bottom-full left-1/2 mb-2 -translate-x-1/2 -translate-y-2 group-hover/avatar:translate-y-0"
  end

  defp status_card_position_classes("bottom") do
    "top-full left-1/2 mt-2 -translate-x-1/2 translate-y-2 group-hover/avatar:translate-y-0"
  end

  # Connecting line classes
  defp status_card_line_classes("right") do
    "left-0 top-4 w-2 h-px"
  end

  defp status_card_line_classes("left") do
    "right-0 top-4 w-2 h-px transform rotate-180"
  end

  defp status_card_line_classes("top") do
    "bottom-0 left-1/2 w-px h-2 transform -translate-x-1/2 rotate-90"
  end

  defp status_card_line_classes("bottom") do
    "top-0 left-1/2 w-px h-2 transform -translate-x-1/2 -rotate-90"
  end

  # Liquid background classes based on status
  defp status_card_liquid_bg_classes("offline") do
    "bg-gradient-to-br from-slate-50/30 via-slate-50/20 to-slate-100/30 dark:from-slate-900/20 dark:via-slate-800/15 dark:to-slate-900/20"
  end

  defp status_card_liquid_bg_classes("calm") do
    "bg-gradient-to-br from-teal-50/30 via-emerald-50/20 to-cyan-50/30 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-cyan-900/20"
  end

  defp status_card_liquid_bg_classes("active") do
    "bg-gradient-to-br from-emerald-50/30 via-teal-50/20 to-emerald-50/30 dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-emerald-900/20"
  end

  defp status_card_liquid_bg_classes("busy") do
    "bg-gradient-to-br from-rose-50/30 via-pink-50/20 to-rose-50/30 dark:from-rose-900/20 dark:via-pink-900/15 dark:to-rose-900/20"
  end

  defp status_card_liquid_bg_classes("away") do
    "bg-gradient-to-br from-amber-50/30 via-orange-50/20 to-amber-50/30 dark:from-amber-900/20 dark:via-orange-900/15 dark:to-amber-900/20"
  end

  # Status display names - proper human-readable labels for your status values
  defp status_display_name("offline"), do: "Offline"
  defp status_display_name("calm"), do: "Calm"
  defp status_display_name("active"), do: "Active"
  defp status_display_name("busy"), do: "Busy"
  defp status_display_name("away"), do: "Away"
  defp status_display_name(status), do: String.capitalize(status)

  # Status messages using StatusHelpers for consistency
  defp default_status_message(status) do
    get_status_fallback_message(String.to_existing_atom(status))
  rescue
    ArgumentError -> "Status unknown"
  end

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
      <div class="isolate">
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
      </div>
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
  attr :trigger_aria_label, :string, default: "Toggle menu"
  attr :phx_hook_id, :string, default: nil
  attr :phx_hook, :string, default: nil
  attr :phx_data_tippy_content, :string, default: nil

  attr :placement, :string,
    default: "bottom-end",
    values: ~w(bottom-start bottom-end top-start top-end)

  attr :class, :string, default: ""
  attr :menu_class, :string, default: ""

  attr :content_class, :string,
    default: "max-h-[12.5rem] overflow-y-auto",
    doc: "classes for the scrollable items wrapper; override to remove the scroll cap"

  slot :trigger, required: true

  slot :item do
    attr :color, :string, values: ~w(slate gray red emerald blue amber purple rose)
    attr :id, :string
    attr :phx_click, :string
    attr :phx_value_id, :string
    attr :phx_value_user_id, :string
    attr :phx_value_post_id, :string
    attr :phx_value_username, :string
    attr :phx_value_user_name, :string
    attr :phx_value_item_id, :string
    attr :phx_value_reply_id, :string
    attr :phx_value_reported_user_id, :string
    attr :phx_value_role, :string
    attr :href, :string
    attr :data_confirm, :string
  end

  def liquid_dropdown(assigns) do
    ~H"""
    <div
      id={@id}
      class={["relative", @class]}
      phx-click-away={JS.hide(to: "##{@id}-menu")}
      phx-window-keydown={JS.hide(to: "##{@id}-menu")}
      phx-key="Escape"
    >
      <%!-- Trigger button --%>
      <button
        type="button"
        phx-click={JS.toggle(to: "##{@id}-menu")}
        class={[
          "relative transition-all duration-200 ease-out",
          "hover:bg-slate-100/50 dark:hover:bg-slate-700/50",
          @trigger_class
        ]}
        aria-label={@trigger_aria_label}
        aria-expanded="false"
        aria-haspopup="true"
        id={if @phx_hook_id, do: @phx_hook_id}
        phx-hook={if @phx_hook, do: @phx_hook}
        data-tippy-content={if @phx_data_tippy_content, do: @phx_data_tippy_content}
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
          placement_classes(@placement),
          @menu_class
        ]}
        role="menu"
        aria-orientation="vertical"
      >
        <%!-- Liquid background effect --%>
        <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 opacity-50">
        </div>

        <div class={["relative py-2", @content_class]}>
          <div
            :for={item <- @item}
            id={item[:id]}
            class={[
              "group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer",
              "hover:bg-slate-100/80 dark:hover:bg-slate-700/80",
              "first:rounded-t-lg last:rounded-b-lg",
              item_color_classes(item[:color] || "slate")
            ]}
            role="menuitem"
            phx-click={item[:phx_click]}
            phx-value-id={item[:phx_value_id]}
            phx-value-user_id={item[:phx_value_user_id]}
            phx-value-post-id={item[:phx_value_post_id]}
            phx-value-username={item[:phx_value_username]}
            phx-value-user-name={item[:phx_value_user_name]}
            phx-value-item-id={item[:phx_value_item_id]}
            phx-value-reply-id={item[:phx_value_reply_id]}
            phx-value-reported-user-id={item[:phx_value_reported_user_id]}
            phx-value-role={item[:phx_value_role]}
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
  Image viewer modal for timeline photos with download functionality.

  ## Examples

      <.liquid_image_modal
        id="timeline-images"
        show={@show_images}
        images={@current_images}
        current_index={@current_image_index}
        can_download={@can_download_images}
        on_cancel={JS.push("close_image_modal")}
      />
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :images, :list, default: []
  attr :image_alt_texts, :list, default: []
  attr :current_index, :integer, default: 0
  attr :can_download, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :class, :any, default: ""

  def liquid_image_modal(assigns) do
    images_json = Jason.encode!(assigns.images || [])

    current_alt =
      case Enum.at(assigns.image_alt_texts || [], assigns.current_index) do
        nil -> "Image #{assigns.current_index + 1}"
        "" -> "Image #{assigns.current_index + 1}"
        alt -> alt
      end

    assigns =
      assigns
      |> assign(:images_json, images_json)
      |> assign(:current_alt, current_alt)

    ~H"""
    <.portal :if={@show} id={"#{@id}-portal"} target="body">
      <div
        id={@id}
        phx-mounted={@show && liquid_show_modal(@id)}
        phx-remove={liquid_hide_modal(@id)}
        phx-hook="ImageModalHook"
        data-cancel={JS.exec(@on_cancel, "phx-remove")}
        data-current-index={@current_index}
        data-images={@images_json}
        class="fixed top-0 left-0 w-screen h-screen z-[60] hidden"
        style="position: fixed !important;"
        data-modal-type="liquid-image-modal"
      >
        <%!-- Backdrop with darker overlay for image viewing --%>
        <div
          id={"#{@id}-bg"}
          class={[
            "fixed top-0 left-0 right-0 bottom-0 z-40 transition-all duration-300 ease-out",
            "bg-black/90 backdrop-blur-sm"
          ]}
          aria-hidden="true"
          style="position: fixed !important; top: 0 !important; left: 0 !important; right: 0 !important; bottom: 0 !important;"
        />

        <%!-- Image modal container --%>
        <div
          class="fixed top-0 left-0 right-0 bottom-0 z-50 flex items-center justify-center p-4"
          role="dialog"
          aria-modal="true"
          aria-label="Image viewer"
          style="position: fixed !important; top: 0 !important; left: 0 !important; right: 0 !important; bottom: 0 !important;"
        >
          <.focus_wrap
            id={"#{@id}-container"}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            class={[
              "relative w-full max-w-6xl max-h-[95vh] flex flex-col",
              "transform-gpu transition-all duration-300 ease-out",
              "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95 hidden",
              "rounded-xl overflow-hidden",
              "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
              "border border-slate-200/60 dark:border-slate-700/60",
              "shadow-2xl shadow-black/50",
              @class
            ]}
          >
            <%!-- Header with controls --%>
            <div class="flex items-center justify-between px-3 py-2.5 sm:p-4 gap-2 border-b border-slate-200 dark:border-slate-700 bg-white/50 dark:bg-slate-800/50">
              <div class="flex items-center gap-1.5 sm:space-x-3 min-w-0">
                <.phx_icon
                  name="hero-photo"
                  class="h-4 w-4 sm:h-5 sm:w-5 flex-shrink-0 text-emerald-600 dark:text-emerald-400"
                />
                <span class="text-sm sm:text-lg font-semibold text-slate-900 dark:text-slate-100 truncate">
                  Photo {@current_index + 1} of {length(@images)}
                </span>
              </div>

              <div class="flex items-center gap-1.5 sm:space-x-2 flex-shrink-0">
                <%!-- Download button — client-side ZK download (no server round-trip) --%>
                <button
                  :if={@can_download && @images != []}
                  id={"download-photo-button-#{@id}"}
                  type="button"
                  data-zk-download
                  data-tippy-content="Download photo"
                  phx-hook="TippyHook"
                  class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-lg text-emerald-700 dark:text-emerald-300 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 transition-colors duration-150"
                >
                  <.phx_icon name="hero-arrow-down-tray" class="h-4 w-4" /> Download
                </button>

                <%!-- Close button --%>
                <.liquid_button
                  id={"close-photo-modal-button-#{@id}"}
                  size="sm"
                  variant="ghost"
                  color="rose"
                  icon="hero-x-mark"
                  phx-click={@on_cancel}
                  data-tippy-content="Close"
                  phx-hook="TippyHook"
                >
                  Close
                </.liquid_button>
              </div>
            </div>

            <%!-- Image container with proper viewport constraints --%>
            <div class="relative flex-1 min-h-0 bg-slate-100 dark:bg-slate-900 overflow-hidden">
              <div
                :if={@images == []}
                class="flex items-center justify-center h-96 text-slate-500 dark:text-slate-400"
              >
                <div class="text-center">
                  <.phx_icon name="hero-photo" class="h-12 w-12 mx-auto mb-2 opacity-50" />
                  <p>No images to display</p>
                </div>
              </div>

              <div
                :if={@images != []}
                id={"photo-container-#{@id}-#{@current_index}"}
                class="relative w-full h-full flex items-center justify-center p-4"
                phx-hook="DisableContextMenu"
                data-can-download={@can_download}
              >
                <img
                  :if={Enum.at(@images, @current_index)}
                  src={Enum.at(@images, @current_index)}
                  alt={@current_alt}
                  class="max-w-full max-h-full w-auto h-auto object-contain"
                  loading="lazy"
                  style="max-height: calc(95vh - 200px); max-width: calc(100vw);"
                />

                <%!-- Navigation arrows --%>
                <button
                  :if={length(@images) > 1 && @current_index > 0}
                  id={"previous-photo-button-#{@id}"}
                  phx-click="prev_timeline_image"
                  class="absolute left-4 top-1/2 -translate-y-1/2 p-3 rounded-full bg-black/60 hover:bg-black/80 text-white transition-all duration-200 hover:scale-110"
                  data-tippy-content="Previous photo (←)"
                  phx-hook="TippyHook"
                  aria-label="Previous photo"
                >
                  <.phx_icon name="hero-chevron-left" class="h-6 w-6 nav-icon" />
                  <div class="nav-spinner hidden w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin">
                  </div>
                </button>

                <button
                  :if={length(@images) > 1 && @current_index < length(@images) - 1}
                  id={"next-photo-button-#{@id}"}
                  phx-click="next_timeline_image"
                  class="absolute right-4 top-1/2 -translate-y-1/2 p-3 rounded-full bg-black/60 hover:bg-black/80 text-white transition-all duration-200 hover:scale-110"
                  data-tippy-content="Next photo (→)"
                  phx-hook="TippyHook"
                  aria-label="Next photo"
                >
                  <.phx_icon name="hero-chevron-right" class="h-6 w-6 nav-icon" />
                  <div class="nav-spinner hidden w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin">
                  </div>
                </button>
              </div>
            </div>

            <%!-- Footer with image dots navigation --%>
            <div
              :if={length(@images) > 1}
              class="flex justify-center p-4 border-t border-slate-200 dark:border-slate-700 bg-white/50 dark:bg-slate-800/50"
            >
              <div class="flex space-x-2">
                <button
                  :for={{_img, index} <- Enum.with_index(@images)}
                  id={"navigation-photo-button-#{@id}-#{index}"}
                  phx-click="goto_timeline_image"
                  phx-value-index={index}
                  class={[
                    "relative w-3 h-3 rounded-full transition-all duration-200 hover:scale-125",
                    if(index == @current_index,
                      do: "bg-emerald-500 ring-2 ring-emerald-200 dark:ring-emerald-800",
                      else:
                        "bg-slate-300 dark:bg-slate-600 hover:bg-slate-400 dark:hover:bg-slate-500"
                    )
                  ]}
                  data-tippy-content={"Photo #{index + 1}"}
                  phx-hook="TippyHook"
                  aria-label={"Go to photo #{index + 1}"}
                >
                  <span class="nav-dot absolute inset-0 rounded-full"></span>
                  <div class="nav-spinner hidden absolute inset-0 flex items-center justify-center">
                    <div class="w-3 h-3 border-2 border-emerald-200 dark:border-emerald-800 border-t-emerald-500 rounded-full animate-spin">
                    </div>
                  </div>
                </button>
              </div>
            </div>
          </.focus_wrap>
        </div>
      </div>
    </.portal>
    """
  end

  @doc """
  A beautiful mood picker with emoji-based selection.

  Displays moods organized by emotional valence (positive → negative) with
  smooth transitions and clear visual feedback.

  ## Examples

      <.mood_picker name="journal_entry[mood]" value={@form[:mood].value} />
      <.mood_picker name="mood" value="happy" on_change="mood_changed" />
  """
  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :id, :string, default: nil
  attr :on_change, :string, default: nil
  attr :entry_id, :string, default: nil

  def mood_picker(assigns) do
    assigns =
      assign(assigns, :id, assigns[:id] || "mood-picker-#{System.unique_integer([:positive])}")

    ~H"""
    <div
      id={@id}
      class="mood-picker relative"
      x-data="{ open: false, search: '' }"
    >
      <input
        type="hidden"
        name={@name}
        value={@value || ""}
        id={"#{@id}-input"}
        data-decrypt-journal-form-mood={@entry_id}
      />
      <button
        type="button"
        @click="open = !open; $nextTick(() => open && $refs.searchInput.focus())"
        aria-label={if @value, do: "Change mood: #{mood_label(@value)}", else: "Select mood"}
        class={[
          "inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm transition-all duration-200",
          "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-teal-500/50",
          "dark:focus:ring-offset-slate-800",
          if(@value,
            do: "bg-slate-100/80 dark:bg-slate-800/80 text-slate-700 dark:text-slate-300",
            else:
              "bg-slate-100/50 dark:bg-slate-800/50 text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700/50"
          )
        ]}
      >
        <span :if={@value} class="text-base leading-none">{mood_emoji(@value)}</span>
        <span :if={!@value} class="text-base leading-none opacity-60">😊</span>
        <span class="text-xs font-medium">
          {if @value, do: mood_label(@value), else: "How are you feeling?"}
        </span>
        <.phx_icon
          name="hero-chevron-down"
          class={[
            "h-3.5 w-3.5 transition-transform duration-200",
            "x-bind:class=\"open && 'rotate-180'\""
          ]}
        />
      </button>
      <div
        x-show="open"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0 -translate-y-2"
        x-transition:enter-end="opacity-100 translate-y-0"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100 translate-y-0"
        x-transition:leave-end="opacity-0 -translate-y-2"
        @click.outside="open = false; search = ''"
        @keydown.escape.window="open = false; search = ''"
        class="absolute left-0 z-50 mt-2 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-lg w-72 sm:w-80"
        style="display: none;"
      >
        <div class="sticky top-0 p-2 sm:p-3 border-b border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 rounded-t-xl">
          <div class="relative">
            <.phx_icon
              name="hero-magnifying-glass"
              class="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 dark:text-slate-500 pointer-events-none"
            />
            <input
              type="text"
              x-ref="searchInput"
              x-model="search"
              placeholder="Search moods..."
              class="w-full pl-8 pr-8 py-2 text-sm bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-600 rounded-lg placeholder-slate-400 dark:placeholder-slate-500 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:border-teal-500/50"
            />
            <button
              type="button"
              x-show="search.length > 0"
              @click="search = ''; $refs.searchInput.focus()"
              aria-label="Clear search"
              class="absolute right-2 top-1/2 -translate-y-1/2 p-0.5 text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300 transition-colors"
            >
              <.phx_icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </div>
        </div>
        <div class="max-h-[50vh] sm:max-h-72 overflow-y-auto overscroll-contain p-3 sm:p-4">
          <div class="space-y-3 sm:space-y-4">
            <template
              x-for="(category, categoryIndex) in window.moodPickerFilterCategories(search)"
              x-bind:key="categoryIndex"
            >
              <div class="space-y-2">
                <div
                  class="text-[11px] font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400 px-1"
                  x-text="category.name"
                >
                </div>
                <div class="flex flex-wrap gap-1.5 sm:gap-2">
                  <template x-for="(mood, moodIndex) in category.moods" x-bind:key="moodIndex">
                    <button
                      type="button"
                      x-on:click={"$dispatch('mood:select', { mood: mood.id, input_id: '#{@id}-input' }); open = false; search = ''"}
                      x-bind:class={"window.moodPickerGetButtonClasses(mood.id, '#{@value || ""}')"}
                      x-bind:title="mood.label"
                    >
                      <span class="text-lg sm:text-xl leading-none flex-shrink-0" x-text="mood.emoji"></span>
                      <span
                        x-bind:class={"window.moodPickerGetLabelClasses(mood.id, '#{@value || ""}')"}
                        x-text="mood.label"
                      ></span>
                    </button>
                  </template>
                </div>
              </div>
            </template>
            <div
              x-show="search.length > 0 && window.moodPickerFilterCategories(search).length === 0"
              class="text-center py-6 text-slate-500 dark:text-slate-400"
            >
              <span class="text-3xl block mb-2">😌</span>
              <p class="text-sm">No moods found</p>
              <p class="text-xs mt-1">Try a different search term</p>
            </div>
          </div>
        </div>
        <div :if={@value} class="border-t border-slate-200 dark:border-slate-700 px-3 sm:px-4 py-2">
          <button
            type="button"
            phx-click={JS.dispatch("mood:select", detail: %{mood: "", input_id: "#{@id}-input"})}
            @click="open = false; search = ''"
            class="w-full flex items-center justify-center gap-1.5 py-1.5 text-xs text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition-colors"
          >
            <.phx_icon name="hero-x-mark" class="h-3.5 w-3.5" /> Clear mood
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Returns the emoji for a given mood string.
  """
  def mood_emoji(mood) when is_binary(mood) do
    mood_map = %{
      "joyful" => "🤩",
      "happy" => "😊",
      "excited" => "🎉",
      "hopeful" => "🌟",
      "goodday" => "☀️",
      "cheerful" => "😄",
      "elated" => "🥳",
      "blissful" => "😇",
      "optimistic" => "🌈",
      "grateful" => "🙏",
      "thankful" => "🌅",
      "blessed" => "✨",
      "appreciative" => "💫",
      "fortunate" => "🍀",
      "loved" => "🥰",
      "loving" => "💕",
      "romantic" => "💘",
      "affectionate" => "🤗",
      "tender" => "💗",
      "adoring" => "😍",
      "content" => "😌",
      "peaceful" => "🕊️",
      "serene" => "🧘",
      "calm" => "😶",
      "relaxed" => "😎",
      "tranquil" => "🌸",
      "centered" => "☯️",
      "mellow" => "🍃",
      "cozy" => "☕",
      "energized" => "⚡",
      "refreshed" => "🌱",
      "alive" => "🌻",
      "vibrant" => "💥",
      "awake" => "🌞",
      "invigorated" => "🏃",
      "inspired" => "💡",
      "creative" => "🎨",
      "curious" => "🤔",
      "confident" => "💪",
      "proud" => "🏆",
      "accomplished" => "🎯",
      "determined" => "🔥",
      "focused" => "🧠",
      "ambitious" => "🚀",
      "driven" => "⭐",
      "playful" => "🎮",
      "silly" => "🤪",
      "adventurous" => "🗺️",
      "spontaneous" => "🎲",
      "carefree" => "🦋",
      "mischievous" => "😏",
      "supported" => "🤝",
      "connected" => "🫂",
      "belonging" => "🏠",
      "understood" => "💭",
      "included" => "👥",
      "social" => "🎊",
      "growing" => "🪴",
      "grounded" => "🌿",
      "breathing" => "🌬️",
      "healing" => "🩹",
      "learning" => "📚",
      "evolving" => "🌀",
      "patient" => "🐢",
      "neutral" => "😐",
      "bored" => "😑",
      "mixed" => "🌊",
      "indifferent" => "🤷",
      "okay" => "👍",
      "meh" => "😶‍🌫️",
      "blah" => "😶",
      "numb" => "🫠",
      "tired" => "😴",
      "exhausted" => "🥱",
      "drained" => "🔋",
      "sleepy" => "😪",
      "fatigued" => "🫠",
      "burnedout" => "🪫",
      "latenight" => "🌙",
      "groggy" => "🥴",
      "weary" => "😩",
      "surprised" => "😲",
      "amazed" => "🤯",
      "shocked" => "😱",
      "astonished" => "😮",
      "bewildered" => "😵‍💫",
      "anxious" => "😰",
      "worried" => "😟",
      "stressed" => "😫",
      "nervous" => "😬",
      "restless" => "🌀",
      "uneasy" => "😧",
      "tense" => "😣",
      "panicked" => "😨",
      "sad" => "😢",
      "lonely" => "🥺",
      "melancholic" => "🌧️",
      "heartbroken" => "💔",
      "grieving" => "🖤",
      "down" => "😞",
      "hopeless" => "🕳️",
      "disappointed" => "😔",
      "empty" => "🫥",
      "nostalgic" => "📷",
      "reminiscing" => "📼",
      "thoughtful" => "🤔",
      "contemplative" => "🌌",
      "introspective" => "🪞",
      "pensive" => "💭",
      "wistful" => "🍂",
      "frustrated" => "😤",
      "angry" => "😠",
      "overwhelmed" => "🤯",
      "irritated" => "😒",
      "resentful" => "😾",
      "bitter" => "🍋",
      "annoyed" => "🙄",
      "rageful" => "🔴",
      "hurt" => "🩹",
      "embarrassed" => "😳",
      "ashamed" => "😣",
      "insecure" => "🐚",
      "exposed" => "🥀",
      "fragile" => "🥚",
      "scared" => "😨",
      "jealous" => "💚",
      "confused" => "😵‍💫",
      "lost" => "🧭",
      "uncertain" => "❓",
      "conflicted" => "⚖️",
      "torn" => "💭",
      "doubtful" => "🤨",
      "relieved" => "😮‍💨",
      "free" => "🕊️",
      "liberated" => "🦅",
      "unburdened" => "🎈",
      "light" => "🪶"
    }

    Map.get(mood_map, mood, "")
  end

  def mood_emoji(_), do: ""

  @doc """
  Returns the label for a given mood string.
  """
  def mood_label(mood) when is_binary(mood) do
    String.capitalize(mood)
  end

  def mood_label(_), do: ""

  # Status dot/ping helper functions (shared with TimelineComponents)
  defp timeline_status_dot_size("online"), do: "w-2 h-2"
  defp timeline_status_dot_size("active"), do: "w-2.5 h-2.5"
  defp timeline_status_dot_size("calm"), do: "w-2.5 h-2.5"
  defp timeline_status_dot_size("away"), do: "w-2 h-2"
  defp timeline_status_dot_size("busy"), do: "w-2 h-2"
  defp timeline_status_dot_size("offline"), do: "w-1.5 h-1.5"

  defp timeline_status_dot_classes("online"), do: "bg-gradient-to-br from-emerald-400 to-teal-500"
  defp timeline_status_dot_classes("active"), do: "bg-gradient-to-br from-blue-400 to-emerald-500"
  defp timeline_status_dot_classes("calm"), do: "bg-gradient-to-br from-teal-400 to-emerald-500"
  defp timeline_status_dot_classes("away"), do: "bg-gradient-to-br from-amber-400 to-orange-500"
  defp timeline_status_dot_classes("busy"), do: "bg-gradient-to-br from-rose-400 to-pink-500"
  defp timeline_status_dot_classes("offline"), do: "bg-gradient-to-br from-slate-400 to-gray-500"

  defp timeline_status_ping_classes("online"), do: "bg-emerald-400"
  defp timeline_status_ping_classes("active"), do: "bg-blue-400"
  defp timeline_status_ping_classes("away"), do: "bg-amber-400"
  defp timeline_status_ping_classes("busy"), do: "bg-rose-400"
  defp timeline_status_ping_classes("calm"), do: "bg-teal-400"
  defp timeline_status_ping_classes("offline"), do: "bg-slate-400"
  defp timeline_status_ping_classes(_), do: ""
end
