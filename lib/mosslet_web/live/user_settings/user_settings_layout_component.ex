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
        <MossletWeb.LanguageSelect.language_select
          current_locale={Gettext.get_locale(MossletWeb.Gettext)}
          language_options={Mosslet.config(:language_options)}
        />
        <%!-- Dark mode toggle removed - will be replaced with updated version --%>
      </:top_right>

      <%!-- Main settings content with liquid styling --%>
      <.liquid_container max_width="xl" class="py-8 lg:py-12">
        <div class="space-y-8">
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
        <MossletWeb.LanguageSelect.language_select
          current_locale={Gettext.get_locale(MossletWeb.Gettext)}
          language_options={Mosslet.config(:language_options)}
        />
        <%!-- Dark mode toggle removed - will be replaced with updated version --%>
      </:top_right>

      <.liquid_container max_width="xl" class="py-8 lg:py-12">
        <div class="space-y-8">
          <.settings_header title={Gettext.gettext(MossletWeb.Gettext, @edit_group_name)}>
            <.liquid_button
              variant="secondary"
              icon="hero-arrow-left"
              navigate={~p"/app/groups/#{@group}"}
            >
              Back to {decr_item(@group.name, @current_user, @user_group.key, @key, @group)} Group
            </.liquid_button>
          </.settings_header>

          <.settings_tabs_container
            current_page={@current_page}
            menu_items={settings_menu_items_group(@current_user, @group, @user_group)}
          >
            {render_slot(@inner_block)}
          </.settings_tabs_container>
        </div>
      </.liquid_container>
    </.modern_sidebar_layout>
    """
  end

  # Modern settings header with liquid metal styling
  defp settings_header(assigns) do
    assigns = assign_new(assigns, :inner_block, fn -> [] end)

    ~H"""
    <div class="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class={[
          "text-3xl font-bold tracking-tight",
          "bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900",
          "dark:from-slate-100 dark:via-white dark:to-slate-100",
          "bg-clip-text text-transparent"
        ]}>
          {@title}
        </h1>
        <p class="mt-2 text-base text-slate-600 dark:text-slate-400">
          Manage your account settings and preferences
        </p>
      </div>

      <div :if={render_slot(@inner_block) != []} class="flex items-center gap-3">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # Modern settings tabs container with enhanced navigation
  defp settings_tabs_container(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Settings breadcrumb navigation --%>
      <.settings_breadcrumb />

      <%!-- Settings content area --%>
      <.liquid_card class="overflow-hidden">
        <div class="flex flex-col lg:flex-row lg:divide-x lg:divide-slate-200/60 dark:lg:divide-slate-700/60">
          <%!-- Settings navigation submenu --%>
          <div class="lg:w-72 lg:flex-shrink-0">
            <div class="p-6">
              <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-4">
                Settings Menu
              </h3>
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
          <div class="flex-1 lg:min-w-0">
            <div class="p-6 lg:p-8">
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </.liquid_card>
    </div>
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
