defmodule MossletWeb.GroupLive.Group do
  use Phoenix.Component
  alias MossletWeb.GroupLive.{GroupMessages, GroupMessage}

  attr :group, :map, required: true
  attr :messages, :any, required: true
  attr :messages_list, :list, required: true
  attr :current_scope, :map, required: true
  attr :user_group, :map, required: true
  attr :scrolled_to_top, :string, required: true
  attr :current_page, :atom, default: nil

  # Org-scoped ZK display names (Task #283): present only for org-backed circles
  # (Family/Business). Personal circles pass the defaults and are unaffected.
  attr :viewer_sealed_org_key, :string, default: nil
  attr :org_display_names, :map, default: %{}

  def show(assigns) do
    ~H"""
    <div id={"group-#{@group.id}"} class="h-full flex flex-col">
      <GroupMessages.list_messages
        messages={@messages}
        messages_list={@messages_list}
        scrolled_to_top={@scrolled_to_top}
        current_scope={@current_scope}
        user_group_key={@user_group.key}
        group={@group}
        current_page={@current_page}
        user_group={@user_group}
        viewer_sealed_org_key={@viewer_sealed_org_key}
        org_display_names={@org_display_names}
      />

      <div class="flex-shrink-0">
        <.live_component
          module={GroupMessage.Form}
          group_id={@group.id}
          sender_id={@user_group.id}
          current_scope={@current_scope}
          user_group_key={@user_group.key}
          public?={@group.public?}
          current_page={@current_page}
          viewer_sealed_org_key={@viewer_sealed_org_key}
          org_display_names={@org_display_names}
          id={"group-#{@group.id}-message-form"}
        />
      </div>
    </div>
    """
  end
end
