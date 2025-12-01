defmodule MossletWeb.UserConnectionLive.Invite do
  use MossletWeb, :live_view

  alias Mosslet.Invitations
  alias Mosslet.Invitations.Invite
  alias MossletWeb.DesignSystem

  def render(assigns) do
    ~H"""
    <.layout current_page={:new_invite} current_user={@current_user} key={@key} type="sidebar">
      <DesignSystem.liquid_container max_width="lg" class="py-8 sm:py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-8 sm:mb-12 max-w-3xl">
          <div class="mb-6 sm:mb-8">
            <h1 class="text-2xl sm:text-3xl font-bold tracking-tight lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Join me on MOSSLET!
            </h1>
            <p class="mt-3 sm:mt-4 text-base sm:text-lg text-slate-600 dark:text-slate-400 leading-relaxed">
              Fill out the form below to send a new invitation. The person you invite will receive an email to their inbox inviting them to join you on MOSSLET.
            </p>
            <p class="mt-2 text-sm sm:text-base text-slate-600 dark:text-slate-400 leading-relaxed">
              Curious to see how it works? Try sending one to yourself.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-16 sm:w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-3xl">
          <%!-- Invitation Form Card --%>
          <DesignSystem.liquid_card heading_level={2}>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/30 dark:via-emerald-900/25 dark:to-cyan-900/30">
                  <.phx_icon
                    name="hero-paper-airplane"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                </div>
                <span>Send Invitation</span>
              </div>
            </:title>

            <.form for={@form} id="new-invite-form" phx-change="validate" phx-submit="send_invite">
              <%!-- Hidden fields --%>
              <DesignSystem.liquid_input
                field={@form[:current_user_name]}
                type="hidden"
                value={decr(@current_user.name, @current_user, @key)}
              />
              <DesignSystem.liquid_input
                field={@form[:current_user_email]}
                type="hidden"
                value={decr(@current_user.email, @current_user, @key)}
              />
              <DesignSystem.liquid_input
                field={@form[:current_user_username]}
                type="hidden"
                value={decr(@current_user.username, @current_user, @key)}
              />

              <div class="space-y-6">
                <%!-- Recipient Name --%>
                <DesignSystem.liquid_input
                  field={@form[:recipient_name]}
                  type="text"
                  label="Name"
                  placeholder="Enter the recipient's full name"
                  required
                  help="The name of the person you'd like to invite to MOSSLET"
                />

                <%!-- Recipient Email --%>
                <DesignSystem.liquid_input
                  field={@form[:recipient_email]}
                  type="email"
                  label="Email"
                  placeholder="Enter their email address"
                  required
                  help="We'll send the invitation to this email address"
                />

                <%!-- Optional Message --%>
                <DesignSystem.liquid_textarea
                  field={@form[:message]}
                  label="Personal Message (optional)"
                  placeholder="Add a personal note to your invitation..."
                  rows={4}
                  help="Include a personal message to make your invitation more meaningful"
                />
              </div>

              <%!-- Action Buttons --%>
              <div class="flex justify-end pt-6">
                <DesignSystem.liquid_button
                  :if={@form.source.valid?}
                  type="submit"
                  phx-disable-with="Sending..."
                  icon="hero-paper-airplane"
                  color="teal"
                >
                  Send Invitation
                </DesignSystem.liquid_button>

                <DesignSystem.liquid_button
                  :if={!@form.source.valid?}
                  type="button"
                  disabled
                  icon="hero-clock"
                  color="slate"
                  variant="secondary"
                >
                  Complete Form
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <%!-- Help Card --%>
          <DesignSystem.liquid_card class="border-blue-200 dark:border-blue-700 bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-information-circle"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">💡 How Invitations Work</span>
              </div>
            </:title>

            <div class="space-y-4 text-blue-700 dark:text-blue-300">
              <p class="text-sm leading-relaxed">
                When you send an invitation, your friend will receive an email with step-by-step instructions on how to join MOSSLET and connect with you. If you include an optional message, they'll see your personalized note too.
              </p>
              <p class="text-sm leading-relaxed">
                The invitation includes your account details (email & username) so they can easily find you once they join. You can send one invitation per person every 3 hours to keep things spam-free.
              </p>
              <p class="text-sm leading-relaxed">
                Email not received? Check the spam folder or try a different email address.
              </p>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
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
