defmodule MossletWeb.UserSettingsLayoutComponent do
  @moduledoc """
  A modern layout for user setting screens with liquid metal styling.
  Updated to use our design system instead of PetalComponents.
  """
  use MossletWeb, :component
  import MossletWeb.DesignSystem
  import MossletWeb.ModernSidebarLayout

  attr :current_user, :map
  attr :current_page, :atom
  attr :key, :string, doc: "the session key for the current user"
  slot :inner_block

  def settings_layout(assigns) do
    ~H"""
    <.modern_sidebar_layout
      current_page={@current_page}
      current_user={@current_user}
      key={@key}
      main_menu_items={sidebar_main_menu_items(@current_user)}
      user_menu_items={sidebar_user_menu_items(@current_user)}
      sidebar_title="Settings"
      home_path="/app"
    >
      <:logo>
        <MossletWeb.CoreComponents.logo class="h-8 w-auto" />
      </:logo>

      <:top_right>
        <.link
          id="invite-connection-link-settings"
          navigate={~p"/app/users/connections/invite/new-invite"}
          phx-hook="TippyHook"
          data-tippy-content="Invite people to join you on Mosslet!"
          class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-lg shadow-sm hover:bg-slate-50 dark:hover:bg-slate-700 hover:border-emerald-300 dark:hover:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-1 transition-all duration-200"
        >
          <MossletWeb.CoreComponents.phx_icon name="hero-paper-airplane" class="size-4" />
          <span class="sr-only">Invite people to join you on Mosslet</span>
        </.link>
        <MossletWeb.Layouts.theme_toggle />
      </:top_right>

      <.liquid_container max_width="xl" class="py-4 sm:py-8 xl:py-12">
        <div class="space-y-4 sm:space-y-8">
          <%!-- Settings header with modern styling --%>
          <.settings_header title="Settings" />

          <%!-- Settings content with sidebar navigation --%>
          <.settings_tabs_container
            current_page={@current_page}
            menu_items={settings_menu_items(@current_user)}
          >
            {render_slot(@inner_block)}
          </.settings_tabs_container>
        </div>
      </.liquid_container>
    </.modern_sidebar_layout>
    """
  end

  def settings_group_layout(assigns) do
    ~H"""
    <.modern_sidebar_layout
      current_page={@current_page}
      current_user={@current_user}
      key={@key}
      main_menu_items={sidebar_main_menu_items(@current_user)}
      user_menu_items={sidebar_user_menu_items(@current_user)}
      sidebar_title="Group Settings"
      home_path="/app"
    >
      <:logo>
        <MossletWeb.CoreComponents.logo class="h-8 w-auto" />
      </:logo>

      <:top_right>
        <.link
          id="invite-connection-link-group-settings"
          navigate={~p"/app/users/connections/invite/new-invite"}
          phx-hook="TippyHook"
          data-tippy-content="Invite people to join you on Mosslet!"
          class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-lg shadow-sm hover:bg-slate-50 dark:hover:bg-slate-700 hover:border-emerald-300 dark:hover:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-1 transition-all duration-200"
        >
          <MossletWeb.CoreComponents.phx_icon name="hero-paper-airplane" class="size-4" />
          <span class="sr-only">Invite people to join you on Mosslet</span>
        </.link>
        <MossletWeb.Layouts.theme_toggle />
      </:top_right>

      <.liquid_container max_width="xl" class="py-4 sm:py-8 xl:py-12">
        <div class="space-y-4 sm:space-y-8">
          <.group_settings_header
            title={Gettext.gettext(MossletWeb.Gettext, "Edit Group Members")}
            group_name={decr_item(@group.name, @current_user, @user_group.key, @key, @group)}
          >
            <.liquid_button
              variant="secondary"
              icon="hero-arrow-left"
              navigate={~p"/app/groups/#{@group}"}
            >
              Back to Group
            </.liquid_button>
          </.group_settings_header>

          <.group_settings_tabs_container
            current_page={@current_page}
            menu_items={settings_menu_items_group(@current_user, @group, @user_group)}
            group={@group}
          >
            {render_slot(@inner_block)}
          </.group_settings_tabs_container>
        </div>
      </.liquid_container>
    </.modern_sidebar_layout>
    """
  end

  # Modern settings header with liquid metal styling
  defp settings_header(assigns) do
    assigns = assign_new(assigns, :inner_block, fn -> [] end)

    ~H"""
    <div class="flex flex-col gap-4">
      <div class="min-w-0">
        <h1 class={[
          "text-2xl sm:text-3xl font-bold tracking-tight",
          "bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900",
          "dark:from-slate-100 dark:via-white dark:to-slate-100",
          "bg-clip-text text-transparent"
        ]}>
          {@title}
        </h1>
        <p class="mt-2 text-sm sm:text-base text-slate-600 dark:text-slate-400">
          Manage your account settings and preferences
        </p>
      </div>

      <div :if={render_slot(@inner_block) != []} class="flex items-center">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # Modern group settings header with liquid metal styling
  defp group_settings_header(assigns) do
    assigns =
      assigns
      |> assign_new(:inner_block, fn -> [] end)
      |> assign_new(:group_name, fn -> nil end)

    ~H"""
    <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div class="min-w-0">
        <div :if={@group_name} class="flex items-center gap-2 mb-2">
          <div class="size-7 flex items-center justify-center rounded-lg bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 flex-shrink-0">
            <MossletWeb.CoreComponents.phx_icon
              name="hero-user-group"
              class="size-4 text-teal-600 dark:text-teal-400"
            />
          </div>
          <span class="text-sm font-medium text-teal-700 dark:text-teal-300 truncate">
            {@group_name}
          </span>
        </div>
        <h1 class={[
          "text-2xl sm:text-3xl font-bold tracking-tight",
          "bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900",
          "dark:from-slate-100 dark:via-white dark:to-slate-100",
          "bg-clip-text text-transparent"
        ]}>
          {@title}
        </h1>
        <p class="mt-2 text-sm sm:text-base text-slate-600 dark:text-slate-400">
          Manage your group settings and preferences
        </p>
      </div>

      <div :if={render_slot(@inner_block) != []} class="flex items-center flex-shrink-0">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # Modern settings tabs container with enhanced navigation
  defp settings_tabs_container(assigns) do
    ~H"""
    <div class="space-y-4 sm:space-y-6">
      <%!-- Settings breadcrumb navigation --%>
      <.settings_breadcrumb />

      <%!-- Settings content area --%>
      <.liquid_card class="overflow-hidden">
        <div class="flex flex-col xl:flex-row xl:divide-x xl:divide-slate-200/60 dark:xl:divide-slate-700/60">
          <%!-- Settings navigation submenu --%>
          <div class="xl:w-72 xl:flex-shrink-0">
            <div class="p-4 sm:p-6">
              <h2 class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-4">
                Settings Menu
              </h2>
              <nav class="space-y-1">
                <.settings_menu_item
                  :for={menu_item <- @menu_items}
                  current={@current_page}
                  {menu_item}
                />
              </nav>
            </div>
          </div>

          <%!-- Main settings content --%>
          <div class="flex-1 xl:min-w-0 min-w-0">
            <div class="p-4 sm:p-6 xl:p-8">
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </.liquid_card>
    </div>
    """
  end

  # Modern settings tabs container with enhanced navigation
  defp group_settings_tabs_container(assigns) do
    ~H"""
    <div class="space-y-4 sm:space-y-6">
      <%!-- Settings breadcrumb navigation --%>
      <.group_settings_breadcrumb group={@group} />

      <%!-- Settings content area --%>
      <.liquid_card class="overflow-hidden">
        <div class="flex flex-col xl:flex-row xl:divide-x xl:divide-slate-200/60 dark:xl:divide-slate-700/60">
          <%!-- Settings navigation submenu --%>
          <div class="xl:w-72 xl:flex-shrink-0">
            <div class="p-4 sm:p-6">
              <h2 class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-4">
                Group Settings Menu
              </h2>
              <nav class="space-y-1">
                <.group_settings_menu_item
                  :for={menu_item <- @menu_items}
                  current={@current_page}
                  {menu_item}
                />
              </nav>
            </div>
          </div>

          <%!-- Main settings content --%>
          <div class="flex-1 xl:min-w-0 min-w-0">
            <div class="p-4 sm:p-6 xl:p-8">
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </.liquid_card>
    </div>
    """
  end

  # Group settings breadcrumb navigation
  defp group_settings_breadcrumb(assigns) do
    ~H"""
    <nav class="flex" aria-label="Breadcrumb">
      <ol class="flex items-center space-x-2">
        <li>
          <.link
            navigate={~p"/app/groups/#{@group}"}
            class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition-colors duration-200"
          >
            <MossletWeb.CoreComponents.phx_icon name="hero-user-group" class="h-4 w-4" />
            <span class="sr-only">Group</span>
          </.link>
        </li>
        <li>
          <MossletWeb.CoreComponents.phx_icon
            name="hero-chevron-right"
            class="h-4 w-4 text-slate-400 dark:text-slate-500"
          />
        </li>
        <li>
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            Settings
          </span>
        </li>
      </ol>
    </nav>
    """
  end

  # Settings breadcrumb navigation
  defp settings_breadcrumb(assigns) do
    ~H"""
    <nav class="flex" aria-label="Breadcrumb">
      <ol class="flex items-center space-x-2">
        <li>
          <.link
            navigate="/app"
            class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition-colors duration-200"
          >
            <MossletWeb.CoreComponents.phx_icon name="hero-home" class="h-4 w-4" />
            <span class="sr-only">Home</span>
          </.link>
        </li>
        <li>
          <MossletWeb.CoreComponents.phx_icon
            name="hero-chevron-right"
            class="h-4 w-4 text-slate-400 dark:text-slate-500"
          />
        </li>
        <li>
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            Settings
          </span>
        </li>
      </ol>
    </nav>
    """
  end

  # Modern group settings menu item with liquid metal hover effects
  defp group_settings_menu_item(assigns) do
    assigns = assign(assigns, :is_active?, assigns.current == assigns.name)

    ~H"""
    <.liquid_nav_item
      navigate={@path}
      icon={@icon}
      active={@is_active?}
      class="mb-1"
    >
      {@label}
    </.liquid_nav_item>
    """
  end

  # Modern settings menu item with liquid metal hover effects
  defp settings_menu_item(assigns) do
    assigns = assign(assigns, :is_active?, assigns.current == assigns.name)

    ~H"""
    <.liquid_nav_item
      navigate={@path}
      icon={@icon}
      active={@is_active?}
      class="mb-1"
    >
      {@label}
    </.liquid_nav_item>
    """
  end

  # Main menu items for the sidebar
  defp sidebar_main_menu_items(current_user) do
    MossletWeb.Menus.build_menu(
      [
        :home,
        :connections,
        :groups,
        :timeline,
        :settings
      ],
      current_user
    )
  end

  # User menu items for the dropdown
  defp sidebar_user_menu_items(current_user) do
    MossletWeb.Menus.build_menu(
      [
        :home,
        :edit_details,
        :sign_out
      ],
      current_user
    )
  end

  # Settings-specific menu items
  defp settings_menu_items(current_user) do
    MossletWeb.Menus.build_menu(
      [
        :edit_details,
        :edit_profile,
        :edit_email,
        :edit_visibility,
        :edit_password,
        :edit_forgot_password,
        :edit_notifications,
        :edit_totp,
        :blocked_users,
        :manage_data,
        :billing,
        :delete_account
      ],
      current_user
    )
  end

  defp settings_menu_items_group(current_user, group, user_group) do
    MossletWeb.Menus.build_menu_group(
      [
        :edit_group_members
      ],
      current_user,
      group,
      user_group
    )
  end
end
