defmodule MossletWeb.ConversationLive.Index do
  use MossletWeb, :live_view

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
      <div id="conversation-index-hook" phx-hook="StartConversation">
        <.liquid_container class="py-6">
          <div class="max-w-3xl mx-auto">
            <div class="flex items-center justify-between mb-6">
              <div class="flex items-center gap-3">
                <div class="flex size-10 items-center justify-center rounded-xl bg-gradient-to-r from-teal-500 to-emerald-500">
                  <.phx_icon name="hero-chat-bubble-left-right" class="size-5 text-white" />
                </div>
                <div>
                  <h1 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
                    Conversations
                  </h1>
                  <p class="text-sm text-slate-500 dark:text-slate-400">
                    End-to-end encrypted messages
                  </p>
                </div>
              </div>
              <button
                type="button"
                phx-click="open_new_conversation"
                class={[
                  "inline-flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-lg",
                  "text-teal-700 dark:text-teal-300",
                  "bg-teal-50 dark:bg-teal-900/30",
                  "border border-teal-200/60 dark:border-teal-700/40",
                  "hover:bg-teal-100 dark:hover:bg-teal-900/50",
                  "transition-all duration-200"
                ]}
              >
                <.phx_icon name="hero-plus" class="size-4" />
                <span class="hidden sm:inline">New</span>
              </button>
            </div>

            <div
              :if={@conversations == []}
              class="text-center py-16"
            >
              <div class="flex size-16 items-center justify-center rounded-2xl bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700 mx-auto mb-4">
                <.phx_icon
                  name="hero-chat-bubble-left-right"
                  class="size-8 text-slate-400 dark:text-slate-500"
                />
              </div>
              <h2 class="text-lg font-medium text-slate-700 dark:text-slate-300 mb-2">
                No conversations yet
              </h2>
              <p class="text-sm text-slate-500 dark:text-slate-400 max-w-sm mx-auto mb-6">
                Start a conversation with any of your connections.
                Messages are end-to-end encrypted — only you and the recipient can read them.
              </p>
              <.liquid_button
                phx-click="open_new_conversation"
                variant="primary"
                color="teal"
                size="md"
                icon="hero-chat-bubble-left-right"
              >
                Start a Conversation
              </.liquid_button>
            </div>

            <div :if={@conversations != []} id="conversations-list" class="space-y-1">
              <div
                :for={conv <- @conversations}
                id={"conversation-#{conv.user_conversation.conversation_id}"}
                class={[
                  "group/conv flex items-center rounded-2xl",
                  "transition-all duration-200 ease-out",
                  "hover:bg-gradient-to-r hover:from-teal-50/50 hover:via-white/70 hover:to-emerald-50/50",
                  "dark:hover:from-teal-900/20 dark:hover:via-slate-800/50 dark:hover:to-emerald-900/20",
                  "border border-transparent hover:border-teal-200/40 dark:hover:border-teal-700/30",
                  if(unread?(conv),
                    do:
                      "bg-teal-50/30 dark:bg-teal-900/10 border-teal-100/50 dark:border-teal-800/30",
                    else: ""
                  )
                ]}
              >
                <.link
                  navigate={~p"/app/conversations/#{conv.user_conversation.conversation_id}"}
                  class="flex items-center gap-3 p-3 sm:p-4 flex-1 min-w-0"
                >
                  <div class="relative flex-shrink-0">
                    <div class="w-12 h-12 rounded-full overflow-hidden ring-2 ring-offset-2 ring-offset-white dark:ring-offset-slate-900 ring-slate-200/60 dark:ring-slate-700/60 transition-all duration-200 group-hover/conv:ring-teal-300/60 dark:group-hover/conv:ring-teal-600/60">
                      <img
                        src={get_avatar_src(conv, @current_scope)}
                        alt="Avatar"
                        class="w-full h-full object-cover"
                      />
                    </div>
                    <div
                      :if={unread?(conv)}
                      class="absolute -top-0.5 -right-0.5 w-3 h-3 rounded-full bg-gradient-to-r from-teal-500 to-emerald-500 ring-2 ring-white dark:ring-slate-900"
                    />
                  </div>

                  <div class="flex-1 min-w-0">
                    <div class="flex items-center justify-between gap-2">
                      <span class={[
                        "font-semibold text-sm truncate",
                        if(unread?(conv),
                          do: "text-slate-900 dark:text-slate-100",
                          else: "text-slate-700 dark:text-slate-300"
                        )
                      ]}>
                        {get_name(conv, @current_scope)}
                      </span>
                      <span
                        :if={conv.last_message}
                        class="text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap flex-shrink-0"
                      >
                        <.local_time_ago
                          id={"conv-time-#{conv.user_conversation.conversation_id}"}
                          at={conv.last_message.inserted_at}
                        />
                      </span>
                    </div>
                    <div class="flex items-center justify-between gap-2 mt-0.5">
                      <p class={[
                        "text-xs truncate",
                        if(unread?(conv),
                          do: "text-slate-600 dark:text-slate-300 font-medium",
                          else: "text-slate-500 dark:text-slate-400"
                        )
                      ]}>
                        <%= if conv.last_message do %>
                          <span class="inline-flex items-center gap-1">
                            <.phx_icon
                              name="hero-lock-closed"
                              class="w-3 h-3 text-teal-500/60 flex-shrink-0"
                            />
                            <span class="italic">Encrypted message</span>
                          </span>
                        <% else %>
                          <span class="italic text-slate-400 dark:text-slate-500">
                            No messages yet
                          </span>
                        <% end %>
                      </p>
                      <div
                        :if={unread?(conv)}
                        class="flex-shrink-0 size-2.5 rounded-full bg-gradient-to-r from-teal-500 to-emerald-500"
                      />
                    </div>
                  </div>
                </.link>

                <div class={[
                  "flex items-center gap-0.5 pr-2 flex-shrink-0",
                  "opacity-0 group-hover/conv:opacity-100",
                  "translate-x-2 group-hover/conv:translate-x-0",
                  "transition-all duration-200"
                ]}>
                  <button
                    type="button"
                    phx-click="confirm_delete_conversation"
                    phx-value-id={conv.user_conversation.conversation_id}
                    phx-value-name={get_name(conv, @current_scope)}
                    class="p-1.5 rounded-lg text-slate-400 hover:text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20 transition-all duration-200"
                    title="Delete conversation"
                  >
                    <.phx_icon name="hero-trash" class="size-4" />
                  </button>
                  <button
                    type="button"
                    phx-click="block_user_from_conversation"
                    phx-value-id={conv.user_conversation.conversation_id}
                    phx-value-name={get_name(conv, @current_scope)}
                    class="p-1.5 rounded-lg text-slate-400 hover:text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20 transition-all duration-200"
                    title="Block user"
                  >
                    <.phx_icon name="hero-no-symbol" class="size-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </.liquid_container>
      </div>

      <.liquid_modal
        :if={@show_new_conversation_modal}
        id="new-conversation-modal"
        show={@show_new_conversation_modal}
        size="md"
        on_cancel={JS.push("close_new_conversation")}
      >
        <:title>New Conversation</:title>

        <div class="space-y-4">
          <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
            Choose a connection to start an end-to-end encrypted conversation.
          </p>

          <%= if @eligible_connections == [] do %>
            <div class="text-center py-8">
              <div class="flex size-12 items-center justify-center rounded-2xl bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700 mx-auto mb-3">
                <.phx_icon name="hero-users" class="size-6 text-slate-400 dark:text-slate-500" />
              </div>
              <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                No connections available
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400 max-w-xs mx-auto">
                You need confirmed connections to start a conversation.
              </p>
            </div>
          <% else %>
            <div class="max-h-80 overflow-y-auto -mx-1 px-1 space-y-1">
              <button
                :for={conn <- @eligible_connections}
                type="button"
                phx-click="select_connection"
                phx-value-connection-id={conn.connection_id}
                class={[
                  "group w-full flex items-center gap-3 p-3 rounded-xl text-left",
                  "transition-all duration-200 ease-out",
                  "hover:bg-gradient-to-r hover:from-teal-50/60 hover:via-emerald-50/40 hover:to-teal-50/60",
                  "dark:hover:from-teal-900/20 dark:hover:via-emerald-900/15 dark:hover:to-teal-900/20",
                  "border border-transparent hover:border-teal-200/40 dark:hover:border-teal-700/30"
                ]}
              >
                <div class="w-10 h-10 rounded-full overflow-hidden ring-2 ring-offset-1 ring-offset-white dark:ring-offset-slate-800 ring-slate-200/60 dark:ring-slate-700/60 flex-shrink-0 transition-all duration-200 group-hover:ring-teal-300/60 dark:group-hover:ring-teal-600/60">
                  <img src={conn.avatar_src} alt="Avatar" class="w-full h-full object-cover" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate group-hover:text-teal-700 dark:group-hover:text-teal-300 transition-colors duration-200">
                    {conn.name}
                  </p>
                  <p class="text-xs text-slate-500 dark:text-slate-400 truncate">
                    @{conn.username}
                  </p>
                </div>
                <.phx_icon
                  name="hero-chat-bubble-left"
                  class="size-4 text-slate-400 group-hover:text-teal-500 transition-colors duration-200 flex-shrink-0"
                />
              </button>
            </div>
          <% end %>
        </div>
      </.liquid_modal>

      <.liquid_modal
        :if={@show_delete_confirm}
        id="delete-conversation-modal"
        show={@show_delete_confirm}
        size="sm"
        on_cancel={JS.push("cancel_delete_conversation")}
      >
        <:title>
          <div class="flex items-center gap-3">
            <div class="p-2 rounded-xl bg-rose-100 dark:bg-rose-900/30">
              <.phx_icon name="hero-trash" class="size-5 text-rose-600 dark:text-rose-400" />
            </div>
            <span>Delete Conversation</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-sm text-slate-600 dark:text-slate-400">
            Are you sure you want to delete your conversation with <span class="font-semibold text-slate-900 dark:text-slate-100">{@delete_conversation_name}</span>?
            This will permanently remove all messages and cannot be undone.
          </p>
          <div class="flex justify-end gap-3 pt-2">
            <.liquid_button
              type="button"
              variant="ghost"
              color="slate"
              phx-click="cancel_delete_conversation"
            >
              Cancel
            </.liquid_button>
            <.liquid_button
              type="button"
              color="rose"
              icon="hero-trash"
              phx-click="delete_conversation"
              phx-value-id={@delete_conversation_id}
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
        user_name={@blocked_user_name}
        post_id="conversation"
        existing_block={nil}
        default_block_type="full"
        decrypted_reason=""
        block_update?={false}
        target_container="#conversation-index-hook"
      />
    </.layout>
    """
  end

  def mount(params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    conversations = Conversations.list_conversations(current_user)

    if connected?(socket) do
      Conversations.subscribe_to_user(current_user.id)
      Accounts.block_subscribe(current_user)
    end

    socket =
      socket
      |> assign(:page_title, "Conversations")
      |> assign(:conversations, conversations)
      |> assign(:show_new_conversation_modal, false)
      |> assign(:eligible_connections, [])
      |> assign(:show_delete_confirm, false)
      |> assign(:delete_conversation_id, nil)
      |> assign(:delete_conversation_name, nil)
      |> assign(:show_block_modal, false)
      |> assign(:blocked_user_id, nil)
      |> assign(:blocked_user_name, nil)

    socket =
      if connected?(socket) && params["start"] do
        handle_start_param(socket, params["start"])
      else
        socket
      end

    {:ok, socket}
  end

  def handle_event("open_new_conversation", _params, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    connections = Accounts.get_all_confirmed_user_connections(current_user.id)

    existing_connection_ids =
      socket.assigns.conversations
      |> Enum.map(fn conv ->
        case conv.user_connection do
          nil -> nil
          uconn -> uconn.connection_id
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    eligible =
      connections
      |> Enum.reject(fn conn -> MapSet.member?(existing_connection_ids, conn.connection_id) end)
      |> Enum.map(fn conn ->
        %{
          connection_id: conn.connection_id,
          user_connection_id: conn.id,
          reverse_user_id: conn.reverse_user_id,
          name: get_decrypted_connection_name(conn, current_user, key),
          username: get_decrypted_connection_username(conn, current_user, key),
          avatar_src: get_connection_avatar_src(conn, current_user, key),
          other_user_public_key: get_other_user_public_key(conn)
        }
      end)
      |> Enum.sort_by(& &1.name)

    {:noreply,
     socket
     |> assign(:show_new_conversation_modal, true)
     |> assign(:eligible_connections, eligible)}
  end

  def handle_event("close_new_conversation", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_conversation_modal, false)
     |> assign(:eligible_connections, [])}
  end

  def handle_event("select_connection", %{"connection-id" => connection_id}, socket) do
    current_user = socket.assigns.current_scope.user

    conn_data =
      Enum.find(socket.assigns.eligible_connections, fn c -> c.connection_id == connection_id end)

    if conn_data do
      existing = Conversations.get_conversation_for_connection(conn_data.user_connection_id)

      if existing do
        uc = Conversations.get_user_conversation(existing.id, current_user.id)

        {:noreply,
         socket
         |> assign(:show_new_conversation_modal, false)
         |> push_navigate(to: ~p"/app/conversations/#{uc.conversation_id}")}
      else
        {:noreply,
         socket
         |> push_event("start-conversation", %{
           user_connection_id: conn_data.user_connection_id,
           current_user_id: current_user.id,
           current_user_public_key: current_user.key_pair["public"],
           other_user_id: conn_data.reverse_user_id,
           other_user_public_key: conn_data.other_user_public_key
         })}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_conversation", params, socket) do
    %{"user_connection_id" => uc_id, "user_conversations" => uc_attrs_list} = params

    uc_attrs =
      Enum.map(uc_attrs_list, fn attrs ->
        key_binary =
          case Base.decode64(attrs["key"]) do
            {:ok, bin} -> bin
            :error -> attrs["key"]
          end

        %{user_id: attrs["user_id"], key: key_binary}
      end)

    case Conversations.get_or_create_conversation(uc_id, uc_attrs) do
      {:ok, conversation} ->
        {:noreply,
         socket
         |> assign(:show_new_conversation_modal, false)
         |> push_navigate(to: ~p"/app/conversations/#{conversation.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create conversation")}
    end
  end

  def handle_event("confirm_delete_conversation", %{"id" => id, "name" => name}, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_confirm, true)
     |> assign(:delete_conversation_id, id)
     |> assign(:delete_conversation_name, name)}
  end

  def handle_event("cancel_delete_conversation", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_confirm, false)
     |> assign(:delete_conversation_id, nil)
     |> assign(:delete_conversation_name, nil)}
  end

  def handle_event("delete_conversation", %{"id" => id}, socket) do
    conversation = Conversations.get_conversation!(id)
    current_user = socket.assigns.current_scope.user
    uc = Conversations.get_user_conversation(id, current_user.id)

    if uc do
      case Conversations.delete_conversation(conversation) do
        {:ok, _} ->
          conversations = Conversations.list_conversations(current_user)

          {:noreply,
           socket
           |> assign(:conversations, conversations)
           |> assign(:show_delete_confirm, false)
           |> assign(:delete_conversation_id, nil)
           |> assign(:delete_conversation_name, nil)
           |> put_flash(:info, "Conversation deleted")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete conversation")}
      end
    else
      {:noreply, put_flash(socket, :error, "Conversation not found")}
    end
  end

  def handle_event(
        "block_user_from_conversation",
        %{"id" => conversation_id, "name" => name},
        socket
      ) do
    current_user = socket.assigns.current_scope.user
    partner_user_id = get_partner_user_id(conversation_id, current_user.id)

    if partner_user_id do
      {:noreply,
       socket
       |> assign(:show_block_modal, true)
       |> assign(:blocked_user_id, partner_user_id)
       |> assign(:blocked_user_name, name)}
    else
      {:noreply, put_flash(socket, :error, "Could not identify user to block")}
    end
  end

  def handle_event("close_block_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_block_modal, false)
     |> assign(:blocked_user_id, nil)
     |> assign(:blocked_user_name, nil)}
  end

  def handle_info({:submit_block, block_params}, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    blocked_user_id = socket.assigns.blocked_user_id

    blocked_user = Accounts.get_user!(blocked_user_id)

    case Accounts.block_user(current_user, blocked_user, block_params,
           user: current_user,
           key: key
         ) do
      {:ok, _user_block} ->
        conversations = Conversations.list_conversations(current_user)

        {:noreply,
         socket
         |> assign(:conversations, conversations)
         |> assign(:show_block_modal, false)
         |> assign(:blocked_user_id, nil)
         |> assign(:blocked_user_name, nil)
         |> put_flash(:info, "User has been blocked")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to block user")}
    end
  end

  def handle_info({:close_block_modal}, socket) do
    {:noreply,
     socket
     |> assign(:show_block_modal, false)
     |> assign(:blocked_user_id, nil)
     |> assign(:blocked_user_name, nil)}
  end

  def handle_info({:conversation_updated, _}, socket) do
    conversations = Conversations.list_conversations(socket.assigns.current_scope.user)
    {:noreply, assign(socket, :conversations, conversations)}
  end

  def handle_info({event, _block}, socket)
      when event in [:user_blocked, :user_unblocked, :user_block_updated] do
    conversations = Conversations.list_conversations(socket.assigns.current_scope.user)
    {:noreply, assign(socket, :conversations, conversations)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp get_name(conv, scope) do
    case conv.user_connection do
      nil -> "[Unknown]"
      uconn -> get_decrypted_connection_name(uconn, scope.user, scope.key)
    end
  end

  defp get_avatar_src(conv, scope) do
    case conv.user_connection do
      nil -> "/images/logo.svg"
      uconn -> get_connection_avatar_src(uconn, scope.user, scope.key)
    end
  end

  defp unread?(%{last_message: nil}), do: false

  defp unread?(%{user_conversation: uc, last_message: msg}) do
    case uc.last_read_at do
      nil -> true
      last_read -> NaiveDateTime.compare(msg.inserted_at, last_read) == :gt
    end
  end

  defp get_other_user_public_key(conn) do
    user = Accounts.get_user!(conn.reverse_user_id)
    user.key_pair["public"]
  end

  defp get_partner_user_id(conversation_id, current_user_id) do
    conversation = Conversations.get_conversation!(conversation_id)

    conversation.user_conversations
    |> Enum.find(fn uc -> uc.user_id != current_user_id end)
    |> case do
      nil -> nil
      uc -> uc.user_id
    end
  end

  defp handle_start_param(socket, connection_id) do
    current_user = socket.assigns.current_scope.user

    conn =
      Accounts.get_all_confirmed_user_connections(current_user.id)
      |> Enum.find(fn c -> c.connection_id == connection_id end)

    if conn do
      existing = Conversations.get_conversation_for_connection(conn.id)

      if existing do
        uc = Conversations.get_user_conversation(existing.id, current_user.id)

        if uc do
          push_navigate(socket, to: ~p"/app/conversations/#{uc.conversation_id}")
        else
          socket
        end
      else
        push_event(socket, "start-conversation", %{
          user_connection_id: conn.id,
          current_user_id: current_user.id,
          current_user_public_key: current_user.key_pair["public"],
          other_user_id: conn.reverse_user_id,
          other_user_public_key: get_other_user_public_key(conn)
        })
      end
    else
      socket
    end
  end
end
