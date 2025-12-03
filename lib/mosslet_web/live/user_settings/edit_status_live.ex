defmodule MossletWeb.EditStatusLive do
  @moduledoc """
  LiveView for managing user status and presence settings.
  Privacy-first approach with granular controls.
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Statuses
  alias MossletWeb.DesignSystem
  import MossletWeb.DesignSystem

  # Import connection helper functions
  import MossletWeb.DesignSystem,
    only: [
      get_decrypted_connection_label: 3,
      get_decrypted_connection_username: 3,
      get_connection_avatar_src: 3,
      get_decrypted_group_name: 3,
      get_decrypted_group_description: 3
    ]

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    # Create forms for status and status visibility
    initial_status_attrs = %{
      "status" => to_string(user.status || :offline),
      "status_message" => get_decrypted_status_message(user, key) || "",
      "auto_status" => user.auto_status || false
    }

    status_changeset =
      Accounts.change_user_status(user, initial_status_attrs, user: user, key: key)

    status_form = to_form(status_changeset)

    # Load saved status visibility selections from connection record
    {saved_groups, saved_users} =
      get_saved_status_visibility_selections(user, key)

    status_visibility_form =
      to_form(%{
        "status_visibility" => Atom.to_string(user.status_visibility || :nobody),
        "show_online_presence" => user.show_online_presence,
        "status_visible_to_groups" => saved_groups,
        "status_visible_to_users" => saved_users,
        # simply match
        "presence_visible_to_groups" => saved_groups,
        # simply match
        "presence_visible_to_users" => saved_users
      })

    # Get visibility groups and connections using existing functions
    visibility_groups = Mosslet.Accounts.get_user_visibility_groups_with_connections(user)
    user_connections = Mosslet.Accounts.filter_user_connections(%{}, user)

    # Subscribe to user's own status updates to refresh the sidebar avatar
    if connected?(socket) do
      Accounts.subscribe_user_status(user)
    end

    {:ok,
     assign(socket,
       page_title: "Settings",
       status_form: status_form,
       status_visibility_form: status_visibility_form,
       user_visibility_groups: visibility_groups,
       user_connections: user_connections,
       status_message: get_decrypted_status_message(user, key) || "",
       auto_status: user.auto_status || false,
       show_auto_status_explanation: false
     )}
  end

  def render(assigns) do
    ~H"""
    <.layout current_user={@current_user} current_page={:edit_status} key={@key} type="sidebar">
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Status & Presence
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Control how and when others can see your activity status on MOSSLET.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-2xl">
          <%!-- Current Status Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/30 dark:via-emerald-900/25 dark:to-teal-900/30">
                  <.phx_icon name="hero-face-smile" class="h-4 w-4 text-teal-600 dark:text-teal-400" />
                </div>
                <span>Your Status</span>
                <%!-- Current status indicator --%>
                <DesignSystem.liquid_timeline_status
                  status={to_string(@status_form[:status].value || :offline)}
                  message={if @status_message != "", do: @status_message, else: nil}
                  class="ml-auto"
                />
              </div>
            </:title>

            <.form
              for={@status_form}
              phx-change="validate_status"
              phx-submit="update_status"
              class="space-y-6"
            >
              <%!-- Hidden status field to ensure status gets submitted --%>
              <.phx_input field={@status_form[:status]} type="hidden" />

              <%!-- Status Selector --%>
              <DesignSystem.liquid_status_selector
                current_status={to_string(@status_form[:status].value || :offline)}
                phx_click="set_status"
              />

              <%!-- Status Message Input --%>
              <div :if={to_string(@status_form[:status].value) != "offline"} class="space-y-3">
                <.phx_input
                  field={@status_form[:status_message]}
                  type="text"
                  label="Status message (optional)"
                  placeholder="What are you up to?"
                  maxlength="160"
                  phx-debounce="200"
                  value={@status_message || ""}
                  help="Share what you're doing with people who can see your status"
                />
              </div>

              <%!-- Auto Status Toggle with Collapsible Beautiful Explanation --%>
              <div class="space-y-4">
                <.phx_input
                  field={@status_form[:auto_status]}
                  type="checkbox"
                  phx-debounce="200"
                  label="Automatically update status based on activity"
                  help="Let MOSSLET intelligently update your status when you're active, away, or offline"
                />

                <%!-- Expandable explanation trigger (only show when auto_status is enabled) --%>
                <div :if={@status_form[:auto_status].value} class="">
                  <button
                    type="button"
                    phx-click="toggle_auto_status_explanation"
                    class="group inline-flex items-center gap-2 text-sm font-medium text-emerald-700 dark:text-emerald-300 hover:text-emerald-800 dark:hover:text-emerald-200 transition-colors duration-200"
                  >
                    <.phx_icon name="hero-sparkles" class="h-4 w-4" />
                    <span>How does auto-status work?</span>
                    <.phx_icon
                      name={
                        if @show_auto_status_explanation,
                          do: "hero-chevron-up",
                          else: "hero-chevron-down"
                      }
                      class="h-4 w-4 transition-transform duration-200 group-hover:scale-110"
                    />
                  </button>
                </div>

                <%!-- Beautiful Auto-Status Explanation Card (Collapsible) --%>
                <div
                  :if={@status_form[:auto_status].value && @show_auto_status_explanation}
                  class="animate-in slide-in-from-top-2 duration-300 ease-out relative overflow-hidden rounded-2xl bg-gradient-to-br from-emerald-50/80 via-teal-50/60 to-cyan-50/40 dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-cyan-900/10 border border-emerald-200/60 dark:border-emerald-700/30 backdrop-blur-sm"
                >
                  <%!-- Subtle animated background --%>
                  <div class="absolute inset-0 bg-gradient-to-r from-emerald-400/5 via-transparent to-teal-400/5 animate-pulse">
                  </div>

                  <div class="relative p-6 space-y-5">
                    <%!-- Header with close button --%>
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <div class="relative flex h-8 w-8 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-emerald-500/20 via-teal-500/15 to-emerald-500/20 dark:from-emerald-400/30 dark:via-teal-400/25 dark:to-emerald-400/30">
                          <.phx_icon
                            name="hero-sparkles"
                            class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                          />
                        </div>
                        <h4 class="text-lg font-semibold bg-gradient-to-r from-emerald-700 via-teal-600 to-emerald-700 dark:from-emerald-300 dark:via-teal-300 dark:to-emerald-300 bg-clip-text text-transparent">
                          How Auto-Status Works
                        </h4>
                      </div>
                      <button
                        type="button"
                        phx-click="toggle_auto_status_explanation"
                        class="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-white/50 dark:hover:bg-slate-800/50 transition-all duration-200"
                        title="Close explanation"
                      >
                        <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                      </button>
                    </div>

                    <%!-- Status flow visualization --%>
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                      <%!-- Active Status --%>
                      <div class="group relative p-4 rounded-xl bg-white/60 dark:bg-slate-800/60 backdrop-blur border border-white/40 dark:border-slate-700/40 hover:bg-white/80 dark:hover:bg-slate-800/80 transition-all duration-300">
                        <div class="flex flex-col items-center gap-3 text-center">
                          <div class="relative">
                            <div class="h-3 w-3 rounded-full bg-gradient-to-br from-blue-400 to-cyan-500 animate-pulse">
                            </div>
                            <div class="absolute inset-0 h-3 w-3 rounded-full bg-blue-400/30 animate-ping">
                            </div>
                          </div>
                          <div>
                            <p class="text-sm font-medium text-blue-700 dark:text-blue-300">Active</p>
                            <p class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                              Recently interacting
                            </p>
                            <p class="text-xs text-slate-500 dark:text-slate-500 mt-0.5">
                              &lt; 2 minutes
                            </p>
                          </div>
                        </div>
                      </div>

                      <%!-- Calm Status --%>
                      <div class="group relative p-4 rounded-xl bg-white/60 dark:bg-slate-800/60 backdrop-blur border border-white/40 dark:border-slate-700/40 hover:bg-white/80 dark:hover:bg-slate-800/80 transition-all duration-300">
                        <div class="flex flex-col items-center gap-3 text-center">
                          <div class="h-3 w-3 rounded-full bg-gradient-to-br from-green-400 to-emerald-500">
                          </div>
                          <div>
                            <p class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
                              Calm
                            </p>
                            <p class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                              Quietly browsing
                            </p>
                            <p class="text-xs text-slate-500 dark:text-slate-500 mt-0.5">
                              2-10 minutes
                            </p>
                          </div>
                        </div>
                      </div>

                      <%!-- Away Status --%>
                      <div class="group relative p-4 rounded-xl bg-white/60 dark:bg-slate-800/60 backdrop-blur border border-white/40 dark:border-slate-700/40 hover:bg-white/80 dark:hover:bg-slate-800/80 transition-all duration-300">
                        <div class="flex flex-col items-center gap-3 text-center">
                          <div class="h-3 w-3 rounded-full bg-gradient-to-br from-amber-400 to-orange-500">
                          </div>
                          <div>
                            <p class="text-sm font-medium text-amber-700 dark:text-amber-300">Away</p>
                            <p class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                              Connected but idle
                            </p>
                            <p class="text-xs text-slate-500 dark:text-slate-500 mt-0.5">
                              10+ minutes
                            </p>
                          </div>
                        </div>
                      </div>

                      <%!-- Offline Status --%>
                      <div class="group relative p-4 rounded-xl bg-white/60 dark:bg-slate-800/60 backdrop-blur border border-white/40 dark:border-slate-700/40 hover:bg-white/80 dark:hover:bg-slate-800/80 transition-all duration-300">
                        <div class="flex flex-col items-center gap-3 text-center">
                          <div class="h-3 w-3 rounded-full bg-gradient-to-br from-slate-400 to-slate-500">
                          </div>
                          <div>
                            <p class="text-sm font-medium text-slate-700 dark:text-slate-300">
                              Offline
                            </p>
                            <p class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                              Not connected
                            </p>
                            <p class="text-xs text-slate-500 dark:text-slate-500 mt-0.5">
                              Disconnected
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>

                    <%!-- Key features --%>
                    <div class="space-y-4">
                      <div class="flex items-start gap-3">
                        <div class="mt-1 h-2 w-2 rounded-full bg-gradient-to-br from-emerald-400 to-teal-500 flex-shrink-0">
                        </div>
                        <div>
                          <p class="text-sm font-medium text-emerald-800 dark:text-emerald-200">
                            Intelligent Detection
                          </p>
                          <p class="text-xs text-slate-600 dark:text-slate-400 leading-relaxed mt-1">
                            Uses your connection status and recent activity like posting, liking, and commenting to determine your engagement level
                          </p>
                        </div>
                      </div>

                      <div class="flex items-start gap-3">
                        <div class="mt-1 h-2 w-2 rounded-full bg-gradient-to-br from-red-400 to-rose-500 flex-shrink-0">
                        </div>
                        <div>
                          <p class="text-sm font-medium text-red-800 dark:text-red-200">
                            Respects Busy Status
                          </p>
                          <p class="text-xs text-slate-600 dark:text-slate-400 leading-relaxed mt-1">
                            Never automatically changes your status when you've manually set it to "Busy" - your intentional status always takes priority
                          </p>
                        </div>
                      </div>

                      <div class="flex items-start gap-3">
                        <div class="mt-1 h-2 w-2 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 flex-shrink-0">
                        </div>
                        <div>
                          <p class="text-sm font-medium text-amber-800 dark:text-amber-200">
                            Preserves Your Message
                          </p>
                          <p class="text-xs text-slate-600 dark:text-slate-400 leading-relaxed mt-1">
                            Your custom status message is always preserved - only the status indicator changes automatically
                          </p>
                        </div>
                      </div>
                    </div>

                    <%!-- Privacy note --%>
                    <div class="flex items-center gap-3 p-3 rounded-xl bg-white/50 dark:bg-slate-800/50 border border-emerald-200/40 dark:border-emerald-700/40">
                      <.phx_icon
                        name="hero-shield-check"
                        class="h-4 w-4 text-emerald-600 dark:text-emerald-400 flex-shrink-0"
                      />
                      <p class="text-xs text-emerald-700 dark:text-emerald-300 leading-relaxed">
                        <span class="font-medium">Privacy-friendly:</span>
                        Auto-status only works when you're actively using MOSSLET and respects all your visibility settings.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Action button --%>
              <div class="flex justify-end pt-4">
                <DesignSystem.liquid_button
                  type="submit"
                  phx-disable-with="Updating..."
                  icon="hero-check"
                  color="teal"
                >
                  Update Status
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <%!-- Status Visibility Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
                  <.phx_icon name="hero-eye" class="h-4 w-4 text-purple-600 dark:text-purple-400" />
                </div>
                <span>Status Visibility</span>
                <%!-- Current visibility badge --%>
                <DesignSystem.liquid_badge
                  variant="soft"
                  color={visibility_badge_color(@status_visibility_form[:status_visibility].value)}
                  size="sm"
                >
                  {String.capitalize(
                    ensure_string(
                      @status_visibility_form[:status_visibility].value ||
                        @status_visibility_form[:status_visibility] || "nobody"
                    )
                  )}
                </DesignSystem.liquid_badge>
              </div>
            </:title>

            <.form
              for={@status_visibility_form}
              phx-change="validate_status_visibility"
              phx-submit="update_status_visibility"
              class="space-y-6"
            >
              <%!-- Current visibility status --%>
              <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700">
                <div class="flex items-center gap-3 mb-3">
                  <.phx_icon name="hero-information-circle" class="h-5 w-5 text-slate-500" />
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                    Current Setting
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  {status_visibility_help_text(
                    @status_visibility_form[:status_visibility].value,
                    @current_user.visibility
                  )}
                </p>
              </div>

              <%!-- Status Visibility Selector --%>
              <div class="space-y-3">
                <.phx_input
                  field={@status_visibility_form[:status_visibility]}
                  type="select"
                  label="Who can see your status"
                  options={get_status_visibility_options(@current_user.visibility)}
                  help="Choose who can see your status message and activity"
                />
              </div>

              <%!-- Group selector (if specific_groups selected) --%>
              <div
                :if={
                  status_visibility_matches?(
                    @status_visibility_form[:status_visibility].value,
                    :specific_groups
                  )
                }
                class="space-y-3"
              >
                <label class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  Choose which groups can see your status:
                </label>
                <div class="space-y-2 max-h-48 overflow-y-auto border border-slate-200 dark:border-slate-700 rounded-xl p-4 bg-slate-50 dark:bg-slate-800/50">
                  <div
                    :if={Enum.empty?(@user_visibility_groups)}
                    class="text-center py-4 text-slate-500 dark:text-slate-400"
                  >
                    <p class="text-sm">No visibility groups created yet.</p>
                    <p class="text-xs mt-1">
                      <.link
                        navigate={~p"/app/users/connections"}
                        class="text-teal-700 hover:text-teal-800 dark:text-teal-300 dark:hover:text-teal-200 underline"
                      >
                        Create visibility groups
                      </.link>
                      to organize your connections.
                    </p>
                  </div>

                  <label
                    :for={group_data <- @user_visibility_groups}
                    class="flex items-center space-x-3 p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 cursor-pointer"
                  >
                    <input
                      type="checkbox"
                      name="status_visible_to_groups[]"
                      value={group_data.group.id}
                      checked={
                        group_data.group.id in (@status_visibility_form[:status_visible_to_groups].value ||
                                                  [])
                      }
                      class="rounded border-slate-300 text-teal-600 focus:ring-teal-500 dark:border-slate-600 dark:bg-slate-700 h-4 w-4"
                    />
                    <div class={["w-3 h-3 rounded-full bg-#{group_data.group.color}-500"]}></div>
                    <div class="flex-1">
                      <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                        {get_decrypted_group_name(group_data, @current_user, @key)}
                      </p>
                      <p
                        :if={group_data.group.description}
                        class="text-xs text-slate-500 dark:text-slate-400"
                      >
                        {get_decrypted_group_description(group_data, @current_user, @key)}
                      </p>
                    </div>
                  </label>
                </div>
              </div>

              <%!-- User selector (if specific_users selected) --%>
              <div
                :if={
                  status_visibility_matches?(
                    @status_visibility_form[:status_visibility].value,
                    :specific_users
                  )
                }
                class="space-y-3"
              >
                <label class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  Choose which users can see your status:
                </label>
                <div class="space-y-2 max-h-48 overflow-y-auto border border-slate-200 dark:border-slate-700 rounded-xl p-4 bg-slate-50 dark:bg-slate-800/50">
                  <div
                    :if={Enum.empty?(@user_connections)}
                    class="text-center py-4 text-slate-500 dark:text-slate-400"
                  >
                    <p class="text-sm">No connections found.</p>
                    <p class="text-xs mt-1">
                      <.link
                        navigate={~p"/app/users/connections"}
                        class="text-teal-700 hover:text-teal-800 dark:text-teal-300 dark:hover:text-teal-200 underline"
                      >
                        Connect with people
                      </.link>
                      to share your status with specific users.
                    </p>
                  </div>

                  <label
                    :for={connection <- @user_connections}
                    class={[
                      "flex items-start gap-3 p-3 rounded-lg border transition-all duration-200 cursor-pointer",
                      "bg-white/95 dark:bg-slate-800/95 border-slate-200/40 dark:border-slate-700/40",
                      "hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-amber-300/60 dark:hover:border-amber-600/60",
                      "hover:shadow-amber-500/10"
                    ]}
                  >
                    <input
                      type="checkbox"
                      name="status_visible_to_users[]"
                      value={connection.connection.user_id}
                      checked={
                        connection.connection.user_id in (@status_visibility_form[
                                                            :status_visible_to_users
                                                          ].value || [])
                      }
                      class="mt-1 h-4 w-4 rounded border-slate-300 text-amber-600 focus:ring-amber-500 dark:border-slate-600 dark:bg-slate-700"
                    />

                    <%!-- Connection avatar with color theming --%>
                    <div class={[
                      "relative w-10 h-10 rounded-xl overflow-hidden flex-shrink-0",
                      "bg-gradient-to-br",
                      case connection.color do
                        :teal ->
                          "from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-teal-900/40"

                        :emerald ->
                          "from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/40 dark:via-teal-900/30 dark:to-emerald-900/40"

                        :cyan ->
                          "from-cyan-100 via-blue-50 to-cyan-100 dark:from-cyan-900/40 dark:via-blue-900/30 dark:to-cyan-900/40"

                        :purple ->
                          "from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/40 dark:via-violet-900/30 dark:to-purple-900/40"

                        :rose ->
                          "from-rose-100 via-pink-50 to-rose-100 dark:from-rose-900/40 dark:via-pink-900/30 dark:to-rose-900/40"

                        :amber ->
                          "from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/40 dark:via-orange-900/30 dark:to-amber-900/40"

                        :yellow ->
                          "from-yellow-100 via-orange-50 to-yellow-100 dark:from-yellow-900/40 dark:via-orange-900/30 dark:to-yellow-900/40"

                        :orange ->
                          "from-orange-100 via-amber-50 to-orange-100 dark:from-orange-900/40 dark:via-amber-900/30 dark:to-orange-900/40"

                        :indigo ->
                          "from-indigo-100 via-blue-50 to-indigo-100 dark:from-indigo-900/40 dark:via-blue-900/30 dark:to-indigo-900/40"

                        :pink ->
                          "from-pink-100 via-rose-50 to-pink-100 dark:from-pink-900/40 dark:via-rose-900/30 dark:to-pink-900/40"

                        _ ->
                          "from-slate-100 via-slate-50 to-slate-100 dark:from-slate-800/40 dark:via-slate-700/30 dark:to-slate-800/40"
                      end
                    ]}>
                      <img
                        src={get_connection_avatar_src(connection, @current_user, @key)}
                        alt="{get_decrypted_connection_label(connection, @current_user, @key)} avatar"
                        class="w-full h-full object-cover"
                        loading="lazy"
                      />
                    </div>

                    <%!-- Connection info with color theming --%>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2 mb-1">
                        <%!-- Connection color indicator --%>
                        <div class={[
                          "w-3 h-3 rounded-full flex-shrink-0",
                          case connection.color do
                            :teal -> "bg-gradient-to-br from-teal-400 to-emerald-500"
                            :emerald -> "bg-gradient-to-br from-emerald-400 to-teal-500"
                            :cyan -> "bg-gradient-to-br from-cyan-400 to-blue-500"
                            :purple -> "bg-gradient-to-br from-purple-400 to-violet-500"
                            :rose -> "bg-gradient-to-br from-rose-400 to-pink-500"
                            :amber -> "bg-gradient-to-br from-amber-400 to-orange-500"
                            :orange -> "bg-gradient-to-br from-orange-400 to-amber-500"
                            :indigo -> "bg-gradient-to-br from-indigo-400 to-blue-500"
                            _ -> "bg-gradient-to-br from-slate-400 to-slate-500"
                          end
                        ]}>
                        </div>

                        <%!-- Connection name --%>
                        <p class={[
                          "text-sm font-medium truncate",
                          case connection.color do
                            :teal -> "text-teal-800 dark:text-teal-200"
                            :emerald -> "text-emerald-800 dark:text-emerald-200"
                            :cyan -> "text-cyan-800 dark:text-cyan-200"
                            :purple -> "text-purple-800 dark:text-purple-200"
                            :rose -> "text-rose-800 dark:text-rose-200"
                            :amber -> "text-amber-800 dark:text-amber-200"
                            :orange -> "text-orange-800 dark:text-orange-200"
                            :indigo -> "text-indigo-800 dark:text-indigo-200"
                            _ -> "text-slate-800 dark:text-slate-200"
                          end
                        ]}>
                          {get_decrypted_connection_label(connection, @current_user, @key)}
                        </p>

                        <%!-- Connection badge with color theming --%>
                        <span class={[
                          "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0",
                          case connection.color do
                            :teal ->
                              "bg-teal-100/80 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300"

                            :emerald ->
                              "bg-emerald-100/80 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300"

                            :cyan ->
                              "bg-cyan-100/80 dark:bg-cyan-900/30 text-cyan-700 dark:text-cyan-300"

                            :purple ->
                              "bg-purple-100/80 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300"

                            :rose ->
                              "bg-rose-100/80 dark:bg-rose-900/30 text-rose-700 dark:text-rose-300"

                            :amber ->
                              "bg-amber-100/80 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300"

                            :orange ->
                              "bg-orange-100/80 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300"

                            :indigo ->
                              "bg-indigo-100/80 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300"

                            _ ->
                              "bg-slate-100/80 dark:bg-slate-900/30 text-slate-700 dark:text-slate-300"
                          end
                        ]}>
                          Connected
                        </span>
                      </div>

                      <%!-- Username display --%>
                      <p class={[
                        "text-xs leading-relaxed",
                        case connection.color do
                          :teal -> "text-teal-600 dark:text-teal-400"
                          :emerald -> "text-emerald-600 dark:text-emerald-400"
                          :cyan -> "text-cyan-600 dark:text-cyan-400"
                          :purple -> "text-purple-600 dark:text-purple-400"
                          :rose -> "text-rose-600 dark:text-rose-400"
                          :amber -> "text-amber-600 dark:text-amber-400"
                          :orange -> "text-orange-600 dark:text-orange-400"
                          :indigo -> "text-indigo-600 dark:text-indigo-400"
                          _ -> "text-slate-600 dark:text-slate-400"
                        end
                      ]}>
                        @{get_decrypted_connection_username(connection, @current_user, @key)}
                      </p>
                    </div>
                  </label>
                </div>
              </div>

              <%!-- Online Presence Controls --%>
              <div class="space-y-4 border-t border-slate-200 dark:border-slate-700 pt-6">
                <h3 class="text-base font-medium text-slate-900 dark:text-slate-100">
                  Online Presence
                </h3>
                <div class="group flex items-center gap-3 p-2 -m-2 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all duration-200 ease-out">
                  <div class="relative">
                    <.phx_input
                      type="checkbox"
                      field={@status_visibility_form[:show_online_presence]}
                      class="h-5 w-5 rounded-lg border-2 border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-emerald-600 dark:text-emerald-400 accent-emerald-600 dark:accent-emerald-400 focus:ring-emerald-500/50 dark:focus:ring-emerald-400/50 focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-slate-800 transition-all duration-200 ease-out hover:border-emerald-400 dark:hover:border-emerald-500 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 checked:border-emerald-600 dark:checked:border-emerald-400 checked:bg-emerald-600 dark:checked:bg-emerald-400 shadow-sm hover:shadow-md"
                    />
                  </div>
                  <div class="flex-1">
                    <label
                      for="show_online_presence"
                      class="text-sm font-medium text-slate-900 dark:text-slate-100 cursor-pointer leading-relaxed hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors duration-200 ease-out"
                    >
                      Show when I'm online
                    </label>
                  </div>
                </div>
              </div>

              <%!-- Action button --%>
              <div class="flex justify-end pt-4">
                <DesignSystem.liquid_button
                  type="submit"
                  phx-disable-with="Updating..."
                  icon="hero-check"
                  color="purple"
                >
                  Update Visibility
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <%!-- Privacy explanation card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">Privacy & Status</span>
              </div>
            </:title>

            <div class="space-y-4">
              <div class="space-y-3">
                <div class="flex items-center gap-3">
                  <DesignSystem.liquid_badge variant="soft" color="teal" size="sm">
                    Privacy First
                  </DesignSystem.liquid_badge>
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                    Your Status is Private by Default
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Your status and online presence are completely private unless you choose to share them.
                  You have granular control over exactly who can see your activity.
                </p>
              </div>

              <div class="space-y-3">
                <div class="flex items-center gap-3">
                  <DesignSystem.liquid_badge variant="soft" color="purple" size="sm">
                    Granular Control
                  </DesignSystem.liquid_badge>
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                    Choose Exactly Who Sees Your Status
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Share your status with everyone, just your connections, specific groups like "Work" or "Family",
                  or even individual people. The choice is always yours.
                </p>
              </div>

              <div class="space-y-3">
                <div class="flex items-center gap-3">
                  <DesignSystem.liquid_badge variant="soft" color="emerald" size="sm">
                    Encrypted
                  </DesignSystem.liquid_badge>
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                    Your Status Messages are Encrypted
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  All status messages are encrypted so only you and the people you choose can read them.
                  Even MOSSLET can't see your status messages.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  def handle_info({:status_updated, user}, socket) do
    # Only handle updates for the current user (to refresh the sidebar avatar)
    current_user = socket.assigns.current_user

    if user.id == current_user.id do
      {:noreply,
       socket
       |> assign(current_user: user)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:status_visibility_updated, user}, socket) do
    # Only handle updates for the current user (to refresh the sidebar avatar)
    current_user = socket.assigns.current_user

    if user.id == current_user.id do
      # Update the current_user assign with the new status to refresh the sidebar
      {:noreply, assign(socket, current_user: user)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Event handlers

  def handle_event("toggle_auto_status_explanation", _params, socket) do
    current_state = socket.assigns.show_auto_status_explanation
    {:noreply, assign(socket, :show_auto_status_explanation, !current_state)}
  end

  def handle_event("set_status", %{"status" => status}, socket) do
    # Get current user and create a changeset with the new status
    user = socket.assigns.current_user
    key = socket.assigns.key

    # Build attrs from current changeset plus new status
    # Handle both changeset and map sources
    current_changes =
      case socket.assigns.status_form.source do
        %Ecto.Changeset{} = changeset ->
          # Convert to string keys
          (changeset.changes || %{})
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Enum.into(%{})

        source_map when is_map(source_map) ->
          # Convert to string keys
          source_map
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Enum.into(%{})

        _ ->
          %{}
      end

    # Ensure all keys are strings for the changeset
    # Make sure to use the decrypted status message, not the encrypted one
    # Clear status message if going offline, otherwise preserve current input or existing message
    status_message =
      if status == "offline" do
        ""
      else
        # Preserve current input from the form or fall back to existing message
        socket.assigns.status_message || get_decrypted_status_message(user, key) || ""
      end

    attrs =
      current_changes
      |> Map.put("status", status)
      |> Map.put("status_message", status_message)
      |> Map.put("auto_status", socket.assigns.auto_status)
      |> Enum.map(fn
        {k, v} when is_atom(k) -> {Atom.to_string(k), v}
        {k, v} -> {k, v}
      end)
      |> Enum.into(%{})

    changeset = Accounts.change_user_status(user, attrs, user: user, key: key)
    status_form = to_form(changeset)

    {:noreply, assign(socket, status_form: status_form, status_message: status_message)}
  end

  def handle_event("validate_status", params, socket) do
    # Handle both nested and direct parameter formats using pattern matching
    status_params =
      case params do
        %{"user" => user_params} -> user_params
        %{"status" => nested_params} when is_map(nested_params) -> nested_params
        direct_params when is_map(direct_params) -> direct_params
        _ -> %{}
      end

    # Create a changeset to validate the parameters
    user = socket.assigns.current_user
    key = socket.assigns.key

    # Get current changeset data to preserve existing changes
    # Handle both changeset and map sources
    current_changeset = socket.assigns.status_form.source

    current_changes =
      case current_changeset do
        %Ecto.Changeset{} = changeset ->
          # Convert changeset changes to string keys to match incoming params
          (changeset.changes || %{})
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Enum.into(%{})

        source_map when is_map(source_map) ->
          # Ensure all keys are strings
          source_map
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Enum.into(%{})

        _ ->
          %{}
      end

    # Convert string values to appropriate types and merge with current state
    # Ensure status_params is enumerable before processing
    normalized_params =
      if is_map(status_params) do
        status_params
        |> Enum.reject(fn {k, _v} ->
          (is_binary(k) and String.starts_with?(k, "_unused_")) or
            k in ["_target", "_csrf_token", "_persistent_id"]
        end)
        |> Enum.map(fn {k, v} ->
          case k do
            "status" when is_binary(v) -> {"status", v}
            "auto_status" when is_binary(v) -> {"auto_status", v == "true"}
            "status_message" when is_binary(v) -> {"status_message", v}
            key when is_binary(key) -> {key, v}
            {key, val} -> {to_string(key), val}
          end
        end)
        |> Enum.into(%{})
      else
        %{}
      end

    # Merge normalized params with current changes to preserve all form state
    # Ensure all keys are strings and all values are properly typed
    merged_params = Map.merge(current_changes, normalized_params)

    # Ensure all keys in merged_params are strings to avoid mixed key errors
    string_params =
      merged_params
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})

    changeset = Accounts.change_user_status(user, string_params, user: user, key: key)

    status_form = to_form(changeset)

    # Update the status_message assign to show current input value for the input field
    current_status_message =
      Map.get(normalized_params, "status_message", socket.assigns.status_message)

    current_auto_status = Map.get(normalized_params, "auto_status", socket.assigns.auto_status)

    {:noreply,
     assign(socket,
       status_form: status_form,
       status_message: current_status_message,
       auto_status: current_auto_status
     )}
  end

  def handle_event("update_status", params, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    # Handle both full status updates and partial updates using pattern matching
    status_params =
      case params do
        %{"user" => nested_params} when is_map(nested_params) -> nested_params
        %{"status" => nested_params} when is_map(nested_params) -> nested_params
        direct_params -> direct_params
      end

    # Build attrs safely with pattern matching for missing fields
    attrs = %{
      "status" =>
        if is_map(status_params) do
          case Map.get(status_params, "status") do
            nil -> "offline"
            status_string -> status_string
          end
        else
          status_params
        end,
      "auto_status" => Map.get(status_params, "auto_status") == "true"
    }

    # Only include status_message if it's explicitly provided and not empty
    # This allows clearing the message when user intentionally empties it
    attrs =
      case Map.get(status_params, "status_message") do
        # Don't update status_message
        nil -> attrs
        # Explicitly clear it
        "" -> Map.put(attrs, "status_message", nil)
        # Set the message
        message -> Map.put(attrs, "status_message", message)
      end

    # Convert string status to atom for the Status module
    status_attrs = %{
      status: String.to_existing_atom(attrs["status"]),
      status_message: attrs["status_message"],
      auto_status: attrs["auto_status"]
    }

    case Statuses.update_user_status(user, status_attrs, user: user, key: key) do
      {:ok, updated_user} ->
        updated_user = Accounts.get_user_with_preloads(updated_user.id)

        status_form =
          to_form(%{
            "status" => to_string(updated_user.status),
            "status_message" => get_decrypted_status_message(updated_user, key) || "",
            "auto_status" => updated_user.auto_status
          })

        {:noreply,
         socket
         |> put_flash(:success, "Your status has been updated successfully!")
         |> assign(
           status_form: status_form,
           status_message: get_decrypted_status_message(updated_user, key) || "",
           auto_status: updated_user.auto_status
         )}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "There was an error updating your status. Please try again.")}
    end
  end

  def handle_event("validate_status_visibility", params, socket) do
    # Extract the status_visibility value from different parameter structures
    status_visibility =
      case params do
        %{"status_visibility_form" => %{"status_visibility" => val}} -> val
        %{"user" => %{"status_visibility" => val}} -> val
        %{"status_visibility" => val} -> val
        _ -> "nobody"
      end

    # Extract checkbox selections for groups and users
    selected_groups = extract_checkbox_values(params, "status_visible_to_groups")
    selected_users = extract_checkbox_values(params, "status_visible_to_users")

    # Extract other form values - the form sends parameters directly at top level
    show_online_presence =
      case params do
        %{"show_online_presence" => val} -> val
        %{"status_visibility_form" => %{"show_online_presence" => val}} -> val
        %{"user" => %{"show_online_presence" => val}} -> val
        _rest -> false
      end

    # Create updated form with current selections
    status_visibility_form =
      to_form(%{
        "status_visibility" => normalize_status_visibility(status_visibility),
        "show_online_presence" => show_online_presence,
        "status_visible_to_groups" => selected_groups,
        "status_visible_to_users" => selected_users,
        # simply match
        "presence_visible_to_groups" => selected_groups,
        # simply match
        "presence_visible_to_users" => selected_users
      })

    {:noreply, assign(socket, status_visibility_form: status_visibility_form)}
  end

  def handle_event("update_status_visibility", params, socket) do
    # Handle different form parameter structures using pattern matching
    visibility_params =
      case params do
        %{"status_visibility_form" => form_params} -> form_params
        %{"user" => user_params} -> user_params
        raw_params when is_map(raw_params) -> raw_params
        _ -> %{}
      end

    # Extract groups and users from form arrays using pattern matching
    selected_groups = extract_checkbox_values(params, "status_visible_to_groups")
    selected_users = extract_checkbox_values(params, "status_visible_to_users")

    # Build normalized params
    formatted_params = %{
      "status_visibility" => visibility_params["status_visibility"] || "nobody",
      "show_online_presence" => visibility_params["show_online_presence"],
      "status_visible_to_groups" => selected_groups,
      "status_visible_to_users" => selected_users,
      "presence_visible_to_groups" => selected_groups,
      "presence_visible_to_users" => selected_users
    }

    handle_status_visibility_update(formatted_params, socket)
  end

  defp handle_status_visibility_update(visibility_params, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    # Safely convert visibility to atom using pattern matching
    status_visibility =
      case visibility_params["status_visibility"] do
        "nobody" -> :nobody
        "connections" -> :connections
        "specific_groups" -> :specific_groups
        "specific_users" -> :specific_users
        "public" -> :public
        val when is_atom(val) -> val
        _ -> :nobody
      end

    # Prepare attrs
    attrs = %{
      status_visibility: status_visibility,
      show_online_presence: visibility_params["show_online_presence"],
      status_visible_to_groups: visibility_params["status_visible_to_groups"] || [],
      status_visible_to_users: visibility_params["status_visible_to_users"] || [],
      presence_visible_to_groups: visibility_params["status_visible_to_groups"] || [],
      presence_visible_to_users: visibility_params["status_visible_to_users"] || []
    }

    case Statuses.update_user_status_visibility(user, attrs, user: user, key: key) do
      {:ok, updated_user} ->
        # Preserve the selected groups from the original form submission
        selected_groups = visibility_params["status_visible_to_groups"] || []
        selected_users = visibility_params["status_visible_to_users"] || []
        selected_presence_groups = visibility_params["status_visible_to_groups"] || []
        selected_presence_users = visibility_params["status_visible_to_users"] || []

        # Recreate form with updated data but preserve selections
        status_visibility_form =
          to_form(%{
            "status_visibility" => Atom.to_string(updated_user.status_visibility || :nobody),
            "show_online_presence" => updated_user.show_online_presence,
            "status_visible_to_groups" => selected_groups,
            "status_visible_to_users" => selected_users,
            "presence_visible_to_groups" => selected_presence_groups,
            "presence_visible_to_users" => selected_presence_users
          })

        {:noreply,
         socket
         |> put_flash(:success, "Your status visibility has been updated successfully!")
         |> assign(status_visibility_form: status_visibility_form)}

      {:error, changeset} ->
        # Show specific validation errors if available using pattern matching
        error_message =
          case changeset.errors do
            [] ->
              "There was an error updating your status visibility. Please try again."

            errors ->
              "Validation errors: " <>
                (Enum.map(errors, fn {field, {msg, _}} -> "#{field}: #{msg}" end)
                 |> Enum.join(", "))
          end

        {:noreply,
         socket
         |> put_flash(:error, error_message)}
    end
  end

  # Helper function to normalize status visibility values (can be atom or string)
  defp normalize_status_visibility(value) do
    case value do
      :nobody -> "nobody"
      :connections -> "connections"
      :specific_groups -> "specific_groups"
      :specific_users -> "specific_users"
      :public -> "public"
      val when is_binary(val) -> val
      _ -> "nobody"
    end
  end

  # Helper function to check if current value matches target visibility
  defp status_visibility_matches?(current_value, target) do
    normalized_current = normalize_status_visibility(current_value)
    normalized_target = normalize_status_visibility(target)
    normalized_current == normalized_target
  end

  # Helper function to extract checkbox values from different parameter structures
  defp extract_checkbox_values(params, field_name) do
    # Build the array field name
    array_field_name = field_name <> "[]"

    # Pattern match different form parameter structures
    case params do
      # Pattern 1: status_visibility_form[field_name][]
      %{"status_visibility_form" => form_params} when is_map(form_params) ->
        cond do
          Map.has_key?(form_params, array_field_name) and is_list(form_params[array_field_name]) ->
            form_params[array_field_name]

          Map.has_key?(form_params, field_name) and is_list(form_params[field_name]) ->
            form_params[field_name]

          Map.has_key?(form_params, field_name) and is_binary(form_params[field_name]) ->
            [form_params[field_name]]

          true ->
            []
        end

      # Pattern 2: Direct field[] at top level
      %{} when is_map_key(params, array_field_name) ->
        case params[array_field_name] do
          values when is_list(values) -> values
          value when is_binary(value) -> [value]
          _ -> []
        end

      # Pattern 3: Direct field at top level
      %{} when is_map_key(params, field_name) ->
        case params[field_name] do
          values when is_list(values) -> values
          value when is_binary(value) -> [value]
          _ -> []
        end

      # Pattern 4: No match, return empty list
      _ ->
        []
    end
    |> List.wrap()
    |> List.flatten()
    |> Enum.filter(&is_binary/1)
  end

  # Helper functions

  defp get_saved_status_visibility_selections(user, key) do
    # Decrypt the saved group/user selections if they exist
    saved_groups = decrypt_selection_list(user.connection.status_visible_to_groups, user, key)
    saved_users = decrypt_selection_list(user.connection.status_visible_to_users, user, key)

    {saved_groups, saved_users}
  end

  defp decrypt_selection_list(encrypted_data, user, key) do
    # Use pattern matching instead of try/rescue
    case encrypted_data do
      # Empty cases
      nil ->
        []

      "" ->
        []

      [] ->
        []

      # List of encrypted strings
      encrypted_list when is_list(encrypted_list) ->
        encrypted_list
        |> Enum.map(fn encrypted_id ->
          case Mosslet.Encrypted.Users.Utils.decrypt_user_item(
                 encrypted_id,
                 user,
                 user.conn_key,
                 key
               ) do
            item_id when is_binary(item_id) -> item_id
            :failed_verification -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))

      # Single encrypted string
      encrypted_string when is_binary(encrypted_string) ->
        case Mosslet.Encrypted.Users.Utils.decrypt_user_item(
               encrypted_string,
               user,
               user.conn_key,
               key
             ) do
          item_id when is_binary(item_id) -> [item_id]
          :failed_verification -> []
        end

      # Unknown format
      _ ->
        []
    end
  end

  defp get_decrypted_status_message(user, key) do
    if user.connection.status_message do
      # Use decrypt_user_data since status_message is encrypted with user_key
      case Mosslet.Encrypted.Users.Utils.decrypt_user_item(
             user.connection.status_message,
             user,
             user.conn_key,
             key
           ) do
        # Handle direct return value (no tuple wrapping)
        decrypted_message when is_binary(decrypted_message) ->
          decrypted_message

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp get_status_visibility_options(user_visibility) do
    base_options = [
      {"Nobody (most private)", :nobody},
      {"All connections", :connections},
      {"Specific groups", :specific_groups},
      {"Specific users", :specific_users}
    ]

    case user_visibility do
      :private ->
        # Private users can only share with nobody or connections
        Enum.take(base_options, 2)

      :connections ->
        # Connections users can't make status public
        base_options

      :public ->
        # Public users can use any status visibility including public
        base_options ++ [{"Everyone (public)", :public}]

      _ ->
        base_options
    end
  end

  defp status_visibility_help_text(status_visibility, user_visibility) do
    case {user_visibility, normalize_status_visibility(status_visibility)} do
      {_, "nobody"} ->
        "Your status is completely private. No one can see your status or online presence."

      {_, "connections"} ->
        "Only your confirmed connections can see your status and online presence."

      {_, "specific_groups"} ->
        "Only people in your selected visibility groups can see your status and online presence."

      {_, "specific_users"} ->
        "Only specific people you choose can see your status and online presence."

      {:public, "public"} ->
        "Everyone can see your status and online presence, including people who aren't connected to you."

      _ ->
        "Choose who can see your status and activity on MOSSLET."
    end
  end

  defp visibility_badge_color(status_visibility) do
    case normalize_status_visibility(status_visibility) do
      "nobody" -> "slate"
      "connections" -> "emerald"
      "specific_groups" -> "purple"
      "specific_users" -> "amber"
      "public" -> "blue"
      _ -> "slate"
    end
  end

  def ensure_string(input) do
    case input do
      :nobody -> "nobody"
      "nobody" -> "nobody"
      :connections -> "connections"
      "connections" -> "connections"
      :specific_groups -> "specific groups"
      "specific_groups" -> "specific groups"
      :specific_users -> "specific users"
      "specific_users" -> "specific users"
      :public -> "public"
      "public" -> "public"
      input when is_map(input) -> "map"
      input when is_list(input) -> "list"
      nil -> "nobody"
      _ -> to_string(input)
    end
  end
end
