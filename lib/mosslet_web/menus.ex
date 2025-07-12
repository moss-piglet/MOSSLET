defmodule MossletWeb.Menus do
  @moduledoc """
  Describe all of your navigation menus in here. This keeps you from having to define them in a layout template
  """
  use MossletWeb, :verified_routes

  use Gettext, backend: MossletWeb.Gettext

  alias Mosslet.Billing.Customers
  alias MossletWeb.Helpers

  # Public menu (marketing related pages)
  def public_menu_items(_user \\ nil),
    do: [
      %{label: gettext("About"), path: "/about"},
      %{label: gettext("MYOB"), path: "/myob"},
      %{label: gettext("Blog"), path: "/blog"},
      %{label: gettext("Features"), path: "/features"},
      %{label: gettext("Huh?"), path: "/in-the-know"},
      %{label: gettext("Pricing"), path: "/pricing"},
      %{label: gettext("FAQ"), path: "/faq"}
    ]

  def public_menu_footer_items(_user \\ nil),
    do: [
      %{label: gettext("About"), path: "/about#"},
      %{label: gettext("MYOB"), path: "/myob"},
      %{label: gettext("Blog"), path: "/blog"},
      %{label: gettext("Features"), path: "/features"},
      %{label: gettext("Huh?"), path: "/in-the-know"},
      %{label: gettext("Pricing"), path: "/pricing"},
      %{label: gettext("Privacy"), path: "/privacy"},
      %{label: gettext("FAQ"), path: "/faq"}
    ]

  # Signed out main menu
  def main_menu_items(nil), do: []

  # Signed in main menu
  def main_menu_items(current_user) do
    if current_user.connection.profile do
      build_menu(
        [:home, :connections, :groups, :timeline, :faq, :subscribe],
        current_user
      )
    else
      build_menu(
        [:dashboard, :connections, :groups, :timeline, :faq, :subscribe],
        current_user
      )
    end
  end

  # Signed out user menu
  def user_menu_items(nil), do: build_menu([:sign_in, :register], nil)

  # Signed in user menu
  def user_menu_items(current_user) do
    if current_user.connection.profile do
      build_menu([:home, :settings, :admin, :dev, :sign_out], current_user)
    else
      build_menu([:dashboard, :settings, :admin, :dev, :sign_out], current_user)
    end
  end

  def build_menu(menu_items, current_user \\ nil) do
    menu_items
    |> Enum.map(fn menu_item ->
      cond do
        is_atom(menu_item) ->
          get_link(menu_item, current_user)

        is_map(menu_item) ->
          Map.merge(
            get_link(menu_item.name, current_user),
            menu_item
          )
      end
    end)
    |> Enum.filter(& &1)
  end

  def build_menu_group(menu_items, current_user \\ nil, group \\ nil, user_group \\ nil) do
    menu_items
    |> Enum.map(fn menu_item ->
      cond do
        is_atom(menu_item) ->
          get_link(menu_item, current_user, group, user_group)

        is_map(menu_item) ->
          Map.merge(
            get_link(menu_item.name, current_user, group, user_group),
            menu_item
          )
      end
    end)
    |> Enum.filter(& &1)
  end

  def get_link(name, current_user \\ nil)

  def get_link(:register = name, _current_user) do
    %{
      name: name,
      label: gettext("Register"),
      path: ~p"/auth/register",
      icon: "hero-clipboard-document-list"
    }
  end

  def get_link(:sign_in = name, _current_user) do
    %{
      name: name,
      label: gettext("Sign In"),
      path: ~p"/auth/sign_in",
      icon: "hero-key"
    }
  end

  def get_link(:sign_out = name, _current_user) do
    %{
      name: name,
      label: gettext("Sign out"),
      path: ~p"/auth/sign_out",
      icon: "hero-arrow-right-on-rectangle",
      method: :delete
    }
  end

  def get_link(:settings = name, _current_user) do
    %{
      name: name,
      label: gettext("Settings"),
      path: ~p"/app/users/edit-details",
      icon: "hero-cog"
    }
  end

  def get_link(:edit_details = name, _current_user) do
    %{
      name: name,
      label: gettext("Edit details"),
      path: ~p"/app/users/edit-details",
      icon: "hero-user-circle"
    }
  end

  def get_link(:edit_profile = name, _current_user) do
    %{
      name: name,
      label: gettext("Edit profile"),
      path: ~p"/app/users/edit-profile",
      icon: "hero-identification"
    }
  end

  def get_link(:edit_email = name, _current_user) do
    %{
      name: name,
      label: gettext("Change email"),
      path: ~p"/app/users/edit-email",
      icon: "hero-at-symbol"
    }
  end

  def get_link(:edit_visibility = name, _current_user) do
    %{
      name: name,
      label: gettext("Change visibility"),
      path: ~p"/app/users/edit-visibility",
      icon: "hero-eye"
    }
  end

  def get_link(:edit_forgot_password = name, _current_user) do
    %{
      name: name,
      label: gettext("Change forgot password"),
      path: ~p"/app/users/change-forgot-password",
      icon: "hero-lifebuoy"
    }
  end

  def get_link(:delete_account = name, _current_user) do
    %{
      name: name,
      label: gettext("Delete your account"),
      path: ~p"/app/users/delete-account",
      icon: "hero-trash"
    }
  end

  def get_link(:edit_notifications = name, _current_user) do
    %{
      name: name,
      label: gettext("Edit notifications"),
      path: ~p"/app/users/edit-notifications",
      icon: "hero-bell"
    }
  end

  def get_link(:edit_password = name, _current_user) do
    %{
      name: name,
      label: gettext("Edit password"),
      path: ~p"/app/users/change-password",
      icon: "hero-key"
    }
  end

  def get_link(:org_invitations = name, _current_user) do
    %{
      name: name,
      label: gettext("Invitations"),
      path: ~p"/app/users/org-invitations",
      icon: "hero-envelope"
    }
  end

  def get_link(:edit_totp = name, _current_user) do
    %{
      name: name,
      label: gettext("2FA"),
      path: ~p"/app/users/two-factor-authentication",
      icon: "hero-shield-check"
    }
  end

  def get_link(:manage_data = name, _current_user) do
    %{
      name: name,
      label: gettext("Manage data"),
      path: ~p"/app/users/manage-data",
      icon: "hero-circle-stack"
    }
  end

  def get_link(:dashboard = name, _current_user) do
    %{
      name: name,
      label: gettext("Home"),
      path: ~p"/app",
      icon: "hero-home"
    }
  end

  def get_link(:home = name, current_user) do
    if current_user.connection.profile do
      %{
        name: name,
        label: gettext("Home"),
        path: ~p"/app/profile/#{current_user.connection.profile.slug}",
        icon: "hero-home"
      }
    end
  end

  def get_link(:connections = name, _current_user) do
    %{
      name: name,
      label: gettext("Connections"),
      path: ~p"/app/users/connections",
      icon: "hero-users"
    }
  end

  def get_link(:faq = name, _current_user) do
    %{
      name: name,
      label: gettext("FAQ"),
      path: ~p"/app/faq",
      icon: "hero-question-mark-circle"
    }
  end

  def get_link(:groups = name, _current_user) do
    %{
      name: name,
      label: gettext("Groups"),
      path: ~p"/app/groups",
      icon: "hero-user-group"
    }
  end

  # def get_link(:orgs = name, _current_user) do
  #  %{
  #    name: name,
  #    label: gettext("Organizations"),
  #    path: ~p"/app/orgs",
  #    icon: "hero-building-office"
  #  }
  # end

  def get_link(:subscribe = name, _current_user) do
    if Customers.entity() == :user do
      %{
        name: name,
        label: gettext("Pay Once"),
        path: ~p"/app/subscribe",
        icon: "hero-shopping-bag"
      }
    end
  end

  def get_link(:timeline = name, _current_user) do
    %{
      name: name,
      label: gettext("Timeline"),
      path: ~p"/app/timeline",
      icon: "hero-book-open"
    }
  end

  def get_link(:billing = name, _current_user) do
    if Customers.entity() == :user do
      %{
        name: name,
        label: gettext("Billing"),
        path: ~p"/app/billing",
        icon: "hero-credit-card"
      }
    end
  end

  def get_link(:admin, current_user) do
    link = get_link(:admin_users, current_user)

    if link do
      link
      |> Map.put(:label, gettext("Admin"))
      |> Map.put(:icon, :lock_closed)
    end
  end

  def get_link(:admin_users = name, current_user) do
    if Helpers.admin?(current_user) do
      %{
        name: name,
        label: gettext("Users"),
        path: ~p"/admin/users",
        icon: "hero-users"
      }
    end
  end

  def get_link(:admin_orgs = name, current_user) do
    if Helpers.admin?(current_user) do
      %{
        name: name,
        label: gettext("Orgs"),
        path: ~p"/admin/orgs",
        icon: "hero-building-office-2"
      }
    end
  end

  def get_link(:admin_logs = name, current_user) do
    if Helpers.admin?(current_user) do
      %{
        name: name,
        label: gettext("Logs"),
        path: ~p"/admin/logs",
        icon: "hero-eye"
      }
    end
  end

  def get_link(:admin_jobs = name, current_user) do
    if Helpers.admin?(current_user) do
      %{
        name: name,
        label: gettext("Jobs"),
        path: ~p"/admin/jobs",
        icon: "hero-server"
      }
    end
  end

  def get_link(:admin_subscriptions = name, current_user) do
    if Helpers.admin?(current_user) do
      %{
        name: name,
        label: gettext("Subscriptions"),
        path: ~p"/admin/subscriptions",
        icon: "hero-wallet"
      }
    end
  end

  def get_link(:dev = name, _current_user) do
    if Mosslet.config(:env) == :dev do
      %{
        name: name,
        label: gettext("Dev"),
        path: "/dev",
        icon: "hero-code-bracket"
      }
    end
  end

  def get_link(:dev_email_templates = name, _current_user) do
    if Mosslet.config(:env) == :dev do
      %{
        name: name,
        label: gettext("Email templates"),
        path: "/dev/emails",
        icon: "hero-rectangle-group"
      }
    end
  end

  def get_link(:dev_sent_emails = name, _current_user) do
    if Mosslet.config(:env) == :dev do
      %{
        name: name,
        label: gettext("Sent emails"),
        path: "/dev/emails/sent",
        icon: "hero-at-symbol"
      }
    end
  end

  def get_link(:dev_resources = name, _current_user) do
    if Mosslet.config(:env) == :dev do
      %{
        name: name,
        label: gettext("Resources"),
        path: ~p"/dev/resources",
        icon: "hero-clipboard-document-list"
      }
    end
  end

  # def get_link(:edit_group = name, _current_user, group, _user_group) do
  #  %{
  #    name: name,
  #    label: gettext("Edit group"),
  #    path: ~p"/app/groups/#{group}/edit-group",
  #    icon: "hero-user-group"
  #  }
  # end

  def get_link(:edit_group_members = name, _current_user, group, user_group)
      when user_group.role in [:owner, :admin] do
    %{
      name: name,
      label: gettext("Edit members"),
      path: ~p"/app/groups/#{group}/edit-group-members",
      icon: "hero-users"
    }
  end

  def get_link(:edit_group_members = _name, _current_user, _group, _user_group), do: nil

  # def get_link(:edit_group_notifications = name, _current_user, group, _user_group) do
  #  %{
  #    name: name,
  #    label: gettext("Edit notifications"),
  #    path: ~p"/app/groups/#{group}/edit-notifications",
  #    icon: "hero-bell"
  #  }
  # end
end
