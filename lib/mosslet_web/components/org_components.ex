defmodule MossletWeb.OrgComponents do
  @moduledoc """
  Shared UI components used by BOTH the Family and Business org dashboards, so
  the two plans stay in sync (no feature gaps between them).

  See `docs/BUSINESS_CIRCLES_DESIGN.md` and the Family/guardianship docs.
  """
  use Phoenix.Component

  import MossletWeb.CoreComponents, only: [phx_icon: 1]

  alias Mosslet.Orgs

  @doc """
  Renders the pending org invitations with Revoke / Resend actions.

  A pending invitation is just a row in `orgs_invitations` (deleted on
  accept/reject), so this list reflects outstanding invites. The recipient
  email (`sent_to`) is decrypted server-side for display to org admins — it is
  Cloak-encrypted at rest, NOT user-key sealed, so showing it to the inviting
  admin is correct and carries no secret material.

  Only rendered when the viewer can manage the org (`can_manage`).
  """
  attr :invitations, :list, required: true
  attr :can_manage, :boolean, required: true

  def pending_invitations_panel(assigns) do
    ~H"""
    <div
      :if={@can_manage && @invitations != []}
      id="pending-invitations"
      class="pt-2 border-t border-slate-100 dark:border-slate-700/60 space-y-3"
    >
      <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
        Pending invitations
      </h3>
      <ul role="list" class="space-y-2">
        <li
          :for={invitation <- @invitations}
          id={"invitation-#{invitation.id}"}
          class="flex items-center justify-between gap-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 px-3 py-2"
        >
          <div class="flex items-center gap-2.5 min-w-0">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-300">
              <.phx_icon name="hero-envelope" class="size-4" />
            </div>
            <div class="min-w-0">
              <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                {invitation.sent_to}
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                <%= cond do %>
                  <% Orgs.invite_link_expired?(invitation) -> %>
                    <span class="inline-flex items-center gap-1 text-amber-600 dark:text-amber-400 font-medium">
                      <.phx_icon name="hero-clock" class="size-3.5" />
                      Link expired — resend to send a fresh one
                    </span>
                  <% invitation.user_id -> %>
                    Has a MOSSLET account — awaiting acceptance
                  <% true -> %>
                    Awaiting sign-up &amp; acceptance
                <% end %>
              </p>
            </div>
          </div>

          <div class="flex items-center gap-3 flex-shrink-0">
            <button
              type="button"
              phx-click="resend_invitation"
              phx-value-id={invitation.id}
              id={"resend-invitation-#{invitation.id}"}
              class={[
                "text-xs font-medium transition-colors",
                if(Orgs.invite_link_expired?(invitation),
                  do:
                    "inline-flex items-center gap-1 rounded-lg bg-amber-100 dark:bg-amber-900/40 px-2 py-1 text-amber-700 dark:text-amber-300 hover:bg-amber-200 dark:hover:bg-amber-900/60",
                  else:
                    "text-teal-600 hover:text-teal-700 dark:text-teal-400 dark:hover:text-teal-300"
                )
              ]}
            >
              Resend
            </button>
            <button
              type="button"
              phx-click="revoke_invitation"
              phx-value-id={invitation.id}
              id={"revoke-invitation-#{invitation.id}"}
              data-confirm={"Revoke the invitation to #{invitation.sent_to}? They won't be able to accept it."}
              class="text-xs font-medium text-rose-500 hover:text-rose-600"
            >
              Revoke
            </button>
          </div>
        </li>
      </ul>
    </div>
    """
  end
end
