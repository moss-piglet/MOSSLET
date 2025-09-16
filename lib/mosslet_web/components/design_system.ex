defmodule MossletWeb.DesignSystem do
  @moduledoc """
  Reusable components following the Mosslet Design System.

  This module provides consistent implementations of common UI patterns
  using our liquid metal aesthetic with teal-to-emerald gradients.

  See DESIGN_SYSTEM.md for detailed guidelines and principles.
  """
  use Phoenix.Component

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
  attr :class, :string, default: ""
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
  attr :class, :string, default: ""
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
  attr :class, :string, default: ""
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
end
