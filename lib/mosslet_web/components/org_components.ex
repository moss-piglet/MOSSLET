defmodule MossletWeb.OrgComponents do
  @moduledoc """
  Shared UI components used by BOTH the Family and Business org dashboards, so
  the two plans stay in sync (no feature gaps between them).

  See `docs/BUSINESS_CIRCLES_DESIGN.md` and the Family/guardianship docs.
  """
  use Phoenix.Component

  import MossletWeb.CoreComponents, only: [phx_icon: 1, phx_input: 1]

  alias MossletWeb.DesignSystem
  alias Mosslet.Orgs
  alias Phoenix.LiveView.JS

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

  @doc """
  Friendly loss-of-coverage notice shown on the Family/Business dashboards
  (Task #223). Org members occupy a seat the org pays for; when the org's plan
  goes overdue (Stripe `past_due`) the member keeps access during the grace
  window but should know to nudge their admin. This is the non-alarming,
  on-brand version of "your org plan needs attention" — never a scary lockout.

  Pass the result of `Mosslet.Orgs.org_coverage_status/1`:

    * `{:grace, org}` — renders an amber "plan is overdue, reach out to your
      admin" banner (access continues during the grace window).
    * anything else — renders nothing (covered members see a clean dashboard;
      fully-lapsed/removed members are handled by the paywall gate before they
      ever reach the dashboard).
  """
  attr :status, :any, required: true

  def org_coverage_notice(%{status: {:grace, _org}} = assigns) do
    ~H"""
    <div
      id="org-coverage-grace-notice"
      role="status"
      class="relative overflow-hidden rounded-2xl border border-amber-300/70 dark:border-amber-700/60 bg-gradient-to-br from-amber-50 to-orange-50 dark:from-amber-950/40 dark:to-orange-950/30 p-5 shadow-sm"
    >
      <div class="flex items-start gap-4">
        <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-amber-100 dark:bg-amber-900/40 text-amber-600 dark:text-amber-300">
          <.phx_icon name="hero-exclamation-triangle" class="size-5" />
        </div>
        <div class="min-w-0 space-y-1">
          <h3 class="text-sm font-semibold text-amber-900 dark:text-amber-200">
            {coverage_grace_title(@status)}
          </h3>
          <p class="text-sm leading-relaxed text-amber-800/90 dark:text-amber-200/80">
            Your access is uninterrupted for now. To keep
            <span class="font-medium">{coverage_org_name(@status)}</span>
            active, an organization admin can update the payment details from the
            organization's billing page. No action is needed from you — just a
            friendly heads-up so nothing lapses.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def org_coverage_notice(assigns), do: ~H""

  @doc """
  Owner-only Ownership / Danger-zone section + the two-step transfer handshake UI
  (Task #237). Shared VERBATIM by the Family and Business dashboards so the two
  plans stay in parity.

  Surfaces, in priority order:

    * To the proposed NEW owner (when a `:pending` transfer targets them): an
      Accept / Decline panel gated behind their own password (their `session_key`
      is then used to sync the org's Stripe customer email — ZK-safe).
    * To the current OWNER: either the pending state with a Cancel action, or the
      "Transfer ownership" affordance (opens a modal to pick an eligible member +
      confirm with their password). Single-member orgs are told they must invite
      someone first (transfer needs a recipient).

  Expects these assigns (provided by each LiveView):

    * `:org`, `:current_user`
    * `:is_owner` — `Orgs.owner?(org, current_user.id)`
    * `:members` — the roster maps from `OrgIdentity.build_members/4`
    * `:viewer_sealed_org_key` — drives the modal picker's ZK name decryption
    * `:pending_transfer` — `Orgs.get_pending_transfer_for_org/1` result or nil
    * `:transfer_modal_open` — boolean
    * `:transfer_form` — `to_form` for the transfer (password + to_user_id)
  """
  attr :org, :map, required: true
  attr :current_user, :map, required: true
  attr :is_owner, :boolean, required: true
  attr :members, :list, default: []
  attr :viewer_sealed_org_key, :string, default: nil
  attr :pending_transfer, :any, default: nil
  attr :transfer_modal_open, :boolean, default: false
  attr :transfer_form, :any, default: nil
  attr :member_count, :integer, default: 0
  attr :delete_modal_open, :boolean, default: false
  attr :delete_form, :any, default: nil

  def ownership_section(assigns) do
    assigns =
      assigns
      |> assign(:incoming_transfer, incoming_transfer(assigns))
      |> assign(:eligible_members, eligible_transfer_members(assigns))

    ~H"""
    <section
      :if={@is_owner || @incoming_transfer}
      id="org-ownership-section"
      class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
    >
      <div class="flex items-center justify-between gap-3">
        <div class="flex items-center gap-2 min-w-0">
          <.phx_icon name="hero-key" class="size-5 text-slate-400 dark:text-slate-500" />
          <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Ownership</h2>
        </div>

        <%!-- Rare, owner-only actions tucked into a calm dropdown so the dashboard
              stays focused on everyday operations (Task #227 UX). Transfer +
              delete live here; only shown when nothing time-sensitive is pending. --%>
        <DesignSystem.liquid_dropdown
          :if={@is_owner && !@incoming_transfer && !@pending_transfer}
          id="org-manage-menu"
          placement="bottom-end"
          class="z-50"
          menu_class="mr-1 w-56"
          trigger_class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
          trigger_aria_label="Manage organization"
        >
          <:trigger>
            <.phx_icon name="hero-cog-6-tooth" class="size-5" />
          </:trigger>
          <:item
            :if={@eligible_members != []}
            phx_click="open_transfer_modal"
            color="blue"
          >
            <.phx_icon name="hero-arrow-right-circle" class="size-4" /> Transfer ownership
          </:item>
          <:item phx_click="open_delete_org_modal" color="rose">
            <.phx_icon name="hero-trash" class="size-4" /> Delete organization
          </:item>
        </DesignSystem.liquid_dropdown>
      </div>

      <%!-- Proposed new owner: Accept / Decline (their own password). --%>
      <div
        :if={@incoming_transfer}
        id="incoming-transfer-panel"
        class="rounded-xl border border-emerald-200/70 dark:border-emerald-800/50 bg-emerald-50/60 dark:bg-emerald-900/20 p-4 space-y-3"
      >
        <p class="text-sm font-medium text-emerald-900 dark:text-emerald-200">
          You've been asked to take ownership of {@org.name}.
        </p>
        <p class="text-xs text-emerald-800/80 dark:text-emerald-300/80">
          Accepting makes you the owner and an admin, and moves the organization's billing to your
          account. Confirm with your password to accept.
        </p>

        <.form
          for={@transfer_form}
          id="accept-transfer-form"
          phx-submit="accept_transfer"
          class="space-y-3"
        >
          <input type="hidden" name="transfer_id" value={@incoming_transfer.id} />
          <.phx_input
            field={@transfer_form[:password]}
            type="password"
            label="Your password"
            placeholder="Confirm your password"
            phx-debounce="300"
          />
          <div class="flex flex-col sm:flex-row gap-2">
            <DesignSystem.liquid_button
              type="submit"
              id="accept-transfer-submit"
              color="emerald"
              icon="hero-check"
            >
              Accept ownership
            </DesignSystem.liquid_button>
            <DesignSystem.liquid_button
              type="button"
              id="decline-transfer-submit"
              color="slate"
              variant="ghost"
              phx-click="decline_transfer"
              phx-value-transfer_id={@incoming_transfer.id}
              data-confirm="Decline this ownership transfer?"
            >
              Decline
            </DesignSystem.liquid_button>
          </div>
        </.form>
      </div>

      <%!-- Owner view --%>
      <div :if={@is_owner && !@incoming_transfer} class="space-y-3">
        <div
          :if={@pending_transfer}
          id="pending-transfer-owner-notice"
          class="rounded-xl border border-amber-200/70 dark:border-amber-800/50 bg-amber-50/60 dark:bg-amber-900/20 p-4 space-y-3"
        >
          <p class="text-sm text-amber-900 dark:text-amber-200">
            An ownership transfer is pending. It will complete once the other member accepts.
          </p>
          <DesignSystem.liquid_button
            type="button"
            id="cancel-transfer-submit"
            color="amber"
            variant="ghost"
            icon="hero-x-mark"
            phx-click="cancel_transfer"
            phx-value-transfer_id={@pending_transfer.id}
            data-confirm="Cancel the pending ownership transfer?"
          >
            Cancel transfer
          </DesignSystem.liquid_button>
        </div>

        <%!-- Calm default state: a one-line summary. The rare transfer/delete
              actions live in the "Manage organization" menu above. --%>
        <div :if={!@pending_transfer} id="org-danger-zone" class="space-y-2">
          <p class="text-sm text-slate-600 dark:text-slate-300">
            You own this organization. Use the
            <span class="font-medium text-slate-700 dark:text-slate-200">manage menu</span>
            <.phx_icon name="hero-cog-6-tooth" class="inline size-3.5 -mt-0.5 text-slate-400" />
            gear icon to transfer ownership or delete completely.
          </p>

          <p
            :if={@eligible_members == []}
            id="ownership-no-members-notice"
            class="rounded-lg bg-slate-100 dark:bg-slate-700/60 px-3 py-2 text-xs text-slate-600 dark:text-slate-300"
          >
            Invite another member before you can transfer ownership — a transfer needs someone to
            hand it to.
          </p>
        </div>
      </div>

      <%!-- Delete confirmation modal: password + typed org-name (Task #227). --%>
      <DesignSystem.liquid_modal
        :if={@delete_modal_open}
        id="delete-org-modal"
        show={@delete_modal_open}
        on_cancel={JS.push("close_delete_org_modal")}
      >
        <:title>Delete {@org.name}?</:title>

        <div id="delete-org-modal-body" class="space-y-4">
          <div class="rounded-xl border border-rose-200/70 dark:border-rose-800/50 bg-rose-50/60 dark:bg-rose-900/20 p-4 space-y-2">
            <p class="text-sm font-medium text-rose-900 dark:text-rose-200">
              This permanently and immediately:
            </p>
            <ul class="space-y-1.5 text-xs text-rose-800/90 dark:text-rose-300/90">
              <li class="flex items-start gap-2">
                <.phx_icon name="hero-x-mark" class="size-3.5 mt-0.5 shrink-0 text-rose-500" />
                <span>Deletes every business circle and its end-to-end encrypted files</span>
              </li>
              <li class="flex items-start gap-2">
                <.phx_icon name="hero-x-mark" class="size-3.5 mt-0.5 shrink-0 text-rose-500" />
                <span>Cancels this organization's plan right now (no period-end grace)</span>
              </li>
              <li class="flex items-start gap-2">
                <.phx_icon name="hero-x-mark" class="size-3.5 mt-0.5 shrink-0 text-rose-500" />
                <span>Removes all invitations and every member's organization membership</span>
              </li>
            </ul>
            <p class="text-xs text-rose-800/90 dark:text-rose-300/90">
              <span class="font-medium">Members are safe:</span>
              everyone keeps their personal MOSSLET account and personal billing — only their
              membership in {@org.name} is removed.
            </p>
          </div>

          <p :if={@eligible_members != []} class="text-xs text-slate-600 dark:text-slate-300">
            Not sure?
            <button
              type="button"
              id="delete-org-transfer-instead"
              phx-click="open_transfer_modal"
              class="font-medium text-emerald-600 dark:text-emerald-400 underline underline-offset-2 hover:text-emerald-700 dark:hover:text-emerald-300 transition-colors"
            >
              Transfer ownership instead
            </button>
            — it keeps everything and just hands the organization to another member.
          </p>

          <.form
            for={@delete_form}
            id="delete-org-form"
            phx-submit="delete_org"
            class="space-y-4"
          >
            <div class="space-y-1.5">
              <label
                for="delete-org-confirm-name"
                class="block text-sm font-medium text-slate-900 dark:text-slate-100"
              >
                Type the organization name to confirm
              </label>
              <input
                type="text"
                id="delete-org-confirm-name"
                name="confirm_name"
                autocomplete="off"
                placeholder={@org.name}
                phx-debounce="200"
                class="block w-full rounded-xl border-2 border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 px-4 py-2.5 text-sm text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:border-rose-500 dark:focus:border-rose-400 focus:outline-none focus:ring-0 transition-colors"
              />
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Enter
                <span class="font-semibold text-slate-700 dark:text-slate-200">{@org.name}</span>
                exactly.
              </p>
            </div>

            <.phx_input
              field={@delete_form[:password]}
              type="password"
              label="Your password"
              placeholder="Confirm your password"
              phx-debounce="300"
            />

            <div class="flex flex-col sm:flex-row gap-2 justify-end">
              <DesignSystem.liquid_button
                type="button"
                id="delete-org-cancel"
                color="slate"
                variant="ghost"
                phx-click="close_delete_org_modal"
              >
                Keep organization
              </DesignSystem.liquid_button>
              <DesignSystem.liquid_button
                type="submit"
                id="delete-org-submit"
                color="rose"
                icon="hero-trash"
                phx-disable-with="Deleting…"
              >
                Delete this organization
              </DesignSystem.liquid_button>
            </div>
          </.form>
        </div>
      </DesignSystem.liquid_modal>

      <%!-- Transfer modal: pick an eligible member + confirm with password. --%>
      <DesignSystem.liquid_modal
        :if={@transfer_modal_open}
        id="transfer-ownership-modal"
        show={@transfer_modal_open}
        on_cancel={JS.push("close_transfer_modal")}
      >
        <:title>Transfer ownership</:title>

        <.form
          for={@transfer_form}
          id="transfer-ownership-form"
          phx-submit="initiate_transfer"
          class="space-y-4"
        >
          <fieldset
            id="transfer-member-picker"
            phx-hook="OrgMembers"
            data-sealed-org-key={@viewer_sealed_org_key}
            data-current-user-id={@current_user.id}
            class="space-y-1 max-h-64 overflow-y-auto"
          >
            <legend class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-1">
              Choose the new owner
            </legend>
            <label
              :for={member <- @eligible_members}
              data-org-member-row
              data-encrypted-display-name={member.encrypted_display_name}
              id={"transfer-option-#{member.user.id}"}
              class="flex items-center gap-3 rounded-lg px-3 py-2 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700/40"
            >
              <input
                type="radio"
                name="to_user_id"
                value={member.user.id}
                class="text-emerald-600 focus:ring-emerald-500/30"
              />
              <span
                class="text-sm text-slate-700 dark:text-slate-200"
                {MossletWeb.OrgIdentity.org_name_target(member)}
              >
                {MossletWeb.OrgIdentity.placeholder_label(member)}
              </span>
            </label>
          </fieldset>

          <.phx_input
            field={@transfer_form[:password]}
            type="password"
            label="Your password"
            placeholder="Confirm your password"
            phx-debounce="300"
          />

          <div class="flex flex-col sm:flex-row gap-2 justify-end">
            <DesignSystem.liquid_button
              type="button"
              id="transfer-modal-cancel"
              color="slate"
              variant="ghost"
              phx-click="close_transfer_modal"
            >
              Cancel
            </DesignSystem.liquid_button>
            <DesignSystem.liquid_button
              type="submit"
              id="initiate-transfer-submit"
              color="emerald"
              icon="hero-paper-airplane"
            >
              Send transfer request
            </DesignSystem.liquid_button>
          </div>
        </.form>
      </DesignSystem.liquid_modal>
    </section>
    """
  end

  # The pending transfer if it targets the current viewer (they can accept it).
  defp incoming_transfer(%{
         pending_transfer: %{to_user_id: to_id} = transfer,
         current_user: %{id: id}
       })
       when to_id == id,
       do: transfer

  defp incoming_transfer(_assigns), do: nil

  # Roster members eligible to receive ownership: confirmed members who are not
  # the current owner (the viewer). The owner can't transfer to themselves.
  defp eligible_transfer_members(%{members: members, current_user: %{id: id}})
       when is_list(members) do
    Enum.reject(members, &(&1.user.id == id))
  end

  defp eligible_transfer_members(_assigns), do: []

  defp coverage_grace_title({:grace, %{name: name}}) when is_binary(name) and name != "",
    do: "#{name}'s plan needs attention"

  defp coverage_grace_title(_), do: "Your organization's plan needs attention"

  defp coverage_org_name({:grace, %{name: name}}) when is_binary(name) and name != "", do: name
  defp coverage_org_name(_), do: "your organization"

  @doc """
  Renders an org's brand logo (Task #228) wherever the generic org/building icon
  would otherwise appear (dashboard header, business list cards, branding
  preview). Zero-knowledge: the logo blob is encrypted with the per-org
  `org_key`, so we hand the browser a short-lived presigned GET URL + the
  viewer's sealed org_key and the `OrgLogoDisplay` hook fetches + decrypts it.

  Loading/error states (so there's never an ugly broken-image flash):

    * No logo / no presigned URL / viewer lacks the org_key — renders the
      `:fallback` slot (the building icon) immediately.
    * Logo present but still decrypting — renders a spinner; the `<img>` is
      hidden (`data-state="loading"`) until the hook sets its `src`.
    * Decrypt succeeded — the hook flips `data-state="ready"`, revealing the
      `<img>` and hiding the spinner.
    * Decrypt/fetch failed — the hook flips `data-state="error"`, hiding the
      spinner and revealing the building icon fallback.

  * `id` — unique DOM id for the hook element (tests + LiveView diffing).
  * `logo_url` — short-lived presigned GET URL for the opaque blob, or nil.
  * `sealed_org_key` — the viewer's `Membership.key` (org_key sealed for them).
  * `frame_class` — sizing/shape classes for the logo frame.
  * `img_class` — classes for the inner `<img>`.
  * `icon_class` — classes for the building fallback icon (loading + error).
  * `alt` — accessible image alt text.
  """
  attr :id, :string, required: true
  attr :logo_url, :string, default: nil
  attr :sealed_org_key, :string, default: nil
  attr :frame_class, :string, default: "h-12 w-12 rounded-2xl"
  attr :img_class, :string, default: "h-full w-full object-contain"
  attr :icon_class, :string, default: "h-6 w-6 text-slate-300 dark:text-slate-600"
  attr :alt, :string, default: "Organization logo"
  slot :fallback, required: true

  def org_logo(assigns) do
    ~H"""
    <%= if @logo_url && @sealed_org_key do %>
      <span
        id={@id}
        phx-hook="OrgLogoDisplay"
        phx-update="ignore"
        data-logo-url={@logo_url}
        data-sealed-org-key={@sealed_org_key}
        data-state="loading"
        class={[
          "group/logo relative flex shrink-0 items-center justify-center overflow-hidden border border-slate-200/70 dark:border-slate-700/70 bg-white dark:bg-slate-900/40",
          @frame_class
        ]}
      >
        <%!-- Spinner: visible while decrypting (data-state="loading"). --%>
        <span
          data-logo-spinner
          class="absolute inset-0 flex items-center justify-center group-data-[state=ready]/logo:hidden group-data-[state=error]/logo:hidden"
          aria-hidden="true"
        >
          <.phx_icon name="hero-arrow-path" class={["animate-spin", @icon_class]} />
        </span>

        <%!-- Building fallback: visible only on decrypt/fetch error. --%>
        <span
          data-logo-error
          class="absolute inset-0 hidden items-center justify-center group-data-[state=error]/logo:flex"
          aria-hidden="true"
        >
          <.phx_icon name="hero-building-office" class={@icon_class} />
        </span>

        <%!-- The decrypted logo: hidden until the hook sets src + flips to ready. --%>
        <img
          data-logo-img
          alt={@alt}
          class={[@img_class, "hidden group-data-[state=ready]/logo:block"]}
        />
      </span>
    <% else %>
      {render_slot(@fallback)}
    <% end %>
    """
  end
end
