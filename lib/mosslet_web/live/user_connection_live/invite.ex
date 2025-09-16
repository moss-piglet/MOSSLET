defmodule MossletWeb.UserConnectionLive.Invite do
  use MossletWeb, :live_view

  alias Mosslet.Invitations
  alias Mosslet.Invitations.Invite

  def render(assigns) do
    ~H"""
    <.layout current_page={:new_invite} current_user={@current_user} key={@key} type="sidebar">
      <div class="space-y-8 pt-4 mx-4 sm:mx-6 max-w-4xl">
        <%!-- Invitation Section --%>
        <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden">
          <%!-- Section Header --%>
          <div class="border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900/50 px-6 py-4">
            <div class="flex flex-col space-y-4">
              <h2
                id="invite-connection-title"
                class="text-xl sm:text-2xl font-semibold text-gray-900 dark:text-white"
              >
                Join me on Mosslet!
              </h2>
              <div class="space-y-3">
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  Fill out the form below to send a new invitation. The person you invite will receive an email to their inbox inviting them to join you on Mosslet.
                </p>
                <p class="text-sm text-gray-600 dark:text-gray-300">
                  Curious to see how it works? Try sending one to yourself.
                </p>
              </div>
            </div>
          </div>

          <%!-- Form Content --%>
          <div class="p-6">
            <.form for={@form} id="new-invite-form" phx-change="validate" phx-submit="send_invite">
              <.phx_input
                field={@form[:current_user_name]}
                type="hidden"
                value={decr(@current_user.name, @current_user, @key)}
              />
              <.phx_input
                field={@form[:current_user_email]}
                type="hidden"
                value={decr(@current_user.email, @current_user, @key)}
              />
              <.phx_input
                field={@form[:current_user_username]}
                type="hidden"
                value={decr(@current_user.username, @current_user, @key)}
              />

              <div class="space-y-6">
                <.phx_input
                  field={@form[:recipient_name]}
                  type="text"
                  label="Name"
                  required
                  phx-debounce="500"
                  autocomplete="off"
                  apply_classes?={true}
                  classes={[
                    "block w-full rounded-md border-0 py-2 px-3 text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800"
                  ]}
                />

                <.phx_input
                  field={@form[:recipient_email]}
                  type="email"
                  label="Email"
                  required
                  phx-debounce="500"
                  autocomplete="off"
                  apply_classes?={true}
                  classes={[
                    "block w-full rounded-md border-0 py-2 px-3 text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800"
                  ]}
                />

                <.phx_input
                  field={@form[:message]}
                  type="textarea"
                  label="Message (optional)"
                  phx-debounce="500"
                  rows="4"
                  apply_classes?={true}
                  classes={[
                    "block w-full rounded-md border-0 py-2 px-3 text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800 resize-none min-h-[6rem]"
                  ]}
                />
              </div>

              <div class="flex justify-end pt-6">
                <button
                  :if={@form.source.valid?}
                  type="submit"
                  phx-disable-with="Sending..."
                  class="inline-flex items-center justify-center rounded-full bg-gradient-to-r from-teal-500 to-emerald-500 px-6 py-3 text-sm font-semibold text-white shadow-lg hover:scale-105 transform transition-all duration-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
                >
                  <.phx_icon name="hero-paper-airplane" class="size-5 mr-2" /> Send Invitation
                </button>

                <button
                  :if={!@form.source.valid?}
                  disabled
                  type="button"
                  class="inline-flex items-center justify-center rounded-full bg-gray-300 dark:bg-gray-600 px-6 py-3 text-sm font-semibold text-gray-500 dark:text-gray-400 cursor-not-allowed opacity-60"
                >
                  <.phx_icon name="hero-clock" class="size-5 mr-2" /> Complete Form
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    form = to_form(Invitations.change_invitation(%Invite{}, %{}))

    {:ok, assign(socket, :form, form)}
  end

  def handle_params(params, _url, socket) do
    live_action = socket.assigns.live_action

    {:noreply, apply_action(socket, live_action, params)}
  end

  def apply_action(socket, :new_invite, _params) do
    socket
    |> assign(:page_title, "New Invitation")
  end

  def handle_event("validate", %{"invite" => params}, socket) do
    changeset =
      %Invite{}
      |> Invitations.change_invitation(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("send_invite", %{"invite" => params}, socket) do
    case save_invite_new_user_job(params) do
      {:ok, %Oban.Job{conflict?: false} = oban_job} ->
        changeset = Invitations.change_invitation(%Invite{}, %{message: params["message"]})

        socket =
          socket
          |> clear_flash(:warning)
          |> clear_flash(:success)
          |> clear_flash(:error)
          |> put_flash(
            :success,
            "Your invitation to #{oban_job.args["recipient_name"]} has been sent to #{oban_job.args["recipient_email"]} successfully."
          )
          |> assign(:form, to_form(changeset))

        {:noreply, socket}

      {:ok, %Oban.Job{conflict?: true} = oban_job} ->
        changeset = Invitations.change_invitation(%Invite{}, %{message: params["message"]})

        socket =
          socket
          |> clear_flash(:warning)
          |> clear_flash(:success)
          |> clear_flash(:error)
          |> put_flash(
            :warning,
            "Your invitation to #{params["recipient_name"]} was not sent to #{oban_job.args["recipient_email"]} because you have already sent them an email. You can send them a reminder email in 3 hours or try another email address."
          )
          |> assign(:form, to_form(changeset))

        {:noreply, socket}

      {:error, _oban_job} ->
        socket =
          socket
          |> clear_flash(:warning)
          |> clear_flash(:success)
          |> clear_flash(:error)
          |> put_flash(
            :error,
            "There was an error sending your email. Please try again or conact us at support@mosslet.com."
          )

        {:noreply, socket}
    end
  end

  defp save_invite_new_user_job(params) do
    params
    |> Mosslet.Workers.InviteNewUserWorker.new()
    |> Oban.insert()
  end
end
