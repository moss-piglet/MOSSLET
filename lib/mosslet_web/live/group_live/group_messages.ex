defmodule MossletWeb.GroupLive.GroupMessages do
  use MossletWeb, :html
  import MossletWeb.CoreComponents

  def list_messages(assigns) do
    ~H"""
    <div
      id="messages"
      phx-update="stream"
      class="overflow-y-auto h-80"
      phx-hook="ScrollDown"
      data-scrolled-to-top={@scrolled_to_top}
    >
      <div id="infinite-scroll-marker" phx-hook="InfiniteScrollGroupMessage"></div>
      <div
        :for={{dom_id, message} <- @messages}
        id={dom_id}
        class="px-2 mt-2 hover:bg-background-200 dark:hover:bg-gray-900 hover:rounded-md messages"
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
    """
  end

  def message_meta(assigns) do
    ~H"""
    <%!-- show current_user message on right side of screen --%>
    <div
      :if={@user_group.id == @message.sender_id}
      class="relative mt-6 flex flex-row-reverse justify-between text-sm leading-6"
    >
      <div class="py-2 inline-flex">
        <div class="pr-2 inline-flex text-[0.9rem] text-gray-900 dark:text-gray-100 font-medium">
          <span :if={@message.sender.name} class="truncate w-1/4 sm:w-3/4 md:w-full">
            {initials(decr_item(@message.sender.name, @current_user, @user_group.key, @key, @group))}

            <span class={group_fingerprint_role_style(@message.sender.role)}>
              <.icon name="hero-finger-print" class="h-4 w-4" />{decr_item(
                @message.sender.moniker,
                @current_user,
                @user_group.key,
                @key,
                @group
              )}
            </span>
          </span>
          <span :if={!@message.sender.name} class="truncate w-1/4 sm:w-3/4 md:w-full">
            {maybe_decr_username_for_user_group(@message.sender.user_id, @current_user, @key)}
          </span>
          <div class="absolute left-4 top-3 text-xs font-light text-gray-500 dark:text-gray-400">
            <.local_time_ago id={@message.id <> "-created"} at={@message.inserted_at} />
          </div>
          <.delete_icon
            :if={@user_group.role in [:owner, :admin, :moderator]}
            id={"message-#{@message.id}-buttons"}
            phx_click="delete_message"
            value={@message.id}
          />
        </div>
        <.phx_avatar
          :if={@user_group.id == @message.sender_id}
          src={maybe_get_user_avatar(@current_user, @key)}
          alt="your avatar"
          class={group_avatar_role_style(@user_group.role)}
        />
      </div>
    </div>

    <%!-- show other messages on left side of screen --%>
    <div
      :if={@user_group.id != @message.sender_id}
      class="relative mt-6 flex flex-col justify-between text-sm leading-6"
    >
      <div class="py-2 inline-flex">
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
          class={group_avatar_role_style(@message.sender.role)}
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
          class={group_avatar_role_style(@message.sender.role)}
        />

        <div class="pl-2 inline-flex text-[0.9rem] text-gray-900 dark:text-gray-100 font-medium">
          <span :if={@message.sender.name} class="truncate w-1/4 sm:w-3/4 md:w-full">
            {initials(decr_item(@message.sender.name, @current_user, @user_group.key, @key, @group))}

            <span class={group_fingerprint_role_style(@message.sender.role)}>
              <.icon name="hero-finger-print" class="h-4 w-4" />{decr_item(
                @message.sender.moniker,
                @current_user,
                @user_group.key,
                @key,
                @group
              )}
            </span>
          </span>
          <span :if={!@message.sender.name} class="truncate w-1/4 sm:w-3/4 md:w-full">
            {maybe_decr_username_for_user_group(@message.sender.user_id, @current_user, @key)}
          </span>
          <div class="absolute right-4 top-3 text-xs font-light text-gray-500 dark:text-gray-400">
            <.local_time_ago id={@message.id <> "-created"} at={@message.inserted_at} />
          </div>
          <.delete_icon
            :if={@user_group.role in [:owner, :admin, :moderator]}
            id={"message-#{@message.id}-buttons"}
            phx_click="delete_message"
            value={@message.id}
          />
        </div>
      </div>
    </div>
    """
  end

  def message_content(assigns) do
    ~H"""
    <%!-- show current_user message on right side of screen --%>
    <div
      :if={@user_group.id == @message.sender_id && @user_group.user_id == @current_user.id}
      class="-my-4 divide-y divide-zinc-100"
    >
      <div class="flex flex-row-reverse gap-4 py-4 sm:gap-2">
        <div
          class="text-sm text-gray-500 dark:text-gray-400"
          style="margin-right: 6%; margin-top: -2.75%;"
        >
          {decr_item(@message.content, @current_user, @user_group_key, @key, @group)}
        </div>
      </div>
    </div>

    <%!-- show other messages on left side of screen --%>
    <div :if={@user_group.id != @message.sender_id} class="-my-4 divide-y divide-zinc-100">
      <div class="flex gap-4 py-4 sm:gap-2">
        <div
          class="text-sm text-gray-500 dark:text-gray-400"
          style="margin-left: 6%; margin-top: -2.75%;"
        >
          {decr_item(@message.content, @current_user, @user_group_key, @key, @group)}
        </div>
      </div>
    </div>
    """
  end
end
