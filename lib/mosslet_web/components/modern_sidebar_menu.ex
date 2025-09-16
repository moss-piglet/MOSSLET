defmodule MossletWeb.ModernSidebarMenu do
  @moduledoc """
  Modern sidebar menu component with improved visual hierarchy and clean design.
  """
  use Phoenix.Component

  attr :menu_items, :list, required: true
  attr :current_page, :atom, required: true
  attr :title, :string, default: nil

  def modern_sidebar_menu(assigns) do
    ~H"""
    <div class="space-y-1">
      <div :if={@title} class="px-4 py-2">
        <h3 class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
          {@title}
        </h3>
      </div>

      <nav class="space-y-0.5">
        <div :for={item <- @menu_items} class="lg:px-4">
          <.modern_menu_item item={item} current_page={@current_page} />
        </div>
      </nav>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :current_page, :atom, required: true

  defp modern_menu_item(assigns) do
    ~H"""
    <.link
      {if @item[:method], do: %{method: @item[:method], href: @item[:path]}, else: %{navigate: @item[:path]}}
      class={[
        "group relative flex items-center gap-x-3 text-sm font-medium",
        "lg:rounded-lg lg:px-4 lg:py-3",
        "px-6 py-4 lg:px-4 lg:py-3",
        "transition-all duration-200 ease-out will-change-transform",
        "overflow-hidden backdrop-blur-sm transform-gpu",
        "hover:translate-x-1 active:translate-x-0",
        menu_item_classes(@current_page, @item[:name])
      ]}
    >
      <%!-- Liquid background effect --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-300 ease-out",
        "bg-gradient-to-r from-teal-50/60 via-emerald-50/80 to-cyan-50/60",
        "dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15",
        "group-hover:opacity-100 transform-gpu"
      ]}>
      </div>

      <%!-- Shimmer effect on hover --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-500 ease-out",
        "bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent",
        "dark:via-emerald-400/15 transform-gpu",
        "group-hover:opacity-100 group-hover:translate-x-full",
        "-translate-x-full"
      ]}>
      </div>

      <.modern_menu_icon
        :if={@item[:icon]}
        icon={@item[:icon]}
        active={@current_page == @item[:name]}
      />
      <span class={[
        "relative flex-1 truncate transition-colors duration-200",
        "group-hover:text-emerald-700 dark:group-hover:text-emerald-300"
      ]}>
        {@item[:label]}
      </span>

      <%!-- Row indicator --%>
      <div class={[
        "relative w-1 h-8 rounded-full transition-all duration-200 transform-gpu",
        "lg:block hidden",
        "opacity-0 group-hover:opacity-100",
        "bg-gradient-to-b from-teal-400 to-emerald-500",
        "shadow-sm shadow-emerald-500/50"
      ]}>
      </div>

      <%!-- Mobile edge indicator --%>
      <div class={[
        "absolute right-0 top-0 bottom-0 w-1 transition-all duration-200 transform-gpu",
        "lg:hidden block",
        "opacity-0 group-hover:opacity-100",
        "bg-gradient-to-b from-teal-400 to-emerald-500",
        "shadow-sm shadow-emerald-500/50"
      ]}>
      </div>
    </.link>
    """
  end

  attr :icon, :any, required: true
  attr :active, :boolean, default: false

  defp modern_menu_icon(assigns) do
    ~H"""
    <div class={[
      "relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden",
      "transition-all duration-200 ease-out transform-gpu will-change-transform",
      if(@active,
        do: [
          "bg-gradient-to-br from-teal-500 to-emerald-600 text-white",
          "shadow-md shadow-emerald-500/30 dark:shadow-emerald-400/20",
          "ring-1 ring-emerald-300/40 dark:ring-emerald-400/30"
        ],
        else: [
          "bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100",
          "dark:from-slate-700 dark:via-slate-600 dark:to-slate-700",
          "text-slate-600 dark:text-slate-300",
          "group-hover:from-teal-100 group-hover:via-emerald-50 group-hover:to-cyan-100",
          "dark:group-hover:from-teal-900/30 dark:group-hover:via-emerald-900/25 dark:group-hover:to-cyan-900/30",
          "group-hover:text-emerald-600 dark:group-hover:text-emerald-400",
          "group-hover:shadow-sm group-hover:shadow-emerald-500/20",
          "border border-slate-200/40 dark:border-slate-600/25",
          "group-hover:border-emerald-200/50 dark:group-hover:border-emerald-700/30"
        ]
      )
    ]}>
      <%!-- Subtle shimmer effect without translation --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-opacity duration-300",
        "bg-gradient-to-br from-white/20 via-transparent to-white/10",
        "group-hover:opacity-100 transform-gpu",
        if(@active, do: "animate-pulse")
      ]}>
      </div>

      <%!-- Active state inner glow --%>
      <div
        :if={@active}
        class="absolute inset-0.5 bg-gradient-to-br from-emerald-300/20 to-teal-500/10 rounded-md animate-pulse"
      >
      </div>

      <%!-- Icon with minimal animation --%>
      <MossletWeb.CoreComponents.phx_icon
        name={@icon}
        class={[
          "relative h-4 w-4 transition-colors duration-200 transform-gpu",
          if(@active, do: "drop-shadow-sm")
        ]}
      />
    </div>
    """
  end

  # Active state with row-like styling
  defp menu_item_classes(page, page) do
    [
      "bg-gradient-to-r from-teal-50/80 via-emerald-50/90 to-cyan-50/70 text-emerald-700",
      "dark:from-teal-900/25 dark:via-emerald-900/35 dark:to-cyan-900/20 dark:text-emerald-300",
      "border-l-2 border-l-emerald-500 dark:border-l-emerald-400",
      "border-y border-r border-emerald-200/50 dark:border-emerald-700/30",
      "shadow-sm shadow-emerald-500/10 dark:shadow-emerald-400/5"
    ]
  end

  # Inactive state with subtle row appearance
  defp menu_item_classes(_current_page, _link_page) do
    [
      "text-slate-600 hover:text-emerald-700 border-l-2 border-l-transparent",
      "dark:text-slate-300 dark:hover:text-emerald-300",
      "hover:border-l-emerald-400 dark:hover:border-l-emerald-500",
      "hover:bg-gradient-to-r hover:from-emerald-50/60 hover:to-transparent",
      "dark:hover:from-emerald-900/15 dark:hover:to-transparent",
      "border-y border-r border-transparent hover:border-y-emerald-200/30 hover:border-r-emerald-200/30",
      "dark:hover:border-y-emerald-700/20 dark:hover:border-r-emerald-700/20"
    ]
  end
end
