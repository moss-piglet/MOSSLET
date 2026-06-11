defmodule MossletWeb.FamilyLive.Show do
  @moduledoc """
  Family org dashboard: member list with roles, guardianship management
  (establish / accept / decline / pause / resume / revoke), invitations, and the
  always-visible managed-member transparency panel (I2).

  All guardian appends to the ZK write path are server-authoritative and derived
  from `Orgs.Guardianship` records (see `docs/GUARDIANSHIP_DESIGN.md`).
  """
  use MossletWeb, :live_view

  alias Mosslet.Orgs

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    org = Orgs.get_org!(current_user, slug)
    membership = Orgs.get_membership!(current_user, slug)

    if org.type == :family do
      {:ok,
       socket
       |> assign(:org, org)
       |> assign(:membership, membership)
       |> assign(:page_title, org.name)
       |> assign(:invite_form, to_form(%{"email" => ""}, as: :invite))
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
              <.phx_button
                phx-click="accept_guardianship"
                phx-value-id={item.guardianship.id}
                id={"accept-#{item.guardianship.id}"}
              >
                Accept
              </.phx_button>
              <button
                phx-click="decline_guardianship"
                phx-value-id={item.guardianship.id}
                class="text-xs font-medium text-slate-500 dark:text-slate-400 hover:text-slate-700"
              >
                Decline
              </button>
            </div>
          </div>
        </div>

        <%!-- Member management (admin only) --%>
        <section class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">Members</h2>
          </div>

          <ul role="list" class="divide-y divide-slate-100 dark:divide-slate-700/60">
            <li
              :for={member <- @members}
              id={"member-#{member.user.id}"}
              class="py-3 flex items-center justify-between gap-3"
            >
              <div class="flex items-center gap-3 min-w-0">
                <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                  <.phx_icon name="hero-user" class="size-4" />
                </div>
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                      {member.display_name}
                    </p>
                    <.family_role_badge role={member.membership.role} />
                  </div>
                  <p
                    :if={member.guardian_summaries != []}
                    class="text-xs text-slate-500 dark:text-slate-400"
                  >
                    Guardians: {Enum.join(member.guardian_summaries, ", ")}
                  </p>
                </div>
              </div>

              <div :if={@membership.role == :admin} class="flex items-center gap-2 flex-shrink-0">
                <form phx-change="change_role" id={"role-form-#{member.user.id}"}>
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
              <.phx_button type="submit" id="invite-submit">Invite</.phx_button>
            </.form>
          </div>
        </section>

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
                <button
                  :if={g.guardianship.status == :active}
                  phx-click="pause_guardianship"
                  phx-value-id={g.guardianship.id}
                  class="text-xs font-medium text-slate-500 hover:text-slate-700 dark:text-slate-400"
                >
                  Pause
                </button>
                <button
                  :if={g.guardianship.status == :paused}
                  phx-click="resume_guardianship"
                  phx-value-id={g.guardianship.id}
                  class="text-xs font-medium text-teal-600 hover:text-teal-700 dark:text-teal-400"
                >
                  Resume
                </button>
                <button
                  phx-click="revoke_guardianship"
                  phx-value-id={g.guardianship.id}
                  data-confirm="Revoke this guardianship? This stops FUTURE co-sealing. Content already shared with the guardian stays shared — that can't be undone."
                  class="text-xs font-medium text-rose-500 hover:text-rose-600"
                >
                  Revoke
                </button>
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
            <.phx_button type="submit" id="establish-submit">Link</.phx_button>
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
  def handle_event("invite_member", %{"invite" => %{"email" => email}}, socket) do
    case Orgs.create_invitation(socket.assigns.org, %{"sent_to" => email}) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:success, "Invitation sent")
         |> assign(:invite_form, to_form(%{"email" => ""}, as: :invite))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not send invitation")}
    end
  end

  @impl true
  def handle_event("change_role", %{"user_id" => user_id, "role" => role}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.user.id == user_id))

    if member do
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

  ## Data loading

  defp assign_family_data(socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    org = socket.assigns.org

    users = Orgs.list_members_by_org(org)
    guardianships = Orgs.list_guardianships_by_org(org)

    members =
      Enum.map(users, fn user ->
        membership = Orgs.get_membership!(user, org.slug)
        display_name = resolve_display_name(user, current_user, key)

        guardian_summaries =
          guardianships
          |> Enum.filter(&(&1.managed_membership.user_id == user.id))
          |> Enum.map(fn g ->
            resolve_display_name(g.guardian_membership.user, current_user, key)
          end)

        %{
          user: user,
          membership: membership,
          display_name: display_name,
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
    |> assign(:guardianships, guardianships_view)
    |> assign(:my_guardianships, my_guardianships)
    |> assign(:my_pending_consent, my_pending_consent)
    |> assign(:guardian_options, guardian_options)
    |> assign(:managed_options, managed_options)
    |> assign(:can_establish?, guardian_options != [] and managed_options != [])
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

  defp role_error_message(changeset) do
    case changeset.errors[:role] do
      {msg, _} -> msg
      _ -> "Could not update role"
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
