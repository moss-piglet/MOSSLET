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
        user_group={@user_group}
        key={@key}
      />

      <div class="flex-shrink-0 border-t border-gray-200/50 dark:border-emerald-500/30 bg-gradient-to-r from-gray-50/80 via-white/60 to-gray-50/80 dark:from-gray-800/50 dark:via-gray-700/30 dark:to-gray-800/50 backdrop-blur-sm px-6 py-4">
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
    </div>
    """
  end
end
