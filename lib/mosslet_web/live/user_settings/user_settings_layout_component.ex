defmodule MossletWeb.UserSettingsLayoutComponent do
  @moduledoc """
  A layout for any user setting screen like "Change email", "Change password" etc
  """
  use MossletWeb, :component
  use PetalComponents

  attr :current_user, :map
  attr :current_page, :atom
  attr :key, :string, doc: "the session key for the current user"
  slot :inner_block

  def settings_layout(assigns) do
    ~H"""
    <.layout current_page={@current_page} current_user={@current_user} key={@key} type="sidebar">
      <.container max_width="xl" class="py-10">
        <.page_header title={gettext("Settings")} />

        <.sidebar_tabs_container current_page={@current_page} menu_items={menu_items(@current_user)}>
          {render_slot(@inner_block)}
        </.sidebar_tabs_container>
      </.container>
    </.layout>
    """
  end

  def settings_group_layout(assigns) do
    ~H"""
    <.layout current_page={@current_page} current_user={@current_user} key={@key} type="sidebar">
      <.container max_width="xl" class="py-10">
        <.page_header title={Gettext.gettext(MossletWeb.Gettext, @edit_group_name)}>
          <.button
            icon="hero-arrow-long-left"
            link_type="live_patch"
            class="rounded-full"
            label={"Back to #{decr_item(@group.name, @current_user, @user_group.key, @key, @group)} Group"}
            to={~p"/app/groups/#{@group}"}
          />
        </.page_header>

        <.sidebar_tabs_container
          current_page={@current_page}
          menu_items={menu_items_group(@current_user, @group, @user_group)}
        >
          {render_slot(@inner_block)}
        </.sidebar_tabs_container>
      </.container>
    </.layout>
    """
  end

  defp menu_items(current_user) do
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
        # :org_invitations, coming soon
        :billing,
        :delete_account
      ],
      current_user
    )
  end

  defp menu_items_group(current_user, group, user_group) do
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
