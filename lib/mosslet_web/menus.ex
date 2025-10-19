defmodule MossletWeb.Menus do
  @moduledoc """
  Describe all of your navigation menus in here. This keeps you from having to define them in a layout template
  """
  use MossletWeb, :verified_routes

  use Gettext, backend: MossletWeb.Gettext

  alias Mosslet.Billing.Customers

  # Helper function to check if user is admin
  defp admin?(current_user) do
    current_user.is_admin? && current_user.confirmed_at
  end

  # Public menu (marketing related pages)
  def public_menu_items(_user \\ nil),
    do: [
      %{label: gettext("About"), path: "/about"},
      %{label: gettext("MYOB"), path: "/myob"},
      %{label: gettext("Blog"), path: "/blog"},
      %{label: gettext("Features"), path: "/features"},
      %{label: gettext("Huh?"), path: "/in-the-know"},
      %{label: gettext("Pricing"), path: "/pricing"}
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
      %{label: gettext("Support"), path: "/support"},
      %{label: gettext("FAQ"), path: "/faq"}
    ]

  # Signed out main menu
  def main_menu_items(nil), do: []

  # Signed in main menu
  def main_menu_items(current_user) do
    cond do
      # Admin users get admin-only menu
      admin?(current_user) ->
        build_menu([:admin_dashboard, :admin_moderation, :admin_settings], current_user)

      # Regular users get normal app menu
      current_user.connection.profile ->
        build_menu(
          [:home, :connections, :groups, :timeline, :settings, :subscribe],
          current_user
        )

      # Users without profile get dashboard menu
      true ->
        build_menu(
          [:dashboard, :connections, :groups, :timeline, :settings, :subscribe],
          current_user
        )
    end
  end

  # Signed out user menu
  def user_menu_items(%{current_user: nil}), do: build_menu([:sign_in, :register], nil)
  def user_menu_items(%{totp_pending: true}), do: build_menu([:sign_in, :register], nil)

  def user_menu_items(%{current_user: current_user}) do
    if current_user.connection.profile do
      build_menu([:home, :settings, :sign_out], current_user)
    else
      build_menu([:dashboard, :settings, :sign_out], current_user)
    end
  end

  # Fallback for legacy direct calls with just a user
  def user_menu_items(nil), do: build_menu([:sign_in, :register], nil)

  def user_menu_items(current_user) when is_map(current_user) do
    user_menu_items(%{current_user: current_user})
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
      icon: "hero-cog",
      children: [
        %{
          name: :edit_details,
          label: gettext("Profile Details"),
          description: gettext("Update your name, username, and avatar"),
          path: ~p"/app/users/edit-details",
          icon: "hero-user-circle"
        },
        %{
          name: :edit_profile,
          label: gettext("Profile"),
          description: gettext("Manage your public profile and bio"),
          path: ~p"/app/users/edit-profile",
          icon: "hero-identification"
        },
        %{
          name: :edit_email,
          label: gettext("Email"),
          description: gettext("Change your email address"),
          path: ~p"/app/users/edit-email",
          icon: "hero-at-symbol"
        },
        %{
          name: :edit_visibility,
          label: gettext("Visibility"),
          description: gettext("Control who can see your profile"),
          path: ~p"/app/users/edit-visibility",
          icon: "hero-eye"
        },
        %{
          name: :status,
          label: gettext("Status"),
          description: gettext("Manage your online status and presence"),
          path: ~p"/app/users/status",
          icon: "hero-signal"
        },
        %{
          name: :edit_password,
          label: gettext("Password"),
          description: gettext("Update your login password"),
          path: ~p"/app/users/change-password",
          icon: "hero-key"
        },
        %{
          name: :edit_forgot_password,
          label: gettext("Recovery"),
          description: gettext("Set up account recovery options"),
          path: ~p"/app/users/change-forgot-password",
          icon: "hero-lifebuoy"
        },
        %{
          name: :edit_notifications,
          label: gettext("Notifications"),
          description: gettext("Manage email and push notifications"),
          path: ~p"/app/users/edit-notifications",
          icon: "hero-bell"
        },
        %{
          name: :edit_totp,
          label: gettext("2FA"),
          description: gettext("Two-factor authentication security"),
          path: ~p"/app/users/two-factor-authentication",
          icon: "hero-shield-check"
        },
        %{
          name: :blocked_users,
          label: gettext("Blocked Users"),
          description: gettext("Manage users you've blocked"),
          path: ~p"/app/users/blocked-users",
          icon: "hero-user-minus"
        },
        %{
          name: :manage_data,
          label: gettext("Data"),
          description: gettext("Export or manage your personal data"),
          path: ~p"/app/users/manage-data",
          icon: "hero-circle-stack"
        },
        %{
          name: :billing,
          label: gettext("Billing"),
          description: gettext("Manage subscription and payments"),
          path: ~p"/app/billing",
          icon: "hero-credit-card"
        },
        %{
          name: :delete_account,
          label: gettext("Delete Account"),
          description: gettext("Permanently delete your account"),
          path: ~p"/app/users/delete-account",
          icon: "hero-trash"
        }
      ]
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

  def get_link(:status = name, _current_user) do
    %{
      name: name,
      label: gettext("Status"),
      path: ~p"/app/users/status",
      icon: "hero-signal"
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

  def get_link(:blocked_users = name, _current_user) do
    %{
      name: name,
      label: gettext("Blocked users"),
      path: ~p"/app/users/blocked-users",
      icon: "hero-user-minus"
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

  # Admin menu items
  def get_link(:admin_dashboard = name, current_user) do
    if current_user.is_admin? && current_user.confirmed_at do
      %{
        name: name,
        label: gettext("Dashboard"),
        path: ~p"/admin/dash",
        icon: "hero-chart-bar"
      }
    end
  end

  def get_link(:admin_moderation = name, current_user) do
    if current_user.is_admin? && current_user.confirmed_at do
      %{
        name: name,
        label: gettext("Moderation"),
        path: ~p"/admin/moderation",
        icon: "hero-shield-check"
      }
    end
  end

  def get_link(:admin_settings = name, current_user) do
    if current_user.is_admin? && current_user.confirmed_at do
      %{
        name: name,
        label: gettext("Admin Tools"),
        path: ~p"/admin/dash",
        icon: "hero-wrench-screwdriver",
        children: [
          %{
            name: :admin_server,
            label: gettext("Server Dashboard"),
            description: gettext("Phoenix LiveDashboard metrics"),
            path: ~p"/admin/server",
            icon: "hero-server"
          },
          %{
            name: :admin_oban,
            label: gettext("Background Jobs"),
            description: gettext("Oban job queue management"),
            path: ~p"/admin/oban",
            icon: "hero-queue-list"
          }
        ]
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
