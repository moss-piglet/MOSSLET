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

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Orgs

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    org = Orgs.get_org!(current_user, slug)
    membership = Orgs.get_membership!(current_user, slug)

    if org.type == :business do
      {:ok,
       socket
       |> assign(:org, org)
       |> assign(:membership, membership)
       |> assign(:page_title, org.name)
       |> assign(:invite_form, to_form(%{"email" => ""}, as: :invite))
       |> assign(:show_circle_form?, false)
       |> assign(:circle_form, to_form(%{"name" => "", "description" => ""}, as: :circle))
       |> assign(:pending_zk_circle_attrs, nil)
       |> assign(:pending_zk_circle_users, nil)
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
            <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
              <.phx_icon name="hero-building-office" class="h-6 w-6 text-white" />
            </div>
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

        <%!-- Member management --%>
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
                    <.business_role_badge role={member.membership.role} />
                  </div>
                </div>
              </div>

              <div
                :if={@can_manage? && member.user.id != @current_scope.user.id}
                class="flex items-center gap-2 flex-shrink-0"
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
                <button
                  phx-click="offboard_member"
                  phx-value-user_id={member.user.id}
                  id={"offboard-#{member.user.id}"}
                  data-confirm="Remove this person from the organization and from all of this org's business circles? We can't recall content they've already downloaded."
                  class="text-xs font-medium text-rose-500 hover:text-rose-600"
                >
                  Remove
                </button>
              </div>
            </li>
          </ul>

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
              <.phx_button type="submit" id="invite-submit">Invite</.phx_button>
            </.form>
          </div>
        </section>

        <%!-- Business circles panel --%>
        <section class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                Business circles
              </h2>
              <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                Private circles restricted to this org's members. Each circle has its own
                end-to-end encrypted chat.
              </p>
            </div>
            <.phx_button
              :if={!@show_circle_form?}
              phx-click="show_circle_form"
              id="new-circle-button"
            >
              <.phx_icon name="hero-plus" class="size-4 mr-1.5" /> New circle
            </.phx_button>
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
                <button
                  type="button"
                  phx-click="hide_circle_form"
                  class="inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700/60 transition-colors duration-200"
                >
                  Cancel
                </button>
                <.phx_button type="submit" id="create-circle-submit" phx-disable-with="Creating...">
                  <.phx_icon name="hero-sparkles" class="size-4 mr-1.5" /> Create circle
                </.phx_button>
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
                navigate={~p"/app/circles/#{circle.group.id}"}
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
            </li>
            <li
              :if={@circles == [] && !@show_circle_form?}
              class="text-xs text-slate-500 dark:text-slate-400"
            >
              No business circles yet. Create one to start a private, encrypted team space.
            </li>
          </ul>
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

    if socket.assigns.can_manage? && member do
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

    if socket.assigns.can_manage? && member && user_id != socket.assigns.current_scope.user.id do
      # Remove the member from every business circle in this org (Q5 — explicit,
      # honest offboarding). We can't recall content already downloaded; we only
      # stop FUTURE access by removing their UserGroup rows.
      org
      |> Groups.list_org_business_circles()
      |> Enum.each(fn group -> Groups.remove_group_members(group, [user_id]) end)

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

  ## Data loading

  defp assign_business_data(socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    org = socket.assigns.org

    users = Orgs.list_members_by_org(org)
    member_user_ids = MapSet.new(users, & &1.id)

    members =
      Enum.map(users, fn user ->
        membership = Orgs.get_membership!(user, org.slug)

        %{
          user: user,
          membership: membership,
          display_name: resolve_display_name(user, current_user, key)
        }
      end)

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
          member_count: length(group.user_groups)
        }
      end)

    socket
    |> assign(:members, members)
    |> assign(:eligible_members, eligible_members)
    |> assign(:circles, circles)
    |> assign(:can_manage?, socket.assigns.membership.role == :admin)
  end

  defp resolve_display_name(%{id: same_id}, %{id: same_id}, _key), do: "You"

  defp resolve_display_name(user, current_user, key) do
    case Mosslet.Accounts.get_user_connection_between_users(user.id, current_user.id) do
      %{} = uconn ->
        uconn = Mosslet.Repo.preload(uconn, :connection)
        get_decrypted_connection_name(uconn, current_user, key)

      _ ->
        "Team member"
    end
  end

  defp role_error_message(changeset) do
    case changeset.errors[:role] do
      {msg, _} -> msg
      _ -> "Could not update"
    end
  end

  defp random_avatar do
    Enum.random(
      ~w(astronaut.png bear.png cat.png chicken.png dinosaur.png dog.png panda.png penguin.png rabbit.png sea-lion.png)
    )
  end
end
