def list_menu_items(assigns) do
  ~H"""
  <%= for menu_item <- @menu_items do %>
    <li class={@li_class}>
      <.link
        navigate={menu_item.path}
        class={[
          "group relative transition-all duration-300 ease-out overflow-hidden px-3 py-2 rounded-lg",
          @a_class
        ]}
        method={if menu_item[:method], do: menu_item[:method], else: nil}
      >
        <%!-- Liquid background effect --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/40 via-emerald-50/60 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15 group-hover:opacity-100 rounded-lg">
        </div>
        <%!-- Shimmer effect --%>
        <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full rounded-lg">
        </div>
        <span class="relative">{menu_item.label}</span>
      </.link>
    </li>
  <% end %>
  """
end
