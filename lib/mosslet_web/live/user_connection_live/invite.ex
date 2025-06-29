defmodule MossletWeb.UserConnectionLive.Invite do
  use MossletWeb, :live_view

  alias Mosslet.Invitations
  alias Mosslet.Invitations.Invite

  def render(assigns) do
    ~H"""
    <.layout current_page={:connections} current_user={@current_user} key={@key} type="sidebar">
      <.page_header title="Invitations" class="pt-4 mx-4 sm:mx-6 max-w-prose"></.page_header>

      <div class="flex-1 items-center mx-4 sm:mx-6 max-w-prose">
        <div class="bg-white dark:bg-gray-950 shadow dark:shadow-emerald-500/50 sm:rounded-lg">
          <div class="flex justify-between items-center align-middle px-4 py-5 sm:px-6">
            <div class="flex flex-col">
              <h2
                id="invite-connection-title"
                class="text-lg/6 font-medium text-gray-900 dark:text-gray-100"
              >
                Join me on Mosslet!
              </h2>
              <.p class="pt-4">
                Fill out the form below to send a new invitation. The person you invite will receive an email to their inbox inviting them to join you on Mosslet.
              </.p>
              <.p class="pt-4">
                Curious to see how it works? Try sending one to yourself.
              </.p>
            </div>
          </div>

          <div class="border-t border-gray-200 dark:border-gray-700 px-4 py-5 sm:px-6">
            <div class="pb-4"></div>
            <.form for={@form} id="new-invite-form" phx-change="validate" phx-submit="send_invite">
              <.field
                field={@form[:current_user_name]}
                type="hidden"
                value={decr(@current_user.name, @current_user, @key)}
              />
              <.field
                field={@form[:current_user_email]}
                type="hidden"
                value={decr(@current_user.email, @current_user, @key)}
              />
              <.field
                field={@form[:current_user_username]}
                type="hidden"
                value={decr(@current_user.username, @current_user, @key)}
              />
              <.field
                field={@form[:recipient_name]}
                required={true}
                label="Name"
                phx-debounce="500"
                autocomplete="off"
              />
              <.field
                field={@form[:recipient_email]}
                required={true}
                label="Email"
                phx-debounce="500"
                autocomplete="off"
              />
              <.field
                field={@form[:message]}
                type="textarea"
                required={false}
                phx-debounce="500"
                label="Message (optional)"
              />

              <div class="flex justify-end">
                <.button :if={@form.source.valid?} class="rounded-full" phx-disable-with="Sending...">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="size-5 mr-1"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M6 12 3.269 3.125A59.769 59.769 0 0 1 21.485 12 59.768 59.768 0 0 1 3.27 20.875L5.999 12Zm0 0h7.5"
                    />
                  </svg>
                  Send
                </.button>
                <.button :if={!@form.source.valid?} disabled class="opacity-25 rounded-full">
                  Waiting...
                </.button>
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
