defmodule MossletWeb.GroupLive.GroupMessages do
  use MossletWeb, :html
  alias MossletWeb.DesignSystem

  def list_messages(assigns) do
    ~H"""
    <div
      id="messages-container"
      class="flex-1 overflow-y-auto min-h-0 px-3 sm:px-4 lg:px-6 py-4"
      phx-hook="ScrollDown"
      data-scrolled-to-top={@scrolled_to_top}
      style="scrollbar-width: thin; scrollbar-color: rgb(20 184 166 / 0.5) transparent;"
      tabindex="0"
      role="log"
      aria-label="Chat messages"
    >
      <div class="max-w-4xl mx-auto">
        <div id="infinite-scroll-marker" phx-hook="InfiniteScrollGroupMessage"></div>
        <div id="messages" phx-update="stream" class="space-y-1">
          <div :for={{dom_id, message} <- @messages} id={dom_id}>
            <.message_details
              message={message}
              current_scope={@current_scope}
              user_group_key={@user_group_key}
              group={@group}
              user_group={@user_group}
              messages_list={@messages_list}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :message, :map, required: true
  attr :current_scope, :map, required: true
  attr :user_group_key, :string, required: true
  attr :group, :map, required: true
  attr :user_group, :map, required: true
  attr :messages_list, :list, required: true

  def message_details(assigns) do
    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.message.sender_id),
        assigns.current_scope.user
      )

    avatar_src =
      if assigns.user_group.id == assigns.message.sender_id do
        maybe_get_user_avatar(assigns.current_scope.user, assigns.current_scope.key) ||
          ~p"/images/groups/#{decr_item(assigns.message.sender.avatar_img, assigns.current_scope.user, assigns.user_group.key, assigns.current_scope.key, assigns.group)}"
      else
        if uconn do
          maybe_get_avatar_src(
            uconn,
            assigns.current_scope.user,
            assigns.current_scope.key,
            assigns.messages_list
          )
        else
          ~p"/images/groups/#{decr_item(assigns.message.sender.avatar_img, assigns.current_scope.user, assigns.user_group.key, assigns.current_scope.key, assigns.group)}"
        end
      end

    is_self = assigns.user_group.id == assigns.message.sender_id
    is_connected = not is_nil(uconn)

    sender_name =
      if is_self || is_connected do
        if assigns.message.sender.name do
          initials(
            decr_item(
              assigns.message.sender.name,
              assigns.current_scope.user,
              assigns.user_group.key,
              assigns.current_scope.key,
              assigns.group
            )
          )
        else
          maybe_decr_username_for_user_group(
            assigns.message.sender.user_id,
            assigns.current_scope.user,
            assigns.current_scope.key
          )
        end
      else
        nil
      end

    moniker =
      decr_item(
        assigns.message.sender.moniker,
        assigns.current_scope.user,
        assigns.user_group.key,
        assigns.current_scope.key,
        assigns.group
      )

    content =
      decr_item(
        assigns.message.content,
        assigns.current_scope.user,
        assigns.user_group_key,
        assigns.current_scope.key,
        assigns.group
      )

    can_delete =
      assigns.user_group.role in [:owner, :admin, :moderator] ||
        assigns.user_group.id == assigns.message.sender_id

    is_grouped = Map.get(assigns.message, :is_grouped, false)
    show_date_separator = Map.get(assigns.message, :show_date_separator, false)
    message_date = Map.get(assigns.message, :message_date)

    assigns =
      assigns
      |> assign(:avatar_src, avatar_src)
      |> assign(:sender_name, sender_name)
      |> assign(:moniker, moniker)
      |> assign(:content, content)
      |> assign(:can_delete, can_delete)
      |> assign(:is_own_message, assigns.user_group.id == assigns.message.sender_id)
      |> assign(:is_grouped, is_grouped)
      |> assign(:show_date_separator, show_date_separator)
      |> assign(:message_date, message_date)

    ~H"""
    <DesignSystem.liquid_chat_message
      id={@message.id}
      avatar_src={@avatar_src}
      avatar_alt="circle member avatar"
      sender_name={@sender_name}
      moniker={@moniker}
      role={@message.sender.role}
      timestamp={@message.inserted_at}
      is_own_message={@is_own_message}
      can_delete={@can_delete}
      on_delete="delete_message"
      is_grouped={@is_grouped}
      show_date_separator={@show_date_separator}
      message_date={@message_date}
    >
      {@content}
    </DesignSystem.liquid_chat_message>
    """
  end
end
