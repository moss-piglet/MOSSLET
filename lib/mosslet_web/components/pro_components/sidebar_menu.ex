defmodule MossletWeb.SidebarMenu do
  @moduledoc """
  Functions concerned with rendering aspects of the sidebar layout.
  """

  use Phoenix.Component, global_prefixes: ~w(x-)
  use PetalComponents

  @doc """
  ## Menu items structure

  ### Navigation items

  Navigation menu items (main_menu_items + user_menu_items) should have this structure:

        [
          %{
            name: :sign_in,
            label: "Sign in",
            path: "/sign-in,
            icon: :key,
          }
        ]

  #### Name

  The name is used to identify the menu item. It is used to highlight the current menu item.

      <.sidebar_layout current_page={:sign_in} ...>

  #### Label

  This is the text that will be displayed in the menu.

  #### Path

  This is the path that the user will be taken to when they click the menu item.
  The default link type is a live_redirect. This will work for non-live view links too.

  ##### Live patching

  Let's say you have three menu items that point to the same live view. In this case we can utilize a live_patch link. To do this, you add the `patch_group` key to the menu item.

      [
        %{name: :one, label: "One", path: "/one, icon: :key, patch_group: :my_unique_group},
        %{name: :two, label: "Two", path: "/two, icon: :key, patch_group: :my_unique_group},
        %{name: :three, label: "Three", path: "/three, icon: :key, patch_group: :my_unique_group},
        %{name: :another_link, label: "Other", path: "/other, icon: :key},
      ]

  Now, if you're on page `:one`, and click a link in the menu to either `:two`, or `:three`, the live view will be patched because they are in the same `patch_group`. If you click `:another_link`, the live view will be redirected.

  #### Icons

  The icon should match to a Heroicon (Petal Components must be installed).
  If you have your own icon, you can pass a function to the icon attribute instead of an atom:

        [
          %{
            name: :sign_in,
            label: "Sign in",
            path: "/sign-in,
            icon: &my_cool_icon/1,
          }
        ]

  Or just pass a string of HTML:

        [
          %{
            name: :sign_in,
            label: "Sign in",
            path: "/sign-in,
            icon: "<svg>...</svg>",
          }
        ]

  ### Custom items

  Sometimes, you may require a menu item which is concerned with something other than navigation - like showing/hiding a flyout menu.
  For this you can provide an entirely custom implementation for your use case using this structure:

        [
          %{
            custom_assigns: %{id: "id-you-apply-in-func"},
            custom_component: &render_me/1
          }
          # you can also render a live component
          %{
            custom_assigns: %{id: "required-id-for-lc", current_user: @current_user},
            custom_component: MyApp.SomeLiveComponent
          }
        ]

  You should take care to accommodate the `isCollapsed` Alpine JS state in your markup, if you're using the collapsible sidebar.

  ## Nested menu items

  You can have nested menu items that will be displayed in a dropdown menu. To do this, you add a `menu_items` key to the menu item. eg:

        [
          %{
            name: :auth,
            label: "Auth",
            icon: :key,
            menu_items: [
              %{
                name: :sign_in,
                label: "Sign in",
                path: "/sign-in,
                icon: :key,
              },
              %{
                name: :sign_up,
                label: "Sign up",
                path: "/sign-up,
                icon: :key,
              },
            ]
          }
        ]

  ## Menu groups

  Sidebar supports multi menu groups for the side menu. eg:

  User
  - Profile
  - Settings

  Company
  - Dashboard
  - Company Settings

  To enable this, change the structure of main_menu_items to this:

      main_menu_items = [
        %{
          title: "Menu group 1",
          menu_items: [ ... menu items ... ]
        },
        %{
          title: "Menu group 2",
          menu_items: [ ... menu items ... ]
        },
      ]
  """

  attr :menu_items, :list, required: true
  attr :current_page, :atom, required: true
  attr :title, :string, default: nil

  def sidebar_menu(assigns) do
    ~H"""
    <%= if menu_items_grouped?(@menu_items) do %>
      <div class="flex flex-col" x-bind:class="isCollapsed ? 'gap-10' : 'gap-5'">
        <.sidebar_menu_group
          :for={menu_group <- @menu_items}
          {menu_group}
          current_page={@current_page}
        />
      </div>
    <% else %>
      <.sidebar_menu_group title={@title} menu_items={@menu_items} current_page={@current_page} />
    <% end %>
    """
  end

  defp menu_items_grouped?(menu_items) do
    menu_items
    |> Enum.reject(fn menu_item -> Map.has_key?(menu_item, :custom_component) end)
    |> Enum.all?(fn menu_item ->
      Map.has_key?(menu_item, :title)
    end)
  end

  def sidebar_menu_group(%{custom_assigns: component_assigns, custom_component: component_func})
      when is_map(component_assigns) and is_function(component_func) do
    Phoenix.LiveView.TagEngine.component(
      component_func,
      component_assigns,
      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  def sidebar_menu_group(%{custom_assigns: lc_assigns, custom_component: lc} = assigns)
      when is_map(lc_assigns) and is_atom(lc) do
    ~H"""
    <.live_component module={@custom_component} {@custom_assigns} />
    """
  end

  def sidebar_menu_group(assigns), do: nav_menu_group(assigns)

  attr :current_page, :atom
  attr :menu_items, :list
  attr :title, :string

  def nav_menu_group(assigns) do
    ~H"""
    <nav>
      <h3
        :if={@title}
        class="pl-3 mb-3 text-xs font-semibold leading-6 text-background-400 uppercase"
        x-bind:class="isCollapsed ? 'hidden' : 'block'"
      >
        {@title}
      </h3>

      <div class="divide-y divide-gray-300">
        <div class="space-y-1">
          <.sidebar_menu_item
            :for={menu_item <- @menu_items}
            all_menu_items={@menu_items}
            current_page={@current_page}
            {menu_item}
          />
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Renders a sidebar layout menu item using a custom component function, live component definition, or the default navigation item structure.
  """

  def sidebar_menu_item(%{custom_assigns: component_assigns, custom_component: component_func})
      when is_map(component_assigns) and is_function(component_func) do
    Phoenix.LiveView.TagEngine.component(
      component_func,
      component_assigns,
      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  def sidebar_menu_item(%{custom_assigns: lc_assigns, custom_component: lc} = assigns)
      when is_map(lc_assigns) and is_atom(lc) do
    ~H"""
    <.live_component module={@custom_component} {@custom_assigns} />
    """
  end

  def sidebar_menu_item(assigns), do: nav_menu_item(assigns)

  attr :current_page, :atom
  attr :path, :string, default: nil
  attr :icon, :any, default: nil
  attr :label, :string
  attr :name, :atom, default: nil
  attr :menu_items, :list, default: nil
  attr :all_menu_items, :list, default: nil
  attr :patch_group, :atom, default: nil
  attr :link_type, :string, default: "live_redirect"

  def nav_menu_item(%{menu_items: nil} = assigns) do
    current_item = find_item(assigns.name, assigns.all_menu_items)
    assigns = assign(assigns, :current_item, current_item)

    ~H"""
    <.a
      id={"menu_item_#{@label |> String.downcase() |> String.replace(" ", "_")}_anchor"}
      phx-hook="TippyHook"
      data-tippy-content={@label}
      data-tippy-placement="right"
      x-bind:data-disable-tippy-on-mount="!isCollapsed"
      x-effect="isCollapsed ? $el?._tippy?.enable() : $el?._tippy?.disable()"
      to={@path}
      link_type={
        if @current_item[:patch_group] &&
             @current_item[:patch_group] == @patch_group,
           do: "live_patch",
           else: "live_redirect"
      }
      class={menu_item_classes(@current_page, @name)}
      x-bind:class="isCollapsed ? 'gap-0 w-min' : 'gap-3 w-full'"
    >
      <.nav_menu_icon icon={@icon} />
      <%!-- hidden on collapse toggle --%>
      <div class="" x-bind:class="isCollapsible && isCollapsed ? 'hidden' : 'flex-1'">
        {@label}
      </div>
    </.a>
    """
  end

  def nav_menu_item(%{menu_items: _} = assigns) do
    ~H"""
    <div
      id={nav_menu_item_id(@label)}
      phx-update="ignore"
      class=""
      x-data={"{ open: #{if nav_menu_item_active?(@name, @current_page, @menu_items), do: "true", else: "false"} }"}
    >
      <button
        id={"#{nav_menu_item_id(@label)}_button"}
        type="button"
        phx-hook="TippyHook"
        data-tippy-content={@label}
        data-tippy-placement="top-end"
        x-bind:data-disable-tippy-on-mount="!isCollapsed"
        x-effect="isCollapsible && isCollapsed ? $el?._tippy?.enable() : $el?._tippy?.disable()"
        x-bind:class="isCollapsible && isCollapsed ? 'w-min gap-0' : 'w-full gap-3'"
        class={menu_item_classes(@current_page, @name)}
        @click.prevent="open = !open"
      >
        <.nav_menu_icon icon={@icon} />
        <%!-- hidden on collapse toggle --%>
        <div class="text-left" x-bind:class="isCollapsible && isCollapsed ? 'hidden' : 'flex-1'">
          {@label}
        </div>

        <%!-- Sub-menu expander --%>
        <div class="relative inline-block">
          <%!-- Chevron right --%>
          <div class="ml-2" x-bind:class="isCollapsed ? 'ml-0 absolute left-[6px] -top-1' : 'ml-2'">
            <.icon
              name="hero-chevron-right"
              class="transition duration-200 transform"
              x-bind:class="{ 'w-2 h-2': isCollapsed, 'w-3 h-3': !isCollapsed, 'rotate-90': open }"
            />
          </div>
        </div>
      </button>

      <%!-- Collapsed -- Sub-menu separator --%>
      <div
        x-show="isCollapsible && isCollapsed && open"
        class="h-[1px] bg-primary-700 dark:bg-primary-400 rounded-full w-2/4 my-2 mx-auto"
      >
      </div>

      <%!--
      Sub-menu Items
      Note: The collapsed view does accommodate nested items, but the current design is not final.
      Improving it to use pop-out menus when collapsed is planned.
      --%>
      <div
        class="mt-1 space-y-1"
        x-bind:class="isCollapsible && isCollapsed ? '' : 'ml-3'"
        x-show="open"
        x-cloak={!nav_menu_item_active?(@name, @current_page, @menu_items)}
      >
        <.sidebar_menu_item :for={menu_item <- @menu_items} current_page={@current_page} {menu_item} />
      </div>
    </div>
    """
  end

  defp nav_menu_item_id(label),
    do: "dropdown_#{label |> String.downcase() |> String.replace(" ", "_")}"

  attr :icon, :any, default: nil

  def nav_menu_icon(assigns) do
    ~H"""
    <%= cond do %>
      <% is_function(@icon) -> %>
        {Phoenix.LiveView.TagEngine.component(
          @icon,
          [class: menu_icon_classes()],
          {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
        )}
      <% is_binary(@icon) && String.match?(@icon, ~r/svg|img/) -> %>
        {Phoenix.HTML.raw(@icon)}
      <% true -> %>
        <.icon name={@icon} class={menu_icon_classes()} />
    <% end %>
    """
  end

  # Check whether the current name equals the current page or whether any of the menu items have the current page as their name. A menu_item may have sub-items, so we need to check recursively.
  defp nav_menu_item_active?(name, current_page, menu_items) do
    name == current_page ||
      Enum.any?(menu_items, fn menu_item ->
        nav_menu_item_active?(menu_item[:name], current_page, menu_item[:menu_items] || [])
      end)
  end

  defp menu_icon_classes, do: "w-5 h-5 flex-shrink-0"

  defp menu_item_base,
    do:
      "flex items-center text-sm font-semibold leading-none px-3 py-2 transition duration-200 rounded-md group"

  # Active state
  defp menu_item_classes(page, page),
    do:
      "#{menu_item_base()} text-background-900 dark:text-white bg-background-200 dark:bg-gray-950"

  # Inactive state
  defp menu_item_classes(_current_page, _link_page),
    do:
      "#{menu_item_base()} text-background-500 hover:bg-background-100 dark:text-gray-400 hover:text-background-900 dark:hover:text-white dark:hover:bg-gray-700"

  defp find_item(name, menu_items) when is_list(menu_items) do
    Enum.find(menu_items, fn menu_item ->
      if menu_item[:name] == name do
        true
      else
        find_item(name, menu_item[:menu_items] || [])
      end
    end)
  end

  defp find_item(_, _), do: nil
end
