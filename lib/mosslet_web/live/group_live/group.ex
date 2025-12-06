defmodule MossletWeb.GroupLive.Group do
  use Phoenix.Component
  alias MossletWeb.GroupLive.{GroupMessages, GroupMessage}

  def show(assigns) do
    ~H"""
    <div id={"group-#{@group.id}"} class="h-full flex flex-col">
      <GroupMessages.list_messages
        messages={@messages}
        messages_list={@messages_list}
        scrolled_to_top={@scrolled_to_top}
        current_user={@current_user}
        user_group_key={@user_group.key}
        group={@group}
        current_page={@current_page}
        user_group={@user_group}
        key={@key}
      />

      <div class="flex-shrink-0">
        <.live_component
          module={GroupMessage.Form}
          group_id={@group.id}
          sender_id={@user_group.id}
          current_user={@current_user}
          user_group_key={@user_group.key}
          public?={@group.public?}
          current_page={@current_page}
          key={@key}
          id={"group-#{@group.id}-message-form"}
        />
      </div>
    </div>
    """
  end
end
