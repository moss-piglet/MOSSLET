defmodule MossletWeb.FamilyLive.Show do
  @moduledoc """
  Family org dashboard: member list with roles, guardianship management
  (establish / accept / decline / pause / resume / revoke), invitations, and the
  always-visible managed-member transparency panel (I2).

  All guardian appends to the ZK write path are server-authoritative and derived
  from `Orgs.Guardianship` records (see `docs/GUARDIANSHIP_DESIGN.md`).
  """
  use MossletWeb, :live_view

  import MossletWeb.OrgTransferActions

  alias Mosslet.Orgs

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    org = Orgs.get_org!(current_user, slug)
    membership = Orgs.get_membership!(current_user, slug)

    if org.type == :family do
      if connected?(socket) do
        Orgs.subscribe_org(org)
        # Personal-connection events (Task #226): reflect a family member
        # accepting our "Connect" request live.
        Mosslet.Accounts.private_subscribe(current_user)
      end

      {:ok,
       socket
       |> assign(:org, org)
       |> assign(:membership, membership)
       |> assign(:page_title, org.name)
       |> assign(:coverage_status, Orgs.org_coverage_status(current_user))
       |> assign(:invite_form, to_form(%{"email" => ""}, as: :invite))
       |> assign(:org_display_name_form, to_form(%{"name" => ""}, as: :org_display_name))
       |> assign(:transfer_modal_open, false)
       |> assign(:transfer_form, to_form(%{"password" => "", "to_user_id" => ""}, as: :transfer))
       |> assign_family_data()}
    else
      {:ok,
       socket
       |> put_flash(:error, "Not a family organization")
       |> push_navigate(to: ~p"/app/family")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      current_page={:family}
      sidebar_current_page={:family}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8 lg:py-10 space-y-6">
        <header class="flex items-center gap-3">
          <.link
            navigate={~p"/app/family"}
            class="p-2 -ml-2 rounded-xl text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-800/60 transition-all duration-200"
            aria-label="Back to families"
          >
            <.phx_icon name="hero-arrow-left" class="size-5" />
          </.link>
          <div class="flex items-center gap-3 min-w-0">
            <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
              <.phx_icon name="hero-users" class="h-6 w-6 text-white" />
            </div>
            <div class="min-w-0">
              <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 truncate">
                {@org.name}
              </h1>
              <div class="flex items-center gap-2">
                <.family_role_badge role={@membership.role} />
                <.link
                  :if={@membership.role == :guardian}
                  navigate={~p"/app/family/#{@org.slug}/feed"}
                  class="text-xs font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700"
                >
                  View family feed →
                </.link>
              </div>
            </div>
          </div>
        </header>

        <.org_coverage_notice status={@coverage_status} />

        <%!-- Managed-member transparency panel (I2, always visible) --%>
        <.transparency_panel
          :if={@my_guardianships != []}
          guardianships={@my_guardianships}
        />

        <%!-- Pending consent requests for the current managed member --%>
        <div
          :if={@my_pending_consent != []}
          id="pending-consent-requests"
          class="rounded-2xl border border-amber-200/70 dark:border-amber-800/40 bg-amber-50/80 dark:bg-amber-900/15 p-4 space-y-3"
        >
          <h2 class="text-sm font-semibold text-amber-900 dark:text-amber-100">
            Guardianship requests
          </h2>
          <div
            :for={item <- @my_pending_consent}
            id={"consent-#{item.guardianship.id}"}
            class="flex items-center justify-between gap-3"
          >
            <p class="text-xs text-amber-800 dark:text-amber-200">
              <span class="font-medium">{item.guardian_name}</span>
              would like to read posts and conversations you create here. They'll use their own
              key — Mosslet still can't read them. You can pause or stop this any time.
            </p>
            <div class="flex items-center gap-2 flex-shrink-0">
              <.liquid_button
                color="emerald"
                size="sm"
                icon="hero-check"
                phx-click="accept_guardianship"
                phx-value-id={item.guardianship.id}
                id={"accept-#{item.guardianship.id}"}
              >
                Accept
              </.liquid_button>
              <.liquid_button
                variant="ghost"
                color="slate"
                size="sm"
                phx-click="decline_guardianship"
                phx-value-id={item.guardianship.id}
              >
                Decline
              </.liquid_button>
            </div>
          </div>
        </div>

        <%!-- Member management (admin only) --%>
        <section class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Members</h2>
            <span
              id="family-seat-usage"
              class={[
                "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium",
                if(@seats.available == 0,
                  do: "bg-rose-100 text-rose-700 dark:bg-rose-900/40 dark:text-rose-300",
                  else: "bg-slate-100 text-slate-600 dark:bg-slate-700/60 dark:text-slate-300"
                )
              ]}
            >
              <.phx_icon name="hero-user-group" class="size-3.5" />
              {@seats.used} of {@seats.cap} seats used
            </span>
          </div>

          <p
            :if={@membership.role == :admin && @seats.available == 0}
            id="family-seat-full-notice"
            class="rounded-lg bg-amber-50 dark:bg-amber-900/20 px-3 py-2 text-xs text-amber-800 dark:text-amber-300"
          >
            All seats are in use (including pending invites).
            <.link
              navigate={~p"/app/org/#{@org.slug}/subscribe"}
              class="font-semibold underline hover:no-underline"
            >
              Add more members
            </.link>
            to invite another family member.
          </p>

          <ul
            role="list"
            class="divide-y divide-slate-100 dark:divide-slate-700/60"
            id="org-members-roster"
            phx-hook="OrgMembers"
            data-sealed-org-key={@viewer_sealed_org_key}
            data-current-user-id={@current_scope.user.id}
          >
            <li
              :for={member <- @members}
              id={"member-#{member.user.id}"}
              class="py-3 flex items-center justify-between gap-3"
              data-org-member-row
              data-encrypted-display-name={member.encrypted_display_name}
            >
              <div class="flex items-center gap-3 min-w-0">
                <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                  <.phx_icon name="hero-user" class="size-4" />
                </div>
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                      <span {MossletWeb.OrgIdentity.org_name_target(member)}>
                        {MossletWeb.OrgIdentity.placeholder_label(member, "Family member")}
                      </span>
                    </p>
                    <.family_role_badge role={member.membership.role} />
                    <span
                      :if={Orgs.owner?(@org, member.user.id)}
                      id={"owner-badge-#{member.user.id}"}
                      class="inline-flex items-center gap-1 rounded-full bg-amber-100 dark:bg-amber-900/40 px-2.5 py-0.5 text-xs font-medium text-amber-700 dark:text-amber-300"
                    >
                      <.phx_icon name="hero-key" class="size-3" /> Owner
                    </span>
                  </div>
                  <p
                    :if={member.guardian_summaries != []}
                    class="text-xs text-slate-500 dark:text-slate-400"
                  >
                    Guardians: {Enum.join(member.guardian_summaries, ", ")}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-2 flex-shrink-0">
                <%!-- One-tap "Connect with teammate" (Task #226): send a personal
                     UserConnection invite to a family member you're not yet
                     connected to. Once accepted, their real personal name lights
                     up via the existing resolution path. --%>
                <.liquid_button
                  :if={MossletWeb.OrgIdentity.show_connect_button?(member)}
                  variant="secondary"
                  size="sm"
                  icon="hero-user-plus"
                  phx-click="connect_teammate"
                  phx-value-user_id={member.user.id}
                  id={"connect-#{member.user.id}"}
                >
                  Connect
                </.liquid_button>
                <span
                  :if={MossletWeb.OrgIdentity.connection_pending?(member)}
                  id={"connect-pending-#{member.user.id}"}
                  class="inline-flex items-center gap-1 rounded-full bg-amber-100 dark:bg-amber-900/40 px-2.5 py-1 text-xs font-medium text-amber-700 dark:text-amber-300"
                >
                  <.phx_icon name="hero-clock" class="size-3.5" /> Pending
                </span>

                <%!-- The owner is the org's billing/coverage anchor: an admin
                     can't change their role (ownership transfer is the only path
                     — Task #237). --%>
                <form
                  :if={@membership.role == :admin && not Orgs.owner?(@org, member.user.id)}
                  phx-change="change_role"
                  id={"role-form-#{member.user.id}"}
                >
                  <input type="hidden" name="user_id" value={member.user.id} />
                  <select
                    name="role"
                    class="rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-700 text-xs py-1.5 focus:border-emerald-500 focus:ring-emerald-500/30"
                  >
                    <option value="member" selected={member.membership.role == :member}>
                      Member
                    </option>
                    <option value="guardian" selected={member.membership.role == :guardian}>
                      Guardian
                    </option>
                    <option
                      value="managed_member"
                      selected={member.membership.role == :managed_member}
                    >
                      Managed
                    </option>
                    <option value="admin" selected={member.membership.role == :admin}>
                      Admin
                    </option>
                  </select>
                </form>
              </div>
            </li>
          </ul>

          <%!-- Org display-name prompt (Task #225): set how your family sees
               you, encrypted browser-side with the org_key. --%>
          <div
            :if={@viewer_sealed_org_key && is_nil(@membership.display_name)}
            id="org-display-name-prompt"
            class="rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-teal-50/60 dark:bg-teal-900/20 p-4"
          >
            <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
              Set how your family sees you
            </p>
            <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
              Family members can't read your personal name unless you're connected. Choose a
              family display name. It's encrypted on your device.
            </p>
            <.form
              for={@org_display_name_form}
              id="org-display-name-form"
              phx-hook="OrgDisplayNameFormHook"
              data-sealed-org-key={@viewer_sealed_org_key}
              phx-submit="save_org_display_name"
              class="mt-3 flex items-end gap-2"
            >
              <div class="flex-1">
                <.phx_input
                  field={@org_display_name_form[:name]}
                  type="text"
                  placeholder="Your family display name"
                  maxlength="160"
                />
              </div>
              <.liquid_button type="submit" id="org-display-name-submit" icon="hero-check">
                Save
              </.liquid_button>
            </.form>
          </div>

          <.pending_invitations_panel
            invitations={@pending_invitations}
            can_manage={@membership.role == :admin}
          />

          <%!-- Invite member (admin) --%>
          <div
            :if={@membership.role == :admin}
            class="pt-2 border-t border-slate-100 dark:border-slate-700/60"
          >
            <.form
              for={@invite_form}
              id="invite-form"
              phx-submit="invite_member"
              class="flex items-end gap-2"
            >
              <div class="flex-1">
                <.phx_input
                  field={@invite_form[:email]}
                  type="email"
                  label="Invite by email"
                  placeholder="member@example.com"
                />
              </div>
              <.liquid_button
                type="submit"
                id="invite-submit"
                color="emerald"
                icon="hero-paper-airplane"
              >
                Invite
              </.liquid_button>
            </.form>
          </div>
        </section>

        <%!-- Ownership / transfer handshake (Task #237) --%>
        <.ownership_section
          org={@org}
          current_user={@current_scope.user}
          is_owner={@is_owner?}
          members={@members}
          viewer_sealed_org_key={@viewer_sealed_org_key}
          pending_transfer={@pending_transfer}
          transfer_modal_open={@transfer_modal_open}
          transfer_form={@transfer_form}
        />

        <%!-- Guardianship management (admin) --%>
        <section
          :if={@membership.role == :admin}
          class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
        >
          <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
            Guardianships
          </h2>

          <ul role="list" class="space-y-2">
            <li
              :for={g <- @guardianships}
              id={"guardianship-#{g.guardianship.id}"}
              class="flex items-center justify-between gap-3 text-sm"
            >
              <div class="min-w-0">
                <p class="text-slate-900 dark:text-slate-100 truncate">
                  <span class="font-medium">{g.guardian_name}</span>
                  <span class="text-slate-400">→</span>
                  <span class="font-medium">{g.managed_name}</span>
                </p>
                <.guardianship_status_pill status={g.guardianship.status} />
              </div>
              <div class="flex items-center gap-2 flex-shrink-0">
                <.liquid_button
                  :if={g.guardianship.status == :active}
                  variant="ghost"
                  color="slate"
                  size="sm"
                  icon="hero-pause"
                  phx-click="pause_guardianship"
                  phx-value-id={g.guardianship.id}
                >
                  Pause
                </.liquid_button>
                <.liquid_button
                  :if={g.guardianship.status == :paused}
                  variant="ghost"
                  color="teal"
                  size="sm"
                  icon="hero-play"
                  phx-click="resume_guardianship"
                  phx-value-id={g.guardianship.id}
                >
                  Resume
                </.liquid_button>
                <.liquid_button
                  variant="ghost"
                  color="rose"
                  size="sm"
                  icon="hero-x-mark"
                  phx-click="revoke_guardianship"
                  phx-value-id={g.guardianship.id}
                  data-confirm="Revoke this guardianship? This stops FUTURE co-sealing. Content already shared with the guardian stays shared — that can't be undone."
                >
                  Revoke
                </.liquid_button>
              </div>
            </li>
            <li :if={@guardianships == []} class="text-xs text-slate-500 dark:text-slate-400">
              No guardianships yet.
            </li>
          </ul>

          <%!-- Establish new guardianship --%>
          <form
            :if={@can_establish?}
            phx-submit="establish_guardianship"
            id="establish-form"
            class="pt-3 border-t border-slate-100 dark:border-slate-700/60 grid grid-cols-1 sm:grid-cols-3 gap-2 items-end"
          >
            <label class="text-xs font-medium text-slate-600 dark:text-slate-300">
              Guardian
              <select
                name="guardian_membership_id"
                class="mt-1 w-full rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-700 text-sm focus:border-emerald-500 focus:ring-emerald-500/30"
              >
                <option :for={m <- @guardian_options} value={m.membership.id}>
                  {m.display_name}
                </option>
              </select>
            </label>
            <label class="text-xs font-medium text-slate-600 dark:text-slate-300">
              Managed member
              <select
                name="managed_membership_id"
                class="mt-1 w-full rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-700 text-sm focus:border-emerald-500 focus:ring-emerald-500/30"
              >
                <option :for={m <- @managed_options} value={m.membership.id}>
                  {m.display_name}
                </option>
              </select>
            </label>
            <.liquid_button type="submit" id="establish-submit" icon="hero-link">
              Link
            </.liquid_button>
          </form>
          <p
            :if={@membership.role == :admin && !@can_establish?}
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            Assign at least one Guardian and one Managed member (above) to create a guardianship.
          </p>
        </section>
      </div>
    </.layout>
    """
  end

  @impl true
  def handle_event("connect_teammate", %{"user_id" => user_id}, socket) do
    {:noreply, connect_teammate(socket, user_id, &assign_family_data/1)}
  end

  ## Ownership transfer handshake (Task #237)

  @impl true
  def handle_event("open_transfer_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:transfer_modal_open, true)
     |> assign(
       :transfer_form,
       to_form(%{"password" => "", "to_user_id" => ""}, as: :transfer)
     )}
  end

  @impl true
  def handle_event("close_transfer_modal", _params, socket) do
    {:noreply, assign(socket, :transfer_modal_open, false)}
  end

  @impl true
  def handle_event("initiate_transfer", params, socket) do
    to_user_id = Map.get(params, "to_user_id", "")
    password = get_in(params, ["transfer", "password"]) || ""
    {:noreply, do_initiate_transfer(socket, to_user_id, password, &assign_family_data/1)}
  end

  @impl true
  def handle_event("accept_transfer", params, socket) do
    transfer_id = Map.get(params, "transfer_id", "")
    password = get_in(params, ["transfer", "password"]) || ""
    {:noreply, do_accept_transfer(socket, transfer_id, password, &assign_family_data/1)}
  end

  @impl true
  def handle_event("decline_transfer", %{"transfer_id" => transfer_id}, socket) do
    {:noreply, do_decline_transfer(socket, transfer_id, &assign_family_data/1)}
  end

  @impl true
  def handle_event("cancel_transfer", %{"transfer_id" => transfer_id}, socket) do
    {:noreply, do_cancel_transfer(socket, transfer_id, &assign_family_data/1)}
  end

  @impl true
  def handle_event("invite_member", %{"invite" => %{"email" => email}}, socket) do
    case Orgs.create_invitation(socket.assigns.org, %{"sent_to" => email}) do
      {:ok, invitation} ->
        flash = invitation_sent_flash(invitation, socket.assigns.org)

        {:noreply,
         socket
         |> put_invitation_flash(flash)
         |> assign(:invite_form, to_form(%{"email" => ""}, as: :invite))
         |> assign_family_data()}

      {:error, :seat_limit_reached} ->
        {:noreply, put_flash(socket, :error, seat_limit_message(socket.assigns.org))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not send invitation")}
    end
  end

  @impl true
  def handle_event("resend_invitation", %{"id" => id}, socket) do
    org = socket.assigns.org

    if socket.assigns.membership.role == :admin do
      flash =
        case Orgs.get_invitation_for_org(org, id) do
          %{} = invitation ->
            case Orgs.resend_invitation(invitation) do
              {:ok, _email} -> {:success, "Invitation re-sent to #{invitation.sent_to}"}
              {:error, _reason} -> {:error, "Could not re-send the invitation. Please try again."}
            end

          nil ->
            {:info, "That invitation is no longer pending."}
        end

      {:noreply, socket |> put_invitation_flash(flash) |> assign_family_data()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("revoke_invitation", %{"id" => id}, socket) do
    org = socket.assigns.org

    if socket.assigns.membership.role == :admin do
      Orgs.revoke_invitation(org, id)

      {:noreply,
       socket
       |> put_flash(:info, "Invitation revoked")
       |> assign_family_data()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_role", %{"user_id" => user_id, "role" => role}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.user.id == user_id))

    # The owner is the org's billing/coverage anchor: their role can't be changed
    # by an admin (ownership transfer is the only path — Task #237).
    if member && socket.assigns.membership.role == :admin &&
         not Orgs.owner?(socket.assigns.org, user_id) do
      case Orgs.update_membership(member.membership, %{"role" => role}) do
        {:ok, _membership} ->
          {:noreply,
           socket
           |> put_flash(:success, "Role updated")
           |> assign_family_data()}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, role_error_message(changeset))
           |> assign_family_data()}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "establish_guardianship",
        %{"guardian_membership_id" => g_id, "managed_membership_id" => m_id},
        socket
      ) do
    guardian = Orgs.get_membership!(g_id)
    managed = Orgs.get_membership!(m_id)

    case Orgs.establish_guardianship(guardian, managed) do
      {:ok, _g} ->
        {:noreply,
         socket
         |> put_flash(:success, "Guardianship created — awaiting the managed member's consent.")
         |> assign_family_data()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, establish_error_message(reason))}
    end
  end

  def handle_event("accept_guardianship", %{"id" => id}, socket) do
    guardianship = Orgs.get_guardianship!(id)

    case Orgs.accept_guardianship(guardianship) do
      {:ok, _g} ->
        {:noreply,
         socket
         |> put_flash(:success, "Guardianship accepted")
         |> assign_family_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not accept")}
    end
  end

  def handle_event("decline_guardianship", %{"id" => id}, socket) do
    guardianship = Orgs.get_guardianship!(id)
    {:ok, _g} = Orgs.decline_guardianship(guardianship)

    {:noreply,
     socket
     |> put_flash(:info, "Guardianship declined")
     |> assign_family_data()}
  end

  def handle_event("pause_guardianship", %{"id" => id}, socket) do
    guardianship = Orgs.get_guardianship!(id)
    {:ok, _g} = Orgs.pause_guardianship(guardianship)

    {:noreply,
     socket
     |> put_flash(:info, "Paused — no NEW content will be shared. Past content stays shared.")
     |> assign_family_data()}
  end

  def handle_event("resume_guardianship", %{"id" => id}, socket) do
    guardianship = Orgs.get_guardianship!(id)
    {:ok, _g} = Orgs.resume_guardianship(guardianship)

    {:noreply,
     socket
     |> put_flash(:success, "Resumed — new content will be shared with the guardian.")
     |> assign_family_data()}
  end

  def handle_event("revoke_guardianship", %{"id" => id}, socket) do
    guardianship = Orgs.get_guardianship!(id)
    {:ok, _g} = Orgs.revoke_guardianship(guardianship)

    {:noreply,
     socket
     |> put_flash(:info, "Guardianship revoked. Future co-sealing stopped.")
     |> assign_family_data()}
  end

  # Org-scoped ZK identity (Task #225). Persist browser-sealed org_key copies
  # (server-authoritative + idempotent), and the member's own encrypted org
  # display name. Identical to the business dashboard (shared OrgIdentity).
  @impl true
  def handle_event("finalize_org_key", %{"sealed_members" => sealed_members}, socket)
      when is_list(sealed_members) do
    case MossletWeb.OrgIdentity.finalize_org_key(socket.assigns.org, sealed_members) do
      {:ok, _count} -> {:noreply, assign_family_data(socket)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "save_org_display_name",
        %{"encrypted_display_name" => encrypted_name},
        socket
      )
      when is_binary(encrypted_name) do
    case Orgs.set_org_display_name(socket.assigns.membership, encrypted_name) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:success, "Your family display name is set")
         |> assign_family_data()}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not save your display name")}
    end
  end

  @impl true
  def handle_event("org_display_name_invalid", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Please use letters, spaces, and basic punctuation (up to 160 characters)."
     )}
  end

  @impl true
  def handle_info({:org_updated, _org_id}, socket) do
    current_user = socket.assigns.current_scope.user
    # Re-fetch the org so ownership-derived state (e.g. `is_owner?` after an
    # ownership transfer, Task #237) reflects the latest `created_by_id` rather
    # than the stale struct captured at mount.
    org = Orgs.get_org_by_id(socket.assigns.org.id) || socket.assigns.org

    # Realtime org changes (Task #223 pubsub). Refresh when still a member;
    # otherwise leave the org surface gracefully (loss-of-coverage state A).
    if Orgs.member_of_org?(org, current_user.id) do
      {:noreply,
       socket
       |> assign(:org, org)
       |> assign(:membership, Orgs.get_membership!(current_user, org.slug))
       |> assign(:coverage_status, Orgs.org_coverage_status(current_user))
       |> assign_family_data()}
    else
      {:noreply,
       socket
       |> put_flash(
         :info,
         "You're no longer a member of this family. You can start your own plan or join another anytime."
       )
       |> push_navigate(to: ~p"/app/family")}
    end
  end

  # Personal-connection changes (Task #226): a family member accepted our
  # "Connect" request (`:uconn_confirmed`), a new request landed, or one was
  # removed. Refresh the roster so the button/pill + the now-readable personal
  # name update live — no full reload.
  def handle_info({event, %Mosslet.Accounts.UserConnection{}}, socket)
      when event in [:uconn_confirmed, :uconn_created, :uconn_deleted, :uconn_updated] do
    {:noreply, assign_family_data(socket)}
  end

  # Ignore unrelated process messages (e.g. Swoosh test email delivery, telemetry).
  def handle_info(_message, socket), do: {:noreply, socket}

  ## Data loading

  defp assign_family_data(socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    org = socket.assigns.org

    users = Orgs.list_members_by_org(org)
    guardianships = Orgs.list_guardianships_by_org(org)

    # Batched personal-connection status for the roster (Task #226): one query
    # instead of N. Drives the one-tap "Connect with teammate" button.
    connection_statuses =
      Mosslet.Accounts.connection_statuses_for(
        current_user.id,
        Enum.map(users, & &1.id)
      )

    members =
      Enum.map(users, fn user ->
        membership = Orgs.get_membership!(user, org.slug)
        personal_name = personal_connection_name(user, current_user, key)
        self? = user.id == current_user.id

        connection_status =
          if self?, do: :self, else: Map.get(connection_statuses, user.id, :none)

        guardian_summaries =
          guardianships
          |> Enum.filter(&(&1.managed_membership.user_id == user.id))
          |> Enum.map(fn g ->
            resolve_display_name(g.guardian_membership.user, current_user, key)
          end)

        %{
          user: user,
          membership: membership,
          # Org-scoped ZK identity (Task #225): server-side placeholder (You /
          # personal name / "Team member"); the org persona is decrypted
          # client-side by the OrgMembers hook.
          encrypted_display_name: membership.display_name,
          personal_name: personal_name,
          self?: self?,
          connection_status: connection_status,
          display_name: resolve_display_name(user, current_user, key),
          guardian_summaries: guardian_summaries
        }
      end)

    name_for_user = fn user -> resolve_display_name(user, current_user, key) end

    guardianships_view =
      Enum.map(guardianships, fn g ->
        %{
          guardianship: g,
          guardian_name: name_for_user.(g.guardian_membership.user),
          managed_name: name_for_user.(g.managed_membership.user)
        }
      end)

    # Transparency panel: guardianships where I am the managed member and active/paused.
    my_guardianships =
      guardianships
      |> Enum.filter(fn g ->
        g.managed_membership.user_id == current_user.id and g.status in [:active, :paused]
      end)
      |> Enum.map(fn g ->
        %{guardianship: g, guardian_name: name_for_user.(g.guardian_membership.user)}
      end)

    # Pending consent requests where I am the managed member.
    my_pending_consent =
      guardianships
      |> Enum.filter(fn g ->
        g.managed_membership.user_id == current_user.id and g.status == :pending
      end)
      |> Enum.map(fn g ->
        %{guardianship: g, guardian_name: name_for_user.(g.guardian_membership.user)}
      end)

    guardian_options = Enum.filter(members, &(&1.membership.role == :guardian))
    managed_options = Enum.filter(members, &(&1.membership.role == :managed_member))

    socket
    |> assign(:members, members)
    |> assign(:viewer_sealed_org_key, MossletWeb.OrgIdentity.viewer_sealed_org_key(members))
    |> assign(
      :should_bootstrap_org_key?,
      MossletWeb.OrgIdentity.should_bootstrap?(org, current_user, members)
    )
    |> assign(:guardianships, guardianships_view)
    |> assign(:my_guardianships, my_guardianships)
    |> assign(:my_pending_consent, my_pending_consent)
    |> assign(:guardian_options, guardian_options)
    |> assign(:managed_options, managed_options)
    |> assign(:pending_invitations, Orgs.list_invitations_by_org(org))
    |> assign(:seats, Orgs.seat_summary(org))
    |> assign(:can_establish?, guardian_options != [] and managed_options != [])
    |> assign(:is_owner?, Orgs.owner?(org, current_user.id))
    |> assign(:pending_transfer, Orgs.get_pending_transfer_for_org(org))
    |> maybe_request_org_key_seal()
  end

  # See OrgIdentity (Task #225): seal/bootstrap the org_key on the viewer's
  # browser when needed. Type-agnostic — identical to the business dashboard.
  defp maybe_request_org_key_seal(socket) do
    org = socket.assigns.org

    cond do
      not connected?(socket) ->
        socket

      socket.assigns.should_bootstrap_org_key? ->
        push_event(socket, "bootstrap_org_key", %{})

      MossletWeb.OrgIdentity.viewer_can_seal_for_others?(socket.assigns.members) ->
        push_event(socket, "seal_org_key_for_members", %{
          members: MossletWeb.OrgIdentity.members_to_seal(org)
        })

      true ->
        socket
    end
  end

  defp seat_limit_message(org) do
    %{used: used, cap: cap} = Orgs.seat_summary(org)

    "All seats are in use (#{used} of #{cap}, including pending invites). " <>
      "Add more members to invite another person."
  end

  # Sends the invitation email and returns a `{kind, message}` flash tuple.
  # Per decision (a), a mail failure is non-fatal — the invitation row already
  # exists, so the recipient can accept from their invitations page and an admin
  # can resend.
  defp invitation_sent_flash(invitation, org) do
    case Orgs.deliver_invitation_email(invitation, org) do
      {:ok, _email} ->
        {:success, "Invitation sent to #{invitation.sent_to}"}

      {:error, _reason} ->
        {:info,
         "Invited #{invitation.sent_to}, but the email couldn't be sent right now. " <>
           "They can still accept from their invitations page, or you can resend below."}
    end
  end

  defp put_invitation_flash(socket, {kind, message}) do
    put_flash(socket, kind, message)
  end

  # Resolve a member's display name using the viewer's connection to them
  # (browser/session-key decrypt). Falls back to a generic label when the
  # viewer has no connection (e.g. a member they're not directly connected to).
  defp resolve_display_name(%{id: same_id}, %{id: same_id}, _key), do: "You"

  defp resolve_display_name(user, current_user, key) do
    case Mosslet.Accounts.get_user_connection_between_users(user.id, current_user.id) do
      %{} = uconn ->
        uconn = Mosslet.Repo.preload(uconn, :connection)
        get_decrypted_connection_name(uconn, current_user, key)

      _ ->
        "Family member"
    end
  end

  # Personal-connection name the viewer can already read for `user` (Task #225,
  # Q4: preferred over the org persona when present). Returns nil when there is
  # no connection — the org display name (or neutral placeholder) is used.
  defp personal_connection_name(user, current_user, key) do
    case Mosslet.Accounts.get_user_connection_between_users(user.id, current_user.id) do
      %{} = uconn ->
        uconn = Mosslet.Repo.preload(uconn, :connection)
        get_decrypted_connection_name(uconn, current_user, key)

      _ ->
        nil
    end
  end

  defp role_error_message(changeset) do
    case changeset.errors[:role] do
      {msg, _} -> msg
      _ -> "Could not update role"
    end
  end

  # One-tap "Connect with teammate" (Task #226): reuse the shared OrgIdentity
  # invite path (server-authoritative org-membership check + the existing
  # UserConnection sealing flow). Refreshes the roster so the button flips to a
  # "Pending" pill immediately.
  defp connect_teammate(socket, target_user_id, refresh_fun) do
    case MossletWeb.OrgIdentity.connect_teammate(
           socket.assigns.org,
           socket.assigns.current_scope,
           target_user_id
         ) do
      {:ok, _uconn} ->
        socket
        |> put_flash(:success, "Connection request sent. They'll see it in their invitations.")
        |> refresh_fun.()

      {:error, :not_a_member} ->
        put_flash(socket, :error, "That person isn't a member of this family.")

      {:error, _changeset} ->
        socket
        |> put_flash(:info, "You've already sent a request or are connected.")
        |> refresh_fun.()
    end
  end

  defp establish_error_message(:different_orgs), do: "Both members must be in this family."

  defp establish_error_message(:guardian_role_required),
    do: "Guardian must have the Guardian role."

  defp establish_error_message(:managed_member_role_required),
    do: "Managed member must have the Managed role."

  defp establish_error_message(:already_exists), do: "That guardianship already exists."
  defp establish_error_message(_), do: "Could not create guardianship."
end
