defmodule MossletWeb.GroupLive.GroupMessages do
  use MossletWeb, :html
  alias MossletWeb.DesignSystem

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
      <div :for={{dom_id, message} <- @messages} id={dom_id}>
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
    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.message.sender_id),
        assigns.current_user
      )

    avatar_src =
      if assigns.user_group.id == assigns.message.sender_id do
        maybe_get_user_avatar(assigns.current_user, assigns.key)
      else
        if uconn do
          maybe_get_avatar_src(
            uconn,
            assigns.current_user,
            assigns.key,
            assigns.messages_list
          )
        else
          ~p"/images/groups/#{decr_item(assigns.message.sender.avatar_img, assigns.current_user, assigns.user_group.key, assigns.key, assigns.group)}"
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
              assigns.current_user,
              assigns.user_group.key,
              assigns.key,
              assigns.group
            )
          )
        else
          maybe_decr_username_for_user_group(
            assigns.message.sender.user_id,
            assigns.current_user,
            assigns.key
          )
        end
      else
        nil
      end

    moniker =
      decr_item(
        assigns.message.sender.moniker,
        assigns.current_user,
        assigns.user_group.key,
        assigns.key,
        assigns.group
      )

    content =
      decr_item(
        assigns.message.content,
        assigns.current_user,
        assigns.user_group_key,
        assigns.key,
        assigns.group
      )

    can_delete =
      assigns.user_group.role in [:owner, :admin, :moderator] ||
        assigns.user_group.id == assigns.message.sender_id

    assigns =
      assigns
      |> assign(:avatar_src, avatar_src)
      |> assign(:sender_name, sender_name)
      |> assign(:moniker, moniker)
      |> assign(:content, content)
      |> assign(:can_delete, can_delete)
      |> assign(:is_own_message, assigns.user_group.id == assigns.message.sender_id)

    ~H"""
    <DesignSystem.liquid_chat_message
      id={@message.id}
      avatar_src={@avatar_src}
      avatar_alt="group member avatar"
      sender_name={@sender_name}
      moniker={@moniker}
      role={@message.sender.role}
      timestamp={@message.inserted_at}
      is_own_message={@is_own_message}
      can_delete={@can_delete}
      on_delete="delete_message"
    >
      {@content}
    </DesignSystem.liquid_chat_message>
    """
  end
end
