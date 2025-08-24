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
        class="mt-2 pb-1.5"
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
    <div class="space-y-2 bg-background-200 dark:bg-gray-900 rounded-md">
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
    <div class="relative mt-6 flex flex-col text-sm leading-6">
      <div class="inline-flex py-2 ml-2">
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

        <.phx_avatar
          :if={@user_group.id == @message.sender_id}
          src={maybe_get_user_avatar(@current_user, @key)}
          alt="your group member avatar"
          class={group_avatar_role_style(@message.sender.role)}
        />

        <div class="pl-2 inline-flex text-[0.9rem] text-gray-900 dark:text-gray-100 font-medium">
          <span :if={@message.sender.name} class="md:w-full">
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
          <span :if={!@message.sender.name} class="md:w-full">
            {maybe_decr_username_for_user_group(@message.sender.user_id, @current_user, @key)}
          </span>
          <div class="inline-flex ml-2 mt-1 text-nowrap text-xs text-gray-600 dark:text-gray-400">
            <.local_time
              id={@message.id <> "-created"}
              for={@message.inserted_at}
              preset="DATETIME_SHORT"
            />
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
    <div class="-my-4">
      <div class="flex gap-4 py-4 sm:gap-2">
        <div
          class="text-md text-gray-600 dark:text-gray-400"
          style="margin-left: 7%; margin-top: -2.75%;"
        >
          {decr_item(@message.content, @current_user, @user_group_key, @key, @group)}
        </div>
      </div>
    </div>
    """
  end
end
