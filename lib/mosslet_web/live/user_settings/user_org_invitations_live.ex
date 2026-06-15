defmodule MossletWeb.UserOrgInvitationsLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts
  alias Mosslet.Orgs

  @impl true
  def mount(_params, _session, socket) do
    socket = assign_invitations(socket)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_layout
      current_page={:org_invitations}
      sidebar_current_page={:settings}
      current_scope={@current_scope}
    >
      <%= if @current_user.confirmed_at do %>
        <%= if Util.blank?(@invitations) do %>
          <div class="mt-6 rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/80 dark:bg-slate-800/80 p-8 text-center">
            <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-700 text-slate-400 dark:text-slate-300">
              <.phx_icon name="hero-envelope-open" class="h-6 w-6" />
            </div>
            <p class="mt-3 text-sm text-slate-600 dark:text-slate-300">
              {gettext("You have no pending invitations.")}
            </p>
            <p class="mt-1 text-xs text-slate-400 dark:text-slate-500">
              {gettext("When someone invites you to a family or team, it'll show up here.")}
            </p>
          </div>
        <% else %>
          <div class="mt-6 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
            <%= for invitation <- @invitations do %>
              <div
                id={"invitation-#{invitation.id}"}
                class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm shadow-sm p-6 flex flex-col"
              >
                <div class="flex items-center gap-2 self-center mb-4 px-3 py-1.5 rounded-full bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/50 dark:border-emerald-700/30">
                  <.phx_icon
                    name={
                      if invitation.org.type == :family,
                        do: "hero-home",
                        else: "hero-building-office-2"
                    }
                    class="w-4 h-4 text-emerald-600 dark:text-emerald-400"
                  />
                  <span class="text-xs font-medium text-emerald-700 dark:text-emerald-300">
                    {if invitation.org.type == :family,
                      do: gettext("Family invitation"),
                      else: gettext("Team invitation")}
                  </span>
                </div>

                <div class="text-center flex-1">
                  <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                    {invitation.org.name}
                  </h3>
                  <p class="mt-1.5 text-sm text-slate-500 dark:text-slate-400">
                    {if invitation.org.type == :family,
                      do: gettext("You've been invited to join this family on MOSSLET."),
                      else: gettext("You've been invited to join this team on MOSSLET.")}
                  </p>
                </div>

                <div class="mt-6 grid grid-cols-2 gap-3">
                  <.phx_button
                    variant="secondary"
                    phx-click="reject_invitation"
                    phx-value-id={invitation.id}
                    data-confirm={gettext("Are you sure you want to decline this invitation?")}
                  >
                    {gettext("Decline")}
                  </.phx_button>

                  <.phx_button phx-click="accept_invitation" phx-value-id={invitation.id}>
                    {gettext("Accept")}
                  </.phx_button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <div
          class="my-5 rounded-lg border border-amber-300 bg-amber-50 dark:border-amber-700 dark:bg-amber-950/40 p-4 text-amber-800 dark:text-amber-200"
          role="alert"
        >
          <p class="font-semibold">{gettext("Unconfirmed account")}</p>
          <p class="mt-1 text-sm">
            {gettext(
              "You may have pending invitations. To see them please confirm your account by clicking the link in the e-mail we sent you. If you didn't receive an e-mail,"
            )}
            <a href="#" phx-click="confirmation_resend" class="underline">
              {gettext("click here to resend it")}.
            </a>
          </p>
        </div>
      <% end %>
    </.settings_layout>
    """
  end

  @impl true
  def handle_event("accept_invitation", %{"id" => id}, socket) do
    membership = Orgs.accept_invitation!(socket.assigns.current_scope.user, id)

    Mosslet.Logs.log("orgs.accept_invitation", %{
      user: socket.assigns.current_scope.user,
      org_id: membership.org_id,
      metadata: %{
        membership_id: membership.id
      }
    })

    # Take the new member straight to the organization they just joined (not back
    # to the invitations list, which was confusing). Family vs Business dashboard
    # by org type. The membership has `:org` preloaded by `accept_invitation!`.
    {:noreply,
     socket
     |> put_flash(:success, gettext("Invitation accepted — welcome aboard!"))
     |> push_navigate(to: org_path(membership.org))}
  end

  @impl true
  def handle_event("reject_invitation", %{"id" => id}, socket) do
    invitation = Orgs.reject_invitation!(socket.assigns.current_scope.user, id)

    Mosslet.Logs.log("orgs.reject_invitation", %{
      user: socket.assigns.current_scope.user,
      org_id: invitation.org_id
    })

    {:noreply,
     socket
     |> put_flash(:info, gettext("Invitation was rejected"))
     |> assign_invitations()}
  end

  @impl true
  def handle_event("confirmation_resend", _, socket) do
    # we're resending to the current_user's email
    key = socket.assigns.current_scope.key
    current_user = socket.assigns.current_scope.user

    d_email =
      Mosslet.Encrypted.Users.Utils.decrypt_user_data(current_user.email, current_user, key)

    Accounts.deliver_user_confirmation_instructions(
      current_user,
      d_email,
      &url(~p"/app/users/settings/confirm-email/#{&1}")
    )

    {:noreply,
     put_flash(socket, :info, gettext("You will receive an e-mail with instructions shortly."))}
  end

  defp assign_invitations(socket) do
    invitations = Orgs.list_invitations_by_user(socket.assigns.current_scope.user)

    assign(socket, :invitations, invitations)
  end

  # Dashboard path for the org the member just joined, by type.
  defp org_path(%{type: :family, slug: slug}), do: ~p"/app/family/#{slug}"
  defp org_path(%{slug: slug}), do: ~p"/app/business/#{slug}"
end
