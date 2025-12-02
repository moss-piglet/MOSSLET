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
        <div
          :for={{id, group} <- @stream}
          id={id}
          class="group/card relative p-4 rounded-xl bg-gradient-to-br from-white via-slate-50/50 to-white dark:from-slate-800/80 dark:via-slate-700/40 dark:to-slate-800/80 border border-slate-200/60 dark:border-slate-700/60 hover:border-emerald-300/60 dark:hover:border-emerald-600/40 shadow-sm hover:shadow-md hover:shadow-emerald-500/5 dark:hover:shadow-emerald-400/5 transition-all duration-200"
        >
          <div class="flex flex-col sm:flex-row gap-4">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-2">
                <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate">
                  {decr_item(
                    group.name,
                    @current_user,
                    get_user_group(group, @current_user).key,
                    @key,
                    group
                  )}
                </h3>
                <span
                  :if={group.require_password?}
                  id={group.id <> "-password-badge"}
                  class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-xs font-medium bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300"
                  data-tippy-content="This group requires a password to join"
                  phx-hook="TippyHook"
                >
                  <.phx_icon name="hero-lock-closed" class="w-3 h-3" /> Password
                </span>
              </div>

              <p class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2 mb-3">
                {decr_item(
                  group.description,
                  @current_user,
                  get_user_group(group, @current_user).key,
                  @key,
                  group
                )}
              </p>

              <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500 dark:text-slate-400">
                <div class="flex items-center gap-1.5">
                  <.phx_icon name="hero-user" class="w-3.5 h-3.5" />
                  <% uconn =
                    get_current_user_connection_between_users!(group.user_id, @current_user.id) %>
                  <span class="font-medium text-emerald-700 dark:text-emerald-300">
                    {decr_uconn(
                      uconn.connection.username,
                      @current_user,
                      uconn.key,
                      @key
                    )}
                  </span>
                  <span class="text-slate-500 dark:text-slate-400">invited you</span>
                </div>
                <span class="text-slate-300 dark:text-slate-600">•</span>
                <time datetime={group.inserted_at}>
                  <.local_time_ago id={"time-created-#{group.id}"} at={group.inserted_at} />
                </time>
              </div>
            </div>

            <div class="flex flex-col sm:items-end gap-3">
              <div
                id={group.id <> "-member-avatars"}
                class="flex -space-x-2"
                data-tippy-content="Group members"
                phx-hook="TippyHook"
              >
                <%= for user_group <- Enum.take(Enum.filter(group.user_groups, & &1.confirmed_at), 5) do %>
                  <% uconn =
                    get_uconn_for_users(
                      get_user_from_user_group_id(user_group.id),
                      @current_user
                    ) %>

                  <.phx_avatar
                    :if={user_group.user_id != @current_user.id && uconn}
                    src={get_user_avatar(uconn, @key)}
                    alt="group member"
                    class="h-8 w-8 rounded-full ring-2 ring-white dark:ring-slate-800 bg-slate-100 dark:bg-slate-700"
                  />

                  <.phx_avatar
                    :if={user_group.user_id != @current_user.id && !uconn}
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
              </div>

              <div class="flex items-center gap-2">
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
              </div>
            </div>
          </div>
        </div>

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
