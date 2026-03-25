defmodule MossletWeb.ConversationLive.Show do
  use MossletWeb, :live_view

  import Ecto.Query, only: [from: 2]

  alias Mosslet.Accounts
  alias Mosslet.Conversations

  def render(assigns) do
    ~H"""
    <.layout
      current_page={:conversations}
      sidebar_current_page={:conversations}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="flex flex-col h-full" id="conversation-show-container">
        <div class={[
          "flex-shrink-0 flex items-center gap-3 px-4 sm:px-6 py-3",
          "border-b border-slate-200/60 dark:border-slate-700/60",
          "bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm"
        ]}>
          <.link
            navigate={~p"/app/conversations"}
            class="p-1.5 -ml-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-all duration-200"
            aria-label="Back to conversations"
          >
            <.phx_icon name="hero-arrow-left" class="size-5" />
          </.link>

          <div class="flex items-center gap-3 flex-1 min-w-0">
            <div class="w-10 h-10 rounded-full overflow-hidden ring-2 ring-offset-1 ring-offset-white dark:ring-offset-slate-800 ring-slate-200/60 dark:ring-slate-700/60 flex-shrink-0">
              <img src={@partner_avatar} alt="Avatar" class="w-full h-full object-cover" />
            </div>
            <div class="min-w-0">
              <h1 class="font-semibold text-sm text-slate-900 dark:text-slate-100 truncate">
                {@partner_name}
              </h1>
              <p class="text-xs text-slate-500 dark:text-slate-400 truncate">
                <span class="inline-flex items-center gap-1">
                  <.phx_icon name="hero-lock-closed" class="w-3 h-3 text-teal-500" />
                  End-to-end encrypted
                </span>
              </p>
            </div>
          </div>

          <div class="flex items-center gap-1">
            <button
              :if={!@is_blocked}
              type="button"
              phx-click="open_block_modal"
              class="p-2 rounded-lg text-slate-400 hover:text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20 transition-all duration-200"
              title={"Block #{@partner_name}"}
            >
              <.phx_icon name="hero-no-symbol" class="size-5" />
            </button>
          </div>
        </div>

        <%= if @is_blocked do %>
          <div class="flex-1 flex items-center justify-center px-4">
            <div class="text-center max-w-sm">
              <div class="flex size-14 items-center justify-center rounded-2xl bg-rose-100 dark:bg-rose-900/30 mx-auto mb-4">
                <.phx_icon name="hero-no-symbol" class="size-7 text-rose-500 dark:text-rose-400" />
              </div>
              <h2 class="text-base font-semibold text-slate-800 dark:text-slate-200 mb-2">
                Conversation Blocked
              </h2>
              <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">
                <%= if @blocked_by_me do %>
                  You have blocked this user. Unblock them from your settings to resume messaging.
                <% else %>
                  You cannot send messages in this conversation.
                <% end %>
              </p>
              <.link
                navigate={~p"/app/conversations"}
                class="text-sm font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300"
              >
                ← Back to conversations
              </.link>
            </div>
          </div>
        <% else %>
          <div
            id="messages-container"
            class="flex-1 overflow-y-auto min-h-0 px-4 sm:px-6 py-4 space-y-1"
            phx-hook="ConversationScroll"
          >
            <div class="max-w-4xl mx-auto">
              <div
                :if={@messages == []}
                class="flex flex-col items-center justify-center h-full text-center py-12"
              >
                <div class="flex size-14 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 mb-4">
                  <.phx_icon name="hero-lock-closed" class="size-7 text-teal-600 dark:text-teal-400" />
                </div>
                <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Start your encrypted conversation
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400 max-w-xs">
                  Messages are encrypted end-to-end. Only you and {@partner_name} can read them.
                </p>
              </div>

              <div
                :for={message <- @messages}
                id={"msg-#{message.id}"}
                class={[
                  "group/msg flex mb-2",
                  if(message.sender_id == @current_scope.user.id,
                    do: "justify-end",
                    else: "justify-start"
                  )
                ]}
              >
                <div class="max-w-[85%] sm:max-w-[75%]">
                  <div class={[
                    "relative rounded-2xl px-4 py-2.5 text-sm leading-relaxed shadow-sm transition-all duration-200",
                    if(message.sender_id == @current_scope.user.id,
                      do: [
                        "bg-gradient-to-r from-teal-500 to-emerald-500 dark:from-teal-600 dark:to-emerald-600",
                        "text-white",
                        "border border-teal-400/40 dark:border-teal-500/50",
                        "shadow-lg shadow-teal-500/25 dark:shadow-teal-500/15"
                      ],
                      else: [
                        "bg-white/95 dark:bg-slate-800/80 backdrop-blur-sm",
                        "text-slate-800 dark:text-slate-200",
                        "border border-slate-200/60 dark:border-slate-700/50"
                      ]
                    )
                  ]}>
                    <div
                      id={"msg-content-#{message.id}"}
                      phx-hook="DecryptMessage"
                      data-encrypted-content={encode_message_content(message.content)}
                      data-conversation-key={@conversation_key_encrypted}
                      class={[
                        "prose prose-sm max-w-none prose-p:my-0.5 prose-headings:mt-2 prose-headings:mb-1 prose-ul:my-1 prose-ol:my-1 prose-li:my-0 prose-pre:my-1.5 break-words",
                        if(message.sender_id == @current_scope.user.id,
                          do:
                            "text-white prose-headings:text-white prose-strong:text-white prose-code:text-teal-100 prose-code:bg-white/10 prose-a:text-teal-100 prose-a:no-underline hover:prose-a:underline",
                          else:
                            "prose-slate dark:prose-invert prose-code:text-teal-600 dark:prose-code:text-teal-400 prose-a:text-teal-600 dark:prose-a:text-teal-400 prose-a:no-underline hover:prose-a:underline"
                        )
                      ]}
                    >
                      <span class="inline-flex items-center gap-1 text-xs opacity-60">
                        <.phx_icon name="hero-lock-closed" class="w-3 h-3" /> Decrypting...
                      </span>
                    </div>
                  </div>
                  <div class={[
                    "flex items-center gap-1.5 mt-1 px-1",
                    if(message.sender_id == @current_scope.user.id,
                      do: "justify-end",
                      else: "justify-start"
                    )
                  ]}>
                    <time class="text-xs text-slate-500 dark:text-slate-400">
                      <.local_time_ago id={"msg-time-#{message.id}"} at={message.inserted_at} />
                    </time>
                    <span
                      :if={message.edited}
                      class="text-xs text-slate-500 dark:text-slate-400 italic"
                    >
                      (edited)
                    </span>
                    <button
                      :if={message.sender_id == @current_scope.user.id}
                      type="button"
                      phx-click="confirm_delete_message"
                      phx-value-id={message.id}
                      class="opacity-0 group-hover/msg:opacity-100 p-0.5 rounded text-slate-400 hover:text-rose-500 transition-all duration-200"
                      title="Delete message"
                    >
                      <.phx_icon name="hero-trash" class="size-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class={[
            "flex-shrink-0 px-4 sm:px-6 py-3",
            "border-t border-slate-200/60 dark:border-slate-700/60",
            "bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm"
          ]}>
            <div
              id="conversation-composer"
              phx-hook="ConversationComposer"
              data-conversation-key={@conversation_key_encrypted}
              data-user-public-key={@current_scope.user.key_pair["public"]}
              data-session-key={@current_scope.key}
              data-encrypted-private-key={@current_scope.user.key_pair["private"]}
              class="max-w-4xl mx-auto"
            >
              <.form for={@form} id="message-form">
                <div class="relative">
                  <textarea
                    id="message-input"
                    name="content"
                    rows="1"
                    placeholder={"Message #{@partner_name}..."}
                    class={[
                      "block w-full resize-none rounded-2xl py-3 pl-4 pr-32 text-sm leading-relaxed",
                      "bg-slate-50/60 dark:bg-slate-900/40",
                      "border border-slate-200/60 dark:border-slate-700/60",
                      "focus:border-teal-400/60 dark:focus:border-teal-500/60",
                      "focus:ring-2 focus:ring-teal-500/20 dark:focus:ring-teal-400/20 focus:outline-none",
                      "text-slate-900 dark:text-slate-100",
                      "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                      "transition-all duration-200",
                      "min-h-[48px] max-h-32 overflow-y-auto"
                    ]}
                    phx-hook="AutoResize"
                  ></textarea>
                  <div class="absolute right-2 bottom-2 flex items-center gap-1 z-[2]">
                    <button
                      type="button"
                      id="conversation-image-upload-button"
                      phx-click="image_upload_placeholder"
                      class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group"
                      title="Attach image (coming soon)"
                    >
                      <.phx_icon
                        name="hero-photo"
                        class="h-4 w-4 transition-transform duration-200 group-hover:scale-110"
                      />
                    </button>
                    <button
                      type="button"
                      id="conversation-emoji-button"
                      class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group"
                      phx-hook="ConversationEmojiPicker"
                      title="Add emoji"
                    >
                      <.phx_icon
                        name="hero-face-smile"
                        class="h-4 w-4 transition-transform duration-200 group-hover:scale-110"
                      />
                    </button>
                    <.liquid_markdown_guide_trigger
                      id="conversation-markdown-guide-trigger"
                      on_click={JS.push("open_markdown_guide")}
                      size="sm"
                    />
                    <button
                      type="submit"
                      class="group/btn inline-flex items-center justify-center gap-1.5 h-10 px-3 sm:px-4 rounded-xl bg-gradient-to-br from-teal-500 to-emerald-500 hover:from-teal-400 hover:to-emerald-400 text-white shadow-lg shadow-teal-500/25 hover:shadow-xl hover:shadow-teal-500/30 active:scale-95 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2 focus:ring-offset-white dark:focus:ring-offset-slate-800"
                      aria-label="Send message"
                    >
                      <.phx_icon name="hero-paper-airplane" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          </div>
        <% end %>
      </div>

      <.liquid_modal
        :if={@show_delete_message_confirm}
        id="delete-message-modal"
        show={@show_delete_message_confirm}
        size="sm"
        on_cancel={JS.push("cancel_delete_message")}
      >
        <:title>
          <div class="flex items-center gap-3">
            <div class="p-2 rounded-xl bg-rose-100 dark:bg-rose-900/30">
              <.phx_icon name="hero-trash" class="size-5 text-rose-600 dark:text-rose-400" />
            </div>
            <span>Delete Message</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-sm text-slate-600 dark:text-slate-400">
            Are you sure you want to delete this message? This cannot be undone.
          </p>
          <div class="flex justify-end gap-3 pt-2">
            <.liquid_button
              type="button"
              variant="ghost"
              color="slate"
              phx-click="cancel_delete_message"
            >
              Cancel
            </.liquid_button>
            <.liquid_button
              type="button"
              color="rose"
              icon="hero-trash"
              phx-click="delete_message"
              phx-value-id={@delete_message_id}
            >
              Delete
            </.liquid_button>
          </div>
        </div>
      </.liquid_modal>

      <.live_component
        :if={@show_block_modal}
        module={MossletWeb.TimelineLive.BlockModalComponent}
        id="block-modal-component"
        show={@show_block_modal}
        user_id={@blocked_user_id}
        user_name={@partner_name}
        post_id="conversation-show"
        existing_block={nil}
        default_block_type="full"
        decrypted_reason=""
        block_update?={false}
        target_container="#conversation-show-container"
      />

      <.liquid_markdown_guide_modal
        id="conversation-markdown-guide-modal"
        show={@show_markdown_guide}
        on_cancel={JS.push("close_markdown_guide")}
      />
    </.layout>
    """
  end

  def mount(%{"id" => conversation_id}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    conversation = Conversations.get_conversation!(conversation_id)
    user_conversation = Conversations.get_user_conversation(conversation_id, current_user.id)

    unless user_conversation do
      {:ok,
       socket
       |> put_flash(:error, "Conversation not found")
       |> push_navigate(to: ~p"/app/conversations")}
    else
      my_user_connection = find_my_user_connection(conversation, current_user)

      {partner_name, partner_avatar, _partner_username} =
        case my_user_connection do
          nil ->
            {"[Unknown]", "/images/logo.svg", "unknown"}

          uconn ->
            {
              get_decrypted_connection_name(uconn, current_user, key),
              get_connection_avatar_src(uconn, current_user, key),
              get_decrypted_connection_username(uconn, current_user, key)
            }
        end

      partner_user_id = get_partner_user_id(conversation, current_user.id)

      {is_blocked, blocked_by_me} = check_block_status(current_user, partner_user_id)

      messages =
        if is_blocked, do: [], else: Conversations.list_messages(conversation_id)

      conversation_key_encrypted =
        case user_conversation.key do
          key_data when is_binary(key_data) -> Base.encode64(key_data)
          _ -> ""
        end

      if connected?(socket) do
        Conversations.subscribe_to_conversation(conversation_id)
        Conversations.mark_conversation_read(conversation_id, current_user.id)
        Accounts.block_subscribe(current_user)
      end

      {:ok,
       socket
       |> assign(:page_title, "#{partner_name} — Conversations")
       |> assign(:conversation, conversation)
       |> assign(:user_conversation, user_conversation)
       |> assign(:partner_name, partner_name)
       |> assign(:partner_avatar, partner_avatar)
       |> assign(:partner_user_id, partner_user_id)
       |> assign(:is_blocked, is_blocked)
       |> assign(:blocked_by_me, blocked_by_me)
       |> assign(:messages, messages)
       |> assign(:conversation_key_encrypted, conversation_key_encrypted)
       |> assign(:show_markdown_guide, false)
       |> assign(:show_delete_message_confirm, false)
       |> assign(:delete_message_id, nil)
       |> assign(:show_block_modal, false)
       |> assign(:blocked_user_id, partner_user_id)
       |> assign(:form, to_form(%{}, as: :message))}
    end
  end

  def handle_event("send_message", %{"encrypted_content" => encrypted_content}, socket) do
    current_user = socket.assigns.current_scope.user
    conversation = socket.assigns.conversation

    if socket.assigns.is_blocked do
      {:noreply, put_flash(socket, :error, "Cannot send messages in a blocked conversation")}
    else
      attrs = %{
        content: Base.decode64!(encrypted_content),
        conversation_id: conversation.id,
        sender_id: current_user.id
      }

      case Conversations.create_message(attrs) do
        {:ok, message} ->
          Conversations.broadcast_new_message(conversation.id, message)

          conversation.user_conversations
          |> Enum.each(fn uc ->
            Conversations.broadcast_conversation_updated(uc.user_id, conversation.id)
          end)

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    end
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("confirm_delete_message", %{"id" => message_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_message_confirm, true)
     |> assign(:delete_message_id, message_id)}
  end

  def handle_event("cancel_delete_message", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_message_confirm, false)
     |> assign(:delete_message_id, nil)}
  end

  def handle_event("delete_message", %{"id" => message_id}, socket) do
    current_user = socket.assigns.current_scope.user
    message = Enum.find(socket.assigns.messages, &(&1.id == message_id))

    cond do
      is_nil(message) ->
        {:noreply, put_flash(socket, :error, "Message not found")}

      message.sender_id != current_user.id ->
        {:noreply, put_flash(socket, :error, "You can only delete your own messages")}

      true ->
        case Conversations.delete_message(message) do
          {:ok, deleted} ->
            Conversations.broadcast_message_deleted(socket.assigns.conversation.id, deleted)
            messages = Enum.reject(socket.assigns.messages, &(&1.id == message_id))

            {:noreply,
             socket
             |> assign(:messages, messages)
             |> assign(:show_delete_message_confirm, false)
             |> assign(:delete_message_id, nil)
             |> put_flash(:info, "Message deleted")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete message")}
        end
    end
  end

  def handle_event("open_block_modal", _params, socket) do
    {:noreply, assign(socket, :show_block_modal, true)}
  end

  def handle_event("close_block_modal", _params, socket) do
    {:noreply, assign(socket, :show_block_modal, false)}
  end

  def handle_event("open_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, true)}
  end

  def handle_event("close_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, false)}
  end

  def handle_event("image_upload_placeholder", _params, socket) do
    {:noreply, put_flash(socket, :info, "Encrypted image sharing is coming soon!")}
  end

  def handle_info({:submit_block, block_params}, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    partner_user_id = socket.assigns.partner_user_id

    blocked_user = Accounts.get_user!(partner_user_id)

    case Accounts.block_user(current_user, blocked_user, block_params,
           user: current_user,
           key: key
         ) do
      {:ok, _user_block} ->
        {:noreply,
         socket
         |> assign(:show_block_modal, false)
         |> assign(:is_blocked, true)
         |> assign(:blocked_by_me, true)
         |> assign(:messages, [])
         |> put_flash(:info, "User has been blocked")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to block user")}
    end
  end

  def handle_info({:close_block_modal}, socket) do
    {:noreply, assign(socket, :show_block_modal, false)}
  end

  def handle_info({:new_message, message}, socket) do
    if socket.assigns.is_blocked do
      {:noreply, socket}
    else
      current_user = socket.assigns.current_scope.user

      socket =
        socket
        |> assign(:messages, socket.assigns.messages ++ [message])
        |> push_event("new-message", %{id: message.id})

      if message.sender_id != current_user.id do
        Conversations.mark_conversation_read(socket.assigns.conversation.id, current_user.id)
      end

      {:noreply, socket}
    end
  end

  def handle_info({:message_updated, message}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn m ->
        if m.id == message.id, do: message, else: m
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:message_deleted, message}, socket) do
    messages = Enum.reject(socket.assigns.messages, &(&1.id == message.id))
    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({event, _block}, socket)
      when event in [:user_blocked, :user_unblocked, :user_block_updated] do
    current_user = socket.assigns.current_scope.user
    partner_user_id = socket.assigns.partner_user_id
    {is_blocked, blocked_by_me} = check_block_status(current_user, partner_user_id)

    messages =
      if is_blocked, do: [], else: Conversations.list_messages(socket.assigns.conversation.id)

    {:noreply,
     socket
     |> assign(:is_blocked, is_blocked)
     |> assign(:blocked_by_me, blocked_by_me)
     |> assign(:messages, messages)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp encode_message_content(content) when is_binary(content) do
    Base.encode64(content)
  end

  defp encode_message_content(_), do: ""

  defp find_my_user_connection(conversation, current_user) do
    connection_id = conversation.user_connection.connection_id

    from(uc in Mosslet.Accounts.UserConnection,
      where: uc.user_id == ^current_user.id and uc.connection_id == ^connection_id,
      preload: [:connection]
    )
    |> Mosslet.Repo.one()
  end

  defp get_partner_user_id(conversation, current_user_id) do
    conversation.user_conversations
    |> Enum.find(fn uc -> uc.user_id != current_user_id end)
    |> case do
      nil -> nil
      uc -> uc.user_id
    end
  end

  defp check_block_status(current_user, partner_user_id) when is_binary(partner_user_id) do
    my_block = Accounts.get_user_block(current_user, partner_user_id)
    partner = Accounts.get_user!(partner_user_id)
    their_block = Accounts.get_user_block(partner, current_user.id)

    conversation_blocked_by_me =
      my_block != nil and my_block.block_type in [:full, :conversations_only]

    conversation_blocked_by_them =
      their_block != nil and their_block.block_type in [:full, :conversations_only]

    {conversation_blocked_by_me || conversation_blocked_by_them, conversation_blocked_by_me}
  end

  defp check_block_status(_current_user, _partner_user_id), do: {false, false}
end
