defmodule MossletWeb.GroupLive.Join do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Groups.Group

  @impl true
  def render(assigns) do
    ~H"""
    <.layout current_user={@current_user} current_page={@current_page} key={@key} type="sidebar">
      <.container>
        <div>
          <div class="relative z-10" aria-labelledby="modal-title" role="dialog" aria-modal="true">
            <div class="fixed inset-0 blur-2xl"></div>

            <div class="fixed inset-0 z-10 w-screen overflow-y-auto">
              <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
                <div class="relative transform overflow-hidden rounded-lg bg-white dark:bg-gray-800 px-4 pb-4 pt-5 text-left shadow-xl dark:shadow-emerald-500/50  transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
                  <div>
                    <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-red-100 dark:bg-red-800">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-6 w-6 text-red-600 dark:text-red-400"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke-width="1.5"
                        stroke="currentColor"
                        class="w-6 h-6"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"
                        />
                      </svg>
                    </div>
                    <div class="mt-3 text-center sm:mt-5">
                      <.h3
                        class="text-base font-semibold leading-6 text-gray-900 dark:text-gray-50"
                        id="modal-title"
                      >
                        {decr_item(
                          @group.name,
                          @current_user,
                          get_user_group(@group, @current_user).key,
                          @key,
                          @group
                        )}
                      </.h3>
                      <div class="mt-2">
                        <.p class="text-sm text-gray-500 dark:text-gray-400">
                          Please enter the group's password to join.
                        </.p>
                      </div>
                    </div>
                  </div>
                  <.form
                    for={@form}
                    id="group-join-password-form"
                    phx-change="validate"
                    phx-submit="save"
                  >
                    <div id="passwordField" class="relative">
                      <div id="pw-label-container" class="flex justify-between">
                        <div id="pw-actions" class="absolute top-0 right-0">
                          <button
                            type="button"
                            id="eye"
                            data-tippy-content="Show password"
                            phx-hook="TippyHook"
                            phx-click={
                              JS.set_attribute({"type", "text"}, to: "#password")
                              |> JS.remove_class("hidden", to: "#eye-slash")
                              |> JS.add_class("hidden", to: "#eye")
                            }
                          >
                            <.icon name="hero-eye" class="h-5 w-5 dark:text-white cursor-pointer" />
                          </button>
                          <button
                            type="button"
                            id="eye-slash"
                            x-data
                            x-tooltip="Hide password"
                            data-tippy-content="Hide password"
                            phx-hook="TippyHook"
                            class="hidden"
                            phx-click={
                              JS.set_attribute({"type", "password"}, to: "#password")
                              |> JS.add_class("hidden", to: "#eye-slash")
                              |> JS.remove_class("hidden", to: "#eye")
                            }
                          >
                            <.icon
                              name="hero-eye-slash"
                              class="h-5 w-5  dark:text-white cursor-pointer"
                            />
                          </button>
                        </div>
                      </div>
                    </div>
                    <.field
                      :if={@live_action == :join_password}
                      id="password"
                      field={@form[:password]}
                      phx-debounce="blur"
                      type="password"
                      label="Password"
                      autocomplete="off"
                      required
                      {alpine_autofocus()}
                    />
                    <.field field={@form[:user_id]} type="hidden" value={@current_user.id} />

                    <div class="mt-5 sm:mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                      <.button
                        :if={@live_action in [:join_password]}
                        phx-disable-with="Checking..."
                        class="rounded-full"
                      >
                        Submit
                      </.button>

                      <.button
                        type="button"
                        color="secondary"
                        class="rounded-full"
                        phx-click={JS.navigate(~p"/app/groups/greet")}
                      >
                        Cancel
                      </.button>
                    </div>
                  </.form>
                </div>
              </div>
            </div>
          </div>
        </div>
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Groups.private_subscribe(socket.assigns.current_user)
    end

    {:ok, assign(socket, :current_page, "Joining Group"), layout: {MossletWeb.Layouts, :app}}
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
    {:noreply, assign(socket, :current_user, user)}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :join_password, %{"id" => id}) do
    group = Groups.get_group!(id)
    user_group = get_user_group(group, socket.assigns.current_user)

    if group.require_password? && can_join_group?(group, user_group, socket.assigns.current_user) do
      changeset = Group.join_changeset(group, %{password: nil})

      socket
      |> assign(:group, Groups.get_group!(id))
      |> assign(:user_group, user_group)
      |> assign(:page_title, "Joining Group")
      |> assign(:live_action, :join_password)
      |> assign(:groups_greeter_open?, false)
      |> assign_form(changeset)
    else
      socket
      |> assign(:page_title, "New Group Invitations")
      |> assign(:live_action, :greet)
      |> assign(:groups_greeter_open?, true)
      |> put_flash(:info, "You do not have permission to join this group.")
    end
  end

  @impl true
  def handle_event("validate", %{"group" => group_params}, socket) do
    changeset =
      Group.join_changeset(socket.assigns.group, %{password: group_params["password"]}, [])
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"group" => group_params}, socket) do
    save_group(socket, socket.assigns.live_action, group_params)
  end

  defp save_group(socket, :join_password, group_params) do
    user = socket.assigns.current_user
    group = socket.assigns.group
    user_group = socket.assigns.user_group

    if can_join_group?(group, user_group, user) do
      case Groups.join_group(group, user_group, join_password: group_params["password"]) do
        {:ok, group} ->
          {:noreply,
           socket
           |> put_flash(:success, "Group joined successfully")
           |> push_navigate(to: ~p"/app/groups/#{group}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          join_attempts = socket.assigns.join_attempts + 1
          socket = assign(socket, join_attempts: join_attempts)

          case join_attempts do
            0 ->
              {:noreply, assign_form(socket, changeset)}

            1 ->
              {:noreply,
               socket
               |> assign_form(changeset)
               |> put_flash(
                 :info,
                 "Incorrect password, #{5 - join_attempts} attempts left, please try again."
               )}

            2 ->
              {:noreply,
               socket
               |> assign_form(changeset)
               |> put_flash(
                 :info,
                 "Incorrect password, #{5 - join_attempts} attempts left, please try again."
               )}

            3 ->
              {:noreply,
               socket
               |> assign_form(changeset)
               |> put_flash(
                 :info,
                 "Incorrect password, #{5 - join_attempts} attempts left, please try again."
               )}

            4 ->
              {:noreply,
               socket
               |> assign_form(changeset)
               |> put_flash(
                 :warning,
                 "Incorrect password, #{5 - join_attempts} attempt left, please try again."
               )}

            5 ->
              {:noreply,
               socket
               |> put_flash(:error, "Too many failed attempts. Please try again later.")
               |> push_navigate(to: ~p"/app/groups/greet")}

            _rest ->
              {:noreply,
               socket
               |> put_flash(:error, "Too many failed attempts. Please try again later.")
               |> push_navigate(to: ~p"/app/groups/greet")}
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
