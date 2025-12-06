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
      current_user={@current_user}
      key={@key}
    >
      <%= if @current_user.confirmed_at do %>
        <%= if Util.blank?(@invitations) do %>
          <.p>
            {gettext("You have no pending invitations.")}
          </.p>
        <% else %>
          <div class="grid grid-cols-1 mt-6 md:grid-cols-2 xl:grid-cols-3">
            <%= for invitation <- @invitations do %>
              <.box padded id={"invitation-#{invitation.id}"}>
                <div>
                  <div class="flex items-center justify-center w-12 h-12 mx-auto bg-blue-100 rounded-full">
                    <.icon name={:envelope} class="w-6 h-6 text-emerald-600" />
                  </div>
                  <div class="mt-3 text-center sm:mt-5">
                    <div class="text-lg font-medium leading-6 text-gray-900 dark:text-white">
                      {gettext("Invitation")}
                    </div>
                    <div class="mt-2">
                      <div class="text-sm text-gray-500 dark:text-gray-400">
                        {gettext("You have been invited to join %{org_name}",
                          org_name: invitation.org.name
                        )}.
                      </div>
                    </div>
                  </div>
                </div>
                <div class="mt-5 sm:mt-6">
                  <div class="mt-5 sm:mt-6 sm:grid sm:grid-cols-2 sm:gap-3 sm:grid-flow-row-dense">
                    <.button
                      phx-click="reject_invitation"
                      phx-value-id={invitation.id}
                      label={gettext("Reject")}
                      data-confirm={gettext("Are you sure you want to reject this invitation?")}
                      color="white"
                    />

                    <.button
                      phx-click="accept_invitation"
                      phx-value-id={invitation.id}
                      label={gettext("Accept")}
                      color="primary"
                    />
                  </div>
                </div>
              </.box>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <.alert color="warning" class="my-5" heading={gettext("Unconfirmed account")}>
          {gettext(
            "You may have pending invitations. To see them please confirm your account by clicking the link in the e-mail we sent you. If you didn't receive an e-mail,"
          )}
          <a href="#" phx-click="confirmation_resend" class="underline">
            {gettext("click here to resend it")}.
          </a>
        </.alert>
      <% end %>
    </.settings_layout>
    """
  end

  @impl true
  def handle_event("accept_invitation", %{"id" => id}, socket) do
    membership = Orgs.accept_invitation!(socket.assigns.current_user, id)

    Mosslet.Logs.log("orgs.accept_invitation", %{
      user: socket.assigns.current_user,
      org_id: membership.org_id,
      metadata: %{
        membership_id: membership.id
      }
    })

    {:noreply,
     socket
     |> put_flash(:success, gettext("Invitation was accepted"))
     |> assign_invitations()}
  end

  @impl true
  def handle_event("reject_invitation", %{"id" => id}, socket) do
    invitation = Orgs.reject_invitation!(socket.assigns.current_user, id)

    Mosslet.Logs.log("orgs.reject_invitation", %{
      user: socket.assigns.current_user,
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
    key = socket.assigns.key
    current_user = socket.assigns.current_user

    d_email =
      Mosslet.Encrypted.Users.Utils.decrypt_user_data(current_user.email, current_user, key)

    Accounts.deliver_user_confirmation_instructions(
      socket.assigns.current_user,
      d_email,
      &url(~p"/app/users/settings/confirm-email/#{&1}")
    )

    {:noreply,
     put_flash(socket, :info, gettext("You will receive an e-mail with instructions shortly."))}
  end

  defp assign_invitations(socket) do
    invitations = Orgs.list_invitations_by_user(socket.assigns.current_user)

    assign(socket, :invitations, invitations)
  end
end
