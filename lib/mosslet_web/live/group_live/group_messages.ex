defmodule MossletWeb.GroupLive.GroupMessages do
  use MossletWeb, :html
  import MossletWeb.CoreComponents

  def list_messages(assigns) do
    ~H"""
    <div
      id="messages"
      phx-update="stream"
      class="flex-1 overflow-y-auto min-h-0 px-6 py-4 bg-gradient-to-b from-transparent via-gray-50/20 to-transparent dark:via-gray-800/10"
      phx-hook="ScrollDown"
      data-scrolled-to-top={@scrolled_to_top}
      style="scrollbar-width: thin; scrollbar-color: rgb(34 197 94) transparent;"
    >
      <div id="infinite-scroll-marker" phx-hook="InfiniteScrollGroupMessage"></div>
      <div
        :for={{dom_id, message} <- @messages}
        id={dom_id}
        class="mb-3 last:mb-2 group"
        phx-hook="HoverGroupMessage"
        data-toggle={JS.toggle(to: "#message-#{message.id}-buttons")}
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
    <div class="relative p-4 rounded-xl transition-all duration-300 group-hover:bg-gradient-to-r group-hover:from-gray-50/80 group-hover:via-white/40 group-hover:to-gray-50/80 dark:group-hover:from-gray-800/40 dark:group-hover:via-gray-700/20 dark:group-hover:to-gray-800/40 group-hover:shadow-sm group-hover:scale-[1.01] group-hover:border group-hover:border-gray-200/50 dark:group-hover:border-gray-600/30">
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
    <div class="flex items-start gap-3 mb-2">
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
          class={"w-10 h-10 ring-2 ring-offset-2 ring-offset-transparent group-hover:ring-offset-white dark:group-hover:ring-offset-gray-800 transition-all duration-300 #{group_avatar_role_style(@message.sender.role)}"}
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
          class={"w-10 h-10 ring-2 ring-offset-2 ring-offset-transparent group-hover:ring-offset-white dark:group-hover:ring-offset-gray-800 transition-all duration-300 #{group_avatar_role_style(@message.sender.role)}"}
        />

        <.phx_avatar
          :if={@user_group.id == @message.sender_id}
          src={maybe_get_user_avatar(@current_user, @key)}
          alt="your group member avatar"
          class={"w-10 h-10 ring-2 ring-offset-2 ring-offset-transparent group-hover:ring-offset-white dark:group-hover:ring-offset-gray-800 transition-all duration-300 #{group_avatar_role_style(@message.sender.role)}"}
        />
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between mb-1">
          <div class="flex items-center gap-2">
            <span class="font-semibold text-gray-900 dark:text-white text-sm">
              <span :if={@message.sender.name}>
                {initials(
                  decr_item(@message.sender.name, @current_user, @user_group.key, @key, @group)
                )}
              </span>
              <span :if={!@message.sender.name}>
                {maybe_decr_username_for_user_group(@message.sender.user_id, @current_user, @key)}
              </span>
            </span>

            <span class={"inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs #{group_fingerprint_role_style(@message.sender.role)} bg-gradient-to-r from-gray-100 to-gray-200 dark:from-gray-700 dark:to-gray-600"}>
              <.icon name="hero-finger-print" class="w-3 h-3" />
              {decr_item(
                @message.sender.moniker,
                @current_user,
                @user_group.key,
                @key,
                @group
              )}
            </span>
          </div>

          <div class="flex items-center gap-2">
            <time class="text-xs text-gray-500 dark:text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
              <.local_time
                id={@message.id <> "-created"}
                for={@message.inserted_at}
                preset="DATETIME_SHORT"
              />
            </time>

            <div class="opacity-0 group-hover:opacity-100 transition-opacity duration-200">
              <.delete_icon
                :if={@user_group.role in [:owner, :admin, :moderator]}
                id={"message-#{@message.id}-buttons"}
                phx_click="delete_message"
                value={@message.id}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def message_content(assigns) do
    ~H"""
    <div class="ml-13 mt-1">
      <div class="text-gray-800 dark:text-gray-200 text-sm leading-relaxed bg-white/80 dark:bg-gray-800/30 rounded-xl px-4 py-3 shadow-sm border border-gray-200/50 dark:border-gray-600/30 group-hover:bg-white dark:group-hover:bg-gray-700/40 transition-all duration-300">
        {decr_item(@message.content, @current_user, @user_group_key, @key, @group)}
      </div>
    </div>
    """
  end
end
