defmodule MossletWeb.GroupLive.PendingComponent do
  use MossletWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-5">
      <div class="flex items-center gap-3 pb-4 border-b border-slate-200/60 dark:border-slate-700/60">
        <div class="p-2.5 rounded-xl bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/30 dark:to-teal-900/30">
          <.phx_icon name="hero-gift" class="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
        </div>
        <div>
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            Group Invitations
          </h2>
          <p class="text-sm text-slate-600 dark:text-slate-400">
            Review invitations and decide which groups to join
          </p>
        </div>
      </div>

      <div
        id="groups-greeter"
        phx-update="stream"
        class="space-y-3"
      >
        <%= for {id, group} <- @stream do %>
          <% user_group = get_user_group(group, @current_user) %>
          <% uconn = get_current_user_connection_between_users!(group.user_id, @current_user.id) %>
          <MossletWeb.DesignSystem.liquid_pending_group_card
            id={id}
            name={decr_item(group.name, @current_user, user_group.key, @key, group)}
            description={decr_item(group.description, @current_user, user_group.key, @key, group)}
            inviter_name={decr_uconn(uconn.connection.username, @current_user, uconn.key, @key)}
            inserted_at={group.inserted_at}
            requires_password={group.require_password?}
          >
            <:members>
              <%= for user_group <- Enum.take(Enum.filter(group.user_groups, & &1.confirmed_at), 5) do %>
                <% member_uconn =
                  get_uconn_for_users(
                    get_user_from_user_group_id(user_group.id),
                    @current_user
                  ) %>

                <.phx_avatar
                  :if={user_group.user_id != @current_user.id && member_uconn}
                  src={get_user_avatar(member_uconn, @key)}
                  alt="group member"
                  class="h-8 w-8 rounded-full ring-2 ring-white dark:ring-slate-800 bg-slate-100 dark:bg-slate-700"
                />

                <.phx_avatar
                  :if={user_group.user_id != @current_user.id && !member_uconn}
                  src={
                    ~p"/images/groups/#{decr_item(user_group.avatar_img, @current_user, get_user_group(group, @current_user).key, @key, group)}"
                  }
                  alt="group member"
                  class="h-8 w-8 rounded-full ring-2 ring-white dark:ring-slate-800 bg-slate-100 dark:bg-slate-700"
                />

                <.phx_avatar
                  :if={user_group.user_id == @current_user.id}
                  src={maybe_get_user_avatar(@current_user, @key)}
                  alt="you"
                  class="h-8 w-8 rounded-full ring-2 ring-white dark:ring-slate-800 bg-slate-100 dark:bg-slate-700"
                />
              <% end %>
              <div
                :if={Enum.count(group.user_groups, & &1.confirmed_at) > 5}
                class="flex items-center justify-center h-8 w-8 rounded-full ring-2 ring-white dark:ring-slate-800 bg-slate-100 dark:bg-slate-700 text-xs font-medium text-slate-600 dark:text-slate-400"
              >
                +{Enum.count(group.user_groups, & &1.confirmed_at) - 5}
              </div>
            </:members>
            <:actions>
              <MossletWeb.DesignSystem.liquid_button
                :if={can_delete_user_group?(get_user_group(group, @current_user), @current_user)}
                phx-click={
                  JS.push("delete-user-group",
                    value: %{id: get_user_group(group, @current_user).id}
                  )
                  |> hide("##{id}")
                }
                data-confirm="Are you sure you want to decline this invitation?"
                size="sm"
                variant="secondary"
                color="rose"
              >
                Decline
              </MossletWeb.DesignSystem.liquid_button>

              <MossletWeb.DesignSystem.liquid_button
                :if={group.require_password?}
                phx-click={JS.navigate(~p"/app/groups/#{group}/join-password")}
                size="sm"
                color="emerald"
                icon="hero-lock-closed"
              >
                Join Group
              </MossletWeb.DesignSystem.liquid_button>

              <MossletWeb.DesignSystem.liquid_button
                :if={!group.require_password?}
                phx-click={JS.patch(~p"/app/groups/#{group}/join")}
                size="sm"
                color="emerald"
                icon="hero-check"
              >
                Join Group
              </MossletWeb.DesignSystem.liquid_button>
            </:actions>
          </MossletWeb.DesignSystem.liquid_pending_group_card>
        <% end %>

        <div :if={!@any_pending_groups?} class="py-8 text-center">
          <MossletWeb.DesignSystem.liquid_empty_state
            icon="hero-gift"
            title="No pending invitations"
            description="You're all caught up! When someone invites you to a group, it will appear here."
            color="emerald"
          />
        </div>
      </div>

      <div class="flex justify-end pt-4 border-t border-slate-200/60 dark:border-slate-700/60">
        <MossletWeb.DesignSystem.liquid_button
          type="button"
          variant="secondary"
          color="slate"
          phx-click={JS.exec("data-cancel", to: "#pending-group-modal")}
        >
          Close
        </MossletWeb.DesignSystem.liquid_button>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end
end
