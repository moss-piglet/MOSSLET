defmodule MossletWeb.GroupLive.Join do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Groups.Group

  @impl true
  def render(assigns) do
    ~H"""
    <.layout current_scope={@current_scope} current_page={@current_page} type="sidebar">
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-amber-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-amber-900/10">
        <div class="flex min-h-[80vh] items-center justify-center p-4">
          <div class="w-full max-w-md">
            <div class="relative bg-white/80 dark:bg-slate-800/80 backdrop-blur-xl rounded-2xl border border-slate-200/60 dark:border-slate-700/60 shadow-xl shadow-slate-900/5 dark:shadow-slate-900/30 overflow-hidden">
              <div class="absolute inset-0 bg-gradient-to-br from-amber-500/5 via-transparent to-orange-500/5 dark:from-amber-500/10 dark:to-orange-500/10 pointer-events-none" />

              <div class="relative p-6 sm:p-8">
                <div class="flex flex-col items-center text-center mb-6">
                  <div class="p-3 rounded-2xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/40 dark:to-orange-900/40 mb-4">
                    <.phx_icon
                      name="hero-lock-closed"
                      class="h-8 w-8 text-amber-600 dark:text-amber-400"
                    />
                  </div>

                  <h1 class="text-xl font-bold text-slate-900 dark:text-slate-100 mb-1">
                    Join Protected Circle
                  </h1>

                  <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
                    Enter the password to join this circle
                  </p>

                  <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-100/80 dark:bg-slate-700/50 border border-slate-200/60 dark:border-slate-600/40">
                    <.phx_icon
                      name="hero-circle-stack"
                      class="w-4 h-4 text-slate-500 dark:text-slate-400"
                    />
                    <span
                      :if={@group.public?}
                      class="text-sm font-medium text-slate-700 dark:text-slate-300"
                    >
                      {decr_public_item(
                        @group.name,
                        get_public_user_group(@group, @current_scope.user).key
                      )}
                    </span>
                    <span
                      :if={!@group.public?}
                      class="text-sm font-medium text-slate-700 dark:text-slate-300"
                    >
                      {decr_item(
                        @group.name,
                        @current_scope.user,
                        get_user_group(@group, @current_scope.user).key,
                        @key,
                        @group
                      )}
                    </span>
                  </div>
                </div>

                <.form
                  for={@form}
                  id="group-join-password-form"
                  phx-change="validate"
                  phx-submit="save"
                  class="space-y-5"
                >
                  <.phx_input
                    :if={@live_action == :join_password}
                    id="password"
                    field={@form[:password]}
                    phx-debounce="blur"
                    type="password"
                    label="Circle Password"
                    autocomplete="off"
                    placeholder="Enter circle password..."
                    required
                    {alpine_autofocus()}
                  />

                  <.phx_input field={@form[:user_id]} type="hidden" value={@current_scope.user.id} />

                  <div
                    :if={@join_attempts > 0 && @join_attempts < 5}
                    class="flex items-center gap-2 p-3 rounded-xl bg-amber-50/80 dark:bg-amber-900/20 border border-amber-200/60 dark:border-amber-700/40"
                  >
                    <.phx_icon
                      name="hero-exclamation-triangle"
                      class="w-5 h-5 text-amber-600 dark:text-amber-400 flex-shrink-0"
                    />
                    <p class="text-sm text-amber-700 dark:text-amber-300">
                      {5 - @join_attempts} attempt{if @join_attempts == 4, do: "", else: "s"} remaining
                    </p>
                  </div>

                  <div class="flex flex-col-reverse sm:flex-row gap-3 pt-2">
                    <MossletWeb.DesignSystem.liquid_button
                      type="button"
                      variant="secondary"
                      color="slate"
                      phx-click={JS.navigate(~p"/app/circles/greet")}
                      class="w-full sm:w-auto sm:flex-1"
                    >
                      Cancel
                    </MossletWeb.DesignSystem.liquid_button>

                    <MossletWeb.DesignSystem.liquid_button
                      :if={@live_action in [:join_password]}
                      type="submit"
                      color="amber"
                      icon="hero-lock-open"
                      class="w-full sm:w-auto sm:flex-1"
                      phx-disable-with="Verifying..."
                    >
                      Join Circle
                    </MossletWeb.DesignSystem.liquid_button>
                  </div>
                </.form>
              </div>
            </div>

            <p class="mt-4 text-center text-xs text-slate-500 dark:text-slate-400">
              Don't know the password?
              <.link
                navigate={~p"/app/circles/greet"}
                class="font-medium text-amber-600 hover:text-amber-500 dark:text-amber-400 dark:hover:text-amber-300"
              >
                Go back to invitations
              </.link>
            </p>
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Groups.private_subscribe(socket.assigns.current_scope.user)
    end

    {:ok, assign(socket, :current_page, :groups), layout: {MossletWeb.Layouts, :app}}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:join_attempts, Map.get(socket.assigns, "join_attempts", 0))

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    current_scope = %{socket.assigns.current_scope | user: user}
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :join_password, %{"id" => id}) do
    group = Groups.get_group!(id)
    user_group = get_user_group(group, socket.assigns.current_scope.user)

    if group.require_password? &&
         can_join_group?(group, user_group, socket.assigns.current_scope.user) do
      changeset = Group.join_changeset(group, %{password: nil})

      socket
      |> assign(:group, Groups.get_group!(id))
      |> assign(:user_group, user_group)
      |> assign(:page_title, "Joining Circle")
      |> assign(:live_action, :join_password)
      |> assign(:groups_greeter_open?, false)
      |> assign_form(changeset)
    else
      socket
      |> assign(:page_title, "New Circle Invitations")
      |> assign(:live_action, :greet)
      |> assign(:groups_greeter_open?, true)
      |> put_flash(:info, "You do not have permission to join this group.")
    end
  end

  @impl true
  def handle_event("validate", %{"group" => _group_params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"group" => group_params}, socket) do
    save_group(socket, socket.assigns.live_action, group_params)
  end

  defp save_group(socket, :join_password, group_params) do
    user = socket.assigns.current_scope.user
    group = socket.assigns.group
    user_group = socket.assigns.user_group
    key = socket.assigns.current_scope.key

    if can_join_group?(group, user_group, user) do
      join_result =
        if group.public? && is_nil(user_group) do
          Groups.join_public_group(group, user, key, join_password: group_params["password"])
        else
          Groups.join_group(group, user_group, join_password: group_params["password"])
        end

      case join_result do
        {:ok, _result} ->
          {:noreply,
           socket
           |> put_flash(:success, "Circle joined successfully")
           |> push_navigate(to: ~p"/app/circles/#{group}")}

        {:error, %Ecto.Changeset{} = _changeset} ->
          join_attempts = socket.assigns.join_attempts + 1
          socket = assign(socket, join_attempts: join_attempts)
          clean_changeset = Group.join_changeset(group, %{password: ""}) |> Map.put(:action, nil)

          case join_attempts do
            0 ->
              {:noreply, assign_form(socket, clean_changeset)}

            1 ->
              {:noreply,
               socket
               |> assign_form(clean_changeset)
               |> put_flash(
                 :info,
                 "Incorrect password, #{5 - join_attempts} attempts left, please try again."
               )}

            2 ->
              {:noreply,
               socket
               |> assign_form(clean_changeset)
               |> put_flash(
                 :info,
                 "Incorrect password, #{5 - join_attempts} attempts left, please try again."
               )}

            3 ->
              {:noreply,
               socket
               |> assign_form(clean_changeset)
               |> put_flash(
                 :info,
                 "Incorrect password, #{5 - join_attempts} attempts left, please try again."
               )}

            4 ->
              {:noreply,
               socket
               |> assign_form(clean_changeset)
               |> put_flash(
                 :warning,
                 "Incorrect password, #{5 - join_attempts} attempt left, please try again."
               )}

            5 ->
              {:noreply,
               socket
               |> put_flash(:error, "Too many failed attempts. Please try again later.")
               |> push_navigate(to: ~p"/app/circles/greet")}

            _rest ->
              {:noreply,
               socket
               |> put_flash(:error, "Too many failed attempts. Please try again later.")
               |> push_navigate(to: ~p"/app/circles/greet")}
          end
      end
    else
      {:noreply, socket}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
