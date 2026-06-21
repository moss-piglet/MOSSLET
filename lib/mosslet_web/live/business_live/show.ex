defmodule MossletWeb.BusinessLive.Show do
  @moduledoc """
  Business org dashboard: org member management (invite / change role / remove),
  explicit offboarding (Q5), and the business-circles panel with an org-scoped
  ZK circle composer.

  Business orgs do NOT use guardianship. A business circle is just a private,
  org-restricted Mosslet circle — membership is the only access-control
  mechanism. See `docs/BUSINESS_CIRCLES_DESIGN.md`.
  """
  use MossletWeb, :live_view

  import MossletWeb.OrgTransferActions
  import MossletWeb.OrgDeleteActions

  alias Mosslet.Accounts
  alias Mosslet.Announcements
  alias Mosslet.Files
  alias Mosslet.FileUploads.SharedFileStorage
  alias Mosslet.GroupMessages
  alias Mosslet.Groups
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Audit
  alias Mosslet.Orgs.Org
  alias Mosslet.Pins

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    org = Orgs.get_org!(current_user, slug)
    membership = Orgs.get_membership!(current_user, slug)

    if org.type == :business do
      if connected?(socket) do
        Orgs.subscribe_org(org)
        # Realtime shared-file changes across the org's circles (Task #232): a
        # file uploaded, removed, or caught-up in any circle refreshes the
        # "Files across your circles" overview live (no reload). Ids only.
        Files.subscribe_org_files(org.id)
        # Personal-connection events (Task #226): reflect a teammate accepting
        # our "Connect" request live — the requester is notified on their own
        # accounts topic when the reverse UserConnection is created on accept.
        Accounts.private_subscribe(current_user)
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
       |> assign(:show_circle_form?, false)
       |> assign(:circle_form, to_form(%{"name" => "", "description" => ""}, as: :circle))
       |> assign(:show_announcement_form?, false)
       |> assign(
         :announcement_form,
         to_form(%{"title" => "", "body" => "", "priority" => "normal"}, as: :announcement)
       )
       |> assign(:show_pin_form?, false)
       |> assign(:pin_form_scope, :personal)
       |> assign(:pin_form, to_form(%{"label" => "", "url" => ""}, as: :pin))
       |> assign(:pending_zk_circle_attrs, nil)
       |> assign(:pending_zk_circle_users, nil)
       |> assign(:pending_zk_circle_type, :community)
       |> assign(:manage_circle_id, nil)
       |> assign(:manage_circle, nil)
       |> assign(:pending_add_member_ids, [])
       |> assign(:transfer_modal_open, false)
       |> assign(:transfer_form, to_form(%{"password" => "", "to_user_id" => ""}, as: :transfer))
       |> assign(:delete_modal_open, false)
       |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete_org))
       |> assign(:logo_upload_stage, nil)
       |> assign(:pending_logo_preview, nil)
       |> assign(:manage_open?, false)
       |> assign(:file_sort, :newest)
       |> allow_upload(:org_logo,
         accept: ~w(.jpg .jpeg .png .webp .heic .heif),
         auto_upload: true,
         max_entries: 1,
         max_file_size: 5_000_000,
         progress: &handle_logo_progress/3,
         writer: fn _name, entry, _socket ->
           {Mosslet.FileUploads.OrgLogoUploadWriter,
            %{
              lv_pid: self(),
              entry_ref: entry.ref,
              expected_size: entry.client_size
            }}
         end
       )
       |> assign_business_data()
       |> maybe_subscribe_to_business_circles(connected?(socket))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Not a business organization")
       |> push_navigate(to: ~p"/app/business")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      current_page={:business}
      sidebar_current_page={:business}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8 lg:py-10 space-y-6 lg:space-y-8">
        <header class="flex items-center gap-3">
          <.link
            navigate={~p"/app/business"}
            class="p-2 -ml-2 rounded-xl text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-800/60 transition-all duration-200"
            aria-label="Back to businesses"
          >
            <.phx_icon name="hero-arrow-left" class="size-5" />
          </.link>
          <div class="flex items-center gap-3 min-w-0">
            <.org_logo
              id="org-header-logo"
              logo_url={@org_logo_url}
              sealed_org_key={@viewer_sealed_org_key}
              frame_class="h-12 w-12 rounded-2xl"
              alt={@org.name <> " logo"}
            >
              <:fallback>
                <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
                  <.phx_icon name="hero-building-office" class="h-6 w-6 text-white" />
                </div>
              </:fallback>
            </.org_logo>
            <div class="min-w-0">
              <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 truncate">
                {@org.name}
              </h1>
              <div class="flex items-center gap-2">
                <.business_role_badge role={@membership.role} />
              </div>
            </div>
          </div>
        </header>

        <.org_coverage_notice status={@coverage_status} />

        <%!-- Branded space pointer (Task #246). Visible to ALL members once the
             org's custom subdomain is live. We keep in-app navigation path-only
             (single-origin per session), so this is the one intentional
             cross-host link: an absolute <a> to the branded host. The "Open" CTA
             only shows when the member is NOT already on the subdomain. --%>
        <div
          :if={@subdomain_live?}
          id="org-branded-space"
          class="rounded-2xl border border-teal-200/70 dark:border-teal-800/50 bg-gradient-to-br from-teal-50/80 to-emerald-50/50 dark:from-teal-900/20 dark:to-emerald-900/10 p-4 sm:p-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="flex items-start gap-3 min-w-0">
            <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/70 dark:bg-slate-800/60 text-teal-600 dark:text-teal-400">
              <.phx_icon name="hero-globe-alt" class="size-5" />
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold text-teal-900 dark:text-teal-200">
                Your branded space
              </p>
              <p class="text-xs text-teal-800/80 dark:text-teal-300/80 break-all">
                {subdomain_display_url(@org.subdomain)}
              </p>
            </div>
          </div>
          <div class="shrink-0">
            <span
              :if={@on_org_subdomain?}
              id="org-branded-space-here"
              class="inline-flex items-center gap-1.5 rounded-full bg-emerald-100 dark:bg-emerald-900/40 px-3 py-1.5 text-xs font-medium text-emerald-700 dark:text-emerald-300"
            >
              <.phx_icon name="hero-check-circle" class="size-4" /> You're on it
            </span>
            <a
              :if={!@on_org_subdomain?}
              id="org-branded-space-open"
              href={@org_branded_url}
              class="inline-flex items-center gap-2 rounded-xl bg-gradient-to-r from-teal-500 to-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm shadow-emerald-500/25 transition-all duration-200 hover:from-teal-600 hover:to-emerald-700 hover:shadow-md"
            >
              <.phx_icon name="hero-arrow-top-right-on-square" class="size-4" /> Open branded space
            </a>
          </div>
        </div>

        <%!-- Pinned strip (Task #229d): quick-access shortcuts to circles, files,
             and links. Two scopes — org-wide (curated by owner/admin) and the
             viewer's own personal pins. Link labels/URLs are encrypted on each
             device (user_key / org_key); circle/file pins reuse the already-
             decrypted name (FK-only). ZK throughout. --%>
        <.pinned_strip
          org={@org}
          sealed_org_key={@viewer_sealed_org_key}
          org_shared_pins={@org_shared_pins}
          personal_pins={@personal_pins}
          can_manage_org_pins?={@can_manage_org_pins?}
          can_pin_personal?={@can_pin_personal?}
          show_pin_form?={@show_pin_form?}
          pin_form={@pin_form}
          pin_form_scope={@pin_form_scope}
        />

        <%!-- Everyday surfaces — members, circles, and files — get the prominent
             real-estate. On lg+ they fan out into a responsive multi-column grid;
             on mobile they stack into one column (Task #248). --%>
        <div class="grid grid-cols-1 gap-6 lg:grid-cols-12 lg:gap-8 lg:items-start">
          <%!-- Member management. On lg+ this is the right-hand "who's here" rail
               (col-span-4); the everyday-work column below takes the prominent
               col-span-8. `order` keeps the work surfaces first on every
               breakpoint (incl. mobile) regardless of source order (Task #263). --%>
          <section class="order-2 lg:col-span-4 rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Members</h2>
              <span
                id="business-seat-usage"
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
              :if={@is_owner? && @seats.available == 0}
              id="business-seat-full-notice"
              class="rounded-lg bg-amber-50 dark:bg-amber-900/20 px-3 py-2 text-xs text-amber-800 dark:text-amber-300"
            >
              All seats are in use (including pending invites).
              <a
                href="#org-seat-management"
                phx-click="open_manage"
                class="font-semibold underline hover:no-underline"
              >
                Add more seats
              </a>
              to invite another teammate.
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
              >
                <div class="flex items-center gap-3 min-w-0">
                  <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                    <.phx_icon name="hero-user" class="size-4" />
                  </div>
                  <div class="min-w-0">
                    <div class="flex items-center gap-2">
                      <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                        <span {MossletWeb.OrgIdentity.org_name_target(member)}>
                          {MossletWeb.OrgIdentity.placeholder_label(member)}
                        </span>
                      </p>
                      <.business_role_badge role={member.membership.role} />
                      <span
                        :if={Orgs.owner?(@org, member.user.id)}
                        id={"owner-badge-#{member.user.id}"}
                        class="inline-flex items-center gap-1 rounded-full bg-amber-100 dark:bg-amber-900/40 px-2.5 py-0.5 text-xs font-medium text-amber-700 dark:text-amber-300"
                      >
                        <.phx_icon name="hero-key" class="size-3" /> Owner
                      </span>
                    </div>
                  </div>
                </div>

                <div class="flex flex-wrap items-center justify-end gap-2 min-w-0">
                  <%!-- Edit display name (Task #263). The viewer can rename
                     themselves (re-edit; the first-time prompt below covers the
                     unset case), and admins/owners can rename anyone — e.g. a
                     teammate who marries or simply wants a different persona. The
                     name is re-encrypted browser-side with the shared org_key
                     (ZK); the server only authorizes + stores ciphertext. --%>
                  <button
                    :if={show_edit_name?(member, @viewer_sealed_org_key, @can_manage?)}
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
                     UserConnection invite to a member you're not yet connected
                     to. Once accepted, their real personal name lights up via the
                     existing resolution path. --%>
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

                  <%!-- Owner is the org's billing/coverage anchor and can't be
                     role-changed or removed by an admin (ownership transfer is the
                     only path — Task #237). --%>
                  <div
                    :if={
                      @can_manage? && member.user.id != @current_scope.user.id &&
                        !Orgs.owner?(@org, member.user.id)
                    }
                    class="flex items-center gap-2"
                  >
                    <form phx-change="change_role" id={"role-form-#{member.user.id}"}>
                      <input type="hidden" name="user_id" value={member.user.id} />
                      <select
                        name="role"
                        class="rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-700 text-xs py-1.5 focus:border-emerald-500 focus:ring-emerald-500/30"
                      >
                        <option value="member" selected={member.membership.role == :member}>
                          Member
                        </option>
                        <option value="admin" selected={member.membership.role == :admin}>
                          Admin
                        </option>
                      </select>
                    </form>
                    <.liquid_button
                      variant="ghost"
                      color="rose"
                      size="sm"
                      icon="hero-user-minus"
                      phx-click="offboard_member"
                      phx-value-user_id={member.user.id}
                      id={"offboard-#{member.user.id}"}
                      data-confirm="Remove this person from the organization and from all of this org's business circles? We can't recall content they've already downloaded."
                    >
                      Remove
                    </.liquid_button>
                  </div>
                </div>

                <%!-- Inline edit-name form (Task #263). Lives inside the row but
                     wraps to its own line (`basis-full`). The OrgDisplayNameFormHook
                     decrypts `data-current-encrypted-name` to PREFILL the input
                     and, on submit, re-encrypts with the org_key and pushes
                     `save_org_display_name` carrying `target_user_id` so the
                     server stores it on the right membership (re-authorized). --%>
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
                      label={if member.self?, do: "Your team display name", else: "Team display name"}
                      placeholder="e.g. Mark — Engineering"
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

            <%!-- Org display-name prompt (Task #225): the member sets how their
               team sees them. Shown when they hold the org_key but haven't set a
               name yet. Encrypted browser-side with the org_key. --%>
            <div
              :if={@viewer_sealed_org_key && is_nil(@membership.display_name)}
              id="org-display-name-prompt"
              class="rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-teal-50/60 dark:bg-teal-900/20 p-4"
            >
              <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                Set how your team sees you
              </p>
              <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                Your teammates can't read your personal name unless you're connected. Choose an
                org display name (e.g. "Mark — Engineering"). It's encrypted on your device.
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
                    placeholder="Your team display name"
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
              can_manage={@can_manage?}
            />

            <%!-- Invite member (admin) --%>
            <div
              :if={@can_manage?}
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
                    placeholder="teammate@example.com"
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

          <div class="order-1 space-y-6 lg:col-span-8">
            <%!-- Org-wide ZK announcements (Task #229c): owner/admin author
                 notices encrypted with the org_key; everyone reads them
                 decrypted browser-side. --%>
            <.announcements_panel
              tier={:org}
              sealed_key={@viewer_sealed_org_key}
              can_post?={@can_post_announcement?}
              show_form?={@show_announcement_form?}
              form={@announcement_form}
              banner={@announcement_banner}
              recent={@announcement_recent}
              unread_count={@announcement_unread_count}
              current_user_id={@current_scope.user.id}
            />
            <%!-- Business circles panel --%>
            <section class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4">
              <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div class="min-w-0">
                  <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                    Business circles
                  </h2>
                  <p class="mt-1 text-sm leading-relaxed text-slate-500 dark:text-slate-400">
                    Private circles restricted to this org's members. Each circle has its own
                    end-to-end encrypted chat.
                  </p>
                </div>
                <.liquid_button
                  :if={!@show_circle_form?}
                  phx-click="show_circle_form"
                  id="new-circle-button"
                  color="emerald"
                  size="md"
                  icon="hero-plus"
                  class="w-full shrink-0 sm:w-auto"
                >
                  New circle
                </.liquid_button>
              </div>

              <div
                :if={@show_circle_form?}
                id="new-circle-form-wrapper"
                class="rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-gradient-to-br from-slate-50/80 to-slate-100/50 dark:from-slate-800/50 dark:to-slate-900/30 p-4"
              >
                <.form
                  for={@circle_form}
                  id="new-circle-form"
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
                  <input
                    :for={member <- @eligible_members}
                    type="hidden"
                    name="group[user_connections][]"
                    value={member.user.id}
                  />

                  <.phx_input
                    field={@circle_form[:name]}
                    name="group[name]"
                    type="text"
                    label="Circle name"
                    placeholder="e.g. Engineering"
                  />
                  <.phx_input
                    field={@circle_form[:description]}
                    name="group[description]"
                    type="text"
                    label="Description"
                    placeholder="What is this circle about?"
                  />

                  <%!-- Circle classification (#229b). Official "Department / Team"
                   circles are authority-gated to org owners/admins; everyone
                   else creates a "Community" circle (a hidden input pins the
                   value, and the server re-checks authority on write). The JS
                   ZK hook reads the chosen value and forwards it. --%>
                  <div :if={@can_create_team_circle?}>
                    <span class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                      Circle type
                    </span>
                    <div class="grid grid-cols-2 gap-2">
                      <label class="relative cursor-pointer">
                        <input
                          type="radio"
                          name="group[org_circle_type]"
                          value="team"
                          class="peer sr-only"
                        />
                        <div class="h-full rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900/40 p-3 transition-all peer-checked:border-teal-500 peer-checked:ring-2 peer-checked:ring-teal-500/30 peer-checked:bg-teal-50/60 dark:peer-checked:bg-teal-900/20">
                          <div class="flex items-center gap-2">
                            <.phx_icon
                              name="hero-building-office-2"
                              class="size-4 text-teal-600 dark:text-teal-400"
                            />
                            <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                              Department / Team
                            </span>
                          </div>
                          <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                            Official, org-branded space.
                          </p>
                        </div>
                      </label>
                      <label class="relative cursor-pointer">
                        <input
                          type="radio"
                          name="group[org_circle_type]"
                          value="community"
                          checked
                          class="peer sr-only"
                        />
                        <div class="h-full rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900/40 p-3 transition-all peer-checked:border-teal-500 peer-checked:ring-2 peer-checked:ring-teal-500/30 peer-checked:bg-teal-50/60 dark:peer-checked:bg-teal-900/20">
                          <div class="flex items-center gap-2">
                            <.phx_icon
                              name="hero-user-group"
                              class="size-4 text-slate-400 dark:text-slate-500"
                            />
                            <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                              Community
                            </span>
                          </div>
                          <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                            Casual, member-made circle.
                          </p>
                        </div>
                      </label>
                    </div>
                  </div>
                  <input
                    :if={!@can_create_team_circle?}
                    type="hidden"
                    name="group[org_circle_type]"
                    value="community"
                  />

                  <p class="text-xs text-slate-500 dark:text-slate-400">
                    All current org members you're connected to will be added. Only org members can
                    be added to a business circle.
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
                      id="create-circle-submit"
                      color="emerald"
                      icon="hero-sparkles"
                      phx-disable-with="Creating..."
                    >
                      Create circle
                    </.liquid_button>
                  </div>
                </.form>
              </div>

              <%!-- Two distinctly-branded tiers (#229b): official "Departments &
               Teams" (org owner/admin curated) vs lighter "Community circles"
               (member-made). Names stay encrypted and decrypt browser-side. --%>
              <div :if={@team_circles != []} class="space-y-2">
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-building-office-2"
                    class="size-4 text-teal-600 dark:text-teal-400"
                  />
                  <h3 class="text-xs font-semibold uppercase tracking-wide text-teal-700 dark:text-teal-300">
                    Departments &amp; Teams
                  </h3>
                </div>
                <ul role="list" class="space-y-2">
                  <.circle_card
                    :for={circle <- @team_circles}
                    circle={circle}
                    tier={:team}
                    manage_circle={@manage_circle}
                    org={@org}
                    current_user_id={@current_scope.user.id}
                    viewer_sealed_org_key={@viewer_sealed_org_key}
                    can_manage_org_pins?={@can_manage_org_pins?}
                    personal_pinned?={MapSet.member?(@personal_pinned_circle_ids, circle.group.id)}
                    org_pinned?={MapSet.member?(@org_pinned_circle_ids, circle.group.id)}
                  />
                </ul>
              </div>

              <div :if={@community_circles != []} class="space-y-2">
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-user-group"
                    class="size-4 text-slate-400 dark:text-slate-500"
                  />
                  <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                    Community circles
                  </h3>
                </div>
                <ul role="list" class="space-y-2">
                  <.circle_card
                    :for={circle <- @community_circles}
                    circle={circle}
                    tier={:community}
                    manage_circle={@manage_circle}
                    org={@org}
                    current_user_id={@current_scope.user.id}
                    viewer_sealed_org_key={@viewer_sealed_org_key}
                    can_manage_org_pins?={@can_manage_org_pins?}
                    personal_pinned?={MapSet.member?(@personal_pinned_circle_ids, circle.group.id)}
                    org_pinned?={MapSet.member?(@org_pinned_circle_ids, circle.group.id)}
                  />
                </ul>
              </div>

              <p
                :if={@circles == [] && !@show_circle_form?}
                class="text-xs text-slate-500 dark:text-slate-400"
              >
                No business circles yet. Create one to start a private, encrypted team space.
              </p>
            </section>
            <%!-- Org-wide files overview (Task #221): every file the viewer can read
             across this org's circles, grouped by circle. Names stay encrypted
             and decrypt browser-side (ZK). Tap a circle to open it. --%>
            <section
              :if={@org_file_circles != []}
              id="org-files-overview"
              phx-hook="OrgFileSearch"
              class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
            >
              <div class="flex items-start gap-3">
                <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-violet-100 text-violet-600 dark:bg-violet-900/40 dark:text-violet-300">
                  <.phx_icon name="hero-folder" class="size-5" />
                </span>
                <div class="min-w-0">
                  <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                    Files across your circles
                  </h2>
                  <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                    Everything shared with circles you're in. Encrypted on each member's device —
                    Mosslet can't read them.
                  </p>
                </div>
              </div>

              <%!-- Find-things-fast toolbar (#229a). Filename SEARCH is client-side
                   (ZK — names only exist decrypted in the browser, via the
                   DecryptSharedFileName hook); the OrgFileSearch hook filters rows
                   by their decrypted text. SORT uses only server-visible metadata
                   (upload time / size) and is handled server-side. --%>
              <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
                <div id="org-file-search-bar" phx-update="ignore" class="relative flex-1">
                  <.phx_icon
                    name="hero-magnifying-glass"
                    class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 size-4 text-slate-400 dark:text-slate-500"
                  />
                  <input
                    type="text"
                    data-file-search
                    id="org-file-search-input"
                    autocomplete="off"
                    spellcheck="false"
                    placeholder="Search files by name…"
                    aria-label="Search files by name"
                    class="w-full rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900/60 py-2 pl-9 pr-9 text-sm text-slate-900 dark:text-slate-100 placeholder:text-slate-400 dark:placeholder:text-slate-500 focus:border-teal-500 focus:ring-teal-500"
                  />
                  <button
                    type="button"
                    data-file-search-clear
                    hidden
                    aria-label="Clear search"
                    class="absolute right-2 top-1/2 -translate-y-1/2 rounded-lg p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
                  >
                    <.phx_icon name="hero-x-mark" class="size-4" />
                  </button>
                </div>
                <form phx-change="sort_files" class="shrink-0">
                  <label for="org-file-sort" class="sr-only">Sort files</label>
                  <select
                    id="org-file-sort"
                    name="sort"
                    class="rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900/60 py-2 pl-3 pr-8 text-sm text-slate-700 dark:text-slate-200 focus:border-teal-500 focus:ring-teal-500"
                  >
                    <option value="newest" selected={@file_sort == :newest}>Newest first</option>
                    <option value="oldest" selected={@file_sort == :oldest}>Oldest first</option>
                    <option value="largest" selected={@file_sort == :largest}>Largest first</option>
                    <option value="smallest" selected={@file_sort == :smallest}>
                      Smallest first
                    </option>
                  </select>
                </form>
              </div>

              <p class="text-xs text-slate-500 dark:text-slate-400">
                <span data-file-count></span>
              </p>

              <div
                data-file-empty
                hidden
                class="rounded-xl border border-dashed border-slate-300 dark:border-slate-600 px-4 py-6 text-center text-sm text-slate-500 dark:text-slate-400"
              >
                No files match “<span data-file-empty-query class="font-medium"></span>”.
              </div>

              <%!-- Files grouped by circle, split into the two #229b tiers so
               official department files read distinctly from community ones.
               Each tier wrapper carries `data-file-tier` so the OrgFileSearch
               hook can hide an entire empty tier (heading included) while a
               filename query is active. --%>
              <div :if={@team_file_circles != []} data-file-tier class="space-y-3">
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-building-office-2"
                    class="size-4 text-teal-600 dark:text-teal-400"
                  />
                  <h3 class="text-xs font-semibold uppercase tracking-wide text-teal-700 dark:text-teal-300">
                    Departments &amp; Teams
                  </h3>
                </div>
                <.file_circle_block
                  :for={entry <- @team_file_circles}
                  entry={entry}
                  tier={:team}
                  org={@org}
                  can_manage_org_pins?={@can_manage_org_pins?}
                  personal_pinned_file_ids={@personal_pinned_file_ids}
                  org_pinned_file_ids={@org_pinned_file_ids}
                />
              </div>

              <div :if={@community_file_circles != []} data-file-tier class="space-y-3">
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-user-group"
                    class="size-4 text-slate-400 dark:text-slate-500"
                  />
                  <h3 class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
                    Community circles
                  </h3>
                </div>
                <.file_circle_block
                  :for={entry <- @community_file_circles}
                  entry={entry}
                  tier={:community}
                  org={@org}
                  can_manage_org_pins?={@can_manage_org_pins?}
                  personal_pinned_file_ids={@personal_pinned_file_ids}
                  org_pinned_file_ids={@org_pinned_file_ids}
                />
              </div>
            </section>
          </div>
        </div>

        <%!-- ADMINISTRATION band (Task #263). Secondary, owner/admin-only zone —
             the accountability feed plus one-time setup — grouped under a single
             full-width divider so it reads as a deliberate "admin" footer rather
             than an abrupt narrow column after the everyday-work grid above. --%>
        <section
          :if={@can_view_audit_log? || @can_manage_branding? || @is_owner? || @incoming_transfer?}
          id="org-admin-band"
          class="space-y-6"
        >
          <div class="flex items-center gap-3 pt-2">
            <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-slate-100 dark:bg-slate-700/60 text-slate-500 dark:text-slate-400">
              <.phx_icon name="hero-lock-closed" class="size-5" />
            </span>
            <div class="min-w-0">
              <h2 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                Administration
              </h2>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Accountability and one-time setup — visible only to owners and admins.
              </p>
            </div>
            <span class="ml-2 hidden h-px flex-1 bg-slate-200/70 dark:bg-slate-700/60 sm:block"></span>
          </div>

          <%!-- Match the admin panels to the everyday-work column width above
               (the files/circles card spans `lg:col-span-8` of the same 12-col,
               `gap-8` grid), so the left edge AND right edge align with the cards
               above — no narrower mismatch, no sparse full-bleed (Task #263). --%>
          <div class="grid grid-cols-1 lg:grid-cols-12 lg:gap-8">
            <div class="space-y-6 lg:col-span-8">
              <%!-- ZK admin activity log (Task #212, §12 of BUSINESS_CIRCLES_DESIGN.md).
                 Owner/admin-only, READ-ONLY, APPEND-ONLY accountability feed. The
                 server stores only opaque ids + a non-sensitive action category +
                 timestamp (no readable content); the human-readable description is
               reconstructed CLIENT-SIDE by the AuditLog hook from the org_key the
               admin already holds (member display names). A "Download" button
               exports a local copy (client-side, ZK) — useful day-to-day and as the
               owner's final snapshot before deleting the org. --%>
              <section
                :if={@can_view_audit_log?}
                id="org-audit-log"
                phx-hook="AuditLog"
                data-sealed-org-key={@viewer_sealed_org_key}
                data-member-directory={@audit_member_directory}
                class="space-y-4"
              >
                <div class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm overflow-hidden">
                  <header class="flex items-center justify-between gap-3 px-5 py-4 border-b border-slate-100 dark:border-slate-700/60">
                    <div class="flex items-center gap-3 min-w-0">
                      <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-slate-100 dark:bg-slate-700/60 text-slate-500 dark:text-slate-400">
                        <.phx_icon name="hero-shield-check" class="size-5" />
                      </span>
                      <div class="min-w-0">
                        <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                          Activity log
                        </h2>
                        <p class="text-xs text-slate-500 dark:text-slate-400">
                          A tamper-proof, zero-knowledge record of admin actions — visible only to owners and admins.
                        </p>
                      </div>
                    </div>
                    <.liquid_button
                      :if={@audit_events != []}
                      type="button"
                      variant="secondary"
                      size="sm"
                      icon="hero-arrow-down-tray"
                      id="org-audit-export"
                      data-audit-export
                    >
                      Download
                    </.liquid_button>
                  </header>

                  <ol id="org-audit-events" class="divide-y divide-slate-100 dark:divide-slate-700/60">
                    <li
                      :if={@audit_events == []}
                      id="org-audit-empty"
                      class="px-5 py-8 text-center text-sm text-slate-500 dark:text-slate-400"
                    >
                      No admin activity yet. Actions like adding members, changing roles, creating circles, and sharing files will appear here.
                    </li>
                    <li
                      :for={event <- @audit_events}
                      id={"audit-#{event.id}"}
                      class="px-5 py-3 flex items-start gap-3"
                      data-audit-row
                      data-audit-action={event.action}
                      data-audit-actor-id={event.actor_id}
                      data-audit-target-id={event.target_id}
                      data-audit-target-type={event.target_type}
                      data-audit-at={NaiveDateTime.to_iso8601(event.inserted_at)}
                    >
                      <span class="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-slate-100 dark:bg-slate-700/60 text-slate-500 dark:text-slate-400">
                        <.phx_icon name={audit_action_icon(event.action)} class="size-4" />
                      </span>
                      <div class="min-w-0 flex-1">
                        <p class="text-sm text-slate-700 dark:text-slate-200" data-audit-text>
                          {audit_action_label(event.action)}
                        </p>
                      </div>
                      <p class="shrink-0 text-right text-xs leading-snug text-slate-400 dark:text-slate-500">
                        <time class="block tabular-nums">
                          {Calendar.strftime(event.inserted_at, "%b %-d, %Y · %H:%M UTC")}
                        </time>
                        <span
                          data-audit-local
                          class="hidden tabular-nums text-emerald-600 dark:text-emerald-400"
                        ></span>
                      </p>
                    </li>
                  </ol>
                </div>
              </section>

              <%!-- One-time SETUP — branding, seats, and ownership — tucked into a
             collapsible, accessible disclosure (default collapsed) so the
             dashboard stays focused on everyday work (Task #248). Native button
             disclosure (no PetalComponents); children stay in the DOM and toggle
             via a CSS class so deep links + tests still resolve. --%>
              <section
                :if={@can_manage_branding? || @is_owner? || @incoming_transfer?}
                id="org-manage"
                class="space-y-4"
              >
                <button
                  type="button"
                  id="org-manage-toggle"
                  phx-click="toggle_manage"
                  aria-expanded={to_string(@manage_open?)}
                  aria-controls="org-manage-panel"
                  class="group flex w-full items-center justify-between gap-3 rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm px-5 py-4 text-left transition-all duration-200 hover:border-slate-300 dark:hover:border-slate-600"
                >
                  <span class="flex items-center gap-3 min-w-0">
                    <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-slate-100 dark:bg-slate-700/60 text-slate-500 dark:text-slate-400 transition-colors group-hover:text-teal-600 dark:group-hover:text-teal-400">
                      <.phx_icon name="hero-cog-6-tooth" class="size-5" />
                    </span>
                    <span class="min-w-0">
                      <span class="block text-base font-semibold text-slate-900 dark:text-slate-100">
                        Manage organization
                      </span>
                      <span class="block text-xs text-slate-500 dark:text-slate-400">
                        Branding, seats, and ownership — one-time setup
                      </span>
                    </span>
                  </span>
                  <.phx_icon
                    name="hero-chevron-down"
                    class={[
                      "size-5 shrink-0 text-slate-400 transition-transform duration-200",
                      @manage_open? && "rotate-180"
                    ]}
                  />
                </button>

                <div
                  id="org-manage-panel"
                  role="region"
                  aria-labelledby="org-manage-toggle"
                  class={["space-y-6", !@manage_open? && "hidden"]}
                >
                  <%!-- Branding (Task #228, branding add-on): owner/admin can upload a
             brand logo. The logo is encrypted browser-side with the per-org
             org_key (ZK) and surfaced across the org dashboard + circle/file
             UIs. Shown only to those who can manage branding. --%>
                  <section
                    :if={@can_manage_branding?}
                    id="org-branding"
                    class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div class="min-w-0">
                        <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                          Branding
                        </h2>
                        <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                          Upload your organization's logo. It's encrypted on your device with your team's
                          key — we never see the original image.
                        </p>
                      </div>
                    </div>

                    <div
                      id="org-logo-uploader"
                      phx-hook="OrgLogoUpload"
                      data-sealed-org-key={@viewer_sealed_org_key}
                    >
                    </div>

                    <.form
                      for={%{}}
                      id="org-logo-form"
                      phx-change="validate_org_logo"
                      phx-submit="validate_org_logo"
                      class="flex flex-col gap-4 sm:flex-row sm:items-center"
                    >
                      <div class="flex h-20 w-20 shrink-0 items-center justify-center rounded-2xl border border-slate-200/70 dark:border-slate-700/70 bg-slate-50 dark:bg-slate-900/40 overflow-hidden">
                        <%= cond do %>
                          <% @pending_logo_preview -> %>
                            <img
                              id="org-logo-preview-pending"
                              src={@pending_logo_preview}
                              alt="Logo preview"
                              class="h-full w-full object-contain"
                            />
                          <% @org.logo_url && @org_logo_url && @viewer_sealed_org_key -> %>
                            <.org_logo
                              id="org-logo-preview-current"
                              logo_url={@org_logo_url}
                              sealed_org_key={@viewer_sealed_org_key}
                              frame_class="h-full w-full border-0 bg-transparent"
                              icon_class="h-8 w-8 text-slate-300 dark:text-slate-600"
                              alt={@org.name <> " logo"}
                            >
                              <:fallback>
                                <.phx_icon
                                  name="hero-building-office"
                                  class="h-8 w-8 text-slate-300 dark:text-slate-600"
                                />
                              </:fallback>
                            </.org_logo>
                          <% true -> %>
                            <.phx_icon
                              name="hero-building-office"
                              class="h-8 w-8 text-slate-300 dark:text-slate-600"
                            />
                        <% end %>
                      </div>

                      <div class="flex-1 space-y-2">
                        <label
                          for={@uploads.org_logo.ref}
                          class="inline-flex cursor-pointer items-center gap-2 rounded-xl border border-slate-200 dark:border-slate-700 px-3 py-2 text-sm font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700/40 transition-colors"
                        >
                          <.phx_icon name="hero-arrow-up-tray" class="size-4" />
                          {if @org.logo_url, do: "Replace logo", else: "Upload logo"}
                        </label>
                        <.live_file_input upload={@uploads.org_logo} class="sr-only" />

                        <p class="text-xs text-slate-400 dark:text-slate-500">
                          PNG, JPG, WebP, or HEIC. Up to 5&nbsp;MB.
                        </p>

                        <p
                          :if={logo_processing?(@logo_upload_stage)}
                          id="org-logo-progress"
                          class="inline-flex items-center gap-1.5 text-xs font-medium text-teal-600 dark:text-teal-400 animate-pulse"
                        >
                          <.phx_icon name="hero-cog-6-tooth" class="size-3.5 animate-spin" />
                          {logo_stage_label(@logo_upload_stage)}
                        </p>

                        <%= for entry <- @uploads.org_logo.entries do %>
                          <%= for err <- upload_errors(@uploads.org_logo, entry) do %>
                            <p class="text-xs font-medium text-rose-600 dark:text-rose-400">
                              {logo_upload_error(err)}
                            </p>
                          <% end %>
                        <% end %>
                      </div>

                      <.liquid_button
                        :if={@org.logo_url}
                        type="button"
                        id="org-logo-remove"
                        variant="secondary"
                        icon="hero-trash"
                        phx-click="remove_org_logo"
                        data-confirm="Remove your organization's logo?"
                      >
                        Remove
                      </.liquid_button>
                    </.form>

                    <%!-- Custom subdomain (Task #240 / #243, Phase B — the PAID add-on).
                Gated by has_branding_addon?/1 (server-authoritative) AND, because
                it mutates the paid subscription, OWNER-ONLY (@is_owner?) — the
                free logo above stays admin-manageable. --%>
                    <div
                      :if={@is_owner?}
                      id="org-subdomain"
                      class="pt-4 border-t border-slate-100 dark:border-slate-700/60 space-y-3"
                    >
                      <div class="flex items-start justify-between gap-3">
                        <div class="min-w-0">
                          <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                            Custom subdomain
                          </h3>
                          <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                            A branded address like
                            <span class="font-medium text-slate-600 dark:text-slate-300">yourteam.mosslet.com</span>
                            — with an org-branded sign-in for your team.
                          </p>
                        </div>
                        <span
                          :if={@has_branding_addon?}
                          class="shrink-0 inline-flex items-center gap-1 rounded-full bg-emerald-50 dark:bg-emerald-900/30 px-2 py-0.5 text-xs font-medium text-emerald-700 dark:text-emerald-300"
                        >
                          <.phx_icon name="hero-check-badge" class="size-3.5" /> Add-on active
                        </span>
                      </div>

                      <%= cond do %>
                        <% @has_branding_addon? && @org.subdomain -> %>
                          <div
                            id="org-subdomain-current"
                            class="rounded-xl bg-slate-50 dark:bg-slate-800/60 p-3 space-y-2"
                          >
                            <p class="text-xs text-slate-500 dark:text-slate-400">Your subdomain</p>
                            <p class="text-sm font-medium text-slate-900 dark:text-slate-100 break-all">
                              {subdomain_display_url(@org.subdomain)}
                            </p>
                            <.liquid_button
                              type="button"
                              id="org-subdomain-release"
                              variant="secondary"
                              size="sm"
                              icon="hero-trash"
                              phx-click="release_subdomain"
                              data-confirm="Release this subdomain and remove the custom-subdomain add-on? Your branded address will stop working and the add-on will be removed from your subscription — the prorated credit appears on your next invoice."
                            >
                              Release subdomain
                            </.liquid_button>
                          </div>
                        <% @has_branding_addon? -> %>
                          <.form
                            for={@subdomain_form}
                            id="org-subdomain-form"
                            phx-change="validate_subdomain"
                            phx-submit="claim_subdomain"
                            class="space-y-2"
                          >
                            <div class="flex flex-col gap-2 sm:flex-row sm:items-end">
                              <div class="flex-1">
                                <.phx_input
                                  field={@subdomain_form[:subdomain]}
                                  type="text"
                                  label="Choose your subdomain"
                                  placeholder="yourteam"
                                  autocomplete="off"
                                  phx-debounce="300"
                                />
                              </div>
                              <.liquid_button
                                type="submit"
                                id="org-subdomain-claim"
                                color="emerald"
                                icon="hero-globe-alt"
                                phx-disable-with="Claiming…"
                              >
                                Claim
                              </.liquid_button>
                            </div>
                            <p class="text-xs text-slate-400 dark:text-slate-500">
                              Lowercase letters, numbers, and hyphens. 3–63 characters.
                            </p>
                          </.form>
                        <% true -> %>
                          <%!-- The dashboard is only reachable for an active/trialing/grace
                      org (Option B), so the org is always covered here — frame the
                      upsell as ADDING the add-on, never "subscribe" (trial-aware,
                      #218). --%>
                          <div
                            id="org-subdomain-upsell-addon"
                            class="rounded-xl border border-teal-200/70 dark:border-teal-800/50 bg-teal-50/60 dark:bg-teal-900/20 p-4 space-y-3"
                          >
                            <p class="text-sm font-medium text-teal-900 dark:text-teal-200">
                              Add a custom subdomain to your plan
                            </p>
                            <p class="text-xs text-teal-800/80 dark:text-teal-300/80">
                              The custom-subdomain add-on is $15/mo (or $150/yr), matched to your billing
                              cycle and prorated to your next invoice. Add it in one click — no checkout
                              needed.
                            </p>
                            <.liquid_button
                              type="button"
                              id="org-subdomain-add-addon"
                              color="emerald"
                              size="sm"
                              icon="hero-sparkles"
                              phx-click="add_subdomain_addon"
                              phx-disable-with="Adding…"
                              data-confirm="Add the custom-subdomain add-on ($15/mo or $150/yr, matched to your billing cycle) to this organization's plan? The prorated amount will be added to your next invoice."
                            >
                              Add custom subdomain
                            </.liquid_button>
                            <p class="text-xs text-teal-700/70 dark:text-teal-400/70">
                              Prefer to review first? <.link
                                navigate={~p"/app/org/#{@org.slug}/billing"}
                                class="font-medium underline underline-offset-2 hover:text-teal-800 dark:hover:text-teal-200"
                              >Manage billing</.link>.
                            </p>
                          </div>
                      <% end %>
                    </div>
                  </section>
                  <%!-- Owner-only in-app seat control (Task #247): adjust the org's paid
                seat count without a Checkout detour. Mirrors the subscribe page's
                seat stepper; the write re-clamps + re-guards server-side via
                Orgs.set_org_seats/2. Gated by can_manage_billing?/2 (owner) since
                it mutates the paid subscription. --%>
                  <div
                    :if={@is_owner? && @seat_management}
                    id="org-seat-management"
                    class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
                  >
                    <div class="flex items-start justify-between gap-4">
                      <div class="min-w-0">
                        <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                          Team seats
                        </h3>
                        <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                          Adjust your plan's seat count any time — prorated to your next invoice.
                        </p>
                      </div>
                      <div class="shrink-0 text-right">
                        <p class="text-2xl font-bold tabular-nums leading-none">
                          <span class="bg-gradient-to-r from-emerald-500 to-teal-500 bg-clip-text text-transparent">{@seat_management.used}</span><span class="text-slate-400 dark:text-slate-500 font-medium">/{@seat_management.cap}</span>
                        </p>
                        <p class="mt-1 text-[11px] font-medium uppercase tracking-wide text-slate-400 dark:text-slate-500">
                          seats in use
                        </p>
                      </div>
                    </div>

                    <%!-- Usage bar: a calm, at-a-glance read of how full the team is. --%>
                    <div class="h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700/60">
                      <div
                        class={[
                          "h-full rounded-full transition-all duration-500",
                          if(@seat_management.used >= @seat_management.cap,
                            do: "bg-gradient-to-r from-amber-400 to-rose-500",
                            else: "bg-gradient-to-r from-teal-400 to-emerald-500"
                          )
                        ]}
                        style={"width: #{min(100, round(@seat_management.used / max(@seat_management.cap, 1) * 100))}%"}
                      >
                      </div>
                    </div>

                    <.form
                      for={to_form(%{})}
                      id="org-seat-form"
                      phx-submit="update_org_seats"
                      class="flex flex-wrap items-end gap-3 pt-1"
                    >
                      <div class="shrink-0">
                        <label
                          for="org-seat-input"
                          class="block text-xs font-medium text-slate-600 dark:text-slate-300 mb-1.5"
                        >
                          Seats
                        </label>
                        <div
                          id="org-seat-stepper"
                          phx-hook="SeatStepper"
                          class={[
                            "inline-flex h-11 w-36 items-stretch overflow-hidden rounded-xl",
                            "border border-slate-300 dark:border-slate-600",
                            "bg-white dark:bg-slate-800 shadow-sm",
                            "focus-within:border-emerald-500 focus-within:ring-1 focus-within:ring-emerald-500",
                            "transition-colors duration-200"
                          ]}
                        >
                          <button
                            type="button"
                            data-seat-step="-1"
                            aria-label="Decrease seats"
                            class={[
                              "flex items-center justify-center w-11 shrink-0 text-slate-500 dark:text-slate-400",
                              "hover:bg-slate-100 dark:hover:bg-slate-700 active:bg-slate-200 dark:active:bg-slate-600",
                              "hover:text-emerald-600 dark:hover:text-emerald-400",
                              "disabled:opacity-40 disabled:pointer-events-none",
                              "transition-colors duration-150 focus:outline-none"
                            ]}
                          >
                            <.phx_icon name="hero-minus" class="size-4" />
                          </button>
                          <input
                            type="number"
                            id="org-seat-input"
                            name="seats"
                            value={@seat_management.cap}
                            min={@seat_management.min}
                            max={@seat_management.max != :infinity && @seat_management.max}
                            step="1"
                            inputmode="numeric"
                            class={[
                              "min-w-0 flex-1 border-0 bg-transparent text-center font-semibold tabular-nums",
                              "text-slate-900 dark:text-slate-100 focus:ring-0 sm:text-sm",
                              "[appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                            ]}
                          />
                          <button
                            type="button"
                            data-seat-step="1"
                            aria-label="Increase seats"
                            class={[
                              "flex items-center justify-center w-11 shrink-0 text-slate-500 dark:text-slate-400",
                              "hover:bg-slate-100 dark:hover:bg-slate-700 active:bg-slate-200 dark:active:bg-slate-600",
                              "hover:text-emerald-600 dark:hover:text-emerald-400",
                              "disabled:opacity-40 disabled:pointer-events-none",
                              "transition-colors duration-150 focus:outline-none"
                            ]}
                          >
                            <.phx_icon name="hero-plus" class="size-4" />
                          </button>
                        </div>
                      </div>
                      <.liquid_button
                        type="submit"
                        id="org-seat-update"
                        color="emerald"
                        icon="hero-user-group"
                        phx-disable-with="Updating…"
                        data-confirm="Update your organization's seat count? Any change is prorated to your next invoice."
                      >
                        Update seats
                      </.liquid_button>
                    </.form>
                    <p class="text-xs text-slate-400 dark:text-slate-500">
                      You can't set fewer seats than your team is currently using (including pending
                      invites).
                    </p>
                  </div>
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
                    audit_export?={@can_view_audit_log?}
                  />
                </div>
              </section>
            </div>
          </div>
        </section>
      </div>
    </.layout>
    """
  end

  # A single business-circle row, shared by both dashboard tiers (#229b). The
  # `:team` tier (official departments) gets org-branded accents + an "Official"
  # badge; `:community` keeps the lighter, member-made look. The circle NAME stays
  # encrypted and is decrypted browser-side via the DecryptGroupMetadata hook
  # (ZK). The inline manage-members affordance is gated by `viewer_can_manage?`.
  attr :circle, :map, required: true
  attr :tier, :atom, required: true
  attr :manage_circle, :map, default: nil
  attr :org, :map, required: true
  attr :current_user_id, :string, required: true
  attr :viewer_sealed_org_key, :string, default: nil
  attr :can_manage_org_pins?, :boolean, default: false
  attr :personal_pinned?, :boolean, default: false
  attr :org_pinned?, :boolean, default: false

  defp circle_card(assigns) do
    ~H"""
    <li
      id={"circle-#{@circle.group.id}"}
      data-hook-scope={"business-circle-#{@circle.group.id}"}
      class={[
        "group overflow-hidden rounded-xl border transition-all duration-200",
        @tier == :team &&
          "border-teal-200/70 dark:border-teal-800/50 bg-gradient-to-br from-teal-50/70 to-emerald-50/40 dark:from-teal-900/15 dark:to-emerald-900/10 hover:border-teal-300 dark:hover:border-teal-700",
        @tier != :team &&
          "border-slate-200/60 dark:border-slate-700/60 bg-white/70 dark:bg-slate-800/50 hover:border-emerald-300/60 dark:hover:border-emerald-700/50"
      ]}
    >
      <div
        id={"decrypt-business-circle-#{@circle.group.id}"}
        phx-hook="DecryptGroupMetadata"
        data-sealed-group-key={@circle.sealed_group_key}
        data-encrypted-name={@circle.encrypted_name}
        data-scope-id={"business-circle-#{@circle.group.id}"}
      >
      </div>
      <div class="flex items-center">
        <.link
          navigate={~p"/app/business/#{@org.slug}/circles/#{@circle.group.id}"}
          class="flex flex-1 min-w-0 items-center gap-3 p-3"
        >
          <div class={[
            "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg relative",
            @tier == :team &&
              "bg-gradient-to-br from-teal-500 to-emerald-600 text-white shadow-sm",
            @tier != :team &&
              "bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300 group-hover:text-teal-600 dark:group-hover:text-teal-300"
          ]}>
            <.phx_icon
              name={
                if(@tier == :team, do: "hero-building-office-2", else: "hero-chat-bubble-left-right")
              }
              class="size-4"
            />
            <.mention_badge
              id={"circle-#{@circle.group.id}-mentions"}
              count={@circle.unread_mention_count}
              variant={:business}
            />
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
              <span data-decrypt-group-name>Business circle</span>
            </p>
            <p class="flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
              {@circle.member_count} member{if @circle.member_count != 1, do: "s"}
              <span
                :if={@circle.unread_announcements > 0}
                id={"circle-#{@circle.group.id}-unread-announcements"}
                class="inline-flex items-center gap-1 rounded-full bg-rose-100 dark:bg-rose-900/40 px-1.5 py-0.5 text-[10px] font-semibold text-rose-700 dark:text-rose-300"
                title="New announcements you haven't read"
              >
                <.phx_icon name="hero-megaphone" class="size-3" />
                {@circle.unread_announcements} new
              </span>
            </p>
          </div>
          <span
            :if={@tier == :team}
            class="shrink-0 inline-flex items-center rounded-full bg-teal-100 dark:bg-teal-900/40 px-2 py-0.5 text-[11px] font-semibold text-teal-700 dark:text-teal-300"
          >
            Official
          </span>
          <.phx_icon
            name="hero-chevron-right"
            class="size-4 shrink-0 text-slate-300 dark:text-slate-600 group-hover:text-teal-500 dark:group-hover:text-teal-400"
          />
        </.link>
        <.pin_toggle_buttons
          class="pr-3"
          pin_type={:circle}
          target_id={@circle.group.id}
          personal_pinned?={@personal_pinned?}
          org_pinned?={@org_pinned?}
          can_manage_org_pins?={@can_manage_org_pins?}
        />
      </div>

      <%!-- Per-circle member management (Task #231): an org admin or the circle
       owner/admin can add/remove members without leaving the org dashboard. --%>
      <div
        :if={@circle.viewer_can_manage?}
        class="border-t border-slate-200/60 dark:border-slate-700/60 px-3 py-2"
      >
        <button
          :if={!(@manage_circle && @manage_circle.group.id == @circle.group.id)}
          type="button"
          phx-click="manage_circle"
          phx-value-circle_id={@circle.group.id}
          id={"manage-circle-#{@circle.group.id}"}
          class="inline-flex items-center gap-1.5 text-xs font-medium text-teal-600 dark:text-teal-400 hover:underline"
        >
          <.phx_icon name="hero-users" class="size-3.5" /> Manage members
        </button>

        <.circle_manage_panel
          :if={@manage_circle && @manage_circle.group.id == @circle.group.id}
          manage={@manage_circle}
          org={@org}
          viewer_sealed_org_key={@viewer_sealed_org_key}
          current_user_id={@current_user_id}
        />
      </div>
    </li>
    """
  end

  # One circle's file group in the org-wide files overview (#229b tiers). The
  # circle NAME stays encrypted (decrypted browser-side via DecryptGroupMetadata)
  # and each filename is decrypted via DecryptSharedFileName — all ZK. Carries
  # the `data-file-group` / `data-file-row` hooks the OrgFileSearch hook filters
  # on. `:team` blocks get a subtle org-branded icon on the circle link.
  attr :entry, :map, required: true
  attr :tier, :atom, required: true
  attr :org, :map, required: true
  attr :can_manage_org_pins?, :boolean, default: false
  attr :personal_pinned_file_ids, :any, default: %MapSet{}
  attr :org_pinned_file_ids, :any, default: %MapSet{}

  defp file_circle_block(assigns) do
    ~H"""
    <div
      id={"org-files-circle-#{@entry.group.id}"}
      data-hook-scope={"files-circle-#{@entry.group.id}"}
      data-file-group
      class="overflow-hidden rounded-xl border border-slate-200/70 dark:border-slate-700/60 bg-white dark:bg-slate-800/40"
    >
      <div
        id={"decrypt-files-circle-#{@entry.group.id}"}
        phx-hook="DecryptGroupMetadata"
        data-sealed-group-key={@entry.sealed_group_key}
        data-encrypted-name={@entry.encrypted_name}
        data-scope-id={"files-circle-#{@entry.group.id}"}
      >
      </div>
      <%!-- Circle header (Task #263): the primary grouping affordance. The whole
           row is the "open circle" link with a tinted chip (teal for official
           Departments & Teams, slate for Community), a clear circle name, a
           file-count pill, and a chevron that nudges on hover. --%>
      <.link
        navigate={~p"/app/business/#{@org.slug}/circles/#{@entry.group.id}"}
        class="group flex items-center gap-3 px-3 py-2.5 bg-slate-50/70 dark:bg-slate-800/60 transition-colors hover:bg-slate-100/80 dark:hover:bg-slate-700/50"
      >
        <span class={[
          "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg",
          if(@tier == :team,
            do: "bg-teal-100 text-teal-600 dark:bg-teal-900/40 dark:text-teal-300",
            else: "bg-slate-100 text-slate-500 dark:bg-slate-700/60 dark:text-slate-300"
          )
        ]}>
          <.phx_icon
            name={
              if(@tier == :team, do: "hero-building-office-2", else: "hero-chat-bubble-left-right")
            }
            class="size-4"
          />
        </span>
        <span
          data-decrypt-group-name
          class="min-w-0 flex-1 truncate text-sm font-semibold text-slate-900 dark:text-slate-100"
        >
          Business circle
        </span>
        <span class="shrink-0 inline-flex items-center rounded-full bg-white px-2 py-0.5 text-xs font-medium text-slate-500 ring-1 ring-slate-200/70 dark:bg-slate-700/60 dark:text-slate-400 dark:ring-slate-600/50">
          {length(@entry.files)} file{if length(@entry.files) != 1, do: "s"}
        </span>
        <.phx_icon
          name="hero-chevron-right"
          class="size-4 shrink-0 text-slate-300 transition-transform duration-200 group-hover:translate-x-0.5 group-hover:text-slate-400 dark:text-slate-600"
        />
      </.link>
      <ul
        role="list"
        class="divide-y divide-slate-100 border-t border-slate-100 dark:divide-slate-700/50 dark:border-slate-700/50"
      >
        <li
          :for={file <- @entry.files}
          id={"org-file-#{file.id}"}
          data-file-row
          class="flex items-center gap-3 px-3 py-2.5 transition-colors hover:bg-slate-50/70 dark:hover:bg-slate-800/40"
        >
          <span class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-violet-100 text-violet-600 dark:bg-violet-900/40 dark:text-violet-300">
            <.phx_icon name="hero-document" class="size-4" />
          </span>
          <div class="min-w-0 flex-1">
            <% viewer_row = List.first(file.user_shared_files) %>
            <div
              :if={viewer_row && file.encrypted_filename}
              id={"decrypt-org-filename-#{file.id}"}
              phx-hook="DecryptSharedFileName"
              phx-update="ignore"
              data-sealed-file-key={viewer_row.key}
              data-encrypted-filename={file.encrypted_filename}
            >
              <p
                data-shared-filename
                class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate"
              >
                Decrypting…
              </p>
            </div>
            <p
              :if={!(viewer_row && file.encrypted_filename)}
              class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate"
            >
              Encrypted file
            </p>
            <p class="text-xs text-slate-400 dark:text-slate-500">
              {format_size(file.size_bytes)}
            </p>
          </div>
          <.pin_toggle_buttons
            pin_type={:file}
            target_id={file.id}
            personal_pinned?={MapSet.member?(@personal_pinned_file_ids, file.id)}
            org_pinned?={MapSet.member?(@org_pinned_file_ids, file.id)}
            can_manage_org_pins?={@can_manage_org_pins?}
          />
        </li>
      </ul>
    </div>
    """
  end

  # Inline per-circle member-management panel rendered on the org dashboard
  # (Task #231). Mirrors the CircleShow members section: a roster (scoped to the
  # circle) with a Remove affordance, plus the ZK add-members composer. Reuses
  # the route-agnostic `CircleAddMembersHook` + `OrgMembers` hooks. Because the
  # dashboard shows multiple circles, the server scopes every add/remove write to
  # `@manage_circle_id` (set when this panel opens) — the hook payload itself is
  # unchanged.
  attr :manage, :map, required: true
  attr :org, :map, required: true
  attr :viewer_sealed_org_key, :string, default: nil
  attr :current_user_id, :string, required: true

  defp circle_manage_panel(assigns) do
    ~H"""
    <div
      id={"manage-circle-panel-#{@manage.group.id}"}
      phx-hook="OrgMembers"
      data-sealed-org-key={@viewer_sealed_org_key}
      data-current-user-id={@current_user_id}
      class="mt-2 rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-gradient-to-br from-teal-50/60 to-emerald-50/40 dark:from-teal-900/15 dark:to-emerald-900/10 p-4 space-y-3"
    >
      <div class="flex items-center justify-between gap-2">
        <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
          Members ({@manage.member_count})
        </p>
        <.liquid_button
          type="button"
          variant="ghost"
          color="slate"
          size="sm"
          phx-click="close_manage_circle"
          id={"close-manage-circle-#{@manage.group.id}"}
        >
          Done
        </.liquid_button>
      </div>

      <ul
        role="list"
        class="rounded-lg border border-slate-200/60 dark:border-slate-700/60 bg-white/60 dark:bg-slate-900/30 divide-y divide-slate-100 dark:divide-slate-700/50"
      >
        <li
          :for={member <- @manage.members}
          id={"manage-member-#{@manage.group.id}-#{member.user.id}"}
          data-org-member-row
          data-encrypted-display-name={member.encrypted_display_name}
          class="flex items-center gap-3 px-3 py-2.5"
        >
          <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/40 dark:to-emerald-900/40 text-teal-600 dark:text-teal-300">
            <.phx_icon name="hero-user" class="size-3.5" />
          </div>
          <span class="min-w-0 flex-1 text-sm text-slate-900 dark:text-slate-100 truncate">
            <span {MossletWeb.OrgIdentity.org_name_target(member)}>
              {MossletWeb.OrgIdentity.placeholder_label(member)}
            </span>
          </span>
          <span
            :if={member.self?}
            class="shrink-0 rounded-full bg-slate-100 dark:bg-slate-700/60 px-2 py-0.5 text-[11px] font-medium text-slate-500 dark:text-slate-400"
          >
            You
          </span>
          <.liquid_button
            :if={!member.self? && member.user.id != @manage.group.user_id}
            type="button"
            variant="ghost"
            color="rose"
            size="sm"
            icon="hero-user-minus"
            phx-click="remove_circle_member"
            phx-value-user_id={member.user.id}
            id={"manage-remove-#{@manage.group.id}-#{member.user.id}"}
            data-confirm="Remove this person from the circle? They'll lose access to its chat and files. You can't recall copies already downloaded."
          >
            Remove
          </.liquid_button>
        </li>
      </ul>

      <%!-- Add members (ZK write path). Any org member not already in the circle
           is addable — org membership is the only prerequisite. --%>
      <form
        :if={@manage.addable_members != []}
        id={"manage-add-members-form-#{@manage.group.id}"}
        phx-hook="CircleAddMembersHook"
        data-sealed-group-key={@manage.sealed_group_key}
        data-sealed-org-key={@viewer_sealed_org_key}
        class="space-y-3"
      >
        <p class="text-xs font-medium text-slate-700 dark:text-slate-300">
          Add people from your organization
        </p>
        <ul
          role="list"
          class="max-h-48 overflow-y-auto rounded-lg border border-slate-200/60 dark:border-slate-700/60 bg-white/60 dark:bg-slate-900/30 divide-y divide-slate-100 dark:divide-slate-700/50"
        >
          <li
            :for={member <- @manage.addable_members}
            id={"manage-add-row-#{@manage.group.id}-#{member.user.id}"}
            data-org-member-row
            data-encrypted-display-name={member.encrypted_display_name}
          >
            <label
              for={"manage-add-#{@manage.group.id}-#{member.user.id}"}
              class="flex items-center gap-3 cursor-pointer px-3 py-2.5 hover:bg-teal-50/60 dark:hover:bg-teal-900/15 transition-colors duration-150"
            >
              <input
                type="checkbox"
                id={"manage-add-#{@manage.group.id}-#{member.user.id}"}
                name="add_members[]"
                value={member.user.id}
                class="size-4 rounded border-slate-300 dark:border-slate-600 text-teal-600 focus:ring-teal-500 focus:ring-offset-0"
              />
              <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                <.phx_icon name="hero-user" class="size-3.5" />
              </div>
              <span
                class="min-w-0 flex-1 text-sm text-slate-900 dark:text-slate-100 truncate"
                data-decrypt-org-name
              >
                {member.personal_name || "Org member"}
              </span>
            </label>
          </li>
        </ul>

        <div class="flex items-center justify-end">
          <.liquid_button
            type="submit"
            id={"manage-add-submit-#{@manage.group.id}"}
            color="emerald"
            icon="hero-user-plus"
            phx-disable-with="Adding…"
          >
            Add to circle
          </.liquid_button>
        </div>
      </form>

      <p
        :if={@manage.addable_members == []}
        class="text-xs text-slate-500 dark:text-slate-400"
      >
        Everyone in this organization is already in this circle.
      </p>
    </div>
    """
  end

  @impl true
  def handle_event("connect_teammate", %{"user_id" => user_id}, socket) do
    {:noreply, connect_teammate(socket, user_id, &assign_business_data/1)}
  end

  @impl true
  def handle_event("invite_member", %{"invite" => %{"email" => email}}, socket) do
    case Orgs.create_invitation(socket.assigns.org, %{"sent_to" => email}) do
      {:ok, invitation} ->
        flash = invitation_sent_flash(invitation, socket.assigns.org)

        Audit.record_audit_event(
          socket.assigns.org,
          socket.assigns.current_scope.user,
          "member_invited",
          target_id: invitation.user_id,
          target_type: invitation.user_id && "user"
        )

        {:noreply,
         socket
         |> put_invitation_flash(flash)
         |> assign(:invite_form, to_form(%{"email" => ""}, as: :invite))
         |> assign_business_data()}

      {:error, :seat_limit_reached} ->
        {:noreply, put_flash(socket, :error, seat_limit_message(socket.assigns.org))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not send invitation")}
    end
  end

  @impl true
  def handle_event("resend_invitation", %{"id" => id}, socket) do
    org = socket.assigns.org

    if socket.assigns.can_manage? do
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

      {:noreply, socket |> put_invitation_flash(flash) |> assign_business_data()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("revoke_invitation", %{"id" => id}, socket) do
    org = socket.assigns.org

    if socket.assigns.can_manage? do
      Orgs.revoke_invitation(org, id)

      {:noreply,
       socket
       |> put_flash(:info, "Invitation revoked")
       |> assign_business_data()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_role", %{"user_id" => user_id, "role" => role}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.user.id == user_id))

    # The owner is the org's billing/coverage anchor: their role can't be changed
    # by an admin (ownership transfer is the only path — Task #237).
    if socket.assigns.can_manage? && member && not Orgs.owner?(socket.assigns.org, user_id) do
      case Orgs.update_membership(member.membership, %{"role" => role}) do
        {:ok, _membership} ->
          Audit.record_audit_event(
            socket.assigns.org,
            socket.assigns.current_scope.user,
            "role_changed",
            target_id: user_id,
            target_type: "user"
          )

          {:noreply,
           socket
           |> put_flash(:success, "Role updated")
           |> assign_business_data()}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, role_error_message(changeset))
           |> assign_business_data()}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("offboard_member", %{"user_id" => user_id}, socket) do
    org = socket.assigns.org
    member = Enum.find(socket.assigns.members, &(&1.user.id == user_id))

    if socket.assigns.can_manage? && member && user_id != socket.assigns.current_scope.user.id &&
         not Orgs.owner?(org, user_id) do
      # Remove the member from every business circle in this org (Q5 — explicit,
      # honest offboarding). We can't recall content already downloaded; we only
      # stop FUTURE access by removing their UserGroup rows AND revoking their
      # sealed file_keys (Task #234), so a later re-add requires a fresh catch-up.
      org
      |> Groups.list_org_business_circles()
      |> Enum.each(fn group ->
        Groups.remove_group_members(group, [user_id])
        Files.revoke_member_file_access(group, user_id)
      end)

      case Orgs.delete_membership(member.membership) do
        {:ok, _} ->
          Audit.record_audit_event(org, socket.assigns.current_scope.user, "member_removed",
            target_id: user_id,
            target_type: "user"
          )

          {:noreply,
           socket
           |> put_flash(
             :info,
             "Removed from the organization and all of its circles. (Content already downloaded can't be recalled.)"
           )
           |> assign_business_data()}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, role_error_message(changeset))
           |> assign_business_data()}
      end
    else
      {:noreply, socket}
    end
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
    {:noreply, do_initiate_transfer(socket, to_user_id, password, &assign_business_data/1)}
  end

  @impl true
  def handle_event("accept_transfer", params, socket) do
    transfer_id = Map.get(params, "transfer_id", "")
    password = get_in(params, ["transfer", "password"]) || ""
    {:noreply, do_accept_transfer(socket, transfer_id, password, &assign_business_data/1)}
  end

  @impl true
  def handle_event("decline_transfer", %{"transfer_id" => transfer_id}, socket) do
    {:noreply, do_decline_transfer(socket, transfer_id, &assign_business_data/1)}
  end

  @impl true
  def handle_event("cancel_transfer", %{"transfer_id" => transfer_id}, socket) do
    {:noreply, do_cancel_transfer(socket, transfer_id, &assign_business_data/1)}
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
    {:noreply, do_delete_org(socket, confirm_name, password, ~p"/app/business")}
  end

  ## Per-circle member management from the org dashboard (Task #231)

  # Open the inline add/remove members panel for a specific circle. Only org
  # admins (or the circle owner/admin) manage membership; the affordance is
  # gated in the template and re-checked on every write.
  @impl true
  def handle_event("manage_circle", %{"circle_id" => circle_id}, socket) do
    {:noreply,
     socket
     |> assign(:manage_circle_id, circle_id)
     |> assign(:show_circle_form?, false)
     |> assign_business_data()}
  end

  @impl true
  def handle_event("close_manage_circle", _params, socket) do
    {:noreply,
     socket
     |> assign(:manage_circle_id, nil)
     |> assign(:manage_circle, nil)}
  end

  # Phase 1 (ZK add): the browser sent the selected org-member ids for the circle
  # currently being managed. Server-authoritative (I1): only an authorized
  # manager may add, and the candidate set is intersected with the circle's
  # addable org members. Returns each member's public keys + org display-name
  # ciphertext + server-generated moniker/avatar for the browser to seal.
  @impl true
  def handle_event("request_add_members", %{"user_ids" => user_ids}, socket)
      when is_list(user_ids) do
    manage = socket.assigns.manage_circle

    cond do
      is_nil(manage) ->
        {:noreply, socket}

      not can_manage_circle?(socket, manage) ->
        {:noreply, put_flash(socket, :error, "You don't have permission to add members.")}

      true ->
        eligible_ids = MapSet.new(manage.addable_members, & &1.user.id)
        selected_ids = Enum.filter(user_ids, &MapSet.member?(eligible_ids, &1))

        members =
          socket.assigns.org
          |> MossletWeb.OrgIdentity.members_to_add(selected_ids)
          |> Enum.map(fn member ->
            member
            |> Map.put(:moniker, FriendlyID.generate(3))
            |> Map.put(:avatar_img, random_avatar())
          end)

        if members == [] do
          {:noreply, put_flash(socket, :info, "No eligible org members selected.")}
        else
          {:noreply,
           socket
           |> assign(:pending_add_member_ids, Enum.map(members, & &1.user_id))
           |> push_event("seal_group_key_for_new_members", %{members: members})}
        end
    end
  end

  # Phase 2 (ZK add): the browser sealed the circle group_key for each new member
  # and encrypted their display name/moniker/avatar with it. Persist via the
  # shared ZK write path, which RE-ENFORCES org-membership eligibility (I1)
  # server-side. The raw group_key NEVER reaches the server. Broadcasts an org
  # update so every open dashboard/circle refreshes live.
  @impl true
  def handle_event("finalize_group_members_zk", %{"sealed_members" => sealed_members}, socket)
      when is_list(sealed_members) do
    manage = socket.assigns.manage_circle

    if manage && can_manage_circle?(socket, manage) do
      {:ok, added} = Groups.add_group_members_zk(manage.group, sealed_members)
      Orgs.broadcast_org_update(socket.assigns.org)

      {:noreply,
       socket
       |> put_flash(:success, "#{added} member#{if added != 1, do: "s"} added to the circle.")
       |> assign(:pending_add_member_ids, [])
       |> assign_business_data()}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to add members.")}
    end
  end

  # Remove a member from the circle currently being managed. Server-
  # authoritative: an org admin (or the circle owner/admin) may remove a
  # non-owner member. Broadcasts an org update so dashboards/circles refresh
  # live (and a removed member with the circle open gets bounced).
  @impl true
  def handle_event("remove_circle_member", %{"user_id" => user_id}, socket) do
    manage = socket.assigns.manage_circle

    cond do
      is_nil(manage) ->
        {:noreply, socket}

      not can_manage_circle?(socket, manage) ->
        {:noreply, put_flash(socket, :error, "You don't have permission to remove members.")}

      user_id == manage.group.user_id ->
        {:noreply, put_flash(socket, :error, "The circle owner can't be removed.")}

      true ->
        {:ok, _} = Groups.remove_group_members(manage.group, [user_id])
        # Revoke the removed member's sealed file_keys for this circle (Task
        # #234) — explicit removal, never silent: a later re-add requires catch-up.
        Files.revoke_member_file_access(manage.group, user_id)
        Orgs.broadcast_org_update(socket.assigns.org)

        {:noreply,
         socket
         |> put_flash(:info, "Member removed from the circle.")
         |> assign_business_data()}
    end
  end

  def handle_event("show_circle_form", _params, socket) do
    {:noreply, assign(socket, :show_circle_form?, true)}
  end

  def handle_event("hide_circle_form", _params, socket) do
    {:noreply, assign(socket, :show_circle_form?, false)}
  end

  # Fallback submit (e.g. WASM unavailable). The ZK hook normally intercepts and
  # pushes "create_group_zk"; without it we can't seal a key in the browser.
  def handle_event("create_circle", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Your browser couldn't prepare encryption keys. Please reload and try again."
     )}
  end

  # Phase 1 (ZK): browser sent encrypted circle content + sealed creator key.
  # Resolve the eligible member public keys (org members the creator is connected
  # to) and hand them back for the browser to seal.
  def handle_event("create_group_zk", params, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    eligible = socket.assigns.eligible_members
    eligible_user_ids = MapSet.new(eligible, & &1.user.id)

    user_connections =
      (params["user_connections"] || [])
      |> Enum.filter(&MapSet.member?(eligible_user_ids, &1))

    # Circle classification (#229b). The client hints the desired tier, but a
    # `:team` (official department) circle is authority-gated; we down-grade a
    # non-owner/admin's `:team` request to `:community` here and the write path
    # (`create_business_circle_zk/6`) re-checks server-authoritatively. Never
    # `String.to_atom/1` on user input — map known values only.
    circle_type =
      case parse_circle_type(params["circle_type"]) do
        :team ->
          if Orgs.can_create_team_circle?(socket.assigns.org, user.id),
            do: :team,
            else: :community

        other ->
          other
      end

    if params["user_id"] == user.id do
      users = Enum.map(user_connections, &Accounts.get_user!/1)

      members =
        Enum.map(users, fn u ->
          uconn = Accounts.get_user_connection_between_users(u.id, user.id)

          name =
            Mosslet.Encrypted.Users.Utils.decrypt_user_item(
              uconn.connection.name,
              user,
              uconn.key,
              key
            )

          %{
            user_id: u.id,
            public_key: u.key_pair["public"],
            pq_public_key: u.pq_public_key,
            name: name,
            moniker: FriendlyID.generate(3),
            avatar_img: random_avatar()
          }
        end)

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
       |> assign(:pending_zk_circle_users, users)
       |> assign(:pending_zk_circle_type, circle_type)
       |> push_event("seal_group_key_for_members", %{
         members: members,
         owner_moniker: FriendlyID.generate(3),
         owner_avatar_img: random_avatar()
       })}
    else
      {:noreply, put_flash(socket, :error, "Could not create circle.")}
    end
  end

  # Phase 2 (ZK): browser sealed the group_key for each member. Persist via the
  # business-circle write path (stamps org_id + enforces org-membership
  # eligibility server-side). The raw group_key NEVER reaches the server.
  def handle_event("finalize_group_zk", params, socket) do
    user = socket.assigns.current_scope.user
    org = socket.assigns.org
    zk_attrs = socket.assigns.pending_zk_circle_attrs
    users = socket.assigns.pending_zk_circle_users || []
    circle_type = socket.assigns.pending_zk_circle_type || :community

    if is_nil(zk_attrs) do
      {:noreply, put_flash(socket, :error, "No pending circle to finalize. Please try again.")}
    else
      zk_attrs =
        zk_attrs
        |> Map.put(:encrypted_owner_moniker, params["encrypted_owner_moniker"])
        |> Map.put(:encrypted_owner_avatar_img, params["encrypted_owner_avatar_img"])

      sealed_members = params["sealed_members"] || []

      socket =
        socket
        |> assign(:pending_zk_circle_attrs, nil)
        |> assign(:pending_zk_circle_users, nil)
        |> assign(:pending_zk_circle_type, :community)

      case Groups.create_business_circle_zk(
             org,
             user,
             zk_attrs,
             users,
             sealed_members,
             circle_type
           ) do
        {:ok, group} ->
          Mosslet.Logs.log("orgs.create_business_circle", %{
            user: user,
            org_id: org.id,
            metadata: %{"group_id" => group.id}
          })

          Audit.record_audit_event(org, user, "circle_created",
            target_id: group.id,
            target_type: "group"
          )

          {:noreply,
           socket
           |> put_flash(:success, "Circle created")
           |> assign(:show_circle_form?, false)
           |> assign(:circle_form, to_form(%{"name" => "", "description" => ""}, as: :circle))
           |> assign_business_data()}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to create circle")}
      end
    end
  end

  # Org-scoped ZK identity (Task #225). The browser sealed the org_key for one or
  # more members (or bootstrapped it as the owner); persist the sealed copies.
  # Server-authoritative + idempotent (drops non-members / already-sealed). The
  # org_updated broadcast re-renders everyone's roster.
  @impl true
  def handle_event("finalize_org_key", %{"sealed_members" => sealed_members}, socket)
      when is_list(sealed_members) do
    case MossletWeb.OrgIdentity.finalize_org_key(socket.assigns.org, sealed_members) do
      {:ok, _count} -> {:noreply, assign_business_data(socket)}
      _ -> {:noreply, socket}
    end
  end

  # The member set their org display name (encrypted browser-side with the
  # org_key). Persist the ciphertext only.
  @impl true
  def handle_event(
        "save_org_display_name",
        %{"encrypted_display_name" => encrypted_name} = params,
        socket
      )
      when is_binary(encrypted_name) do
    # The display name is ciphertext under the shared `org_key` (every member's
    # sealed key unseals to the SAME key), so any key-holder can re-encrypt any
    # member's name browser-side. Authority still gates the WRITE here (I1):
    #   * self-edit — any member may rename themselves.
    #   * editing someone else — admins/owners only (`@can_manage?`).
    current_user_id = socket.assigns.current_scope.user.id
    target_user_id = params["target_user_id"]

    target_membership =
      cond do
        is_nil(target_user_id) or target_user_id == current_user_id ->
          socket.assigns.membership

        socket.assigns.can_manage? ->
          case Enum.find(socket.assigns.members, &(&1.user.id == target_user_id)) do
            %{membership: membership} -> membership
            _ -> nil
          end

        true ->
          nil
      end

    case target_membership && Orgs.set_org_display_name(target_membership, encrypted_name) do
      {:ok, _membership} ->
        # ZK audit (#264): record the rename as metadata only — actor + target
        # user id + category. actor == target distinguishes a self-rename from an
        # admin/owner renaming someone else (the client builds the human sentence
        # from decrypted names). Best-effort; never blocks the save.
        Audit.record_audit_event(
          socket.assigns.org,
          socket.assigns.current_scope.user,
          "display_name_changed",
          target_id: target_membership.user_id,
          target_type: "user"
        )

        message =
          if is_nil(target_user_id) or target_user_id == current_user_id,
            do: "Your team display name is saved",
            else: "Display name updated"

        {:noreply,
         socket
         |> assign(:editing_name_user_id, nil)
         |> put_flash(:success, message)
         |> assign_business_data()}

      nil ->
        {:noreply, put_flash(socket, :error, "You can't edit that member's name")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not save the display name")}
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

  @impl true
  def handle_event("org_display_name_invalid", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Please use letters, spaces, and basic punctuation (up to 160 characters)."
     )}
  end

  # Open the inline "edit display name" form for a single roster row (Task #263).
  # Allowed for the viewer's OWN row, or for any row when the viewer can manage
  # the org (admin/owner). The actual write is re-authorized in
  # "save_org_display_name", so a tampered toggle can't escalate.
  @impl true
  def handle_event("edit_name", %{"user_id" => user_id}, socket) do
    allowed? = user_id == socket.assigns.current_scope.user.id or socket.assigns.can_manage?

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

  ## Org-wide ZK announcements (Task #229c)

  @impl true
  def handle_event("show_announcement_form", _params, socket) do
    {:noreply, assign(socket, :show_announcement_form?, true)}
  end

  @impl true
  def handle_event("hide_announcement_form", _params, socket) do
    {:noreply, assign(socket, :show_announcement_form?, false)}
  end

  # The browser encrypted the title/body with the org_key and pushed the
  # ciphertext. Persist it (server re-checks owner/admin authority — I1). The raw
  # org_key + plaintext NEVER reach the server. We mark it read for the author so
  # their own post doesn't count as "unread".
  @impl true
  def handle_event("save_announcement", params, socket) do
    user = socket.assigns.current_scope.user
    org = socket.assigns.org

    attrs = %{
      "encrypted_title" => params["encrypted_title"],
      "encrypted_body" => params["encrypted_body"],
      "priority" => Announcements.parse_priority(params["priority"]),
      "expires_at" => Announcements.parse_expires_at(params["expires_at"])
    }

    case Announcements.create_org_announcement(org, user, attrs) do
      {:ok, announcement} ->
        Announcements.mark_read(announcement, user)

        {:noreply,
         socket
         |> put_flash(:success, "Announcement posted")
         |> assign(:show_announcement_form?, false)
         |> assign_business_data()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to post announcements.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not post that announcement.")}
    end
  end

  # Fallback when browser crypto is unavailable: the AnnouncementFormHook normally
  # intercepts the submit and pushes "save_announcement" with ciphertext. Without
  # it the raw form params would arrive here — we must NEVER persist plaintext
  # (ZK), so refuse gracefully.
  @impl true
  def handle_event("create_announcement", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Your browser couldn't prepare encryption keys. Please reload and try again."
     )}
  end

  @impl true
  def handle_event("announcement_invalid", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please add a message (up to 5000 characters).")}
  end

  @impl true
  def handle_event("delete_announcement", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    announcement = Announcements.get_announcement(id)

    cond do
      is_nil(announcement) or announcement.org_id != socket.assigns.org.id ->
        {:noreply, socket}

      true ->
        case Announcements.delete_announcement(announcement, user) do
          {:ok, :deleted} ->
            {:noreply,
             socket |> put_flash(:info, "Announcement deleted") |> assign_business_data()}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You can't delete that announcement.")}

          _ ->
            {:noreply, put_flash(socket, :error, "Could not delete that announcement.")}
        end
    end
  end

  @impl true
  def handle_event("mark_announcements_read", _params, socket) do
    Announcements.mark_all_read_org(socket.assigns.org, socket.assigns.current_scope.user)
    {:noreply, assign_business_data(socket)}
  end

  ## Dashboard pins (Task #229d)

  @impl true
  def handle_event("show_pin_form", _params, socket) do
    {:noreply, assign(socket, :show_pin_form?, true)}
  end

  @impl true
  def handle_event("hide_pin_form", _params, socket) do
    {:noreply, assign(socket, :show_pin_form?, false)}
  end

  # Switch the link-compose form's target scope (owner/admin only — re-checked on
  # write). Personal pins use the user_key; org-wide pins use the org_key.
  @impl true
  def handle_event("set_pin_form_scope", %{"scope" => scope}, socket) do
    scope =
      if scope == "org_shared" and socket.assigns.can_manage_org_pins?,
        do: :org_shared,
        else: :personal

    {:noreply, assign(socket, :pin_form_scope, scope)}
  end

  # The browser encrypted the link label + URL with the user_key (personal) or
  # org_key (org-wide) and pushed the ciphertext. Persist it (server re-checks
  # authority — I1). The raw key + plaintext NEVER reach the server.
  @impl true
  def handle_event("save_pin_link", params, socket) do
    user = socket.assigns.current_scope.user
    org = socket.assigns.org

    attrs = %{
      "pin_type" => :link,
      "encrypted_label" => params["encrypted_label"],
      "encrypted_url" => params["encrypted_url"]
    }

    result =
      if params["scope"] == "org_shared" do
        Pins.create_org_shared_pin(org, user, attrs)
      else
        Pins.create_personal_pin(org, user, attrs)
      end

    case result do
      {:ok, _pin} ->
        {:noreply,
         socket
         |> put_flash(:success, "Link pinned")
         |> assign(:show_pin_form?, false)
         |> assign(:pin_form_scope, :personal)
         |> assign_business_data()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to pin that.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not pin that link.")}
    end
  end

  # Fallback when browser crypto is unavailable: PinLinkFormHook normally
  # intercepts the submit and pushes "save_pin_link" with ciphertext. Without it
  # the raw params would arrive here — we must NEVER persist plaintext (ZK), so
  # refuse gracefully.
  @impl true
  def handle_event("create_pin_link", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Your browser couldn't prepare encryption keys. Please reload and try again."
     )}
  end

  @impl true
  def handle_event("pin_link_invalid", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please add a label and a valid https:// link.")}
  end

  # Quick-pin toggle on a circle card / file row: pin the target if not yet
  # pinned in the chosen scope, else unpin it. Server-authoritative (the context
  # re-checks authority — I1).
  @impl true
  def handle_event(
        "toggle_pin",
        %{"pin_type" => pin_type, "target_id" => target_id, "scope" => scope},
        socket
      ) do
    user = socket.assigns.current_scope.user
    org = socket.assigns.org
    pin_type = Pins.parse_pin_type(pin_type)

    cond do
      is_nil(pin_type) or pin_type == :link ->
        {:noreply, socket}

      scope == "org_shared" ->
        existing = Pins.get_org_shared_target_pin(org, pin_type, target_id)

        result =
          if existing do
            Pins.delete_pin(existing, user)
          else
            Pins.create_org_shared_pin(org, user, %{
              "pin_type" => pin_type,
              "target_id" => target_id
            })
          end

        {:noreply, after_toggle(socket, result)}

      true ->
        existing = Pins.get_personal_target_pin(org, user, pin_type, target_id)

        result =
          if existing do
            Pins.delete_pin(existing, user)
          else
            Pins.create_personal_pin(org, user, %{
              "pin_type" => pin_type,
              "target_id" => target_id
            })
          end

        {:noreply, after_toggle(socket, result)}
    end
  end

  @impl true
  def handle_event("remove_pin", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    pin = Pins.get_pin(id)

    cond do
      is_nil(pin) or pin.org_id != socket.assigns.org.id ->
        {:noreply, socket}

      true ->
        case Pins.delete_pin(pin, user) do
          {:ok, :deleted} ->
            {:noreply, socket |> put_flash(:info, "Pin removed") |> assign_business_data()}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You can't remove that pin.")}

          _ ->
            {:noreply, put_flash(socket, :error, "Could not remove that pin.")}
        end
    end
  end

  @impl true
  def handle_event("reorder_pins", %{"scope" => scope, "order" => order}, socket)
      when is_list(order) do
    user = socket.assigns.current_scope.user
    org = socket.assigns.org

    if scope == "org_shared" do
      Pins.reorder_org_shared_pins(org, user, order)
    else
      Pins.reorder_personal_pins(org, user, order)
    end

    {:noreply, assign_business_data(socket)}
  end

  defp after_toggle(socket, {:error, :unauthorized}),
    do: put_flash(socket, :error, "You don't have permission to pin that.")

  defp after_toggle(socket, _result), do: assign_business_data(socket)

  ## Org brand logo (Task #228, branding add-on)

  # The <.live_file_input> change/submit; the writer + hook drive everything else.
  @impl true
  def handle_event("validate_org_logo", _params, socket), do: {:noreply, socket}

  # Browser finished the ZK encryption with the org_key and sent back the opaque
  # ciphertext. Store it as an opaque blob (server never sees plaintext — I3),
  # then stamp the storage path on the org. Owner/admin only.
  @impl true
  def handle_event(
        "encrypted_org_logo_ready",
        %{"encrypted_blob_b64" => encrypted_blob_b64, "upload_id" => "org_logo"},
        socket
      )
      when is_binary(encrypted_blob_b64) do
    if Orgs.can_manage_branding?(socket.assigns.org, socket.assigns.membership) do
      e_blob = Base.decode64!(encrypted_blob_b64)

      with {:ok, storage_path} <- SharedFileStorage.put_encrypted_blob(e_blob),
           {:ok, org} <- Orgs.set_org_logo(socket.assigns.org, storage_path) do
        {:noreply,
         socket
         |> assign(:org, org)
         |> assign(:logo_upload_stage, nil)
         |> assign(:pending_logo_preview, nil)
         |> put_flash(:success, "Your organization logo has been updated.")
         |> assign_business_data()}
      else
        _ ->
          {:noreply,
           socket
           |> assign(:logo_upload_stage, {:error, "Upload failed"})
           |> put_flash(:error, "Could not save the logo. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to change the logo.")}
    end
  end

  # Fallback: the OrgLogoUpload hook normally intercepts and encrypts the bytes
  # browser-side with the org_key. If browser crypto is unavailable we must NEVER
  # persist a plaintext logo (ZK) — refuse gracefully and ask for a reload.
  @impl true
  def handle_event(
        "encrypted_org_logo_failed",
        %{"upload_id" => "org_logo"} = _params,
        socket
      ) do
    {:noreply,
     socket
     |> assign(:logo_upload_stage, {:error, "Encryption unavailable"})
     |> put_flash(
       :error,
       "Your browser couldn't prepare encryption keys. Please reload and try again."
     )}
  end

  @impl true
  def handle_event("remove_org_logo", _params, socket) do
    if Orgs.can_manage_branding?(socket.assigns.org, socket.assigns.membership) do
      case Orgs.clear_org_logo(socket.assigns.org) do
        {:ok, org} ->
          {:noreply,
           socket
           |> assign(:org, org)
           |> put_flash(:success, "Your organization logo has been removed.")
           |> assign_business_data()}

        _ ->
          {:noreply, put_flash(socket, :error, "Could not remove the logo. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to change the logo.")}
    end
  end

  ## Custom subdomain (Task #240 / #243, branding add-on Phase B — paid add-on)

  @impl true
  def handle_event("validate_subdomain", %{"branding" => params}, socket) do
    changeset =
      socket.assigns.org
      |> Org.subdomain_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :subdomain_form, to_form(changeset, as: :branding))}
  end

  def handle_event("validate_subdomain", _params, socket), do: {:noreply, socket}

  def handle_event("claim_subdomain", %{"branding" => params}, socket) do
    org = socket.assigns.org

    cond do
      # Owner-only gate: claiming a subdomain mutates the org's paid subscription
      # (the add-on), so it's restricted to the billing owner — stricter than the
      # free logo (admins).
      not Orgs.can_manage_billing?(org, socket.assigns.current_scope.user.id) ->
        {:noreply,
         put_flash(socket, :error, "Only the organization owner can manage the subdomain.")}

      # Entitlement gate (server-authoritative): only orgs carrying the paid
      # add-on may claim a subdomain. The logo is never gated this way.
      not Orgs.has_branding_addon?(org) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "The custom-subdomain add-on isn't active for this organization."
         )}

      true ->
        case Orgs.set_org_subdomain(org, params) do
          {:ok, org} ->
            {:noreply,
             socket
             |> assign(:org, org)
             |> assign_subdomain_state(org)
             |> assign(
               :subdomain_form,
               to_form(Org.subdomain_changeset(org, %{}), as: :branding)
             )
             |> put_flash(:success, "Your custom subdomain is live.")}

          {:error, changeset} ->
            {:noreply,
             assign(
               socket,
               :subdomain_form,
               to_form(Map.put(changeset, :action, :insert), as: :branding)
             )}
        end
    end
  end

  def handle_event("release_subdomain", _params, socket) do
    org = socket.assigns.org

    if Orgs.can_manage_billing?(org, socket.assigns.current_scope.user.id) do
      # Releasing is a deliberate teardown: drop the paid add-on first so billing
      # stops (prorated credit on the next invoice), THEN clear the reserved
      # subdomain row. If the add-on removal fails we abort and keep BOTH, so the
      # owner never loses the subdomain while still being charged for it.
      with {:ok, _} <- Orgs.remove_subdomain_addon(org),
           {:ok, org} <- Orgs.clear_org_subdomain(org) do
        {:noreply,
         socket
         |> assign(:org, org)
         |> assign_subdomain_state(org)
         |> assign(
           :subdomain_form,
           to_form(Org.subdomain_changeset(org, %{}), as: :branding)
         )
         |> put_flash(
           :success,
           "Your custom subdomain has been released and the add-on removed — the prorated credit will appear on your next invoice."
         )}
      else
        {:error, _} ->
          {:noreply,
           put_flash(socket, :error, "Could not release the subdomain. Please try again.")}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Only the organization owner can manage the subdomain.")}
    end
  end

  # One-click add-on purchase for an already-active org (Task #240 / #243). The
  # dashboard is only reachable for a covered org, so there's always an active
  # subscription to append the line item to — no Checkout Session, no plan swap.
  # Re-checks the role gate server-side; the entitlement is set BY this action so
  # it must NOT be required up-front (that's the upsell branch's whole purpose).
  def handle_event("add_subdomain_addon", _params, socket) do
    org = socket.assigns.org

    if Orgs.can_manage_billing?(org, socket.assigns.current_scope.user.id) do
      case Orgs.add_subdomain_addon(org) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign_subdomain_state(org)
           |> assign(:subdomain_form, to_form(Org.subdomain_changeset(org, %{}), as: :branding))
           |> put_flash(
             :success,
             "The custom-subdomain add-on is now active. Claim your subdomain below."
           )}

        {:error, _reason} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "We couldn't add the subdomain add-on right now. Please try from billing, or contact support."
           )}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Only the organization owner can manage the subdomain.")}
    end
  end

  # One-click owner-only seat update for an active org (Task #247). Re-checks the
  # owner gate server-side, then sets the seat count via Orgs.set_org_seats/2
  # (which clamps to the plan range and refuses to drop below current usage). On
  # success the seat assigns refresh immediately; the broadcast_org_update also
  # re-runs assign_business_data for any other open sessions.
  def handle_event("update_org_seats", %{"seats" => seats}, socket) do
    org = socket.assigns.org

    if Orgs.can_manage_billing?(org, socket.assigns.current_scope.user.id) do
      case Orgs.set_org_seats(org, seats) do
        {:ok, target} ->
          {:noreply,
           socket
           |> assign(:seats, Orgs.seat_summary(org))
           |> assign(:seat_management, Orgs.seat_management_data(org))
           |> put_flash(
             :success,
             "Your organization now has #{target} seats. Any change is prorated to your next invoice."
           )}

        {:error, :below_current_usage} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "You can't set fewer seats than your team is currently using (including pending invites)."
           )}

        {:error, :seats_unavailable} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Seats can't be adjusted for this plan right now. Please try from billing, or contact support."
           )}

        {:error, _reason} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "We couldn't update your seats right now. Please try from billing, or contact support."
           )}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the organization owner can manage seats.")}
    end
  end

  # Toggle the collapsible "Manage organization" disclosure (Task #248). Children
  # stay in the DOM; we flip a socket assign that drives the panel's `hidden`
  # class + the toggle's aria-expanded state.
  def handle_event("toggle_manage", _params, socket) do
    {:noreply, assign(socket, :manage_open?, !socket.assigns.manage_open?)}
  end

  # Open the Manage disclosure (used by the seat-full notice's "Add more seats"
  # link, which deep-links to the relocated #org-seat-management control).
  def handle_event("open_manage", _params, socket) do
    {:noreply, assign(socket, :manage_open?, true)}
  end

  # Org-wide file overview sort (#229a). Only server-visible metadata (upload
  # time, byte size) is sortable server-side; filename search stays client-side
  # (ZK). Re-sorts the already-loaded list in memory (no re-query).
  def handle_event("sort_files", %{"sort" => sort}, socket) do
    sort = parse_file_sort(sort)

    org_file_circles = sort_org_file_circles(socket.assigns.org_file_circles, sort)

    {:noreply,
     socket
     |> assign(:file_sort, sort)
     |> assign_org_file_circles(org_file_circles)}
  end

  # us {:org_logo_upload_*} messages; nothing to do in the LiveView's progress cb.
  defp handle_logo_progress(:org_logo, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:org_logo_upload_progress, _ref, stage, percent}, socket) do
    {:noreply, assign(socket, :logo_upload_stage, {stage, percent})}
  end

  # Server finished processing the image (resize/WebP). Hand the final bytes to
  # the browser for ZK encryption with the org_key (OrgLogoUpload hook).
  @impl true
  def handle_info(
        {:org_logo_upload_ready, _ref, %{webp_binary: webp_binary, preview_data_url: preview}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:logo_upload_stage, {:encrypting, 90})
     |> assign(:pending_logo_preview, preview)
     |> push_event("encrypt_org_logo", %{
       blob_b64: Base.encode64(webp_binary),
       upload_id: "org_logo"
     })}
  end

  @impl true
  def handle_info({:org_logo_upload_error, _ref, reason}, socket) do
    {:noreply,
     socket
     |> assign(:logo_upload_stage, {:error, reason})
     |> put_flash(:warning, to_string(reason))}
  end

  @impl true
  def handle_info({:org_updated, _org_id}, socket) do
    current_user = socket.assigns.current_scope.user
    # Re-fetch the org so ownership-derived state (e.g. `is_owner?` after an
    # ownership transfer, Task #237) reflects the latest `created_by_id` rather
    # than the stale struct captured at mount.
    org = Orgs.get_org_by_id(socket.assigns.org.id) || socket.assigns.org

    # Realtime org changes (Task #223 pubsub). If the current user is still a
    # member, refresh the dashboard data + coverage. If they were removed (their
    # membership row is gone), send them off the org surface with a friendly
    # heads-up (loss-of-coverage state A) rather than crashing on a missing
    # membership.
    if Orgs.member_of_org?(org, current_user.id) do
      {:noreply,
       socket
       |> assign(:org, org)
       |> assign(:membership, Orgs.get_membership!(current_user, org.slug))
       |> assign(:coverage_status, Orgs.org_coverage_status(current_user))
       |> assign_business_data()}
    else
      {:noreply,
       socket
       |> put_flash(
         :info,
         "You're no longer a member of this organization. You can start your own plan or join another organization anytime."
       )
       |> push_navigate(to: ~p"/app/business")}
    end
  end

  # Personal-connection changes (Task #226): a teammate accepted our "Connect"
  # request (`:uconn_confirmed`), a new request landed, or one was removed.
  # Refresh the roster so the button/pill + the now-readable personal name
  # update live — no full reload.
  def handle_info({event, %Mosslet.Accounts.UserConnection{}}, socket)
      when event in [:uconn_confirmed, :uconn_created, :uconn_deleted, :uconn_updated] do
    {:noreply, assign_business_data(socket)}
  end

  # Realtime shared-file change in one of the org's circles (Task #232): a file
  # was uploaded, removed, or a catch-up granted access. Refresh the dashboard
  # so the "Files across your circles" overview updates live (no reload).
  def handle_info({:shared_files_updated, _id}, socket) do
    {:noreply, assign_business_data(socket)}
  end

  # Realtime org-wide announcement published (Task #229c): refresh the panel and,
  # for everyone EXCEPT the author (who just posted), surface a "new announcement"
  # toast. Id-only event (no plaintext/keys).
  def handle_info({:announcement_published, %{scope: :org, author_id: author_id}}, socket) do
    socket = assign_business_data(socket)

    socket =
      if author_id == socket.assigns.current_scope.user.id do
        socket
      else
        put_flash(socket, :info, "New announcement posted")
      end

    {:noreply, socket}
  end

  # An org-wide announcement was edited or deleted — refresh the panel (no toast).
  def handle_info({:announcements_updated, %{scope: :org}}, socket) do
    {:noreply, assign_business_data(socket)}
  end

  # A CIRCLE announcement was posted/edited/deleted in one of this org's circles
  # (Task #229c/#229d). Refresh so the per-circle "new announcement" badge on the
  # dashboard updates live. Id-only event (no plaintext/keys).
  def handle_info({:circle_announcement_activity, %{}}, socket) do
    {:noreply, assign_business_data(socket)}
  end

  # Realtime org-wide pin change (Task #229d): an owner/admin added, removed, or
  # reordered a shared pin. Refresh the strip (id-only event — no plaintext/keys).
  def handle_info({:pins_updated, %{scope: :org_shared}}, socket) do
    {:noreply, assign_business_data(socket)}
  end

  # Realtime audit event recorded (Task #212): an admin action was logged.
  # Refresh just the audit feed so connected admins see it live. Id-only event
  # (no plaintext/keys — descriptions render client-side).
  def handle_info({:audit_recorded, %{org_id: _org_id}}, socket) do
    {:noreply, assign(socket, :audit_events, Audit.list_audit_events(socket.assigns.org))}
  end

  # Realtime unread-@mention badge (Task #280): a new message in any business
  # circle the viewer belongs to. Recompute only the per-circle counts over the
  # circles we already hold (server-authoritative, ZK-safe) — no full data
  # refresh, so the browser-side circle-name decryption isn't re-triggered.
  def handle_info(%{event: "new_message"}, socket) do
    circles = put_unread_mention_counts(socket.assigns.circles)

    {:noreply,
     socket
     |> assign(:circles, circles)
     |> assign(:team_circles, Enum.filter(circles, &(&1.org_circle_type == :team)))
     |> assign(:community_circles, Enum.filter(circles, &(&1.org_circle_type != :team)))}
  end

  # Ignore unrelated process messages (e.g. Swoosh test email delivery, telemetry).
  def handle_info(_message, socket), do: {:noreply, socket}

  ## Data loading

  # Org brand logo (Task #228): a short-lived presigned GET URL for the opaque
  # (org_key-encrypted) blob, or nil when no logo is set. The browser fetches the
  # ciphertext and decrypts it with the org_key (OrgLogoDisplay hook).
  defp org_logo_presigned_url(%{logo_url: path}) when is_binary(path) do
    case Mosslet.FileUploads.SharedFileStorage.presigned_url(path) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  defp org_logo_presigned_url(_), do: nil

  # The org's branded address for display (Task #240). The subdomain label is
  # non-sensitive plaintext; the base host comes from the canonical-host config
  # (apex the subdomain hangs off), falling back to the production apex.
  defp subdomain_display_url(subdomain) when is_binary(subdomain) do
    "#{subdomain}.#{Application.get_env(:mosslet, :canonical_host) || "mosslet.com"}"
  end

  # Defensive: a released/absent subdomain renders nothing. The branded-space
  # sections are already gated by `@subdomain_live?` / `@org.subdomain`, but this
  # keeps a transient assign state (mid-release) from crashing the diff.
  defp subdomain_display_url(_), do: ""

  # Whether the current request is being served on THIS org's branded subdomain
  # (Task #246). Drives the "Open your branded space" CTA — we only invite a
  # member to switch hosts when they're NOT already on it. Reuses the host plug's
  # parser against `socket.host_uri`; safely false on apex / when unset.
  defp on_org_subdomain?(socket, %{subdomain: subdomain}) when is_binary(subdomain) do
    with %URI{host: host} when is_binary(host) <- socket.host_uri,
         base when is_binary(base) <- Application.get_env(:mosslet, :canonical_host),
         {:ok, label} <- MossletWeb.Plugs.OrgSubdomain.subdomain_label(host, base) do
      label == subdomain
    else
      _ -> false
    end
  end

  defp on_org_subdomain?(_socket, _org), do: false

  # Resolve the org's pending ownership transfer once and derive whether the
  # viewer is its proposed new owner (drives both the ownership section and the
  # "Manage" disclosure gate) — single query, no N+1.
  defp assign_pending_transfer(socket, org, current_user) do
    pending_transfer = Orgs.get_pending_transfer_for_org(org)

    socket
    |> assign(:pending_transfer, pending_transfer)
    |> assign(:incoming_transfer?, incoming_transfer?(pending_transfer, current_user))
  end

  # True when the viewer is the proposed new owner of a pending ownership
  # transfer. Mirrors `OrgComponents.ownership_section`'s internal check so the
  # collapsible "Manage" disclosure still surfaces for a plain member who needs
  # to Accept/Decline an incoming transfer (otherwise gated to admins/owner).
  defp incoming_transfer?(%{to_user_id: user_id}, %{id: user_id}), do: true
  defp incoming_transfer?(_pending_transfer, _user), do: false

  defp logo_processing?({stage, _}) when stage in [:receiving, :processing, :encrypting], do: true
  defp logo_processing?(_), do: false

  # Whether to show the inline "edit display name" affordance on a roster row
  # (Task #263). Requires the viewer to hold the org_key (else they can't
  # encrypt). The viewer may re-edit their OWN name once set — the first-time
  # prompt covers the unset case; admins/owners may edit anyone's.
  defp show_edit_name?(_member, nil, _can_manage?), do: false

  defp show_edit_name?(%{self?: true} = member, _sealed, _can_manage?),
    do: not is_nil(member.encrypted_display_name)

  defp show_edit_name?(%{self?: false}, _sealed, can_manage?), do: can_manage?

  defp logo_stage_label({:receiving, _}), do: "Uploading…"
  defp logo_stage_label({:processing, _}), do: "Processing…"
  defp logo_stage_label({:encrypting, _}), do: "Encrypting…"
  defp logo_stage_label(_), do: "Working…"

  defp logo_upload_error(:too_large), do: "That image is too large (5 MB max)."
  defp logo_upload_error(:too_many_files), do: "Please choose a single image."
  defp logo_upload_error(:not_accepted), do: "Please use a PNG, JPG, WebP, or HEIC image."
  defp logo_upload_error(_), do: "Something went wrong with that file."

  # Recompute the per-circle unread @mention count (Task #280) over already-built
  # business-circle view-models. Server-authoritative + ZK-safe: counts come from
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

  # Subscribe to each business circle's `group:#{id}` PubSub topic (Task #280) so
  # a new message anywhere refreshes the unread-@mention badge live. Subscribing
  # is NOT idempotent (a repeat yields duplicate messages), so this runs exactly
  # once in mount — never on data refresh.
  defp maybe_subscribe_to_business_circles(socket, false), do: socket

  defp maybe_subscribe_to_business_circles(socket, true) do
    Enum.each(socket.assigns.circles, fn %{group: group} ->
      Groups.group_subscribe(group)
    end)

    socket
  end

  defp assign_business_data(socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    org = socket.assigns.org

    users = Orgs.list_members_by_org(org)
    member_user_ids = MapSet.new(users, & &1.id)

    # Batched personal-connection status for the roster (Task #226): one query
    # instead of N. Drives the one-tap "Connect with teammate" button.
    connection_statuses =
      Accounts.connection_statuses_for(
        current_user.id,
        Enum.map(users, & &1.id)
      )

    # Org-scoped ZK identity (Task #225): build roster rows carrying the org
    # display-name ciphertext + a preferred personal-connection name (Q4). The
    # plaintext org persona is filled in client-side by the OrgMembers hook.
    members =
      MossletWeb.OrgIdentity.build_members(
        org,
        current_user,
        fn user -> personal_connection_name(user, current_user, key) end,
        connection_statuses
      )

    # Candidate members for the circle composer: the creator's confirmed
    # connections who are also current org members (server still enforces I1).
    eligible_members =
      current_user.id
      |> Accounts.get_all_confirmed_user_connections()
      |> Enum.map(fn uconn ->
        %{
          user: Accounts.get_user!(uconn.connection.user_id),
          uconn: uconn
        }
      end)
      |> Enum.filter(&MapSet.member?(member_user_ids, &1.user.id))

    circles =
      org
      |> Groups.list_business_circles(current_user)
      |> Enum.map(fn group ->
        user_group = Enum.find(group.user_groups, &(&1.user_id == current_user.id))

        %{
          group: group,
          encrypted_name: group.name,
          org_circle_type: group.org_circle_type,
          sealed_group_key: user_group && user_group.key,
          # The viewer's user_group id drives the server-authoritative, ZK-safe
          # unread-@mention count (Task #280); never derived from ciphertext.
          user_group_id: user_group && user_group.id,
          member_count: length(group.user_groups),
          unread_announcements: Announcements.unread_circle_count(group, current_user),
          unread_mention_count: 0,
          viewer_can_manage?:
            socket.assigns.membership.role == :admin or
              (is_struct(user_group) and user_group.role in [:owner, :admin])
        }
      end)
      |> put_unread_mention_counts()

    # Org-wide ZK file overview (Task #221 / #229): every file the viewer can
    # read across this org's circles, grouped by circle, newest first. The
    # circle name stays encrypted — decrypted browser-side via the viewer's
    # sealed group key (looked up from the circles we already loaded).
    sealed_keys_by_group =
      Map.new(circles, fn circle -> {circle.group.id, circle.sealed_group_key} end)

    file_sort = Map.get(socket.assigns, :file_sort, :newest)

    org_shared_files = Files.list_org_shared_files_for_user(org.id, current_user)

    org_file_circles =
      org_shared_files
      |> Enum.group_by(& &1.group_id)
      |> Enum.map(fn {group_id, files} ->
        group = hd(files).group

        %{
          group: group,
          encrypted_name: group.name,
          org_circle_type: group.org_circle_type,
          sealed_group_key: Map.get(sealed_keys_by_group, group_id),
          files: files
        }
      end)
      |> Enum.sort_by(fn %{files: files} -> hd(files).inserted_at end, {:desc, NaiveDateTime})
      |> sort_org_file_circles(file_sort)

    # Org-wide ZK announcements (Task #229c): the live notices for this org,
    # split into a single pinned banner + the "Recent" list. Bodies stay
    # encrypted and decrypt browser-side with the org_key.
    org_announcements = Announcements.list_org_announcements(org)
    {announcement_banner, announcement_recent} = Announcements.partition_pinned(org_announcements)

    # Dashboard pins (Task #229d): resolve the org-wide + personal pins into
    # render view-models. Circle/file pins reuse the already-loaded sealed keys +
    # ciphertext (FK-only, ZK) and are dropped if the viewer can't access the
    # target; link pins carry their own encrypted label/URL.
    can_manage_org_pins? = Pins.can_manage_org_pins?(org, current_user.id)
    circles_by_id = Map.new(circles, fn circle -> {circle.group.id, circle} end)
    files_by_id = Map.new(org_shared_files, fn file -> {file.id, file} end)

    org_shared_pins =
      org
      |> Pins.list_org_shared_pins()
      |> resolve_pins(can_manage_org_pins?, circles_by_id, files_by_id, org)

    personal_pins =
      org
      |> Pins.list_personal_pins(current_user)
      |> resolve_pins(true, circles_by_id, files_by_id, org)

    socket
    |> assign(:members, members)
    |> assign(:viewer_sealed_org_key, MossletWeb.OrgIdentity.viewer_sealed_org_key(members))
    |> assign(
      :should_bootstrap_org_key?,
      MossletWeb.OrgIdentity.should_bootstrap?(org, current_user, members)
    )
    |> assign(:eligible_members, eligible_members)
    |> assign(:circles, circles)
    |> assign(:team_circles, Enum.filter(circles, &(&1.org_circle_type == :team)))
    |> assign(:community_circles, Enum.filter(circles, &(&1.org_circle_type != :team)))
    |> assign(:can_create_team_circle?, Orgs.can_create_team_circle?(org, current_user.id))
    |> assign(:announcement_banner, announcement_banner)
    |> assign(:announcement_recent, announcement_recent)
    |> assign(:announcement_unread_count, Announcements.unread_org_count(org, current_user))
    |> assign(
      :can_post_announcement?,
      Announcements.can_post_org_announcement?(org, current_user.id)
    )
    |> assign(:org_shared_pins, org_shared_pins)
    |> assign(:personal_pins, personal_pins)
    |> assign(:can_manage_org_pins?, can_manage_org_pins?)
    |> assign(:can_pin_personal?, Pins.can_pin_personal?(org, current_user.id))
    |> assign(:personal_pinned_circle_ids, pinned_target_ids(personal_pins, :circle))
    |> assign(:personal_pinned_file_ids, pinned_target_ids(personal_pins, :file))
    |> assign(:org_pinned_circle_ids, pinned_target_ids(org_shared_pins, :circle))
    |> assign(:org_pinned_file_ids, pinned_target_ids(org_shared_pins, :file))
    |> assign_org_file_circles(org_file_circles)
    |> assign(:pending_invitations, Orgs.list_invitations_by_org(org))
    |> assign(:seats, Orgs.seat_summary(org))
    |> assign(:seat_management, Orgs.seat_management_data(org))
    |> assign(:can_manage?, socket.assigns.membership.role == :admin)
    |> assign(:is_owner?, Orgs.owner?(org, current_user.id))
    |> assign(:can_view_audit_log?, Audit.can_view_audit_log?(org, current_user.id))
    |> assign(:audit_events, Audit.list_audit_events(org))
    |> assign(:audit_member_directory, audit_member_directory(members))
    |> assign(
      :can_manage_branding?,
      Orgs.can_manage_branding?(org, socket.assigns.membership)
    )
    |> assign_subdomain_state(org)
    |> assign(:subdomain_form, to_form(Org.subdomain_changeset(org, %{}), as: :branding))
    |> assign(:org_logo_url, org_logo_presigned_url(org))
    |> assign_pending_transfer(org, current_user)
    |> assign_manage_circle(members)
    |> maybe_request_org_key_seal()
  end

  # Compact JSON directory mapping each member's user_id -> their org-display-name
  # CIPHERTEXT (org_key secretbox). Handed to the AuditLog hook so it can resolve
  # actor/target names CLIENT-SIDE (decrypting with the org_key the viewer already
  # holds) — the server never sees the plaintext names. ZK-safe: only opaque ids
  # + ciphertext leave the server.
  defp audit_member_directory(members) do
    members
    |> Enum.map(fn m -> %{"id" => m.user.id, "name" => m.encrypted_display_name || ""} end)
    |> Jason.encode!()
  end

  # Generic, name-free server-rendered fallback for an audit row (shown before the
  # AuditLog hook enriches it with client-decrypted names, or if decryption is
  # unavailable). NEVER contains sensitive content.
  defp audit_action_label("member_invited"), do: "A teammate was invited"
  defp audit_action_label("member_added"), do: "A teammate joined the organization"
  defp audit_action_label("member_removed"), do: "A teammate was removed from the organization"
  defp audit_action_label("role_changed"), do: "A teammate's role was changed"
  defp audit_action_label("display_name_changed"), do: "A teammate's display name was changed"
  defp audit_action_label("circle_created"), do: "A circle was created"
  defp audit_action_label("file_shared"), do: "A file was shared"
  defp audit_action_label("file_revoked"), do: "A file was removed"
  defp audit_action_label(_), do: "An action was performed"

  defp audit_action_icon("member_invited"), do: "hero-envelope"
  defp audit_action_icon("member_added"), do: "hero-user-plus"
  defp audit_action_icon("member_removed"), do: "hero-user-minus"
  defp audit_action_icon("role_changed"), do: "hero-adjustments-horizontal"
  defp audit_action_icon("display_name_changed"), do: "hero-pencil-square"
  defp audit_action_icon("circle_created"), do: "hero-user-group"
  defp audit_action_icon("file_shared"), do: "hero-document-arrow-up"
  defp audit_action_icon("file_revoked"), do: "hero-document-minus"
  defp audit_action_icon(_), do: "hero-clock"

  # Recomputes the four subdomain/add-on-derived assigns from the org's current
  # (server-authoritative) state. Called from `assign_business_data/1` AND from
  # the claim/add/release handlers so the UI stays consistent after a mutation —
  # e.g. releasing the subdomain flips `has_branding_addon?`/`subdomain_live?`
  # to false (which also prevents rendering `subdomain_display_url/1` with a now
  # nil subdomain).
  defp assign_subdomain_state(socket, org) do
    socket
    |> assign(:has_branding_addon?, Orgs.has_branding_addon?(org))
    |> assign(:subdomain_live?, Orgs.subdomain_live?(org))
    |> assign(:org_branded_url, Orgs.org_base_url(org))
    |> assign(:on_org_subdomain?, on_org_subdomain?(socket, org))
  end

  # Builds the per-circle member-management view-model for the circle currently
  # being managed (`@manage_circle_id`), or nil when no circle is open. Lets an
  # admin add/remove members for an existing circle from the org dashboard (Task
  # #231) — consistent with the CircleShow members section.
  #
  # `members` is the full org roster (carrying each member's org-display-name
  # ciphertext, built once by `assign_business_data/1`). We scope it to THIS
  # circle's confirmed members for the roster, and derive the addable set (any
  # org member not yet in the circle, excluding self) for the composer. All
  # server-authoritative — the add write re-enforces org-eligibility (I1).
  defp assign_manage_circle(socket, members) do
    current_user = socket.assigns.current_scope.user

    manage =
      case socket.assigns.manage_circle_id do
        nil ->
          nil

        circle_id ->
          group = Groups.get_group!(circle_id)

          if is_nil(group) or group.org_id != socket.assigns.org.id do
            nil
          else
            user_group = Enum.find(group.user_groups, &(&1.user_id == current_user.id))

            circle_member_ids =
              group.user_groups
              |> Enum.filter(&(not is_nil(&1.confirmed_at)))
              |> MapSet.new(& &1.user_id)

            circle_members =
              Enum.filter(members, &MapSet.member?(circle_member_ids, &1.user.id))

            addable =
              Enum.filter(members, fn m ->
                not m.self? and not MapSet.member?(circle_member_ids, m.user.id)
              end)

            %{
              group: group,
              user_group: user_group,
              sealed_group_key: user_group && user_group.key,
              members: circle_members,
              addable_members: addable,
              member_count: MapSet.size(circle_member_ids)
            }
          end
      end

    assign(socket, :manage_circle, manage)
  end

  # After loading roster data, if the viewer holds the org_key and some members
  # lack it, ask the viewer's browser to seal it for them (design 4.2b). If
  # nobody holds it yet and the viewer is the owner, ask the browser to bootstrap
  # (Q1=A). Only meaningful on a connected socket (the hook is alive).
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
      "Add more seats to invite another teammate."
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

  # Personal-connection name the viewer can already read for `user` (Q4: preferred
  # over the org persona when present). Returns nil when there is no connection —
  # the org display name (or neutral placeholder) is used instead. Never returns
  # "Team member" here; that placeholder is the shared OrgIdentity fallback.
  defp personal_connection_name(user, current_user, key) do
    case Mosslet.Accounts.get_user_connection_between_users(user.id, current_user.id) do
      %{} = uconn ->
        uconn = Mosslet.Repo.preload(uconn, :connection)
        get_decrypted_connection_name(uconn, current_user, key)

      _ ->
        nil
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
        put_flash(socket, :error, "That person isn't a member of this organization.")

      {:error, _changeset} ->
        socket
        |> put_flash(:info, "You've already sent a request or are connected.")
        |> refresh_fun.()
    end
  end

  defp role_error_message(changeset) do
    case changeset.errors[:role] do
      {msg, _} -> msg
      _ -> "Could not update"
    end
  end

  # Whether the viewer may manage membership for the given circle: an org admin
  # (org-level role) OR the circle owner/admin (per-circle role). Server-
  # authoritative — checked on every add/remove write.
  defp can_manage_circle?(socket, manage) do
    org_admin? = socket.assigns.membership.role == :admin

    circle_manager? =
      is_struct(manage.user_group) and manage.user_group.role in [:owner, :admin]

    org_admin? or circle_manager?
  end

  defp random_avatar do
    Enum.random(
      ~w(astronaut.png bear.png cat.png chicken.png dinosaur.png dog.png panda.png penguin.png rabbit.png sea-lion.png)
    )
  end

  defp format_size(nil), do: "—"

  defp format_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  # Resolves each dashboard pin (Task #229d) into a render view-model. Circle and
  # file pins are FK-only: we reuse the already-loaded sealed key + ciphertext
  # (ZK — the server never decrypts the name) and DROP pins whose target the
  # viewer can't access. Link pins carry their own encrypted label/URL. `org` is
  # used to build the click-through navigation path.
  defp resolve_pins(pins, can_manage?, circles_by_id, files_by_id, org) do
    Enum.flat_map(pins, fn pin ->
      case pin.pin_type do
        :link ->
          [
            %{
              pin: pin,
              can_manage?: can_manage?,
              sealed_key: nil,
              label_ciphertext: nil,
              navigate: nil
            }
          ]

        :circle ->
          case Map.get(circles_by_id, pin.target_id) do
            nil ->
              []

            circle ->
              [
                %{
                  pin: pin,
                  can_manage?: can_manage?,
                  sealed_key: circle.sealed_group_key,
                  label_ciphertext: circle.encrypted_name,
                  org_circle_type: circle.org_circle_type,
                  navigate: ~p"/app/business/#{org.slug}/circles/#{circle.group.id}"
                }
              ]
          end

        :file ->
          case Map.get(files_by_id, pin.target_id) do
            nil ->
              []

            file ->
              viewer_row = List.first(file.user_shared_files)

              if viewer_row && file.encrypted_filename do
                [
                  %{
                    pin: pin,
                    can_manage?: can_manage?,
                    sealed_key: viewer_row.key,
                    label_ciphertext: file.encrypted_filename,
                    navigate: ~p"/app/business/#{org.slug}/circles/#{file.group_id}"
                  }
                ]
              else
                []
              end
          end
      end
    end)
  end

  # The set of target ids pinned for a given pin_type (drives the quick-pin
  # toggle button state on circle cards / file rows).
  defp pinned_target_ids(resolved_pins, pin_type) do
    resolved_pins
    |> Enum.filter(&(&1.pin.pin_type == pin_type))
    |> MapSet.new(& &1.pin.target_id)
  end

  # Assigns the org-wide file overview plus its two classification partitions
  # (#229b: official "Departments & Teams" vs "Community circles"). Keeps all
  # three assigns in sync from one place (used by initial load + sort handler).
  defp assign_org_file_circles(socket, org_file_circles) do
    socket
    |> assign(:org_file_circles, org_file_circles)
    |> assign(:team_file_circles, Enum.filter(org_file_circles, &(&1.org_circle_type == :team)))
    |> assign(
      :community_file_circles,
      Enum.filter(org_file_circles, &(&1.org_circle_type != :team))
    )
  end

  # Server-side sort of the org-wide file overview (#229a). Only server-VISIBLE
  # metadata is sorted here (upload time, byte size) — filename sorting/search is
  # ZK and lives entirely in the browser (OrgFileSearch hook), since the server
  # never sees plaintext names. We sort the files WITHIN each circle; the circle
  # blocks themselves stay ordered by their most-recent file.
  defp sort_org_file_circles(org_file_circles, sort) do
    Enum.map(org_file_circles, fn entry ->
      %{entry | files: sort_files(entry.files, sort)}
    end)
  end

  defp sort_files(files, :newest),
    do: Enum.sort_by(files, & &1.inserted_at, {:desc, NaiveDateTime})

  defp sort_files(files, :oldest),
    do: Enum.sort_by(files, & &1.inserted_at, {:asc, NaiveDateTime})

  defp sort_files(files, :largest), do: Enum.sort_by(files, &(&1.size_bytes || 0), :desc)
  defp sort_files(files, :smallest), do: Enum.sort_by(files, &(&1.size_bytes || 0), :asc)
  defp sort_files(files, _), do: files

  # Maps the user-supplied sort string to a known atom (never String.to_atom on
  # user input). Unknown values fall back to :newest.
  defp parse_file_sort("newest"), do: :newest
  defp parse_file_sort("oldest"), do: :oldest
  defp parse_file_sort("largest"), do: :largest
  defp parse_file_sort("smallest"), do: :smallest
  defp parse_file_sort(_), do: :newest

  # Maps the client circle-type hint to a known atom (never String.to_atom on
  # user input). Unknown values fall back to :community (the unprivileged tier).
  defp parse_circle_type("team"), do: :team
  defp parse_circle_type("community"), do: :community
  defp parse_circle_type(_), do: :community
end
