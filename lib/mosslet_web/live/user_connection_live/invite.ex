defmodule MossletWeb.UserConnectionLive.Invite do
  use MossletWeb, :live_view

  alias Mosslet.Invitations
  alias Mosslet.Invitations.Invite
  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Subscriptions
  alias MossletWeb.DesignSystem

  def render(assigns) do
    ~H"""
    <.layout current_page={:new_invite} current_scope={@current_scope} type="sidebar">
      <DesignSystem.liquid_container max_width="lg" class="py-8 sm:py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-8 sm:mb-12 max-w-3xl">
          <div class="mb-6 sm:mb-8">
            <h1 class="text-2xl sm:text-3xl font-bold tracking-tight lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Invite a Friend to MOSSLET
            </h1>
            <p class="mt-3 sm:mt-4 text-base sm:text-lg text-slate-600 dark:text-slate-400 leading-relaxed">
              Share MOSSLET with someone you care about. They'll receive a personalized email invitation to join you.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-16 sm:w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-3xl">
          <%!-- Privacy & Security Notice --%>
          <DesignSystem.liquid_card class="border-amber-200 dark:border-amber-700/50 bg-gradient-to-br from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-amber-600 dark:text-amber-400"
                  />
                </div>
                <span class="text-amber-800 dark:text-amber-200">Privacy & Email Security</span>
              </div>
            </:title>

            <div class="space-y-4 text-amber-700 dark:text-amber-300 text-sm">
              <p class="leading-relaxed">
                <strong>What your friend will see in the invitation email:</strong>
              </p>
              <ul class="space-y-1.5 ml-4">
                <li class="flex items-start gap-2">
                  <.phx_icon name="hero-check-circle" class="h-4 w-4 mt-0.5 text-amber-500 shrink-0" />
                  <span>
                    <strong>Your name</strong>
                    and <strong>username</strong>
                    (so they know who's inviting them)
                  </span>
                </li>
                <li class="flex items-start gap-2">
                  <.phx_icon name="hero-check-circle" class="h-4 w-4 mt-0.5 text-amber-500 shrink-0" />
                  <span><strong>Their name</strong> (the name you provide below)</span>
                </li>
                <li class="flex items-start gap-2">
                  <.phx_icon name="hero-check-circle" class="h-4 w-4 mt-0.5 text-amber-500 shrink-0" />
                  <span><strong>Your personal message</strong> (if you add one)</span>
                </li>
              </ul>
              <div class="pt-2 border-t border-amber-200 dark:border-amber-700/50">
                <p class="leading-relaxed">
                  <.phx_icon name="hero-lock-closed" class="h-4 w-4 inline-block mr-1 text-amber-500" />
                  <strong>Your account email is NOT shared</strong>
                  in the invitation – only your username is visible. We take your privacy seriously.
                </p>
              </div>
              <div class="pt-2">
                <p class="leading-relaxed text-xs text-amber-600 dark:text-amber-400">
                  <.phx_icon name="hero-shield-exclamation" class="h-3.5 w-3.5 inline-block mr-1" />
                  This email is sent outside of MOSSLET to your friend's email provider. We use TLS encryption for all email transit to protect your data in motion.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>

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
                value={decr(@current_scope.user.name, @current_scope.user, @current_scope.key)}
              />
              <DesignSystem.liquid_input
                field={@form[:current_user_username]}
                type="hidden"
                value={decr(@current_scope.user.username, @current_scope.user, @current_scope.key)}
              />
              <DesignSystem.liquid_input
                :if={@referral_code}
                field={@form[:referral_code]}
                type="hidden"
                value={@referral_code}
              />

              <div class="space-y-6">
                <%!-- Recipient Name --%>
                <DesignSystem.liquid_input
                  field={@form[:recipient_name]}
                  type="text"
                  label="Friend's Name"
                  placeholder="Enter your friend's name"
                  required
                  help="This name will appear in the invitation email"
                />

                <%!-- Recipient Email --%>
                <DesignSystem.liquid_input
                  field={@form[:recipient_email]}
                  type="email"
                  label="Friend's Email"
                  placeholder="Enter their email address"
                  required
                  help="The invitation will be sent to this email address"
                />

                <%!-- Optional Message --%>
                <DesignSystem.liquid_textarea
                  field={@form[:message]}
                  label="Personal Message (optional)"
                  placeholder="Add a personal note to make your invitation more meaningful..."
                  rows={4}
                  help="This message will be displayed in the invitation email"
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

          <%!-- Referral Badge (if user has active referral code) --%>
          <DesignSystem.liquid_card
            :if={@referral_code}
            class="border-purple-200 dark:border-purple-700/50 bg-gradient-to-br from-purple-50/50 to-indigo-50/30 dark:from-purple-900/20 dark:to-indigo-900/10"
          >
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-indigo-50 to-purple-100 dark:from-purple-900/30 dark:via-indigo-900/25 dark:to-purple-900/30">
                  <.phx_icon
                    name="hero-gift"
                    class="h-4 w-4 text-purple-600 dark:text-purple-400"
                  />
                </div>
                <span class="text-purple-800 dark:text-purple-200">🎁 Referral Bonus Active</span>
              </div>
            </:title>

            <div class="space-y-3 text-purple-700 dark:text-purple-300 text-sm">
              <p class="leading-relaxed">
                Your referral code is active! When your friend signs up using your invitation link:
              </p>
              <ul class="space-y-1.5 ml-4">
                <li class="flex items-start gap-2">
                  <.phx_icon name="hero-sparkles" class="h-4 w-4 mt-0.5 text-purple-500 shrink-0" />
                  <span>They'll get a <strong>special discount</strong> on their purchase</span>
                </li>
                <li class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-currency-dollar"
                    class="h-4 w-4 mt-0.5 text-purple-500 shrink-0"
                  />
                  <span>You'll earn a <strong>referral commission</strong> when they subscribe</span>
                </li>
              </ul>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Free Trial Notice (if user is in free trial without referral code) --%>
          <DesignSystem.liquid_card
            :if={!@referral_code && @in_free_trial}
            class="border-violet-200 dark:border-violet-700/50 bg-gradient-to-br from-violet-50/50 to-purple-50/30 dark:from-violet-900/20 dark:to-purple-900/10"
          >
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-violet-100 via-purple-50 to-violet-100 dark:from-violet-900/30 dark:via-purple-900/25 dark:to-violet-900/30">
                  <.phx_icon
                    name="hero-sparkles"
                    class="h-4 w-4 text-violet-600 dark:text-violet-400"
                  />
                </div>
                <span class="text-violet-800 dark:text-violet-200">🎁 Referral Program</span>
              </div>
            </:title>

            <div class="space-y-3 text-violet-700 dark:text-violet-300 text-sm">
              <p class="leading-relaxed">
                You're currently on a <strong>free trial</strong>. Once your trial ends and you become a paid member, you'll get your own referral code!
              </p>
              <ul class="space-y-1.5 ml-4">
                <li class="flex items-start gap-2">
                  <.phx_icon name="hero-gift" class="h-4 w-4 mt-0.5 text-violet-500 shrink-0" />
                  <span>
                    Your referrals will get a <strong>special discount</strong> on their purchase
                  </span>
                </li>
                <li class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-currency-dollar"
                    class="h-4 w-4 mt-0.5 text-violet-500 shrink-0"
                  />
                  <span>
                    You'll earn a <strong>lifetime commission</strong> on every purchase they make
                  </span>
                </li>
                <li class="flex items-start gap-2">
                  <.phx_icon name="hero-arrow-path" class="h-4 w-4 mt-0.5 text-violet-500 shrink-0" />
                  <span>We share revenue with you for as long as they're a member</span>
                </li>
              </ul>
              <p class="leading-relaxed pt-2 text-violet-600 dark:text-violet-400">
                <.phx_icon name="hero-clock" class="h-4 w-4 inline-block mr-1" />
                Complete your subscription to unlock your referral code and start earning!
              </p>
            </div>
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
                When you send an invitation, your friend will receive an email with step-by-step instructions on how to join MOSSLET and connect with you. Your username will be included so they can easily find you once they join.
              </p>
              <p class="text-sm leading-relaxed">
                You can send one invitation per email address every 3 hours to keep things spam-free. If they don't receive the email, ask them to check their spam folder.
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
    user = socket.assigns.current_scope.user
    session_key = socket.assigns.current_scope.key

    referral_code = get_active_referral_code(user, session_key)
    in_free_trial = user_in_free_trial?(user)

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:referral_code, referral_code)
     |> assign(:in_free_trial, in_free_trial)}
  end

  defp get_active_referral_code(user, session_key) do
    case Referrals.get_referral_code_by_user(user.id) do
      %{is_active: true} = code ->
        decr(code.code, user, session_key)

      _ ->
        nil
    end
  end

  defp user_in_free_trial?(user) do
    case user do
      %{customer: %{id: customer_id}} when not is_nil(customer_id) ->
        case Subscriptions.get_active_subscription_by_customer_id(customer_id) do
          %{status: "trialing"} -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  def handle_params(params, _url, socket) do
    live_action = socket.assigns.live_action

    {:noreply, apply_action(socket, live_action, params)}
  end

  def apply_action(socket, :new_invite, _params) do
    socket
    |> assign(:page_title, "Invite a Friend")
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
