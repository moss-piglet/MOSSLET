defmodule MossletWeb.GroupLive.GroupMessages do
  use MossletWeb, :html
  import MossletWeb.CoreComponents

  def list_messages(assigns) do
    ~H"""
    <div
      id="messages"
      phx-update="stream"
      class="flex-1 overflow-y-auto min-h-0 px-3 sm:px-6 py-4 space-y-1"
      phx-hook="ScrollDown"
      data-scrolled-to-top={@scrolled_to_top}
      style="scrollbar-width: thin; scrollbar-color: rgb(20 184 166 / 0.5) transparent;"
      tabindex="0"
      role="log"
      aria-label="Chat messages"
    >
      <div id="infinite-scroll-marker" phx-hook="InfiniteScrollGroupMessage"></div>
      <div
        :for={{dom_id, message} <- @messages}
        id={dom_id}
        class="group/msg"
      >
        <.message_details
          message={message}
          current_user={@current_user}
          user_group_key={@user_group_key}
          group={@group}
          key={@key}
          user_group={@user_group}
          messages_list={@messages_list}
        />
      </div>
    </div>
    """
  end

  def message_details(assigns) do
    ~H"""
    <div class="relative py-2 px-3 sm:px-4 rounded-xl transition-all duration-200 ease-out group-hover/msg:bg-gradient-to-r group-hover/msg:from-teal-50/40 group-hover/msg:via-white/60 group-hover/msg:to-emerald-50/40 dark:group-hover/msg:from-teal-900/15 dark:group-hover/msg:via-slate-800/40 dark:group-hover/msg:to-emerald-900/15">
      <.message_meta
        message={@message}
        current_user={@current_user}
        user_group={@user_group}
        group={@group}
        key={@key}
        messages_list={@messages_list}
      />

      <.message_content
        message={@message}
        current_user={@current_user}
        user_group={@user_group}
        user_group_key={@user_group_key}
        group={@group}
        key={@key}
      />
    </div>
    """
  end

  def message_meta(assigns) do
    ~H"""
    <div class="flex items-start gap-2.5 sm:gap-3 relative">
      <div class="flex-shrink-0">
        <% uconn =
          get_uconn_for_users(
            get_user_from_user_group_id(@message.sender_id),
            @current_user
          ) %>
        <.phx_avatar
          :if={@user_group.id != @message.sender_id && !uconn}
          src={
            ~p"/images/groups/#{decr_item(@message.sender.avatar_img, @current_user, @user_group.key, @key, @group)}"
          }
          alt="group member avatar"
          class={"w-8 h-8 sm:w-10 sm:h-10 ring-2 ring-offset-1 ring-offset-white dark:ring-offset-slate-800 transition-all duration-200 #{liquid_avatar_role_style(@message.sender.role)}"}
        />

        <.phx_avatar
          :if={@user_group.id != @message.sender_id && uconn}
          src={
            maybe_get_avatar_src(
              uconn,
              @current_user,
              @key,
              @messages_list
            )
          }
          alt="group member avatar"
          class={"w-8 h-8 sm:w-10 sm:h-10 ring-2 ring-offset-1 ring-offset-white dark:ring-offset-slate-800 transition-all duration-200 #{liquid_avatar_role_style(@message.sender.role)}"}
        />

        <.phx_avatar
          :if={@user_group.id == @message.sender_id}
          src={maybe_get_user_avatar(@current_user, @key)}
          alt="your group member avatar"
          class={"w-8 h-8 sm:w-10 sm:h-10 ring-2 ring-offset-1 ring-offset-white dark:ring-offset-slate-800 transition-all duration-200 #{liquid_avatar_role_style(@message.sender.role)}"}
        />
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex flex-wrap items-baseline gap-x-2 gap-y-0.5">
          <span class="font-semibold text-slate-900 dark:text-slate-100 text-sm">
            <span :if={@message.sender.name}>
              {initials(decr_item(@message.sender.name, @current_user, @user_group.key, @key, @group))}
            </span>
            <span :if={!@message.sender.name}>
              {maybe_decr_username_for_user_group(@message.sender.user_id, @current_user, @key)}
            </span>
          </span>

          <span class={"inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-xs font-medium #{liquid_fingerprint_role_style(@message.sender.role)}"}>
            <.icon name="hero-finger-print" class="w-3 h-3" />
            <span class="truncate max-w-[80px] sm:max-w-[120px]">
              {decr_item(
                @message.sender.moniker,
                @current_user,
                @user_group.key,
                @key,
                @group
              )}
            </span>
          </span>

          <time
            id={"time-tooltip-" <> @message.id}
            class="text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap cursor-help"
            phx-hook="LocalTimeTooltip"
            data-timestamp={@message.inserted_at}
          >
            <.local_time
              id={@message.id <> "-created"}
              for={@message.inserted_at}
              preset="TIME_SIMPLE"
              class="hover:text-slate-700 dark:hover:text-slate-300 transition-colors duration-150"
            />
          </time>
        </div>
      </div>

      <div class="absolute top-0 right-0 flex items-center gap-1.5 opacity-0 group-hover/msg:opacity-100 focus-within:opacity-100 transition-opacity duration-200">
        <.delete_icon
          :if={
            @user_group.role in [:owner, :admin, :moderator] ||
              @user_group.id == @message.sender_id
          }
          id={"message-#{@message.id}-buttons"}
          phx_click="delete_message"
          value={@message.id}
        />
      </div>
    </div>
    """
  end

  def message_content(assigns) do
    ~H"""
    <div class="ml-10 sm:ml-13 mt-1.5">
      <div class="text-slate-700 dark:text-slate-200 text-sm leading-relaxed bg-white/90 dark:bg-slate-800/50 rounded-xl px-3 sm:px-4 py-2.5 sm:py-3 shadow-sm border border-slate-200/50 dark:border-slate-700/50 group-hover/msg:border-teal-200/50 dark:group-hover/msg:border-teal-700/40 group-hover/msg:shadow-md group-hover/msg:shadow-teal-500/5 dark:group-hover/msg:shadow-teal-400/5 transition-all duration-200">
        {decr_item(@message.content, @current_user, @user_group_key, @key, @group)}
      </div>
    </div>
    """
  end

  defp liquid_avatar_role_style(:owner),
    do: "ring-amber-400 dark:ring-amber-500"

  defp liquid_avatar_role_style(:admin),
    do: "ring-purple-400 dark:ring-purple-500"

  defp liquid_avatar_role_style(:moderator),
    do: "ring-blue-400 dark:ring-blue-500"

  defp liquid_avatar_role_style(_),
    do: "ring-teal-300 dark:ring-teal-600"

  defp liquid_fingerprint_role_style(:owner),
    do:
      "bg-gradient-to-r from-amber-100 to-amber-50 text-amber-700 dark:from-amber-900/40 dark:to-amber-800/30 dark:text-amber-300"

  defp liquid_fingerprint_role_style(:admin),
    do:
      "bg-gradient-to-r from-purple-100 to-purple-50 text-purple-700 dark:from-purple-900/40 dark:to-purple-800/30 dark:text-purple-300"

  defp liquid_fingerprint_role_style(:moderator),
    do:
      "bg-gradient-to-r from-blue-100 to-blue-50 text-blue-700 dark:from-blue-900/40 dark:to-blue-800/30 dark:text-blue-300"

  defp liquid_fingerprint_role_style(_),
    do:
      "bg-gradient-to-r from-teal-100 to-emerald-50 text-teal-700 dark:from-teal-900/40 dark:to-emerald-800/30 dark:text-teal-300"
end
