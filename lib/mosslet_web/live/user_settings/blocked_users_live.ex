defmodule MossletWeb.BlockedUsersLive do
  @moduledoc """
  Manage blocked users with a calm, expandable interface.
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       blocked_users:
         list_blocked_users_with_details(
           socket.assigns.current_scope.user,
           socket.assigns.current_scope.key
         ),
       show_blocked_users: false
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(socket,
       page_title: "Settings",
       blocked_users:
         list_blocked_users_with_details(
           socket.assigns.current_scope.user,
           socket.assigns.current_scope.key
         ),
       show_blocked_users: false
     )}
  end

  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:blocked_users}
      sidebar_current_page={:blocked_users}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-8">
        <%!-- Page header with rose/pink styling --%>
        <div class="mb-8">
          <div class="mb-6">
            <h1 class="text-2xl font-bold tracking-tight sm:text-3xl bg-gradient-to-r from-rose-500 to-pink-600 bg-clip-text text-transparent">
              Blocked Users
            </h1>
            <p class="mt-2 text-base text-slate-600 dark:text-slate-400">
              Manage users you've blocked for a more peaceful experience.
            </p>
          </div>
          <%!-- Decorative accent line in rose colors --%>
          <div class="h-1 w-20 rounded-full bg-gradient-to-r from-rose-400 via-pink-500 to-rose-400 shadow-sm shadow-rose-500/30">
          </div>
        </div>

        <div class="space-y-6 max-w-3xl">
          <%!-- Summary Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-rose-50/50 to-pink-50/30 dark:from-rose-900/20 dark:to-pink-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-rose-100 via-pink-50 to-rose-100 dark:from-rose-900/30 dark:via-pink-900/25 dark:to-rose-900/30">
                  <.phx_icon
                    name="hero-user-minus"
                    class="h-4 w-4 text-rose-600 dark:text-rose-400"
                  />
                </div>
                <span class="text-rose-800 dark:text-rose-200">Blocked Users</span>
              </div>
            </:title>

            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <p class="text-rose-700 dark:text-rose-300 leading-relaxed">
                  You currently have <strong>{length(@blocked_users)}</strong>
                  {if length(@blocked_users) == 1, do: "user", else: "users"} blocked.
                </p>

                <DesignSystem.liquid_button
                  variant="primary"
                  color="rose"
                  icon={if @show_blocked_users, do: "hero-eye-slash", else: "hero-eye"}
                  phx-click="toggle_blocked_users"
                  class="text-sm"
                  disabled={@blocked_users == []}
                >
                  {if @show_blocked_users && @blocked_users != [], do: "Hide", else: "Show"}
                  {if @blocked_users != [], do: "(#{length(@blocked_users)})"}
                </DesignSystem.liquid_button>
              </div>

              <%= if @blocked_users != [] do %>
                <div class="bg-rose-100 dark:bg-rose-900/30 rounded-lg p-4 border border-rose-200 dark:border-rose-700">
                  <div class="flex items-start gap-3">
                    <.phx_icon
                      name="hero-information-circle"
                      class="h-5 w-5 mt-0.5 text-rose-600 dark:text-rose-400 flex-shrink-0"
                    />
                    <div class="space-y-2">
                      <span class="font-medium text-sm text-rose-800 dark:text-rose-200">
                        About Blocking
                      </span>
                      <p class="text-sm text-rose-700 dark:text-rose-300">
                        MOSSLET offers three levels of blocking: <strong>Everything</strong>
                        (full block), <strong>Posts only</strong>
                        (hide posts but allow replies), or <strong>Replies only</strong>
                        (block replies but see posts).
                        You can unblock or modify these settings anytime.
                      </p>
                    </div>
                  </div>
                </div>
              <% else %>
                <div class="bg-emerald-50 dark:bg-emerald-900/20 rounded-lg p-4 border border-emerald-200 dark:border-emerald-700">
                  <div class="flex items-start gap-3">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-5 w-5 mt-0.5 text-emerald-600 dark:text-emerald-400 flex-shrink-0"
                    />
                    <div class="space-y-2">
                      <h3 class="font-medium text-sm text-emerald-800 dark:text-emerald-200">
                        Clean Slate
                      </h3>
                      <p class="text-sm text-emerald-700 dark:text-emerald-300">
                        You haven't blocked anyone yet. Blocking is a tool to help maintain a peaceful experience
                        when you need space from certain authors and don't want to remove the connection.
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Expandable Blocked Users List --%>
          <%= if @show_blocked_users && @blocked_users != [] do %>
            <DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center justify-between w-full">
                  <div class="flex items-center gap-3">
                    <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-rose-100 via-pink-50 to-rose-100 dark:from-rose-900/30 dark:via-pink-900/25 dark:to-rose-900/30">
                      <.phx_icon
                        name="hero-users"
                        class="h-4 w-4 text-rose-600 dark:text-rose-400"
                      />
                    </div>
                    <span class="text-rose-800 dark:text-rose-200">
                      Blocked Users ({length(@blocked_users)})
                    </span>
                  </div>
                  <DesignSystem.liquid_button
                    variant="ghost"
                    icon="hero-eye-slash"
                    phx-click="toggle_blocked_users"
                    class="text-sm"
                    color="rose"
                  >
                    Hide
                  </DesignSystem.liquid_button>
                </div>
              </:title>

              <div class="space-y-1">
                <.blocked_user_item
                  :for={blocked_user <- @blocked_users}
                  blocked_user={blocked_user}
                  current_scope={@current_scope}
                />
              </div>
            </DesignSystem.liquid_card>
          <% end %>

          <%!-- How Blocking Works Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">
                  Three Levels of Blocking
                </span>
              </div>
            </:title>

            <div class="space-y-6">
              <p class="text-blue-700 dark:text-blue-300 leading-relaxed">
                MOSSLET offers flexible blocking options to help you curate your experience:
              </p>

              <%!-- Block Type Explanations --%>
              <div class="space-y-4">
                <%!-- Full Block --%>
                <div class="p-4 rounded-xl border border-blue-200 dark:border-blue-700 bg-blue-50/50 dark:bg-blue-900/20">
                  <div class="flex items-start gap-3">
                    <div class="p-2 rounded-lg bg-blue-100 dark:bg-blue-800/50">
                      <.phx_icon
                        name="hero-no-symbol"
                        class="h-4 w-4 text-blue-600 dark:text-blue-400"
                      />
                    </div>
                    <div class="flex-1">
                      <h3 class="font-semibold text-blue-900 dark:text-blue-100">
                        Everything (Full Block)
                      </h3>
                      <p class="text-sm text-blue-700 dark:text-blue-300 mt-1">
                        Complete separation - you won't see any of their content, and they can't interact with you in any way.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Posts Only --%>
                <div class="p-4 rounded-xl border border-blue-200 dark:border-blue-700 bg-blue-50/30 dark:bg-blue-900/15">
                  <div class="flex items-start gap-3">
                    <div class="p-2 rounded-lg bg-blue-100 dark:bg-blue-800/50">
                      <.phx_icon
                        name="hero-document-text"
                        class="h-4 w-4 text-blue-600 dark:text-blue-400"
                      />
                    </div>
                    <div class="flex-1">
                      <h3 class="font-semibold text-blue-900 dark:text-blue-100">Posts Only</h3>
                      <p class="text-sm text-blue-700 dark:text-blue-300 mt-1">
                        Hide their posts from your timeline, but they can still reply to your content if they find it.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Replies Only --%>
                <div class="p-4 rounded-xl border border-blue-200 dark:border-blue-700 bg-blue-50/30 dark:bg-blue-900/15">
                  <div class="flex items-start gap-3">
                    <div class="p-2 rounded-lg bg-blue-100 dark:bg-blue-800/50">
                      <.phx_icon
                        name="hero-chat-bubble-left"
                        class="h-4 w-4 text-blue-600 dark:text-blue-400"
                      />
                    </div>
                    <div class="flex-1">
                      <h3 class="font-semibold text-blue-900 dark:text-blue-100">Replies Only</h3>
                      <p class="text-sm text-blue-700 dark:text-blue-300 mt-1">
                        You can still see their posts, but they cannot reply to your content or engage in conversations.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- What's always true --%>
              <div class="pt-4 border-t border-blue-200 dark:border-blue-700">
                <h4 class="font-medium text-blue-800 dark:text-blue-200 mb-2">All blocking types:</h4>
                <ul class="space-y-1 text-sm text-blue-700 dark:text-blue-300">
                  <li class="flex items-start gap-2">
                    <.phx_icon name="hero-eye-slash" class="h-4 w-4 mt-0.5 flex-shrink-0" />
                    Are completely private - blocked users are never notified
                  </li>
                  <li class="flex items-start gap-2">
                    <.phx_icon name="hero-arrow-path" class="h-4 w-4 mt-0.5 flex-shrink-0" />
                    Can be changed or removed anytime from your settings
                  </li>
                  <li class="flex items-start gap-2">
                    <.phx_icon name="hero-shield-check" class="h-4 w-4 mt-0.5 flex-shrink-0" />
                    Help you maintain control over your social experience
                  </li>
                </ul>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  # Component for individual blocked user items
  defp blocked_user_item(assigns) do
    ~H"""
    <div class="group relative overflow-hidden rounded-xl p-4 -m-2 transition-all duration-200 ease-out hover:bg-slate-50 dark:hover:bg-slate-800/50">
      <div class="relative flex items-center justify-between">
        <div class="flex items-center gap-4">
          <%!-- User Avatar --%>
          <div class="relative">
            <%= if show_avatar?(@blocked_user.blocked) do %>
              <img
                src={
                  maybe_get_avatar_src(
                    @blocked_user.blocked,
                    @current_scope.user,
                    @current_scope.key,
                    ""
                  )
                }
                alt="Avatar"
                class="h-10 w-10 rounded-full object-cover ring-2 ring-slate-200 dark:ring-slate-700"
              />
            <% else %>
              <div class="h-10 w-10 rounded-full bg-gradient-to-br from-slate-200 to-slate-300 dark:from-slate-700 dark:to-slate-600 flex items-center justify-center">
                <.phx_icon
                  name="hero-user"
                  class="h-5 w-5 text-slate-500 dark:text-slate-400"
                />
              </div>
            <% end %>
            <%!-- Blocked indicator with block type --%>
            <div class="absolute -bottom-1 -right-1 h-4 w-4 rounded-full bg-rose-500 border-2 border-white dark:border-slate-800 flex items-center justify-center">
              <.phx_icon
                name="hero-no-symbol"
                class="h-2.5 w-2.5 text-white"
              />
            </div>
          </div>

          <%!-- User Info --%>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                <%= if @blocked_user.user_connection do %>
                  {decr_uconn(
                    @blocked_user.user_connection.connection.name,
                    @current_scope.user,
                    @blocked_user.user_connection.key,
                    @current_scope.key
                  )}
                <% else %>
                  [No connection found]
                <% end %>
              </p>
              <%= if @blocked_user.user_connection do %>
                <span class="text-xs font-mono text-slate-600 dark:text-slate-300 bg-slate-100 dark:bg-slate-700 px-2 py-0.5 rounded-md truncate">
                  @{decr_uconn(
                    @blocked_user.user_connection.connection.username,
                    @current_scope.user,
                    @blocked_user.user_connection.key,
                    @current_scope.key
                  )}
                </span>
              <% end %>
            </div>
            <p class="text-sm text-slate-500 dark:text-slate-400 truncate">
              {format_block_type(@blocked_user.block_type)} · Blocked {format_date(
                @blocked_user.inserted_at
              )}
            </p>
            <%= if @blocked_user.reason && String.trim(@blocked_user.reason) != "" do %>
              <p class="text-xs text-slate-500 dark:text-slate-400 truncate mt-1">
                {String.slice(@blocked_user.reason, 0, 50)}{if String.length(@blocked_user.reason) >
                                                                 50,
                                                               do: "..."}
              </p>
            <% end %>

            <%!-- Block type badge --%>
            <div class="mt-2">
              <span class={[
                "inline-flex items-center px-2 py-1 rounded-md text-xs font-medium",
                block_type_classes(@blocked_user.block_type)
              ]}>
                {format_block_type(@blocked_user.block_type)}
              </span>
            </div>
          </div>
        </div>

        <%!-- Unblock Button --%>
        <DesignSystem.liquid_button
          variant="secondary"
          color="emerald"
          icon="hero-user-plus"
          size="sm"
          phx-click="unblock_user"
          phx-value-user-id={@blocked_user.blocked.id}
          data-confirm="Are you sure you want to unblock this user? They will be able to see your content and interact with you again."
        >
          Unblock
        </DesignSystem.liquid_button>
      </div>
    </div>
    """
  end

  def handle_event("toggle_blocked_users", _params, socket) do
    {:noreply, assign(socket, show_blocked_users: !socket.assigns.show_blocked_users)}
  end

  def handle_event("unblock_user", %{"user-id" => blocked_user_id}, socket) do
    current_user = socket.assigns.current_scope.user

    blocked_user = Accounts.get_user!(blocked_user_id)

    case Accounts.unblock_user(current_user, blocked_user) do
      {:ok, _deleted_block} ->
        # Refresh the blocked users list
        blocked_users =
          list_blocked_users_with_details(current_user, socket.assigns.current_scope.key)

        {:noreply,
         socket
         |> assign(blocked_users: blocked_users)
         |> put_flash(:success, "User has been unblocked successfully.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to unblock user. Please try again.")}
    end
  end

  # Helper function to get blocked users with decrypted details
  defp list_blocked_users_with_details(current_user, key) do
    current_user
    |> Accounts.list_blocked_users()
    |> Enum.map(fn user_block ->
      # Get the user connection between current user and blocked user
      user_connection =
        Accounts.get_user_connection_between_users(
          user_block.blocked.id,
          current_user.id
        )

      # Decrypt the reason if it exists
      decrypted_reason =
        if user_block.reason do
          Mosslet.Encrypted.Users.Utils.decrypt_user_data(
            user_block.reason,
            current_user,
            key
          )
        else
          nil
        end

      # Add the user_connection to the user_block for decryption purposes
      user_block
      |> Map.put(:reason, decrypted_reason)
      |> Map.put(:user_connection, user_connection)
    end)
  end

  # Helper function to format dates nicely
  defp format_date(datetime) do
    # Convert NaiveDateTime to DateTime if needed
    datetime_utc =
      case datetime do
        %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
        %DateTime{} -> datetime
        _ -> DateTime.utc_now()
      end

    case DateTime.diff(DateTime.utc_now(), datetime_utc, :day) do
      0 -> "today"
      1 -> "yesterday"
      days when days < 7 -> "#{days} days ago"
      days when days < 30 -> "#{div(days, 7)} weeks ago"
      days when days < 365 -> "#{div(days, 30)} months ago"
      days -> "#{div(days, 365)} years ago"
    end
  end

  # Helper function to format block type
  defp format_block_type(:full), do: "Everything blocked"
  defp format_block_type(:posts_only), do: "Posts blocked"
  defp format_block_type(:replies_only), do: "Replies blocked"
  defp format_block_type(_), do: "Blocked"

  # Helper function to get block type badge classes
  defp block_type_classes(:full) do
    "bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-300"
  end

  defp block_type_classes(:posts_only) do
    "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300"
  end

  defp block_type_classes(:replies_only) do
    "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300"
  end

  defp block_type_classes(_) do
    "bg-slate-100 text-slate-800 dark:bg-slate-900/30 dark:text-slate-300"
  end
end
