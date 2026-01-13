defmodule MossletWeb.DesignSystem do
  @moduledoc """
  Reusable components following the Mosslet Design System.

  This module provides consistent implementations of common UI patterns
  using our liquid metal aesthetic with teal-to-emerald gradients.

  See DESIGN_SYSTEM.md for detailed guidelines and principles.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  # Import components for time display
  import MossletWeb.CoreComponents, only: [phx_input: 1, local_time_ago: 1]
  import MossletWeb.LocalTime, only: [local_time: 1]

  # Import helper functions
  import MossletWeb.Helpers,
    only: [
      alpine_autofocus: 0,
      contains_html?: 1,
      format_decrypted_content: 1,
      format_decrypted_content_orange: 1,
      decr: 3,
      decr_uconn: 4,
      html_block: 1,
      is_connected_to_reply_author?: 2,
      is_shared_recipient?: 2,
      get_reply_post_key: 2,
      get_safe_reply_author_name: 3,
      photos?: 1,
      user_name: 2,
      maybe_get_user_avatar: 2,
      decr_item: 6,
      show_avatar?: 1,
      maybe_get_avatar_src: 4,
      get_uconn_for_shared_item: 2
    ]

  # Import StatusHelpers for consistent status message handling
  import MossletWeb.Helpers.StatusHelpers,
    only: [
      can_view_status?: 3,
      get_status_fallback_message: 1,
      get_user_status_info: 3,
      get_user_status_message: 3
    ]

  alias Mosslet.Accounts
  alias Mosslet.Accounts.Scope
  alias Mosslet.Timeline
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

  defp word_count(nil), do: 0
  defp word_count(""), do: 0

  defp word_count(text) when is_binary(text) do
    text |> String.split(~r/\s+/, trim: true) |> length()
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
    values: ~w(teal emerald blue purple amber rose cyan indigo slate orange)

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
                <.footer_link href="/discover" label="Discover" />
              </ul>
            </div>

            <%!-- Resources Column --%>
            <div class="space-y-3">
              <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 uppercase tracking-wider">
                Resources
              </h3>
              <ul class="space-y-2">
                <.footer_link href="/faq" label="FAQ" />
                <.footer_link href="/support" label="Support" />
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
                "relative w-full max-h-[95vh] min-h-0 flex flex-col overflow-y-auto",
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
                  <div
                    id="comparison-beta-pricing"
                    phx-hook="TippyHook"
                    data-tippy-content="Beta pricing - 50% off regular price"
                    class="inline-block cursor-help"
                  >
                    <div class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                      From $80/yr
                    </div>
                    <div class="text-xs text-emerald-600 dark:text-emerald-400">
                      Or lifetime • Beta
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

  ## Examples

      <.liquid_avatar src="/path/to/avatar.jpg" name="John Doe" size="md" />
      <.liquid_avatar src="/path/to/avatar.jpg" name="Jane" size="lg" status="online" />
      <.liquid_avatar name="Anonymous" size="sm" verified={true} />
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

  attr :rest, :global

  def liquid_avatar(assigns) do
    assigns = assign(assigns, :avatar_url, assigns.src || "/images/logo.svg")

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
          position="right"
          class=""
        />
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
    assigns =
      assign(assigns, :color_classes, get_tab_color_classes(assigns.tab_color))

    ~H"""
    <div class={["relative py-6", @class]}>
      <div class="absolute inset-0 flex items-center" aria-hidden="true">
        <div class={[
          "w-full h-px bg-gradient-to-r from-transparent to-transparent",
          @color_classes.divider_line
        ]} />
      </div>

      <div class="relative flex justify-center">
        <button
          type="button"
          class={[
            "group inline-flex items-center gap-2.5 px-5 py-2.5 rounded-full",
            "bg-white dark:bg-slate-800",
            "border",
            @color_classes.border,
            "shadow-lg shadow-slate-900/5 dark:shadow-black/20",
            "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-black/30",
            @color_classes.hover_border,
            "focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-slate-900",
            @color_classes.focus_ring,
            "transition-all duration-300 ease-out",
            "transform hover:scale-[1.02] active:scale-[0.98]",
            "phx-click-loading:cursor-wait phx-click-loading:opacity-90",
            @loading && "cursor-wait opacity-80"
          ]}
          disabled={@loading}
          {@rest}
        >
          <div class="phx-click-loading:flex hidden items-center gap-2">
            <div class={[
              "h-4 w-4 animate-spin rounded-full border-2",
              @color_classes.spinner
            ]} />
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">
              Loading...
            </span>
          </div>

          <div :if={@loading} class="phx-click-loading:hidden flex items-center gap-2">
            <div class={[
              "h-4 w-4 animate-spin rounded-full border-2",
              @color_classes.spinner
            ]} />
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">
              Loading more posts...
            </span>
          </div>

          <div :if={!@loading} class="phx-click-loading:hidden flex items-center gap-2.5">
            <div class={[
              "flex items-center justify-center w-6 h-6 rounded-full",
              "bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-700 dark:to-slate-800",
              @color_classes.icon_bg_hover,
              "transition-all duration-300"
            ]}>
              <.phx_icon
                name="hero-arrow-down"
                class={[
                  "w-3.5 h-3.5 text-slate-500 dark:text-slate-400",
                  @color_classes.icon_hover,
                  "transition-all duration-300"
                ]}
              />
            </div>

            <span class="text-sm font-medium text-slate-600 dark:text-slate-300 group-hover:text-slate-800 dark:group-hover:text-slate-100 transition-colors">
              <span class="text-slate-500 dark:text-slate-400">Load</span>
              <span class={[
                "inline-flex items-center justify-center min-w-[1.5rem] px-1.5 py-0.5 mx-1",
                "text-xs font-semibold rounded-full",
                "text-white shadow-sm",
                @color_classes.badge
              ]}>
                {@load_count}
              </span>
              <span class="text-slate-500 dark:text-slate-400">more</span>
              <span class="text-slate-500 dark:text-slate-400 ml-1">({@remaining_count} left)</span>
            </span>

            <div class={[
              "flex items-center justify-center w-6 h-6 rounded-full",
              "bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-700 dark:to-slate-800",
              @color_classes.icon_bg_hover,
              "transition-all duration-300"
            ]}>
              <.phx_icon
                name="hero-plus"
                class={[
                  "w-3.5 h-3.5 text-slate-400 dark:text-slate-500",
                  @color_classes.icon_hover,
                  "transition-colors duration-300"
                ]}
              />
            </div>
          </div>
        </button>
      </div>
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
      "bookmarks" -> "orange"
      # This maps to indigo-blue gradient
      "discover" -> "purple"
      _ -> "slate"
    end
  end

  # Helper function to get color classes for different tabs
  def get_tab_color_classes(tab_color) do
    case tab_color do
      "emerald" ->
        %{
          badge: "bg-gradient-to-br from-emerald-500 to-teal-600 shadow-emerald-500/30",
          focus_ring: "focus:ring-emerald-500/50",
          icon_hover: "group-hover:text-emerald-600 dark:group-hover:text-emerald-400",
          icon_bg_hover:
            "group-hover:from-emerald-100 group-hover:to-teal-50 dark:group-hover:from-emerald-900/40 dark:group-hover:to-teal-900/30",
          spinner: "border-emerald-500/30 border-t-emerald-500",
          divider_line: "via-emerald-300/40 dark:via-emerald-600/40",
          button:
            "bg-gradient-to-r from-emerald-500 to-teal-600 text-white focus:ring-emerald-500/50",
          indicator: "bg-emerald-400",
          border: "border-emerald-200/80 dark:border-emerald-700/80",
          hover_border: "hover:border-emerald-300 dark:hover:border-emerald-600"
        }

      "teal" ->
        %{
          badge: "bg-gradient-to-br from-blue-500 to-cyan-600 shadow-blue-500/30",
          focus_ring: "focus:ring-blue-500/50",
          icon_hover: "group-hover:text-blue-600 dark:group-hover:text-blue-400",
          icon_bg_hover:
            "group-hover:from-blue-100 group-hover:to-cyan-50 dark:group-hover:from-blue-900/40 dark:group-hover:to-cyan-900/30",
          spinner: "border-blue-500/30 border-t-blue-500",
          divider_line: "via-blue-300/40 dark:via-blue-600/40",
          button: "bg-gradient-to-r from-blue-500 to-cyan-600 text-white focus:ring-blue-500/50",
          indicator: "bg-blue-400",
          border: "border-blue-200/80 dark:border-blue-700/80",
          hover_border: "hover:border-blue-300 dark:hover:border-blue-600"
        }

      "blue" ->
        %{
          badge: "bg-gradient-to-br from-purple-500 to-violet-600 shadow-purple-500/30",
          focus_ring: "focus:ring-purple-500/50",
          icon_hover: "group-hover:text-purple-600 dark:group-hover:text-purple-400",
          icon_bg_hover:
            "group-hover:from-purple-100 group-hover:to-violet-50 dark:group-hover:from-purple-900/40 dark:group-hover:to-violet-900/30",
          spinner: "border-purple-500/30 border-t-purple-500",
          divider_line: "via-purple-300/40 dark:via-purple-600/40",
          button:
            "bg-gradient-to-r from-purple-500 to-violet-600 text-white focus:ring-purple-500/50",
          indicator: "bg-purple-400",
          border: "border-purple-200/80 dark:border-purple-700/80",
          hover_border: "hover:border-purple-300 dark:hover:border-purple-600"
        }

      "purple" ->
        %{
          badge: "bg-gradient-to-br from-indigo-500 to-blue-600 shadow-indigo-500/30",
          focus_ring: "focus:ring-indigo-500/50",
          icon_hover: "group-hover:text-indigo-600 dark:group-hover:text-indigo-400",
          icon_bg_hover:
            "group-hover:from-indigo-100 group-hover:to-blue-50 dark:group-hover:from-indigo-900/40 dark:group-hover:to-blue-900/30",
          spinner: "border-indigo-500/30 border-t-indigo-500",
          divider_line: "via-indigo-300/40 dark:via-indigo-600/40",
          button:
            "bg-gradient-to-r from-indigo-500 to-blue-600 text-white focus:ring-indigo-500/50",
          indicator: "bg-indigo-400",
          border: "border-indigo-200/80 dark:border-indigo-700/80",
          hover_border: "hover:border-indigo-300 dark:hover:border-indigo-600"
        }

      "orange" ->
        %{
          badge: "bg-gradient-to-br from-amber-500 to-orange-600 shadow-amber-500/30",
          focus_ring: "focus:ring-amber-500/50",
          icon_hover: "group-hover:text-amber-600 dark:group-hover:text-amber-400",
          icon_bg_hover:
            "group-hover:from-amber-100 group-hover:to-orange-50 dark:group-hover:from-amber-900/40 dark:group-hover:to-orange-900/30",
          spinner: "border-amber-500/30 border-t-amber-500",
          divider_line: "via-amber-300/40 dark:via-amber-600/40",
          button:
            "bg-gradient-to-r from-amber-500 to-orange-600 text-white focus:ring-amber-500/50",
          indicator: "bg-amber-400",
          border: "border-amber-200/80 dark:border-amber-700/80",
          hover_border: "hover:border-amber-300 dark:hover:border-amber-600"
        }

      "cyan" ->
        %{
          badge: "bg-gradient-to-br from-cyan-500 to-teal-600 shadow-cyan-500/30",
          focus_ring: "focus:ring-cyan-500/50",
          icon_hover: "group-hover:text-cyan-600 dark:group-hover:text-cyan-400",
          icon_bg_hover:
            "group-hover:from-cyan-100 group-hover:to-teal-50 dark:group-hover:from-cyan-900/40 dark:group-hover:to-teal-900/30",
          spinner: "border-cyan-500/30 border-t-cyan-500",
          divider_line: "via-cyan-300/40 dark:via-cyan-600/40",
          button: "bg-gradient-to-r from-cyan-500 to-teal-600 text-white focus:ring-cyan-500/50",
          indicator: "bg-cyan-400",
          border: "border-cyan-200/80 dark:border-cyan-700/80",
          hover_border: "hover:border-cyan-300 dark:hover:border-cyan-600"
        }

      "indigo" ->
        %{
          badge: "bg-gradient-to-br from-indigo-500 to-blue-600 shadow-indigo-500/30",
          focus_ring: "focus:ring-indigo-500/50",
          icon_hover: "group-hover:text-indigo-600 dark:group-hover:text-indigo-400",
          icon_bg_hover:
            "group-hover:from-indigo-100 group-hover:to-blue-50 dark:group-hover:from-indigo-900/40 dark:group-hover:to-blue-900/30",
          spinner: "border-indigo-500/30 border-t-indigo-500",
          divider_line: "via-indigo-300/40 dark:via-indigo-600/40",
          button:
            "bg-gradient-to-r from-indigo-500 to-blue-600 text-white focus:ring-indigo-500/50",
          indicator: "bg-indigo-400",
          border: "border-indigo-200/80 dark:border-indigo-700/80",
          hover_border: "hover:border-indigo-300 dark:hover:border-indigo-600"
        }

      _ ->
        %{
          badge: "bg-gradient-to-br from-slate-500 to-slate-600 shadow-slate-500/30",
          focus_ring: "focus:ring-slate-500/50",
          icon_hover: "group-hover:text-slate-600 dark:group-hover:text-slate-400",
          icon_bg_hover:
            "group-hover:from-slate-200 group-hover:to-slate-100 dark:group-hover:from-slate-700 dark:group-hover:to-slate-600",
          spinner: "border-slate-500/30 border-t-slate-500",
          divider_line: "via-slate-300/40 dark:via-slate-600/40",
          button:
            "bg-gradient-to-r from-slate-500 to-slate-600 text-white focus:ring-slate-500/50",
          indicator: "bg-slate-400",
          border: "border-slate-200/80 dark:border-slate-700/80",
          hover_border: "hover:border-slate-300 dark:hover:border-slate-600"
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
        "text-center",
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
  A beautiful, calm "New Post" prompt card that navigates to the timeline composer.
  Perfect for profile pages and dashboards.
  """
  attr :user_name, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :placeholder, :string, default: "Share something meaningful..."
  attr :class, :any, default: ""
  attr :id, :string, default: "new-post-prompt"
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :show_status, :boolean, default: false
  attr :status_message, :string, default: nil

  def liquid_new_post_prompt(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <.link
      navigate={~p"/app/timeline"}
      id={@id}
      class={[
        "block relative rounded-2xl transition-all duration-300 ease-out",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-xl",
        "border border-slate-200/80 dark:border-slate-700/80",
        "shadow-lg shadow-slate-900/5 dark:shadow-black/30",
        "ring-1 ring-slate-900/5 dark:ring-white/5",
        "hover:shadow-xl hover:shadow-emerald-500/10 dark:hover:shadow-emerald-500/5",
        "hover:border-emerald-400/60 dark:hover:border-emerald-500/40",
        "hover:scale-[1.01] active:scale-[0.99]",
        "focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-500/60",
        "group cursor-pointer",
        @class
      ]}
    >
      <%!-- Subtle liquid gradient background on hover --%>
      <div class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/20 to-cyan-50/30 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-cyan-900/10">
      </div>

      <%!-- Content --%>
      <div class="relative p-4 sm:p-5">
        <div class="flex items-center gap-3 sm:gap-4">
          <%!-- User avatar --%>
          <div class="flex-shrink-0">
            <.liquid_avatar
              src={@user_avatar}
              name={@user_name}
              size="md"
              status={
                if @current_scope.user,
                  do: to_string(@current_scope.user.status || "offline"),
                  else: "offline"
              }
              status_message={@status_message}
              user_id={if @current_scope.user, do: @current_scope.user.id}
              show_status={@show_status}
              id={"#{@id}-avatar"}
            />
          </div>

          <%!-- Prompt text area simulation --%>
          <div class="flex-1 min-w-0">
            <div class={[
              "w-full px-4 py-3 rounded-xl",
              "bg-slate-50/80 dark:bg-slate-700/50",
              "border border-slate-200/60 dark:border-slate-600/40",
              "group-hover:bg-emerald-50/50 dark:group-hover:bg-emerald-900/20",
              "group-hover:border-emerald-200/60 dark:group-hover:border-emerald-700/40",
              "transition-all duration-200"
            ]}>
              <span class="text-slate-500 dark:text-slate-400 text-sm sm:text-base group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors duration-200">
                {@placeholder}
              </span>
            </div>
          </div>

          <%!-- Action icons (visible on larger screens) --%>
          <div class="hidden sm:flex items-center gap-2">
            <div class="p-2 rounded-lg text-slate-400 dark:text-slate-500 group-hover:text-emerald-500 dark:group-hover:text-emerald-400 transition-colors duration-200">
              <.phx_icon name="hero-photo" class="h-5 w-5" />
            </div>
            <div class="p-2 rounded-lg text-slate-400 dark:text-slate-500 group-hover:text-emerald-500 dark:group-hover:text-emerald-400 transition-colors duration-200">
              <.phx_icon name="hero-face-smile" class="h-5 w-5" />
            </div>
          </div>

          <%!-- Arrow indicator --%>
          <div class="flex-shrink-0 p-2 rounded-full bg-emerald-100/80 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 group-hover:bg-emerald-500 dark:group-hover:bg-emerald-500 group-hover:text-white transition-all duration-200">
            <.phx_icon
              name="hero-arrow-right"
              class="h-4 w-4 sm:h-5 sm:w-5 transition-transform duration-200 group-hover:translate-x-0.5"
            />
          </div>
        </div>

        <%!-- Mobile hint --%>
        <div class="sm:hidden mt-3 flex items-center justify-center gap-4 text-xs text-slate-600 dark:text-slate-400">
          <div class="flex items-center gap-1">
            <.phx_icon name="hero-photo" class="h-3.5 w-3.5" />
            <span>Photos</span>
          </div>
          <div class="flex items-center gap-1">
            <.phx_icon name="hero-face-smile" class="h-3.5 w-3.5" />
            <span>Emoji</span>
          </div>
          <div class="flex items-center gap-1">
            <.phx_icon name="hero-lock-closed" class="h-3.5 w-3.5" />
            <span>Privacy</span>
          </div>
        </div>
      </div>
    </.link>
    """
  end

  @doc """
  Timeline composer with enhanced liquid metal avatar and calm design focus.
  """
  attr :user_name, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :placeholder, :string, default: "What's on your mind?"
  attr :word_limit, :integer, default: 500
  attr :privacy_level, :string, default: "connections", values: ~w(public connections private)
  attr :selector, :string, default: "connections"
  attr :form, :any, required: true
  attr :uploads, :any, default: nil
  attr :upload_stages, :map, default: %{}
  attr :completed_uploads, :list, default: []
  attr :class, :any, default: ""
  attr :privacy_controls_expanded, :boolean, default: false
  attr :content_warning_enabled?, :boolean, default: false
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :id, :string, default: nil
  attr :url_preview, :map, default: nil
  attr :url_preview_loading, :boolean, default: false
  attr :collapsed, :boolean, default: false

  def liquid_timeline_composer_enhanced(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <div
      :if={!@collapsed}
      id={@id}
      phx-remove={
        JS.transition(
          {"ease-out duration-150", "opacity-100 scale-100", "opacity-0 scale-[0.97]"},
          time: 150
        )
      }
      class={[
        "relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
        "bg-white dark:bg-slate-800 backdrop-blur-xl",
        "border-2 border-emerald-200/80 dark:border-emerald-700/60",
        "shadow-xl shadow-emerald-500/10 dark:shadow-emerald-900/30",
        "ring-1 ring-emerald-500/10 dark:ring-emerald-400/10",
        "hover:shadow-2xl hover:shadow-emerald-500/15 dark:hover:shadow-emerald-900/40",
        "hover:border-emerald-300/80 dark:hover:border-emerald-600/60",
        "focus-within:border-emerald-400 dark:focus-within:border-emerald-500",
        "focus-within:shadow-2xl focus-within:shadow-emerald-500/20",
        "focus-within:ring-2 focus-within:ring-emerald-500/30",
        "animate-in fade-in slide-in-from-top-2 duration-300",
        @class
      ]}
    >
      <button
        type="button"
        id={"collapse-composer-btn-#{@id}"}
        phx-click="toggle_composer_collapsed"
        class={[
          "absolute top-3 right-3 z-20 p-2 rounded-full",
          "bg-slate-100/80 dark:bg-slate-700/80 backdrop-blur-sm",
          "text-slate-500 dark:text-slate-400",
          "hover:bg-slate-200/90 dark:hover:bg-slate-600/90",
          "hover:text-slate-700 dark:hover:text-slate-200",
          "hover:scale-110 active:scale-95",
          "transition-all duration-200 ease-out",
          "focus:outline-none focus:ring-2 focus:ring-slate-400/40",
          "shadow-sm hover:shadow-md"
        ]}
        title="Collapse composer"
        phx-hook="TippyHook"
        data-tippy-content="Collapse composer"
      >
        <.phx_icon name="hero-x-mark" class="h-3.5 w-3.5" />
      </button>

      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/20 to-cyan-50/30 dark:from-emerald-900/20 dark:via-teal-900/10 dark:to-cyan-900/20 focus-within:opacity-100">
      </div>

      <div class="relative p-6 animate-in fade-in duration-200 overflow-auto max-h-[calc(100vh-10rem)]">
        <%!-- User section with enhanced liquid avatar --%>
        <div class="flex items-start gap-4 mb-4">
          <%!-- Enhanced liquid metal avatar --%>
          <.liquid_avatar
            src={@user_avatar}
            name={@user_name}
            size="md"
            status={to_string(@current_scope.user.status || "offline")}
            user_id={@current_scope.user.id}
            status_message={
              get_user_status_message(@current_scope.user, @current_scope.user, @current_scope.key)
            }
            show_status={
              can_view_status?(@current_scope.user, @current_scope.user, @current_scope.key)
            }
            id={"composer-avatar-#{@id}"}
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
                class="w-full resize-none border-0 bg-transparent text-slate-900 dark:text-slate-100 placeholder:text-slate-500 dark:placeholder:text-slate-400 text-lg leading-relaxed focus:outline-none focus:ring-0"
                phx-hook="WordCounter"
                phx-debounce="500"
                data-limit={@word_limit}
                value={@form[:body].value}
                {alpine_autofocus()}
              >{@form[:body].value}</textarea>

              <%!-- Word counter (shows when textarea has content) --%>
              <div
                class={[
                  "absolute bottom-2 right-2 transition-all duration-300 ease-out",
                  (@form[:body].value && String.trim(@form[:body].value) != "" && "opacity-100") ||
                    "opacity-0"
                ]}
                id={"word-counter-#{@word_limit}"}
              >
                <span class="text-xs text-slate-500 dark:text-slate-400 bg-white/95 dark:bg-slate-800/95 px-3 py-1.5 rounded-full backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg">
                  <span class="js-word-count">{word_count(@form[:body].value)}</span>/{@word_limit} words
                </span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Photo upload preview section --%>
        <.liquid_photo_upload_preview
          :if={@uploads}
          uploads={@uploads}
          upload_stages={@upload_stages}
          completed_uploads={@completed_uploads}
          class=""
        />
        <%!-- URL Preview Section --%>
        <div :if={assigns[:url_preview_loading]} class="mt-4 animate-pulse">
          <div class="flex gap-3 p-2 rounded-xl border border-slate-200/60 dark:border-slate-700/40 bg-slate-50/50 dark:bg-slate-800/50">
            <div class="w-20 h-14 shrink-0 rounded-lg bg-slate-200 dark:bg-slate-700"></div>
            <div class="flex-1 space-y-2 py-0.5">
              <div class="h-4 w-3/4 rounded bg-slate-200 dark:bg-slate-700"></div>
              <div class="h-3 w-full rounded bg-slate-200 dark:bg-slate-700"></div>
            </div>
          </div>
        </div>

        <div :if={assigns[:url_preview] && !assigns[:url_preview_loading]} class="mt-4">
          <div class="relative group">
            <button
              type="button"
              phx-click="remove_url_preview"
              class="absolute -top-2 -right-2 z-10 p-1 rounded-full bg-slate-900/80 text-white hover:bg-slate-900 transition-all opacity-0 group-hover:opacity-100"
            >
              <.phx_icon name="hero-x-mark" class="w-4 h-4" />
            </button>

            <div class="flex gap-3 p-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white/95 dark:bg-slate-800/95 hover:border-emerald-400 dark:hover:border-emerald-500 transition-all duration-200">
              <div
                :if={@url_preview["image"] && @url_preview["image"] != ""}
                class="w-20 h-14 shrink-0 overflow-hidden rounded-lg"
                phx-hook="ImageErrorHook"
                id={"url-preview-image-#{@id}"}
              >
                <img
                  src={@url_preview["image"]}
                  alt={@url_preview["title"] || "Preview image"}
                  class="w-full h-full object-cover"
                />
              </div>

              <div class="flex-1 min-w-0 py-0.5">
                <div class="flex items-center gap-1.5 mb-0.5">
                  <.phx_icon name="hero-link" class="h-3 w-3 text-emerald-500" />
                  <span class="text-xs text-slate-500 dark:text-slate-400 truncate">
                    {@url_preview["site_name"]}
                  </span>
                </div>

                <p
                  :if={@url_preview["title"]}
                  class="font-medium text-sm text-slate-900 dark:text-slate-100 line-clamp-1"
                >
                  {@url_preview["title"]}
                </p>

                <p
                  :if={@url_preview["description"]}
                  class="text-xs text-slate-600 dark:text-slate-400 line-clamp-2 mt-0.5"
                >
                  {@url_preview["description"]}
                </p>
              </div>
            </div>
          </div>
        </div>

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
              data-tippy-content="Add photos (GIF, JPG, PNG up to 10MB each)"
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
              aria-label={
                if @content_warning_enabled?,
                  do: "Remove content warning",
                  else: "Add content warning"
              }
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

            <.liquid_markdown_guide_trigger
              id="composer-markdown-guide-trigger"
              on_click={JS.push("open_markdown_guide")}
            />
          </div>

          <%!-- Privacy controls and post button with improved mobile stacking --%>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-end gap-3">
            <%!-- Hidden field for form data integrity --%>
            <input
              type="hidden"
              name={@form[:visibility].name}
              value={@selector}
              id="privacy-hidden-field"
            />

            <%!-- Enhanced privacy selector with mobile-friendly full width --%>
            <div
              id={"privacy-selector-#{@selector}"}
              class={[
                "relative inline-flex items-center gap-2 px-3 py-2.5 rounded-full text-sm",
                "w-full sm:w-auto justify-center sm:justify-start",
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

            <%!-- Post button with mobile-friendly full width --%>
            <.liquid_button
              size="md"
              type="submit"
              class="w-full sm:w-auto sm:flex-shrink-0"
              phx-disable-with="Sharing..."
              disabled={true}
            >
              Share thoughtfully
            </.liquid_button>
          </div>
        </div>

        <%!-- Compact Privacy Controls Section (conditionally shown) --%>
        <%= if @privacy_controls_expanded do %>
          <div class="mt-3 nested-reply-expand-enter">
            <.liquid_compact_privacy_controls
              form={@form}
              selector={@selector}
              current_scope={@current_scope}
            />
          </div>
        <% end %>

        <%!-- Content Warning Section (conditionally shown) --%>
        <%= if @content_warning_enabled? do %>
          <div class="mt-3 p-3 rounded-lg bg-teal-50/50 dark:bg-teal-900/20 border border-teal-200/60 dark:border-teal-700/50">
            <div class="flex items-center gap-1.5 mb-2">
              <.phx_icon
                name="hero-hand-raised"
                class="h-3.5 w-3.5 text-teal-600 dark:text-teal-400"
              />
              <span class="text-xs font-medium text-teal-700 dark:text-teal-300">
                Content Warning
              </span>
            </div>

            <div class="space-y-2.5">
              <div class="relative">
                <textarea
                  id="content-warning-textarea"
                  name={@form[:content_warning].name}
                  placeholder="e.g., Discussion of mental health, sensitive content..."
                  rows="2"
                  maxlength="100"
                  class="w-full resize-none text-sm leading-relaxed rounded-lg px-3 py-2 bg-white dark:bg-slate-800 border border-teal-200 dark:border-teal-700 hover:border-teal-300 dark:hover:border-teal-600 focus:border-teal-500 dark:focus:border-teal-400 focus:ring-1 focus:ring-teal-500/20 text-slate-900 dark:text-slate-100 placeholder:text-teal-600/60 dark:placeholder:text-teal-400/60 transition-colors duration-200"
                  phx-hook="CharacterCounter"
                  phx-debounce="300"
                  data-limit="100"
                  value={@form[:content_warning].value}
                >{@form[:content_warning].value}</textarea>

                <div
                  class={[
                    "absolute bottom-1.5 right-1.5 transition-opacity duration-200",
                    (@form[:content_warning].value && String.trim(@form[:content_warning].value) != "" &&
                       "opacity-100") ||
                      "opacity-0"
                  ]}
                  id="char-counter-100"
                >
                  <span class="text-[10px] text-teal-600 dark:text-teal-400 bg-teal-50/90 dark:bg-teal-900/90 px-1.5 py-0.5 rounded-full">
                    <span class="js-char-count">{String.length(@form[:content_warning].value || "")}</span>/100
                  </span>
                </div>
              </div>

              <.liquid_select_custom
                field={@form[:content_warning_category]}
                label="Category (optional)"
                prompt="Select category..."
                color="teal"
                class="text-xs"
                options={[
                  {"Violence", "violence"},
                  {"Graphic Content", "graphic"},
                  {"Mental Health", "mental_health"},
                  {"Substance Use", "substance_use"},
                  {"Sexual Content", "sexual"},
                  {"Spoilers", "spoilers"},
                  {"Politics", "politics"},
                  {"News", "news"},
                  {"Flashing/Strobing", "flashing"},
                  {"Personal/Sensitive", "personal"},
                  {"Other", "other"}
                ]}
              />

              <%!-- 18+ Mature Content Toggle - Styled as a prominent button --%>
              <div class="pt-3 mt-3 border-t border-teal-200/40 dark:border-teal-700/30">
                <.mature_content_toggle field={@form[:mature_content]} />
              </div>
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
  defp humanize_upload_error(:too_large), do: "File is too large (max 10MB)"
  defp humanize_upload_error(:too_many_files), do: "Too many files (max 10 photos)"

  defp humanize_upload_error(:not_accepted),
    do: "File type not supported (GIF, JPG, PNG, WEBP, HEIC/HEIF only)"

  defp humanize_upload_error(error), do: "Upload error: #{error}"

  @doc """
  Liquid metal photo gallery component for timeline posts.
  Integrates with existing TrixContentPostHook and encrypted image system.
  """
  attr :post, :any, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :class, :any, default: ""

  def liquid_post_photo_gallery(assigns) do
    assigns = assign_scope_fields(assigns)
    image_count = length(assigns.post.image_urls)

    grid_class =
      cond do
        image_count == 1 -> "grid-cols-6"
        image_count == 2 -> "grid-cols-6"
        image_count <= 4 -> "grid-cols-6"
        image_count <= 6 -> "grid-cols-6 sm:grid-cols-8"
        true -> "grid-cols-6 sm:grid-cols-8 lg:grid-cols-10"
      end

    assigns = assign(assigns, :grid_class, grid_class)
    assigns = assign(assigns, :image_count, image_count)

    ~H"""
    <div
      :if={photos?(@post.image_urls)}
      id={"photo-gallery-#{@post.id}"}
      class={[
        "mt-3 overflow-hidden rounded-lg border border-slate-200/60 dark:border-slate-700/60",
        "bg-slate-50/50 dark:bg-slate-800/30",
        @class
      ]}
    >
      <div
        id={"post-body-#{@post.id}"}
        phx-hook="TrixContentPostHook"
        class="photos-container p-2"
        data-image-count={@image_count}
        data-grid-class={@grid_class}
      >
        <div class={"grid #{@grid_class} gap-1.5"}>
          <div
            :for={{_image_url, index} <- Enum.with_index(@post.image_urls)}
            class="group relative overflow-hidden rounded-md bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-800"
            style={"animation-delay: #{index * 100}ms"}
          >
            <div class="aspect-square flex items-center justify-center">
              <div class="relative">
                <div class="w-6 h-6 rounded-full bg-slate-200/80 dark:bg-slate-600/80 flex items-center justify-center">
                  <.phx_icon
                    name="hero-photo"
                    class="h-3 w-3 text-slate-400 dark:text-slate-500"
                  />
                </div>
                <div class="absolute inset-0 rounded-full border-2 border-transparent border-t-emerald-500/30 animate-spin opacity-0 group-[.photos-loading]:opacity-100 transition-opacity duration-300">
                </div>
              </div>
            </div>
            <div class="absolute bottom-1 right-1 px-1 py-0.5 rounded text-[10px] bg-black/30 text-white font-medium backdrop-blur-sm">
              {index + 1}/{@image_count}
            </div>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-between px-2.5 py-1.5">
        <div class="flex items-center gap-2">
          <div class="flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
            <.phx_icon name="hero-photo" class="h-3.5 w-3.5" />
            <span>{@image_count} {if @image_count == 1, do: "photo", else: "photos"}</span>
          </div>
          <span
            :if={@post.ai_generated}
            class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-[10px] font-medium bg-violet-500/10 text-violet-600 dark:text-violet-400"
          >
            <.phx_icon name="hero-sparkles" class="h-2.5 w-2.5" /> AI
          </span>
        </div>

        <button
          id={"post-#{@post.id}-show-photos-#{@current_scope.user.id}"}
          class="group inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium transition-all duration-200 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 hover:bg-emerald-500/20 active:scale-[0.97]"
          phx-click={
            JS.add_class("photos-loading", to: "#post-body-#{@post.id}")
            |> JS.dispatch("mosslet:show-post-photos-#{@post.id}",
              to: "#post-body-#{@post.id}",
              detail: %{post_id: @post.id, user_id: @current_scope.user.id}
            )
            |> JS.hide(to: "#post-#{@post.id}-show-photos-#{@current_scope.user.id}")
            |> JS.show(to: "#post-#{@post.id}-loading-indicator", display: "inline-flex")
          }
          phx-hook="TippyHook"
          data-tippy-content="Decrypt and display photos"
        >
          <.phx_icon name="hero-eye" class="h-3.5 w-3.5" />
          <span>View</span>
        </button>

        <div
          id={"post-#{@post.id}-loading-indicator"}
          style="display: none;"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400"
        >
          <svg
            class="animate-spin h-3 w-3 text-emerald-500"
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
          <span>Decrypting...</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Enhanced photo upload preview with liquid metal styling for the composer.
  Shows real processing stages: receiving, validating, processing, uploading, ready.
  """
  attr :uploads, :any, required: true
  attr :upload_stages, :map, default: %{}
  attr :completed_uploads, :list, default: []
  attr :class, :any, default: ""

  def liquid_photo_upload_preview(assigns) do
    ~H"""
    <div
      :if={
        (@uploads && @uploads.photos && @uploads.photos.entries != []) ||
          @completed_uploads != []
      }
      class={[
        "mt-4 p-4 rounded-xl border border-slate-200/60 dark:border-slate-700/60",
        "bg-gradient-to-br from-emerald-50/30 to-teal-50/20 dark:from-emerald-900/10 dark:to-teal-900/5",
        @class
      ]}
    >
      <% total_count = length(@uploads.photos.entries) + length(@completed_uploads) %>
      <% entries_count = length(@uploads.photos.entries) %>
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <.phx_icon
            name="hero-cloud-arrow-up"
            class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
          />
          <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
            {total_count} {if total_count == 1, do: "photo", else: "photos"}
          </span>
        </div>

        <div class="text-xs font-medium">
          <%= cond do %>
            <% entries_count == 0 and @completed_uploads != [] -> %>
              <span class="text-emerald-600 dark:text-emerald-400">✓ Ready to post</span>
            <% all_ready?(@uploads.photos.entries, @upload_stages) and entries_count > 0 -> %>
              <span class="text-emerald-600 dark:text-emerald-400">✓ Ready to post</span>
            <% any_error?(@uploads.photos.entries, @upload_stages) -> %>
              <span class="text-red-500">
                {get_first_error_reason(@uploads.photos.entries, @upload_stages)}
              </span>
            <% entries_count > 0 -> %>
              <span class="text-amber-600 dark:text-amber-400">Processing...</span>
            <% true -> %>
              <span class="text-emerald-600 dark:text-emerald-400">✓ Ready to post</span>
          <% end %>
        </div>
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
        <%!-- Show completed uploads first --%>
        <%= for upload <- @completed_uploads do %>
          <div class="relative group overflow-hidden rounded-lg border border-emerald-200/60 dark:border-emerald-700/60 bg-white dark:bg-slate-800">
            <%= if upload[:preview_data_url] do %>
              <img
                src={upload.preview_data_url}
                alt={"Completed upload preview #{upload.ref}"}
                class="w-full h-24 object-cover transition-all duration-200 group-hover:scale-105"
              />
            <% else %>
              <div class="w-full h-24 bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center">
                <.phx_icon name="hero-photo" class="h-8 w-8 text-emerald-500 dark:text-emerald-400" />
              </div>
            <% end %>

            <div class="absolute top-1 left-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg">
              <.phx_icon name="hero-check" class="h-3 w-3 text-white" />
            </div>

            <button
              type="button"
              id={"remove-completed-photo-#{upload.ref}"}
              phx-click="remove_completed_upload"
              phx-value-ref={upload.ref}
              aria-label="Remove photo"
              class="absolute top-1 right-1 z-10 w-6 h-6 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-all duration-200 hover:scale-110"
              phx-hook="TippyHook"
              data-tippy-content="Remove photo"
            >
              <.phx_icon name="hero-x-mark" class="h-3 w-3" />
            </button>

            <div class="absolute bottom-0 left-0 right-0 bg-black/50 px-2 py-1 text-xs text-white truncate">
              {upload.client_name}
            </div>
          </div>
        <% end %>

        <%!-- Show in-progress entries (excluding completed ones) --%>
        <% completed_refs = Enum.map(@completed_uploads, & &1.ref) %>
        <%= for entry <- @uploads.photos.entries, entry.ref not in completed_refs do %>
          <% stage_info = Map.get(@upload_stages, entry.ref, {:receiving, 0}) %>
          <div class="relative group overflow-hidden rounded-lg border border-emerald-200/60 dark:border-emerald-700/60 bg-white dark:bg-slate-800">
            <.live_img_preview
              entry={entry}
              alt={"Photo upload preview #{entry.ref}"}
              class="w-full h-24 object-cover transition-all duration-200 group-hover:scale-105"
            />

            <%= cond do %>
              <% is_entry_error?(stage_info) -> %>
                <div class="absolute inset-0 bg-red-500/90 flex items-center justify-center p-2">
                  <div class="text-center">
                    <.phx_icon
                      name="hero-exclamation-triangle"
                      class="h-5 w-5 text-white mx-auto mb-1"
                    />
                    <div class="text-xs text-white font-medium">
                      {format_error(stage_info)}
                    </div>
                  </div>
                </div>
              <% is_entry_ready?(stage_info) -> %>
                <div class="absolute top-1 left-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg">
                  <.phx_icon name="hero-check" class="h-3 w-3 text-white" />
                </div>
              <% true -> %>
                <div class="absolute inset-0 bg-gradient-to-t from-black/70 to-black/20 flex flex-col items-center justify-center">
                  <div class="text-center">
                    <div class="w-6 h-6 border-2 border-white border-t-transparent rounded-full animate-spin mb-2 mx-auto">
                    </div>
                    <div class="text-xs text-white font-medium mb-1">
                      {stage_label(stage_info)}
                    </div>
                    <div class="w-16 h-1 bg-white/30 rounded-full overflow-hidden mx-auto">
                      <div
                        class="h-full bg-emerald-400 transition-all duration-300"
                        style={"width: #{stage_progress(stage_info)}%"}
                      >
                      </div>
                    </div>
                  </div>
                </div>
            <% end %>

            <button
              type="button"
              id={"remove-photo-#{entry.ref}"}
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              aria-label="Remove photo"
              class="absolute top-1 right-1 z-10 w-6 h-6 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-all duration-200 hover:scale-110"
              phx-hook="TippyHook"
              data-tippy-content="Remove photo"
            >
              <.phx_icon name="hero-x-mark" class="h-3 w-3" />
            </button>

            <div
              :if={upload_errors(@uploads.photos, entry) != []}
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

      <div
        :if={upload_errors(@uploads.photos) != []}
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

  defp all_ready?(entries, upload_stages) do
    Enum.all?(entries, fn entry ->
      case Map.get(upload_stages, entry.ref) do
        {:ready, _} -> true
        _ -> false
      end
    end)
  end

  defp any_error?(entries, upload_stages) do
    Enum.any?(entries, fn entry ->
      case Map.get(upload_stages, entry.ref) do
        {:error, _} -> true
        _ -> false
      end
    end)
  end

  defp is_entry_ready?({:ready, _}), do: true
  defp is_entry_ready?(_), do: false

  defp is_entry_error?({:error, _}), do: true
  defp is_entry_error?(_), do: false

  defp get_first_error_reason(entries, upload_stages) do
    Enum.find_value(entries, "Error processing", fn entry ->
      case Map.get(upload_stages, entry.ref) do
        {:error, {:nsfw, details}} when is_map(details) ->
          categories = Map.get(details, :flagged_categories, [])

          if categories != [],
            do: "Content flagged: #{Enum.join(categories, ", ")}",
            else: "Content not allowed"

        {:error, {:nsfw, reason}} ->
          "#{reason}"

        {:error, reason} when is_binary(reason) ->
          reason

        {:error, _} ->
          "Upload failed"

        _ ->
          nil
      end
    end)
  end

  defp format_error({:error, {:nsfw, _}}), do: "Content not allowed"
  defp format_error({:error, reason}) when is_binary(reason), do: reason
  defp format_error({:error, _}), do: "Upload failed"
  defp format_error(_), do: ""

  defp stage_label({:receiving, _}), do: "Receiving..."
  defp stage_label({:validating, _}), do: "Checking..."
  defp stage_label({:processing, _}), do: "Processing..."
  defp stage_label({:uploading, _}), do: "Uploading..."
  defp stage_label(_), do: "Processing..."

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
              id={"avatar-upload-preview-#{@user.id}"}
            />
            <button
              :if={@current_avatar_src && @on_delete}
              type="button"
              id="delete-avatar-button"
              phx-click={@on_delete}
              phx-value-url={@url}
              data-confirm="Are you sure you want to remove your avatar?"
              class="absolute -top-1 -right-1 w-7 h-7 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-lg transition-all duration-200 hover:scale-110"
              phx-hook="TippyHook"
              data-tippy-content="Remove avatar"
              aria-label="Remove avatar"
            >
              <.phx_icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </div>

          <%= if Enum.any?(@upload.entries) do %>
            <div class="flex items-center gap-3 shrink-0">
              <.phx_icon
                name="hero-arrow-right"
                class="h-5 w-5 text-slate-400 dark:text-slate-500 shrink-0"
              />
              <%= for entry <- @upload.entries do %>
                <div class="relative shrink-0">
                  <div class={[
                    "w-20 h-20 rounded-xl overflow-hidden",
                    "border-2 transition-all duration-300",
                    avatar_upload_border_class(@upload_stage)
                  ]}>
                    <.live_img_preview
                      entry={entry}
                      class="w-full h-full object-cover"
                      alt="Avatar preview"
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
              <span>{humanize_upload_error(err)}</span>
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

  @doc """
  Liquid banner upload component with detailed progress feedback.
  Shows processing stages and helpful dimension tips for optimal banner display.
  """
  attr :upload, :map, required: true
  attr :upload_stage, :any, default: nil
  attr :current_banner_src, :string, default: nil
  attr :banner_loading, :any, default: nil
  attr :user, :map, required: true
  attr :encryption_key, :string, required: true
  attr :url, :string, default: nil
  attr :on_delete, :string, default: nil
  attr :class, :any, default: nil

  def liquid_banner_upload(assigns) do
    ~H"""
    <div class={["space-y-4", @class]}>
      <div class="space-y-3">
        <div class="flex items-start gap-3 p-3 rounded-xl bg-purple-50/60 dark:bg-purple-900/20 border border-purple-200/60 dark:border-purple-700/40">
          <.phx_icon
            name="hero-light-bulb"
            class="h-5 w-5 text-purple-600 dark:text-purple-400 mt-0.5 shrink-0"
          />
          <div class="space-y-1">
            <p class="text-sm font-medium text-purple-800 dark:text-purple-200">
              Banner Image Tips
            </p>
            <ul class="text-xs text-purple-700/90 dark:text-purple-300/90 space-y-0.5">
              <li>
                • Recommended size: <span class="font-medium">1500×500 pixels</span> (3:1 ratio)
              </li>
              <li>• Minimum width: <span class="font-medium">1200px</span> for best quality</li>
              <li>• File types: JPEG, PNG, WebP, HEIC</li>
              <li>• Max file size: 10MB</li>
            </ul>
          </div>
        </div>

        <div
          phx-drop-target={@upload.ref}
          class="relative rounded-xl overflow-hidden border-2 border-dashed border-slate-300 dark:border-slate-600 transition-all duration-200 hover:border-purple-400 dark:hover:border-purple-500 phx-drop-target:border-purple-500 phx-drop-target:bg-purple-50 dark:phx-drop-target:bg-purple-900/20"
        >
          <%= cond do %>
            <% @banner_loading -> %>
              <div class="aspect-[3/1] flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700">
                <div class="text-center">
                  <div class="w-10 h-10 border-3 border-purple-400 border-t-transparent rounded-full animate-spin mx-auto mb-2">
                  </div>
                  <p class="text-sm text-slate-500 dark:text-slate-400">Loading banner...</p>
                </div>
              </div>
            <% @current_banner_src -> %>
              <div class="relative aspect-[3/1] bg-slate-100 dark:bg-slate-800">
                <img
                  src={@current_banner_src}
                  class="w-full h-full object-cover"
                  alt="Current banner"
                />
                <div class="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent"></div>
                <button
                  :if={@on_delete}
                  type="button"
                  id="delete-banner-button"
                  phx-click={@on_delete}
                  phx-value-url={@url}
                  data-confirm="Are you sure you want to remove your custom banner?"
                  class="absolute top-3 right-3 w-8 h-8 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-lg transition-all duration-200 hover:scale-110"
                  phx-hook="TippyHook"
                  data-tippy-content="Remove banner"
                  aria-label="Remove banner"
                >
                  <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                </button>
              </div>
            <% true -> %>
              <div class="aspect-[3/1] flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700">
                <div class="text-center">
                  <.phx_icon
                    name="hero-photo"
                    class="h-10 w-10 text-slate-400 dark:text-slate-500 mx-auto mb-2"
                  />
                  <p class="text-sm text-slate-500 dark:text-slate-400">No custom banner uploaded</p>
                </div>
              </div>
          <% end %>
        </div>

        <%= if Enum.any?(@upload.entries) do %>
          <div class="space-y-3">
            <p class="text-sm font-medium text-slate-700 dark:text-slate-300">Preview</p>
            <%= for entry <- @upload.entries do %>
              <div class="relative rounded-xl overflow-hidden border-2 border-purple-400 dark:border-purple-500">
                <div class="relative aspect-[3/1]">
                  <.live_img_preview
                    entry={entry}
                    class="w-full h-full object-cover"
                    alt="Banner preview"
                  />
                  <div
                    :if={is_processing?(@upload_stage)}
                    class="absolute inset-0 bg-black/50 flex items-center justify-center"
                  >
                    <div class="w-8 h-8 border-3 border-white border-t-transparent rounded-full animate-spin">
                    </div>
                  </div>
                  <button
                    :if={!is_processing?(@upload_stage)}
                    type="button"
                    id={"cancel-banner-upload-#{entry.ref}"}
                    phx-click="cancel-banner-upload"
                    phx-value-ref={entry.ref}
                    class="absolute top-3 right-3 w-8 h-8 bg-slate-700/80 hover:bg-slate-700 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                    phx-hook="TippyHook"
                    data-tippy-content="Cancel"
                    aria-label="Cancel upload"
                  >
                    <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="flex items-center gap-4">
          <label
            for={@upload.ref}
            class={[
              "inline-flex items-center gap-2 px-4 py-2.5 rounded-xl cursor-pointer",
              "bg-purple-100 dark:bg-purple-900/40",
              "border border-purple-200/60 dark:border-purple-700/60",
              "hover:bg-purple-200/80 dark:hover:bg-purple-800/60",
              "transition-all duration-200 ease-out",
              "text-sm font-medium text-purple-700 dark:text-purple-200"
            ]}
          >
            <.phx_icon name="hero-arrow-up-tray" class="h-4 w-4" />
            <span>{if @current_banner_src, do: "Replace banner", else: "Upload banner"}</span>
          </label>
          <.live_file_input upload={@upload} class="hidden" />
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {Enum.join(@upload.acceptable_exts, ", ")}
          </p>
        </div>
      </div>

      <%= if Enum.any?(@upload.entries) || is_processing?(@upload_stage) do %>
        <.liquid_banner_upload_progress
          upload={@upload}
          upload_stage={@upload_stage}
        />
      <% end %>

      <%= for entry <- @upload.entries do %>
        <%= for err <- upload_errors(@upload, entry) do %>
          <div class="p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl">
            <div class="flex items-center gap-2 text-sm text-red-700 dark:text-red-300">
              <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
              <span>{humanize_upload_error(err)}</span>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :upload, :map, required: true
  attr :upload_stage, :any, default: nil

  def liquid_banner_upload_progress(assigns) do
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
      "bg-gradient-to-br from-purple-50/80 to-purple-100/60 dark:from-purple-900/30 dark:to-purple-900/20",
      "border-purple-200/60 dark:border-purple-700/60"
    ]}>
      <div class="flex items-center gap-2 mb-4">
        <.phx_icon
          name="hero-cog-6-tooth"
          class="h-4 w-4 text-purple-600 dark:text-purple-400 animate-spin"
        />
        <span class="text-sm font-medium text-purple-700 dark:text-purple-300">
          Processing your banner
        </span>
      </div>

      <div class="space-y-2">
        <%= for {stage_key, stage_label, stage_icon} <- @stages do %>
          <% status = get_stage_status(@upload_stage, stage_key) %>
          <div class={[
            "flex items-center gap-3 px-3 py-2 rounded-lg transition-all duration-300",
            banner_stage_status_bg_class(status)
          ]}>
            <div class={[
              "w-6 h-6 rounded-full flex items-center justify-center transition-all duration-300",
              banner_stage_status_icon_class(status)
            ]}>
              <%= case status do %>
                <% :completed -> %>
                  <.phx_icon name="hero-check" class="h-3.5 w-3.5 text-white" />
                <% :active -> %>
                  <div class="w-3 h-3 border-2 border-purple-600 border-t-transparent rounded-full animate-spin">
                  </div>
                <% :pending -> %>
                  <.phx_icon name={stage_icon} class="h-3.5 w-3.5 text-slate-400 dark:text-slate-500" />
                <% :error -> %>
                  <.phx_icon name="hero-x-mark" class="h-3.5 w-3.5 text-white" />
              <% end %>
            </div>

            <span class={[
              "text-sm font-medium transition-all duration-300",
              banner_stage_status_text_class(status)
            ]}>
              {stage_label}
            </span>

            <%= if status == :active do %>
              <div class="ml-auto flex items-center gap-2">
                <div class="w-16 h-1.5 bg-purple-200 dark:bg-purple-800 rounded-full overflow-hidden">
                  <div class="h-full bg-purple-500 rounded-full animate-pulse w-2/3"></div>
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

  defp banner_stage_status_bg_class(:completed), do: "bg-purple-50/80 dark:bg-purple-900/20"
  defp banner_stage_status_bg_class(:active), do: "bg-purple-100/80 dark:bg-purple-900/30"
  defp banner_stage_status_bg_class(:error), do: "bg-red-50/80 dark:bg-red-900/20"
  defp banner_stage_status_bg_class(:pending), do: "bg-transparent"

  defp banner_stage_status_icon_class(:completed), do: "bg-purple-500"
  defp banner_stage_status_icon_class(:active), do: "bg-purple-100 dark:bg-purple-900/50"
  defp banner_stage_status_icon_class(:error), do: "bg-red-500"
  defp banner_stage_status_icon_class(:pending), do: "bg-slate-100 dark:bg-slate-700"

  defp banner_stage_status_text_class(:completed), do: "text-purple-700 dark:text-purple-300"
  defp banner_stage_status_text_class(:active), do: "text-purple-700 dark:text-purple-300"
  defp banner_stage_status_text_class(:error), do: "text-red-700 dark:text-red-300"
  defp banner_stage_status_text_class(:pending), do: "text-slate-500 dark:text-slate-400"

  defp avatar_upload_border_class(nil), do: "border-slate-200 dark:border-slate-600"
  defp avatar_upload_border_class({:error, _}), do: "border-red-400 dark:border-red-500"
  defp avatar_upload_border_class({:ready, _}), do: "border-emerald-400 dark:border-emerald-500"

  defp avatar_upload_border_class(_),
    do: "border-emerald-400/50 dark:border-emerald-500/50 animate-pulse"

  @doc """
  Journal book cover upload component with compact design.
  Shows a square preview area and upload progress for book covers.
  """
  attr :upload, :map, required: true
  attr :upload_stage, :any, default: nil
  attr :current_cover_src, :string, default: nil
  attr :cover_loading, :boolean, default: false
  attr :on_delete, :string, default: nil
  attr :class, :any, default: nil

  def liquid_journal_cover_upload(assigns) do
    ~H"""
    <div id="cover-upload-container" class={["space-y-3", @class]}>
      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
        Cover Image (optional)
      </label>

      <div
        phx-drop-target={@upload.ref}
        class={[
          "relative rounded-xl overflow-hidden border-2 border-dashed transition-all duration-200 text-center",
          if(is_upload_complete?(@upload_stage),
            do: "border-emerald-400 dark:border-emerald-500",
            else:
              "border-slate-300 dark:border-slate-600 hover:border-emerald-400 dark:hover:border-emerald-500 phx-drop-target:border-emerald-500 phx-drop-target:bg-emerald-50 dark:phx-drop-target:bg-emerald-900/20"
          )
        ]}
      >
        <%= cond do %>
          <% @cover_loading -> %>
            <div class="aspect-[4/3] max-h-48 flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700">
              <div class="text-center">
                <div class="w-8 h-8 border-3 border-emerald-400 border-t-transparent rounded-full animate-spin mx-auto mb-2">
                </div>
                <p class="text-xs text-slate-500 dark:text-slate-400">Loading cover...</p>
              </div>
            </div>
          <% Enum.any?(@upload.entries) -> %>
            <% entry = List.first(@upload.entries) %>
            <div class="relative w-full aspect-[4/3] max-h-48 bg-slate-100 dark:bg-slate-800">
              <.live_img_preview
                entry={entry}
                class="w-full h-full object-cover"
                alt="Cover preview"
              />
              <div
                :if={entry.progress < 100}
                class="absolute inset-0 bg-black/60 flex flex-col items-center justify-center gap-2"
              >
                <div class="w-8 h-8 border-3 border-emerald-400 border-t-transparent rounded-full animate-spin">
                </div>
                <span class="text-xs text-white font-medium">
                  Uploading {entry.progress}%
                </span>
              </div>
              <div
                :if={entry.progress == 100 && is_processing?(@upload_stage)}
                class="absolute inset-0 bg-black/60 flex flex-col items-center justify-center gap-2"
              >
                <div class="w-8 h-8 border-3 border-emerald-400 border-t-transparent rounded-full animate-spin">
                </div>
                <span class="text-xs text-white font-medium">
                  {cover_stage_label(@upload_stage)}
                </span>
              </div>
              <div
                :if={is_upload_complete?(@upload_stage)}
                class="absolute bottom-2 left-2 flex items-center gap-1.5 px-2 py-1 bg-emerald-500 text-white text-xs font-medium rounded-full shadow-md"
              >
                <.phx_icon name="hero-check" class="h-3.5 w-3.5" />
                <span>Uploaded</span>
              </div>
              <button
                :if={is_upload_complete?(@upload_stage)}
                type="button"
                phx-click="remove_cover"
                class="absolute top-2 right-2 w-7 h-7 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                aria-label="Remove cover"
              >
                <.phx_icon name="hero-trash" class="h-4 w-4" />
              </button>
              <button
                :if={
                  !is_processing?(@upload_stage) && !is_upload_complete?(@upload_stage) &&
                    entry.progress == 100
                }
                type="button"
                phx-click="cancel_cover_upload"
                phx-value-ref={entry.ref}
                class="absolute top-2 right-2 w-7 h-7 bg-slate-700/80 hover:bg-slate-700 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                aria-label="Cancel upload"
              >
                <.phx_icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>
          <% @current_cover_src -> %>
            <div class="relative w-full aspect-[4/3] max-h-48 bg-slate-100 dark:bg-slate-800">
              <img
                src={@current_cover_src}
                class="w-full h-full object-cover"
                alt="Current cover"
              />
              <button
                :if={@on_delete}
                type="button"
                phx-click={@on_delete}
                data-confirm="Are you sure you want to remove this cover image?"
                class="absolute top-2 right-2 w-7 h-7 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                aria-label="Remove cover"
              >
                <.phx_icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>
          <% true -> %>
            <label
              for={@upload.ref}
              class="w-full aspect-[4/3] max-h-48 flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700 cursor-pointer"
            >
              <div class="text-center px-4">
                <.phx_icon
                  name="hero-photo"
                  class="h-8 w-8 text-slate-400 dark:text-slate-500 mx-auto mb-2"
                />
                <p class="text-sm text-emerald-600 dark:text-emerald-400 font-medium">
                  Upload cover
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                  or drag and drop
                </p>
              </div>
            </label>
        <% end %>
      </div>

      <.live_file_input upload={@upload} class="hidden" />

      <%= if is_upload_error?(@upload_stage) do %>
        <div class="p-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
          <div class="flex items-center gap-2 text-xs text-red-700 dark:text-red-300">
            <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
            <span>{get_upload_error_message(@upload_stage)}</span>
          </div>
        </div>
      <% end %>

      <%= for entry <- @upload.entries do %>
        <%= for err <- upload_errors(@upload, entry) do %>
          <div class="p-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
            <div class="flex items-center gap-2 text-xs text-red-700 dark:text-red-300">
              <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
              <span>{humanize_upload_error(err)}</span>
            </div>
          </div>
        <% end %>
      <% end %>

      <p class="text-xs text-slate-500 dark:text-slate-400">
        JPEG, PNG, WebP, or HEIC • Max 5MB
      </p>
    </div>
    """
  end

  defp cover_stage_label({:receiving, _}), do: "Uploading..."
  defp cover_stage_label({:checking, _}), do: "Checking..."
  defp cover_stage_label({:processing, _}), do: "Processing..."
  defp cover_stage_label({:encrypting, _}), do: "Encrypting..."
  defp cover_stage_label({:uploading, _}), do: "Saving..."
  defp cover_stage_label({:ready, _}), do: "Done!"
  defp cover_stage_label(_), do: "Processing..."

  defp is_processing?(nil), do: false
  defp is_processing?({:ready, _}), do: false
  defp is_processing?({:error, _}), do: false
  defp is_processing?(_), do: true

  defp is_upload_complete?({:ready, _}), do: true
  defp is_upload_complete?(_), do: false

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

  defp stage_progress({_stage, progress}) when is_integer(progress), do: progress
  defp stage_progress(_), do: 0

  defp privacy_icon("public"), do: "hero-globe-alt"
  defp privacy_icon("connections"), do: "hero-user-group"
  defp privacy_icon("private"), do: "hero-lock-closed"
  defp privacy_icon("specific_groups"), do: "hero-squares-2x2"
  defp privacy_icon("specific_users"), do: "hero-user-plus"
  defp privacy_icon(_), do: "hero-lock-closed"

  defp privacy_label("public"), do: "Public"
  defp privacy_label("connections"), do: "Connections"
  defp privacy_label("private"), do: "Private"
  defp privacy_label("specific_groups"), do: "Groups"
  defp privacy_label("specific_users"), do: "Specific"
  defp privacy_label(_), do: "Private"

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
  attr :user_status, :string, default: nil
  attr :user_status_message, :string, default: nil
  attr :timestamp, :string, required: true
  attr :content, :string, required: true
  attr :images, :list, default: []
  attr :stats, :map, default: %{}
  attr :verified, :boolean, default: false
  attr :current_user_id, :string, required: true
  attr :liked, :boolean, default: false
  attr :bookmarked, :boolean, default: false
  attr :can_repost, :boolean, default: false
  attr :can_reply?, :boolean, default: false
  attr :can_bookmark?, :boolean, default: false
  attr :post, :map, required: true

  attr :post_shared_users, :list,
    default: [],
    doc: "the list of Post.SharedUser structs mapped from the current_user's user_connections"

  attr :removing_shared_user_id, :string,
    default: nil,
    doc: "the user_id of the shared user currently being removed"

  attr :adding_shared_user, :map,
    default: nil,
    doc: "map with post_id and username of user being added"

  attr :post_id, :string, default: nil
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :is_repost, :boolean, default: false
  attr :share_note, :any, default: nil, doc: "Personal note from the sender when sharing"
  # New: unread state
  attr :unread?, :boolean, default: false
  attr :unread_replies_count, :integer, default: 0
  attr :unread_nested_replies_by_parent, :map, default: %{}
  attr :calm_notifications, :boolean, default: false
  attr :class, :any, default: ""
  # Content warning
  attr :content_warning?, :boolean, default: false

  attr :content_warning, :any,
    default: nil,
    doc: "type :string but we default to nil so we use :any type"

  attr :content_warning_category, :any,
    default: nil,
    doc: "type :string but we default to nil so we use :any type"

  attr :decrypted_url_preview, :any,
    default: nil,
    doc: "type :map but we default to nil so we use :any type"

  # Report modal state
  attr :show_report_modal?, :boolean, default: false

  attr :show_post_author_status, :boolean,
    default: true,
    doc: "Whether to show the status indicator (based on privacy settings)"

  attr :author_profile_slug, :string,
    default: nil,
    doc: "The profile slug of the post author (for linking to their profile)"

  attr :author_profile_visibility, :atom,
    default: nil,
    doc: "The profile visibility of the post author (:private, :connections, :public)"

  def liquid_timeline_post(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <article
      id={"timeline-card-#{@post.id}"}
      phx-hook="TouchHoverHook"
      class={
        [
          "group relative rounded-2xl transition-all duration-300 ease-out",
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
        "group-hover:opacity-100 touch-hover:opacity-100",
        "bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10"
      ]}>
      </div>

      <%!-- Subtle left-side shared indicator for posts shared WITH you --%>
      <button
        :if={@is_repost && @current_user_id != @post.user_id}
        type="button"
        phx-click={
          JS.show(
            to: "#share-overlay-#{@post.id}",
            transition:
              {"ease-out duration-200", "opacity-0 -translate-x-4", "opacity-100 translate-x-0"}
          )
        }
        class="absolute left-0 top-4 bottom-4 w-1 bg-gradient-to-b from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500 rounded-r-full opacity-70 hover:opacity-100 hover:w-1.5 transition-all duration-200 cursor-pointer group z-10"
        aria-label="View shared message"
      >
        <span class="absolute left-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 touch-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium text-emerald-600 dark:text-emerald-400 bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border border-emerald-200/50 dark:border-emerald-700/50">
          Shared with you
        </span>
      </button>

      <%!-- Subtle left-side indicator for posts YOU shared with others (reposts only) --%>
      <button
        :if={@is_repost && @current_user_id == @post.user_id && !Enum.empty?(@post.shared_users)}
        type="button"
        phx-click={
          JS.show(
            to: "#shared-by-you-overlay-#{@post.id}",
            transition:
              {"ease-out duration-200", "opacity-0 -translate-x-4", "opacity-100 translate-x-0"}
          )
        }
        class="absolute left-0 top-4 bottom-4 w-1 bg-gradient-to-b from-sky-400 via-blue-400 to-sky-400 dark:from-sky-500 dark:via-blue-500 dark:to-sky-500 rounded-r-full opacity-70 hover:opacity-100 hover:w-1.5 transition-all duration-200 cursor-pointer group z-10"
        aria-label="View who you shared with"
      >
        <span class="absolute left-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 touch-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium text-sky-600 dark:text-sky-400 bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border border-sky-200/50 dark:border-sky-700/50">
          You shared this
        </span>
      </button>

      <%!-- Right-side visibility indicator for post owner (non-public posts) --%>
      <button
        :if={@current_user_id == @post.user_id && @post.visibility != :public}
        type="button"
        phx-click={
          JS.show(
            to: "#visibility-overlay-#{@post.id}",
            transition:
              {"ease-out duration-200", "opacity-0 translate-x-4", "opacity-100 translate-x-0"}
          )
        }
        class={"absolute right-0 top-4 bottom-4 w-1 bg-gradient-to-b #{visibility_indicator_gradient(@post.visibility)} rounded-l-full opacity-70 hover:opacity-100 hover:w-1.5 transition-all duration-200 cursor-pointer group z-10"}
        aria-label="View visibility settings"
        id={"visibility-indicator-#{@post.id}"}
      >
        <span class={"absolute right-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 touch-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium px-2 py-1 rounded-md shadow-sm border #{visibility_indicator_hover_text_classes(@post.visibility)}"}>
          {visibility_badge_text(@post.visibility)}
        </span>
      </button>

      <%!-- Right-side visibility indicator for non-owner or public posts (non-interactive) --%>
      <div
        :if={@current_user_id != @post.user_id || @post.visibility == :public}
        class={"absolute right-0 top-4 bottom-4 w-1 bg-gradient-to-b #{visibility_indicator_gradient(@post.visibility)} rounded-l-full opacity-50 group z-10"}
        aria-label={visibility_badge_text(@post.visibility)}
      >
        <span class={"absolute right-3 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 touch-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium px-2 py-1 rounded-md shadow-sm border #{visibility_indicator_hover_text_classes(@post.visibility)}"}>
          {visibility_badge_text(@post.visibility)}
        </span>
      </div>

      <%!-- Share note overlay modal for posts shared WITH you --%>
      <div
        :if={@is_repost && @current_user_id != @post.user_id}
        id={"share-overlay-#{@post.id}"}
        class="hidden absolute inset-0 z-20 bg-white/98 dark:bg-slate-800/98 backdrop-blur-sm rounded-2xl overflow-hidden"
        phx-window-keydown={
          JS.hide(
            to: "#share-overlay-#{@post.id}",
            transition:
              {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
          )
        }
        phx-key="Escape"
      >
        <div class="absolute left-0 top-0 bottom-0 w-1.5 bg-gradient-to-b from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500 rounded-r-full shadow-[0_0_8px_rgba(52,211,153,0.4)] dark:shadow-[0_0_8px_rgba(52,211,153,0.3)]">
        </div>
        <div class="h-full flex flex-col p-4 pl-5 overflow-hidden">
          <div class="flex items-center gap-3 mb-3 shrink-0">
            <div class="flex items-center justify-center w-9 h-9 rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/50 dark:to-teal-900/50 shadow-sm">
              <.phx_icon
                name="hero-paper-airplane-solid"
                class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
              />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                Shared by {@user_name}
              </p>
            </div>
            <button
              type="button"
              phx-click={
                JS.hide(
                  to: "#share-overlay-#{@post.id}",
                  transition:
                    {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
                )
              }
              class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors duration-200"
              aria-label="Close"
            >
              <.phx_icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </div>
          <%= if @share_note do %>
            <div class="flex-1 min-h-0 overflow-y-auto">
              <p class="text-sm text-slate-700 dark:text-slate-300 leading-relaxed break-words whitespace-pre-wrap">
                {@share_note}
              </p>
            </div>
          <% else %>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              No message included
            </p>
          <% end %>
          <button
            type="button"
            phx-click={
              JS.hide(
                to: "#share-overlay-#{@post.id}",
                transition:
                  {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
              )
            }
            class="mt-3 inline-flex items-center gap-1.5 self-start text-xs font-medium text-emerald-600 dark:text-emerald-400 bg-emerald-50/80 dark:bg-emerald-900/30 hover:bg-emerald-100 dark:hover:bg-emerald-900/50 px-3 py-1.5 rounded-lg border border-emerald-200/50 dark:border-emerald-700/50 transition-colors duration-200 shrink-0"
          >
            <.phx_icon name="hero-arrow-left-mini" class="h-3.5 w-3.5" /> Back to post
          </button>
        </div>
      </div>

      <%!-- Overlay modal for posts YOU shared with others --%>
      <div
        :if={@current_user_id == @post.user_id && !Enum.empty?(@post.shared_users)}
        id={"shared-by-you-overlay-#{@post.id}"}
        class="hidden absolute inset-0 z-20 bg-white/98 dark:bg-slate-800/98 backdrop-blur-sm rounded-2xl overflow-hidden"
        phx-window-keydown={
          JS.hide(
            to: "#shared-by-you-overlay-#{@post.id}",
            transition:
              {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
          )
        }
        phx-key="Escape"
      >
        <div class="absolute left-0 top-0 bottom-0 w-1.5 bg-gradient-to-b from-sky-400 via-blue-400 to-sky-400 dark:from-sky-500 dark:via-blue-500 dark:to-sky-500 rounded-r-full shadow-[0_0_8px_rgba(56,189,248,0.4)] dark:shadow-[0_0_8px_rgba(56,189,248,0.3)]">
        </div>
        <div class="h-full flex flex-col p-4 pl-5 overflow-hidden">
          <div class="flex items-center gap-3 mb-3 shrink-0">
            <div class="flex items-center justify-center w-9 h-9 rounded-full bg-gradient-to-br from-sky-100 to-blue-100 dark:from-sky-900/50 dark:to-blue-900/50 shadow-sm">
              <.phx_icon
                name="hero-share-solid"
                class="h-4 w-4 text-sky-600 dark:text-sky-400"
              />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                You shared this
              </p>
            </div>
            <button
              type="button"
              phx-click={
                JS.hide(
                  to: "#shared-by-you-overlay-#{@post.id}",
                  transition:
                    {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
                )
              }
              class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors duration-200"
              aria-label="Close"
            >
              <.phx_icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </div>
          <p class="text-xs text-slate-500 dark:text-slate-400 mb-3 shrink-0">
            Shared with {length(@post.shared_users)} {if length(@post.shared_users) == 1,
              do: "person",
              else: "people"}
          </p>
          <div class="flex-1 min-h-0 overflow-y-auto space-y-1.5">
            <%= for shared_user <- @post.shared_users do %>
              <% shared_post_user = get_shared_connection(shared_user.user_id, @post_shared_users) %>
              <div class="flex items-center gap-3 p-2 bg-slate-50/80 dark:bg-slate-700/50 rounded-lg">
                <%= if shared_post_user do %>
                  <div class={[
                    "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg",
                    "bg-gradient-to-br transition-all duration-200",
                    get_post_shared_user_classes(shared_post_user.color)
                  ]}>
                    <span class={[
                      "text-sm font-semibold",
                      get_post_shared_user_text_classes(shared_post_user.color)
                    ]}>
                      {String.first(shared_post_user.username || "?") |> String.upcase()}
                    </span>
                  </div>
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                    {shared_post_user.username}
                  </span>
                <% else %>
                  <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-slate-200 dark:bg-slate-700">
                    <.phx_icon
                      name="hero-user-minus"
                      class="w-4 h-4 text-slate-400 dark:text-slate-500"
                    />
                  </div>
                  <span class="text-sm font-medium text-slate-500 dark:text-slate-400 truncate italic">
                    Former connection
                  </span>
                <% end %>
              </div>
            <% end %>
          </div>
          <button
            type="button"
            phx-click={
              JS.hide(
                to: "#shared-by-you-overlay-#{@post.id}",
                transition:
                  {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 -translate-x-4"}
              )
            }
            class="mt-3 inline-flex items-center gap-1.5 self-start text-xs font-medium text-sky-600 dark:text-sky-400 bg-sky-50/80 dark:bg-sky-900/30 hover:bg-sky-100 dark:hover:bg-sky-900/50 px-3 py-1.5 rounded-lg border border-sky-200/50 dark:border-sky-700/50 transition-colors duration-200 shrink-0"
          >
            <.phx_icon name="hero-arrow-left-mini" class="h-3.5 w-3.5" /> Back to post
          </button>
        </div>
      </div>

      <%!-- Visibility/Shared users overlay for post owner --%>
      <div
        :if={@current_user_id == @post.user_id && @post.visibility != :public}
        id={"visibility-overlay-#{@post.id}"}
        class="hidden absolute inset-0 z-20 bg-white/98 dark:bg-slate-800/98 backdrop-blur-sm rounded-2xl overflow-hidden"
        phx-window-keydown={
          JS.hide(
            to: "#visibility-overlay-#{@post.id}",
            transition:
              {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 translate-x-4"}
          )
        }
        phx-key="Escape"
      >
        <div class={"absolute right-0 top-0 bottom-0 w-1.5 bg-gradient-to-b #{visibility_overlay_gradient(@post.visibility)} rounded-l-full shadow-[0_0_8px_rgba(168,85,247,0.4)] dark:shadow-[0_0_8px_rgba(168,85,247,0.3)]"}>
        </div>
        <div class="h-full flex flex-col p-4 pr-5 overflow-hidden">
          <div class="flex items-center gap-3 mb-3 shrink-0">
            <div class={"flex items-center justify-center w-9 h-9 rounded-full bg-gradient-to-br #{visibility_overlay_icon_bg(@post.visibility)} shadow-sm"}>
              <.phx_icon
                name={visibility_overlay_icon(@post.visibility)}
                class={"h-4 w-4 #{visibility_overlay_icon_color(@post.visibility)}"}
              />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                {visibility_badge_text(@post.visibility)}
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                <%= if @post.visibility == :private do %>
                  Only visible to you
                <% else %>
                  {length(@post.shared_users)} {if length(@post.shared_users) == 1,
                    do: "person",
                    else: "people"}
                <% end %>
              </p>
            </div>
            <button
              type="button"
              phx-click={
                JS.hide(
                  to: "#visibility-overlay-#{@post.id}",
                  transition:
                    {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 translate-x-4"}
                )
              }
              class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors duration-200"
              aria-label="Close"
            >
              <.phx_icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </div>

          <%= if @post.visibility == :private do %>
            <div class="flex-1 flex flex-col items-center justify-center text-center">
              <div class="inline-flex items-center justify-center w-12 h-12 mb-3 rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600">
                <.phx_icon name="hero-lock-closed" class="w-6 h-6 text-slate-500 dark:text-slate-400" />
              </div>
              <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Private post
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400 max-w-[200px]">
                This post is only visible to you.
              </p>
            </div>
            <div class="pt-3 mt-3 border-t border-slate-200/60 dark:border-slate-700/60 shrink-0 flex justify-end">
              <button
                type="button"
                phx-click={
                  JS.hide(
                    to: "#visibility-overlay-#{@post.id}",
                    transition:
                      {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 translate-x-4"}
                  )
                }
                class={"inline-flex items-center gap-1.5 text-xs font-medium #{visibility_overlay_back_button_classes(@post.visibility)} px-3 py-1.5 rounded-lg border transition-colors duration-200"}
              >
                Back to post <.phx_icon name="hero-arrow-right-mini" class="h-3.5 w-3.5" />
              </button>
            </div>
          <% else %>
            <div class="flex-1 min-h-0 overflow-y-auto">
              <div class="grid grid-cols-2 gap-1.5">
                <%= for shared_user <- @post.shared_users do %>
                  <% shared_post_user = get_shared_connection(shared_user.user_id, @post_shared_users) %>
                  <% shared_user_id_str =
                    if is_binary(shared_user.user_id),
                      do: Ecto.UUID.cast!(shared_user.user_id),
                      else: shared_user.user_id %>
                  <% is_removing = @removing_shared_user_id == shared_user_id_str %>
                  <div class={[
                    "relative flex items-center gap-2 p-1.5 bg-slate-50/80 dark:bg-slate-700/50 rounded-lg transition-all duration-200",
                    is_removing && "opacity-50 pointer-events-none"
                  ]}>
                    <%= if shared_post_user do %>
                      <.link
                        :if={show_profile?(shared_post_user)}
                        id={"profile-link-#{@post.id}-person-#{shared_user.user_id}"}
                        phx-hook="TippyHook"
                        data-tippy-content="View profile"
                        navigate={~p"/app/profile/#{shared_post_user.profile_slug}"}
                        class="flex items-center gap-2 flex-1 min-w-0"
                      >
                        <div class={[
                          "flex h-6 w-6 shrink-0 items-center justify-center rounded",
                          "bg-gradient-to-br transition-all duration-200",
                          get_post_shared_user_classes(shared_post_user.color)
                        ]}>
                          <span class={[
                            "text-xs font-semibold",
                            get_post_shared_user_text_classes(shared_post_user.color)
                          ]}>
                            {String.first(shared_post_user.username || "?") |> String.upcase()}
                          </span>
                        </div>
                        <span class="text-xs font-medium text-slate-900 dark:text-slate-100 truncate">
                          {shared_post_user.username}
                        </span>
                      </.link>
                      <div
                        :if={!show_profile?(shared_post_user)}
                        class="flex items-center gap-2 flex-1 min-w-0"
                      >
                        <div class={[
                          "flex h-6 w-6 shrink-0 items-center justify-center rounded",
                          "bg-gradient-to-br transition-all duration-200",
                          get_post_shared_user_classes(shared_post_user.color)
                        ]}>
                          <span class={[
                            "text-xs font-semibold",
                            get_post_shared_user_text_classes(shared_post_user.color)
                          ]}>
                            {String.first(shared_post_user.username || "?") |> String.upcase()}
                          </span>
                        </div>
                        <span class="text-xs font-medium text-slate-900 dark:text-slate-100 truncate">
                          {shared_post_user.username}
                        </span>
                      </div>
                      <button
                        type="button"
                        phx-click="remove_shared_user"
                        phx-value-post-id={@post.id}
                        phx-value-user-id={shared_user.user_id}
                        phx-value-shared-username={shared_post_user.username}
                        class="p-0.5 rounded text-slate-400 dark:text-slate-500 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 shrink-0"
                        phx-hook="TippyHook"
                        data-tippy-content="Remove access"
                        id={"remove-access-#{@post.id}-person-#{shared_user.user_id}"}
                      >
                        <span class="sr-only">Remove access for {shared_post_user.username}</span>
                        <%= if is_removing do %>
                          <.phx_icon name="hero-arrow-path-mini" class="w-3.5 h-3.5 animate-spin" />
                        <% else %>
                          <.phx_icon name="hero-trash-mini" class="w-3.5 h-3.5" />
                        <% end %>
                      </button>
                    <% else %>
                      <div class="flex items-center gap-2 flex-1 min-w-0">
                        <div class="flex h-6 w-6 shrink-0 items-center justify-center rounded bg-slate-200 dark:bg-slate-700">
                          <.phx_icon
                            name="hero-user-minus"
                            class="w-3 h-3 text-slate-400 dark:text-slate-500"
                          />
                        </div>
                        <span class="text-xs font-medium text-slate-500 dark:text-slate-400 truncate italic">
                          Former
                        </span>
                      </div>
                      <button
                        type="button"
                        phx-click="remove_shared_user"
                        phx-value-post-id={@post.id}
                        phx-value-user-id={shared_user.user_id}
                        phx-value-shared-username=""
                        class="p-0.5 rounded text-slate-400 dark:text-slate-500 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 shrink-0"
                        title="Remove"
                      >
                        <%= if is_removing do %>
                          <.phx_icon name="hero-arrow-path-mini" class="w-3.5 h-3.5 animate-spin" />
                        <% else %>
                          <.phx_icon name="hero-trash-mini" class="w-3.5 h-3.5" />
                        <% end %>
                      </button>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <div :if={Enum.empty?(@post.shared_users)} class="py-2 text-center">
                <div class="inline-flex items-center justify-center w-8 h-8 mb-1.5 rounded-full bg-slate-100 dark:bg-slate-700">
                  <.phx_icon
                    name="hero-user-group"
                    class="w-4 h-4 text-slate-400 dark:text-slate-500"
                  />
                </div>
                <p class="text-xs text-slate-500 dark:text-slate-400">
                  Not shared with anyone yet
                </p>
              </div>
            </div>

            <div class="pt-3 mt-3 border-t border-slate-200/60 dark:border-slate-700/60 shrink-0">
              <% available_connections =
                Enum.reject(@post_shared_users, fn psu ->
                  Enum.any?(@post.shared_users, &(&1.user_id == psu.user_id))
                end) %>

              <%= if @adding_shared_user && @adding_shared_user.post_id == @post.id do %>
                <div class="flex items-center gap-2 p-2 rounded-lg bg-emerald-50 dark:bg-emerald-900/20 animate-pulse">
                  <.phx_icon
                    name="hero-arrow-path"
                    class="w-4 h-4 text-emerald-600 dark:text-emerald-400 animate-spin"
                  />
                  <span class="text-sm text-emerald-700 dark:text-emerald-300">
                    Adding {@adding_shared_user.username}...
                  </span>
                </div>
              <% else %>
                <%= if Enum.empty?(available_connections) do %>
                  <p class="text-xs text-slate-400 dark:text-slate-500 text-center py-1">
                    All connections have access
                  </p>
                <% else %>
                  <div class="relative" id={"add-shared-user-overlay-#{@post.id}"}>
                    <button
                      type="button"
                      phx-click={JS.toggle(to: "#add-shared-user-overlay-list-#{@post.id}")}
                      class={"w-full flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium rounded-lg border border-dashed transition-all duration-200 #{visibility_add_button_classes(@post.visibility)}"}
                    >
                      <.phx_icon name="hero-plus-mini" class="w-4 h-4" /> Add someone
                    </button>

                    <div
                      id={"add-shared-user-overlay-list-#{@post.id}"}
                      phx-click-away={JS.hide(to: "#add-shared-user-overlay-list-#{@post.id}")}
                      phx-key="escape"
                      phx-window-keydown={JS.hide(to: "#add-shared-user-overlay-list-#{@post.id}")}
                      class="hidden absolute bottom-full left-0 right-0 mb-2 max-h-48 overflow-y-auto rounded-xl border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 shadow-xl ring-1 ring-black/5 dark:ring-white/10 backdrop-blur-sm animate-in fade-in slide-in-from-bottom-2 duration-150"
                    >
                      <div class="p-1.5 space-y-0.5">
                        <div
                          :for={conn <- available_connections}
                          id={"add-shared-user-item-#{@post.id}-#{conn.user_id}"}
                          phx-click={
                            JS.hide(to: "#add-shared-user-overlay-list-#{@post.id}")
                            |> JS.push("add_shared_user")
                          }
                          phx-value-post-id={@post.id}
                          phx-value-user-id={conn.user_id}
                          phx-value-username={conn.username}
                          class={[
                            "flex items-center gap-3 px-3 py-2.5 cursor-pointer rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700/60 active:bg-slate-200 dark:active:bg-slate-600/60 transition-colors duration-150",
                            @adding_shared_user && @adding_shared_user.post_id == @post.id &&
                              @adding_shared_user.username == conn.username &&
                              "opacity-50 pointer-events-none"
                          ]}
                        >
                          <%= if @adding_shared_user && @adding_shared_user.post_id == @post.id && @adding_shared_user.username == conn.username do %>
                            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-emerald-100 dark:bg-emerald-900/30">
                              <.phx_icon
                                name="hero-arrow-path"
                                class="w-4 h-4 text-emerald-600 dark:text-emerald-400 animate-spin"
                              />
                            </div>
                            <span class="text-sm font-medium text-emerald-600 dark:text-emerald-400">
                              Adding...
                            </span>
                          <% else %>
                            <div class={[
                              "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg shadow-sm",
                              "bg-gradient-to-br",
                              get_post_shared_user_classes(conn.color)
                            ]}>
                              <span class={[
                                "text-xs font-bold",
                                get_post_shared_user_text_classes(conn.color)
                              ]}>
                                {String.first(conn.username || "?") |> String.upcase()}
                              </span>
                            </div>
                            <span class={[
                              "text-sm font-medium truncate",
                              get_post_shared_user_text_classes(conn.color)
                            ]}>
                              {conn.username}
                            </span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
            <button
              type="button"
              phx-click={
                JS.hide(
                  to: "#visibility-overlay-#{@post.id}",
                  transition:
                    {"ease-in duration-150", "opacity-100 translate-x-0", "opacity-0 translate-x-4"}
                )
              }
              class={"mt-3 inline-flex items-center gap-1.5 self-end text-xs font-medium #{visibility_overlay_back_button_classes(@post.visibility)} px-3 py-1.5 rounded-lg border transition-colors duration-200 shrink-0"}
            >
              Back to post <.phx_icon name="hero-arrow-right-mini" class="h-3.5 w-3.5" />
            </button>
          <% end %>
        </div>
      </div>

      <%!-- Content Warning Overlay (covers entire post) --%>
      <div
        :if={(@content_warning? && @content_warning) || @post.mature_content}
        id={"content-warning-#{@post.id}"}
        class={[
          "content-warning-overlay absolute inset-0 z-20 rounded-2xl backdrop-blur-sm transition-all duration-300 ease-out overflow-hidden",
          if(@post.mature_content && !(@content_warning? && @content_warning),
            do: "bg-amber-50/95 dark:bg-slate-800/98",
            else: "bg-teal-50/95 dark:bg-slate-800/98"
          )
        ]}
      >
        <div class={[
          "absolute inset-0",
          if(@post.mature_content && !(@content_warning? && @content_warning),
            do:
              "bg-gradient-to-b from-amber-100/50 via-amber-50/30 to-amber-100/50 dark:from-amber-900/40 dark:via-slate-800/20 dark:to-amber-900/40",
            else:
              "bg-gradient-to-b from-teal-100/50 via-teal-50/30 to-teal-100/50 dark:from-teal-900/40 dark:via-slate-800/20 dark:to-teal-900/40"
          )
        ]}>
        </div>
        <div class={[
          "absolute top-0 left-0 right-0 h-1 opacity-60",
          if(@post.mature_content && !(@content_warning? && @content_warning),
            do:
              "bg-gradient-to-r from-amber-400 via-orange-400 to-amber-400 dark:from-amber-500 dark:via-orange-500 dark:to-amber-500",
            else:
              "bg-gradient-to-r from-teal-400 via-cyan-400 to-teal-400 dark:from-teal-500 dark:via-cyan-500 dark:to-teal-500"
          )
        ]}>
        </div>
        <div class="relative h-full flex flex-col justify-center p-4 sm:p-6">
          <div class="flex items-start gap-4">
            <div class={[
              "flex-shrink-0 flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-full border shadow-sm",
              if(@post.mature_content && !(@content_warning? && @content_warning),
                do:
                  "bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-800/60 dark:to-orange-800/60 border-amber-200 dark:border-amber-700",
                else:
                  "bg-gradient-to-br from-teal-100 to-cyan-100 dark:from-teal-800/60 dark:to-cyan-800/60 border-teal-200 dark:border-teal-700"
              )
            ]}>
              <.phx_icon
                name={
                  if @post.mature_content && !(@content_warning? && @content_warning),
                    do: "hero-exclamation-triangle",
                    else: "hero-hand-raised"
                }
                class={[
                  "h-5 w-5 sm:h-6 sm:w-6",
                  if(@post.mature_content && !(@content_warning? && @content_warning),
                    do: "text-amber-600 dark:text-amber-400",
                    else: "text-teal-600 dark:text-teal-400"
                  )
                ]}
              />
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-1">
                <span class={[
                  "text-base sm:text-lg font-semibold",
                  if(@post.mature_content && !(@content_warning? && @content_warning),
                    do: "text-amber-700 dark:text-amber-300",
                    else: "text-teal-700 dark:text-teal-300"
                  )
                ]}>
                  <%= if @post.mature_content && !(@content_warning? && @content_warning) do %>
                    18+ Mature Content
                  <% else %>
                    Content Warning
                  <% end %>
                </span>
                <%= if @content_warning_category do %>
                  <span class={[
                    "text-xs px-2 py-0.5 rounded-full border",
                    if(@post.mature_content && !(@content_warning? && @content_warning),
                      do:
                        "bg-amber-100 dark:bg-amber-800/50 text-amber-700 dark:text-amber-300 border-amber-200 dark:border-amber-700",
                      else:
                        "bg-teal-100 dark:bg-teal-800/50 text-teal-700 dark:text-teal-300 border-teal-200 dark:border-teal-700"
                    )
                  ]}>
                    {format_content_warning_category(@content_warning_category)}
                  </span>
                <% end %>
                <%= if @post.mature_content && !@content_warning_category do %>
                  <span class="text-xs px-2 py-0.5 rounded-full bg-amber-100 dark:bg-amber-800/50 text-amber-700 dark:text-amber-300 border border-amber-200 dark:border-amber-700">
                    Age Restricted
                  </span>
                <% end %>
              </div>
              <%= if @content_warning? && @content_warning do %>
                <p class={[
                  "text-sm leading-relaxed line-clamp-2",
                  if(@post.mature_content,
                    do: "text-amber-600 dark:text-amber-400",
                    else: "text-teal-600 dark:text-teal-400"
                  )
                ]}>
                  {@content_warning}
                </p>
              <% else %>
                <p class="text-sm text-amber-600 dark:text-amber-400 leading-relaxed">
                  This post contains mature content.
                </p>
              <% end %>
            </div>
            <button
              type="button"
              id={"content-warning-button-#{@post.id}"}
              aria-label="Show content"
              phx-click={
                JS.hide(
                  to: "#content-warning-#{@post.id}",
                  transition:
                    {"ease-in duration-200", "opacity-100 translate-y-0", "opacity-0 -translate-y-4"}
                )
                |> JS.show(
                  to: "#content-warning-bar-#{@post.id}",
                  transition:
                    {"ease-out duration-200", "opacity-0 translate-y-4", "opacity-100 translate-y-0"}
                )
              }
              class={[
                "flex-shrink-0 inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white rounded-lg shadow-lg transition-all duration-200 ease-out transform hover:scale-105 active:scale-95",
                if(@post.mature_content && !(@content_warning? && @content_warning),
                  do:
                    "bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 dark:from-amber-600 dark:to-orange-600 dark:hover:from-amber-500 dark:hover:to-orange-500 shadow-amber-500/25 dark:shadow-amber-900/40",
                  else:
                    "bg-gradient-to-r from-teal-500 to-cyan-500 hover:from-teal-600 hover:to-cyan-600 dark:from-teal-600 dark:to-cyan-600 dark:hover:from-teal-500 dark:hover:to-cyan-500 shadow-teal-500/25 dark:shadow-teal-900/40"
                )
              ]}
            >
              <.phx_icon name="hero-eye" class="h-4 w-4" />
              <span class="hidden sm:inline">Show</span>
            </button>
          </div>
        </div>
      </div>

      <%!-- Post content --%>
      <div class="relative p-6">
        <%!-- User header --%>
        <div class="flex items-start gap-4 mb-4">
          <%!-- Enhanced liquid metal avatar - conditionally linked to author profile --%>
          <.link
            :if={show_author_profile?(@author_profile_slug, @author_profile_visibility)}
            navigate={~p"/app/profile/#{@author_profile_slug}"}
            class="flex-shrink-0"
          >
            <.liquid_avatar
              src={@user_avatar}
              name={@user_name}
              size="md"
              verified={@verified}
              clickable={true}
              status={@user_status}
              status_message={@user_status_message}
              show_status={@show_post_author_status}
              user_id={@post.user_id}
              id={"avatar-#{@post.id}"}
            />
          </.link>
          <.liquid_avatar
            :if={!show_author_profile?(@author_profile_slug, @author_profile_visibility)}
            src={@user_avatar}
            name={@user_name}
            size="md"
            verified={@verified}
            clickable={true}
            status={@user_status}
            status_message={@user_status_message}
            show_status={@show_post_author_status}
            user_id={@post.user_id}
            id={"avatar-#{@post.id}"}
          />

          <%!-- User info --%>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <.link
                :if={show_author_profile?(@author_profile_slug, @author_profile_visibility)}
                navigate={~p"/app/profile/#{@author_profile_slug}"}
                class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
              >
                {@user_name}
              </.link>
              <span
                :if={!show_author_profile?(@author_profile_slug, @author_profile_visibility)}
                class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate"
              >
                {@user_name}
              </span>
              <.phx_icon
                :if={@verified}
                name="hero-check-badge"
                class="h-5 w-5 text-emerald-500 flex-shrink-0"
              />
              <%!-- Interaction controls indicators --%>
              <div class="flex items-center gap-1 ml-2">
                <%!-- Ephemeral indicator with countdown --%>
                <.phx_icon
                  :if={@post.is_ephemeral}
                  id={"ephemeral-indicator-#{@post.id}"}
                  name="hero-clock"
                  class="h-3 w-3 text-amber-500 dark:text-amber-400"
                  phx_hook="TippyHook"
                  data_tippy_content={
                    if @post.expires_at do
                      expires_in = MossletWeb.Helpers.get_expiration_time_remaining(@post)

                      if expires_in do
                        "Ephemeral post - expires in #{expires_in}"
                      else
                        "Ephemeral post - expired"
                      end
                    else
                      "Ephemeral post - will auto-delete"
                    end
                  }
                />

                <%!-- Mature content indicator --%>
                <.phx_icon
                  :if={@post.mature_content}
                  id={"mature-content-indicator-#{@post.id}"}
                  name="hero-exclamation-triangle"
                  class="h-3 w-3 text-orange-500 dark:text-orange-400"
                  phx_hook="TippyHook"
                  data_tippy_content="Mature content (18+)"
                />

                <%!-- No replies indicator --%>
                <.phx_icon
                  :if={!@post.allow_replies}
                  id={"allow-replies-indicator-#{@post.id}"}
                  name="hero-chat-bubble-oval-left-ellipsis"
                  class="h-3 w-3 text-slate-400 dark:text-slate-500 line-through"
                  phx_hook="TippyHook"
                  data_tippy_content="Replies disabled"
                />

                <%!-- No shares indicator --%>
                <.phx_icon
                  :if={!@post.allow_shares}
                  id={"allow-shares-indicator-#{@post.id}"}
                  name="hero-arrow-path"
                  class="h-3 w-3 text-slate-400 dark:text-slate-500 line-through"
                  phx_hook="TippyHook"
                  data_tippy_content="Sharing disabled"
                />

                <%!-- No bookmarks indicator --%>
                <.phx_icon
                  :if={!@post.allow_bookmarks}
                  id={"allow-bookmarks-indicator-#{@post.id}"}
                  name="hero-bookmark"
                  class="h-3 w-3 text-slate-400 dark:text-slate-500 line-through"
                  phx_hook="TippyHook"
                  data_tippy_content="Bookmarking disabled"
                />

                <%!-- Connection required for replies indicator --%>
                <.phx_icon
                  :if={@post.require_follow_to_reply && @post.visibility == :public}
                  id={"connection-required-reply-indicator-#{@post.id}"}
                  name="hero-shield-check"
                  class="h-3 w-3 text-emerald-500 dark:text-emerald-400"
                  phx_hook="TippyHook"
                  data_tippy_content="Connection required to reply"
                />
              </div>
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

            <:item
              :if={@current_user_id != @post.user_id && is_shared_recipient?(@post, @current_user_id)}
              phx_click="remove_self_from_post"
              phx_value_post_id={@post.id}
              data_confirm="Are you sure you want to remove yourself from this post? You will no longer be able to see it."
              color="slate"
            >
              <.phx_icon name="hero-x-circle" class="h-4 w-4" /> Remove Post
            </:item>
          </.liquid_dropdown>
        </div>

        <%!-- Content Warning Bar (shown after reveal - click to hide content again) --%>
        <button
          :if={(@content_warning? && @content_warning) || @post.mature_content}
          type="button"
          id={"content-warning-bar-#{@post.id}"}
          phx-click={
            JS.hide(
              to: "#content-warning-bar-#{@post.id}",
              transition:
                {"ease-in duration-150", "opacity-100 translate-y-0", "opacity-0 -translate-y-4"}
            )
            |> JS.show(
              to: "#content-warning-#{@post.id}",
              transition:
                {"ease-out duration-200", "opacity-0 translate-y-4", "opacity-100 translate-y-0"}
            )
          }
          class={[
            "content-warning-bar hidden absolute left-4 right-4 top-0 h-1 rounded-b-lg opacity-70 hover:opacity-100 hover:h-1.5 transition-all duration-200 cursor-pointer group/cw z-30",
            if(@post.mature_content && !(@content_warning? && @content_warning),
              do:
                "bg-gradient-to-r from-amber-400 via-orange-400 to-amber-400 dark:from-amber-500 dark:via-orange-500 dark:to-amber-500",
              else:
                "bg-gradient-to-r from-teal-400 via-cyan-400 to-teal-400 dark:from-teal-500 dark:via-cyan-500 dark:to-teal-500"
            )
          ]}
          aria-label="Hide content"
        >
          <span class={[
            "absolute left-1/2 -translate-x-1/2 top-3 opacity-60 group-hover/cw:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border",
            if(@post.mature_content && !(@content_warning? && @content_warning),
              do: "text-amber-600 dark:text-amber-400 border-amber-200/50 dark:border-amber-700/50",
              else: "text-teal-600 dark:text-teal-400 border-teal-200/50 dark:border-teal-700/50"
            )
          ]}>
            Hide content
          </span>
        </button>

        <%!-- Post content with markdown support --%>
        <div class="mb-4">
          <%!-- Legacy posts with HTML (sanitized and rendered) --%>
          <p
            :if={contains_html?(@content)}
            class="text-slate-900 dark:text-slate-100 leading-relaxed whitespace-pre-wrap text-base"
          >
            {html_block(@content)}
          </p>

          <%!-- Modern posts with markdown rendering --%>
          <div
            :if={!contains_html?(@content)}
            class="prose prose-slate dark:prose-invert prose-sm max-w-none prose-p:my-1.5 prose-headings:mt-3 prose-headings:mb-1.5 prose-ul:my-1.5 prose-ol:my-1.5 prose-li:my-0.5 prose-pre:my-2 prose-code:text-emerald-600 dark:prose-code:text-emerald-400 prose-a:text-emerald-600 dark:prose-a:text-emerald-400 prose-a:no-underline hover:prose-a:underline"
          >
            {format_decrypted_content(@content)}
          </div>

          <%!-- Images with enhanced encrypted display system --%>
          <div :if={@post && photos?(@post.image_urls)} class="mb-4">
            <.liquid_post_photo_gallery post={@post} current_scope={@current_scope} class="" />
          </div>

          <%!-- URL Preview Card (if available) --%>
          <div :if={@decrypted_url_preview} class="mb-4">
            <a
              href={@decrypted_url_preview["url"]}
              target="_blank"
              rel="noopener noreferrer"
              class="flex gap-3 p-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white/95 dark:bg-slate-800/95 hover:border-emerald-400 dark:hover:border-emerald-500 transition-all duration-200 group"
            >
              <div
                :if={@decrypted_url_preview["image"] && @decrypted_url_preview["image"] != ""}
                class="w-20 h-14 shrink-0 overflow-hidden rounded-lg"
                phx-hook="URLPreviewHook"
                id={"url-preview-#{@post.id}"}
                data-post-id={@post.id}
                data-image-hash={@decrypted_url_preview["image_hash"]}
                data-url-preview-fetched-at={@post.url_preview_fetched_at}
                data-presigned-url={@decrypted_url_preview["image"]}
              >
                <img
                  alt={@decrypted_url_preview["title"] || "Preview image"}
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                />
              </div>

              <div class="flex-1 min-w-0 py-0.5">
                <div class="flex items-center gap-1.5 mb-0.5">
                  <.phx_icon name="hero-link" class="h-3 w-3 text-slate-400" />
                  <span class="text-xs text-slate-500 dark:text-slate-400 truncate">
                    {@decrypted_url_preview["site_name"] || "External Link"}
                  </span>
                </div>

                <p
                  :if={@decrypted_url_preview["title"]}
                  class="font-medium text-sm text-slate-900 dark:text-slate-100 line-clamp-1 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors"
                >
                  {@decrypted_url_preview["title"]}
                </p>

                <p
                  :if={@decrypted_url_preview["description"]}
                  class="text-xs text-slate-600 dark:text-slate-400 line-clamp-2 mt-0.5"
                >
                  {@decrypted_url_preview["description"]}
                </p>
              </div>
            </a>
          </div>
        </div>

        <div class="flex items-center justify-between pt-3 border-t border-slate-200/50 dark:border-slate-700/50">
          <div class="flex items-center gap-1">
            <button
              id={
                if @unread?,
                  do: "mark-read-button-#{@post_id}",
                  else: "mark-as-unread-button-#{@post_id}"
              }
              class={[
                "p-2 rounded-lg transition-all duration-200 ease-out group/read active:scale-95 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2",
                "phx-click-loading:opacity-60 phx-click-loading:cursor-wait phx-click-loading:pointer-events-none",
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
                class="h-5 w-5 transition-transform duration-200 group-hover/read:scale-110 phx-click-loading:hidden"
              />
              <svg
                class="hidden phx-click-loading:block h-5 w-5 animate-spin text-teal-500"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
              >
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                >
                </circle>
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                >
                </path>
              </svg>
              <span class="sr-only">{if @unread?, do: "Mark as read", else: "Mark as unread"}</span>
            </button>

            <.liquid_timeline_action
              :if={@can_reply?}
              icon="hero-chat-bubble-oval-left"
              active_icon="hero-chat-bubble-oval-left-solid"
              count={Map.get(@stats, :replies, 0)}
              notification_count={
                if @calm_notifications && @post.user_id == @current_scope.user.id,
                  do: @unread_replies_count,
                  else: 0
              }
              label="Reply"
              color="emerald"
              icon_id={"reply-icon-#{@post_id}"}
              id={"reply-button-#{@post_id}"}
              phx-hook="TippyHook"
              data-tippy-content="Toggle reply composer"
              phx-click={
                toggle_reply_section(
                  @post_id,
                  (@calm_notifications && @post.user_id == @current_scope.user.id) and
                    @unread_replies_count > 0
                )
              }
            />
            <.liquid_timeline_action
              :if={@can_repost}
              icon="hero-paper-airplane"
              id={"share-button-#{@post.id}"}
              icon_id={"share-icon-#{@post.id}"}
              count={Map.get(@stats, :shares, 0)}
              label="Share"
              color="emerald"
              repost_post_id={@post.id}
              phx-hook="TippyHook"
              data-tippy-content="Share with someone"
              phx-click="open_share_modal"
              phx-value-id={@post_id}
              phx-value-body={@content}
              phx-value-username={@user_handle}
            />
            <.liquid_timeline_action
              :if={!@can_repost && @post.user_id == @current_scope.user.id && @post.allow_shares}
              icon="hero-paper-airplane"
              id={"share-button-disabled-#{@post.id}"}
              icon_id={"share-icon-disabled-#{@post.id}"}
              count={Map.get(@stats, :shares, 0)}
              label="Share"
              color="emerald"
              repost_post_id={@post.id}
              phx-hook="TippyHook"
              class="cursor-not-allowed"
              data-tippy-content="You cannot share your own post"
              phx-click={nil}
              phx-value-id={nil}
              phx-value-body={nil}
              phx-value-username={nil}
            />
            <.liquid_timeline_action
              :if={!@can_repost && @post.user_id != @current_scope.user.id}
              icon="hero-paper-airplane"
              id={"share-button-disabled-#{@post.id}"}
              icon_id={"share-icon-disabled-#{@post.id}"}
              count={Map.get(@stats, :shares, 0)}
              label="Share"
              color="emerald"
              repost_post_id={@post.id}
              phx-hook="TippyHook"
              class="cursor-not-allowed"
              data-tippy-content="You have already shared this"
              phx-click={nil}
              phx-value-id={nil}
              phx-value-body={nil}
              phx-value-username={nil}
            />
            <.liquid_timeline_action
              id={
                if @liked,
                  do: "hero-heart-solid-button-#{@post_id}",
                  else: "hero-heart-button-#{@post_id}"
              }
              icon_id={
                if @liked,
                  do: "hero-heart-solid-icon-#{@post_id}",
                  else: "hero-heart-icon-#{@post_id}"
              }
              icon={if @liked, do: "hero-heart-solid", else: "hero-heart"}
              count={Map.get(@stats, :likes, 0)}
              label={if @liked, do: "Unlike", else: "Like"}
              color="rose"
              active={@liked}
              post_id={@post_id}
              phx-hook="TippyHook"
              data-tippy-content={if @liked, do: "Remove love", else: "Show love"}
              phx-click={if @liked, do: "unfav", else: "fav"}
              phx-value-id={@post_id}
            />
          </div>

          <button
            :if={@can_bookmark?}
            id={
              if @bookmarked,
                do: "hero-bookmark-solid-button-#{@post_id}",
                else: "hero-bookmark-button-#{@post_id}"
            }
            class={[
              "p-2 rounded-lg transition-all duration-200 ease-out group/bookmark active:scale-95 focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:ring-offset-2",
              "phx-click-loading:opacity-60 phx-click-loading:cursor-wait phx-click-loading:pointer-events-none",
              if(@bookmarked,
                do: "text-amber-600 dark:text-amber-400 bg-amber-50/50 dark:bg-amber-900/20",
                else:
                  "text-slate-400 hover:text-amber-600 dark:hover:text-amber-400 hover:bg-amber-50/50 dark:hover:bg-amber-900/20"
              )
            ]}
            phx-click="bookmark_post"
            phx-value-id={@post_id}
            phx-hook="TippyHook"
            data-tippy-content={if @bookmarked, do: "Remove bookmark", else: "Bookmark this post"}
          >
            <.phx_icon
              id={
                if @bookmarked,
                  do: "hero-bookmark-solid-icon-#{@post_id}",
                  else: "hero-bookmark-icon-#{@post_id}"
              }
              name={if @bookmarked, do: "hero-bookmark-solid", else: "hero-bookmark"}
              class="h-5 w-5 transition-transform duration-200 group-hover/bookmark:scale-110 phx-click-loading:hidden"
            />
            <svg
              class="hidden phx-click-loading:block h-5 w-5 animate-spin text-amber-500"
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
            <span class="sr-only">
              {if @bookmarked, do: "Remove bookmark", else: "Bookmark this post"}
            </span>
          </button>
        </div>
      </div>
    </article>

    <%!-- Collapsible reply composer LiveComponent (hidden by default, toggled by JS) --%>
    <.live_component
      :if={@can_reply?}
      module={MossletWeb.TimelineLive.ReplyComposerComponent}
      id={"reply-composer-#{@post.id}"}
      post_id={@post.id}
      visibility={@post.visibility}
      current_scope={@current_scope}
      user_name={user_name(@current_scope.user, @current_scope.key) || "You"}
      user_avatar={
        if show_avatar?(@current_scope.user),
          do: maybe_get_user_avatar(@current_scope.user, @current_scope.key) || "/images/logo.svg",
          else: "/images/logo.svg"
      }
      word_limit={500}
      username={decr(@current_scope.user.username, @current_scope.user, @current_scope.key)}
      class=""
    />

    <%!-- Collapsible reply thread (uses existing liquid components) --%>
    <.liquid_collapsible_reply_thread
      post_id={@post.id}
      replies={@post.replies || []}
      reply_count={Map.get(@stats, :replies, 0)}
      show={true}
      current_scope={@current_scope}
      unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
      calm_notifications={@calm_notifications}
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

  defp visibility_overlay_gradient(visibility) do
    case visibility do
      :private ->
        "from-slate-400 via-slate-500 to-slate-400 dark:from-slate-500 dark:via-slate-600 dark:to-slate-500"

      :connections ->
        "from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500"

      :specific_groups ->
        "from-purple-400 via-violet-400 to-purple-400 dark:from-purple-500 dark:via-violet-500 dark:to-purple-500"

      :specific_users ->
        "from-amber-400 via-yellow-400 to-amber-400 dark:from-amber-500 dark:via-yellow-500 dark:to-amber-500"

      _ ->
        "from-slate-400 via-slate-500 to-slate-400 dark:from-slate-500 dark:via-slate-600 dark:to-slate-500"
    end
  end

  defp visibility_overlay_icon_bg(visibility) do
    case visibility do
      :private ->
        "from-slate-100 to-slate-200 dark:from-slate-800/50 dark:to-slate-700/50"

      :connections ->
        "from-emerald-100 to-teal-100 dark:from-emerald-900/50 dark:to-teal-900/50"

      :specific_groups ->
        "from-purple-100 to-violet-100 dark:from-purple-900/50 dark:to-violet-900/50"

      :specific_users ->
        "from-amber-100 to-yellow-100 dark:from-amber-900/50 dark:to-yellow-900/50"

      _ ->
        "from-slate-100 to-slate-200 dark:from-slate-800/50 dark:to-slate-700/50"
    end
  end

  defp visibility_overlay_icon(visibility) do
    case visibility do
      :private -> "hero-lock-closed-solid"
      :connections -> "hero-user-group-solid"
      :specific_groups -> "hero-user-group-solid"
      :specific_users -> "hero-users-solid"
      _ -> "hero-lock-closed-solid"
    end
  end

  defp visibility_overlay_icon_color(visibility) do
    case visibility do
      :private -> "text-slate-600 dark:text-slate-400"
      :connections -> "text-emerald-600 dark:text-emerald-400"
      :specific_groups -> "text-purple-600 dark:text-purple-400"
      :specific_users -> "text-amber-600 dark:text-amber-400"
      _ -> "text-slate-600 dark:text-slate-400"
    end
  end

  defp visibility_overlay_back_button_classes(visibility) do
    case visibility do
      :private ->
        "text-slate-600 dark:text-slate-400 bg-slate-50/80 dark:bg-slate-900/30 hover:bg-slate-100 dark:hover:bg-slate-900/50 border-slate-200/50 dark:border-slate-700/50"

      :connections ->
        "text-emerald-600 dark:text-emerald-400 bg-emerald-50/80 dark:bg-emerald-900/30 hover:bg-emerald-100 dark:hover:bg-emerald-900/50 border-emerald-200/50 dark:border-emerald-700/50"

      :specific_groups ->
        "text-purple-600 dark:text-purple-400 bg-purple-50/80 dark:bg-purple-900/30 hover:bg-purple-100 dark:hover:bg-purple-900/50 border-purple-200/50 dark:border-purple-700/50"

      :specific_users ->
        "text-amber-600 dark:text-amber-400 bg-amber-50/80 dark:bg-amber-900/30 hover:bg-amber-100 dark:hover:bg-amber-900/50 border-amber-200/50 dark:border-amber-700/50"

      _ ->
        "text-slate-600 dark:text-slate-400 bg-slate-50/80 dark:bg-slate-900/30 hover:bg-slate-100 dark:hover:bg-slate-900/50 border-slate-200/50 dark:border-slate-700/50"
    end
  end

  defp visibility_add_button_classes(visibility) do
    case visibility do
      :private ->
        "text-slate-600 dark:text-slate-400 border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-800/50"

      :connections ->
        "text-emerald-600 dark:text-emerald-400 border-emerald-300 dark:border-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-900/20"

      :public ->
        "text-blue-600 dark:text-blue-400 border-blue-300 dark:border-blue-700 hover:bg-blue-50 dark:hover:bg-blue-900/20"

      :specific_groups ->
        "text-purple-600 dark:text-purple-400 border-purple-300 dark:border-purple-700 hover:bg-purple-50 dark:hover:bg-purple-900/20"

      :specific_users ->
        "text-amber-600 dark:text-amber-400 border-amber-300 dark:border-amber-700 hover:bg-amber-50 dark:hover:bg-amber-900/20"

      _ ->
        "text-slate-600 dark:text-slate-400 border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-800/50"
    end
  end

  defp visibility_indicator_hover_text_classes(visibility) do
    case visibility do
      :private ->
        "text-slate-600 dark:text-slate-400 bg-white/90 dark:bg-slate-800/90 border-slate-200/50 dark:border-slate-700/50"

      :connections ->
        "text-emerald-600 dark:text-emerald-400 bg-white/90 dark:bg-slate-800/90 border-emerald-200/50 dark:border-emerald-700/50"

      :public ->
        "text-blue-600 dark:text-blue-400 bg-white/90 dark:bg-slate-800/90 border-blue-200/50 dark:border-blue-700/50"

      :specific_groups ->
        "text-purple-600 dark:text-purple-400 bg-white/90 dark:bg-slate-800/90 border-purple-200/50 dark:border-purple-700/50"

      :specific_users ->
        "text-amber-600 dark:text-amber-400 bg-white/90 dark:bg-slate-800/90 border-amber-200/50 dark:border-amber-700/50"

      _ ->
        "text-slate-600 dark:text-slate-400 bg-white/90 dark:bg-slate-800/90 border-slate-200/50 dark:border-slate-700/50"
    end
  end

  defp visibility_indicator_gradient(visibility) do
    case visibility do
      :private ->
        "from-slate-400 via-slate-500 to-slate-400 dark:from-slate-500 dark:via-slate-600 dark:to-slate-500"

      :connections ->
        "from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500"

      :public ->
        "from-blue-400 via-sky-400 to-blue-400 dark:from-blue-500 dark:via-sky-500 dark:to-blue-500"

      :specific_groups ->
        "from-purple-400 via-violet-400 to-purple-400 dark:from-purple-500 dark:via-violet-500 dark:to-purple-500"

      :specific_users ->
        "from-amber-400 via-yellow-400 to-amber-400 dark:from-amber-500 dark:via-yellow-500 dark:to-amber-500"

      _ ->
        "from-slate-400 via-slate-500 to-slate-400 dark:from-slate-500 dark:via-slate-600 dark:to-slate-500"
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
  attr :active_icon, :string, default: nil
  attr :count, :integer, default: 0
  attr :notification_count, :integer, default: 0
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :color, :string, default: "slate", values: ~w(slate emerald amber rose)
  attr :class, :any, default: ""
  attr :post_id, :string, default: nil
  attr :reply_id, :string, default: nil
  attr :current_user_id, :string, default: nil
  attr :icon_id, :string, default: nil
  attr :repost_post_id, :string, default: nil

  attr :id, :string, default: nil

  attr :rest, :global,
    include:
      ~w(phx-click phx-value-id phx-value-url data-confirm data-composer-open data-expanded phx-hook data-tippy-content)

  def liquid_timeline_action(assigns) do
    assigns = assign_new(assigns, :has_active_icon, fn -> assigns[:active_icon] != nil end)

    ~H"""
    <button
      id={@id}
      class={[
        "group/action relative flex items-center gap-2 px-3 py-2 rounded-xl",
        "transition-all duration-200 ease-out active:scale-95",
        "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
        "phx-click-loading:opacity-60 phx-click-loading:cursor-wait phx-click-loading:pointer-events-none",
        timeline_action_classes(@active, @color),
        @class
      ]}
      data-expanded="false"
      {@rest}
    >
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-300 ease-out rounded-xl",
        "group-hover/action:opacity-100",
        "[.reply-expanded_&]:opacity-100",
        timeline_action_bg_classes(@color)
      ]}>
      </div>

      <div class="relative flex items-center gap-2">
        <%!-- Notification badge for unread replies --%>
        <span
          :if={@notification_count > 0}
          id={"notification-badge-#{@id}"}
          class={[
            "absolute -top-1.5 -right-1.5 z-10 flex items-center justify-center",
            "min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold",
            "bg-gradient-to-r from-emerald-500 to-teal-500 text-white",
            "shadow-sm shadow-emerald-500/30",
            "animate-pulse"
          ]}
        >
          {if @notification_count > 99, do: "99+", else: @notification_count}
        </span>
        <%!-- Default icon (shown when not expanded) --%>
        <.phx_icon
          name={@icon}
          id={@icon_id}
          class={[
            "h-4 w-4 transition-all duration-200 ease-out group-hover/action:scale-110",
            "phx-click-loading:hidden",
            @has_active_icon && "[.reply-expanded_&]:hidden"
          ]}
        />
        <%!-- Active/filled icon (shown when expanded, only if active_icon is provided) --%>
        <.phx_icon
          :if={@has_active_icon}
          name={@active_icon}
          id={"#{@icon_id}-active"}
          class={[
            "h-4 w-4 transition-all duration-200 ease-out scale-110",
            "phx-click-loading:hidden",
            "hidden [.reply-expanded_&]:block"
          ]}
        />
        <%!-- Loading spinner --%>
        <svg
          class="hidden phx-click-loading:block h-4 w-4 animate-spin"
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

        <span
          :if={@count > 0 || (@color == "rose" && (@post_id || @reply_id)) || @repost_post_id}
          class="text-sm font-medium"
          data-post-fav-count={if @color == "rose" && @post_id, do: @post_id, else: nil}
          data-reply-fav-count={if @color == "rose" && @reply_id, do: @reply_id, else: nil}
          data-post-repost-count={@repost_post_id}
        >
          {if @count > 0, do: @count, else: ""}
        </span>
      </div>
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
  attr :status, :string, default: "calm", values: ~w(online calm away active busy offline)
  attr :message, :string, default: nil

  attr :show_status, :boolean,
    default: true,
    doc: "Whether to show the status indicator (based on privacy settings)"

  attr :class, :any, default: ""

  def liquid_timeline_status(assigns) do
    ~H"""
    <div
      :if={@show_status}
      class={[
        "inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
        "border transition-all duration-200 ease-out",
        timeline_status_classes(@status),
        @class
      ]}
    >
      <%!-- Status indicator --%>
      <div class={[
        "relative flex-shrink-0 rounded-full transition-all duration-300 ease-out",
        timeline_status_dot_size(@status),
        timeline_status_dot_classes(@status)
      ]}>
        <%!-- Pulse animation for certain statuses --%>
        <div
          :if={@status in ["online", "calm", "active", "busy", "away"]}
          class={[
            "absolute inset-0 rounded-full animate-ping opacity-75",
            timeline_status_ping_classes(@status)
          ]}
        >
        </div>
      </div>

      <span class="font-medium">
        {@message || get_status_fallback_message(String.to_existing_atom(@status))}
      </span>
    </div>

    <div
      :if={!@show_status}
      class={[
        "inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
        "border transition-all duration-200 ease-out",
        timeline_status_classes("offline"),
        @class
      ]}
    >
      <%!-- Status indicator --%>
      <div class={[
        "relative flex-shrink-0 rounded-full transition-all duration-300 ease-out",
        timeline_status_dot_size("offline"),
        timeline_status_dot_classes("offline")
      ]}>
      </div>

      <span class="font-medium">
        {"Not sharing status"}
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
  attr :loading_tab, :string, default: nil
  attr :class, :any, default: ""

  def liquid_timeline_tabs(assigns) do
    ~H"""
    <div class={[
      "relative flex-1 min-w-0",
      @class
    ]}>
      <div
        id="timeline-tabs-scroll"
        phx-hook="ScrollableTabs"
        class="overflow-x-auto scrollbar-hide xs:overflow-visible"
      >
        <div class="flex items-center gap-1 xs:justify-between">
          <button
            :for={tab <- @tabs}
            data-active={to_string(tab.key == @active_tab)}
            disabled={@loading_tab != nil}
            class={[
              "relative flex items-center justify-center gap-1 sm:gap-1.5 transition-all duration-200 ease-out",
              "focus:outline-none focus:ring-2 focus:ring-emerald-500/50",
              "flex-shrink-0 xs:flex-1",
              "px-3 py-1.5 sm:py-2 text-xs sm:text-sm font-medium rounded-lg",
              timeline_tab_classes(tab.key, tab.key == @active_tab),
              @loading_tab != nil && "cursor-wait"
            ]}
            phx-click="switch_tab"
            phx-value-tab={tab.key}
          >
            <%!-- Active tab background --%>
            <div
              :if={tab.key == @active_tab}
              class={[
                "absolute inset-0 rounded-lg transition-all duration-300 ease-out",
                timeline_tab_active_bg(tab.key)
              ]}
            >
            </div>

            <%!-- Loading spinner for the tab being loaded --%>
            <div
              :if={tab.key == @loading_tab}
              class="h-4 w-4 flex-shrink-0 relative z-10 animate-spin"
            >
              <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none">
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="3"
                />
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                />
              </svg>
            </div>

            <%!-- Tab icon (hide when loading this tab) --%>
            <.phx_icon
              :if={tab_icon(tab.key) && tab.key != @loading_tab}
              name={tab_icon(tab.key)}
              class="h-4 w-4 flex-shrink-0 relative z-10"
            />

            <%!-- Tab label --%>
            <span class="relative z-10">
              {tab.label}
            </span>

            <%!-- Unread badge (inline flow, never clipped) --%>
            <span
              :if={tab[:unread] && tab.unread > 0 && tab.key != @loading_tab}
              class={[
                "flex-shrink-0 relative z-10",
                "flex items-center justify-center",
                "min-w-[1.25rem] h-5 px-1.5 text-[10px] font-bold rounded-full",
                "bg-gradient-to-r from-teal-400 to-cyan-400 text-white",
                "shadow-sm animate-pulse"
              ]}
            >
              {tab.unread}
            </span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline header - beautiful banner with user customization support.

  Shows the user's chosen banner image if they have a profile set up,
  otherwise displays an elegant default gradient design.
  """
  attr :class, :any, default: ""
  attr :id, :string, default: nil
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :custom_banner_src, :any, default: nil, doc: "async result for custom banner data URL"
  attr :banner_loading, :boolean, default: false, doc: "whether custom banner is loading"

  def liquid_timeline_header(assigns) do
    assigns = assign_scope_fields(assigns)
    banner_image = get_user_banner_image(assigns[:current_scope].user)
    assigns = assign(assigns, :banner_image, banner_image)

    ~H"""
    <div
      id={@id}
      class={[
        "relative overflow-hidden rounded-2xl",
        @class
      ]}
    >
      <%= cond do %>
        <% @banner_loading -> %>
          <div class="relative h-32 sm:h-40 lg:h-48 bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700">
            <div class="absolute inset-0 flex items-center justify-center">
              <div class="w-10 h-10 border-3 border-purple-400 border-t-transparent rounded-full animate-spin">
              </div>
            </div>
          </div>
        <% @custom_banner_src -> %>
          <div class="relative h-32 sm:h-40 lg:h-48">
            <img
              src={@custom_banner_src}
              alt=""
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/20 to-transparent" />
            <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/10 via-transparent to-teal-500/10" />
            <div class="absolute bottom-0 left-0 right-0 p-4 sm:p-6">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-white/20 backdrop-blur-md shadow-lg border border-white/30">
                  <.phx_icon
                    name="hero-book-open"
                    class="w-5 h-5 sm:w-6 sm:h-6 text-white drop-shadow-sm"
                  />
                </div>
                <div>
                  <h1 class="text-lg sm:text-xl font-semibold text-white drop-shadow-sm">
                    Timeline
                  </h1>
                  <p class="text-sm text-white/80 drop-shadow-sm">
                    Your private feed
                  </p>
                </div>
              </div>
            </div>
          </div>
        <% @banner_image -> %>
          <div class="relative h-32 sm:h-40 lg:h-48">
            <img
              src={~p"/images/profile/#{@banner_image}"}
              alt=""
              class="absolute inset-0 w-full h-full object-cover"
            />
            <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-black/20 to-transparent" />
            <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/10 via-transparent to-teal-500/10" />
            <div class="absolute bottom-0 left-0 right-0 p-4 sm:p-6">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-white/20 backdrop-blur-md shadow-lg border border-white/30">
                  <.phx_icon
                    name="hero-book-open"
                    class="w-5 h-5 sm:w-6 sm:h-6 text-white drop-shadow-sm"
                  />
                </div>
                <div>
                  <h1 class="text-lg sm:text-xl font-semibold text-white drop-shadow-sm">
                    Timeline
                  </h1>
                  <p class="text-sm text-white/80 drop-shadow-sm">
                    Your private feed
                  </p>
                </div>
              </div>
            </div>
          </div>
        <% true -> %>
          <div class="relative h-32 sm:h-40 lg:h-48 bg-gradient-to-br from-emerald-500/90 via-teal-500/80 to-cyan-500/90 dark:from-emerald-600/80 dark:via-teal-600/70 dark:to-cyan-600/80">
            <div class="absolute inset-0 overflow-hidden">
              <div class="absolute -top-24 -right-24 w-64 h-64 bg-white/10 rounded-full blur-3xl animate-pulse" />
              <div class="absolute -bottom-16 -left-16 w-48 h-48 bg-emerald-300/20 rounded-full blur-2xl" />
              <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-32 bg-teal-200/10 rounded-full blur-3xl rotate-12" />
              <svg
                class="absolute inset-0 w-full h-full"
                viewBox="0 0 800 200"
                preserveAspectRatio="none"
              >
                <path
                  d="M0 120 Q200 80 400 120 T800 100"
                  fill="none"
                  stroke="white"
                  stroke-width="1"
                  opacity="0.2"
                />
                <path
                  d="M0 150 Q250 110 500 150 T800 130"
                  fill="none"
                  stroke="white"
                  stroke-width="0.8"
                  opacity="0.15"
                />
                <path
                  d="M0 80 Q150 50 350 80 T800 60"
                  fill="none"
                  stroke="white"
                  stroke-width="0.6"
                  opacity="0.1"
                />
              </svg>
            </div>

            <div class="absolute inset-0 bg-gradient-to-t from-black/30 via-transparent to-transparent" />

            <div class="absolute bottom-0 left-0 right-0 p-4 sm:p-6">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-white/20 backdrop-blur-md shadow-lg border border-white/30">
                  <.phx_icon
                    name="hero-book-open"
                    class="w-5 h-5 sm:w-6 sm:h-6 text-white drop-shadow-sm"
                  />
                </div>
                <div>
                  <h1 class="text-lg sm:text-xl font-semibold text-white drop-shadow-sm">
                    Timeline
                  </h1>
                  <p class="text-sm text-white/80 drop-shadow-sm">
                    Your private feed
                  </p>
                </div>
              </div>
            </div>
          </div>
      <% end %>
    </div>
    """
  end

  defp get_user_banner_image(nil), do: nil

  defp get_user_banner_image(user) do
    with %{connection: %{profile: %{banner_image: banner}}}
         when not is_nil(banner) and banner != :custom <- user do
      "#{banner}.jpg"
    else
      _ -> nil
    end
  rescue
    _ -> nil
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
      "hover:text-emerald-600 dark:hover:text-emerald-400",
      "[&.reply-expanded]:text-emerald-600 [&.reply-expanded]:dark:text-emerald-400",
      "[&.reply-expanded]:bg-emerald-50/50 [&.reply-expanded]:dark:bg-emerald-900/20"
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

  defp timeline_status_classes("active") do
    [
      "bg-blue-50/80 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300",
      "border-blue-200/60 dark:border-blue-700/60"
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

  defp timeline_status_classes("offline") do
    [
      "bg-slate-50/80 dark:bg-slate-800/20 text-slate-600 dark:text-slate-400",
      "border-slate-200/60 dark:border-slate-600/60"
    ]
  end

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

          <%!-- Custom message --%>
          <div
            :if={@message && String.trim(@message) != ""}
            class="text-sm text-slate-600 dark:text-slate-300 leading-relaxed"
            data-status-message-content="true"
          >
            {@message}
          </div>

          <%!-- Default message if no custom message --%>
          <div
            :if={!@message || String.trim(@message) == ""}
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

  slot :trigger, required: true

  slot :item do
    attr :color, :string, values: ~w(slate gray red emerald blue amber purple rose)
    attr :phx_click, :string
    attr :phx_value_id, :string
    attr :phx_value_post_id, :string
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
          placement_classes(@placement)
        ]}
        role="menu"
        aria-orientation="vertical"
      >
        <%!-- Liquid background effect --%>
        <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 opacity-50">
        </div>

        <div class="relative py-2 max-h-[12.5rem] overflow-y-auto">
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
            phx-value-post-id={item[:phx_value_post_id]}
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
  Shared users dropdown with profile links, remove functionality, and add user UI.
  """
  attr :post, :map, required: true
  attr :post_shared_users, :list, required: true
  attr :removing_shared_user_id, :string, default: nil
  attr :adding_shared_user, :map, default: nil

  def liquid_shared_users_dropdown(assigns) do
    ~H"""
    <div
      id={"post-shared-users-menu-#{@post.id}"}
      class="relative"
      phx-click-away={JS.hide(to: "#post-shared-users-menu-#{@post.id}-menu")}
    >
      <button
        type="button"
        phx-click={JS.toggle(to: "#post-shared-users-menu-#{@post.id}-menu")}
        class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100/50 dark:hover:bg-slate-700/50 transition-all duration-200 ease-out"
        id={"post-shared-users-menu-trigger-#{@post.id}"}
        phx-hook="TippyHook"
        data-tippy-content="Manage who you shared with"
      >
        <.liquid_badge variant="soft" color={visibility_badge_color(@post.visibility)} size="sm">
          {visibility_badge_text(@post.visibility)}
        </.liquid_badge>
      </button>

      <div
        id={"post-shared-users-menu-#{@post.id}-menu"}
        class={[
          "absolute z-[200] mt-2 w-72 origin-top-right hidden right-0",
          "rounded-xl border border-slate-200/60 dark:border-slate-700/60",
          "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
          "shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30",
          "ring-1 ring-slate-200/60 dark:ring-slate-700/60",
          "animate-in fade-in slide-in-from-top-2 duration-200"
        ]}
      >
        <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 opacity-50">
        </div>

        <div class="relative">
          <div class="px-4 py-3 border-b border-slate-200/60 dark:border-slate-700/60">
            <h4 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
              Shared with
            </h4>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              {length(@post.shared_users)} {if length(@post.shared_users) == 1,
                do: "person",
                else: "people"}
            </p>
          </div>

          <div class="max-h-[14rem] overflow-y-auto py-2">
            <div
              :for={shared_user <- @post.shared_users}
              :if={!Enum.empty?(@post.shared_users)}
              class="group"
            >
              <% shared_post_user = get_shared_connection(shared_user.user_id, @post_shared_users) %>
              <% is_removing = @removing_shared_user_id == shared_user.user_id %>
              <div class={[
                "flex items-center gap-3 px-2 py-1.5 transition-all duration-200",
                is_removing && "opacity-50 pointer-events-none"
              ]}>
                <%= if shared_post_user do %>
                  <.link
                    :if={show_profile?(shared_post_user)}
                    id={"profile-link-#{@post.id}-person-#{shared_user.user_id}"}
                    navigate={~p"/app/profile/#{shared_post_user.profile_slug}"}
                    phx-hook="TippyHook"
                    data-tippy-content="View profile"
                    class="flex items-center gap-3 flex-1 min-w-0 px-2 py-1.5 -mx-2 -my-1.5 rounded-lg hover:bg-slate-100/80 dark:hover:bg-slate-700/50 transition-all duration-200"
                  >
                    <div class={[
                      "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg",
                      "bg-gradient-to-br transition-all duration-200",
                      get_post_shared_user_classes(shared_post_user.color)
                    ]}>
                      <span class={[
                        "text-sm font-semibold",
                        get_post_shared_user_text_classes(shared_post_user.color)
                      ]}>
                        {String.first(shared_post_user.username || "?") |> String.upcase()}
                      </span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate block">
                        {shared_post_user.username}
                      </span>
                      <span class="text-xs text-slate-500 dark:text-slate-400">
                        Connection
                      </span>
                    </div>
                  </.link>
                  <div
                    :if={!show_profile?(shared_post_user)}
                    class="flex items-center gap-3 flex-1 min-w-0"
                  >
                    <div class={[
                      "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg",
                      "bg-gradient-to-br transition-all duration-200",
                      get_post_shared_user_classes(shared_post_user.color)
                    ]}>
                      <span class={[
                        "text-sm font-semibold",
                        get_post_shared_user_text_classes(shared_post_user.color)
                      ]}>
                        {String.first(shared_post_user.username || "?") |> String.upcase()}
                      </span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate block">
                        {shared_post_user.username}
                      </span>
                      <span class="text-xs text-slate-500 dark:text-slate-400">
                        Connection
                      </span>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_shared_user"
                    phx-value-post-id={@post.id}
                    phx-value-user-id={shared_user.user_id}
                    phx-value-shared-username={shared_post_user.username}
                    class="p-2 rounded-lg text-slate-400 dark:text-slate-500 hover:text-rose-600 dark:hover:text-rose-400 bg-slate-100/60 dark:bg-slate-700/40 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 shrink-0"
                    phx-hook="TippyHook"
                    data-tippy-content="Remove access"
                    id={"remove-access-#{@post.id}-person-#{shared_user.user_id}"}
                  >
                    <%= if is_removing do %>
                      <.phx_icon name="hero-arrow-path-mini" class="w-4 h-4 animate-spin" />
                    <% else %>
                      <.phx_icon name="hero-x-mark-mini" class="w-4 h-4" />
                    <% end %>
                  </button>
                <% else %>
                  <div class="flex items-center gap-3 flex-1 min-w-0">
                    <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-slate-200 dark:bg-slate-700">
                      <.phx_icon
                        name="hero-user-minus"
                        class="w-4 h-4 text-slate-400 dark:text-slate-500"
                      />
                    </div>
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-slate-500 dark:text-slate-400 truncate italic block">
                        Former connection
                      </span>
                      <span class="text-xs text-slate-400 dark:text-slate-500">
                        No longer connected
                      </span>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_shared_user"
                    phx-value-post-id={@post.id}
                    phx-value-user-id={shared_user.user_id}
                    phx-value-shared-username=""
                    class="p-2 rounded-lg text-slate-400 dark:text-slate-500 hover:text-rose-600 dark:hover:text-rose-400 bg-slate-100/60 dark:bg-slate-700/40 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-all duration-200 shrink-0"
                    title="Remove"
                  >
                    <%= if is_removing do %>
                      <.phx_icon name="hero-arrow-path-mini" class="w-4 h-4 animate-spin" />
                    <% else %>
                      <.phx_icon name="hero-x-mark-mini" class="w-4 h-4" />
                    <% end %>
                  </button>
                <% end %>
              </div>
            </div>

            <div :if={Enum.empty?(@post.shared_users)} class="px-4 py-6 text-center">
              <div class="inline-flex items-center justify-center w-12 h-12 mb-3 rounded-full bg-slate-100 dark:bg-slate-700">
                <.phx_icon name="hero-user-group" class="w-6 h-6 text-slate-400 dark:text-slate-500" />
              </div>
              <p class="text-sm text-slate-500 dark:text-slate-400">
                Not shared with anyone yet
              </p>
            </div>
          </div>

          <div class="px-4 py-3 border-t border-slate-200/60 dark:border-slate-700/60">
            <% available_connections =
              Enum.reject(@post_shared_users, fn psu ->
                Enum.any?(@post.shared_users, &(&1.user_id == psu.user_id))
              end) %>

            <%= if @adding_shared_user && @adding_shared_user.post_id == @post.id do %>
              <div class="flex items-center gap-2 p-2 rounded-lg bg-emerald-50 dark:bg-emerald-900/20 animate-pulse">
                <.phx_icon
                  name="hero-arrow-path"
                  class="w-4 h-4 text-emerald-600 dark:text-emerald-400 animate-spin"
                />
                <span class="text-sm text-emerald-700 dark:text-emerald-300">
                  Adding {@adding_shared_user.username}...
                </span>
              </div>
            <% else %>
              <%= if Enum.empty?(available_connections) do %>
                <p class="text-xs text-slate-400 dark:text-slate-500 text-center py-1">
                  All connections have access
                </p>
              <% else %>
                <div class="relative" id={"add-shared-user-#{@post.id}"}>
                  <button
                    type="button"
                    phx-click={JS.toggle(to: "#add-shared-user-list-#{@post.id}")}
                    class="w-full flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium text-emerald-600 dark:text-emerald-400 rounded-lg border border-dashed border-emerald-300 dark:border-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 transition-all duration-200"
                  >
                    <.phx_icon name="hero-plus-mini" class="w-4 h-4" /> Add someone
                  </button>

                  <div
                    id={"add-shared-user-list-#{@post.id}"}
                    phx-click-away={JS.hide(to: "#add-shared-user-list-#{@post.id}")}
                    phx-key="escape"
                    phx-window-keydown={JS.hide(to: "#add-shared-user-list-#{@post.id}")}
                    class="hidden absolute bottom-full left-0 right-0 mb-2 max-h-40 overflow-y-auto rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 shadow-lg animate-in fade-in slide-in-from-bottom-2 duration-150"
                  >
                    <div
                      :for={conn <- available_connections}
                      id={"add-shared-user-list-item-#{@post.id}-#{conn.user_id}"}
                      phx-click={
                        JS.hide(to: "#add-shared-user-list-#{@post.id}")
                        |> JS.push("add_shared_user")
                      }
                      phx-value-post-id={@post.id}
                      phx-value-user-id={conn.user_id}
                      phx-value-username={conn.username}
                      class={[
                        "flex items-center gap-3 px-3 py-2 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors duration-150",
                        @adding_shared_user && @adding_shared_user.post_id == @post.id &&
                          @adding_shared_user.username == conn.username &&
                          "opacity-50 pointer-events-none"
                      ]}
                    >
                      <%= if @adding_shared_user && @adding_shared_user.post_id == @post.id && @adding_shared_user.username == conn.username do %>
                        <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-emerald-100 dark:bg-emerald-900/30">
                          <.phx_icon
                            name="hero-arrow-path"
                            class="w-4 h-4 text-emerald-600 dark:text-emerald-400 animate-spin"
                          />
                        </div>
                        <span class="text-sm text-emerald-600 dark:text-emerald-400">
                          Adding...
                        </span>
                      <% else %>
                        <div class={[
                          "flex h-7 w-7 shrink-0 items-center justify-center rounded-md",
                          "bg-gradient-to-br",
                          get_post_shared_user_classes(conn.color)
                        ]}>
                          <span class={[
                            "text-xs font-semibold",
                            get_post_shared_user_text_classes(conn.color)
                          ]}>
                            {String.first(conn.username || "?") |> String.upcase()}
                          </span>
                        </div>
                        <span class="text-sm text-slate-700 dark:text-slate-300 truncate">
                          {conn.username}
                        </span>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Collapsible reply thread display component.

  ## Examples

      <.liquid_collapsible_reply_thread
        post_id={@post.id}
        replies={@post.replies || []}
        reply_count={Map.get(@stats, :replies, 0)}
        show={true}
        current_scope={@current_scope}
        class="mt-3"
      />
  """
  attr :post_id, :string, required: true
  attr :replies, :list, default: []
  attr :show, :boolean, default: false
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :reply_count, :integer, default: 0
  attr :unread_nested_replies_by_parent, :map, default: %{}
  attr :calm_notifications, :boolean, default: false
  attr :class, :any, default: ""

  def liquid_collapsible_reply_thread(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <div
      id={"reply-thread-#{@post_id}"}
      data-show-js={
        JS.show(
          to: "#reply-thread-#{@post_id}",
          transition: {"nested-reply-expand-enter", "", ""},
          time: 300
        )
      }
      class={[
        "hidden",
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
          <div
            :for={reply <- filter_top_level_replies(@replies)}
            class="reply-item relative"
            data-user-id={reply.user_id}
          >
            <%!-- Individual reply connection --%>
            <div class="absolute -left-4 sm:-left-6 top-6 w-3 sm:w-4 h-px bg-gradient-to-r from-emerald-300/60 to-transparent dark:from-emerald-400/60">
            </div>

            <.liquid_nested_reply_item
              reply={reply}
              current_scope={@current_scope}
              depth={0}
              max_depth={3}
              post_id={@post_id}
              unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
              calm_notifications={@calm_notifications}
            />
          </div>

          <%!-- Load more replies if needed --%>
          <div :if={@reply_count > count_loaded_replies(@replies)} class="pt-2">
            <.liquid_button
              variant="ghost"
              size="sm"
              color="emerald"
              phx-click="load_more_replies"
              phx-value-post-id={@post_id}
              class="text-emerald-600 dark:text-emerald-400"
            >
              Load {min(@reply_count - count_loaded_replies(@replies), 5)} more replies
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
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 3
  attr :post_id, :string, default: nil
  attr :unread_nested_replies_by_parent, :map, default: %{}
  attr :calm_notifications, :boolean, default: false
  attr :class, :any, default: ""

  def liquid_nested_reply_item(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <div class={[
      "nested-reply-container",
      @class
    ]}>
      <%!-- Render the current reply --%>
      <.liquid_reply_item
        reply={@reply}
        current_scope={@current_scope}
        depth={@depth}
        post_id={@post_id}
      />

      <%!-- Collapse/Expand toggle for nested replies --%>
      <div :if={@depth < @max_depth and has_child_replies?(@reply)} class="mt-2">
        <button
          type="button"
          id={"nested-toggle-#{@reply.id}"}
          phx-click={
            toggle_nested_replies(
              @reply.id,
              @post_id,
              if(@calm_notifications,
                do: Map.get(@unread_nested_replies_by_parent, @reply.id, 0),
                else: 0
              )
            )
          }
          phx-click-away-mark-read={
            if @calm_notifications && Map.get(@unread_nested_replies_by_parent, @reply.id, 0) > 0,
              do: "mark_nested_replies_read"
          }
          phx-value-reply-id={@reply.id}
          phx-value-post-id={@post_id}
          class="group flex items-center gap-1.5 text-xs font-medium text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors duration-200"
          aria-expanded="false"
          aria-controls={"nested-children-#{@reply.id}"}
        >
          <span
            id={"collapse-indicator-#{@reply.id}"}
            class={[
              "flex items-center justify-center w-5 h-5 rounded-full transition-colors duration-200",
              if(@calm_notifications && Map.get(@unread_nested_replies_by_parent, @reply.id, 0) > 0,
                do: "bg-emerald-500 text-white",
                else:
                  "bg-slate-100 dark:bg-slate-700/50 group-hover:bg-emerald-100 dark:group-hover:bg-emerald-900/30"
              )
            ]}
          >
            <.phx_icon
              name="hero-chevron-down"
              class={[
                "w-3 h-3 transition-transform duration-200 -rotate-90",
                @calm_notifications && Map.get(@unread_nested_replies_by_parent, @reply.id, 0) > 0 &&
                  "hidden"
              ]}
              id={"collapse-icon-#{@reply.id}"}
            />
            <span
              id={"unread-badge-#{@reply.id}"}
              class={[
                "text-[10px] font-bold",
                (!@calm_notifications || Map.get(@unread_nested_replies_by_parent, @reply.id, 0) == 0) &&
                  "hidden"
              ]}
            >
              {Map.get(@unread_nested_replies_by_parent, @reply.id, 0)}
            </span>
          </span>
          <span id={"collapse-text-#{@reply.id}"} class="hidden">
            Hide {length(get_child_replies(@reply))} {if length(get_child_replies(@reply)) == 1,
              do: "reply",
              else: "replies"}
          </span>
          <span id={"expand-text-#{@reply.id}"}>
            <span
              id={"expand-unread-text-#{@reply.id}"}
              class={[
                (!@calm_notifications || Map.get(@unread_nested_replies_by_parent, @reply.id, 0) == 0) &&
                  "hidden"
              ]}
            >
              {Map.get(@unread_nested_replies_by_parent, @reply.id, 0)} new
            </span>
            <span
              id={"expand-normal-text-#{@reply.id}"}
              class={[
                @calm_notifications && Map.get(@unread_nested_replies_by_parent, @reply.id, 0) > 0 &&
                  "hidden"
              ]}
            >
              Show {length(get_child_replies(@reply))}
            </span>
            {if length(get_child_replies(@reply)) == 1, do: "reply", else: "replies"}
          </span>
        </button>
      </div>

      <%!-- Render nested child replies with improved visual hierarchy --%>
      <div
        :if={@depth < @max_depth and has_child_replies?(@reply)}
        id={"nested-children-#{@reply.id}"}
        class={[
          "nested-children mt-3 relative overflow-hidden transition-all duration-300 ease-out hidden",
          if(@depth == 0, do: "ml-6 sm:ml-8", else: "ml-4 sm:ml-6"),
          "border-l-2 border-emerald-200/40 dark:border-emerald-700/40 pl-4 sm:pl-6"
        ]}
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
              current_scope={@current_scope}
              depth={@depth + 1}
              max_depth={@max_depth}
              post_id={@post_id}
              unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
              calm_notifications={@calm_notifications}
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
          phx-click="expand_nested_replies"
          phx-value-reply-id={@reply.id}
          phx-value-post-id={@post_id}
          class="text-xs text-emerald-600 dark:text-emerald-400"
        >
          View {length(get_child_replies(@reply))} more replies
        </.liquid_button>
      </div>

      <%!-- Nested reply composer LiveComponent (hidden by default, toggled by JS) --%>
      <div
        :if={@current_scope.user}
        id={"nested-composer-#{@reply.id}"}
        class="ml-4 sm:ml-6 mt-3 hidden"
        data-hide-js={
          JS.hide(
            to: "#nested-composer-#{@reply.id}",
            transition: {"nested-reply-expand-leave", "", ""},
            time: 300
          )
          |> JS.remove_class("text-emerald-600 dark:text-emerald-400",
            to: "#reply-button-#{@reply.id}"
          )
          |> JS.set_attribute({"data-composer-open", "false"},
            to: "#reply-button-#{@reply.id}"
          )
        }
      >
        <.live_component
          module={MossletWeb.TimelineLive.NestedReplyComposerComponent}
          id={"nested-composer-component-#{@reply.id}"}
          parent_reply={@reply}
          post_id={@post_id}
          current_scope={@current_scope}
          author_name={get_safe_reply_author_name(@reply, @current_scope.user, @current_scope.key)}
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
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :depth, :integer, default: 0
  attr :post_id, :string, default: nil
  attr :class, :any, default: ""

  def liquid_reply_item(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <div class={[
      "relative rounded-xl transition-all duration-200 ease-out",
      reply_background_classes(@depth),
      reply_border_classes(@depth),
      reply_hover_classes(@depth),
      "shadow-sm hover:shadow-md dark:shadow-slate-900/20",
      @class
    ]}>
      <%!-- Depth-aware reply accent (top bar) --%>
      <div class={[
        "absolute left-3 right-3 top-0 rounded-b-full",
        reply_top_accent_classes(@depth)
      ]}>
      </div>

      <div class={[
        "p-4 sm:p-4",
        reply_padding_classes(@depth)
      ]}>
        <div class="flex items-start gap-3">
          <%!-- Reply author avatar (small) - conditionally linked to author profile --%>
          <.link
            :if={
              show_author_profile?(
                get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key),
                get_reply_author_profile_visibility(@reply, @current_scope.user)
              )
            }
            navigate={
              ~p"/app/profile/#{get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key)}"
            }
            class="flex-shrink-0"
          >
            <.liquid_avatar
              id={"liquid-avatar-#{@post_id}-#{@reply.id}-#{@current_scope.user.id}"}
              src={get_reply_author_avatar(@reply, @current_scope.user, @current_scope.key)}
              name={get_safe_reply_author_name(@reply, @current_scope.user, @current_scope.key)}
              status={get_reply_author_status(@reply, @current_scope.user, @current_scope.key)}
              status_message={
                get_reply_author_status_message(@reply, @current_scope.user, @current_scope.key)
              }
              show_status={
                get_reply_author_show_status(@reply, @current_scope.user, @current_scope.key)
              }
              user_id={@reply.user_id}
              size="sm"
              clickable={true}
              class="mt-0.5"
            />
          </.link>
          <.liquid_avatar
            :if={
              !show_author_profile?(
                get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key),
                get_reply_author_profile_visibility(@reply, @current_scope.user)
              )
            }
            id={"liquid-avatar-#{@post_id}-#{@reply.id}-#{@current_scope.user.id}"}
            src={get_reply_author_avatar(@reply, @current_scope.user, @current_scope.key)}
            name={get_safe_reply_author_name(@reply, @current_scope.user, @current_scope.key)}
            status={get_reply_author_status(@reply, @current_scope.user, @current_scope.key)}
            status_message={
              get_reply_author_status_message(@reply, @current_scope.user, @current_scope.key)
            }
            show_status={
              get_reply_author_show_status(@reply, @current_scope.user, @current_scope.key)
            }
            user_id={@reply.user_id}
            size="sm"
            class="flex-shrink-0 mt-0.5"
          />

          <div class="flex-1 min-w-0">
            <%!-- Reply header - author name also linked when profile is viewable --%>
            <div class="flex items-center gap-2 mb-2">
              <.link
                :if={
                  show_author_profile?(
                    get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key),
                    get_reply_author_profile_visibility(@reply, @current_scope.user)
                  )
                }
                navigate={
                  ~p"/app/profile/#{get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key)}"
                }
                class="text-sm font-semibold text-slate-900 dark:text-slate-100 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
              >
                {get_safe_reply_author_name(@reply, @current_scope.user, @current_scope.key)}
              </.link>
              <span
                :if={
                  !show_author_profile?(
                    get_reply_author_profile_slug(@reply, @current_scope.user, @current_scope.key),
                    get_reply_author_profile_visibility(@reply, @current_scope.user)
                  )
                }
                class="text-sm font-semibold text-slate-900 dark:text-slate-100"
              >
                {get_safe_reply_author_name(@reply, @current_scope.user, @current_scope.key)}
              </span>
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {format_reply_timestamp(@reply.inserted_at)}
              </span>
            </div>

            <%!-- Reply content with markdown support --%>
            <div class="prose prose-slate dark:prose-invert prose-sm max-w-none prose-p:my-1 prose-headings:mt-2 prose-headings:mb-1 prose-ul:my-1 prose-ol:my-1 prose-li:my-0.5 prose-pre:my-1.5 prose-code:text-emerald-600 dark:prose-code:text-emerald-400 prose-a:text-emerald-600 dark:prose-a:text-emerald-400 prose-a:no-underline hover:prose-a:underline">
              {format_decrypted_content(
                get_decrypted_reply_content(@reply, @current_scope.user, @current_scope.key)
              )}
            </div>

            <%!-- Reply actions (mobile-optimized) - only show for connected users or own replies --%>
            <div class="flex items-center justify-between mt-3 sm:mt-2">
              <div class="flex items-center gap-3 sm:gap-4">
                <.liquid_timeline_action
                  :if={can_interact_with_reply?(@reply, @current_scope.user)}
                  id={
                    if @current_scope.user.id in @reply.favs_list,
                      do: "hero-heart-solid-reply-button-#{@reply.id}",
                      else: "hero-heart-reply-button-#{@reply.id}"
                  }
                  icon_id={
                    if @current_scope.user.id in @reply.favs_list,
                      do: "hero-heart-solid-reply-icon-#{@reply.id}",
                      else: "hero-heart-reply-icon-#{@reply.id}"
                  }
                  icon={
                    if @current_scope.user.id in @reply.favs_list,
                      do: "hero-heart-solid",
                      else: "hero-heart"
                  }
                  count={@reply.favs_count}
                  label={if @current_scope.user.id in @reply.favs_list, do: "Unlike", else: "Love"}
                  color="rose"
                  active={@current_scope.user.id in @reply.favs_list}
                  reply_id={@reply.id}
                  phx-click={
                    if @current_scope.user.id in @reply.favs_list,
                      do: "unfav_reply",
                      else: "fav_reply"
                  }
                  phx-value-id={@reply.id}
                  phx-hook="TippyHook"
                  data-tippy-content={
                    if @current_scope.user.id in @reply.favs_list,
                      do: "Remove love",
                      else: "Show love"
                  }
                  class="text-xs sm:scale-75 sm:origin-left min-h-[44px] sm:min-h-0"
                />
                <button
                  :if={can_interact_with_reply?(@reply, @current_scope.user)}
                  id={"reply-button-#{@reply.id}"}
                  phx-click={
                    JS.toggle(
                      to: "#nested-composer-#{@reply.id}",
                      in: {"nested-reply-expand-enter", "", ""},
                      out: {"nested-reply-expand-leave", "", ""},
                      time: 300
                    )
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
                  can_manage_reply?(@reply, @current_scope.user, @post_id) or
                    can_moderate_reply?(@reply, @current_scope.user)
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
                      can_moderate_reply?(@reply, @current_scope.user) and
                        @reply.user_id != @current_scope.user.id
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
                      can_moderate_reply?(@reply, @current_scope.user) and
                        @reply.user_id != @current_scope.user.id
                    }
                    color="rose"
                    phx_click="block_user_from_reply"
                    phx_value_id={@reply.user_id}
                    phx_value_user_name={
                      get_safe_reply_author_name(@reply, @current_scope.user, @current_scope.key)
                    }
                    phx_value_reply_id={@reply.id}
                  >
                    <.phx_icon name="hero-no-symbol" class="h-4 w-4" />
                    <span>Block Author</span>
                  </:item>

                  <%!-- Delete option for reply owner or post owner --%>
                  <:item
                    :if={can_manage_reply?(@reply, @current_scope.user, @post_id)}
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

  # Helper function for mapping post.shared_users (user_ids) to list of post_shared_users
  # returns the matching %Post.SharedUser{} mapped from current_user's user_connections
  # in handle_params of our timline index
  def get_shared_connection(user_id, post_shared_users_list) do
    Enum.find(post_shared_users_list, nil, fn post_shared_user ->
      post_shared_user.user_id === user_id
    end)
  end

  def show_profile?(shared_post_user) do
    shared_post_user.profile_slug &&
      shared_post_user.profile_visibility in [:connections, :public]
  end

  def show_author_profile?(author_profile_slug, author_profile_visibility) do
    author_profile_slug &&
      author_profile_visibility in [:connections, :public]
  end

  def connection_has_user_post?(post_id, user_id) do
    case get_user_post_for_user_id(post_id, user_id) do
      %Timeline.UserPost{} = _user_post -> true
      _rest -> false
    end
  end

  defp get_user_post_for_user_id(post_id, user_id) do
    Timeline.get_user_post_by_post_id_and_user_id(post_id, user_id)
  end

  defp get_reply_author_avatar(reply, current_user, key) do
    cond do
      reply.user_id == current_user.id ->
        if show_avatar?(current_user),
          do: maybe_get_user_avatar(current_user, key) || "/images/logo.svg",
          else: "/images/logo.svg"

      not is_connected_to_reply_author?(reply, current_user) ->
        "/images/logo.svg"

      true ->
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
    cond do
      reply.user_id == current_user.id ->
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

      not is_connected_to_reply_author?(reply, current_user) ->
        "[Reply from non-connected user]"

      true ->
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
  end

  # Helper function to get the reply author's status if visible to current user
  # Similar to get_post_author_status but for replies
  def get_reply_author_status(reply, current_user, key) do
    case Accounts.get_user_with_preloads(reply.user_id) do
      %{} = reply_author ->
        case get_user_status_info(reply_author, current_user, key) do
          %{status: status} when is_binary(status) -> status
          _ -> "offline"
        end

      nil ->
        # User account not found
        "offline"
    end
  end

  # Helper function to get the reply author's status message if visible to current user
  # Similar to get_post_author_status_message but for replies
  def get_reply_author_status_message(reply, current_user, key) do
    case Accounts.get_user_with_preloads(reply.user_id) do
      %{} = reply_author ->
        get_user_status_message(reply_author, current_user, key)

      nil ->
        # User account not found
        nil
    end
  end

  def get_reply_author_show_status(reply, current_user, key) do
    case Accounts.get_user_with_preloads(reply.user_id) do
      %{} = reply_author ->
        MossletWeb.Helpers.StatusHelpers.can_view_status?(reply_author, current_user, key)

      nil ->
        false
    end
  end

  def get_reply_author_profile_slug(reply, current_user, _key) do
    cond do
      reply.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{slug: slug}} when is_binary(slug) -> slug
          _ -> nil
        end

      not is_connected_to_reply_author?(reply, current_user) ->
        nil

      true ->
        case Accounts.get_user_with_preloads(reply.user_id) do
          %{connection: %{profile: %{slug: slug}}} when is_binary(slug) -> slug
          _ -> nil
        end
    end
  end

  def get_reply_author_profile_visibility(reply, current_user) do
    cond do
      reply.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{visibility: visibility}} -> visibility
          _ -> nil
        end

      not is_connected_to_reply_author?(reply, current_user) ->
        nil

      true ->
        case Accounts.get_user_with_preloads(reply.user_id) do
          %{connection: %{profile: %{visibility: visibility}}} -> visibility
          _ -> nil
        end
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

  # Helper function to check if user can interact with a reply (fav/reply)
  # User can interact if they are the reply author OR connected to the reply author
  defp can_interact_with_reply?(reply, current_user) do
    reply.user_id == current_user.id or is_connected_to_reply_author?(reply, current_user)
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
          relative_time < 3_600 -> "#{div(relative_time, 60)}m"
          relative_time < 86_400 -> "#{div(relative_time, 3_600)}h"
          relative_time < 2_592_000 -> "#{div(relative_time, 86_400)}d"
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

  defp reply_top_accent_classes(depth) do
    case depth do
      0 ->
        "h-1 bg-gradient-to-r from-emerald-400/80 via-teal-400/60 to-emerald-300/40 dark:from-emerald-500/80 dark:via-teal-500/60 dark:to-emerald-400/40"

      1 ->
        "h-0.5 bg-gradient-to-r from-teal-400/70 via-emerald-400/50 to-teal-300/30 dark:from-teal-500/70 dark:via-emerald-500/50 dark:to-teal-400/30"

      2 ->
        "h-0.5 bg-gradient-to-r from-cyan-400/60 via-teal-400/40 to-cyan-300/20 dark:from-cyan-500/60 dark:via-teal-500/40 dark:to-cyan-400/20"

      _ ->
        "h-px bg-gradient-to-r from-slate-400/50 via-slate-300/30 to-transparent dark:from-slate-500/50 dark:via-slate-400/30"
    end
  end

  defp reply_padding_classes(depth) do
    case depth do
      0 -> "pt-5 sm:pt-6"
      1 -> "pt-4 sm:pt-5"
      2 -> "pt-3 sm:pt-4"
      _ -> "pt-2 sm:pt-3"
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
      list when is_list(list) -> list != []
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

  defp toggle_reply_section(post_id, mark_replies_read?) do
    js =
      JS.toggle(
        to: "#reply-composer-#{post_id}",
        in: {"nested-reply-expand-enter", "", ""},
        out: {"nested-reply-expand-leave", "", ""},
        time: 300
      )
      |> JS.toggle(
        to: "#reply-thread-#{post_id}",
        in: {"nested-reply-expand-enter", "", ""},
        out: {"nested-reply-expand-leave", "", ""},
        time: 300
      )
      |> JS.toggle_class("ring-2 ring-emerald-300", to: "#timeline-card-#{post_id}")
      |> JS.toggle_class("reply-expanded", to: "#reply-button-#{post_id}")
      |> JS.toggle_attribute({"data-expanded", "true", "false"}, to: "#reply-button-#{post_id}")

    if mark_replies_read? do
      js
      |> JS.push("mark_replies_read", value: %{post_id: post_id})
    else
      js
    end
  end

  defp toggle_nested_replies(reply_id, post_id, unread_count) do
    js =
      JS.toggle(
        to: "#nested-children-#{reply_id}",
        in: {"nested-reply-expand-enter", "", ""},
        out: {"nested-reply-expand-leave", "", ""},
        time: 300
      )
      |> JS.toggle_class("hidden", to: "#collapse-text-#{reply_id}")
      |> JS.toggle_class("hidden", to: "#expand-text-#{reply_id}")
      |> JS.toggle_class("-rotate-90", to: "#collapse-icon-#{reply_id}")
      |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#nested-toggle-#{reply_id}")

    js =
      if unread_count > 0 do
        js
        |> JS.hide(to: "#unread-badge-#{reply_id}")
        |> JS.show(to: "#collapse-icon-#{reply_id}")
        |> JS.remove_class("bg-emerald-500 text-white",
          to: "#collapse-indicator-#{reply_id}"
        )
        |> JS.add_class(
          "bg-slate-100 dark:bg-slate-700/50 group-hover:bg-emerald-100 dark:group-hover:bg-emerald-900/30",
          to: "#collapse-indicator-#{reply_id}"
        )
        |> JS.hide(to: "#expand-unread-text-#{reply_id}")
        |> JS.show(to: "#expand-normal-text-#{reply_id}")
        |> JS.push("mark_nested_replies_read",
          value: %{reply_id: reply_id, post_id: post_id, unread_count: unread_count}
        )
        |> JS.dispatch("mosslet:decrement-badge",
          to: "#notification-badge-reply-button-#{post_id}",
          detail: %{decrement: unread_count}
        )
      else
        js
      end

    js
  end

  defp count_loaded_replies(replies) when is_list(replies) do
    Enum.reduce(replies, 0, fn reply, acc ->
      child_count = count_loaded_replies(get_child_replies(reply))
      acc + 1 + child_count
    end)
  end

  defp count_loaded_replies(_), do: 0

  @doc """
  Nested reply composer for replying to specific replies
  """
  attr :form, :map, required: true
  attr :parent_reply, :map, required: true
  attr :post, :map, required: true
  attr :author_name, :string, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :current_user, :map, required: true, doc: "deprecated: use current_scope instead"
  attr :class, :any, default: ""

  def liquid_nested_reply_composer(assigns) do
    assigns = assign_scope_fields(assigns)

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
            <span>Reply inherits post's visibility</span>
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
  Compact liquid filter select for admin interfaces.
  Follows the same liquid metal design patterns as liquid_select but optimized for filter forms.
  """
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :options, :list, required: true
  attr :label, :string, default: nil
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_filter_select(assigns) do
    assigns = assign_new(assigns, :id, fn -> assigns.name end)

    ~H"""
    <div class={["group relative", @class]}>
      <label :if={@label} for={@id} class="sr-only">{@label}</label>
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
        id={@id}
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
          "appearance-none cursor-pointer bg-none",
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
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :current_user, :any, default: nil, doc: "deprecated: use current_scope instead"
  attr :key, :any, default: nil, doc: "deprecated: use current_scope instead"
  attr :class, :any, default: ""

  def liquid_enhanced_privacy_controls(assigns) do
    assigns = assign_scope_fields(assigns)
    # Get visibility groups from current user if available
    visibility_groups =
      if is_map_key(assigns, :current_user) and is_map_key(assigns, :key) do
        Mosslet.Accounts.get_user_visibility_groups_with_connections(assigns.current_user)
      else
        []
      end

    # Get connections for specific user selection if available
    user_connections =
      if is_map_key(assigns, :current_user) do
        Mosslet.Accounts.filter_user_connections(%{}, assigns.current_user)
      else
        []
      end

    assigns =
      assign(assigns, visibility_groups: visibility_groups, user_connections: user_connections)

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
          <p class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Who can see this?
          </p>

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

          <%!-- Advanced granular options (Level 3) --%>
          <div class="pt-2 border-t border-emerald-200/60 dark:border-emerald-700/30">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <%!-- Specific Groups Option --%>
              <.liquid_privacy_radio_option
                name="visibility"
                value="specific_groups"
                current_value={@selector}
                icon="hero-squares-2x2"
                label="Specific Groups"
                description="Select groups"
              />

              <%!-- Specific Users Option --%>
              <.liquid_privacy_radio_option
                name="visibility"
                value="specific_users"
                current_value={@selector}
                icon="hero-user-plus"
                label="Specific People"
                description="Select individuals"
              />
            </div>

            <%!-- Group/User selection UI (when specific visibility is selected) --%>
            <div :if={@selector in ["specific_groups", "specific_users"]} class="mt-4">
              <%= if @selector == "specific_groups" do %>
                <%!-- Group selection interface with purple theme (groups = organization) --%>
                <div class="p-4 rounded-xl bg-gradient-to-br from-purple-50/80 via-violet-50/60 to-purple-50/80 dark:from-purple-900/25 dark:via-violet-900/20 dark:to-purple-900/25 border border-purple-200/60 dark:border-purple-700/40 shadow-sm shadow-purple-500/10 dark:shadow-purple-400/15">
                  <div class="flex items-center gap-3 mb-4">
                    <div class="p-2 rounded-lg bg-purple-100/80 dark:bg-purple-800/40 border border-purple-200/60 dark:border-purple-700/50">
                      <.phx_icon
                        name="hero-squares-2x2"
                        class="h-5 w-5 text-purple-600 dark:text-purple-400"
                      />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-purple-800 dark:text-purple-200">
                        Select Connection Groups
                      </p>
                      <p class="text-xs text-purple-600 dark:text-purple-400">
                        Share with organized groups of your connections
                      </p>
                    </div>
                  </div>
                  <div class="space-y-3">
                    <p class="text-sm text-purple-700 dark:text-purple-300 leading-relaxed">
                      Choose which of your connection groups can see this post. Groups help organize your connections by context like work colleagues, family members, or friend circles.
                    </p>
                    <%!-- Real group selection UI --%>
                    <%= if @visibility_groups != [] do %>
                      <div class="space-y-3">
                        <%= for group_data <- @visibility_groups do %>
                          <% group = group_data.group %>
                          <% decrypted_name =
                            get_decrypted_group_name(group_data, @current_user, @key) %>
                          <% decrypted_description =
                            get_decrypted_group_description(group_data, @current_user, @key) %>
                          <% connection_count = length(group_data.group.connection_ids || []) %>

                          <label class={[
                            "flex items-start gap-3 p-3 rounded-lg border transition-all duration-200 cursor-pointer",
                            get_group_card_classes(group.color)
                          ]}>
                            <input
                              type="checkbox"
                              name="post[visibility_groups][]"
                              value={group.id}
                              checked={group.id in (@form[:visibility_groups].value || [])}
                              class={[
                                "mt-1 h-4 w-4 rounded focus:ring-2 focus:ring-offset-2",
                                "text-#{connection_badge_color(group.color)}-600",
                                "focus:ring-#{connection_badge_color(group.color)}-500",
                                "border-#{connection_badge_color(group.color)}-300"
                              ]}
                            />
                            <div class="flex-1 min-w-0">
                              <div class="flex items-center gap-2 mb-1">
                                <!-- Group color indicator - preserve the user's chosen color -->
                                <div class={[
                                  "w-3 h-3 rounded-full flex-shrink-0",
                                  get_group_color_indicator_classes(group.color)
                                ]}>
                                </div>
                                <h5 class={[
                                  "text-sm font-medium truncate",
                                  "text-#{connection_badge_color(group.color)}-800 dark:text-#{connection_badge_color(group.color)}-200"
                                ]}>
                                  {decrypted_name}
                                </h5>
                                <!-- Group badge with group colors -->
                                <span class={[
                                  "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0",
                                  get_group_badge_classes(group.color)
                                ]}>
                                  {connection_count} {if connection_count == 1,
                                    do: "person",
                                    else: "people"}
                                </span>
                              </div>
                              <%= if decrypted_description != "" do %>
                                <p class={[
                                  "text-xs leading-relaxed",
                                  "text-#{connection_badge_color(group.color)}-600 dark:text-#{connection_badge_color(group.color)}-400"
                                ]}>
                                  {decrypted_description}
                                </p>
                              <% end %>
                            </div>
                          </label>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="p-3 rounded-lg bg-purple-100/50 dark:bg-purple-800/30 border border-purple-200/60 dark:border-purple-700/40">
                        <div class="flex items-center gap-2 mb-2">
                          <.phx_icon
                            name="hero-plus-circle"
                            class="h-4 w-4 text-purple-600 dark:text-purple-400"
                          />
                          <span class="text-sm font-medium text-purple-700 dark:text-purple-300">
                            No Groups Created
                          </span>
                        </div>
                        <p class="text-sm text-purple-600 dark:text-purple-400 mb-3">
                          Create connection groups to organize your network and share with specific groups.
                        </p>
                        <a
                          href="/app/users/connections"
                          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 bg-purple-600 text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500/20"
                        >
                          <.phx_icon name="hero-plus" class="h-4 w-4" /> Create Groups
                        </a>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <%!-- User selection interface with amber theme (specific people = selective/exclusive) --%>
                <div class="p-4 rounded-xl bg-gradient-to-br from-amber-50/80 via-orange-50/60 to-amber-50/80 dark:from-amber-900/25 dark:via-orange-900/20 dark:to-amber-900/25 border border-amber-200/60 dark:border-amber-700/40 shadow-sm shadow-amber-500/10 dark:shadow-amber-400/15">
                  <div class="flex items-center gap-3 mb-4">
                    <div class="p-2 rounded-lg bg-amber-100/80 dark:bg-amber-800/40 border border-amber-200/60 dark:border-amber-700/50">
                      <.phx_icon
                        name="hero-user-plus"
                        class="h-5 w-5 text-amber-600 dark:text-amber-400"
                      />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-amber-800 dark:text-amber-200">
                        Select Specific People
                      </p>
                      <p class="text-xs text-amber-600 dark:text-amber-400">
                        Share with carefully chosen individuals
                      </p>
                    </div>
                  </div>
                  <div class="space-y-3">
                    <p class="text-sm text-amber-700 dark:text-amber-300 leading-relaxed">
                      Choose specific individuals from your connections who can see this post. Perfect for sharing personal content with just a select few people you trust.
                    </p>
                    <%!-- Real user selection UI --%>
                    <%= if @user_connections != [] do %>
                      <div class="space-y-3">
                        <div class="max-h-48 overflow-y-auto space-y-2">
                          <%= for connection <- @user_connections do %>
                            <% decrypted_name =
                              get_decrypted_connection_name(connection, @current_user, @key) %>
                            <% decrypted_username =
                              get_decrypted_connection_username(connection, @current_user, @key) %>
                            <% decrypted_label =
                              get_decrypted_connection_label(connection, @current_user, @key) %>

                            <label class="flex items-center gap-3 p-3 rounded-lg border transition-all duration-200 cursor-pointer hover:bg-amber-50/50 dark:hover:bg-amber-900/30 border-amber-200/60 dark:border-amber-700/50">
                              <input
                                type="checkbox"
                                name="post[visibility_users][]"
                                value={get_connection_other_user_id(connection, @current_user)}
                                checked={
                                  get_connection_other_user_id(connection, @current_user) in (@form[
                                                                                                :visibility_users
                                                                                              ].value ||
                                                                                                [])
                                }
                                class="h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 rounded"
                              />
                              <div class="flex-shrink-0">
                                <img
                                  src={get_connection_avatar_src(connection, @current_user, @key)}
                                  alt={decrypted_name}
                                  class="w-8 h-8 rounded-full border border-amber-200 dark:border-amber-700"
                                />
                              </div>
                              <div class="flex-1 min-w-0">
                                <div class="flex flex-col">
                                  <div class="flex items-center gap-2">
                                    <span class="text-sm font-medium text-amber-800 dark:text-amber-200 truncate">
                                      {decrypted_name}
                                    </span>
                                    <%= if decrypted_label != "" do %>
                                      <span class={[
                                        "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0",
                                        get_connection_color_badge_classes(connection.color)
                                      ]}>
                                        {decrypted_label}
                                      </span>
                                    <% end %>
                                  </div>
                                  <%= if decrypted_username && decrypted_username != "" do %>
                                    <span class={[
                                      "text-xs truncate",
                                      connection_username_color_classes(connection.color)
                                    ]}>
                                      @{decrypted_username}
                                    </span>
                                  <% end %>
                                </div>
                              </div>
                            </label>
                          <% end %>
                        </div>
                      </div>
                    <% else %>
                      <div class="p-3 rounded-lg bg-amber-100/50 dark:bg-amber-800/30 border border-amber-200/60 dark:border-amber-700/40">
                        <div class="flex items-center gap-2 mb-2">
                          <.phx_icon
                            name="hero-user-plus"
                            class="h-4 w-4 text-amber-600 dark:text-amber-400"
                          />
                          <span class="text-sm font-medium text-amber-700 dark:text-amber-300">
                            No Connections
                          </span>
                        </div>
                        <p class="text-sm text-amber-600 dark:text-amber-400 mb-3">
                          Connect with other users to share posts with specific people.
                        </p>
                        <a
                          href="/app/users/connections"
                          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-200 bg-amber-600 text-white hover:bg-amber-700 focus:outline-none focus:ring-2 focus:ring-amber-500/20"
                        >
                          <.phx_icon name="hero-plus" class="h-4 w-4" /> Find Connections
                        </a>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Interaction Controls (Level 2) --%>
        <div class="space-y-3">
          <p class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Interaction Controls
          </p>

          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <%!-- Allow Replies --%>
            <.liquid_checkbox
              field={@form[:allow_replies]}
              label="Replies"
              help="Others can reply"
            />

            <%!-- Allow Shares --%>
            <.liquid_checkbox
              :if={@form[:is_ephemeral].value == false or @form[:is_ephemeral].value == "false"}
              field={@form[:allow_shares]}
              label="Sharing"
              help="Others can repost"
            />

            <%!-- Allow Bookmarks (with warning for ephemeral posts) --%>
            <div class="space-y-2">
              <.liquid_checkbox
                field={@form[:allow_bookmarks]}
                label="Bookmarks"
                help="Others can save"
              />

              <%!-- Educational note for ephemeral + bookmarks --%>
              <div
                :if={
                  (@form[:is_ephemeral].value == true or @form[:is_ephemeral].value == "true") and
                    (@form[:allow_bookmarks].value == true or @form[:allow_bookmarks].value == "true")
                }
                class="ml-6 p-2 rounded-lg bg-amber-50/50 dark:bg-amber-900/20 border border-amber-200/60 dark:border-amber-700/30"
              >
                <div class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-information-circle"
                    class="h-3 w-3 text-amber-600 dark:text-amber-400 mt-0.5 flex-shrink-0"
                  />
                  <p class="text-xs text-amber-700 dark:text-amber-300">
                    Bookmarks of this post will automatically be removed when the post expires.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- Require Connection to Reply (only shown for public posts) --%>
          <div
            :if={@selector == "public"}
            class="mt-3 p-3 rounded-lg bg-emerald-100/60 dark:bg-emerald-800/30 border border-emerald-300/60 dark:border-emerald-600/40"
          >
            <div class="flex items-center gap-2 mb-2">
              <.phx_icon
                name="hero-shield-check"
                class="h-4 w-4 text-emerald-700 dark:text-emerald-300"
              />
              <span class="text-xs font-medium text-emerald-800 dark:text-emerald-200 uppercase tracking-wide">
                Public Post Security
              </span>
            </div>
            <.liquid_checkbox
              field={@form[:require_follow_to_reply]}
              label="Require connection to reply"
              help="Only your confirmed connections can reply to this public post"
            />
          </div>
        </div>

        <%!-- Additional Controls (Level 2) --%>
        <div class="space-y-3">
          <p class="text-xs font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
            Additional Options
          </p>

          <div class="grid grid-cols-1 gap-3">
            <%!-- Temporary Post --%>
            <.liquid_checkbox
              field={@form[:is_ephemeral]}
              label="Ephemeral post"
              help="Auto-delete after time limit"
            />

            <%!-- Mature Content Toggle (available independent of content warnings) --%>
            <.liquid_checkbox
              field={@form[:mature_content]}
              label="Mature content (18+)"
              help="Mark this content as mature/adult content"
            />
          </div>

          <%!-- Expiration Controls (when ephemeral is enabled) --%>
          <div
            :if={@form[:is_ephemeral].value == true or @form[:is_ephemeral].value == "true"}
            class="mt-3 p-3 rounded-lg bg-amber-50/50 dark:bg-amber-900/20 border border-amber-200/60 dark:border-amber-700/30"
          >
            <div class="flex items-center gap-2 mb-3">
              <.phx_icon
                name="hero-clock"
                class="h-4 w-4 text-amber-600 dark:text-amber-400"
              />
              <span class="text-xs font-medium text-amber-700 dark:text-amber-300 uppercase tracking-wide">
                Auto-deletion Settings
              </span>
            </div>

            <%!-- Educational prompt for public ephemeral posts --%>
            <div
              :if={@selector == "public"}
              class="mb-4 p-3 rounded-lg bg-emerald-100/60 dark:bg-emerald-800/30 border border-emerald-300/60 dark:border-emerald-600/40"
            >
              <div class="flex items-start gap-2">
                <.phx_icon
                  name="hero-information-circle"
                  class="h-4 w-4 text-emerald-700 dark:text-emerald-300 mt-0.5 flex-shrink-0"
                />
                <div class="text-sm text-emerald-800 dark:text-emerald-200">
                  <strong>Public ephemeral post:</strong>
                  This will appear in public feeds but automatically delete.
                  Others may still screenshot or save the content before deletion. Minimum 24 hours for public accountability.
                </div>
              </div>
            </div>

            <.liquid_select_custom
              field={@form[:expires_at_option]}
              label="Delete after"
              prompt="Select timeframe..."
              color="amber"
              class="text-sm"
              options={
                if @selector == "public" do
                  [
                    {"24 hours", "24_hours"},
                    {"7 days", "7_days"},
                    {"30 days", "30_days"}
                  ]
                else
                  [
                    {"1 hour", "1_hour"},
                    {"6 hours", "6_hours"},
                    {"24 hours", "24_hours"},
                    {"7 days", "7_days"},
                    {"30 days", "30_days"}
                  ]
                end
              }
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

  @doc """
  Compact privacy controls with horizontal pill selector and inline options.
  More space-efficient than liquid_enhanced_privacy_controls.
  """
  attr :form, :any, required: true
  attr :selector, :string, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :class, :any, default: ""

  def liquid_compact_privacy_controls(assigns) do
    assigns = assign_scope_fields(assigns)

    visibility_groups =
      if is_map_key(assigns, :current_user) and is_map_key(assigns, :key) do
        Mosslet.Accounts.get_user_visibility_groups_with_connections(assigns.current_user)
      else
        []
      end

    user_connections =
      if is_map_key(assigns, :current_user) do
        Mosslet.Accounts.filter_user_connections(%{}, assigns.current_user)
      else
        []
      end

    assigns =
      assign(assigns, visibility_groups: visibility_groups, user_connections: user_connections)

    ~H"""
    <div class={[
      "p-3 rounded-lg border transition-all duration-200",
      "bg-emerald-50/30 dark:bg-emerald-900/15",
      "border-emerald-200/50 dark:border-emerald-700/40",
      @class
    ]}>
      <div class="space-y-3">
        <%!-- Visibility Pills --%>
        <div class="space-y-1.5">
          <div class="flex items-center gap-1.5">
            <.phx_icon name="hero-eye" class="h-3.5 w-3.5 text-emerald-600 dark:text-emerald-400" />
            <span class="text-xs font-medium text-emerald-700 dark:text-emerald-300">Visibility</span>
          </div>
          <div class="flex flex-wrap gap-1">
            <.privacy_pill
              value="private"
              current={@selector}
              icon="hero-lock-closed"
              label="Private"
            />
            <.privacy_pill
              value="connections"
              current={@selector}
              icon="hero-user-group"
              label="Connections"
            />
            <.privacy_pill value="public" current={@selector} icon="hero-globe-alt" label="Public" />
            <.privacy_pill
              value="specific_groups"
              current={@selector}
              icon="hero-squares-2x2"
              label="Groups"
            />
            <.privacy_pill
              value="specific_users"
              current={@selector}
              icon="hero-users"
              label="People"
            />
          </div>
        </div>

        <%!-- Group/User Selection (collapsible) --%>
        <div
          :if={@selector in ["specific_groups", "specific_users"]}
          class="pt-2 border-t border-emerald-200/40 dark:border-emerald-700/30"
        >
          <%= if @selector == "specific_groups" do %>
            <.compact_group_selector
              groups={@visibility_groups}
              form={@form}
              current_scope={@current_scope}
            />
          <% else %>
            <.compact_user_selector
              connections={@user_connections}
              form={@form}
              current_scope={@current_scope}
            />
          <% end %>
        </div>

        <%!-- Inline Options Row --%>
        <div class="pt-2 border-t border-emerald-200/40 dark:border-emerald-700/30">
          <div class="flex flex-wrap items-center gap-x-4 gap-y-2">
            <.compact_toggle
              field={@form[:allow_replies]}
              label="Replies"
              icon="hero-chat-bubble-left"
            />
            <.compact_toggle
              :if={@form[:is_ephemeral].value == false or @form[:is_ephemeral].value == "false"}
              field={@form[:allow_shares]}
              label="Shares"
              icon="hero-arrow-path-rounded-square"
            />
            <.compact_toggle field={@form[:allow_bookmarks]} label="Saves" icon="hero-bookmark" />
            <.compact_toggle
              field={@form[:is_ephemeral]}
              label="Ephemeral"
              icon="hero-clock"
              color="amber"
            />
          </div>
        </div>

        <%!-- Public post security --%>
        <div
          :if={@selector == "public"}
          class="pt-2 border-t border-emerald-200/40 dark:border-emerald-700/30"
        >
          <.compact_toggle
            field={@form[:require_follow_to_reply]}
            label="Require connection to reply"
            icon="hero-shield-check"
          />
        </div>

        <%!-- Ephemeral settings --%>
        <div
          :if={@form[:is_ephemeral].value == true or @form[:is_ephemeral].value == "true"}
          class="pt-2 border-t border-amber-200/40 dark:border-amber-700/30"
        >
          <div class="flex items-center gap-2">
            <.phx_icon name="hero-clock" class="h-3.5 w-3.5 text-amber-600 dark:text-amber-400" />
            <span class="text-xs text-amber-700 dark:text-amber-300">Delete after:</span>
            <select
              name={@form[:expires_at_option].name}
              id={@form[:expires_at_option].id}
              aria-label="Delete after"
              class="text-xs py-1 pl-2 pr-6 rounded border border-amber-200 dark:border-amber-700 bg-amber-50 dark:bg-amber-900/30 text-amber-800 dark:text-amber-200 focus:ring-1 focus:ring-amber-400"
            >
              <%= if @selector == "public" do %>
                <option
                  value="24_hours"
                  selected={
                    @form[:expires_at_option].value in [nil, "", "24_hours", "1_hour", "6_hours"]
                  }
                >
                  24 hours
                </option>
                <option value="7_days" selected={@form[:expires_at_option].value == "7_days"}>
                  7 days
                </option>
                <option value="30_days" selected={@form[:expires_at_option].value == "30_days"}>
                  30 days
                </option>
              <% else %>
                <option
                  value="1_hour"
                  selected={@form[:expires_at_option].value in [nil, "", "1_hour"]}
                >
                  1 hour
                </option>
                <option value="6_hours" selected={@form[:expires_at_option].value == "6_hours"}>
                  6 hours
                </option>
                <option value="24_hours" selected={@form[:expires_at_option].value == "24_hours"}>
                  24 hours
                </option>
                <option value="7_days" selected={@form[:expires_at_option].value == "7_days"}>
                  7 days
                </option>
                <option value="30_days" selected={@form[:expires_at_option].value == "30_days"}>
                  30 days
                </option>
              <% end %>
            </select>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :value, :string, required: true
  attr :current, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp privacy_pill(assigns) do
    assigns = assign(assigns, :selected, assigns.value == assigns.current)

    ~H"""
    <label class={[
      "inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium cursor-pointer transition-all duration-150",
      if(@selected,
        do: "bg-emerald-600 text-white shadow-sm",
        else:
          "bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-600 hover:border-emerald-300 dark:hover:border-emerald-600"
      )
    ]}>
      <input
        type="radio"
        name="visibility"
        value={@value}
        checked={@selected}
        class="sr-only"
        phx-click="update_privacy_visibility"
        phx-value-visibility={@value}
      />
      <.phx_icon name={@icon} class="h-3 w-3" />
      <span>{@label}</span>
    </label>
    """
  end

  attr :field, :any, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "emerald"

  defp compact_toggle(assigns) do
    value = assigns.field.value
    checked = value == true or value == "true" or value == "on"
    assigns = assign(assigns, :checked, checked)

    ~H"""
    <label class={[
      "inline-flex items-center gap-1.5 px-2 py-1 rounded-md text-xs cursor-pointer transition-all duration-150",
      if(@checked,
        do: [
          "bg-#{@color}-100 dark:bg-#{@color}-900/40 text-#{@color}-700 dark:text-#{@color}-300",
          "border border-#{@color}-300 dark:border-#{@color}-600"
        ],
        else:
          "text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800"
      )
    ]}>
      <input type="hidden" name={@field.name} value="false" />
      <input
        type="checkbox"
        name={@field.name}
        value="true"
        checked={@checked}
        class="sr-only"
      />
      <.phx_icon name={@icon} class="h-3 w-3" />
      <span>{@label}</span>
    </label>
    """
  end

  attr :field, :any, required: true

  defp mature_content_toggle(assigns) do
    value = assigns.field.value
    checked = value == true or value == "true" or value == "on"
    assigns = assign(assigns, :checked, checked)

    ~H"""
    <label class={[
      "flex items-center gap-2.5 w-full px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200",
      "border-2",
      if(@checked,
        do: [
          "bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-900/30 dark:to-orange-900/30",
          "border-amber-400 dark:border-amber-500",
          "shadow-md shadow-amber-500/20"
        ],
        else: [
          "bg-slate-50/50 dark:bg-slate-800/50 hover:bg-amber-50/50 dark:hover:bg-amber-900/20",
          "border-slate-200 dark:border-slate-700 hover:border-amber-300 dark:hover:border-amber-600"
        ]
      )
    ]}>
      <input type="hidden" name={@field.name} value="false" />
      <input
        type="checkbox"
        name={@field.name}
        value="true"
        checked={@checked}
        class="sr-only"
      />
      <div class={[
        "flex items-center justify-center w-8 h-8 rounded-full transition-all duration-200",
        if(@checked,
          do: "bg-amber-500 text-white shadow-sm",
          else: "bg-slate-200 dark:bg-slate-700 text-slate-500 dark:text-slate-400"
        )
      ]}>
        <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4" />
      </div>
      <div class="flex flex-col">
        <span class={[
          "text-sm font-semibold transition-colors",
          if(@checked,
            do: "text-amber-700 dark:text-amber-300",
            else: "text-slate-700 dark:text-slate-300"
          )
        ]}>
          18+ Mature Content
        </span>
        <span class="text-[11px] text-slate-500 dark:text-slate-400">
          Mark as adult-only content
        </span>
      </div>
      <div class={[
        "ml-auto flex items-center justify-center w-6 h-6 rounded-full transition-all duration-200",
        if(@checked,
          do: "bg-amber-500 text-white",
          else: "bg-slate-200 dark:bg-slate-700"
        )
      ]}>
        <.phx_icon
          name={if(@checked, do: "hero-check", else: "hero-plus")}
          class="h-3.5 w-3.5"
        />
      </div>
    </label>
    """
  end

  attr :groups, :list, required: true
  attr :form, :any, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"

  defp compact_group_selector(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <div class="space-y-2">
      <p class="text-xs text-purple-700 dark:text-purple-300">Select groups:</p>
      <%= if @groups != [] do %>
        <div class="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
          <%= for group_data <- @groups do %>
            <% group = group_data.group %>
            <% decrypted_name =
              get_decrypted_group_name(group_data, @current_scope.user, @current_scope.key) %>
            <% selected = group.id in (@form[:visibility_groups].value || []) %>
            <label class={[
              "inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-xs cursor-pointer transition-all",
              if(selected,
                do: "bg-purple-600 text-white",
                else:
                  "bg-purple-50 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 border border-purple-200 dark:border-purple-700 hover:bg-purple-100"
              )
            ]}>
              <input
                type="checkbox"
                name="post[visibility_groups][]"
                value={group.id}
                checked={selected}
                class="sr-only"
              />
              <div class={["w-2 h-2 rounded-full", get_group_color_indicator_classes(group.color)]}>
              </div>
              <span>{decrypted_name}</span>
            </label>
          <% end %>
        </div>
      <% else %>
        <p class="text-xs text-purple-600 dark:text-purple-400">
          <a href="/app/users/connections" class="underline hover:no-underline">Create groups</a>
          to share with specific groups.
        </p>
      <% end %>
    </div>
    """
  end

  attr :connections, :list, required: true
  attr :form, :any, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"

  defp compact_user_selector(assigns) do
    assigns = assign_scope_fields(assigns)

    ~H"""
    <div class="space-y-2">
      <p class="text-xs text-amber-700 dark:text-amber-300">Select people:</p>
      <%= if @connections != [] do %>
        <div class="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto">
          <%= for connection <- @connections do %>
            <% decrypted_name =
              get_decrypted_connection_name(connection, @current_scope.user, @current_scope.key) %>
            <% user_id = get_connection_other_user_id(connection, @current_scope.user) %>
            <% selected = user_id in (@form[:visibility_users].value || []) %>
            <label class={[
              "inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-xs cursor-pointer transition-all",
              if(selected,
                do: "bg-amber-600 text-white",
                else:
                  "bg-amber-50 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 border border-amber-200 dark:border-amber-700 hover:bg-amber-100"
              )
            ]}>
              <input
                type="checkbox"
                name="post[visibility_users][]"
                value={user_id}
                checked={selected}
                class="sr-only"
              />
              <img
                src={get_connection_avatar_src(connection, @current_scope.user, @current_scope.key)}
                alt={decrypted_name}
                class="w-4 h-4 rounded-full"
              />
              <span>{decrypted_name}</span>
            </label>
          <% end %>
        </div>
      <% else %>
        <p class="text-xs text-amber-600 dark:text-amber-400">
          <a href="/app/users/connections" class="underline hover:no-underline">Add connections</a>
          to share with specific people.
        </p>
      <% end %>
    </div>
    """
  end

  @doc """
  Header component for circles page - minimal design focusing on content.
  """
  attr :class, :any, default: ""
  attr :id, :string, default: nil

  def liquid_circles_header(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "flex items-center gap-3 pb-2",
        @class
      ]}
    >
      <div class="flex items-center justify-center w-10 h-10 rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 shadow-sm">
        <.phx_icon name="hero-circle-stack" class="w-5 h-5 text-teal-600 dark:text-teal-400" />
      </div>
      <div>
        <h1 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
          Circles
        </h1>
        <p class="text-sm text-slate-500 dark:text-slate-400">
          Your private groups
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Header component for connections page - minimal design focusing on content.
  """
  attr :class, :any, default: ""
  attr :id, :string, default: nil

  def liquid_connections_header(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "flex items-center gap-3 pb-2",
        @class
      ]}
    >
      <div class="flex items-center justify-center w-10 h-10 rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 shadow-sm">
        <.phx_icon name="hero-users" class="w-5 h-5 text-teal-600 dark:text-teal-400" />
      </div>
      <div>
        <h1 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
          Connections
        </h1>
        <p class="text-sm text-slate-500 dark:text-slate-400">
          Your trusted network
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Search input component with liquid metal styling.
  """
  attr :placeholder, :string, default: "Search..."
  attr :value, :string, default: ""
  attr :class, :any, default: ""
  attr :phx_change, :string
  attr :id, :string
  attr :rest, :global, include: ~w(id name)

  def liquid_search_input(assigns) do
    ~H"""
    <.form id={@id} for={%{}} phx-change={@phx_change}>
      <div class={["relative", @class]}>
        <%!-- Liquid background effect --%>
        <div class="absolute inset-0 rounded-xl bg-gradient-to-r from-slate-100/80 via-white/60 to-slate-100/80 dark:from-slate-700/80 dark:via-slate-600/60 dark:to-slate-700/80 opacity-100 transition-opacity duration-200 ease-out focus-within:opacity-100">
        </div>

        <%!-- Search icon --%>
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none z-10">
          <.phx_icon name="hero-magnifying-glass" class="h-5 w-5 text-slate-400 dark:text-slate-500" />
        </div>

        <%!-- Input field --%>
        <input
          type="text"
          name="search_query"
          placeholder={@placeholder}
          phx-debounce={500}
          value={@value}
          class="relative z-10 block w-full pl-10 pr-4 py-3 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-500 dark:placeholder-slate-400 bg-transparent border border-slate-200/60 dark:border-slate-600/60 rounded-xl shadow-sm focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:border-teal-500/50 dark:focus:ring-teal-400/50 dark:focus:border-teal-400/50 transition-all duration-200 ease-out"
          {@rest}
        />
      </div>
    </.form>
    """
  end

  @doc """
  Empty state component with liquid metal styling and semantic colors.
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :action_label, :string, default: nil
  attr :action_navigate, :string, default: nil
  attr :action_patch, :string, default: nil
  attr :action_click, :string, default: nil
  attr :color, :string, default: "teal", values: ~w(teal emerald cyan purple indigo blue)
  attr :heading_level, :integer, default: 2, values: 1..6
  attr :class, :any, default: ""

  def liquid_empty_state(assigns) do
    ~H"""
    <div class={["text-center py-12 sm:py-16", @class]}>
      <%!-- Icon container with semantic color styling --%>
      <div class={[
        "mx-auto w-16 h-16 sm:w-20 sm:h-20 rounded-2xl border flex items-center justify-center mb-6 relative overflow-hidden group transition-all duration-300",
        get_empty_state_icon_styles(@color)
      ]}>
        <%!-- Shimmer effect with semantic color --%>
        <div class={[
          "absolute inset-0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000 ease-out",
          get_empty_state_shimmer(@color)
        ]}>
        </div>

        <.phx_icon
          name={@icon}
          class={[
            "w-8 h-8 sm:w-10 sm:h-10 relative z-10 transition-transform duration-300 group-hover:scale-110",
            get_empty_state_icon_color(@color)
          ]}
        />
      </div>

      <%!-- Content with semantic color theming --%>
      <div class="space-y-3 mb-6">
        <.dynamic_heading
          level={@heading_level}
          class={[
            "text-lg sm:text-xl font-semibold",
            get_empty_state_title_color(@color)
          ]}
        >
          {@title}
        </.dynamic_heading>
        <p class={[
          "max-w-md mx-auto leading-relaxed",
          get_empty_state_description_color(@color)
        ]}>
          {@description}
        </p>
      </div>

      <%!-- Action button with semantic color --%>
      <div :if={@action_label}>
        <.liquid_button
          navigate={@action_navigate}
          patch={@action_patch}
          phx-click={@action_click}
          icon="hero-plus"
          color={@color}
          class="justify-center"
        >
          {@action_label}
        </.liquid_button>
      </div>
    </div>
    """
  end

  # Helper functions for semantic empty state styling
  defp get_empty_state_icon_styles(color) do
    case color do
      "teal" ->
        "bg-gradient-to-br from-teal-100/80 via-teal-50/60 to-teal-100/80 dark:from-teal-900/30 dark:via-teal-800/20 dark:to-teal-900/30 border-teal-200/40 dark:border-teal-700/40"

      "emerald" ->
        "bg-gradient-to-br from-emerald-100/80 via-emerald-50/60 to-emerald-100/80 dark:from-emerald-900/30 dark:via-emerald-800/20 dark:to-emerald-900/30 border-emerald-200/40 dark:border-emerald-700/40"

      "cyan" ->
        "bg-gradient-to-br from-cyan-100/80 via-cyan-50/60 to-cyan-100/80 dark:from-cyan-900/30 dark:via-cyan-800/20 dark:to-cyan-900/30 border-cyan-200/40 dark:border-cyan-700/40"

      "purple" ->
        "bg-gradient-to-br from-purple-100/80 via-purple-50/60 to-purple-100/80 dark:from-purple-900/30 dark:via-purple-800/20 dark:to-purple-900/30 border-purple-200/40 dark:border-purple-700/40"

      "indigo" ->
        "bg-gradient-to-br from-indigo-100/80 via-indigo-50/60 to-indigo-100/80 dark:from-indigo-900/30 dark:via-indigo-800/20 dark:to-indigo-900/30 border-indigo-200/40 dark:border-indigo-700/40"

      "blue" ->
        "bg-gradient-to-br from-blue-100/80 via-blue-50/60 to-blue-100/80 dark:from-blue-900/30 dark:via-blue-800/20 dark:to-blue-900/30 border-blue-200/40 dark:border-blue-700/40"

      _ ->
        "bg-gradient-to-br from-teal-100/80 via-teal-50/60 to-teal-100/80 dark:from-teal-900/30 dark:via-teal-800/20 dark:to-teal-900/30 border-teal-200/40 dark:border-teal-700/40"
    end
  end

  defp get_empty_state_shimmer(color) do
    case color do
      "teal" ->
        "bg-gradient-to-r from-transparent via-teal-200/30 dark:via-teal-400/20 to-transparent"

      "emerald" ->
        "bg-gradient-to-r from-transparent via-emerald-200/30 dark:via-emerald-400/20 to-transparent"

      "cyan" ->
        "bg-gradient-to-r from-transparent via-cyan-200/30 dark:via-cyan-400/20 to-transparent"

      "purple" ->
        "bg-gradient-to-r from-transparent via-purple-200/30 dark:via-purple-400/20 to-transparent"

      "indigo" ->
        "bg-gradient-to-r from-transparent via-indigo-200/30 dark:via-indigo-400/20 to-transparent"

      "blue" ->
        "bg-gradient-to-r from-transparent via-blue-200/30 dark:via-blue-400/20 to-transparent"

      _ ->
        "bg-gradient-to-r from-transparent via-teal-200/30 dark:via-teal-400/20 to-transparent"
    end
  end

  defp get_empty_state_icon_color(color) do
    case color do
      "teal" -> "text-teal-600 dark:text-teal-400"
      "emerald" -> "text-emerald-600 dark:text-emerald-400"
      "cyan" -> "text-cyan-600 dark:text-cyan-400"
      "purple" -> "text-purple-600 dark:text-purple-400"
      "indigo" -> "text-indigo-600 dark:text-indigo-400"
      "blue" -> "text-blue-600 dark:text-blue-400"
      _ -> "text-teal-600 dark:text-teal-400"
    end
  end

  defp get_empty_state_title_color(color) do
    case color do
      "teal" -> "text-teal-900 dark:text-teal-100"
      "emerald" -> "text-emerald-900 dark:text-emerald-100"
      "cyan" -> "text-cyan-900 dark:text-cyan-100"
      "purple" -> "text-purple-900 dark:text-purple-100"
      "indigo" -> "text-indigo-900 dark:text-indigo-100"
      "blue" -> "text-blue-900 dark:text-blue-100"
      _ -> "text-teal-900 dark:text-teal-100"
    end
  end

  defp get_empty_state_description_color(color) do
    case color do
      "teal" -> "text-teal-700 dark:text-teal-300"
      "emerald" -> "text-emerald-700 dark:text-emerald-300"
      "cyan" -> "text-cyan-700 dark:text-cyan-300"
      "purple" -> "text-purple-700 dark:text-purple-300"
      "indigo" -> "text-indigo-700 dark:text-indigo-300"
      "blue" -> "text-blue-700 dark:text-blue-300"
      _ -> "text-teal-700 dark:text-teal-300"
    end
  end

  @doc """
  Connection card component with liquid metal styling.
  Expects decrypted data from the LiveView.
  """
  attr :name, :string, required: true
  attr :username, :string, required: true
  attr :label, :string, required: true
  attr :color, :atom, required: true
  attr :avatar_src, :string, required: true
  attr :connected_at, :any, required: true
  attr :connection_id, :string, required: true
  attr :zen?, :boolean, default: false
  attr :photos?, :boolean, default: false
  attr :show_interactions?, :boolean, default: true
  attr :show_profile?, :boolean, default: false
  attr :status, :string, default: nil
  attr :status_message, :string, default: nil
  attr :heading_level, :integer, default: 2, values: 1..6
  attr :class, :any, default: ""

  def liquid_connection_card(assigns) do
    ~H"""
    <div class="relative">
      <article class={[
        "group/card relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
        "hover:border-slate-300/60 dark:hover:border-slate-600/60",
        "transform-gpu will-change-transform cursor-pointer",
        @class
      ]}>
        <%!-- Liquid background effect on hover --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out group-hover/card:opacity-100 bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10">
        </div>

        <%!-- Shimmer effect --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out group-hover/card:opacity-100 bg-gradient-to-r from-transparent via-emerald-200/20 dark:via-emerald-400/10 to-transparent group-hover/card:translate-x-full -translate-x-full">
        </div>

        <%!-- Card content --%>
        <div class="relative p-6">
          <%!-- Header with avatar and name --%>
          <div class="flex items-start gap-4 mb-4">
            <%!-- Avatar --%>
            <div class="relative flex-shrink-0">
              <.liquid_avatar
                id={"liquid-avatar-#{@connection_id}"}
                src={@avatar_src}
                name={@name}
                size="lg"
                status={@status}
                status_message={@status_message}
                clickable={true}
              />

              <%!-- Status indicator now handled by liquid_avatar component --%>
            </div>

            <%!-- User info --%>
            <div class="flex-1 min-w-0">
              <div class="flex items-start justify-between gap-2">
                <div class="min-w-0 flex-1">
                  <.dynamic_heading
                    level={@heading_level}
                    class="text-lg font-semibold text-slate-900 dark:text-slate-100 truncate group-hover:text-teal-700 dark:group-hover:text-teal-300 transition-colors duration-200"
                  >
                    {@name}
                  </.dynamic_heading>
                  <p class="text-sm text-slate-600 dark:text-slate-400 truncate">
                    @{@username}
                  </p>

                  <%!-- Connection indicators (similar to timeline post indicators) --%>
                  <div class="flex items-center gap-1 mt-1">
                    <%!-- Muted indicator --%>
                    <.phx_icon
                      :if={@zen?}
                      id={"zen-muted-#{@connection_id}"}
                      name="hero-speaker-x-mark"
                      class="h-3 w-3 text-amber-500 dark:text-amber-400"
                      phx_hook="TippyHook"
                      data_tippy_content="Muted"
                    />

                    <%!-- Photos enabled indicator --%>
                    <.phx_icon
                      :if={@photos?}
                      id={"photos-enabled-#{@connection_id}"}
                      name="hero-photo"
                      class="h-3 w-3 text-emerald-500 dark:text-emerald-400"
                      phx_hook="TippyHook"
                      data_tippy_content="Photo downloads enabled"
                    />
                  </div>
                </div>

                <%!-- Connection label badge --%>
                <.liquid_badge
                  variant="soft"
                  color={connection_badge_color(@color)}
                  size="sm"
                >
                  {@label}
                </.liquid_badge>
              </div>

              <%!-- Status or last activity --%>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-2">
                Connected <.local_time_ago id={@connection_id} at={@connected_at} />
              </p>
            </div>
          </div>

          <%!-- Quick actions --%>
          <div class="flex items-center justify-between pt-4 border-t border-slate-200/60 dark:border-slate-600/60">
            <%!-- Action buttons --%>
            <div :if={@show_interactions?} class="flex items-center gap-2">
              <%!-- Message button --%>
              <%!-- Future feature maybe --%>
              <%!--
              <button
                id={"message-button-#{@connection_id}"}
                phx-hook="TippyHook"
                data-tippy-content="Coming Soon - TBD"
                type="button"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-teal-600 dark:text-teal-400 bg-teal-50/50 dark:bg-teal-900/20 hover:bg-teal-100/50 dark:hover:bg-teal-900/30 border border-teal-200/40 dark:border-teal-700/40 rounded-full transition-all duration-200 ease-out hover:scale-105"
                title="Send message"
              >
                <.phx_icon name="hero-chat-bubble-left" class="h-3.5 w-3.5" /> Message
              </button>
              --%>

              <%!-- View profile button --%>

              <.link
                :if={@show_profile?}
                id={"profile-button-#{@connection_id}"}
                phx-hook="TippyHook"
                navigate={~p"/app/profile/#{@username}"}
                data-tippy-content="View profile"
                type="button"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-50/50 dark:bg-slate-700/20 hover:bg-slate-100/50 dark:hover:bg-slate-600/30 border border-slate-200/40 dark:border-slate-600/40 rounded-full transition-all duration-200 ease-out hover:scale-105"
              >
                <.phx_icon name="hero-user" class="h-3.5 w-3.5" /> Profile
              </.link>
            </div>

            <%!-- Placeholder when interactions are hidden (to maintain layout) --%>
            <div :if={!@show_interactions?} class="flex items-center gap-2">
              <div class="text-xs text-slate-400 dark:text-slate-500 italic">
                Profile not available
              </div>
            </div>

            <%!-- Dropdown trigger only (menu will be positioned outside) --%>
            <button
              type="button"
              phx-click={JS.toggle(to: "#connection-menu-#{@connection_id}-menu")}
              class="p-1.5 text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-400 rounded-full hover:bg-slate-100/50 dark:hover:bg-slate-700/30 transition-all duration-200 ease-out"
              title="More options"
            >
              <.phx_icon
                name="hero-ellipsis-horizontal"
                class="h-4 w-4"
              />
            </button>
          </div>
        </div>
      </article>

      <%!-- Dropdown menu positioned outside the card to avoid clipping --%>
      <div
        id={"connection-menu-#{@connection_id}-menu"}
        class="absolute z-[200] mt-2 w-48 origin-top-right hidden right-0 top-full rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 transition-all duration-200 ease-out ring-1 ring-slate-200/60 dark:ring-slate-700/60"
        role="menu"
        aria-orientation="vertical"
        phx-click-away={JS.hide(to: "#connection-menu-#{@connection_id}-menu")}
      >
        <%!-- Liquid background effect --%>
        <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 opacity-50">
        </div>

        <div class="relative py-2">
          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            role="menuitem"
            phx-click="edit_connection"
            phx-value-id={@connection_id}
          >
            <.phx_icon name="hero-pencil" class="h-4 w-4" /> Edit Label
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            role="menuitem"
            phx-click="toggle_mute"
            phx-value-id={@connection_id}
            id={"toggle-mute-button-#{@connection_id}"}
          >
            <.phx_icon
              name={if @zen?, do: "hero-speaker-wave", else: "hero-speaker-x-mark"}
              class="h-4 w-4"
            />
            {if @zen?, do: "Unmute", else: "Mute"}
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            role="menuitem"
            phx-click="toggle_photos"
            phx-value-id={@connection_id}
          >
            <.phx_icon name={if @photos?, do: "hero-photo-solid", else: "hero-photo"} class="h-4 w-4" />
            {if @photos?, do: "Disable Photo Downloads", else: "Enable Photo Downloads"}
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-amber-700 dark:text-amber-300 hover:text-amber-900 dark:hover:text-amber-100"
            role="menuitem"
            phx-click="block_user"
            phx-value-id={@connection_id}
            phx-value-name={@name}
          >
            <.phx_icon name="hero-no-symbol" class="h-4 w-4" /> Block Author
          </div>

          <div
            class="group flex items-center gap-3 px-4 py-2.5 text-sm transition-all duration-200 ease-out cursor-pointer hover:bg-slate-100/80 dark:hover:bg-slate-700/80 first:rounded-t-lg last:rounded-b-lg text-red-700 dark:text-red-300 hover:text-red-900 dark:hover:text-red-100"
            role="menuitem"
            phx-click="delete_connection"
            phx-value-id={@connection_id}
            data-confirm="Are you sure you want to delete this connection? This action cannot be undone."
          >
            <.phx_icon name="hero-trash" class="h-4 w-4" /> Delete Connection
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Arrivals section for pending connection requests.
  Expects decrypted arrival data from the LiveView.
  """
  attr :arrivals, :list, required: true
  attr :arrivals_count, :integer, required: true
  attr :class, :any, default: ""

  def liquid_arrivals_section(assigns) do
    ~H"""
    <div class={["space-y-6", @class]}>
      <%!-- Section header --%>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-xl bg-gradient-to-br from-emerald-100 via-emerald-50 to-emerald-100 dark:from-emerald-900/30 dark:via-emerald-800/20 dark:to-emerald-900/30 border border-emerald-200/40 dark:border-emerald-700/40">
            <.phx_icon
              name="hero-inbox-arrow-down"
              class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
            />
          </div>
          <div>
            <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
              Pending Connections
            </h2>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              {@arrivals_count} people want to connect with you
            </p>
          </div>
        </div>
      </div>

      <%!-- Arrivals list --%>
      <div class="space-y-4">
        <%!-- Empty state for arrivals --%>
        <div :if={Enum.empty?(@arrivals)} class="text-center py-8">
          <div class="mx-auto w-12 h-12 rounded-full bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center mb-4">
            <.phx_icon name="hero-check" class="w-6 h-6 text-emerald-600 dark:text-emerald-400" />
          </div>
          <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-2">
            All caught up!
          </h3>
          <p class="text-slate-600 dark:text-slate-300">
            You have no pending connection requests.
          </p>
        </div>

        <%!-- Arrival cards --%>
        <div :for={arrival <- @arrivals} class="arrival-card-container">
          <.liquid_arrival_card
            name={arrival.name}
            email={arrival.email}
            label={arrival.label}
            color={arrival.color}
            avatar_src={arrival.avatar_src}
            requested_at={arrival.requested_at}
            arrival_id={arrival.id}
            class="transition-all duration-300"
          />
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Individual arrival card for connection requests.
  Expects decrypted data from the LiveView.
  """
  attr :name, :string, required: true
  attr :email, :string, required: true
  attr :label, :string, required: true
  attr :color, :atom, required: true
  attr :avatar_src, :string, required: true
  attr :requested_at, :any, required: true
  attr :arrival_id, :string, required: true
  attr :status, :string, default: nil
  attr :status_message, :string, default: nil
  attr :heading_level, :integer, default: 2, values: 1..6
  attr :class, :any, default: ""

  def liquid_arrival_card(assigns) do
    ~H"""
    <article class={[
      "group relative rounded-2xl overflow-hidden transition-all duration-300 ease-out",
      "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
      "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30",
      "hover:border-slate-300/60 dark:hover:border-slate-600/60",
      @class
    ]}>
      <%!-- Enhanced liquid background with emerald/teal gradient --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out group-hover:opacity-100 bg-gradient-to-br from-emerald-50/20 via-teal-50/10 to-emerald-50/20 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-emerald-900/10">
      </div>

      <%!-- Shimmer effect for enhanced interaction feedback --%>
      <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out group-hover:opacity-100 bg-gradient-to-r from-transparent via-emerald-200/20 dark:via-emerald-400/10 to-transparent group-hover:translate-x-full -translate-x-full">
      </div>

      <%!-- Card content with enhanced responsive padding and spacing --%>
      <div class="relative p-5 sm:p-7 lg:p-8">
        <%!-- Enhanced mobile-first layout with better spacing --%>
        <div class="flex flex-col gap-5 sm:gap-6 lg:flex-row lg:items-center lg:justify-between lg:gap-8">
          <%!-- User info section with refined mobile layout --%>
          <div class="flex items-start gap-4 sm:gap-5 flex-1 min-w-0">
            <%!-- Avatar with better mobile sizing --%>
            <div class="flex-shrink-0">
              <.liquid_avatar
                id={"liquid-avatar-#{@arrival_id}"}
                src={@avatar_src}
                name={@name}
                size="lg"
                clickable={false}
                status={@status}
                status_message={@status_message}
              />
            </div>

            <%!-- User details with enhanced typography hierarchy --%>
            <div class="flex-1 min-w-0">
              <%!-- Name and badge row with improved spacing --%>
              <div class="flex items-start justify-between gap-3 mb-3">
                <div class="min-w-0 flex-1">
                  <.dynamic_heading
                    level={@heading_level}
                    class="text-xl sm:text-2xl font-bold text-slate-900 dark:text-slate-100 truncate group-hover:text-emerald-700 dark:group-hover:text-emerald-300 transition-colors duration-200 leading-tight"
                  >
                    {@name}
                  </.dynamic_heading>
                </div>

                <%!-- Badge with enhanced visual weight --%>
                <div class="flex-shrink-0">
                  <.liquid_badge
                    variant="soft"
                    color={connection_badge_color(@color)}
                    size="md"
                  >
                    {@label}
                  </.liquid_badge>
                </div>
              </div>

              <%!-- Email with improved secondary hierarchy --%>
              <p class="text-base sm:text-lg text-slate-600 dark:text-slate-400 truncate mb-3 font-medium">
                {@email}
              </p>

              <%!-- Timestamp with enhanced visual treatment --%>
              <div class="flex items-center gap-2 text-sm sm:text-base text-slate-500 dark:text-slate-400">
                <div class="flex items-center justify-center w-5 h-5 rounded-full bg-emerald-100 dark:bg-emerald-900/30">
                  <.phx_icon name="hero-clock" class="h-3 w-3 text-emerald-600 dark:text-emerald-400" />
                </div>
                <span class="font-medium">
                  Requested <.local_time_ago id={@arrival_id} at={@requested_at} />
                </span>
              </div>
            </div>
          </div>

          <%!-- Enhanced action buttons with clear visual hierarchy --%>
          <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 sm:gap-4 flex-shrink-0 min-w-0 sm:min-w-[180px]">
            <%!-- Primary Accept button with enhanced prominence --%>
            <.liquid_button
              size="md"
              color="emerald"
              icon="hero-check"
              phx-click="accept_uconn"
              phx-value-id={@arrival_id}
              shimmer="card"
              class="flex-1 sm:flex-initial min-h-[48px] justify-center order-1 font-semibold shadow-lg shadow-emerald-500/25 dark:shadow-emerald-400/20 hover:shadow-xl hover:shadow-emerald-500/30 dark:hover:shadow-emerald-400/25 transform transition-all duration-200 hover:scale-105"
            >
              <span class="sm:hidden">Accept</span>
              <span class="hidden sm:inline">Accept Request</span>
            </.liquid_button>

            <%!-- Secondary Decline button with subtle styling --%>
            <.liquid_button
              size="md"
              variant="secondary"
              color="slate"
              icon="hero-x-mark"
              phx-click="decline_uconn"
              phx-value-id={@arrival_id}
              data-confirm="Are you sure you wish to decline this connection request?"
              class="flex-1 sm:flex-initial min-h-[48px] justify-center order-2 font-medium hover:bg-rose-50 dark:hover:bg-rose-900/20 hover:text-rose-600 dark:hover:text-rose-400 hover:border-rose-200 dark:hover:border-rose-700 transition-all duration-200"
            >
              <span class="sm:hidden">Decline</span>
              <span class="hidden sm:inline">Decline</span>
            </.liquid_button>
          </div>
        </div>
      </div>
    </article>
    """
  end

  @doc """
  Tab navigation component for connections page with fixed responsive behavior.
  """
  attr :tabs, :list, required: true
  attr :active_tab, :string, required: true
  attr :class, :any, default: ""

  def liquid_connections_tabs(assigns) do
    ~H"""
    <div class={["flex items-center gap-2 md:gap-3", @class]}>
      <div :for={tab <- @tabs} class="relative overflow-visible">
        <button
          type="button"
          phx-click="switch_tab"
          phx-value-tab={tab.key}
          class={[
            "group relative flex items-center justify-center gap-2 px-4 py-3 md:px-5 md:py-3 xl:px-6 xl:py-3.5 rounded-xl text-sm md:text-base font-medium transition-all duration-200 ease-out overflow-visible backdrop-blur-sm min-h-[44px] whitespace-nowrap",
            get_tab_styles(@active_tab, tab)
          ]}
        >
          <%!-- Enhanced liquid background for active tab with semantic colors --%>
          <div
            :if={@active_tab == tab.key}
            class={[
              "absolute inset-0 transition-all duration-300 ease-out",
              get_tab_background(tab)
            ]}
          >
          </div>

          <%!-- Tab icon with consistent sizing --%>
          <div class="relative z-10">
            <.phx_icon name={tab.icon} class="h-4 w-4 md:h-5 md:w-5" />
          </div>

          <%!-- Tab label only (removing count badge to match timeline pattern) --%>
          <div class="relative z-10 flex items-center gap-2">
            <span class="font-medium">{tab.label}</span>
          </div>

          <%!-- Enhanced unread badge indicator with count (following timeline pattern) --%>
          <span
            :if={Map.get(tab, :unread, 0) > 0}
            class={[
              "absolute -top-1 -right-1 z-20",
              "flex items-center justify-center",
              "min-w-[1.25rem] h-5 px-1.5 text-xs font-bold rounded-full",
              "bg-gradient-to-r from-teal-400 to-cyan-400 text-white",
              "shadow-lg shadow-teal-500/50 dark:shadow-cyan-400/40",
              "ring-2 ring-white dark:ring-slate-800",
              "animate-pulse"
            ]}
          >
            {Map.get(tab, :unread, 0)}
          </span>
        </button>
      </div>
    </div>
    """
  end

  # Helper functions for semantic tab styling
  defp get_tab_styles(active_tab, tab) when active_tab == tab.key do
    case Map.get(tab, :color, "teal") do
      "teal" ->
        "bg-gradient-to-r from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-teal-900/40 text-teal-700 dark:text-teal-300 border border-teal-200/60 dark:border-teal-700/60 shadow-sm shadow-teal-500/20"

      "emerald" ->
        "bg-gradient-to-r from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/40 dark:via-teal-900/30 dark:to-emerald-900/40 text-emerald-700 dark:text-emerald-300 border border-emerald-200/60 dark:border-emerald-700/60 shadow-sm shadow-emerald-500/20"

      "purple" ->
        "bg-gradient-to-r from-purple-100 via-indigo-50 to-purple-100 dark:from-purple-900/40 dark:via-indigo-900/30 dark:to-purple-900/40 text-purple-700 dark:text-purple-300 border border-purple-200/60 dark:border-purple-700/60 shadow-sm shadow-purple-500/20"

      _ ->
        "bg-gradient-to-r from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-teal-900/40 text-teal-700 dark:text-teal-300 border border-teal-200/60 dark:border-teal-700/60 shadow-sm shadow-teal-500/20"
    end
  end

  defp get_tab_styles(_active_tab, _tab) do
    "text-slate-600 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100/50 dark:hover:bg-slate-700/30 border border-transparent"
  end

  defp get_tab_background(tab) do
    case Map.get(tab, :color, "teal") do
      "teal" ->
        "bg-gradient-to-r from-teal-50/60 via-emerald-50/40 to-teal-50/60 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-teal-900/20"

      "emerald" ->
        "bg-gradient-to-r from-emerald-50/60 via-teal-50/40 to-emerald-50/60 dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-emerald-900/20"

      "purple" ->
        "bg-gradient-to-r from-purple-50/60 via-indigo-50/40 to-purple-50/60 dark:from-purple-900/20 dark:via-indigo-900/15 dark:to-purple-900/20"

      _ ->
        "bg-gradient-to-r from-teal-50/60 via-emerald-50/40 to-teal-50/60 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-teal-900/20"
    end
  end

  # Helper functions for connection-related styling
  defp connection_badge_color(:emerald), do: "emerald"
  defp connection_badge_color(:orange), do: "orange"
  defp connection_badge_color(:amber), do: "amber"
  defp connection_badge_color(:pink), do: "rose"
  defp connection_badge_color(:purple), do: "purple"
  defp connection_badge_color(:rose), do: "rose"
  defp connection_badge_color(:yellow), do: "amber"
  defp connection_badge_color(:zinc), do: "slate"
  defp connection_badge_color(:cyan), do: "cyan"
  defp connection_badge_color(:indigo), do: "indigo"
  defp connection_badge_color(:teal), do: "teal"
  defp connection_badge_color(_), do: "purple"

  def connection_username_color_classes(:emerald),
    do: "text-emerald-600/80 dark:text-emerald-400/70"

  def connection_username_color_classes(:orange),
    do: "text-orange-600/80 dark:text-orange-400/70"

  def connection_username_color_classes(:amber), do: "text-amber-600/80 dark:text-amber-400/70"
  def connection_username_color_classes(:pink), do: "text-rose-600/80 dark:text-rose-400/70"
  def connection_username_color_classes(:purple), do: "text-purple-600/80 dark:text-purple-400/70"
  def connection_username_color_classes(:rose), do: "text-rose-600/80 dark:text-rose-400/70"
  def connection_username_color_classes(:yellow), do: "text-amber-600/80 dark:text-amber-400/70"
  def connection_username_color_classes(:zinc), do: "text-slate-600/80 dark:text-slate-400/70"
  def connection_username_color_classes(:cyan), do: "text-cyan-600/80 dark:text-cyan-400/70"
  def connection_username_color_classes(:indigo), do: "text-indigo-600/80 dark:text-indigo-400/70"
  def connection_username_color_classes(:teal), do: "text-teal-600/80 dark:text-teal-400/70"
  def connection_username_color_classes(_), do: "text-purple-600/80 dark:text-purple-400/70"

  # Helper functions for decrypting connection data (using pattern matching)

  def get_connection_avatar_src(connection, current_user, key) do
    if !show_avatar?(connection) do
      "/images/logo.svg"
    else
      case maybe_get_avatar_src(connection, current_user, key, []) do
        "" -> "/images/logo.svg"
        nil -> "/images/logo.svg"
        result when is_binary(result) -> result
      end
    end
  end

  def get_decrypted_connection_name(connection, current_user, key) do
    case decr_uconn(connection.connection.name, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted]"
    end
  end

  def get_decrypted_connection_username(connection, current_user, key) do
    case decr_uconn(connection.connection.username, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[encrypted]"
    end
  end

  def get_decrypted_connection_label(connection, current_user, key) do
    case decr_uconn(connection.label, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted]"
    end
  end

  # Helper functions for visibility groups with liquid metal design consistency

  def get_decrypted_group_name(group_data, current_user, key) do
    group =
      case group_data do
        %{group: g} -> g
        g -> g
      end

    case decr(group.name, current_user, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted Group]"
    end
  end

  def get_decrypted_group_description(group_data, current_user, key) do
    group =
      case group_data do
        %{group: g} -> g
        g -> g
      end

    case decr(group.description, current_user, key) do
      result when is_binary(result) -> result
      _ -> ""
    end
  end

  defp get_connection_other_user_id(connection, current_user) do
    if connection.user_id == current_user.id do
      connection.reverse_user_id
    else
      connection.user_id
    end
  end

  defp get_post_shared_user_classes(color) do
    case color do
      :emerald ->
        "from-emerald-100 to-emerald-200 dark:from-emerald-900/30 dark:to-emerald-800/30"

      :teal ->
        "from-teal-100 to-teal-200 dark:from-teal-900/30 dark:to-teal-800/30"

      :orange ->
        "from-orange-100 to-orange-200 dark:from-orange-900/30 dark:to-orange-800/30"

      :purple ->
        "from-purple-100 to-purple-200 dark:from-purple-900/30 dark:to-purple-800/30"

      :rose ->
        "from-rose-100 to-rose-200 dark:from-rose-900/30 dark:to-rose-800/30"

      :amber ->
        "from-amber-100 to-amber-200 dark:from-amber-900/30 dark:to-amber-800/30"

      :yellow ->
        "from-yellow-100 to-yellow-200 dark:from-yellow-900/30 dark:to-yellow-800/30"

      :cyan ->
        "from-cyan-100 to-cyan-200 dark:from-cyan-900/30 dark:to-cyan-800/30"

      :indigo ->
        "from-indigo-100 to-indigo-200 dark:from-indigo-900/30 dark:to-indigo-800/30"

      :pink ->
        "from-pink-100 to-pink-200 dark:from-pink-900/30 dark:to-pink-800/30"

      _ ->
        "from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600"
    end
  end

  defp get_post_shared_user_text_classes(color) do
    case color do
      :emerald -> "text-emerald-600 dark:text-emerald-400"
      :teal -> "text-teal-600 dark:text-teal-400"
      :orange -> "text-orange-600 dark:text-orange-400"
      :purple -> "text-purple-600 dark:text-purple-400"
      :rose -> "text-rose-600 dark:text-rose-400"
      :amber -> "text-amber-600 dark:text-amber-400"
      :yellow -> "text-yellow-600 dark:text-yellow-400"
      :cyan -> "text-cyan-600 dark:text-cyan-400"
      :indigo -> "text-indigo-600 dark:text-indigo-400"
      :pink -> "text-pink-600 dark:text-pink-400"
      _ -> "text-slate-600 dark:text-slate-400"
    end
  end

  defp get_connection_color_badge_classes(color) do
    case color do
      :teal ->
        "bg-teal-100/80 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300"

      :emerald ->
        "bg-emerald-100/80 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300"

      :cyan ->
        "bg-cyan-100/80 dark:bg-cyan-900/30 text-cyan-700 dark:text-cyan-300"

      :purple ->
        "bg-purple-100/80 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300"

      :pink ->
        "bg-pink-100/80 dark:bg-pink-900/30 text-pink-700 dark:text-pink-300"

      :rose ->
        "bg-rose-100/80 dark:bg-rose-900/30 text-rose-700 dark:text-rose-300"

      :amber ->
        "bg-amber-100/80 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300"

      :yellow ->
        "bg-yellow-100/80 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-300"

      :orange ->
        "bg-orange-100/80 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300"

      :indigo ->
        "bg-indigo-100/80 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300"

      _ ->
        "bg-slate-100/80 dark:bg-slate-900/30 text-slate-700 dark:text-slate-300"
    end
  end

  # Card background and border classes following the liquid metal aesthetic
  def get_group_card_classes(color) do
    base_classes = "bg-white/95 dark:bg-slate-800/95"

    case color do
      :teal ->
        "#{base_classes} border-teal-200/40 dark:border-teal-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-teal-300/60 dark:hover:border-teal-600/60 hover:shadow-teal-500/10"

      :emerald ->
        "#{base_classes} border-emerald-200/40 dark:border-emerald-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-emerald-300/60 dark:hover:border-emerald-600/60 hover:shadow-emerald-500/10"

      :cyan ->
        "#{base_classes} border-cyan-200/40 dark:border-cyan-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-cyan-300/60 dark:hover:border-cyan-600/60 hover:shadow-cyan-500/10"

      :purple ->
        "#{base_classes} border-purple-200/40 dark:border-purple-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-purple-300/60 dark:hover:border-purple-600/60 hover:shadow-purple-500/10"

      :rose ->
        "#{base_classes} border-rose-200/40 dark:border-rose-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-rose-300/60 dark:hover:border-rose-600/60 hover:shadow-rose-500/10"

      :amber ->
        "#{base_classes} border-amber-200/40 dark:border-amber-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-amber-300/60 dark:hover:border-amber-600/60 hover:shadow-amber-500/10"

      :orange ->
        "#{base_classes} border-orange-200/40 dark:border-orange-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-orange-300/60 dark:hover:border-orange-600/60 hover:shadow-orange-500/10"

      :indigo ->
        "#{base_classes} border-indigo-200/40 dark:border-indigo-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-indigo-300/60 dark:hover:border-indigo-600/60 hover:shadow-indigo-500/10"

      :pink ->
        "#{base_classes} border-pink-200/40 dark:border-pink-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-pink-300/60 dark:hover:border-pink-600/60 hover:shadow-pink-500/10"

      _ ->
        "#{base_classes} border-slate-200/40 dark:border-slate-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-slate-300/60 dark:hover:border-slate-600/60 hover:shadow-slate-500/10"
    end
  end

  # Edit button classes with color-coordinated hover states
  def get_group_edit_button_classes(color) do
    base_classes = "text-slate-400 dark:text-slate-500"

    case color do
      :teal ->
        "#{base_classes} hover:text-teal-600 hover:bg-teal-50 dark:hover:text-teal-400 dark:hover:bg-teal-900/20"

      :emerald ->
        "#{base_classes} hover:text-emerald-600 hover:bg-emerald-50 dark:hover:text-emerald-400 dark:hover:bg-emerald-900/20"

      :cyan ->
        "#{base_classes} hover:text-cyan-600 hover:bg-cyan-50 dark:hover:text-cyan-400 dark:hover:bg-cyan-900/20"

      :purple ->
        "#{base_classes} hover:text-purple-600 hover:bg-purple-50 dark:hover:text-purple-400 dark:hover:bg-purple-900/20"

      :rose ->
        "#{base_classes} hover:text-rose-600 hover:bg-rose-50 dark:hover:text-rose-400 dark:hover:bg-rose-900/20"

      :amber ->
        "#{base_classes} hover:text-amber-600 hover:bg-amber-50 dark:hover:text-amber-400 dark:hover:bg-amber-900/20"

      :orange ->
        "#{base_classes} hover:text-orange-600 hover:bg-orange-50 dark:hover:text-orange-400 dark:hover:bg-orange-900/20"

      :indigo ->
        "#{base_classes} hover:text-indigo-600 hover:bg-indigo-50 dark:hover:text-indigo-400 dark:hover:bg-indigo-900/20"

      :pink ->
        "#{base_classes} hover:text-pink-600 hover:bg-pink-50 dark:hover:text-pink-400 dark:hover:bg-pink-900/20"

      _ ->
        "#{base_classes} hover:text-slate-600 hover:bg-slate-50 dark:hover:text-slate-400 dark:hover:bg-slate-900/20"
    end
  end

  # Color indicator with gradient and ring following liquid metal patterns
  def get_group_color_indicator_classes(color) do
    case color do
      :teal ->
        "bg-gradient-to-br from-teal-400 to-teal-500 ring-2 ring-teal-500/20"

      :emerald ->
        "bg-gradient-to-br from-emerald-400 to-emerald-500 ring-2 ring-emerald-500/20"

      :cyan ->
        "bg-gradient-to-br from-cyan-400 to-cyan-500 ring-2 ring-cyan-500/20"

      :purple ->
        "bg-gradient-to-br from-purple-400 to-purple-500 ring-2 ring-purple-500/20"

      :rose ->
        "bg-gradient-to-br from-rose-400 to-rose-500 ring-2 ring-rose-500/20"

      :amber ->
        "bg-gradient-to-br from-amber-400 to-amber-500 ring-2 ring-amber-500/20"

      :orange ->
        "bg-gradient-to-br from-orange-400 to-orange-500 ring-2 ring-orange-500/20"

      :indigo ->
        "bg-gradient-to-br from-indigo-400 to-indigo-500 ring-2 ring-indigo-500/20"

      :pink ->
        "bg-gradient-to-br from-pink-400 to-pink-500 ring-2 ring-pink-500/20"

      _ ->
        "bg-gradient-to-br from-slate-400 to-slate-500 ring-2 ring-slate-500/20"
    end
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
  attr :current_index, :integer, default: 0
  attr :can_download, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :class, :any, default: ""

  def liquid_image_modal(assigns) do
    images_json = Jason.encode!(assigns.images || [])
    assigns = assign(assigns, :images_json, images_json)

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
                <%!-- Download button - only show if user has photos permission --%>
                <.liquid_button
                  :if={@can_download && @images != []}
                  id={"download-photo-button-#{@id}"}
                  size="sm"
                  variant="ghost"
                  color="emerald"
                  icon="hero-arrow-down-tray"
                  phx-click="download_timeline_image"
                  phx-value-index={@current_index}
                  data-tippy-content="Download photo"
                  phx-hook="TippyHook"
                >
                  Download
                </.liquid_button>

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
                  alt={"Timeline image #{@current_index + 1}"}
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
  Website URL preview card component with loading state.

  Displays a link preview with image, title, and description when available,
  a loading skeleton while fetching, or a simple link fallback.

  ## Examples

      <.website_url_preview
        preview={@website_url_preview}
        loading={@website_url_preview_loading}
        url={@decrypted_website_url}
        label="My Website"
      />
  """
  attr :preview, :map, default: nil, doc: "The preview map with image, title, description keys"
  attr :loading, :boolean, default: false, doc: "Whether the preview is currently loading"
  attr :url, :string, required: true, doc: "The decrypted website URL"
  attr :label, :string, default: "Website", doc: "Label shown above the preview"

  def website_url_preview(assigns) do
    ~H"""
    <div :if={@url && @url != ""} class="flex items-start gap-3">
      <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-100 to-purple-100 dark:from-violet-900/30 dark:to-purple-900/30">
        <.phx_icon name="hero-globe-alt" class="size-5 text-violet-600 dark:text-violet-400" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm text-slate-500 dark:text-slate-400">{@label}</p>

        <a
          :if={@preview && @preview["image"]}
          href={@url}
          target="_blank"
          rel="noopener noreferrer"
          class="block group mt-2"
        >
          <div class="flex gap-3 p-2 rounded-xl border border-violet-200/60 dark:border-violet-700/40 bg-gradient-to-br from-violet-50/50 to-purple-50/50 dark:from-violet-900/10 dark:to-purple-900/10 transition-all duration-300 hover:shadow-md hover:shadow-violet-500/10 hover:border-violet-300 dark:hover:border-violet-600">
            <div class="w-20 h-14 shrink-0 overflow-hidden rounded-lg">
              <img
                src={@preview["image"]}
                alt={@preview["title"] || "Website preview"}
                class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
              />
            </div>
            <div class="flex-1 min-w-0 py-0.5">
              <p
                :if={@preview["title"]}
                class="font-medium text-sm text-slate-900 dark:text-white line-clamp-1 group-hover:text-violet-600 dark:group-hover:text-violet-400 transition-colors"
              >
                {@preview["title"]}
              </p>
              <p
                :if={@preview["description"]}
                class="text-xs text-slate-500 dark:text-slate-400 line-clamp-2 mt-0.5"
              >
                {@preview["description"]}
              </p>
            </div>
          </div>
        </a>

        <div
          :if={@loading}
          class="flex items-center gap-3 p-2 mt-2 rounded-xl border border-violet-200/60 dark:border-violet-700/40 bg-gradient-to-br from-violet-50/50 to-purple-50/50 dark:from-violet-900/10 dark:to-purple-900/10"
        >
          <div class="w-20 h-14 shrink-0 rounded-lg bg-violet-100 dark:bg-violet-900/30 animate-pulse">
          </div>
          <div class="flex-1 space-y-2">
            <div class="h-4 w-3/4 rounded bg-violet-100 dark:bg-violet-900/30 animate-pulse"></div>
            <div class="h-3 w-full rounded bg-violet-100 dark:bg-violet-900/30 animate-pulse"></div>
          </div>
        </div>

        <a
          :if={(!@preview || !@preview["image"]) && !@loading}
          href={@url}
          target="_blank"
          rel="noopener noreferrer"
          class="text-slate-900 dark:text-white hover:text-violet-600 dark:hover:text-violet-400 transition-colors truncate block"
        >
          {@url}
        </a>
      </div>
    </div>
    """
  end

  # Badge classes with subtle background and matching text colors
  def get_group_badge_classes(color) do
    case color do
      :teal ->
        "bg-teal-100/80 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300"

      :emerald ->
        "bg-emerald-100/80 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300"

      :cyan ->
        "bg-cyan-100/80 dark:bg-cyan-900/30 text-cyan-700 dark:text-cyan-300"

      :purple ->
        "bg-purple-100/80 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300"

      :rose ->
        "bg-rose-100/80 dark:bg-rose-900/30 text-rose-700 dark:text-rose-300"

      :amber ->
        "bg-amber-100/80 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300"

      :orange ->
        "bg-orange-100/80 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300"

      :indigo ->
        "bg-indigo-100/80 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300"

      _ ->
        "bg-slate-100/80 dark:bg-slate-900/30 text-slate-700 dark:text-slate-300"
    end
  end

  @doc """
  Public group card with liquid metal styling for discovery/join UI.

  ## Examples

      <.liquid_group_card
        name="My Group"
        member_count={5}
        require_password={false}
        group_id="123"
      />
  """
  attr :name, :string, required: true
  attr :member_count, :integer, required: true
  attr :require_password, :boolean, default: false
  attr :group_id, :string, required: true
  attr :visible_members, :integer, default: 3
  attr :class, :any, default: ""
  attr :rest, :global

  def liquid_group_card(assigns) do
    assigns = assign(assigns, :avatar_count, min(assigns.member_count, assigns.visible_members))

    assigns =
      assign(assigns, :overflow_count, max(0, assigns.member_count - assigns.visible_members))

    ~H"""
    <div
      class={[
        "group/card relative rounded-2xl overflow-hidden",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "hover:border-cyan-300/50 dark:hover:border-cyan-600/50",
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "hover:shadow-xl hover:shadow-cyan-500/10 dark:hover:shadow-cyan-400/10",
        "transition-all duration-300 ease-out transform-gpu will-change-transform",
        "hover:-translate-y-0.5",
        @class
      ]}
      {@rest}
    >
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-300 ease-out bg-gradient-to-r from-cyan-50/60 via-teal-50/80 to-emerald-50/60 dark:from-cyan-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 transform-gpu">
      </div>
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-cyan-200/30 to-transparent dark:via-cyan-400/15 transform-gpu group-hover/card:translate-x-full -translate-x-full">
      </div>

      <div class="relative p-4 sm:p-5">
        <div class="flex gap-4">
          <div class="relative flex h-12 w-12 shrink-0 items-center justify-center rounded-xl overflow-hidden transition-all duration-200 ease-out transform-gpu will-change-transform bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 group-hover/card:from-cyan-100 group-hover/card:via-teal-50 group-hover/card:to-emerald-100 dark:group-hover/card:from-cyan-900/30 dark:group-hover/card:via-teal-900/25 dark:group-hover/card:to-emerald-900/30 shadow-sm">
            <.phx_icon
              name="hero-globe-alt"
              class={[
                "h-6 w-6 transition-colors duration-200",
                "text-slate-500 dark:text-slate-400",
                "group-hover/card:text-cyan-600 dark:group-hover/card:text-cyan-400"
              ]}
            />
          </div>

          <div class="flex-1 min-w-0 pt-0.5">
            <div class="flex items-start justify-between gap-3 mb-1.5">
              <div class="flex items-center gap-2 flex-wrap min-w-0">
                <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate group-hover/card:text-cyan-700 dark:group-hover/card:text-cyan-300 transition-colors duration-200">
                  {@name}
                </h2>
                <span
                  :if={@require_password}
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-amber-100 to-orange-100 text-amber-700 dark:from-amber-900/40 dark:to-orange-900/40 dark:text-amber-300 shrink-0"
                >
                  <.phx_icon name="hero-lock-closed" class="h-3 w-3" /> Protected
                </span>
              </div>

              <div :if={@avatar_count > 0} class="isolate flex -space-x-2 shrink-0">
                <div
                  :for={_ <- 1..@avatar_count}
                  class="w-7 h-7 rounded-full bg-gradient-to-br from-cyan-100 to-teal-100 dark:from-cyan-900/40 dark:to-teal-900/40 border-2 border-white dark:border-slate-800 flex items-center justify-center"
                >
                  <.phx_icon name="hero-user" class="w-3.5 h-3.5 text-cyan-600 dark:text-cyan-400" />
                </div>
                <div
                  :if={@overflow_count > 0}
                  class="w-7 h-7 rounded-full bg-slate-100 dark:bg-slate-700 border-2 border-white dark:border-slate-800 flex items-center justify-center text-xs font-medium text-slate-600 dark:text-slate-400"
                >
                  +{@overflow_count}
                </div>
              </div>
            </div>

            <p class="text-sm text-slate-600 dark:text-slate-400">
              {@member_count} {if @member_count == 1, do: "member", else: "members"}
            </p>
          </div>
        </div>

        <div class="relative mt-4 pt-3 border-t border-slate-100 dark:border-slate-700/50 flex items-center justify-end">
          <.liquid_button
            phx-click="join_public_group"
            phx-value-id={@group_id}
            size="sm"
            color="cyan"
            icon={if @require_password, do: "hero-lock-closed", else: "hero-arrow-right"}
          >
            Join Circle
          </.liquid_button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Liquid tab bar component with consistent styling across the app.

  ## Examples

      <.liquid_tab_bar>
        <:tab id="my_groups" icon="hero-user-group" active={@active_tab == "my_groups"} count={5}>
          My Groups
        </:tab>
        <:tab id="discover" icon="hero-globe-alt" active={@active_tab == "discover"} color="cyan">
          Discover
        </:tab>
      </.liquid_tab_bar>
  """
  attr :class, :any, default: ""

  slot :tab, required: true do
    attr :id, :string, required: true
    attr :icon, :string
    attr :active, :boolean
    attr :count, :integer
    attr :color, :string
  end

  attr :rest, :global, include: ~w(phx-click)

  def liquid_tab_bar(assigns) do
    ~H"""
    <div class={["border-b border-slate-200/60 dark:border-slate-700/60", @class]}>
      <nav class="flex" aria-label="Tabs">
        <button
          :for={tab <- @tab}
          type="button"
          phx-click="switch_tab"
          phx-value-tab={tab.id}
          class={[
            "flex-1 sm:flex-none px-4 sm:px-6 py-3 sm:py-4 text-sm font-medium border-b-2 transition-all duration-200 focus:outline-none touch-manipulation",
            tab_active_classes(tab[:active], tab[:color] || "teal")
          ]}
        >
          <span class="flex items-center justify-center sm:justify-start gap-2">
            <.phx_icon :if={tab[:icon]} name={tab.icon} class="w-4 h-4" />
            <span class="truncate">{render_slot(tab)}</span>
            <span
              :if={tab[:count] && tab[:count] > 0}
              class={[
                "ml-1 px-2 py-0.5 rounded-full text-xs",
                tab_count_classes(tab[:active], tab[:color] || "teal")
              ]}
            >
              {tab.count}
            </span>
          </span>
        </button>
      </nav>
    </div>
    """
  end

  defp tab_active_classes(true, color) do
    case color do
      "cyan" ->
        "border-cyan-500 text-cyan-600 dark:text-cyan-400 bg-cyan-50/50 dark:bg-cyan-900/20"

      "emerald" ->
        "border-emerald-500 text-emerald-600 dark:text-emerald-400 bg-emerald-50/50 dark:bg-emerald-900/20"

      _ ->
        "border-teal-500 text-teal-600 dark:text-teal-400 bg-teal-50/50 dark:bg-teal-900/20"
    end
  end

  defp tab_active_classes(_, _color) do
    "border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:border-slate-300 dark:hover:border-slate-600"
  end

  defp tab_count_classes(true, color) do
    case color do
      "cyan" -> "bg-cyan-100 text-cyan-700 dark:bg-cyan-900/50 dark:text-cyan-300"
      "emerald" -> "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/50 dark:text-emerald-300"
      _ -> "bg-teal-100 text-teal-700 dark:bg-teal-900/50 dark:text-teal-300"
    end
  end

  defp tab_count_classes(_, _color) do
    "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400"
  end

  @doc """
  My Groups card for responsive display (card on mobile, row-like on desktop).

  ## Examples

      <.liquid_my_group_card
        id="group-123"
        name="My Group"
        description="Group description"
        is_public={false}
        can_edit={true}
        can_delete={true}
        group_id="123"
        navigate_url="/app/circles/123"
        edit_url="/app/circles/123/edit"
      >
        <:members>
          <.group_avatar ... />
        </:members>
      </.liquid_my_group_card>
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :description, :string, default: nil
  attr :is_public, :boolean, default: false
  attr :can_edit, :boolean, default: false
  attr :can_delete, :boolean, default: false
  attr :group_id, :string, required: true
  attr :navigate_url, :string, required: true
  attr :edit_url, :string, default: nil
  attr :class, :any, default: ""
  slot :members

  def liquid_my_group_card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "group/card relative rounded-2xl overflow-hidden cursor-pointer",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "hover:border-teal-300/50 dark:hover:border-teal-600/50",
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "hover:shadow-xl hover:shadow-teal-500/10 dark:hover:shadow-teal-400/10",
        "transition-all duration-300 ease-out transform-gpu will-change-transform",
        "hover:-translate-y-0.5",
        @class
      ]}
      phx-click={JS.navigate(@navigate_url)}
    >
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/60 via-emerald-50/80 to-cyan-50/60 dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15 transform-gpu">
      </div>
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 transform-gpu group-hover/card:translate-x-full -translate-x-full">
      </div>

      <div class="relative p-4 sm:p-5">
        <div class="flex gap-4">
          <div class="relative flex h-12 w-12 shrink-0 items-center justify-center rounded-xl overflow-hidden transition-all duration-200 ease-out transform-gpu will-change-transform bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700 group-hover/card:from-teal-100 group-hover/card:via-emerald-50 group-hover/card:to-cyan-100 dark:group-hover/card:from-teal-900/30 dark:group-hover/card:via-emerald-900/25 dark:group-hover/card:to-cyan-900/30 shadow-sm">
            <.phx_icon
              name={if @is_public, do: "hero-globe-alt", else: "hero-circle-stack"}
              class={[
                "h-6 w-6 transition-colors duration-200",
                "text-slate-500 dark:text-slate-400",
                "group-hover/card:text-teal-600 dark:group-hover/card:text-teal-400"
              ]}
            />
          </div>

          <div class="flex-1 min-w-0 pt-0.5">
            <div class="flex items-start justify-between gap-3 mb-1.5">
              <div class="flex items-center gap-2 flex-wrap min-w-0">
                <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate group-hover/card:text-teal-700 dark:group-hover/card:text-teal-300 transition-colors duration-200">
                  {@name}
                </h2>
                <span
                  :if={@is_public}
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-cyan-100 to-teal-100 text-cyan-700 dark:from-cyan-900/40 dark:to-teal-900/40 dark:text-cyan-300 shrink-0"
                >
                  <.phx_icon name="hero-globe-alt" class="h-3 w-3 mr-1" /> Public
                </span>
              </div>

              <div :if={render_slot(@members) != []} class="isolate flex -space-x-2 shrink-0 mr-6">
                {render_slot(@members)}
              </div>
            </div>

            <p
              :if={@description}
              class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2 leading-relaxed"
            >
              {@description}
            </p>
            <p
              :if={!@description}
              class="text-sm text-slate-400 dark:text-slate-500 italic"
            >
              No description
            </p>
          </div>
        </div>

        <div
          :if={@can_edit || @can_delete}
          class="relative mt-4 pt-3 border-t border-slate-100 dark:border-slate-700/50 flex items-center justify-end gap-2"
        >
          <.link
            :if={@can_edit && @edit_url}
            patch={@edit_url}
            phx-click-stop-propagation
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-100 dark:bg-slate-700/50 hover:bg-teal-100 hover:text-teal-700 dark:hover:bg-teal-900/30 dark:hover:text-teal-400 transition-all duration-200"
          >
            <.phx_icon name="hero-pencil-square" class="h-3.5 w-3.5" /> Edit
          </.link>
          <button
            :if={@can_delete}
            phx-click={JS.push("delete", value: %{id: @group_id}) |> JS.hide(to: "##{@id}")}
            phx-click-stop-propagation
            data-confirm="Are you sure you want to delete this group?"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium text-slate-600 dark:text-slate-400 bg-slate-100 dark:bg-slate-700/50 hover:bg-rose-100 hover:text-rose-700 dark:hover:bg-rose-900/30 dark:hover:text-rose-400 transition-all duration-200"
          >
            <.phx_icon name="hero-trash" class="h-3.5 w-3.5" /> Delete
          </button>
        </div>
      </div>

      <div class="absolute right-4 top-1/2 -translate-y-1/2 opacity-0 group-hover/card:opacity-100 transition-all duration-200 pointer-events-none">
        <.phx_icon
          name="hero-chevron-right"
          class="h-5 w-5 text-teal-500/60 dark:text-teal-400/60"
        />
      </div>
    </div>
    """
  end

  @doc """
  Card component for pending group invitations with liquid metal styling.

  ## Examples

      <.liquid_pending_group_card
        id="pending-group-123"
        name="My Awesome Group"
        description="A group for awesome people"
        inviter_name="John Doe"
        inserted_at={~U[2024-01-01 12:00:00Z]}
        requires_password={false}
        group_id="123"
      >
        <:members>
          <.avatar src="/avatar.jpg" />
        </:members>
        <:actions>
          <.liquid_button>Join</.liquid_button>
        </:actions>
      </.liquid_pending_group_card>
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :description, :string, default: nil
  attr :inviter_name, :string, required: true
  attr :inserted_at, :any, required: true
  attr :requires_password, :boolean, default: false
  attr :class, :any, default: ""
  slot :members
  slot :actions

  def liquid_pending_group_card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "group/card relative rounded-2xl overflow-hidden",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "hover:border-emerald-300/50 dark:hover:border-emerald-600/50",
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "hover:shadow-xl hover:shadow-emerald-500/10 dark:hover:shadow-emerald-400/10",
        "transition-all duration-300 ease-out transform-gpu will-change-transform",
        "hover:-translate-y-0.5",
        @class
      ]}
    >
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-300 ease-out bg-gradient-to-r from-emerald-50/60 via-teal-50/80 to-cyan-50/60 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-cyan-900/15 transform-gpu">
      </div>
      <div class="absolute inset-0 opacity-0 group-hover/card:opacity-100 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 transform-gpu group-hover/card:translate-x-full -translate-x-full">
      </div>

      <div class="relative p-4 sm:p-5">
        <div class="flex flex-col sm:flex-row gap-4">
          <div class="relative flex h-12 w-12 shrink-0 items-center justify-center rounded-xl overflow-hidden transition-all duration-200 ease-out transform-gpu will-change-transform bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30 shadow-sm">
            <.phx_icon
              name="hero-gift"
              class="h-6 w-6 text-emerald-600 dark:text-emerald-400 transition-transform duration-200 group-hover/card:scale-110"
            />
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between gap-3 mb-2">
              <div class="flex items-center gap-2 flex-wrap min-w-0">
                <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate group-hover/card:text-emerald-700 dark:group-hover/card:text-emerald-300 transition-colors duration-200">
                  {@name}
                </h2>
                <span
                  :if={@requires_password}
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-gradient-to-r from-amber-100 to-orange-100 text-amber-700 dark:from-amber-900/40 dark:to-orange-900/40 dark:text-amber-300 shrink-0"
                >
                  <.phx_icon name="hero-lock-closed" class="h-3 w-3" /> Password
                </span>
              </div>

              <div :if={render_slot(@members) != []} class="isolate flex -space-x-2 shrink-0">
                {render_slot(@members)}
              </div>
            </div>

            <p
              :if={@description}
              class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2 leading-relaxed mb-3"
            >
              {@description}
            </p>
            <p
              :if={!@description}
              class="text-sm text-slate-400 dark:text-slate-500 italic mb-3"
            >
              No description
            </p>

            <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500 dark:text-slate-400">
              <div class="flex items-center gap-1.5">
                <.phx_icon name="hero-user" class="w-3.5 h-3.5" />
                <span class="font-medium text-emerald-700 dark:text-emerald-300">
                  {@inviter_name}
                </span>
                <span>invited you</span>
              </div>
              <span class="text-slate-300 dark:text-slate-600">•</span>
              <time datetime={@inserted_at}>
                <.local_time_ago id={"time-created-#{@id}"} at={@inserted_at} />
              </time>
            </div>
          </div>
        </div>

        <div
          :if={render_slot(@actions) != []}
          class="relative mt-4 pt-3 border-t border-slate-100 dark:border-slate-700/50 flex flex-wrap items-center justify-end gap-2"
        >
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Load more indicator for groups with liquid metal styling.
  Reuses the same pattern as timeline scroll indicator.

  ## Examples

      <.liquid_load_more_groups
        remaining_count={15}
        load_count={10}
        loading={false}
        color="teal"
        phx-click="load_more_groups"
      />
  """
  attr :remaining_count, :integer, default: 0
  attr :load_count, :integer, default: 10
  attr :loading, :boolean, default: false
  attr :color, :string, default: "teal"
  attr :item_label, :string, default: "groups"
  attr :class, :any, default: ""
  attr :rest, :global, include: ~w(phx-click)

  def liquid_load_more_groups(assigns) do
    assigns = assign(assigns, :color_classes, get_load_more_color_classes(assigns.color))

    ~H"""
    <div class={["text-center py-6", @class]}>
      <div
        :if={@loading}
        class="inline-flex items-center gap-3 px-6 py-3 rounded-xl bg-slate-50/80 dark:bg-slate-800/80 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 text-slate-600 dark:text-slate-400"
      >
        <div class={["w-2 h-2 rounded-full animate-pulse", @color_classes.indicator]}></div>
        <span class="text-sm font-medium">Loading more {@item_label}...</span>
      </div>

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
          Load {min(@load_count, @remaining_count)} more {@item_label} ({@remaining_count} remaining)
        </span>
      </button>
    </div>
    """
  end

  defp get_load_more_color_classes(color) do
    case color do
      "teal" ->
        %{
          button:
            "bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-md hover:from-teal-600 hover:to-emerald-600",
          indicator: "bg-white/80"
        }

      "cyan" ->
        %{
          button:
            "bg-gradient-to-r from-cyan-500 to-teal-500 text-white shadow-md hover:from-cyan-600 hover:to-teal-600",
          indicator: "bg-white/80"
        }

      "emerald" ->
        %{
          button:
            "bg-gradient-to-r from-emerald-500 to-teal-500 text-white shadow-md hover:from-emerald-600 hover:to-teal-600",
          indicator: "bg-white/80"
        }

      _ ->
        %{
          button:
            "bg-slate-50/80 dark:bg-slate-800/80 border border-slate-200/60 dark:border-slate-700/60 text-slate-600 dark:text-slate-400 hover:bg-slate-100/80 dark:hover:bg-slate-700/80",
          indicator: "bg-gradient-to-r from-slate-400 to-slate-500"
        }
    end
  end

  @doc """
  Liquid chat message component with premium styling for group chat.

  ## Examples

      <.liquid_chat_message
        id="msg-123"
        avatar_src="/images/avatar.jpg"
        sender_name="John"
        moniker="JD123"
        role={:owner}
        timestamp={~N[2024-01-01 12:00:00]}
        is_own_message={false}
        can_delete={true}
        on_delete="delete_message"
      >
        Hello, this is my message!
      </.liquid_chat_message>
  """
  attr :id, :string, required: true
  attr :avatar_src, :string, required: true
  attr :avatar_alt, :string, default: "User avatar"
  attr :sender_name, :string, required: true
  attr :moniker, :string, required: true
  attr :role, :atom, default: :member
  attr :timestamp, :any, required: true
  attr :is_own_message, :boolean, default: false
  attr :can_delete, :boolean, default: false
  attr :on_delete, :string, default: nil
  attr :is_grouped, :boolean, default: false
  attr :show_date_separator, :boolean, default: false
  attr :message_date, Date, default: nil
  attr :class, :any, default: ""
  slot :inner_block, required: true

  def liquid_chat_message(assigns) do
    ~H"""
    <div>
      <.liquid_chat_date_separator :if={@show_date_separator && @message_date} date={@message_date} />
      <div
        id={@id}
        class={[
          "group/msg relative flex",
          if(@is_own_message, do: "justify-end", else: "justify-start"),
          @class
        ]}
      >
        <div class={[
          "relative rounded-2xl transition-all duration-300 ease-out max-w-[85%] sm:max-w-[75%]",
          "hover:bg-gradient-to-r hover:from-teal-50/50 hover:via-white/70 hover:to-emerald-50/50",
          "dark:hover:from-teal-900/20 dark:hover:via-slate-800/50 dark:hover:to-emerald-900/20",
          if(@is_grouped, do: "py-1 px-3 sm:px-4", else: "py-2.5 px-3 sm:px-4")
        ]}>
          <div class="flex items-start gap-3">
            <div :if={!@is_grouped && !@is_own_message} class="flex-shrink-0 pt-0.5">
              <div class={[
                "relative w-9 h-9 sm:w-10 sm:h-10 rounded-full overflow-hidden",
                "ring-2 ring-offset-2 ring-offset-white dark:ring-offset-slate-900",
                "transition-all duration-200",
                liquid_chat_avatar_ring(@role)
              ]}>
                <img src={@avatar_src} alt={@avatar_alt} class="w-full h-full object-cover" />
                <div class={[
                  "absolute inset-0 rounded-full opacity-0 group-hover/msg:opacity-100",
                  "bg-gradient-to-br from-white/20 to-transparent",
                  "transition-opacity duration-300"
                ]} />
              </div>
            </div>
            <div :if={@is_grouped && !@is_own_message} class="w-9 sm:w-10 flex-shrink-0" />

            <div class="flex-1 min-w-0">
              <div
                :if={!@is_grouped}
                class={[
                  "flex flex-wrap items-center gap-x-2 gap-y-1 mb-1.5",
                  if(@is_own_message, do: "justify-end", else: "justify-start")
                ]}
              >
                <span
                  :if={@sender_name && !@is_own_message}
                  class={[
                    "font-semibold text-sm truncate max-w-[120px] sm:max-w-[180px]",
                    "text-slate-900 dark:text-slate-100",
                    "group-hover/msg:text-teal-700 dark:group-hover/msg:text-teal-300",
                    "transition-colors duration-200"
                  ]}
                >
                  {@sender_name}
                </span>

                <span
                  :if={!@is_own_message}
                  class={[
                    "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium",
                    "transition-all duration-200",
                    liquid_chat_role_badge(@role)
                  ]}
                >
                  <.phx_icon name="hero-finger-print" class="w-3 h-3" />
                  <span class="truncate max-w-[60px] sm:max-w-[100px]">{@moniker}</span>
                </span>

                <span
                  :if={@is_own_message}
                  class={[
                    "inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-xs font-medium",
                    "bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-700",
                    "dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-300",
                    "border border-teal-200/60 dark:border-teal-700/40"
                  ]}
                >
                  <.phx_icon name="hero-check-mini" class="w-3 h-3" />
                  <span>You</span>
                </span>

                <time
                  id={"time-tooltip-" <> @id}
                  class={[
                    "text-xs whitespace-nowrap cursor-help",
                    "text-slate-500 dark:text-slate-400",
                    "hover:text-slate-700 dark:hover:text-slate-200",
                    "transition-colors duration-150"
                  ]}
                  phx-hook="LocalTimeTooltip"
                  data-timestamp={@timestamp}
                >
                  <.local_time id={@id <> "-created"} for={@timestamp} preset="TIME_SIMPLE" />
                </time>

                <button
                  :if={@can_delete && @on_delete}
                  type="button"
                  phx-click={@on_delete}
                  phx-value-id={@id}
                  class={[
                    "p-1 rounded-lg opacity-0 group-hover/msg:opacity-100 focus:opacity-100",
                    "text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400",
                    "hover:bg-red-50 dark:hover:bg-red-900/20",
                    "transition-all duration-200"
                  ]}
                  aria-label="Delete message"
                >
                  <.phx_icon name="hero-trash" class="w-3.5 h-3.5" />
                </button>
              </div>

              <div class="flex items-center gap-2">
                <div
                  :if={@is_grouped && @can_delete && @on_delete && !@is_own_message}
                  class="flex-shrink-0"
                >
                  <button
                    type="button"
                    phx-click={@on_delete}
                    phx-value-id={@id}
                    class={[
                      "p-1 rounded-lg opacity-0 group-hover/msg:opacity-100 focus:opacity-100",
                      "text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20",
                      "transition-all duration-200"
                    ]}
                    aria-label="Delete message"
                  >
                    <.phx_icon name="hero-trash" class="w-3.5 h-3.5" />
                  </button>
                </div>
                <div class={[
                  "relative rounded-xl sm:rounded-2xl px-3.5 sm:px-4 py-2.5 sm:py-3",
                  "text-sm leading-relaxed",
                  "shadow-sm",
                  "transition-all duration-200",
                  if(@is_own_message,
                    do: [
                      "bg-gradient-to-r from-teal-500 to-emerald-500 dark:from-teal-600 dark:to-emerald-600",
                      "text-white",
                      "border border-teal-400/40 dark:border-teal-500/50",
                      "shadow-lg shadow-teal-500/25 dark:shadow-teal-500/15",
                      "group-hover/msg:shadow-xl group-hover/msg:shadow-teal-500/30 dark:group-hover/msg:shadow-teal-400/20",
                      "group-hover/msg:scale-[1.01]"
                    ],
                    else: [
                      "bg-white/95 dark:bg-slate-800/80 backdrop-blur-sm",
                      "border border-slate-200/60 dark:border-slate-700/50",
                      "group-hover/msg:border-teal-200/60 dark:group-hover/msg:border-teal-700/50",
                      "group-hover/msg:shadow-md group-hover/msg:shadow-teal-500/5 dark:group-hover/msg:shadow-teal-400/5"
                    ]
                  )
                ]}>
                  <div class={[
                    "prose prose-sm max-w-none prose-p:my-0.5 prose-headings:mt-2 prose-headings:mb-1 prose-ul:my-1 prose-ol:my-1 prose-li:my-0 prose-pre:my-1.5 break-words",
                    if(@is_own_message,
                      do:
                        "text-white prose-headings:text-white prose-strong:text-white prose-code:text-teal-100 prose-code:bg-white/10 prose-a:text-teal-100 prose-a:no-underline hover:prose-a:underline",
                      else:
                        "prose-slate dark:prose-invert prose-code:text-teal-600 dark:prose-code:text-teal-400 prose-a:text-teal-600 dark:prose-a:text-teal-400 prose-a:no-underline hover:prose-a:underline"
                    )
                  ]}>
                    {render_slot(@inner_block)}
                  </div>
                </div>
                <div
                  :if={@is_grouped && @can_delete && @on_delete && @is_own_message}
                  class="flex-shrink-0"
                >
                  <button
                    type="button"
                    phx-click={@on_delete}
                    phx-value-id={@id}
                    class={[
                      "p-1 rounded-lg opacity-0 group-hover/msg:opacity-100 focus:opacity-100",
                      "text-slate-400 hover:text-red-500 dark:text-slate-500 dark:hover:text-red-400",
                      "hover:bg-red-50 dark:hover:bg-red-900/20",
                      "transition-all duration-200"
                    ]}
                    aria-label="Delete message"
                  >
                    <.phx_icon name="hero-trash" class="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp liquid_chat_avatar_ring(:owner), do: "ring-pink-400 dark:ring-pink-500"
  defp liquid_chat_avatar_ring(:admin), do: "ring-orange-400 dark:ring-orange-500"
  defp liquid_chat_avatar_ring(:moderator), do: "ring-purple-400 dark:ring-purple-500"
  defp liquid_chat_avatar_ring(:member), do: "ring-emerald-400 dark:ring-emerald-500"
  defp liquid_chat_avatar_ring(_), do: "ring-teal-300 dark:ring-teal-500"

  defp liquid_chat_role_badge(:owner) do
    "bg-gradient-to-r from-pink-100 to-rose-50 text-pink-700 dark:from-pink-900/50 dark:to-rose-900/30 dark:text-pink-300"
  end

  defp liquid_chat_role_badge(:admin) do
    "bg-gradient-to-r from-orange-100 to-amber-50 text-orange-700 dark:from-orange-900/50 dark:to-amber-900/30 dark:text-orange-300"
  end

  defp liquid_chat_role_badge(:moderator) do
    "bg-gradient-to-r from-purple-100 to-indigo-50 text-purple-700 dark:from-purple-900/50 dark:to-indigo-900/30 dark:text-purple-300"
  end

  defp liquid_chat_role_badge(:member) do
    "bg-gradient-to-r from-emerald-100 to-teal-50 text-emerald-700 dark:from-emerald-900/50 dark:to-teal-900/30 dark:text-emerald-300"
  end

  defp liquid_chat_role_badge(_) do
    "bg-gradient-to-r from-teal-100 to-emerald-50 text-teal-700 dark:from-teal-900/50 dark:to-emerald-900/30 dark:text-teal-300"
  end

  @doc """
  Date separator for chat messages.

  ## Examples

      <.liquid_chat_date_separator date={~D[2024-01-15]} />
  """
  attr :date, Date, required: true
  attr :class, :any, default: ""

  def liquid_chat_date_separator(assigns) do
    ~H"""
    <div class={["flex items-center gap-3 py-3", @class]}>
      <div class="flex-1 h-px bg-gradient-to-r from-transparent via-slate-200/60 to-slate-200/40 dark:via-slate-700/60 dark:to-slate-700/40" />
      <span class={[
        "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium",
        "bg-gradient-to-r from-slate-100/80 via-white/60 to-slate-100/80",
        "dark:from-slate-800/80 dark:via-slate-700/60 dark:to-slate-800/80",
        "text-slate-500 dark:text-slate-400",
        "border border-slate-200/40 dark:border-slate-700/40",
        "shadow-sm"
      ]}>
        <.phx_icon name="hero-calendar-days" class="w-3.5 h-3.5" />
        {format_chat_date(@date)}
      </span>
      <div class="flex-1 h-px bg-gradient-to-r from-slate-200/40 via-slate-200/60 to-transparent dark:from-slate-700/40 dark:via-slate-700/60" />
    </div>
    """
  end

  defp format_chat_date(date) do
    today = Date.utc_today()
    yesterday = Date.add(today, -1)

    cond do
      Date.compare(date, today) == :eq -> "Today"
      Date.compare(date, yesterday) == :eq -> "Yesterday"
      Date.diff(today, date) < 7 -> Calendar.strftime(date, "%A")
      date.year == today.year -> Calendar.strftime(date, "%B %d")
      true -> Calendar.strftime(date, "%B %d, %Y")
    end
  end

  @doc """
  Timeline date separator with enhanced visual design.

  A visually prominent date separator for timeline posts with subtle animation
  and improved readability.

  ## Examples

      <.liquid_timeline_date_separator date={~D[2024-01-15]} />
      <.liquid_timeline_date_separator date={~D[2024-01-15]} color="orange" />
  """
  attr :date, Date, required: true
  attr :class, :any, default: ""
  attr :first, :boolean, default: false, doc: "Whether this is the first separator (no top line)"
  attr :color, :string, default: "emerald", doc: "Color theme: emerald or orange"

  def liquid_timeline_date_separator(assigns) do
    color_classes =
      case assigns.color do
        "orange" ->
          %{
            line_top: "bg-gradient-to-b from-transparent to-orange-400/50 dark:to-orange-500/40",
            dot: "bg-orange-500 dark:bg-orange-400 shadow-orange-500/30",
            line_bottom:
              "bg-gradient-to-b from-orange-400/50 to-transparent dark:from-orange-500/40",
            text: "text-orange-600 dark:text-orange-400"
          }

        _ ->
          %{
            line_top:
              "bg-gradient-to-b from-transparent to-emerald-400/50 dark:to-emerald-500/40",
            dot: "bg-emerald-500 dark:bg-emerald-400 shadow-emerald-500/30",
            line_bottom:
              "bg-gradient-to-b from-emerald-400/50 to-transparent dark:from-emerald-500/40",
            text: "text-emerald-600 dark:text-emerald-400"
          }
      end

    assigns = assign(assigns, :color_classes, color_classes)

    ~H"""
    <div class={["flex items-center py-1", @class]}>
      <div class="flex items-center gap-2.5 pl-1">
        <div class="flex flex-col items-center">
          <div class={[
            "w-px h-3",
            !@first && @color_classes.line_top,
            @first && "bg-transparent"
          ]} />
          <div class={[
            "w-2.5 h-2.5 rounded-full shadow-sm ring-2 ring-white dark:ring-slate-900",
            @color_classes.dot
          ]} />
          <div class={["w-px h-3", @color_classes.line_bottom]} />
        </div>
        <div class={["flex items-center gap-1.5 text-xs font-medium", @color_classes.text]}>
          <.phx_icon name="hero-calendar-days-mini" class="w-3.5 h-3.5" />
          <span>{format_chat_date(@date)}</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Timeline read posts divider with expand/collapse functionality.

  A beautiful animated divider that separates unread posts from read posts,
  with smooth animations and loading states.

  ## Examples

      <.liquid_read_posts_divider
        count={5}
        expanded={false}
        loading={false}
        tab_color="emerald"
      />
  """
  attr :count, :integer, required: true
  attr :expanded, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :tab_color, :string, default: "emerald"
  attr :class, :any, default: ""

  def liquid_read_posts_divider(assigns) do
    assigns = assign(assigns, :color_classes, get_tab_color_classes(assigns.tab_color))

    ~H"""
    <div class={["relative py-6", @class]}>
      <div class="absolute inset-0 flex items-center" aria-hidden="true">
        <div class={[
          "w-full h-px bg-gradient-to-r from-transparent to-transparent",
          @color_classes.divider_line
        ]} />
      </div>

      <div class="relative flex justify-center">
        <button
          type="button"
          phx-click="toggle_read_posts"
          disabled={@loading}
          class={[
            "group inline-flex items-center gap-2.5 px-5 py-2.5 rounded-full",
            "bg-white dark:bg-slate-800",
            "border",
            @color_classes.border,
            "shadow-lg shadow-slate-900/5 dark:shadow-black/20",
            "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-black/30",
            @color_classes.hover_border,
            "focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-slate-900",
            @color_classes.focus_ring,
            "transition-all duration-300 ease-out",
            "transform hover:scale-[1.02] active:scale-[0.98]",
            "phx-click-loading:cursor-wait phx-click-loading:opacity-90",
            @loading && "cursor-wait opacity-80"
          ]}
        >
          <div class="phx-click-loading:flex hidden items-center gap-2">
            <div class={[
              "h-4 w-4 animate-spin rounded-full border-2",
              @color_classes.spinner
            ]} />
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">
              {if @expanded, do: "Hiding...", else: "Loading..."}
            </span>
          </div>

          <div :if={@loading} class="phx-click-loading:hidden flex items-center gap-2">
            <div class={[
              "h-4 w-4 animate-spin rounded-full border-2",
              @color_classes.spinner
            ]} />
            <span class="text-sm font-medium text-slate-600 dark:text-slate-300">
              Loading posts...
            </span>
          </div>

          <div :if={!@loading} class="phx-click-loading:hidden flex items-center gap-2.5">
            <div class={[
              "flex items-center justify-center w-6 h-6 rounded-full",
              "bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-700 dark:to-slate-800",
              @color_classes.icon_bg_hover,
              "transition-all duration-300"
            ]}>
              <.phx_icon
                name={if @expanded, do: "hero-chevron-up", else: "hero-chevron-down"}
                class={[
                  "w-3.5 h-3.5 text-slate-500 dark:text-slate-400",
                  @color_classes.icon_hover,
                  "transition-all duration-300",
                  @expanded && "rotate-180"
                ]}
              />
            </div>

            <span class="text-sm font-medium text-slate-600 dark:text-slate-300 group-hover:text-slate-800 dark:group-hover:text-slate-100 transition-colors">
              <%= if @expanded do %>
                Hide read posts
              <% else %>
                <span class="text-slate-500 dark:text-slate-400">Show</span>
                <span class={[
                  "inline-flex items-center justify-center min-w-[1.5rem] px-1.5 py-0.5 mx-1",
                  "text-xs font-semibold rounded-full",
                  "text-white shadow-sm",
                  @color_classes.badge
                ]}>
                  {@count}
                </span>
                <span class="text-slate-500 dark:text-slate-400">read posts</span>
              <% end %>
            </span>

            <div
              :if={!@expanded}
              class={[
                "flex items-center justify-center w-6 h-6 rounded-full",
                "bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-700 dark:to-slate-800",
                @color_classes.icon_bg_hover,
                "transition-all duration-300"
              ]}
            >
              <.phx_icon
                name="hero-eye"
                class={[
                  "w-3.5 h-3.5 text-slate-400 dark:text-slate-500",
                  @color_classes.icon_hover,
                  "transition-colors duration-300"
                ]}
              />
            </div>
          </div>
        </button>
      </div>

      <div
        :if={@expanded && !@loading}
        class="absolute left-0 right-0 bottom-0 flex items-center hidden"
        aria-hidden="true"
      >
        <div class="w-full h-px bg-gradient-to-r from-transparent via-emerald-300/40 to-transparent dark:via-emerald-600/40 animate-pulse" />
      </div>
    </div>
    """
  end

  @doc """
  Sync status indicator for native apps showing online/offline state, sync progress, and last synced time.

  Only displayed when running on native platforms (desktop/mobile).

  ## Examples

      <.liquid_sync_status
        online={true}
        syncing={false}
        last_sync={~U[2025-01-01 12:00:00Z]}
        pending_count={0}
      />
  """
  attr :online, :boolean, default: true
  attr :syncing, :boolean, default: false
  attr :last_sync, :any, default: nil
  attr :pending_count, :integer, default: 0
  attr :class, :string, default: nil

  def liquid_sync_status(assigns) do
    ~H"""
    <div
      id="sync-status-indicator"
      class={[
        "group relative flex items-center gap-2 px-3 py-1.5 rounded-full text-sm",
        "transition-all duration-300 ease-out cursor-default",
        cond do
          @syncing ->
            "bg-gradient-to-r from-blue-50/80 to-cyan-50/80 dark:from-blue-900/30 dark:to-cyan-900/30 border border-blue-200/60 dark:border-blue-700/60"

          not @online ->
            "bg-gradient-to-r from-amber-50/80 to-orange-50/80 dark:from-amber-900/30 dark:to-orange-900/30 border border-amber-200/60 dark:border-amber-700/60"

          true ->
            "bg-gradient-to-r from-emerald-50/60 to-teal-50/60 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/40 dark:border-emerald-700/40"
        end,
        @class
      ]}
    >
      <div class="flex items-center gap-1.5">
        <%= cond do %>
          <% @syncing -> %>
            <div class="relative">
              <.phx_icon
                name="hero-arrow-path"
                class="h-4 w-4 text-blue-500 dark:text-blue-400 animate-spin"
              />
            </div>
            <span class="text-xs font-medium text-blue-700 dark:text-blue-300">
              Syncing{if @pending_count > 0, do: " (#{@pending_count})"}
            </span>
          <% not @online -> %>
            <div class="relative flex items-center justify-center">
              <span class="absolute w-2 h-2 bg-amber-400 dark:bg-amber-500 rounded-full animate-ping opacity-75" />
              <span class="relative w-2 h-2 bg-amber-500 dark:bg-amber-400 rounded-full" />
            </div>
            <span class="text-xs font-medium text-amber-700 dark:text-amber-300">
              Offline
            </span>
          <% true -> %>
            <div class="relative flex items-center justify-center">
              <span class="w-2 h-2 bg-emerald-500 dark:bg-emerald-400 rounded-full" />
            </div>
            <span class="text-xs font-medium text-emerald-700 dark:text-emerald-300">
              Synced
            </span>
        <% end %>
      </div>

      <div
        :if={@last_sync && @online && !@syncing}
        class="text-xs text-slate-500 dark:text-slate-400 pl-1.5 border-l border-slate-200/60 dark:border-slate-700/60"
      >
        <.local_time_ago id="sync-last-sync-time" at={@last_sync} />
      </div>

      <div
        :if={@pending_count > 0 && !@syncing}
        class="flex items-center gap-1 text-xs text-amber-600 dark:text-amber-400 pl-1.5 border-l border-slate-200/60 dark:border-slate-700/60"
      >
        <.phx_icon name="hero-clock" class="h-3 w-3" />
        <span>{@pending_count} pending</span>
      </div>
    </div>
    """
  end

  @doc """
  A simplified timeline card for public/discover pages with orange/amber theme.

  ## Examples

      <.public_timeline_card
        user_name="Jane Doe"
        user_handle="@jane"
        timestamp="2 hours ago"
        content="This is a public post..."
        images={["/uploads/image1.jpg"]}
        stats={%{replies: 3, likes: 12}}
      />
  """
  attr :id, :string, required: true
  attr :user_name, :string, required: true
  attr :user_handle, :string, required: true
  attr :user_avatar, :string, default: nil
  attr :author_profile_slug, :string, default: nil
  attr :author_profile_visibility, :atom, default: nil
  attr :timestamp, :string, required: true
  attr :content, :string, required: true
  attr :images, :list, default: []
  attr :stats, :map, default: %{}
  attr :content_warning?, :boolean, default: false
  attr :content_warning, :any, default: nil
  attr :content_warning_category, :any, default: nil
  attr :decrypted_url_preview, :any, default: nil
  attr :url_preview_fetched_at, :any, default: nil
  attr :class, :any, default: ""

  def public_timeline_card(assigns) do
    ~H"""
    <article
      id={@id}
      phx-hook="TouchHoverHook"
      class={[
        "group relative rounded-2xl transition-all duration-300 ease-out",
        "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
        "border border-orange-200/60 dark:border-orange-800/40",
        "shadow-lg shadow-orange-900/5 dark:shadow-orange-900/20",
        "hover:shadow-xl hover:shadow-orange-900/10 dark:hover:shadow-orange-900/30",
        "hover:border-orange-300/60 dark:hover:border-orange-700/60",
        "transform-gpu will-change-transform",
        @class
      ]}
    >
      <div class={[
        "absolute inset-0 rounded-2xl opacity-0 transition-all duration-500 ease-out",
        "group-hover:opacity-100 touch-hover:opacity-100",
        "bg-gradient-to-br from-orange-50/30 via-amber-50/20 to-yellow-50/30 dark:from-orange-900/10 dark:via-amber-900/5 dark:to-yellow-900/10"
      ]}>
      </div>

      <div class="absolute right-0 top-4 bottom-4 w-1 bg-gradient-to-b from-orange-400 via-amber-400 to-orange-400 dark:from-orange-500 dark:via-amber-500 dark:to-orange-500 rounded-l-full opacity-50">
      </div>

      <div class="relative p-4 sm:p-5">
        <div class="flex items-start gap-3 sm:gap-4">
          <%= if can_view_profile?(@author_profile_visibility) && @author_profile_slug do %>
            <.link navigate={~p"/profile/#{@author_profile_slug}"} class="shrink-0 group/avatar">
              <div class="relative">
                <%= if @user_avatar do %>
                  <img
                    src={@user_avatar}
                    alt={@user_name}
                    class="w-10 h-10 sm:w-11 sm:h-11 rounded-xl object-cover ring-2 ring-orange-200/50 dark:ring-orange-700/50 group-hover/avatar:ring-orange-300 dark:group-hover/avatar:ring-orange-600 transition-all duration-200"
                  />
                <% else %>
                  <div class="w-10 h-10 sm:w-11 sm:h-11 rounded-xl bg-gradient-to-br from-orange-400 to-amber-500 flex items-center justify-center ring-2 ring-orange-200/50 dark:ring-orange-700/50 group-hover/avatar:ring-orange-300 dark:group-hover/avatar:ring-orange-600 transition-all duration-200">
                    <span class="text-white font-semibold text-sm sm:text-base">
                      {String.first(@user_name) |> String.upcase()}
                    </span>
                  </div>
                <% end %>
              </div>
            </.link>
          <% else %>
            <div class="shrink-0">
              <div class="relative">
                <%= if @user_avatar do %>
                  <img
                    src={@user_avatar}
                    alt={@user_name}
                    class="w-10 h-10 sm:w-11 sm:h-11 rounded-xl object-cover ring-2 ring-orange-200/50 dark:ring-orange-700/50"
                  />
                <% else %>
                  <div class="w-10 h-10 sm:w-11 sm:h-11 rounded-xl bg-gradient-to-br from-orange-400 to-amber-500 flex items-center justify-center ring-2 ring-orange-200/50 dark:ring-orange-700/50">
                    <span class="text-white font-semibold text-sm sm:text-base">
                      {String.first(@user_name) |> String.upcase()}
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <%= if can_view_profile?(@author_profile_visibility) && @author_profile_slug do %>
                <.link
                  navigate={~p"/profile/#{@author_profile_slug}"}
                  class="font-semibold text-slate-900 dark:text-slate-100 hover:text-orange-600 dark:hover:text-orange-400 transition-colors truncate"
                >
                  {@user_name}
                </.link>
              <% else %>
                <span class="font-semibold text-slate-900 dark:text-slate-100 truncate">
                  {@user_name}
                </span>
              <% end %>
              <span class="text-slate-500 dark:text-slate-400 text-sm truncate">{@user_handle}</span>
              <span class="text-slate-400 dark:text-slate-500">·</span>
              <span class="text-slate-500 dark:text-slate-400 text-sm whitespace-nowrap">
                {@timestamp}
              </span>
            </div>

            <div class="mt-2 sm:mt-3">
              <%= if @content_warning? do %>
                <.public_content_warning_wrapper
                  id={@id}
                  content_warning={@content_warning}
                  content_warning_category={@content_warning_category}
                >
                  <.public_post_content
                    content={@content}
                    images={@images}
                    url_preview={@decrypted_url_preview}
                    post_id={@id}
                    url_preview_fetched_at={@url_preview_fetched_at}
                  />
                </.public_content_warning_wrapper>
              <% else %>
                <.public_post_content
                  content={@content}
                  images={@images}
                  url_preview={@decrypted_url_preview}
                  post_id={@id}
                  url_preview_fetched_at={@url_preview_fetched_at}
                />
              <% end %>
            </div>

            <div class="mt-3 sm:mt-4 flex items-center gap-4 sm:gap-6 text-slate-500 dark:text-slate-400">
              <div class="flex items-center gap-1.5 text-sm">
                <.phx_icon name="hero-chat-bubble-oval-left" class="h-4 w-4" />
                <span>{Map.get(@stats, :replies, 0)}</span>
              </div>
              <div class="flex items-center gap-1.5 text-sm">
                <.phx_icon name="hero-heart" class="h-4 w-4" />
                <span>{Map.get(@stats, :likes, 0)}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </article>
    """
  end

  attr :id, :string, required: true
  attr :content_warning, :string, default: nil
  attr :content_warning_category, :string, default: nil
  slot :inner_block, required: true

  defp public_content_warning_wrapper(assigns) do
    ~H"""
    <div id={"cw-wrapper-#{@id}"}>
      <div
        id={"cw-overlay-#{@id}"}
        class="relative p-4 bg-gradient-to-br from-amber-50/80 to-orange-50/80 dark:from-amber-900/20 dark:to-orange-900/20 rounded-xl border border-amber-200/60 dark:border-amber-700/40"
      >
        <div class="flex items-start gap-3">
          <div class="shrink-0 p-2 rounded-lg bg-amber-100 dark:bg-amber-900/40">
            <.phx_icon name="hero-eye-slash" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="font-medium text-amber-800 dark:text-amber-200 text-sm">
              Content Warning
            </p>
            <p :if={@content_warning} class="text-amber-700 dark:text-amber-300 text-sm mt-1">
              {@content_warning}
            </p>
            <p
              :if={@content_warning_category}
              class="text-amber-600/80 dark:text-amber-400/80 text-xs mt-1"
            >
              Category: {@content_warning_category}
            </p>
            <button
              type="button"
              phx-click={
                JS.hide(to: "#cw-overlay-#{@id}")
                |> JS.show(to: "#cw-content-#{@id}")
              }
              class="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-amber-700 dark:text-amber-300 bg-amber-100 dark:bg-amber-900/40 hover:bg-amber-200 dark:hover:bg-amber-800/50 rounded-lg transition-colors"
            >
              <.phx_icon name="hero-eye" class="h-3.5 w-3.5" /> Show Content
            </button>
          </div>
        </div>
      </div>
      <div id={"cw-content-#{@id}"} class="hidden">
        {render_slot(@inner_block)}
        <button
          type="button"
          phx-click={
            JS.show(to: "#cw-overlay-#{@id}")
            |> JS.hide(to: "#cw-content-#{@id}")
          }
          class="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-amber-700 dark:text-amber-300 bg-amber-100/80 dark:bg-amber-900/30 hover:bg-amber-200 dark:hover:bg-amber-800/50 rounded-lg transition-colors"
        >
          <.phx_icon name="hero-eye-slash" class="h-3.5 w-3.5" /> Hide Content
        </button>
      </div>
    </div>
    """
  end

  attr :content, :string, required: true
  attr :images, :list, default: []
  attr :url_preview, :any, default: nil
  attr :post_id, :string, required: true
  attr :url_preview_fetched_at, :any, default: nil

  defp public_post_content(assigns) do
    assigns = assign(assigns, :image_count, length(assigns.images))

    ~H"""
    <div class="space-y-3">
      <div class="text-slate-800 dark:text-slate-200 text-sm sm:text-base leading-relaxed whitespace-pre-wrap break-words">
        {format_decrypted_content_orange(@content)}
      </div>

      <div
        :if={@image_count > 0}
        id={"public-post-images-#{@post_id}"}
        phx-hook="PublicPostImagesHook"
        data-post-id={@post_id}
        data-image-count={@image_count}
        class="relative rounded-xl overflow-hidden border border-slate-200/60 dark:border-slate-700/60 mt-3"
      >
        <div class="w-full h-24 sm:h-32 flex items-center justify-center bg-slate-100 dark:bg-slate-800">
          <div class="flex flex-col items-center gap-2">
            <div class="w-6 h-6 rounded-full border-2 border-orange-500/30 border-t-orange-500 animate-spin">
            </div>
            <span class="text-xs text-slate-500 dark:text-slate-400">Loading photos...</span>
          </div>
        </div>
      </div>

      <%= if @url_preview do %>
        <.public_url_preview
          preview={@url_preview}
          post_id={@post_id}
          url_preview_fetched_at={@url_preview_fetched_at}
        />
      <% end %>
    </div>
    """
  end

  attr :preview, :map, required: true
  attr :post_id, :string, required: true
  attr :url_preview_fetched_at, :any, default: nil

  defp public_url_preview(assigns) do
    ~H"""
    <a
      :if={@preview["url"]}
      href={@preview["url"]}
      target="_blank"
      rel="noopener noreferrer"
      class="flex gap-3 p-2 mt-3 rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-slate-50/50 dark:bg-slate-800/50 hover:border-orange-300/60 dark:hover:border-orange-600/60 transition-all duration-200 group/preview"
    >
      <div
        :if={@preview["image"] && @preview["image"] != ""}
        class="w-20 h-14 shrink-0 overflow-hidden rounded-lg bg-slate-100 dark:bg-slate-700"
        phx-hook="URLPreviewHook"
        id={"url-preview-#{@post_id}"}
        data-post-id={@post_id}
        data-image-hash={@preview["image_hash"]}
        data-url-preview-fetched-at={@url_preview_fetched_at}
        data-presigned-url={@preview["image"]}
      >
        <img
          alt={@preview["title"] || "Preview image"}
          class="w-full h-full object-cover group-hover/preview:scale-105 transition-transform duration-300"
        />
      </div>
      <div class="flex-1 min-w-0 py-0.5">
        <div class="flex items-center gap-1.5 mb-0.5">
          <.phx_icon name="hero-link" class="h-3 w-3 text-slate-400" />
          <span class="text-xs text-slate-500 dark:text-slate-400 truncate">
            {@preview["site_name"] || URI.parse(@preview["url"]).host}
          </span>
        </div>
        <p
          :if={@preview["title"]}
          class="font-medium text-sm text-slate-900 dark:text-slate-100 line-clamp-1 group-hover/preview:text-orange-600 dark:group-hover/preview:text-orange-400 transition-colors"
        >
          {@preview["title"]}
        </p>
        <p
          :if={@preview["description"]}
          class="text-xs text-slate-600 dark:text-slate-400 line-clamp-2 mt-0.5"
        >
          {@preview["description"]}
        </p>
      </div>
    </a>
    """
  end

  defp can_view_profile?(:public), do: true
  defp can_view_profile?(_), do: false

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

  def mood_picker(assigns) do
    assigns =
      assign(assigns, :id, assigns[:id] || "mood-picker-#{System.unique_integer([:positive])}")

    ~H"""
    <div id={@id} class="mood-picker relative" x-data="{ open: false }">
      <input type="hidden" name={@name} value={@value || ""} id={"#{@id}-input"} />
      <button
        type="button"
        @click="open = !open"
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
        @click.outside="open = false"
        class="absolute left-0 z-50 mt-2 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-lg w-72 sm:w-80"
        style="display: none;"
      >
        <div class="max-h-[60vh] sm:max-h-80 overflow-y-auto overscroll-contain p-3 sm:p-4">
          <div class="space-y-3 sm:space-y-4">
            <div :for={{category, moods} <- mood_categories()} class="space-y-2">
              <div class="text-[11px] font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400 px-1">
                {category}
              </div>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-1.5 sm:gap-2">
                <button
                  :for={{mood, emoji, label} <- moods}
                  type="button"
                  phx-click={
                    JS.dispatch("mood:select", detail: %{mood: mood, input_id: "#{@id}-input"})
                  }
                  @click="open = false"
                  phx-value-mood={mood}
                  class={[
                    "group flex items-center gap-2 px-2.5 py-2 sm:px-3 sm:py-2.5 rounded-lg text-left min-w-0",
                    "transition-colors duration-150 ease-out",
                    "focus:outline-none focus:ring-2 focus:ring-teal-500/50",
                    mood_grid_button_classes(mood, @value)
                  ]}
                  title={label}
                >
                  <span class="text-lg sm:text-xl leading-none flex-shrink-0">{emoji}</span>
                  <span class={[
                    "text-xs sm:text-sm leading-tight transition-colors duration-150 truncate",
                    if(@value == mood,
                      do: "font-medium",
                      else:
                        "text-slate-700 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-slate-100"
                    )
                  ]}>
                    {label}
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
        <div :if={@value} class="border-t border-slate-200 dark:border-slate-700 px-3 sm:px-4 py-2">
          <button
            type="button"
            phx-click={JS.dispatch("mood:select", detail: %{mood: "", input_id: "#{@id}-input"})}
            @click="open = false"
            class="w-full flex items-center justify-center gap-1.5 py-1.5 text-xs text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition-colors"
          >
            <.phx_icon name="hero-x-mark" class="h-3.5 w-3.5" /> Clear mood
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp mood_categories do
    [
      {"Happy",
       [
         {"joyful", "🤩", "Joyful"},
         {"happy", "😊", "Happy"},
         {"excited", "🎉", "Excited"},
         {"hopeful", "🌟", "Hopeful"},
         {"goodday", "☀️", "Good Day"},
         {"cheerful", "😄", "Cheerful"},
         {"elated", "🥳", "Elated"},
         {"blissful", "😇", "Blissful"},
         {"optimistic", "🌈", "Optimistic"}
       ]},
      {"Grateful",
       [
         {"grateful", "🙏", "Grateful"},
         {"thankful", "🌅", "Thankful"},
         {"blessed", "✨", "Blessed"},
         {"appreciative", "💫", "Appreciative"},
         {"fortunate", "🍀", "Fortunate"}
       ]},
      {"Love",
       [
         {"loved", "🥰", "Loved"},
         {"loving", "💕", "Loving"},
         {"romantic", "💘", "Romantic"},
         {"affectionate", "🤗", "Affectionate"},
         {"tender", "💗", "Tender"},
         {"adoring", "😍", "Adoring"}
       ]},
      {"Calm",
       [
         {"content", "😌", "Content"},
         {"peaceful", "🕊️", "Peaceful"},
         {"serene", "🧘", "Serene"},
         {"calm", "😶", "Calm"},
         {"relaxed", "😎", "Relaxed"},
         {"tranquil", "🌸", "Tranquil"},
         {"centered", "☯️", "Centered"},
         {"mellow", "🍃", "Mellow"},
         {"cozy", "☕", "Cozy"}
       ]},
      {"Energized",
       [
         {"energized", "⚡", "Energized"},
         {"refreshed", "🌱", "Refreshed"},
         {"alive", "🌻", "Alive"},
         {"vibrant", "💥", "Vibrant"},
         {"awake", "🌞", "Awake"},
         {"invigorated", "🏃", "Invigorated"}
       ]},
      {"Motivated",
       [
         {"inspired", "💡", "Inspired"},
         {"creative", "🎨", "Creative"},
         {"curious", "🤔", "Curious"},
         {"confident", "💪", "Confident"},
         {"proud", "🏆", "Proud"},
         {"accomplished", "🎯", "Accomplished"},
         {"determined", "🔥", "Determined"},
         {"focused", "🧠", "Focused"},
         {"ambitious", "🚀", "Ambitious"},
         {"driven", "⭐", "Driven"}
       ]},
      {"Playful",
       [
         {"playful", "🎮", "Playful"},
         {"silly", "🤪", "Silly"},
         {"adventurous", "🗺️", "Adventurous"},
         {"spontaneous", "🎲", "Spontaneous"},
         {"carefree", "🦋", "Carefree"},
         {"mischievous", "😏", "Mischievous"}
       ]},
      {"Connected",
       [
         {"supported", "🤝", "Supported"},
         {"connected", "🫂", "Connected"},
         {"belonging", "🏠", "Belonging"},
         {"understood", "💭", "Understood"},
         {"included", "👥", "Included"},
         {"social", "🎊", "Social"}
       ]},
      {"Growth",
       [
         {"growing", "🪴", "Growing"},
         {"grounded", "🌿", "Grounded"},
         {"breathing", "🌬️", "Letting Go"},
         {"healing", "🩹", "Healing"},
         {"learning", "📚", "Learning"},
         {"evolving", "🌀", "Evolving"},
         {"patient", "🐢", "Patient"}
       ]},
      {"Neutral",
       [
         {"neutral", "😐", "Neutral"},
         {"tired", "😴", "Tired"},
         {"bored", "😑", "Bored"},
         {"mixed", "🌊", "Mixed"},
         {"latenight", "🌙", "Late Night"},
         {"drained", "🔋", "Drained"},
         {"indifferent", "🤷", "Indifferent"},
         {"okay", "👍", "Okay"},
         {"meh", "😶‍🌫️", "Meh"}
       ]},
      {"Surprised",
       [
         {"surprised", "😲", "Surprised"},
         {"amazed", "🤯", "Amazed"},
         {"shocked", "😱", "Shocked"},
         {"astonished", "😮", "Astonished"},
         {"bewildered", "😵‍💫", "Bewildered"}
       ]},
      {"Anxious",
       [
         {"anxious", "😰", "Anxious"},
         {"worried", "😟", "Worried"},
         {"stressed", "😫", "Stressed"},
         {"nervous", "😬", "Nervous"},
         {"restless", "🌀", "Restless"},
         {"uneasy", "😧", "Uneasy"},
         {"tense", "😣", "Tense"},
         {"panicked", "😨", "Panicked"}
       ]},
      {"Sad",
       [
         {"sad", "😢", "Sad"},
         {"lonely", "🥺", "Lonely"},
         {"melancholic", "🌧️", "Melancholy"},
         {"heartbroken", "💔", "Heartbroken"},
         {"grieving", "🖤", "Grieving"},
         {"down", "😞", "Down"},
         {"hopeless", "🕳️", "Hopeless"},
         {"disappointed", "😔", "Disappointed"},
         {"empty", "🫥", "Empty"}
       ]},
      {"Reflective",
       [
         {"nostalgic", "📷", "Nostalgic"},
         {"reminiscing", "📼", "Reminiscing"},
         {"thoughtful", "🤔", "Thoughtful"},
         {"contemplative", "🌌", "Contemplative"},
         {"introspective", "🪞", "Introspective"},
         {"pensive", "💭", "Pensive"},
         {"wistful", "🍂", "Wistful"}
       ]},
      {"Difficult",
       [
         {"frustrated", "😤", "Frustrated"},
         {"angry", "😠", "Angry"},
         {"overwhelmed", "🤯", "Overwhelmed"},
         {"irritated", "😒", "Irritated"},
         {"resentful", "😾", "Resentful"},
         {"bitter", "🍋", "Bitter"},
         {"annoyed", "🙄", "Annoyed"},
         {"rageful", "🔴", "Rageful"}
       ]},
      {"Vulnerable",
       [
         {"hurt", "🩹", "Hurt"},
         {"embarrassed", "😳", "Embarrassed"},
         {"ashamed", "😣", "Ashamed"},
         {"insecure", "🐚", "Insecure"},
         {"exposed", "🥀", "Exposed"},
         {"fragile", "🥚", "Fragile"},
         {"scared", "😨", "Scared"},
         {"jealous", "💚", "Jealous"}
       ]},
      {"Confused",
       [
         {"confused", "😵‍💫", "Confused"},
         {"lost", "🧭", "Lost"},
         {"uncertain", "❓", "Uncertain"},
         {"conflicted", "⚖️", "Conflicted"},
         {"torn", "💭", "Torn"},
         {"doubtful", "🤨", "Doubtful"}
       ]},
      {"Relief",
       [
         {"relieved", "😮‍💨", "Relieved"},
         {"free", "🕊️", "Free"},
         {"liberated", "🦅", "Liberated"},
         {"unburdened", "🎈", "Unburdened"},
         {"light", "🪶", "Light"}
       ]}
    ]
  end

  defp mood_grid_button_classes(mood, current_value) when mood == current_value do
    mood_color = mood_color_scheme(mood)

    [
      mood_color[:bg],
      mood_color[:text],
      "ring-1",
      mood_color[:border]
    ]
  end

  defp mood_grid_button_classes(_mood, _current_value) do
    [
      "bg-slate-50/50 dark:bg-slate-700/30",
      "text-slate-700 dark:text-slate-300",
      "hover:bg-slate-100 dark:hover:bg-slate-700/50"
    ]
  end

  defp mood_color_scheme(mood)
       when mood in ~w(joyful happy excited hopeful goodday cheerful elated blissful optimistic grateful thankful blessed appreciative fortunate) do
    %{
      bg: "bg-amber-50 dark:bg-amber-900/30",
      text: "text-amber-700 dark:text-amber-300",
      border: "border-amber-200 dark:border-amber-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(loved loving romantic affectionate tender adoring) do
    %{
      bg: "bg-pink-50 dark:bg-pink-900/30",
      text: "text-pink-700 dark:text-pink-300",
      border: "border-pink-200 dark:border-pink-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(content peaceful serene calm relaxed tranquil centered mellow cozy) do
    %{
      bg: "bg-teal-50 dark:bg-teal-900/30",
      text: "text-teal-700 dark:text-teal-300",
      border: "border-teal-200 dark:border-teal-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(energized refreshed alive vibrant awake invigorated) do
    %{
      bg: "bg-yellow-50 dark:bg-yellow-900/30",
      text: "text-yellow-700 dark:text-yellow-300",
      border: "border-yellow-200 dark:border-yellow-700/50"
    }
  end

  defp mood_color_scheme("neutral") do
    %{
      bg: "bg-slate-100 dark:bg-slate-700/50",
      text: "text-slate-600 dark:text-slate-300",
      border: "border-slate-200 dark:border-slate-600"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(tired bored latenight drained indifferent okay meh) do
    %{
      bg: "bg-slate-100 dark:bg-slate-700/50",
      text: "text-slate-500 dark:text-slate-400",
      border: "border-slate-200 dark:border-slate-600"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(inspired creative curious confident proud accomplished determined focused ambitious driven) do
    %{
      bg: "bg-indigo-50 dark:bg-indigo-900/30",
      text: "text-indigo-700 dark:text-indigo-300",
      border: "border-indigo-200 dark:border-indigo-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(playful silly adventurous spontaneous carefree mischievous) do
    %{
      bg: "bg-orange-50 dark:bg-orange-900/30",
      text: "text-orange-700 dark:text-orange-300",
      border: "border-orange-200 dark:border-orange-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(supported connected belonging understood included social) do
    %{
      bg: "bg-sky-50 dark:bg-sky-900/30",
      text: "text-sky-700 dark:text-sky-300",
      border: "border-sky-200 dark:border-sky-700/50"
    }
  end

  defp mood_color_scheme(mood) when mood in ~w(surprised amazed shocked astonished bewildered) do
    %{
      bg: "bg-fuchsia-50 dark:bg-fuchsia-900/30",
      text: "text-fuchsia-700 dark:text-fuchsia-300",
      border: "border-fuchsia-200 dark:border-fuchsia-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(anxious worried stressed nervous restless uneasy tense panicked) do
    %{
      bg: "bg-purple-50 dark:bg-purple-900/30",
      text: "text-purple-700 dark:text-purple-300",
      border: "border-purple-200 dark:border-purple-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(frustrated angry irritated resentful bitter annoyed rageful) do
    %{
      bg: "bg-rose-50 dark:bg-rose-900/30",
      text: "text-rose-700 dark:text-rose-300",
      border: "border-rose-200 dark:border-rose-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(sad lonely overwhelmed nostalgic reminiscing melancholic heartbroken grieving down hopeless disappointed empty thoughtful contemplative introspective pensive wistful) do
    %{
      bg: "bg-blue-50 dark:bg-blue-900/30",
      text: "text-blue-700 dark:text-blue-300",
      border: "border-blue-200 dark:border-blue-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(hurt embarrassed ashamed insecure exposed fragile scared jealous) do
    %{
      bg: "bg-violet-50 dark:bg-violet-900/30",
      text: "text-violet-700 dark:text-violet-300",
      border: "border-violet-200 dark:border-violet-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(confused lost uncertain conflicted torn doubtful) do
    %{
      bg: "bg-gray-50 dark:bg-gray-900/30",
      text: "text-gray-700 dark:text-gray-300",
      border: "border-gray-200 dark:border-gray-700/50"
    }
  end

  defp mood_color_scheme(mood) when mood in ~w(relieved free liberated unburdened light) do
    %{
      bg: "bg-lime-50 dark:bg-lime-900/30",
      text: "text-lime-700 dark:text-lime-300",
      border: "border-lime-200 dark:border-lime-700/50"
    }
  end

  defp mood_color_scheme(mood)
       when mood in ~w(growing grounded breathing healing learning evolving patient) do
    %{
      bg: "bg-emerald-50 dark:bg-emerald-900/30",
      text: "text-emerald-700 dark:text-emerald-300",
      border: "border-emerald-200 dark:border-emerald-700/50"
    }
  end

  defp mood_color_scheme("mixed") do
    %{
      bg: "bg-cyan-50 dark:bg-cyan-900/30",
      text: "text-cyan-700 dark:text-cyan-300",
      border: "border-cyan-200 dark:border-cyan-700/50"
    }
  end

  defp mood_color_scheme(_) do
    %{
      bg: "bg-slate-100 dark:bg-slate-700/50",
      text: "text-slate-600 dark:text-slate-300",
      border: "border-slate-200 dark:border-slate-600"
    }
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
      "tired" => "😴",
      "bored" => "😑",
      "mixed" => "🌊",
      "latenight" => "🌙",
      "drained" => "🔋",
      "indifferent" => "🤷",
      "okay" => "👍",
      "meh" => "😶‍🌫️",
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

  attr :active, :boolean, required: true
  attr :countdown, :integer, default: 0
  attr :needs_password, :boolean, default: false
  attr :on_activate, :string, default: "activate_privacy"
  attr :on_reveal, :string, default: "reveal_content"
  attr :on_password_submit, :string, default: "verify_privacy_password"
  attr :privacy_form, Phoenix.HTML.Form, default: nil

  def privacy_screen(assigns) do
    ~H"""
    <div
      :if={@active}
      id="privacy-screen"
      phx-hook="LockBodyScroll"
      class="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto overscroll-contain bg-gradient-to-br from-slate-50 via-stone-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800"
    >
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute top-1/4 left-1/4 w-96 h-96 rounded-full bg-gradient-to-br from-teal-200/20 to-emerald-200/20 dark:from-teal-800/10 dark:to-emerald-800/10 blur-3xl animate-pulse" />
        <div class="absolute bottom-1/4 right-1/4 w-80 h-80 rounded-full bg-gradient-to-br from-emerald-200/20 to-cyan-200/20 dark:from-emerald-800/10 dark:to-cyan-800/10 blur-3xl animate-pulse [animation-delay:1s]" />
        <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 rounded-full bg-gradient-to-br from-slate-200/30 to-slate-300/30 dark:from-slate-700/20 dark:to-slate-600/20 blur-2xl" />
      </div>

      <div class="relative text-center px-6 py-6 sm:py-8 max-w-md my-auto">
        <div class="mb-4 sm:mb-8">
          <div class="relative inline-flex items-center justify-center w-16 h-16 sm:w-24 sm:h-24 rounded-2xl sm:rounded-3xl bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-800 dark:via-slate-700 dark:to-slate-800 shadow-lg border border-slate-200/50 dark:border-slate-700/50">
            <div class="absolute inset-0 rounded-2xl sm:rounded-3xl bg-gradient-to-br from-teal-500/5 to-emerald-500/5 dark:from-teal-400/10 dark:to-emerald-400/10" />
            <MossletWeb.CoreComponents.phx_icon
              name="hero-eye-slash"
              class="h-8 w-8 sm:h-12 sm:w-12 text-slate-400 dark:text-slate-500"
            />
          </div>
        </div>

        <h2 class="text-xl sm:text-2xl font-semibold text-slate-800 dark:text-slate-200 mb-2 sm:mb-3">
          Privacy Mode Active
        </h2>
        <p class="text-sm sm:text-base text-slate-600 dark:text-slate-400 mb-6 sm:mb-8 leading-relaxed">
          Your journal content is hidden for your privacy. Click the button below when you're ready to continue journaling.
        </p>

        <%= if @needs_password do %>
          <.privacy_password_form on_submit={@on_password_submit} form={@privacy_form} />
        <% else %>
          <button
            type="button"
            phx-click={@on_reveal}
            class="inline-flex items-center justify-center gap-3 px-8 py-4 text-base font-medium rounded-2xl transition-all duration-300 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg hover:shadow-xl hover:from-teal-600 hover:to-emerald-600 transform hover:scale-[1.02]"
          >
            <MossletWeb.CoreComponents.phx_icon name="hero-eye" class="h-5 w-5" />
            <%= if @countdown > 0 do %>
              <span>Reveal Content</span>
              <span class="tabular-nums font-mono text-white/80">
                ({format_countdown(@countdown)})
              </span>
            <% else %>
              <span>Reveal Content</span>
            <% end %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :on_submit, :string, required: true
  attr :form, Phoenix.HTML.Form, required: true

  defp privacy_password_form(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800/80 rounded-2xl p-6 border border-slate-200 dark:border-slate-700 shadow-lg">
      <div class="flex items-center gap-2 mb-4">
        <MossletWeb.CoreComponents.phx_icon
          name="hero-lock-closed"
          class="h-5 w-5 text-amber-500"
        />
        <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
          Enter your password to continue<span class="text-red-500">*</span>
        </span>
      </div>
      <.form for={@form} id="privacy-unlock-form" phx-submit={@on_submit} class="space-y-4">
        <div>
          <input
            type="password"
            name={@form[:password].name}
            id={@form[:password].id}
            placeholder="Your password"
            autocomplete="current-password"
            required
            class="w-full px-4 py-3 text-sm text-slate-900 dark:text-slate-100 bg-slate-50 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-teal-500 focus:border-teal-500 transition-colors"
          />
        </div>
        <button
          type="submit"
          class="w-full px-6 py-3 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200 cursor-pointer touch-manipulation active:scale-[0.98]"
        >
          Unlock Journal
        </button>
      </.form>
    </div>
    """
  end

  defp format_countdown(seconds) when seconds > 0 do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp format_countdown(_), do: "00:00"

  @doc """
  A markdown guide modal showing available markdown syntax and previews.

  ## Examples

      <.liquid_markdown_guide_modal
        id="markdown-guide-modal"
        show={@show_markdown_guide}
        on_cancel={JS.push("close_markdown_guide")}
      />
  """
  attr :id, :string, default: "markdown-guide-modal"
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  def liquid_markdown_guide_modal(assigns) do
    ~H"""
    <.liquid_modal
      id={@id}
      show={@show}
      on_cancel={@on_cancel}
      size="lg"
    >
      <:title>
        <div class="flex items-center gap-3">
          <div class="p-2.5 rounded-xl bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/30 dark:to-teal-900/30">
            <.phx_icon
              name="hero-document-text"
              class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
            />
          </div>
          <div>
            <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              Markdown Guide
            </h3>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Format your posts with style
            </p>
          </div>
        </div>
      </:title>

      <div class="space-y-5">
        <p class="text-sm text-slate-600 dark:text-slate-400">
          You can use markdown to format your posts. Here's a quick reference:
        </p>

        <div class="grid gap-4 sm:grid-cols-2">
          <.markdown_guide_section
            title="Text Formatting"
            items={[
              {"**bold**", "<strong>bold</strong>"},
              {"*italic*", "<em>italic</em>"},
              {"~~strike~~", "<s>strikethrough</s>"},
              {"^super^", "super<sup>script</sup>"}
            ]}
          />

          <.markdown_guide_section
            title="Headers"
            items={[
              {"# H1", "<span class='font-bold'>Heading 1</span>"},
              {"## H2", "<span class='font-semibold'>Heading 2</span>"},
              {"### H3", "<span class='font-medium'>Heading 3</span>"}
            ]}
          />

          <.markdown_guide_section
            title="Lists"
            items={[
              {"- item", "• bullet list"},
              {"1. item", "1. numbered list"},
              {"- [x] done", "☑ task list"}
            ]}
          />

          <.markdown_guide_section
            title="Links & Images"
            items={[
              {"[text](url)",
               "<span class='text-emerald-600 dark:text-emerald-400 underline'>link</span>"},
              {"![alt](url)", "🖼️ image"},
              {"auto-links",
               "<span class='text-emerald-600 dark:text-emerald-400'>urls → links</span>"}
            ]}
          />

          <.markdown_guide_section
            title="Code"
            items={[
              {"`code`",
               "<code class='px-1 py-0.5 rounded bg-slate-200 dark:bg-slate-600 text-xs'>inline</code>"},
              {"```lang block```",
               "<code class='px-1 py-0.5 rounded bg-slate-200 dark:bg-slate-600 text-xs'>syntax hl block</code>"}
            ]}
          />

          <.markdown_guide_section
            title="Other"
            items={[
              {"> quote",
               "<span class='border-l-2 border-emerald-400 pl-2 italic text-slate-600 dark:text-slate-400'>quote</span>"},
              {"---", "<span class='text-slate-400'>───</span> divider"},
              {"| table |", "📊 tables"}
            ]}
          />
        </div>

        <div class="pt-3 border-t border-slate-200/60 dark:border-slate-700/60">
          <p class="text-xs text-slate-500 dark:text-slate-400">
            <span class="font-medium text-emerald-600 dark:text-emerald-400">Tip:</span>
            URLs auto-link and code blocks have syntax highlighting.
          </p>
        </div>
      </div>
    </.liquid_modal>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true

  defp markdown_guide_section(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-200/60 dark:border-slate-700/60 overflow-hidden">
      <div class="px-3 py-2 bg-gradient-to-r from-slate-50 to-slate-100/50 dark:from-slate-800/80 dark:to-slate-800/40 border-b border-slate-200/60 dark:border-slate-700/60">
        <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300">{@title}</h4>
      </div>
      <div class="divide-y divide-slate-100 dark:divide-slate-700/50 bg-white/50 dark:bg-slate-800/30">
        <div
          :for={{syntax, preview} <- @items}
          class="px-3 py-2 flex items-center justify-between gap-4"
        >
          <code class="text-xs font-mono text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-900/30 px-1.5 py-0.5 rounded flex-shrink-0">
            {syntax}
          </code>
          <div class="text-sm text-slate-600 dark:text-slate-400 text-right">
            {Phoenix.HTML.raw(preview)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  A small icon button to trigger the markdown guide modal.

  ## Examples

      <.liquid_markdown_guide_trigger on_click={JS.push("open_markdown_guide")} />
      <.liquid_markdown_guide_trigger on_click={JS.push("open_markdown_guide")} size="sm" />
  """
  attr :id, :string, default: "markdown-guide-trigger"
  attr :on_click, JS, default: %JS{}
  attr :size, :string, default: "md", values: ~w(sm md)
  attr :class, :any, default: ""

  def liquid_markdown_guide_trigger(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      phx-click={@on_click}
      phx-hook="TippyHook"
      data-tippy-content="Markdown formatting guide"
      aria-label="Markdown formatting guide"
      class={[
        "rounded-lg text-slate-500 dark:text-slate-400",
        "hover:text-emerald-600 dark:hover:text-emerald-400",
        "hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20",
        "transition-all duration-200 ease-out group",
        if(@size == "sm", do: "p-1.5", else: "p-2"),
        @class
      ]}
    >
      <.phx_icon
        name="hero-document-text"
        class={[
          "transition-transform duration-200 group-hover:scale-110",
          if(@size == "sm", do: "h-4 w-4", else: "h-5 w-5")
        ]}
      />
    </button>
    """
  end

  attr :active, :boolean, required: true
  attr :countdown, :integer, default: 0
  attr :on_click, :string, default: "activate_privacy"

  def privacy_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@on_click}
      id="privacy-button"
      phx-hook="TippyHook"
      data-tippy-content={if @active, do: "Privacy mode active", else: "Hide content quickly"}
      class={[
        "inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium rounded-xl border shadow-sm transition-all duration-200",
        if(@active,
          do:
            "text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-900/30 border-amber-200 dark:border-amber-700",
          else:
            "text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 hover:text-teal-600 dark:hover:text-teal-400 hover:border-teal-300 dark:hover:border-teal-600"
        )
      ]}
    >
      <MossletWeb.CoreComponents.phx_icon
        name={if @active, do: "hero-eye-slash", else: "hero-eye-slash"}
        class="h-5 w-5"
      />
      <span class="sr-only">
        {if @active, do: "Privacy mode active", else: "Hide content quickly"}
      </span>
      <%= if @active && @countdown > 0 do %>
        <span class="tabular-nums text-xs font-mono">{format_countdown(@countdown)}</span>
      <% end %>
    </button>
    """
  end
end
