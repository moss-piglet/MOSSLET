defmodule MossletWeb.GroupLive.PendingComponent do
  use MossletWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.page_header :if={@action == :greet} title={@title} />
      <.p>
        View your Group invitations below and accept or decline.
      </.p>

      <ul role="list" class="divide-y divide-gray-100" id="groups-greeter" phx-update="stream">
        <li
          :for={{id, group} <- @stream}
          id={id}
          class="flex flex-wrap items-center justify-between gap-x-6 gap-y-4 py-5 sm:flex-nowrap"
        >
          <div>
            <p class="text-sm leading-6 text-gray-900 dark:text-gray-400">
              {decr_item(
                group.description,
                @current_user,
                get_user_group(group, @current_user).key,
                @key,
                group
              )}
            </p>
            <div class="mt-1 inline-flex gap-x-2 text-xs leading-5 text-gray-500 dark:text-gray-400">
              <div :if={group.require_password?}>
                <span
                  :if={group.require_password?}
                  id={group.id <> "-password-symbol"}
                  class="text-red-500 dark:text-red-400 cursor-help"
                  data-tippy-content="This Group requires a password to join."
                  phx-hook="TippyHook"
                >
                  <.icon :if={group.require_password?} name="hero-lock-closed" class="h-4 w-4" />
                </span>
              </div>
              <div class="inline-flex items-center align-middle text-sm font-semibold leading-6 text-gray-900 dark:text-gray-100">
                {decr_item(
                  group.name,
                  @current_user,
                  get_user_group(group, @current_user).key,
                  @key,
                  group
                )}
              </div>
              <div class="inline-flex items-center align-middle">
                <svg viewBox="0 0 2 2" class="h-0.5 w-0.5 fill-current">
                  <circle cx="1" cy="1" r="1" />
                </svg>
              </div>
              <div
                id={"group-owner-username-#{group.id}"}
                phx-hook="TippyHook"
                data-tippy-content="This is the creator of the Group."
                class={"inline-flex items-center align-middle cursor-help #{role_badge_color_ring(:owner)}"}
              >
                <% uconn = get_current_user_connection_between_users!(group.user_id, @current_user.id) %>
                {decr_uconn(
                  uconn.connection.username,
                  @current_user,
                  uconn.key,
                  @key
                )}
              </div>
              <div class="inline-flex items-center align-middle">
                <svg viewBox="0 0 2 2" class="h-0.5 w-0.5 fill-current">
                  <circle cx="1" cy="1" r="1" />
                </svg>
              </div>
              <div class="inline-flex items-center align-middle">
                <time datetime="2023-01-23T22:34Z">
                  <.local_time_ago id={"time-created-#{group.id}"} at={group.inserted_at} />
                </time>
              </div>
            </div>
          </div>
          <dl class="flex w-full flex-none justify-between gap-x-8 sm:w-auto">
            <div
              id={group.id <> "-member-avatar-group"}
              class="flex -space-x-0.5 items-center align-middle cursor-help"
              data-tippy-content="Group members"
              phx-hook="TippyHook"
            >
              <dt class="sr-only">Members</dt>
              <%= for user_group <- group.user_groups, user_group.confirmed_at do %>
                <% uconn =
                  get_uconn_for_users(
                    get_user_from_user_group_id(user_group.id),
                    @current_user
                  ) %>

                <dd>
                  <.phx_avatar
                    :if={user_group.user_id != @current_user.id && uconn}
                    src={
                      get_user_avatar(
                        uconn,
                        @key
                      )
                    }
                    alt="group member connection avatar"
                    class="h-6 w-6 rounded-full bg-gray-50 ring-2 ring-white"
                  />

                  <.phx_avatar
                    :if={user_group.user_id != @current_user.id && !uconn}
                    src={
                      ~p"/images/groups/#{decr_item(user_group.avatar_img, @current_user, get_user_group(group, @current_user).key, @key, group)}"
                    }
                    alt="unknown group member avatar"
                    class="h-6 w-6 rounded-full bg-gray-50 ring-2 ring-white"
                  />

                  <.phx_avatar
                    :if={user_group.user_id == @current_user.id}
                    src={maybe_get_user_avatar(@current_user, @key)}
                    alt="your group avatar"
                    class="h-6 w-6 rounded-full bg-gray-50 ring-2 ring-white"
                  />
                </dd>
              <% end %>
            </div>
            <div class="flex flex-wrap w-16 gap-x-2.5">
              <.link
                :if={group.require_password?}
                class="text-emerald-600 hover:text-emerald-500 active:text-emerald-700"
                phx-click={JS.patch(~p"/app/groups/#{group}/join")}
              >
                Join
              </.link>
              <.link
                :if={!group.require_password?}
                class="text-emerald-600 hover:text-emerald-500 active:text-emerald-700"
                phx-target={@myself}
                phx-click={JS.patch(~p"/app/groups/#{group}/join")}
              >
                Join
              </.link>

              <.link
                :if={can_delete_user_group?(get_user_group(group, @current_user), @current_user)}
                phx-click={
                  JS.push("delete-user-group", value: %{id: get_user_group(group, @current_user).id})
                  |> hide("##{id}")
                }
                data-confirm="Are you sure you want to delete this group invitation?"
                class="hover:text-rose-500 active:text-rose-700"
              >
                Decline
              </.link>
            </div>
          </dl>
        </li>
      </ul>
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
