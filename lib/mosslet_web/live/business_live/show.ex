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
  alias Mosslet.Files
  alias Mosslet.FileUploads.SharedFileStorage
  alias Mosslet.Groups
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Org

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
       |> assign(:show_circle_form?, false)
       |> assign(:circle_form, to_form(%{"name" => "", "description" => ""}, as: :circle))
       |> assign(:pending_zk_circle_attrs, nil)
       |> assign(:pending_zk_circle_users, nil)
       |> assign(:manage_circle_id, nil)
       |> assign(:manage_circle, nil)
       |> assign(:pending_add_member_ids, [])
       |> assign(:transfer_modal_open, false)
       |> assign(:transfer_form, to_form(%{"password" => "", "to_user_id" => ""}, as: :transfer))
       |> assign(:delete_modal_open, false)
       |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete_org))
       |> assign(:logo_upload_stage, nil)
       |> assign(:pending_logo_preview, nil)
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
       |> assign_business_data()}
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
      <div class="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8 lg:py-10 space-y-6">
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

        <%!-- Member management --%>
        <section class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4">
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
            :if={@can_manage? && @seats.available == 0}
            id="business-seat-full-notice"
            class="rounded-lg bg-amber-50 dark:bg-amber-900/20 px-3 py-2 text-xs text-amber-800 dark:text-amber-300"
          >
            All seats are in use (including pending invites).
            <.link
              navigate={~p"/app/org/#{@org.slug}/subscribe"}
              class="font-semibold underline hover:no-underline"
            >
              Add more seats
            </.link>
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

              <div class="flex items-center gap-2 flex-shrink-0">
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
                Gated by has_branding_addon?/1 (server-authoritative). The logo
                above stays free; only this subdomain is behind the add-on. --%>
          <div
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
                    data-confirm="Release this subdomain? Your branded address will stop working."
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
                  class="rounded-xl border border-teal-200/70 dark:border-teal-800/50 bg-teal-50/60 dark:bg-teal-900/20 p-4 space-y-2"
                >
                  <p class="text-sm font-medium text-teal-900 dark:text-teal-200">
                    Add a custom subdomain to your plan
                  </p>
                  <p class="text-xs text-teal-800/80 dark:text-teal-300/80">
                    The custom-subdomain add-on is $15/mo (or $150/yr). You can add it from your
                    organization's billing settings.
                  </p>
                  <.link
                    navigate={~p"/app/org/#{@org.slug}/billing"}
                    class="inline-flex items-center gap-1.5 text-sm font-medium text-teal-700 dark:text-teal-300 hover:text-teal-800 dark:hover:text-teal-200"
                  >
                    <.phx_icon name="hero-credit-card" class="size-4" /> Manage billing
                  </.link>
                </div>
            <% end %>
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
          delete_modal_open={@delete_modal_open}
          delete_form={@delete_form}
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

          <ul role="list" class="space-y-2">
            <li
              :for={circle <- @circles}
              id={"circle-#{circle.group.id}"}
              data-hook-scope={"business-circle-#{circle.group.id}"}
              class="group overflow-hidden rounded-xl border border-slate-200/60 dark:border-slate-700/60 bg-white/70 dark:bg-slate-800/50 transition-all duration-200 hover:border-emerald-300/60 dark:hover:border-emerald-700/50"
            >
              <div
                id={"decrypt-business-circle-#{circle.group.id}"}
                phx-hook="DecryptGroupMetadata"
                data-sealed-group-key={circle.sealed_group_key}
                data-encrypted-name={circle.encrypted_name}
                data-scope-id={"business-circle-#{circle.group.id}"}
              >
              </div>
              <.link
                navigate={~p"/app/business/#{@org.slug}/circles/#{circle.group.id}"}
                class="flex items-center gap-3 p-3"
              >
                <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300 group-hover:text-teal-600 dark:group-hover:text-teal-300">
                  <.phx_icon name="hero-chat-bubble-left-right" class="size-4" />
                </div>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                    <span data-decrypt-group-name>Business circle</span>
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

              <%!-- Per-circle member management (Task #231): an org admin or the
                   circle owner/admin can add/remove members without leaving the
                   org dashboard. Consistent with the CircleShow members section. --%>
              <div
                :if={circle.viewer_can_manage?}
                class="border-t border-slate-200/60 dark:border-slate-700/60 px-3 py-2"
              >
                <button
                  :if={!(@manage_circle && @manage_circle.group.id == circle.group.id)}
                  type="button"
                  phx-click="manage_circle"
                  phx-value-circle_id={circle.group.id}
                  id={"manage-circle-#{circle.group.id}"}
                  class="inline-flex items-center gap-1.5 text-xs font-medium text-teal-600 dark:text-teal-400 hover:underline"
                >
                  <.phx_icon name="hero-users" class="size-3.5" /> Manage members
                </button>

                <.circle_manage_panel
                  :if={@manage_circle && @manage_circle.group.id == circle.group.id}
                  manage={@manage_circle}
                  org={@org}
                  viewer_sealed_org_key={@viewer_sealed_org_key}
                  current_user_id={@current_scope.user.id}
                />
              </div>
            </li>
            <li
              :if={@circles == [] && !@show_circle_form?}
              class="text-xs text-slate-500 dark:text-slate-400"
            >
              No business circles yet. Create one to start a private, encrypted team space.
            </li>
          </ul>
        </section>

        <%!-- Org-wide files overview (Task #221): every file the viewer can read
             across this org's circles, grouped by circle. Names stay encrypted
             and decrypt browser-side (ZK). Tap a circle to open it. --%>
        <section
          :if={@org_file_circles != []}
          id="org-files-overview"
          class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
        >
          <div>
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
              Files across your circles
            </h2>
            <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
              Everything shared with circles you're in. Encrypted on each member's device —
              Mosslet can't read them.
            </p>
          </div>

          <div
            :for={entry <- @org_file_circles}
            id={"org-files-circle-#{entry.group.id}"}
            data-hook-scope={"files-circle-#{entry.group.id}"}
            class="space-y-2"
          >
            <div
              id={"decrypt-files-circle-#{entry.group.id}"}
              phx-hook="DecryptGroupMetadata"
              data-sealed-group-key={entry.sealed_group_key}
              data-encrypted-name={entry.encrypted_name}
              data-scope-id={"files-circle-#{entry.group.id}"}
            >
            </div>
            <.link
              navigate={~p"/app/business/#{@org.slug}/circles/#{entry.group.id}"}
              class="flex items-center gap-2 text-xs font-semibold text-teal-600 dark:text-teal-400 hover:underline"
            >
              <.phx_icon name="hero-chat-bubble-left-right" class="size-3.5" />
              <span data-decrypt-group-name>Business circle</span>
              <span class="text-slate-400 dark:text-slate-500 font-normal">
                · {length(entry.files)} file{if length(entry.files) != 1, do: "s"}
              </span>
            </.link>
            <ul role="list" class="divide-y divide-slate-100 dark:divide-slate-700/60 pl-1">
              <li
                :for={file <- entry.files}
                id={"org-file-#{file.id}"}
                class="py-2.5 flex items-center gap-3"
              >
                <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                  <.phx_icon name="hero-document" class="size-4" />
                </div>
                <div class="min-w-0">
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
                  <p class="text-xs text-slate-500 dark:text-slate-400">
                    {format_size(file.size_bytes)}
                  </p>
                </div>
              </li>
            </ul>
          </div>
        </section>
      </div>
    </.layout>
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

      case Groups.create_business_circle_zk(org, user, zk_attrs, users, sealed_members) do
        {:ok, group} ->
          Mosslet.Logs.log("orgs.create_business_circle", %{
            user: user,
            org_id: org.id,
            metadata: %{"group_id" => group.id}
          })

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
        %{"encrypted_display_name" => encrypted_name},
        socket
      )
      when is_binary(encrypted_name) do
    case Orgs.set_org_display_name(socket.assigns.membership, encrypted_name) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:success, "Your team display name is set")
         |> assign_business_data()}

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

  @impl true
  def handle_event("org_display_name_invalid", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Please use letters, spaces, and basic punctuation (up to 160 characters)."
     )}
  end

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
      # Role gate (admins-only) — unchanged from logo management.
      not Orgs.can_manage_branding?(org, socket.assigns.membership) ->
        {:noreply, put_flash(socket, :error, "You don't have permission to manage branding.")}

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

    if Orgs.can_manage_branding?(org, socket.assigns.membership) do
      case Orgs.clear_org_subdomain(org) do
        {:ok, org} ->
          {:noreply,
           socket
           |> assign(:org, org)
           |> assign(
             :subdomain_form,
             to_form(Org.subdomain_changeset(org, %{}), as: :branding)
           )
           |> put_flash(:success, "Your custom subdomain has been released.")}

        {:error, _} ->
          {:noreply,
           put_flash(socket, :error, "Could not release the subdomain. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage branding.")}
    end
  end

  # Auto-upload entry progress is driven by the OrgLogoUploadWriter, which sends
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

  defp logo_processing?({stage, _}) when stage in [:receiving, :processing, :encrypting], do: true
  defp logo_processing?(_), do: false

  defp logo_stage_label({:receiving, _}), do: "Uploading…"
  defp logo_stage_label({:processing, _}), do: "Processing…"
  defp logo_stage_label({:encrypting, _}), do: "Encrypting…"
  defp logo_stage_label(_), do: "Working…"

  defp logo_upload_error(:too_large), do: "That image is too large (5 MB max)."
  defp logo_upload_error(:too_many_files), do: "Please choose a single image."
  defp logo_upload_error(:not_accepted), do: "Please use a PNG, JPG, WebP, or HEIC image."
  defp logo_upload_error(_), do: "Something went wrong with that file."

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
          sealed_group_key: user_group && user_group.key,
          member_count: length(group.user_groups),
          viewer_can_manage?:
            socket.assigns.membership.role == :admin or
              (is_struct(user_group) and user_group.role in [:owner, :admin])
        }
      end)

    # Org-wide ZK file overview (Task #221 / #229): every file the viewer can
    # read across this org's circles, grouped by circle, newest first. The
    # circle name stays encrypted — decrypted browser-side via the viewer's
    # sealed group key (looked up from the circles we already loaded).
    sealed_keys_by_group =
      Map.new(circles, fn circle -> {circle.group.id, circle.sealed_group_key} end)

    org_file_circles =
      org.id
      |> Files.list_org_shared_files_for_user(current_user)
      |> Enum.group_by(& &1.group_id)
      |> Enum.map(fn {group_id, files} ->
        group = hd(files).group

        %{
          group: group,
          encrypted_name: group.name,
          sealed_group_key: Map.get(sealed_keys_by_group, group_id),
          files: files
        }
      end)
      |> Enum.sort_by(fn %{files: files} -> hd(files).inserted_at end, {:desc, NaiveDateTime})

    socket
    |> assign(:members, members)
    |> assign(:viewer_sealed_org_key, MossletWeb.OrgIdentity.viewer_sealed_org_key(members))
    |> assign(
      :should_bootstrap_org_key?,
      MossletWeb.OrgIdentity.should_bootstrap?(org, current_user, members)
    )
    |> assign(:eligible_members, eligible_members)
    |> assign(:circles, circles)
    |> assign(:org_file_circles, org_file_circles)
    |> assign(:pending_invitations, Orgs.list_invitations_by_org(org))
    |> assign(:seats, Orgs.seat_summary(org))
    |> assign(:can_manage?, socket.assigns.membership.role == :admin)
    |> assign(:is_owner?, Orgs.owner?(org, current_user.id))
    |> assign(
      :can_manage_branding?,
      Orgs.can_manage_branding?(org, socket.assigns.membership)
    )
    |> assign(:has_branding_addon?, Orgs.has_branding_addon?(org))
    |> assign(:subdomain_form, to_form(Org.subdomain_changeset(org, %{}), as: :branding))
    |> assign(:org_logo_url, org_logo_presigned_url(org))
    |> assign(:pending_transfer, Orgs.get_pending_transfer_for_org(org))
    |> assign_manage_circle(members)
    |> maybe_request_org_key_seal()
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
end
