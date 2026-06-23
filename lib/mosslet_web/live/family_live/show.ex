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
  import MossletWeb.OrgDeleteActions

  alias Mosslet.GroupMessages
  alias Mosslet.Groups
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
       |> assign(:editing_name_user_id, nil)
       |> assign(:transfer_modal_open, false)
       |> assign(:transfer_form, to_form(%{"password" => "", "to_user_id" => ""}, as: :transfer))
       |> assign(:delete_modal_open, false)
       |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete_org))
       |> assign(:show_circle_form?, false)
       |> assign(:circle_form, to_form(%{"name" => "", "description" => ""}, as: :circle))
       |> assign(:pending_zk_circle_attrs, nil)
       |> assign_family_data()
       |> maybe_subscribe_to_family_circles(connected?(socket))}
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
              <.phx_icon name="hero-heart" class="h-6 w-6 text-white" />
            </div>
            <div class="min-w-0">
              <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 truncate">
                {@org.name}
              </h1>
              <div class="flex items-center gap-2">
                <.family_role_badge role={@membership.role} />
                <.link
                  :if={@is_guardian?}
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

        <%!-- Family guardian safety override (Task #284): when the viewer is a
        managed member whose guardian(s) still lack a sealed copy of their
        conn_key, this hidden hook seals it browser-side (the only place conn_key
        exists) so the guardian can see the managed member's PERSONAL avatar. --%>
        <div
          :if={@guardian_avatar_seal_targets != []}
          id="guardian-avatar-seal"
          phx-hook="GuardianAvatarSeal"
          class="hidden"
        >
        </div>

        <%!-- Managed-member transparency panel (I2, always visible) --%>
        <.transparency_panel
          :if={@my_guardianships != []}
          guardianships={@my_guardianships}
        />

        <%!-- Pending consent requests for the current managed member --%>
        <div
          :if={@my_pending_consent != []}
          id="pending-consent-requests"
          phx-hook="DecryptComposerGuardians"
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
              <span
                class="font-medium"
                data-guardian-name
                data-sealed-org-key={item[:sealed_org_key]}
                data-encrypted-display-name={item[:encrypted_display_name]}
              >{item.guardian_name}</span>
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
              class="py-3 flex flex-wrap items-center justify-between gap-x-3 gap-y-2"
              data-org-member-row
              data-encrypted-display-name={member.encrypted_display_name}
              data-encrypted-org-avatar={member.encrypted_org_avatar}
              data-guardian-avatar-blob={
                MossletWeb.OrgIdentity.guardian_avatar_attr(
                  @guardian_avatars,
                  member,
                  :encrypted_blob_b64
                )
              }
              data-guardian-sealed-key={
                MossletWeb.OrgIdentity.guardian_avatar_attr(@guardian_avatars, member, :sealed_key)
              }
            >
              <div class="flex items-center gap-3 min-w-0">
                <div class="relative flex h-9 w-9 shrink-0 items-center justify-center rounded-full overflow-hidden bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                  <span data-org-avatar-fallback class="flex items-center justify-center">
                    <.phx_icon name="hero-user" class="size-4" />
                  </span>
                  <img
                    data-org-avatar-target
                    hidden
                    alt=""
                    class="absolute inset-0 h-full w-full object-cover"
                  />
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
                <%!-- Edit display name (Task #264 parity). The viewer can rename
                     themselves (re-edit; the first-time prompt below covers the
                     unset case), and family admins can rename anyone. The name is
                     re-encrypted browser-side with the shared org_key (ZK); the
                     server only authorizes + stores ciphertext. No audit log —
                     unlike business orgs, families have no admin activity feed. --%>
                <button
                  :if={show_edit_name?(member, @viewer_sealed_org_key, @membership.role == :admin)}
                  type="button"
                  phx-click="edit_name"
                  phx-value-user_id={member.user.id}
                  id={"edit-name-#{member.user.id}"}
                  aria-label="Edit display name"
                  title="Edit display name"
                  class="rounded-lg p-1.5 text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-700/60 transition-colors duration-200"
                >
                  <.phx_icon name="hero-pencil-square" class="size-4" />
                </button>

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

              <%!-- Inline edit-name form (Task #264 parity). Wraps to its own
                   line (`basis-full`). The OrgDisplayNameFormHook decrypts
                   `data-current-encrypted-name` to PREFILL the input and, on
                   submit, re-encrypts with the org_key and pushes
                   `save_org_display_name` carrying `target_user_id` so the server
                   stores it on the right membership (re-authorized). --%>
              <.form
                :if={@editing_name_user_id == member.user.id}
                for={@org_display_name_form}
                id={"edit-name-form-#{member.user.id}"}
                phx-hook="OrgDisplayNameFormHook"
                data-sealed-org-key={@viewer_sealed_org_key}
                data-target-user-id={member.user.id}
                data-current-encrypted-name={member.encrypted_display_name}
                phx-submit="save_org_display_name"
                class="basis-full mt-1 flex flex-col gap-2 rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-teal-50/60 dark:bg-teal-900/20 p-3 sm:flex-row sm:items-end"
              >
                <div class="flex-1">
                  <.phx_input
                    field={@org_display_name_form[:name]}
                    type="text"
                    label={
                      if member.self?, do: "Your family display name", else: "Family display name"
                    }
                    placeholder="Your family display name"
                    maxlength="160"
                    autocomplete="off"
                  />
                </div>
                <div class="flex items-center gap-2">
                  <.liquid_button
                    type="submit"
                    size="sm"
                    color="emerald"
                    icon="hero-check"
                    id={"edit-name-submit-#{member.user.id}"}
                  >
                    Save
                  </.liquid_button>
                  <.liquid_button
                    type="button"
                    variant="ghost"
                    color="slate"
                    size="sm"
                    phx-click="cancel_edit_name"
                  >
                    Cancel
                  </.liquid_button>
                </div>
              </.form>
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

          <%!-- Org display-AVATAR control (Task #277): set the avatar your
               family sees — separate from your personal avatar. Resized +
               encrypted with the org_key entirely in the browser; the server
               only stores ciphertext. When unset, family members see initials
               from the family display name. --%>
          <div
            :if={@viewer_sealed_org_key}
            id="org-avatar-manage"
            phx-hook="OrgAvatarFormHook"
            data-sealed-org-key={@viewer_sealed_org_key}
            data-current-encrypted-avatar={@membership.avatar}
            class="rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-teal-50/60 dark:bg-teal-900/20 p-4"
          >
            <div class="flex items-center gap-4">
              <div class="relative w-14 h-14 flex-shrink-0 rounded-full overflow-hidden ring-2 ring-teal-300/60 dark:ring-teal-700/60 bg-white dark:bg-slate-800">
                <img
                  data-org-avatar-preview
                  src={~p"/images/logo.svg"}
                  alt="Your family avatar"
                  class="w-full h-full object-cover"
                />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  Your family avatar
                </p>
                <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                  How family members see you when you're not personally connected. Encrypted on
                  your device — we never see the image.
                </p>
                <div class="mt-2 flex items-center gap-2">
                  <input
                    type="file"
                    data-org-avatar-input
                    accept="image/png,image/jpeg,image/webp,image/gif,image/heic,image/heif"
                    class="sr-only"
                  />
                  <.liquid_button
                    type="button"
                    size="sm"
                    color="teal"
                    icon="hero-photo"
                    data-org-avatar-trigger
                    id="org-avatar-trigger"
                  >
                    {if @membership.avatar, do: "Change avatar", else: "Upload avatar"}
                  </.liquid_button>
                  <.liquid_button
                    :if={@membership.avatar}
                    type="button"
                    variant="ghost"
                    color="slate"
                    size="sm"
                    phx-click="remove_org_avatar"
                    data-confirm="Remove your family avatar? Family members will see your initials instead."
                    id="org-avatar-remove"
                  >
                    Remove
                  </.liquid_button>
                </div>
              </div>
            </div>
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

        <%!-- Family circle (Task #271): a dedicated shared family space — chat +
             ZK file sharing — kept separate from personal Circles. Guardians of
             managed members co-read it (consent-based, transparent). --%>
        <section class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="min-w-0">
              <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                Family circles
              </h2>
              <p class="mt-1 text-sm leading-relaxed text-slate-500 dark:text-slate-400">
                A private, end-to-end encrypted space for your family to chat and share files.
                A managed member's guardian co-reads it with their own key.
              </p>
            </div>
            <.liquid_button
              :if={!@show_circle_form?}
              phx-click="show_circle_form"
              id="new-family-circle-button"
              color="emerald"
              size="md"
              icon="hero-plus"
              class="w-full shrink-0 sm:w-auto"
            >
              New family circle
            </.liquid_button>
          </div>

          <div
            :if={@show_circle_form?}
            id="new-family-circle-form-wrapper"
            class="rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-gradient-to-br from-slate-50/80 to-slate-100/50 dark:from-slate-800/50 dark:to-slate-900/30 p-4"
          >
            <.form
              for={@circle_form}
              id="new-family-circle-form"
              phx-submit="create_circle"
              phx-hook="GroupMetadataFormHook"
              data-action="new"
              data-public="false"
              class="space-y-4"
            >
              <input type="hidden" name="group[user_id]" value={@current_scope.user.id} />
              <input
                type="hidden"
                name="group[user_name]"
                value={@current_scope.user.decrypted[:name]}
              />

              <.phx_input
                field={@circle_form[:name]}
                name="group[name]"
                type="text"
                label="Circle name"
                placeholder="e.g. The Smiths"
              />
              <.phx_input
                field={@circle_form[:description]}
                name="group[description]"
                type="text"
                label="Description"
                placeholder="What is this circle about?"
              />

              <p class="text-xs text-slate-500 dark:text-slate-400">
                You'll start as the only member — add family members from inside the circle.
              </p>

              <div class="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-end">
                <.liquid_button
                  type="button"
                  variant="ghost"
                  color="slate"
                  phx-click="hide_circle_form"
                >
                  Cancel
                </.liquid_button>
                <.liquid_button
                  type="submit"
                  id="create-family-circle-submit"
                  color="emerald"
                  icon="hero-sparkles"
                  phx-disable-with="Creating..."
                >
                  Create circle
                </.liquid_button>
              </div>
            </.form>
          </div>

          <ul :if={@family_circles != []} role="list" class="space-y-2">
            <li
              :for={circle <- @family_circles}
              id={"family-circle-#{circle.group.id}"}
              data-hook-scope={"family-circle-#{circle.group.id}"}
              class="group overflow-hidden rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-white/70 dark:bg-slate-800/50 hover:border-emerald-300/60 dark:hover:border-emerald-700/50 transition-all duration-200"
            >
              <div
                id={"decrypt-family-circle-#{circle.group.id}"}
                phx-hook="DecryptGroupMetadata"
                data-sealed-group-key={circle.sealed_group_key}
                data-encrypted-name={circle.encrypted_name}
                data-scope-id={"family-circle-#{circle.group.id}"}
              >
              </div>
              <.link
                navigate={~p"/app/family/#{@org.slug}/circles/#{circle.group.id}"}
                class="flex items-center gap-3 p-3"
              >
                <div class="relative flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/40 dark:to-emerald-900/40 text-teal-600 dark:text-teal-300 group-hover:text-teal-700">
                  <.phx_icon name="hero-home-modern" class="size-4" />
                  <.mention_badge
                    id={"family-circle-#{circle.group.id}-mentions"}
                    count={circle.unread_mention_count}
                    variant={:family}
                  />
                </div>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                    <span id={"family-circle-name-#{circle.group.id}"} phx-update="ignore">
                      <span data-decrypt-group-name>Family circle</span>
                    </span>
                  </p>
                  <p class="text-xs text-slate-500 dark:text-slate-400">
                    {circle.member_count} member{if circle.member_count != 1, do: "s"}
                  </p>
                </div>
                <.phx_icon
                  name="hero-chevron-right"
                  class="size-4 shrink-0 text-slate-300 dark:text-slate-600 group-hover:text-teal-500 dark:group-hover:text-teal-400"
                />
              </.link>
            </li>
          </ul>

          <p
            :if={@family_circles == [] && !@show_circle_form?}
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            No family circle yet. Create one to start a private, encrypted space for your family.
          </p>
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
          delete_modal_open={@delete_modal_open}
          delete_form={@delete_form}
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
                id="establish-guardian-select"
                phx-hook="DecryptOrgNameOptions"
                data-sealed-org-key={@viewer_sealed_org_key}
                class="mt-1 w-full rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-700 text-sm focus:border-emerald-500 focus:ring-emerald-500/30"
              >
                <option
                  :for={m <- @guardian_options}
                  value={m.membership.id}
                  data-encrypted-display-name={m.encrypted_display_name}
                >
                  {m.display_name}
                </option>
              </select>
            </label>
            <label class="text-xs font-medium text-slate-600 dark:text-slate-300">
              Managed member
              <select
                name="managed_membership_id"
                id="establish-managed-select"
                phx-hook="DecryptOrgNameOptions"
                data-sealed-org-key={@viewer_sealed_org_key}
                class="mt-1 w-full rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-700 text-sm focus:border-emerald-500 focus:ring-emerald-500/30"
              >
                <option
                  :for={m <- @managed_options}
                  value={m.membership.id}
                  data-encrypted-display-name={m.encrypted_display_name}
                >
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
            Assign at least one Managed member (above) to create a guardianship — you (the owner) or any Guardian can serve as the guardian.
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
     |> assign(:delete_modal_open, false)
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

  ## Safe org deletion + ZK teardown (Task #227)

  @impl true
  def handle_event("open_delete_org_modal", _params, socket) do
    {:noreply, open_delete_org_modal(socket)}
  end

  @impl true
  def handle_event("close_delete_org_modal", _params, socket) do
    {:noreply, close_delete_org_modal(socket)}
  end

  @impl true
  def handle_event("delete_org", params, socket) do
    confirm_name = Map.get(params, "confirm_name", "")
    password = get_in(params, ["delete_org", "password"]) || ""
    {:noreply, do_delete_org(socket, confirm_name, password, ~p"/app/family")}
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
    # Consent (§6.3): only the MANAGED member can accept their own guardianship.
    with_authorized_guardianship(socket, id, &consent_actor?/3, fn guardianship, socket ->
      case Orgs.accept_guardianship(guardianship) do
        {:ok, _g} ->
          socket
          |> put_flash(:success, "Guardianship accepted")
          |> assign_family_data()

        {:error, _} ->
          put_flash(socket, :error, "Could not accept")
      end
    end)
  end

  def handle_event("decline_guardianship", %{"id" => id}, socket) do
    # Consent (§6.3): only the MANAGED member can decline.
    with_authorized_guardianship(socket, id, &consent_actor?/3, fn guardianship, socket ->
      {:ok, _g} = Orgs.decline_guardianship(guardianship)

      socket
      |> put_flash(:info, "Guardianship declined")
      |> assign_family_data()
    end)
  end

  def handle_event("pause_guardianship", %{"id" => id}, socket) do
    # Privacy toggle (DESIGN §0): the managed member, the guardian, OR an admin.
    with_authorized_guardianship(socket, id, &can_toggle_guardianship?/3, fn guardianship,
                                                                             socket ->
      {:ok, _g} = Orgs.pause_guardianship(guardianship)

      socket
      |> put_flash(:info, "Paused — no NEW content will be shared. Past content stays shared.")
      |> assign_family_data()
    end)
  end

  def handle_event("resume_guardianship", %{"id" => id}, socket) do
    with_authorized_guardianship(socket, id, &can_toggle_guardianship?/3, fn guardianship,
                                                                             socket ->
      {:ok, _g} = Orgs.resume_guardianship(guardianship)

      socket
      |> put_flash(:success, "Resumed — new content will be shared with the guardian.")
      |> assign_family_data()
    end)
  end

  def handle_event("revoke_guardianship", %{"id" => id}, socket) do
    # Structural teardown: admin or guardian only. The managed member uses Pause
    # (reversible, keeps the transparency record honest) rather than deleting.
    with_authorized_guardianship(socket, id, &can_revoke_guardianship?/3, fn guardianship,
                                                                             socket ->
      {:ok, _g} = Orgs.revoke_guardianship(guardianship)

      socket
      |> put_flash(:info, "Guardianship revoked. Future co-sealing stopped.")
      |> assign_family_data()
    end)
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

  # TOFU key-pin persist from the verify-before-seal paths on the family
  # dashboard (#294): org_key seal (OrgMembers) and the guardian conn_key seal
  # (GuardianAvatarSeal). CO-MEMBERSHIP guard — guardians and managed members are
  # all members of the same family org, so a current family-org membership is the
  # legitimate authority (no personal connection required). First-write-wins.
  def handle_event("store_peer_pins", %{"pins" => pins}, socket) do
    org = socket.assigns.org
    user = socket.assigns.current_scope.user

    MossletWeb.Helpers.persist_peer_pins(to_string(user.id), pins, fn pid ->
      Orgs.member_of_org?(org, pid)
    end)

    {:noreply, socket}
  end

  # Family guardian safety override (Task #284): persist the managed member's
  # conn_key sealed for each guardian (the viewer IS the managed member here).
  # Server-authoritative + idempotent — only :active guardianships where this
  # user is the managed member and the key is unset are written.
  @impl true
  def handle_event("finalize_managed_avatar_key", %{"sealed" => sealed}, socket)
      when is_list(sealed) do
    current_user = socket.assigns.current_scope.user

    case Orgs.seal_managed_avatar_keys(current_user.id, sealed) do
      {:ok, count} when count > 0 -> {:noreply, assign_family_data(socket)}
      _ -> {:noreply, socket}
    end
  end

  ## Family circle create (Task #271 — owner-only ZK create; members are added
  ## from inside the circle via the org_key-based add flow, which also co-seals
  ## for guardians of any managed-member participants).

  @impl true
  def handle_event("show_circle_form", _params, socket) do
    {:noreply, assign(socket, :show_circle_form?, true)}
  end

  @impl true
  def handle_event("hide_circle_form", _params, socket) do
    {:noreply, assign(socket, :show_circle_form?, false)}
  end

  # Fallback when browser crypto is unavailable (ZK — never persist plaintext).
  @impl true
  def handle_event("create_circle", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Your browser couldn't prepare encryption keys. Please reload and try again."
     )}
  end

  # Phase 1 (ZK): the browser generated a fresh group_key, encrypted the
  # name/description, and sealed the creator's own copy. The family circle starts
  # owner-only; we hand back an empty member list (plus the owner moniker/avatar)
  # for the hook to finalize. The raw group_key never reaches the server.
  @impl true
  def handle_event("create_group_zk", params, socket) do
    user = socket.assigns.current_scope.user

    if params["user_id"] == user.id do
      zk_attrs = %{
        encrypted_name: params["encrypted_name"],
        encrypted_description: params["encrypted_description"],
        name_blind_index: params["name_blind_index"],
        sealed_creator_key: params["sealed_creator_key"],
        encrypted_user_name: params["encrypted_user_name"],
        require_password?: false,
        password: ""
      }

      {:noreply,
       socket
       |> assign(:pending_zk_circle_attrs, zk_attrs)
       |> push_event("seal_group_key_for_members", %{
         members: [],
         owner_moniker: FriendlyID.generate(3),
         owner_avatar_img: random_avatar()
       })}
    else
      {:noreply, put_flash(socket, :error, "Could not create the family circle.")}
    end
  end

  # Phase 2 (ZK): the browser sealed the owner's moniker/avatar with the
  # group_key. Persist via the family-circle write path (stamps the family
  # `org_id` + enforces org-membership server-side). The raw group_key NEVER
  # reaches the server.
  @impl true
  def handle_event("finalize_group_zk", params, socket) do
    user = socket.assigns.current_scope.user
    org = socket.assigns.org
    zk_attrs = socket.assigns.pending_zk_circle_attrs

    if is_nil(zk_attrs) do
      {:noreply, put_flash(socket, :error, "No pending circle to finalize. Please try again.")}
    else
      zk_attrs =
        zk_attrs
        |> Map.put(:encrypted_owner_moniker, params["encrypted_owner_moniker"])
        |> Map.put(:encrypted_owner_avatar_img, params["encrypted_owner_avatar_img"])

      sealed_members = params["sealed_members"] || []
      socket = assign(socket, :pending_zk_circle_attrs, nil)

      case Groups.create_family_circle_zk(org, user, zk_attrs, [], sealed_members) do
        {:ok, group} ->
          Mosslet.Logs.log("orgs.create_family_circle", %{
            user: user,
            org_id: org.id,
            metadata: %{"group_id" => group.id}
          })

          {:noreply,
           socket
           |> put_flash(:success, "Family circle created")
           |> assign(:show_circle_form?, false)
           |> assign(:circle_form, to_form(%{"name" => "", "description" => ""}, as: :circle))
           |> push_navigate(to: ~p"/app/family/#{org.slug}/circles/#{group.id}")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not create the family circle.")}
      end
    end
  end

  @impl true
  def handle_event(
        "save_org_display_name",
        %{"encrypted_display_name" => encrypted_name} = params,
        socket
      )
      when is_binary(encrypted_name) do
    # The display name is ciphertext under the shared `org_key`, so any key-holder
    # can re-encrypt any member's name browser-side. Authority still gates the
    # WRITE here (I1):
    #   * self-edit — any member may rename themselves.
    #   * editing someone else — family admins only.
    # No audit log: families have no admin activity feed (unlike business orgs).
    current_user_id = socket.assigns.current_scope.user.id
    target_user_id = params["target_user_id"]
    can_manage? = socket.assigns.membership.role == :admin

    target_membership =
      cond do
        is_nil(target_user_id) or target_user_id == current_user_id ->
          socket.assigns.membership

        can_manage? ->
          case Enum.find(socket.assigns.members, &(&1.user.id == target_user_id)) do
            %{membership: membership} -> membership
            _ -> nil
          end

        true ->
          nil
      end

    case target_membership && Orgs.set_org_display_name(target_membership, encrypted_name) do
      {:ok, _membership} ->
        message =
          if is_nil(target_user_id) or target_user_id == current_user_id,
            do: "Your family display name is set",
            else: "Display name updated"

        {:noreply,
         socket
         |> assign(:editing_name_user_id, nil)
         |> put_flash(:success, message)
         |> assign_family_data()}

      nil ->
        {:noreply, put_flash(socket, :error, "You can't edit that member's name")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not save your display name")}
    end
  end

  # Fallback (e.g. WASM/keys unavailable): the OrgDisplayNameFormHook normally
  # intercepts the submit, encrypts the name browser-side with the org_key, and
  # pushes "save_org_display_name" with `encrypted_display_name`. Without it the
  # raw form params arrive here. We must NEVER persist the plaintext name (ZK),
  # so we refuse gracefully and ask the member to reload.
  def handle_event("save_org_display_name", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Your browser couldn't prepare encryption keys. Please reload and try again."
     )}
  end

  # Open/close the inline "edit display name" form for a single roster row
  # (Task #264 parity). Allowed for the viewer's OWN row, or any row when the
  # viewer is a family admin. The write is re-authorized in
  # "save_org_display_name", so a tampered toggle can't escalate.
  @impl true
  def handle_event("edit_name", %{"user_id" => user_id}, socket) do
    allowed? =
      user_id == socket.assigns.current_scope.user.id or
        socket.assigns.membership.role == :admin

    if allowed? do
      {:noreply,
       socket
       |> assign(:editing_name_user_id, user_id)
       |> assign(:org_display_name_form, to_form(%{"name" => ""}, as: :org_display_name))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit_name", _params, socket) do
    {:noreply, assign(socket, :editing_name_user_id, nil)}
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

  # The member set their family display AVATAR (Task #277), resized + encrypted
  # browser-side with the org_key. Persist ciphertext only, on the viewer's OWN
  # membership (avatars are self-managed).
  @impl true
  def handle_event("save_org_avatar", %{"encrypted_avatar" => encrypted_avatar}, socket)
      when is_binary(encrypted_avatar) do
    case socket.assigns.membership &&
           Orgs.set_org_avatar(socket.assigns.membership, encrypted_avatar) do
      {:ok, membership} ->
        {:noreply,
         socket
         |> assign(:membership, membership)
         |> put_flash(:success, "Your family avatar is saved")
         |> assign_family_data()}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not save your family avatar")}
    end
  end

  @impl true
  def handle_event("org_avatar_invalid", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "We couldn't prepare that image. Use a PNG/JPEG/WebP under 8MB and try again."
     )}
  end

  @impl true
  def handle_event("remove_org_avatar", _params, socket) do
    case socket.assigns.membership && Orgs.clear_org_avatar(socket.assigns.membership) do
      {:ok, membership} ->
        {:noreply,
         socket
         |> assign(:membership, membership)
         |> put_flash(:success, "Your family avatar was removed")
         |> assign_family_data()}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not remove your family avatar")}
    end
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

  # Realtime unread-@mention badge (Task #280): a new message in any family
  # circle the viewer belongs to. Recompute only the per-circle counts over the
  # circles we already hold (server-authoritative, ZK-safe) — no full data
  # refresh, so the browser-side circle-name decryption isn't re-triggered.
  def handle_info(%{event: "new_message"}, socket) do
    circles = put_unread_mention_counts(socket.assigns.family_circles)
    {:noreply, assign(socket, :family_circles, circles)}
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
          encrypted_org_avatar: membership.avatar,
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
        entry = guardian_name_entry(g.guardian_membership.user, current_user, key)

        %{
          guardianship: g,
          guardian_name: entry.name,
          sealed_org_key: entry.sealed_org_key,
          encrypted_display_name: entry.encrypted_display_name
        }
      end)

    # Pending consent requests where I am the managed member.
    my_pending_consent =
      guardianships
      |> Enum.filter(fn g ->
        g.managed_membership.user_id == current_user.id and g.status == :pending
      end)
      |> Enum.map(fn g ->
        entry = guardian_name_entry(g.guardian_membership.user, current_user, key)

        %{
          guardianship: g,
          guardian_name: entry.name,
          sealed_org_key: entry.sealed_org_key,
          encrypted_display_name: entry.encrypted_display_name
        }
      end)

    # Whether the viewer actually ACTS as a guardian of someone (role :guardian
    # OR owner-as-guardian, Task #267) — drives the "View family feed" link.
    i_am_guardian? =
      Enum.any?(guardianships, fn g ->
        g.guardian_membership.user_id == current_user.id and g.status in [:active, :paused]
      end)

    # The owner/admin is guardian-eligible too (Task #267), so a 2-member family
    # (owner + one managed child) can establish a guardianship. Self-guardianship
    # is impossible (single role per membership + distinct-membership validation).
    guardian_options =
      Enum.filter(members, &(&1.membership.role in [:guardian, :admin]))

    managed_options = Enum.filter(members, &(&1.membership.role == :managed_member))

    family_circles = build_family_circles(org, current_user)

    # Family guardian safety override (Task #284): guardianships where the viewer
    # IS the managed member and their guardian still lacks a sealed copy of the
    # viewer's conn_key. The viewer's browser (the only holder of conn_key) seals
    # it for each guardian. Server-authoritative recipient set (I1).
    guardian_avatar_seal_targets =
      Orgs.list_guardianships_needing_avatar_key(current_user.id)
      |> Enum.map(fn %{guardianship_id: gid, guardian_user: guardian} ->
        %{
          guardianship_id: gid,
          user_id: guardian.id,
          public_key: guardian.key_pair["public"],
          pq_public_key: guardian.pq_public_key
        }
      end)
      |> Enum.reject(&is_nil(&1.public_key))

    socket
    |> assign(:members, members)
    |> assign(
      :guardian_avatars,
      MossletWeb.Helpers.guardian_avatar_directory(members, current_user, key)
    )
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
    |> assign(:is_guardian?, i_am_guardian?)
    |> assign(:pending_invitations, Orgs.list_invitations_by_org(org))
    |> assign(:seats, Orgs.seat_summary(org))
    |> assign(:can_establish?, guardian_options != [] and managed_options != [])
    |> assign(:is_owner?, Orgs.owner?(org, current_user.id))
    |> assign(:pending_transfer, Orgs.get_pending_transfer_for_org(org))
    |> assign(:family_circles, family_circles)
    |> assign(:guardian_avatar_seal_targets, guardian_avatar_seal_targets)
    |> maybe_request_org_key_seal()
    |> maybe_request_avatar_key_seal()
  end

  # Family circle view-models (Task #271): the shared family circles the viewer
  # is a confirmed member of, each carrying the viewer's sealed `group_key` so
  # the circle NAME decrypts browser-side (ZK) on the card.
  defp build_family_circles(org, current_user) do
    org
    |> Groups.list_family_circles(current_user)
    |> Enum.map(fn group ->
      ug = Enum.find(group.user_groups, &(&1.user_id == current_user.id))

      member_count =
        group.user_groups |> Enum.count(&(not is_nil(&1.confirmed_at)))

      %{
        group: group,
        encrypted_name: group.name,
        sealed_group_key: ug && ug.key,
        # The viewer's user_group id drives the server-authoritative, ZK-safe
        # unread-@mention count (Task #280); never derived from ciphertext.
        user_group_id: ug && ug.id,
        member_count: member_count,
        unread_mention_count: 0
      }
    end)
    |> put_unread_mention_counts()
  end

  # Recompute the per-circle unread @mention count (Task #280) over already-built
  # family-circle view-models. Server-authoritative + ZK-safe: counts come from
  # `GroupMessageMention` records keyed on the viewer's `user_group_id`, returned
  # as `%{group_id => count}`. Used in mount and on every realtime `new_message`.
  defp put_unread_mention_counts(circles) do
    user_group_ids =
      circles |> Enum.map(& &1.user_group_id) |> Enum.reject(&is_nil/1)

    counts = GroupMessages.get_unread_mention_counts_by_group(user_group_ids)

    Enum.map(circles, fn circle ->
      %{circle | unread_mention_count: Map.get(counts, circle.group.id, 0)}
    end)
  end

  # Subscribe to each family circle's `group:#{id}` PubSub topic (Task #280) so a
  # new message anywhere refreshes the unread-@mention badge live. Subscribing is
  # NOT idempotent (a repeat yields duplicate messages), so this runs exactly once
  # in mount — never on data refresh.
  defp subscribe_to_family_circles(circles) do
    Enum.each(circles, fn %{group: group} -> Groups.group_subscribe(group) end)
  end

  defp maybe_subscribe_to_family_circles(socket, false), do: socket

  defp maybe_subscribe_to_family_circles(socket, true) do
    subscribe_to_family_circles(socket.assigns.family_circles)
    socket
  end

  defp random_avatar do
    Enum.random(
      ~w(astronaut.png bear.png cat.png chicken.png dinosaur.png dog.png panda.png penguin.png rabbit.png sea-lion.png)
    )
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
          members:
            MossletWeb.Helpers.hydrate_sealed_pins(
              MossletWeb.OrgIdentity.members_to_seal(org),
              to_string(socket.assigns.current_scope.user.id)
            )
        })

      true ->
        socket
    end
  end

  # Family guardian safety override (Task #284): when the viewer is a managed
  # member whose guardian(s) still need a sealed copy of their conn_key, ask the
  # viewer's browser (GuardianAvatarSeal hook) to seal it. The recipient set is
  # server-authoritative (I1) — built from the active guardianship rows.
  defp maybe_request_avatar_key_seal(socket) do
    targets = socket.assigns.guardian_avatar_seal_targets

    if connected?(socket) and targets != [] do
      push_event(socket, "seal_avatar_key_for_guardians", %{
        guardians:
          MossletWeb.Helpers.hydrate_sealed_pins(
            targets,
            to_string(socket.assigns.current_scope.user.id)
          )
      })
    else
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
  # Whether to show the inline "edit display name" affordance on a roster row
  # (Task #264 parity). Requires the viewer to hold the org_key (else they can't
  # encrypt). The viewer may re-edit their OWN name once set — the first-time
  # prompt covers the unset case; admins may edit anyone's.
  defp show_edit_name?(_member, nil, _can_manage?), do: false

  defp show_edit_name?(%{self?: true} = member, _sealed, _can_manage?),
    do: not is_nil(member.encrypted_display_name)

  defp show_edit_name?(%{self?: false}, _sealed, can_manage?), do: can_manage?

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

  # Resolves a guardian's display name for the managed member's transparency
  # surfaces. When the guardian is also a personal connection, the server can
  # decrypt the name directly. Otherwise there is NO personal UserConnection (the
  # common Family case) so we fall back to the ZK family `org_key` path (Task
  # #225/#270): the server returns the viewer's sealed org_key + the guardian's
  # org_key-sealed display name, and the `DecryptComposerGuardians` hook resolves
  # the real name in the browser. Returns a neutral "Family member" placeholder
  # when no org name is set (or the viewer doesn't yet hold the org_key).
  defp guardian_name_entry(guardian_user, current_user, key) do
    case Mosslet.Accounts.get_user_connection_between_users(guardian_user.id, current_user.id) do
      %{} = uconn ->
        uconn = Mosslet.Repo.preload(uconn, :connection)

        %{
          name: get_decrypted_connection_name(uconn, current_user, key),
          sealed_org_key: nil,
          encrypted_display_name: nil
        }

      _ ->
        case Orgs.org_name_resolution_between_users(current_user.id, guardian_user.id) do
          %{sealed_org_key: sealed_org_key, encrypted_display_name: encrypted_display_name} ->
            %{
              name: "Family member",
              sealed_org_key: sealed_org_key,
              encrypted_display_name: encrypted_display_name
            }

          _ ->
            %{name: "Family member", sealed_org_key: nil, encrypted_display_name: nil}
        end
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

  # Server-authoritative guardianship action gate (I1). Loads the guardianship,
  # confirms it belongs to THIS org, and runs `auth_fun.(guardianship, user,
  # membership)` before performing `action_fun.(guardianship, socket)`. Any
  # unauthorized or cross-org attempt is refused with a flash — the buttons are
  # never the only line of defense.
  defp with_authorized_guardianship(socket, id, auth_fun, action_fun) do
    guardianship = Orgs.get_guardianship!(id)
    current_user = socket.assigns.current_scope.user
    membership = socket.assigns.membership

    if guardianship.org_id == socket.assigns.org.id and
         auth_fun.(guardianship, current_user, membership) do
      {:noreply, action_fun.(guardianship, socket)}
    else
      {:noreply, put_flash(socket, :error, "You're not allowed to change that guardianship.")}
    end
  end

  # Accept/Decline: only the MANAGED member of the guardianship (their consent).
  defp consent_actor?(guardianship, current_user, _membership),
    do: guardianship.managed_membership.user_id == current_user.id

  # Pause/Resume (the privacy toggle, DESIGN §0): the managed member themselves,
  # the guardian, or an org admin — anyone with a legitimate stake in the link.
  defp can_toggle_guardianship?(guardianship, current_user, membership) do
    membership.role == :admin or
      guardianship.guardian_membership.user_id == current_user.id or
      guardianship.managed_membership.user_id == current_user.id
  end

  # Revoke (delete the relationship): admin or guardian only. The managed member
  # pauses instead — pause is reversible and stops all future co-sealing too.
  defp can_revoke_guardianship?(guardianship, current_user, membership) do
    membership.role == :admin or
      guardianship.guardian_membership.user_id == current_user.id
  end

  defp establish_error_message(:different_orgs), do: "Both members must be in this family."

  defp establish_error_message(:guardian_role_required),
    do: "Guardian must be a Guardian or the family owner."

  defp establish_error_message(:managed_member_role_required),
    do: "Managed member must have the Managed role."

  defp establish_error_message(:already_exists), do: "That guardianship already exists."
  defp establish_error_message(_), do: "Could not create guardianship."
end
