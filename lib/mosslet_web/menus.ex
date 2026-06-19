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

  # Show an org-scoped nav item when the user owns or belongs to an ACTIVE org of
  # that type (Option B / Task #235). "Active" means the org's own `:org`-source
  # subscription is live — an org created but not yet paid for is inert and does
  # NOT surface nav. Personal-plan users (no org) see no Family/Business items.
  defp show_org_nav?(current_user, type) do
    Mosslet.Orgs.has_active_org_of_type?(current_user, type)
  end

  @doc """
  Resolves a user's plan type for UI tailoring: `:family`, `:business`, or
  `:personal`.

  A user is Family/Business when they own or belong to an ACTIVE org of that
  type (its `:org`-source subscription is live). This is fully independent of
  the user's personal (`:user`-source) plan — a personal subscriber with no org
  is `:personal`. Everyone else is `:personal`.
  """
  def plan_type(nil), do: :personal

  def plan_type(current_user) do
    cond do
      show_org_nav?(current_user, :business) -> :business
      show_org_nav?(current_user, :family) -> :family
      true -> :personal
    end
  end

  @doc """
  A human-friendly label for a user's plan type (for badges/headers).
  """
  def plan_label(current_user) do
    case plan_type(current_user) do
      :business -> gettext("Business")
      :family -> gettext("Family")
      :personal -> gettext("Personal")
    end
  end

  @doc """
  Returns true when the user has at least one pending org invitation.
  """
  def has_pending_invitations?(nil), do: false

  def has_pending_invitations?(current_user) do
    current_user
    |> Mosslet.Orgs.list_invitations_by_user()
    |> Enum.any?()
  end

  # Public menu (marketing related pages)
  def public_menu_items(_user \\ nil),
    do: [
      %{label: gettext("Blog"), path: "/blog"},
      %{label: gettext("Discover"), path: "/discover"},
      %{label: gettext("Features"), path: "/features"},
      %{label: gettext("Pricing"), path: "/pricing"}
    ]

  def public_menu_footer_items(_user \\ nil),
    do: [
      %{label: gettext("About"), path: "/about"},
      %{label: gettext("Blog"), path: "/blog"},
      %{label: gettext("Discover"), path: "/discover"},
      # %{label: gettext("Download"), path: "/download"},
      %{label: gettext("FAQ"), path: "/faq"},
      %{label: gettext("Features"), path: "/features"},
      %{label: gettext("Pricing"), path: "/pricing"},
      %{label: gettext("Privacy"), path: "/privacy"},
      %{label: gettext("Referrals"), path: "/referrals"},
      %{label: gettext("Support"), path: "/support"},
      %{label: gettext("Updates"), path: "/updates"}
    ]

  # Signed out main menu
  def main_menu_items(nil), do: []

  # Signed in main menu
  def main_menu_items(current_user) do
    cond do
      # Admin users get admin-only menu
      admin?(current_user) ->
        build_menu(
          [
            :admin_backups,
            :admin_bot_defense,
            :admin_dashboard,
            :admin_key_rotation,
            :admin_moderation,
            :admin_settings
          ],
          current_user
        )

      # Regular users get normal app menu
      current_user.connection.profile ->
        build_menu(
          [
            :home,
            :journal,
            :circles,
            :connections,
            :conversations,
            :timeline,
            :family,
            :business,
            :settings,
            :subscribe
          ],
          current_user
        )

      # Users without profile get dashboard menu
      true ->
        build_menu(
          [
            :dashboard,
            :journal,
            :circles,
            :connections,
            :conversations,
            :timeline,
            :family,
            :business,
            :settings,
            :subscribe
          ],
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

  def build_menu_with_sections(menu_items, current_user \\ nil) do
    menu_items
    |> Enum.map(fn
      %{type: :section} = section ->
        section

      menu_item when is_atom(menu_item) ->
        get_link(menu_item, current_user)

      menu_item when is_map(menu_item) ->
        Map.merge(
          get_link(menu_item.name, current_user),
          menu_item
        )
    end)
    |> Enum.filter(& &1)
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

  def get_link(:settings = name, current_user) do
    %{
      name: name,
      label: gettext("Settings"),
      path: ~p"/app/users/edit-details",
      icon: "hero-cog",
      badge: plan_label(current_user),
      children: settings_children(current_user)
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
      path: ~p"/app/users/edit-status",
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

  # Only surfaced when the user actually has a pending org invitation, so the
  # settings menu stays clean for everyone else.
  def get_link(:org_invitations = name, current_user) do
    if has_pending_invitations?(current_user) do
      %{
        name: name,
        label: gettext("Invitations"),
        path: ~p"/app/users/org-invitations",
        icon: "hero-envelope"
      }
    end
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

  def get_link(:bluesky_settings = name, _current_user) do
    %{
      name: name,
      label: gettext("Bluesky"),
      path: ~p"/app/users/bluesky",
      icon: "hero-cloud"
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
    profile = current_user.connection.profile

    path =
      if profile && profile.slug do
        ~p"/app/profile/#{profile.slug}"
      else
        ~p"/app"
      end

    %{
      name: name,
      label: gettext("Home"),
      path: path,
      icon: "hero-home"
    }
  end

  def get_link(:connections = name, _current_user) do
    %{
      name: name,
      label: gettext("Connections"),
      path: ~p"/app/users/connections",
      icon: "hero-users"
    }
  end

  def get_link(:conversations = name, _current_user) do
    %{
      name: name,
      label: gettext("Conversations"),
      path: ~p"/app/conversations",
      icon: "hero-chat-bubble-left-right"
    }
  end

  def get_link(:circles = name, _current_user) do
    %{
      name: name,
      label: gettext("Circles"),
      path: ~p"/app/circles",
      icon: "hero-circle-stack"
    }
  end

  # Family nav item is only shown when the user belongs to a :family org OR
  # holds an active family plan (so new subscribers can reach org creation).
  def get_link(:family = name, current_user) do
    if current_user && show_org_nav?(current_user, :family) do
      %{
        name: name,
        label: gettext("Family"),
        path: ~p"/app/family",
        icon: "hero-heart"
      }
    end
  end

  # Business nav item is only shown when the user belongs to a :business org OR
  # holds an active business plan (Q4 — keeps the sidebar clean for the majority
  # who never use it).
  def get_link(:business = name, current_user) do
    if current_user && show_org_nav?(current_user, :business) do
      %{
        name: name,
        label: gettext("Business"),
        path: ~p"/app/business",
        icon: "hero-building-office"
      }
    end
  end

  # def get_link(:orgs = name, _current_user) do
  #  %{
  #    name: name,
  #    label: gettext("Organizations"),
  #    path: ~p"/app/orgs",
  #    icon: "hero-building-office"
  #  }
  # end

  # Settings-menu variants of the family/business links. Same gating as the
  # sidebar items, but worded as a management entry point ("Manage ...") and
  # placed under the settings "Plan & Organization" section.
  def get_link(:manage_family = name, current_user) do
    if current_user && show_org_nav?(current_user, :family) do
      %{
        name: name,
        label: gettext("Manage Family"),
        path: ~p"/app/family",
        icon: "hero-heart"
      }
    end
  end

  def get_link(:manage_business = name, current_user) do
    if current_user && show_org_nav?(current_user, :business) do
      %{
        name: name,
        label: gettext("Manage Business"),
        path: ~p"/app/business",
        icon: "hero-building-office"
      }
    end
  end

  def get_link(:subscribe = name, current_user) do
    if Customers.entity() == :user && not MossletWeb.Helpers.user_has_paid?(current_user) do
      %{
        name: name,
        label: gettext("Plans"),
        path: ~p"/app/subscribe",
        icon: "hero-credit-card"
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

  def get_link(:journal = name, _current_user) do
    %{
      name: name,
      label: gettext("Journal"),
      path: ~p"/app/journal",
      icon: "hero-pencil-square"
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

  def get_link(:referrals = name, _current_user) do
    %{
      name: name,
      label: gettext("Referrals"),
      path: ~p"/app/referrals",
      icon: "hero-banknotes"
    }
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
  def get_link(:admin_backups = name, current_user) do
    if current_user.is_admin? && current_user.confirmed_at do
      %{
        name: name,
        label: gettext("Backups"),
        path: ~p"/admin/backups",
        icon: "hero-archive-box"
      }
    end
  end

  def get_link(:admin_bot_defense = name, current_user) do
    if current_user.is_admin? && current_user.confirmed_at do
      %{
        name: name,
        label: gettext("Bot Defense"),
        path: ~p"/admin/bot-defense",
        icon: "hero-bug-ant"
      }
    end
  end

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

  def get_link(:admin_key_rotation = name, current_user) do
    if current_user.is_admin? && current_user.confirmed_at do
      %{
        name: name,
        label: gettext("Key Rotation"),
        path: ~p"/admin/key-rotation",
        icon: "hero-key"
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
  #    path: ~p"/app/circles/#{group}/edit-group",
  #    icon: "hero-user-group"
  #  }
  # end

  def get_link(:edit_circle_members = name, _current_user, group, user_group)
      when user_group.role in [:owner, :admin] do
    %{
      name: name,
      label: gettext("Edit members"),
      path: ~p"/app/circles/#{group}/edit-group-members",
      icon: "hero-users"
    }
  end

  def get_link(:edit_circle_members = _name, _current_user, _group, _user_group), do: nil

  def get_link(:moderate_circle_members = name, _current_user, group, user_group)
      when user_group.role in [:owner, :admin, :moderator] do
    %{
      name: name,
      label: gettext("Manage members"),
      path: ~p"/app/circles/#{group}/moderate-members",
      icon: "hero-shield-exclamation"
    }
  end

  def get_link(:moderate_circle_members = _name, _current_user, _group, _user_group), do: nil

  # def get_link(:edit_group_notifications = name, _current_user, group, _user_group) do
  #  %{
  #    name: name,
  #    label: gettext("Edit notifications"),
  #    path: ~p"/app/circles/#{group}/edit-notifications",
  #    icon: "hero-bell"
  #  }
  # end

  # Builds the settings submenu, tailored to the user's plan. Profile/Security/
  # Integrations stay constant; the "Plan & Organization" category surfaces
  # Billing plus contextual entries (pending Invitations, Manage Family/Business)
  # for Family/Business subscribers and org members.
  defp settings_children(current_user) do
    profile_and_security() ++
      plan_and_org_category(current_user) ++
      account_category()
  end

  defp profile_and_security do
    [
      %{type: :category, label: gettext("Profile")},
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
        name: :edit_status,
        label: gettext("Status"),
        description: gettext("Manage your online status and presence"),
        path: ~p"/app/users/edit-status",
        icon: "hero-signal"
      },
      %{type: :category, label: gettext("Security")},
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
      %{type: :category, label: gettext("Integrations")},
      %{
        name: :bluesky_settings,
        label: gettext("Bluesky"),
        description: gettext("Connect and sync with Bluesky"),
        path: ~p"/app/users/bluesky",
        icon: "hero-cloud"
      }
    ]
  end

  # Plan & Organization: Billing for everyone, plus plan-specific management and
  # any pending invitations. Filters out entries that don't apply to this user.
  defp plan_and_org_category(current_user) do
    plan = plan_type(current_user)

    contextual =
      [
        if has_pending_invitations?(current_user) do
          %{
            name: :org_invitations,
            label: gettext("Invitations"),
            description: gettext("Review pending family or business invitations"),
            path: ~p"/app/users/org-invitations",
            icon: "hero-envelope"
          }
        end,
        if plan == :family do
          %{
            name: :manage_family,
            label: gettext("Manage Family"),
            description: gettext("Members, guardianship, and your family circle"),
            path: ~p"/app/family",
            icon: "hero-users"
          }
        end,
        if plan == :business do
          %{
            name: :manage_business,
            label: gettext("Manage Business"),
            description: gettext("Team members, business circles, and file sharing"),
            path: ~p"/app/business",
            icon: "hero-building-office"
          }
        end
      ]
      |> Enum.reject(&is_nil/1)

    [
      %{type: :category, label: gettext("Plan & Organization")},
      %{
        name: :billing,
        label: gettext("Billing"),
        description: billing_description(plan),
        path: ~p"/app/billing",
        icon: "hero-credit-card"
      }
      | contextual
    ] ++
      [
        %{
          name: :referrals,
          label: gettext("Referrals"),
          description: gettext("Earn rewards by inviting friends"),
          path: ~p"/app/referrals",
          icon: "hero-banknotes"
        }
      ]
  end

  defp billing_description(:family),
    do: gettext("Manage your family subscription, seats, and payments")

  defp billing_description(:business),
    do: gettext("Manage your business subscription, seats, and payments")

  defp billing_description(_),
    do: gettext("Manage subscription and payments")

  defp account_category do
    [
      %{type: :category, label: gettext("Account")},
      %{
        name: :manage_data,
        label: gettext("Data"),
        description: gettext("Export or manage your personal data"),
        path: ~p"/app/users/manage-data",
        icon: "hero-circle-stack"
      },
      %{type: :category, label: gettext("Danger Zone")},
      %{
        name: :delete_account,
        label: gettext("Delete Account"),
        description: gettext("Permanently delete your account"),
        path: ~p"/app/users/delete-account",
        icon: "hero-trash"
      }
    ]
  end
end
