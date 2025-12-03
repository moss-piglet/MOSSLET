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

      <div class="flex-shrink-0 border-t border-slate-200/60 dark:border-slate-700/60 bg-gradient-to-r from-slate-50/80 via-white/60 to-slate-50/80 dark:from-slate-800/60 dark:via-slate-700/40 dark:to-slate-800/60 backdrop-blur-sm px-4 sm:px-6 py-3 sm:py-4">
        <.live_component
          module={GroupMessage.Form}
          group_id={@group.id}
          sender_id={@user_group.id}
          current_user={@current_user}
          user_group_key={@user_group.key}
          public?={@group.public?}
          key={@key}
          id={"group-#{@group.id}-message-form"}
        />
      </div>
    </div>
    """
  end
end
