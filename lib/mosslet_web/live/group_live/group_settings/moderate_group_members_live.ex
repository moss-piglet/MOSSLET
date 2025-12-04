defmodule MossletWeb.GroupLive.GroupSettings.ModerateGroupMembersLive do
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent
  import MossletWeb.DesignSystem

  alias Mosslet.Groups
  alias MossletWeb.Endpoint

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_group_layout
      current_page={:moderate_group_members}
      current_user={@current_user}
      key={@key}
      group={@group}
      user_group={@current_user_group}
      edit_group_name={"Moderate #{decr_item(@group.name, @current_user, @current_user_group.key, @key, @group)} Members"}
    >
      <div class="space-y-6">
        <header class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="space-y-1">
            <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
              Manage Members
            </h2>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              Kick or block members from this group
            </p>
          </div>
          <.liquid_badge color="emerald" size="md">
            <.phx_icon name="hero-shield-exclamation" class="w-4 h-4 mr-1.5" />
            {length(@group.user_groups)} members
          </.liquid_badge>
        </header>

        <div role="list" aria-label="Group members" class="grid gap-3 sm:gap-4">
          <div :for={ug <- @group.user_groups} role="listitem">
            <.member_card
              user_group={ug}
              current_user_group={@current_user_group}
              current_user={@current_user}
              group={@group}
              key={@key}
            />
          </div>
        </div>

        <.blocked_users_section
          :if={@blocked_users != []}
          blocked_users={@blocked_users}
          current_user_group={@current_user_group}
          current_user={@current_user}
          group={@group}
          key={@key}
        />

        <aside
          aria-label="Moderation information"
          class="pt-4 border-t border-slate-200/60 dark:border-slate-700/60"
        >
          <div class={[
            "flex items-start gap-4 p-4 sm:p-5 rounded-xl",
            "bg-gradient-to-br from-rose-50/60 via-pink-50/40 to-red-50/60",
            "dark:from-rose-900/25 dark:via-pink-900/20 dark:to-red-900/25",
            "border border-rose-200/50 dark:border-rose-700/40",
            "shadow-sm shadow-rose-500/5 dark:shadow-rose-400/5"
          ]}>
            <div class={[
              "flex-shrink-0 flex items-center justify-center w-10 h-10 rounded-lg",
              "bg-gradient-to-br from-rose-500 to-pink-600",
              "shadow-md shadow-pink-500/30 dark:shadow-pink-400/20"
            ]}>
              <.phx_icon name="hero-shield-exclamation" class="w-5 h-5 text-white" />
            </div>
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold text-rose-800 dark:text-rose-200">
                Moderation Actions
              </h3>
              <p class="mt-1 text-sm text-rose-700 dark:text-rose-300 leading-relaxed">
                <strong>Kick</strong>
                removes a member but allows them to rejoin. <strong>Block</strong>
                removes and prevents rejoining.
              </p>
            </div>
          </div>
        </aside>
      </div>

      <.kick_modal
        :if={@live_action == :kick_member}
        user_group={@target_user_group}
        current_user_group={@current_user_group}
        current_user={@current_user}
        group={@group}
        key={@key}
      />

      <.block_modal
        :if={@live_action == :block_member}
        user_group={@target_user_group}
        current_user_group={@current_user_group}
        current_user={@current_user}
        group={@group}
        key={@key}
      />
    </.settings_group_layout>
    """
  end

  attr :user_group, :map, required: true
  attr :current_user_group, :map, required: true
  attr :current_user, :map, required: true
  attr :group, :map, required: true
  attr :key, :string, required: true

  defp member_card(assigns) do
    is_self = assigns.user_group.id == assigns.current_user_group.id
    can_moderate = Groups.can_moderate?(assigns.current_user_group.role, assigns.user_group.role)

    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.user_group.id),
        assigns.current_user
      )

    is_connected = not is_nil(uconn)

    member_name =
      if is_self || is_connected do
        decr_item(
          assigns.user_group.name,
          assigns.current_user,
          assigns.current_user_group.key,
          assigns.key,
          assigns.group
        )
      else
        nil
      end

    assigns =
      assigns
      |> assign(:is_self, is_self)
      |> assign(:can_moderate, can_moderate && !is_self)
      |> assign(:member_name, member_name)

    ~H"""
    <div class={[
      "group relative flex flex-col sm:flex-row sm:items-center gap-3 p-3 sm:p-5 rounded-xl",
      "bg-white/90 dark:bg-slate-800/80 backdrop-blur-sm",
      "border border-slate-200/60 dark:border-slate-700/60",
      "shadow-sm shadow-slate-900/5 dark:shadow-slate-900/20"
    ]}>
      <div class="flex items-center gap-3 sm:gap-4 flex-1 min-w-0">
        <div class="relative flex-shrink-0 p-1">
          <.phx_avatar
            :if={@current_user_group.id != @user_group.id}
            src={
              get_user_avatar(
                get_uconn_for_users(
                  get_user_from_user_group_id(@user_group.id),
                  @current_user
                ),
                @key
              )
            }
            alt=""
            class={"w-10 h-10 sm:w-12 sm:h-12 #{role_avatar_ring(@user_group.role)}"}
          />
          <.phx_avatar
            :if={@current_user_group.user_id == @user_group.user_id}
            src={maybe_get_user_avatar(@current_user, @key)}
            alt=""
            class={"w-10 h-10 sm:w-12 sm:h-12 #{role_avatar_ring(@user_group.role)}"}
          />
          <div
            :if={@is_self}
            class={[
              "absolute -bottom-1 -right-1 w-5 h-5 rounded-full",
              "bg-gradient-to-br from-cyan-500 to-teal-600",
              "border-2 border-white dark:border-slate-800",
              "flex items-center justify-center",
              "shadow-md shadow-cyan-500/30"
            ]}
            aria-hidden="true"
          >
            <.phx_icon name="hero-check-mini" class="w-3 h-3 text-white" />
          </div>
        </div>

        <div class="flex-1 min-w-0 space-y-1.5 overflow-hidden">
          <div class="flex flex-wrap items-center gap-2">
            <span
              :if={@member_name}
              class="font-semibold text-slate-900 dark:text-slate-100 truncate text-sm sm:text-base"
            >
              {@member_name}
            </span>
            <.liquid_badge :if={@is_self} color="cyan" size="xs" variant="soft">
              You
            </.liquid_badge>
          </div>

          <div class="flex flex-wrap items-center gap-x-2 sm:gap-x-3 gap-y-1 text-xs sm:text-sm">
            <span class="inline-flex items-center gap-1.5 text-slate-600 dark:text-slate-400 min-w-0">
              <.phx_icon
                name="hero-finger-print"
                class="w-4 h-4 text-teal-500 dark:text-teal-400 flex-shrink-0"
              />
              <span class="truncate">
                {decr_item(
                  @user_group.moniker,
                  @current_user,
                  @current_user_group.key,
                  @key,
                  @group
                )}
              </span>
            </span>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-end gap-2 sm:gap-3 sm:flex-shrink-0">
        <.role_badge role={@user_group.role} />

        <div :if={@can_moderate} class="flex items-center gap-2">
          <.link
            patch={~p"/app/groups/user_group/#{@user_group.id}/kick-member"}
            class={[
              "flex items-center justify-center w-8 h-8 sm:w-9 sm:h-9 rounded-lg",
              "bg-amber-100/80 dark:bg-amber-900/40",
              "text-amber-600 dark:text-amber-400",
              "hover:bg-amber-200 dark:hover:bg-amber-800/60",
              "transition-all duration-200"
            ]}
            title="Kick member"
          >
            <.phx_icon name="hero-arrow-right-start-on-rectangle" class="w-4 h-4" />
          </.link>
          <.link
            patch={~p"/app/groups/user_group/#{@user_group.id}/block-member"}
            class={[
              "flex items-center justify-center w-8 h-8 sm:w-9 sm:h-9 rounded-lg",
              "bg-rose-100/80 dark:bg-rose-900/40",
              "text-rose-600 dark:text-rose-400",
              "hover:bg-rose-200 dark:hover:bg-rose-800/60",
              "transition-all duration-200"
            ]}
            title="Block member"
          >
            <.phx_icon name="hero-no-symbol" class="w-4 h-4" />
          </.link>
        </div>

        <div
          :if={@is_self}
          class="text-xs text-slate-400 dark:text-slate-500 italic"
        >
          (You)
        </div>
      </div>
    </div>
    """
  end

  attr :blocked_users, :list, required: true
  attr :current_user_group, :map, required: true
  attr :current_user, :map, required: true
  attr :group, :map, required: true
  attr :key, :string, required: true

  defp blocked_users_section(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 flex items-center gap-2">
        <.phx_icon name="hero-no-symbol" class="w-5 h-5 text-rose-500" /> Blocked Users
      </h3>
      <div class="grid gap-3">
        <div
          :for={block <- @blocked_users}
          class={[
            "flex items-center justify-between gap-3 p-4 rounded-xl",
            "bg-rose-50/50 dark:bg-rose-900/20",
            "border border-rose-200/50 dark:border-rose-700/40"
          ]}
        >
          <div class="flex items-center gap-3">
            <.phx_icon name="hero-user-minus" class="w-5 h-5 text-rose-500" />
            <span class="text-sm text-slate-700 dark:text-slate-300">
              <span :if={block.blocked_moniker} class="inline-flex items-center gap-1.5">
                <.phx_icon name="hero-finger-print" class="w-4 h-4 text-rose-400" />
                {decr_item(
                  block.blocked_moniker,
                  @current_user,
                  @current_user_group.key,
                  @key,
                  @group
                )}
              </span>
              <span :if={!block.blocked_moniker}>Blocked user</span>
            </span>
          </div>
          <button
            phx-click="unblock"
            phx-value-block-id={block.id}
            class={[
              "px-3 py-1.5 text-xs font-medium rounded-lg",
              "bg-emerald-100 dark:bg-emerald-900/40",
              "text-emerald-700 dark:text-emerald-300",
              "hover:bg-emerald-200 dark:hover:bg-emerald-800/60",
              "transition-all duration-200"
            ]}
          >
            Unblock
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :user_group, :map, required: true
  attr :current_user_group, :map, required: true
  attr :current_user, :map, required: true
  attr :group, :map, required: true
  attr :key, :string, required: true

  defp kick_modal(assigns) do
    is_self = assigns.user_group.id == assigns.current_user_group.id
    can_moderate = Groups.can_moderate?(assigns.current_user_group.role, assigns.user_group.role)

    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.user_group.id),
        assigns.current_user
      )

    is_connected = not is_nil(uconn)

    member_name =
      if is_self || is_connected do
        decr_item(
          assigns.user_group.name,
          assigns.current_user,
          assigns.current_user_group.key,
          assigns.key,
          assigns.group
        )
      else
        nil
      end

    member_moniker =
      decr_item(
        assigns.user_group.moniker,
        assigns.current_user,
        assigns.current_user_group.key,
        assigns.key,
        assigns.group
      )

    assigns =
      assigns
      |> assign(:is_self, is_self)
      |> assign(:can_moderate, can_moderate && !is_self)
      |> assign(:member_name, member_name)
      |> assign(:member_moniker, member_moniker)

    ~H"""
    <.liquid_modal
      id="kick-member-modal"
      show
      on_cancel={JS.patch(~p"/app/groups/#{@group}/moderate-members")}
    >
      <:title>Kick Member</:title>
      <div class="space-y-4">
        <p class="text-slate-600 dark:text-slate-400">
          Are you sure you want to kick
          <strong class="text-slate-900 dark:text-slate-100">
            <.phx_icon :if={is_nil(@member_name)} name="hero-finger-print" class="size-4" />{if @member_name,
              do: @member_name,
              else: @member_moniker}
          </strong>
          from this group?
        </p>
        <p class="text-sm text-amber-600 dark:text-amber-400">
          They will be removed but can rejoin the group later.
        </p>
        <div class="flex justify-end gap-3 pt-4">
          <.link
            patch={~p"/app/groups/#{@group}/moderate-members"}
            class={[
              "px-4 py-2 text-sm font-medium rounded-lg",
              "bg-slate-100 dark:bg-slate-700",
              "text-slate-700 dark:text-slate-300",
              "hover:bg-slate-200 dark:hover:bg-slate-600",
              "transition-all duration-200"
            ]}
          >
            Cancel
          </.link>
          <button
            phx-click={if @can_moderate, do: "kick", else: nil}
            phx-value-user-group-id={@user_group.id}
            class={[
              "px-4 py-2 text-sm font-medium rounded-lg",
              "bg-amber-500 hover:bg-amber-600",
              "text-white",
              "transition-all duration-200"
            ]}
          >
            Kick Member
          </button>
        </div>
      </div>
    </.liquid_modal>
    """
  end

  attr :user_group, :map, required: true
  attr :current_user_group, :map, required: true
  attr :current_user, :map, required: true
  attr :group, :map, required: true
  attr :key, :string, required: true

  defp block_modal(assigns) do
    is_self = assigns.user_group.id == assigns.current_user_group.id
    can_moderate = Groups.can_moderate?(assigns.current_user_group.role, assigns.user_group.role)

    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.user_group.id),
        assigns.current_user
      )

    is_connected = not is_nil(uconn)

    member_name =
      if is_self || is_connected do
        decr_item(
          assigns.user_group.name,
          assigns.current_user,
          assigns.current_user_group.key,
          assigns.key,
          assigns.group
        )
      else
        nil
      end

    member_moniker =
      decr_item(
        assigns.user_group.moniker,
        assigns.current_user,
        assigns.current_user_group.key,
        assigns.key,
        assigns.group
      )

    assigns =
      assigns
      |> assign(:is_self, is_self)
      |> assign(:can_moderate, can_moderate && !is_self)
      |> assign(:member_name, member_name)
      |> assign(:member_moniker, member_moniker)

    ~H"""
    <.liquid_modal
      id="block-member-modal"
      show
      on_cancel={JS.patch(~p"/app/groups/#{@group}/moderate-members")}
    >
      <:title>Block Member</:title>
      <div class="space-y-4">
        <p class="text-slate-600 dark:text-slate-400">
          Are you sure you want to block
          <strong class="text-slate-900 dark:text-slate-100">
            <.phx_icon :if={is_nil(@member_name)} name="hero-finger-print" class="size-4" />{if @member_name,
              do: @member_name,
              else: @member_moniker}
          </strong>
          from this group?
        </p>
        <p class="text-sm text-rose-600 dark:text-rose-400">
          They will be removed and prevented from rejoining until unblocked.
        </p>
        <div class="flex justify-end gap-3 pt-4">
          <.link
            patch={~p"/app/groups/#{@group}/moderate-members"}
            class={[
              "px-4 py-2 text-sm font-medium rounded-lg",
              "bg-slate-100 dark:bg-slate-700",
              "text-slate-700 dark:text-slate-300",
              "hover:bg-slate-200 dark:hover:bg-slate-600",
              "transition-all duration-200"
            ]}
          >
            Cancel
          </.link>
          <button
            phx-click="block"
            phx-value-user-group-id={@user_group.id}
            class={[
              "px-4 py-2 text-sm font-medium rounded-lg",
              "bg-rose-500 hover:bg-rose-600",
              "text-white",
              "transition-all duration-200"
            ]}
          >
            Block Member
          </button>
        </div>
      </div>
    </.liquid_modal>
    """
  end

  attr :role, :atom, required: true

  defp role_badge(assigns) do
    {color, icon} =
      case assigns.role do
        :owner -> {"pink", "hero-star"}
        :admin -> {"orange", "hero-shield-check"}
        :moderator -> {"purple", "hero-wrench"}
        :member -> {"emerald", "hero-user"}
        _ -> {"teal", "hero-user"}
      end

    assigns =
      assigns
      |> assign(:color, color)
      |> assign(:icon, icon)

    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
      "transition-all duration-200 transform-gpu",
      role_badge_styles(@color)
    ]}>
      <.phx_icon name={@icon} class="w-3.5 h-3.5" />
      {String.capitalize(Atom.to_string(@role))}
    </span>
    """
  end

  defp role_badge_styles("pink") do
    [
      "bg-gradient-to-r from-pink-100 to-rose-100 text-pink-700",
      "dark:from-pink-900/40 dark:to-rose-900/40 dark:text-pink-300",
      "border border-pink-200/60 dark:border-pink-700/50",
      "shadow-sm shadow-pink-500/10 dark:shadow-pink-400/10"
    ]
  end

  defp role_badge_styles("orange") do
    [
      "bg-gradient-to-r from-orange-100 to-amber-100 text-orange-700",
      "dark:from-orange-900/40 dark:to-amber-900/40 dark:text-orange-300",
      "border border-orange-200/60 dark:border-orange-700/50",
      "shadow-sm shadow-orange-500/10 dark:shadow-orange-400/10"
    ]
  end

  defp role_badge_styles("purple") do
    [
      "bg-gradient-to-r from-purple-100 to-violet-100 text-purple-700",
      "dark:from-purple-900/40 dark:to-violet-900/40 dark:text-purple-300",
      "border border-purple-200/60 dark:border-purple-700/50",
      "shadow-sm shadow-purple-500/10 dark:shadow-purple-400/10"
    ]
  end

  defp role_badge_styles("emerald") do
    [
      "bg-gradient-to-r from-emerald-100 to-teal-100 text-emerald-700",
      "dark:from-emerald-900/40 dark:to-teal-900/40 dark:text-emerald-300",
      "border border-emerald-200/60 dark:border-emerald-700/50",
      "shadow-sm shadow-emerald-500/10 dark:shadow-emerald-400/10"
    ]
  end

  defp role_badge_styles(_color) do
    [
      "bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-700",
      "dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-300",
      "border border-teal-200/60 dark:border-teal-700/50",
      "shadow-sm shadow-teal-500/10 dark:shadow-teal-400/10"
    ]
  end

  defp role_avatar_ring(:owner) do
    "rounded-full ring-2 ring-pink-400 dark:ring-pink-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp role_avatar_ring(:admin) do
    "rounded-full ring-2 ring-orange-400 dark:ring-orange-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp role_avatar_ring(:moderator) do
    "rounded-full ring-2 ring-purple-400 dark:ring-purple-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp role_avatar_ring(:member) do
    "rounded-full ring-2 ring-emerald-400 dark:ring-emerald-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp role_avatar_ring(_role) do
    "rounded-full ring-2 ring-teal-300 dark:ring-teal-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  @impl true
  def mount(%{"id" => id} = _params, _session, socket) do
    group =
      if socket.assigns.live_action in [:kick_member, :block_member] do
        case Groups.get_user_group(id) do
          nil ->
            nil

          user_group ->
            Groups.get_group!(user_group.group_id)
        end
      else
        Groups.get_group!(id)
      end

    if is_nil(group) do
      {:ok,
       socket
       |> put_flash(:info, "This member no longer exists in the group.")
       |> push_navigate(to: ~p"/app/groups")}
    else
      current_user_group =
        Groups.get_user_group_for_group_and_user(group, socket.assigns.current_user)

      if current_user_group && current_user_group.role in [:owner, :admin, :moderator] do
        blocked_users = Groups.list_blocked_users(group.id)

        {:ok,
         socket
         |> assign(:group, group)
         |> assign(:current_user_group, current_user_group)
         |> assign(:blocked_users, blocked_users)
         |> assign(:target_user_group, nil)
         |> assign(
           :group_name,
           decr_item(
             group.name,
             socket.assigns.current_user,
             current_user_group.key,
             socket.assigns.key,
             group
           )
         )
         |> assign(:page_title, "Moderate Members"), layout: {MossletWeb.Layouts, :app}}
      else
        {:ok,
         socket
         |> put_flash(:info, "You do not have permission to access this page.")
         |> push_navigate(to: ~p"/app/groups/#{group}")}
      end
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case socket.assigns.live_action do
      action when action in [:kick_member, :block_member] ->
        case Groups.get_user_group(id) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:info, "This member no longer exists in the group.")
             |> push_navigate(to: ~p"/app/groups")}

          user_group ->
            group = Groups.get_group!(user_group.group_id)

            if connected?(socket) do
              Endpoint.subscribe("group:#{group.id}")
              Groups.private_subscribe(socket.assigns.current_user)
            end

            {:noreply,
             socket
             |> assign(:group, group)
             |> assign(:target_user_group, user_group)}
        end

      nil ->
        if connected?(socket) do
          Endpoint.subscribe("group:#{id}")
          Groups.private_subscribe(socket.assigns.current_user)
        end

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("kick", %{"user-group-id" => user_group_id}, socket) do
    target = Groups.get_user_group!(user_group_id)
    actor = socket.assigns.current_user_group

    case Groups.kick_member(actor, target) do
      {:ok, _} ->
        group = Groups.get_group!(socket.assigns.group.id)

        {:noreply,
         socket
         |> assign(:group, group)
         |> assign(:target_user_group, nil)
         |> put_flash(:success, "Member has been kicked from the group.")
         |> push_event("restore-body-scroll", %{})
         |> push_patch(to: ~p"/app/groups/#{group}/moderate-members")}

      {:error, :cannot_kick_self} ->
        {:noreply, put_flash(socket, :error, "You cannot kick yourself.")}

      {:error, :insufficient_permissions} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to kick this member.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to kick member.")}
    end
  end

  @impl true
  def handle_event("block", %{"user-group-id" => user_group_id}, socket) do
    target = Groups.get_user_group!(user_group_id)
    actor = socket.assigns.current_user_group

    case Groups.block_member(actor, target) do
      {:ok, _} ->
        group = Groups.get_group!(socket.assigns.group.id)
        blocked_users = Groups.list_blocked_users(group.id)

        {:noreply,
         socket
         |> assign(:group, group)
         |> assign(:blocked_users, blocked_users)
         |> assign(:target_user_group, nil)
         |> put_flash(:success, "Member has been blocked from the group.")
         |> push_patch(to: ~p"/app/groups/#{group}/moderate-members")}

      {:error, :cannot_block_self} ->
        {:noreply, put_flash(socket, :error, "You cannot block yourself.")}

      {:error, :insufficient_permissions} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to block this member.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to block member.")}
    end
  end

  @impl true
  def handle_event("unblock", %{"block-id" => block_id}, socket) do
    block = Groups.get_group_block!(block_id)
    actor = socket.assigns.current_user_group

    case Groups.unblock_member(actor, block) do
      {:ok, _} ->
        blocked_users = Groups.list_blocked_users(socket.assigns.group.id)

        {:noreply,
         socket
         |> assign(:blocked_users, blocked_users)
         |> put_flash(:success, "User has been unblocked.")}

      {:error, :insufficient_permissions} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to unblock users.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to unblock user.")}
    end
  end

  @impl true
  def handle_event("restore-body-scroll", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:group_joined, group}, socket) do
    if group.id == socket.assigns.group.id do
      {:noreply, assign(socket, :group, group)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_kicked, {group, kicked_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      if kicked_user_id == socket.assigns.current_user.id do
        {:noreply,
         socket
         |> put_flash(:info, "You have been removed from this group.")
         |> push_navigate(to: ~p"/app/groups")}
      else
        {:noreply, assign(socket, :group, group)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_blocked, {group, blocked_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      if blocked_user_id == socket.assigns.current_user.id do
        {:noreply,
         socket
         |> put_flash(:info, "You have been removed from this group.")
         |> push_navigate(to: ~p"/app/groups")}
      else
        blocked_users = Groups.list_blocked_users(group.id)

        {:noreply,
         socket
         |> assign(:group, group)
         |> assign(:blocked_users, blocked_users)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_unblocked, {group, _target_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      blocked_users = Groups.list_blocked_users(group.id)

      {:noreply,
       socket
       |> assign(:group, group)
       |> assign(:blocked_users, blocked_users)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(message, socket) do
    IO.inspect(message, label: "GROUP MODERATE SETTINGS")
    {:noreply, socket}
  end
end
