defmodule MossletWeb.GroupLive.GroupMessages do
  use MossletWeb, :html
  alias MossletWeb.DesignSystem
  alias Mosslet.Groups

  @mention_token_regex ~r/@\[([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\]/i

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
        group_avatar_fallback =
          ~p"/images/groups/#{decr_item(assigns.message.sender.avatar_img, assigns.current_scope.user, assigns.user_group.key, assigns.current_scope.key, assigns.group)}"

        if uconn do
          case maybe_get_avatar_src(
                 uconn,
                 assigns.current_scope.user,
                 assigns.current_scope.key,
                 assigns.messages_list
               ) do
            "" -> group_avatar_fallback
            nil -> group_avatar_fallback
            src -> src
          end
        else
          group_avatar_fallback
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

    raw_content =
      decr_item(
        assigns.message.content,
        assigns.current_scope.user,
        assigns.user_group_key,
        assigns.current_scope.key,
        assigns.group
      )

    content = render_mentions(raw_content, assigns)

    can_delete =
      assigns.user_group.role in [:owner, :admin, :moderator] ||
        assigns.user_group.id == assigns.message.sender_id

    is_grouped = Map.get(assigns.message, :is_grouped, false)
    show_date_separator = Map.get(assigns.message, :show_date_separator, false)
    message_datetime = assigns.message.inserted_at

    is_mentioned = content_mentions_user?(raw_content, assigns.user_group.id)

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
      |> assign(:message_datetime, message_datetime)
      |> assign(:is_mentioned, is_mentioned)

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
      message_datetime={@message_datetime}
      is_mentioned={@is_mentioned}
    >
      {Mosslet.MarkdownRenderer.to_html(@content) |> Phoenix.HTML.raw()}
    </DesignSystem.liquid_chat_message>
    """
  end

  defp content_mentions_user?(content, user_group_id) when is_binary(content) do
    String.contains?(content, "@[#{user_group_id}]")
  end

  defp content_mentions_user?(_, _), do: false

  defp render_mentions(content, assigns) when is_binary(content) do
    Regex.replace(@mention_token_regex, content, fn _full, user_group_id ->
      render_mention_pill(user_group_id, assigns)
    end)
  end

  defp render_mentions(content, _assigns), do: content

  defp render_mention_pill(user_group_id, assigns) do
    is_self = user_group_id == assigns.user_group.id

    case Groups.get_user_group(user_group_id) do
      nil ->
        "@unknown"

      mentioned_ug ->
        mentioned_user = get_user_from_user_group_id(user_group_id)
        uconn = get_uconn_for_users(mentioned_user, assigns.current_scope.user)
        is_connected = not is_nil(uconn)

        display_name =
          if is_self || is_connected do
            if mentioned_ug.name do
              decr_item(
                mentioned_ug.name,
                assigns.current_scope.user,
                assigns.user_group.key,
                assigns.current_scope.key,
                assigns.group
              )
            else
              maybe_decr_username_for_user_group(
                mentioned_ug.user_id,
                assigns.current_scope.user,
                assigns.current_scope.key
              )
            end
          else
            decr_item(
              mentioned_ug.moniker,
              assigns.current_scope.user,
              assigns.user_group.key,
              assigns.current_scope.key,
              assigns.group
            )
          end

        if is_self do
          "<span class=\"mention-pill mention-pill-self inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md bg-gradient-to-r from-teal-100 to-emerald-100 dark:from-teal-900/50 dark:to-emerald-900/50 text-teal-700 dark:text-teal-300 text-sm font-medium border border-teal-200/60 dark:border-teal-700/40\">@#{display_name}</span>"
        else
          "<span class=\"mention-pill inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md bg-slate-100 dark:bg-slate-700/50 text-slate-700 dark:text-slate-300 text-sm font-medium border border-slate-200/60 dark:border-slate-600/40\">@#{display_name}</span>"
        end
    end
  end
end
