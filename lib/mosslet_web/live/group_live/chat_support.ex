defmodule MossletWeb.GroupLive.ChatSupport do
  @moduledoc """
  Reusable, route-agnostic chat plumbing for circle (group) message streams.

  Both the personal Circles realm (`MossletWeb.GroupLive.Show`) and the
  org-scoped business dashboard (`MossletWeb.BusinessLive.CircleShow`) embed the
  exact same zero-knowledge chat (`MossletWeb.GroupLive.Group.show/1`). Rather
  than duplicate the ~700 lines of stream-management, message grouping, and
  ZK pre-decryption logic, both LiveViews delegate to the functions here.

  The chat itself is ZK: non-public group message bodies are encrypted/decrypted
  in the browser. Nothing here ever sees a `file_key`, session key, or plaintext
  it shouldn't — the same guarantees as the original `GroupLive.Show`.

  Navigation (where to send a user when they're kicked, when the group is
  deleted, etc.) is realm-specific and stays in the host LiveView; these helpers
  only touch the message stream + counts.
  """

  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView, only: [stream: 3, stream_insert: 3, stream_insert: 4, stream_delete: 3]

  alias Mosslet.GroupMessages
  alias Mosslet.Groups

  import MossletWeb.Helpers,
    only: [
      pre_decrypt_group_message: 5,
      pre_decrypt_group_messages: 5,
      ensure_group_message_author_avatar_cached: 3
    ]

  @grouping_window_minutes 5

  ## Surface variant ---------------------------------------------------------

  @doc """
  Maps a host LiveView's `current_page` to the chat surface variant used for
  tailored mention theming. The mention *mechanics* (token format, persistence,
  notify/mark-read) are identical across surfaces — only presentation differs.

      :family   -> "family"   (warm)
      :business -> "business" (professional)
      _         -> "personal" (brand default)
  """
  def mention_variant(:family), do: "family"
  def mention_variant(:business), do: "business"
  def mention_variant(_), do: "personal"

  ## Initial load -----------------------------------------------------------

  @doc """
  Loads the most recent messages for `socket.assigns.group` into the
  `:messages` stream, with grouping context + ZK pre-decryption. Requires
  `:group`, `:current_user_group`, and `:current_scope` to be assigned.
  """
  def assign_active_group_messages(socket) do
    user_group = socket.assigns.current_user_group
    group = socket.assigns.group
    current_scope = socket.assigns.current_scope

    unread_message_ids =
      if user_group && user_group.confirmed_at do
        GroupMessages.get_unread_mention_message_ids(user_group.id, group.id)
      else
        MapSet.new()
      end

    messages = GroupMessages.last_ten_messages_for(group.id)
    messages_with_context = add_initial_grouping_context(messages, unread_message_ids)

    # Warm each message author's avatar into the node-global ETS cache so the ZK
    # DecryptAvatar hook can render them without a hard refresh on a cold cache.
    # Self-authored / avatar-less / unconnected authors short-circuit; each cold
    # fetch re-streams just that message via {"get_user_avatar", :group_message, id}.
    if Phoenix.LiveView.connected?(socket) and user_group do
      Enum.each(
        messages,
        &ensure_group_message_author_avatar_cached(&1, current_scope.user, current_scope.key)
      )
    end

    pre_decrypted =
      if user_group do
        pre_decrypt_group_messages(
          messages_with_context,
          group,
          user_group,
          current_scope.user,
          current_scope.key
        )
      else
        messages_with_context
      end

    if Enum.empty?(messages) do
      socket
      |> assign(:messages_list, messages)
      |> assign(:total_messages_count, 0)
      |> assign(:last_message_info, nil)
      |> stream(:messages, pre_decrypted)
      |> assign(:oldest_message_id, nil)
    else
      last_message = List.last(messages)

      socket
      |> assign(:messages_list, messages)
      |> assign(:total_messages_count, GroupMessages.get_message_count_for_group(group.id))
      |> assign(:last_message_info, extract_message_info(last_message))
      |> stream(:messages, pre_decrypted)
      |> assign(:oldest_message_id, List.first(messages).id)
    end
  end

  @doc """
  Assigns `:message` — the current user's most recent message in the group, used
  to seed edit-form state. Accepts an optional `message` to short-circuit.
  """
  def assign_last_user_message(%{assigns: %{current_scope: current_scope}} = socket, message)
      when current_scope.user.id == message.sender_id do
    assign(socket, :message, message)
  end

  def assign_last_user_message(socket, _message), do: socket

  def assign_last_user_message(%{assigns: %{group: nil}} = socket) do
    assign(socket, :message, %Groups.GroupMessage{})
  end

  def assign_last_user_message(%{assigns: %{group: group, current_scope: current_scope}} = socket) do
    assign(socket, :message, get_last_user_message_for_group(group.id, current_scope.user.id))
  end

  def get_last_user_message_for_group(group_id, current_user_id) do
    GroupMessages.last_user_message_for_group(group_id, current_user_id) || %Groups.GroupMessage{}
  end

  def assign_scrolled_to_top(socket, scrolled_to_top \\ "false") do
    assign(socket, :scrolled_to_top, scrolled_to_top)
  end

  def assign_oldest_message_id(socket, nil), do: assign(socket, :oldest_message_id, nil)

  def assign_oldest_message_id(socket, message),
    do: assign(socket, :oldest_message_id, message.id)

  ## Chat events -------------------------------------------------------------

  @doc """
  Handles the chat-related `handle_event/3` messages shared by both realms.
  Returns `{:halt, socket}` if it handled the event, or `:cont` if the host
  LiveView should handle it itself.
  """
  def handle_chat_event("load_more", _params, socket) do
    {:halt, load_more(socket)}
  end

  def handle_chat_event("unpin_scrollbar_from_top", _params, socket) do
    {:halt, assign_scrolled_to_top(socket, "false")}
  end

  def handle_chat_event("mark_mention_read", %{"message_id" => message_id}, socket) do
    GroupMessages.mark_single_mention_as_read(message_id, socket.assigns.current_user_group.id)
    {:halt, socket}
  end

  def handle_chat_event("delete_message", %{"id" => message_id}, socket) do
    message = GroupMessages.get_message!(message_id)
    GroupMessages.delete_message(message)
    # Stream removal + count happens on the broadcast.
    {:halt, socket}
  end

  def handle_chat_event(_event, _params, _socket), do: :cont

  defp load_more(socket) do
    oldest_message_id = socket.assigns.oldest_message_id

    messages =
      case oldest_message_id && GroupMessages.get_message!(oldest_message_id) do
        nil ->
          GroupMessages.get_previous_n_messages(nil, socket.assigns.group.id, 5)

        oldest ->
          GroupMessages.get_previous_n_messages(oldest.inserted_at, socket.assigns.group.id, 5)
      end

    current_scope = socket.assigns.current_scope

    Enum.each(
      messages,
      &ensure_group_message_author_avatar_cached(&1, current_scope.user, current_scope.key)
    )

    socket
    |> stream_batch_insert(:messages, pre_decrypt_messages(messages, socket), at: 0)
    |> assign_oldest_message_id(List.first(messages))
    |> assign_scrolled_to_top("true")
  end

  ## Chat broadcasts ---------------------------------------------------------

  @doc """
  Handles the chat-related `handle_info/2` PubSub broadcasts shared by both
  realms. Returns `{:halt, socket}` if handled, or `:cont` otherwise.
  """
  def handle_chat_info(%{event: "new_message", payload: %{message: message}}, socket) do
    socket =
      if message.sender_id == socket.assigns.current_user_group.id do
        message_with_context = add_grouping_context(message, socket)

        socket
        |> stream_insert(:messages, pre_decrypt_message(message_with_context, socket))
        |> assign(:last_message_info, extract_message_info(message))
        |> assign_last_user_message(message)
      else
        ensure_group_message_author_avatar_cached(
          message,
          socket.assigns.current_scope.user,
          socket.assigns.current_scope.key
        )

        socket
        |> insert_new_message(message, is_new: true)
        |> assign(:last_message_info, extract_message_info(message))
        |> assign_last_user_message(message)
      end

    {:halt, socket}
  end

  def handle_chat_info(%{event: "updated_message", payload: %{message: message}}, socket) do
    socket =
      socket
      |> insert_updated_message(message)
      |> assign_last_user_message(message)

    {:halt, socket}
  end

  def handle_chat_info(%{event: "deleted_message", payload: %{message: message}}, socket) do
    {:halt, handle_message_deletion(socket, message)}
  end

  def handle_chat_info({:message_sent, _message}, socket) do
    {:halt, update(socket, :total_messages_count, &(&1 + 1))}
  end

  # A cold message-author avatar finished caching in ETS (Task #342) — re-stream
  # just that message so it re-renders with the now-available encrypted blob.
  def handle_chat_info({_ref, {"get_user_avatar", :group_message, message_id}}, socket) do
    {:halt, restream_message_for_avatar(socket, message_id)}
  end

  def handle_chat_info(_msg, _socket), do: :cont

  ## Stream helpers ----------------------------------------------------------

  def insert_new_message(socket, message, opts \\ []) do
    is_new = Keyword.get(opts, :is_new, false)
    message_with_context = add_grouping_context(message, socket, is_new: is_new)

    socket
    |> stream_insert(:messages, pre_decrypt_message(message_with_context, socket))
    |> update(:total_messages_count, &(&1 + 1))
  end

  def insert_updated_message(socket, message) do
    preloaded = GroupMessages.preload_message_sender(message)
    stream_insert(socket, :messages, pre_decrypt_message(preloaded, socket), at: -1)
  end

  @doc """
  A cold message-author avatar finished caching in ETS (Task #342) — re-stream
  JUST that message so it re-renders with the now-available encrypted blob.

  Grouping context (is_grouped / date separator) and unread-mention state are
  recomputed deterministically from the message's actual predecessor and the
  live unread set — mirroring the initial-load logic — so position, ordering,
  and the unread highlight are preserved. Uses `update_only: true` so a message
  that scrolled out of the client window is never re-inserted.
  """
  def restream_message_for_avatar(socket, message_id) do
    group = socket.assigns.group
    user_group = socket.assigns.current_user_group

    case safe_get_message(message_id) do
      nil ->
        socket

      message ->
        message = GroupMessages.preload_message_sender(message)

        prev_message =
          case GroupMessages.get_previous_n_messages(message.inserted_at, group.id, 1) do
            [prev | _] -> prev
            _ -> nil
          end

        unread_ids =
          if user_group && user_group.confirmed_at do
            GroupMessages.get_unread_mention_message_ids(user_group.id, group.id)
          else
            MapSet.new()
          end

        message_with_context = put_single_grouping_context(message, prev_message, unread_ids)

        stream_insert(
          socket,
          :messages,
          pre_decrypt_message(message_with_context, socket),
          update_only: true
        )
    end
  end

  defp safe_get_message(message_id) do
    GroupMessages.get_message!(message_id)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp stream_batch_insert(socket, name, items, opts) do
    Enum.reduce(items, socket, fn item, acc -> stream_insert(acc, name, item, opts) end)
  end

  defp handle_message_deletion(socket, deleted_message) do
    next_message = GroupMessages.get_next_message_after(deleted_message)
    prev_message = GroupMessages.get_previous_message_before(deleted_message)

    socket
    |> stream_delete(:messages, deleted_message)
    |> update(:total_messages_count, &max(&1 - 1, 0))
    |> maybe_update_next_message_grouping(next_message, prev_message, deleted_message)
    |> assign_last_user_message(deleted_message)
    |> update_last_message_info_after_deletion(deleted_message)
  end

  defp update_last_message_info_after_deletion(socket, deleted_message) do
    last_info = socket.assigns[:last_message_info]

    if last_info && last_info.sender_id == deleted_message.sender_id &&
         last_info.inserted_at == deleted_message.inserted_at do
      last_message = GroupMessages.get_last_message_for_group(socket.assigns.group.id)

      if last_message do
        assign(socket, :last_message_info, extract_message_info(last_message))
      else
        assign(socket, :last_message_info, nil)
      end
    else
      socket
    end
  end

  defp maybe_update_next_message_grouping(socket, nil, _prev_message, _deleted_message),
    do: socket

  defp maybe_update_next_message_grouping(socket, next_message, prev_message, deleted_message) do
    next_date = get_message_date(next_message.inserted_at)

    {new_is_grouped, new_show_date_separator} =
      if prev_message do
        prev_date = get_message_date(prev_message.inserted_at)
        same_sender = prev_message.sender_id == next_message.sender_id
        same_date = prev_date == next_date

        within_window =
          within_grouping_window?(prev_message.inserted_at, next_message.inserted_at)

        {same_sender && same_date && within_window, !same_date}
      else
        {false, true}
      end

    was_grouped_with_deleted =
      deleted_message.sender_id == next_message.sender_id &&
        get_message_date(deleted_message.inserted_at) == next_date &&
        within_grouping_window?(deleted_message.inserted_at, next_message.inserted_at)

    if was_grouped_with_deleted do
      updated_next =
        next_message
        |> Map.put(:is_grouped, new_is_grouped)
        |> Map.put(:show_date_separator, new_show_date_separator)
        |> Map.put(:message_date, next_date)

      stream_insert(socket, :messages, updated_next, at: -1)
    else
      socket
    end
  end

  ## Pre-decrypt + grouping context -----------------------------------------

  def pre_decrypt_message(message, socket) do
    group = socket.assigns.group
    user_group = socket.assigns.current_user_group
    current_scope = socket.assigns.current_scope

    if user_group do
      pre_decrypt_group_message(message, group, user_group, current_scope.user, current_scope.key)
    else
      message
    end
  end

  def pre_decrypt_messages(messages, socket) do
    Enum.map(messages, &pre_decrypt_message(&1, socket))
  end

  def add_grouping_context(message, socket, opts \\ []) do
    message = GroupMessages.preload_message_sender(message)
    last_info = Map.get(socket.assigns, :last_message_info)
    is_new = Keyword.get(opts, :is_new, false)
    current_user_group = socket.assigns.current_user_group

    message_date = get_message_date(message.inserted_at)

    {is_grouped, show_date_separator} =
      if last_info do
        same_sender = last_info.sender_id == message.sender_id
        same_date = last_info.date == message_date
        within_window = within_grouping_window?(last_info.inserted_at, message.inserted_at)

        {same_sender && same_date && within_window, !same_date}
      else
        {false, true}
      end

    # A realtime mention highlight fires only for freshly-arrived messages that
    # mention the current user. Detection is server-authoritative via the
    # persisted mention records (ZK-safe) — see GroupMessages.message_mentions_user_group?/2.
    is_new_mention =
      is_new && current_user_group != nil &&
        GroupMessages.message_mentions_user_group?(message.id, current_user_group.id)

    message
    |> Map.put(:is_grouped, is_grouped)
    |> Map.put(:show_date_separator, show_date_separator)
    |> Map.put(:message_date, message_date)
    |> Map.put(:is_new_message, is_new)
    |> Map.put(:is_new_mention, is_new_mention)
  end

  def extract_message_info(message) do
    %{
      sender_id: message.sender_id,
      inserted_at: message.inserted_at,
      date: get_message_date(message.inserted_at)
    }
  end

  defp add_initial_grouping_context(messages, unread_message_ids) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {message, index} ->
      prev_message = if index > 0, do: Enum.at(messages, index - 1)
      put_single_grouping_context(message, prev_message, unread_message_ids)
    end)
  end

  # Computes a single message's grouping + unread context relative to its
  # predecessor. Shared by the initial load and the avatar re-stream (Task #342)
  # so both paths produce identical is_grouped / date-separator / unread flags.
  defp put_single_grouping_context(message, prev_message, unread_message_ids) do
    message_date = get_message_date(message.inserted_at)

    {is_grouped, show_date_separator} =
      if prev_message do
        prev_date = get_message_date(prev_message.inserted_at)
        same_sender = prev_message.sender_id == message.sender_id
        same_date = prev_date == message_date
        within_window = within_grouping_window?(prev_message.inserted_at, message.inserted_at)

        {same_sender && same_date && within_window, !same_date}
      else
        {false, true}
      end

    message
    |> Map.put(:is_grouped, is_grouped)
    |> Map.put(:show_date_separator, show_date_separator)
    |> Map.put(:message_date, message_date)
    |> Map.put(:is_new_message, MapSet.member?(unread_message_ids, message.id))
    |> Map.put(:is_new_mention, MapSet.member?(unread_message_ids, message.id))
  end

  defp get_message_date(datetime) when is_struct(datetime, NaiveDateTime),
    do: NaiveDateTime.to_date(datetime)

  defp get_message_date(datetime) when is_struct(datetime, DateTime),
    do: DateTime.to_date(datetime)

  defp get_message_date(_), do: nil

  defp within_grouping_window?(prev_time, curr_time) do
    NaiveDateTime.diff(curr_time, prev_time, :minute) <= @grouping_window_minutes
  end
end
