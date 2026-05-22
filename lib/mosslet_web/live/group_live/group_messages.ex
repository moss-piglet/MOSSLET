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
    decrypted = Map.get(assigns.message, :decrypted, %{})

    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.message.sender_id),
        assigns.current_scope.user
      )

    # Avatar: prefer connection avatar, fall back to decrypted group avatar
    group_avatar_path =
      case decrypted[:avatar_img] do
        img when is_binary(img) and img != "" -> ~p"/images/groups/#{img}"
        _ -> ~p"/images/groups/default.png"
      end

    avatar_src =
      if assigns.user_group.id == assigns.message.sender_id do
        nil
      else
        if uconn do
          case maybe_get_avatar_src(
                 uconn,
                 assigns.current_scope.user,
                 assigns.current_scope.key,
                 assigns.messages_list
               ) do
            nil -> group_avatar_path
            src -> src
          end
        else
          group_avatar_path
        end
      end

    is_self = assigns.user_group.id == assigns.message.sender_id
    is_connected = not is_nil(uconn)

    sender_name =
      cond do
        is_self ->
          maybe_decr_username_for_user_group(
            assigns.message.sender.user_id,
            assigns.current_scope.user,
            assigns.current_scope.key
          )

        is_connected ->
          maybe_decr_username_for_user_group(
            assigns.message.sender.user_id,
            assigns.current_scope.user,
            assigns.current_scope.key
          )

        true ->
          nil
      end

    moniker = decrypted[:moniker] || "member"

    # For non-public groups, content is nil (browser decrypts via hook).
    # For public groups, content is pre-decrypted by the server.
    raw_content = decrypted[:content]

    is_own_message = assigns.user_group.id == assigns.message.sender_id
    browser_decrypt? = decrypted[:browser_decrypt?] || false

    {content, can_check_mentions} =
      if browser_decrypt? do
        # Content will be decrypted and rendered by the DecryptGroupMessage hook
        {nil, false}
      else
        markdown_html = Mosslet.MarkdownRenderer.to_html(raw_content)
        rendered = render_mentions(markdown_html, assigns, is_own_message)
        {rendered, true}
      end

    can_delete =
      assigns.user_group.role in [:owner, :admin, :moderator] || is_own_message

    is_grouped = Map.get(assigns.message, :is_grouped, false)
    show_date_separator = Map.get(assigns.message, :show_date_separator, false)
    message_datetime = assigns.message.inserted_at
    is_new_message = Map.get(assigns.message, :is_new_message, false)

    is_mentioned =
      if can_check_mentions do
        content_mentions_user?(raw_content, assigns.user_group.id)
      else
        # For browser-decrypted messages, check the encrypted content for mention tokens
        # (mention tokens @[uuid] are not encrypted — they're part of the plaintext structure)
        content_mentions_user?(assigns.message.content, assigns.user_group.id)
      end

    is_new_mention = is_mentioned && is_new_message

    assigns =
      assigns
      |> assign(:avatar_src, avatar_src)
      |> assign(:sender_name, sender_name)
      |> assign(:moniker, moniker)
      |> assign(:content, content)
      |> assign(:can_delete, can_delete)
      |> assign(:is_own_message, is_own_message)
      |> assign(:is_grouped, is_grouped)
      |> assign(:show_date_separator, show_date_separator)
      |> assign(:message_datetime, message_datetime)
      |> assign(:is_mentioned, is_mentioned)
      |> assign(:is_new_mention, is_new_mention)
      |> assign(:browser_decrypt?, browser_decrypt?)
      |> assign(:encrypted_content, decrypted[:encrypted_content])
      |> assign(:sealed_group_key, decrypted[:sealed_group_key])

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
      is_new_mention={@is_new_mention}
    >
      <div
        :if={@browser_decrypt?}
        id={"decrypt-msg-#{@message.id}"}
        phx-hook="DecryptGroupMessage"
        data-encrypted-content={@encrypted_content}
        data-sealed-group-key={@sealed_group_key}
      >
        <span class="text-slate-400 dark:text-slate-500 text-sm italic">Decrypting...</span>
      </div>
      <div :if={not @browser_decrypt?}>
        {@content |> Phoenix.HTML.raw()}
      </div>
    </DesignSystem.liquid_chat_message>
    """
  end

  defp content_mentions_user?(content, user_group_id) when is_binary(content) do
    String.contains?(content, "@[#{user_group_id}]")
  end

  defp content_mentions_user?(_, _), do: false

  defp render_mentions(content, assigns, is_own_message) when is_binary(content) do
    Regex.replace(@mention_token_regex, content, fn _full, user_group_id ->
      render_mention_pill(user_group_id, assigns, is_own_message)
    end)
  end

  defp render_mentions(content, _assigns, _is_own_message), do: content

  defp render_mention_pill(user_group_id, assigns, is_own_message) do
    is_self = user_group_id == assigns.user_group.id

    case Groups.get_user_group(user_group_id) do
      nil ->
        "@unknown"

      mentioned_ug ->
        mentioned_user = get_user_from_user_group_id(user_group_id)
        uconn = get_uconn_for_users(mentioned_user, assigns.current_scope.user)
        is_connected = not is_nil(uconn)

        display_name =
          cond do
            is_self ->
              maybe_decr_username_for_user_group(
                mentioned_ug.user_id,
                assigns.current_scope.user,
                assigns.current_scope.key
              )

            is_connected ->
              maybe_decr_username_for_user_group(
                mentioned_ug.user_id,
                assigns.current_scope.user,
                assigns.current_scope.key
              )

            true ->
              decr_item(
                mentioned_ug.moniker,
                assigns.current_scope.user,
                assigns.user_group.key,
                assigns.current_scope.key,
                assigns.group
              )
          end

        role = mentioned_ug.role || :member
        text_class = mention_text_class(role, is_own_message)

        if is_self do
          "<span class=\"mention-self #{text_class} font-semibold underline decoration-2 underline-offset-2\"><span class=\"opacity-60\">@</span>#{display_name}</span>"
        else
          "<span class=\"mention #{text_class} font-medium\"><span class=\"opacity-50\">@</span>#{display_name}</span>"
        end
    end
  end

  defp mention_text_class(:owner, true), do: "text-pink-200"
  defp mention_text_class(:admin, true), do: "text-orange-200"
  defp mention_text_class(:moderator, true), do: "text-purple-200"
  defp mention_text_class(:member, true), do: "text-yellow-200"
  defp mention_text_class(_, true), do: "text-slate-200"
  defp mention_text_class(:owner, _), do: "text-pink-600 dark:text-pink-300"
  defp mention_text_class(:admin, _), do: "text-orange-600 dark:text-orange-300"
  defp mention_text_class(:moderator, _), do: "text-purple-600 dark:text-purple-300"
  defp mention_text_class(:member, _), do: "text-emerald-600 dark:text-emerald-300"
  defp mention_text_class(_, _), do: "text-slate-600 dark:text-slate-300"
end
