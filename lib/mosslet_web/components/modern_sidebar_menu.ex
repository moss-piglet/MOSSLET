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
    <div class="space-y-6">
      <div :if={@title} class="px-2">
        <h3 class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
          {@title}
        </h3>
      </div>

      <ul class="space-y-1">
        <li :for={item <- @menu_items}>
          <.modern_menu_item item={item} current_page={@current_page} />
        </li>
      </ul>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :current_page, :atom, required: true

  defp modern_menu_item(assigns) do
    ~H"""
    <.link
      navigate={@item[:path]}
      class={[
        "group flex gap-x-3 rounded-lg p-2 text-sm font-medium leading-6 transition-all duration-200",
        menu_item_classes(@current_page, @item[:name])
      ]}
    >
      <.modern_menu_icon :if={@item[:icon]} icon={@item[:icon]} active={@current_page == @item[:name]} />
      <span class="truncate">{@item[:label]}</span>
    </.link>
    """
  end

  attr :icon, :any, required: true
  attr :active, :boolean, default: false

  defp modern_menu_icon(assigns) do
    ~H"""
    <div class={[
      "flex h-6 w-6 shrink-0 items-center justify-center rounded-lg text-[0.625rem] font-medium transition-colors",
      if(@active,
        do: "bg-emerald-600 text-white",
        else: "bg-slate-100 text-slate-600 group-hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-300 dark:group-hover:bg-slate-600"
      )
    ]}>
      <MossletWeb.CoreComponents.phx_icon name={@icon} class="h-4 w-4" />
    </div>
    """
  end

  # Active state
  defp menu_item_classes(page, page) do
    [
      "bg-slate-100 text-slate-900",
      "dark:bg-slate-800 dark:text-slate-100"
    ]
  end

  # Inactive state
  defp menu_item_classes(_current_page, _link_page) do
    [
      "text-slate-600 hover:text-slate-900 hover:bg-slate-50",
      "dark:text-slate-300 dark:hover:text-slate-100 dark:hover:bg-slate-700/50"
    ]
  end
end
