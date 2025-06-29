defmodule MossletWeb.GroupLive.Group do
  use Phoenix.Component
  alias MossletWeb.GroupLive.{GroupMessages, GroupMessage}

  def show(assigns) do
    ~H"""
    <div id={"group-#{@group.id}"}>
      <GroupMessages.list_messages
        messages={@messages}
        messages_list={@messages_list}
        scrolled_to_top={@scrolled_to_top}
        current_user={@current_user}
        user_group_key={@user_group.key}
        group={@group}
        user_group={@user_group}
        key={@key}
      />
      <.live_component
        module={GroupMessage.Form}
        group_id={@group.id}
        sender_id={@user_group.id}
        current_user={@current_user}
        user_group_key={@user_group.key}
        key={@key}
        id={"group-#{@group.id}-message-form"}
      />
    </div>
    """
  end
end
