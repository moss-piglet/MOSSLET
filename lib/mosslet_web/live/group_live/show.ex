defmodule MossletWeb.GroupLive.Show do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.GroupMessages
  alias MossletWeb.GroupLive.{Group, GroupMessage.EditForm}
  alias Mosslet.Memories
  alias Mosslet.Timeline
  alias Mosslet.Timeline.Reply

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(
        socket,
        :user_connections,
        decrypt_user_connections(
          Accounts.get_all_confirmed_user_connections(socket.assigns.current_user.id),
          socket.assigns.current_user,
          socket.assigns.key
        )
      )

    {:ok,
     socket
     |> assign(:slide_over, false)
     |> assign(:slide_over_content, "")
     |> assign_active_group()
     |> assign_scrolled_to_top()
     |> assign_last_user_message(), layout: {MossletWeb.Layouts, :app}}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    current_user = socket.assigns.current_user
    group = Groups.get_group(id)

    if connected?(socket) do
      Accounts.subscribe_account_deleted()
      Groups.private_subscribe(current_user)
      Groups.public_subscribe()
      Groups.group_subscribe(group)
    end

    # if the group is deleted we redirect everyone currently viewing it.
    if is_nil(group) do
      {:noreply,
       socket
       |> put_flash(:info, "This group has been deleted.")
       |> push_navigate(to: ~p"/app/groups")}
    else
      user_group = get_user_group(group, current_user)

      {:noreply,
       socket
       |> assign(:group, group)
       |> assign(:current_user_group, user_group)
       |> assign(:page_title, page_title(socket.assigns.live_action))
       |> stream(:user_groups, Groups.list_user_groups(group))
       |> assign_active_group_messages()
       |> assign_last_user_message()
       |> apply_action(socket.assigns.live_action, params)}
    end
  end

  defp apply_action(socket, :show, _params) do
    if not is_nil(socket.assigns.current_user_group) &&
         socket.assigns.current_user_group.confirmed_at do
      socket
      |> assign(page_title: "Show Group")
    else
      socket
      |> put_flash(:info, "You don't have permission to view this group or it does not exist.")
      |> push_navigate(to: ~p"/app/groups")
    end
  end

  defp apply_action(socket, :edit, _params) do
    if can_edit_group?(
         socket.assigns.current_user_group,
         socket.assigns.current_user
       ) do
      socket
      |> assign(:page_title, "Edit Group")
    else
      socket
      |> put_flash(:info, "You do not have permission to edit this group.")
      |> push_patch(to: ~p"/app/groups")
    end
  end

  @impl true
  def handle_info(%{event: "new_message", payload: %{message: message}}, socket) do
    # Check if this message is from the current user to avoid double counting
    if message.sender_id == socket.assigns.current_user_group.id do
      # For own messages: add to stream but don't increment (already counted locally)
      {:noreply,
       socket
       |> stream_insert(:messages, GroupMessages.preload_message_sender(message))
       |> assign_last_user_message(message)}
    else
      # For others' messages: add to stream and increment count
      {:noreply,
       socket
       |> insert_new_message(message)
       |> assign_last_user_message(message)}
    end
  end

  @impl true
  def handle_info(%{event: "updated_message", payload: %{message: message}}, socket) do
    # For message updates, don't increment count - just update the stream
    {:noreply,
     socket
     |> insert_updated_message(message)
     |> assign_last_user_message(message)}
  end

  @impl true
  def handle_info(%{event: "deleted_message", payload: %{message: message}}, socket) do
    # Someone else's message - remove from stream AND decrement count
    {:noreply,
     socket
     |> stream_delete(:messages, message)
     |> update(:total_messages_count, &max(&1 - 1, 0))
     |> assign_last_user_message(message)}
  end

  @impl true
  def handle_info({MossletWeb.GroupLive.FormComponent, {:saved, group}}, socket) do
    {:noreply, assign(socket, :group, group)}
  end

  @impl true
  def handle_info({MossletWeb.GroupLive.Show, {:deleted, post}}, socket) do
    if post.user_id == socket.assigns.current_user.id do
      {:noreply, stream_delete(socket, :posts, post)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_updated, group}, socket) do
    {:noreply, assign(socket, :group, group)}
  end

  @impl true
  def handle_info({:user_group_deleted, user_group}, socket) do
    if user_group.user_id != socket.assigns.current_user.id do
      {:noreply, push_navigate(socket, to: ~p"/app/groups/#{user_group.group_id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_updated_member, group}, socket) do
    {:noreply, assign(socket, :group, group) |> push_patch(to: ~p"/app/groups/#{group}")}
  end

  @impl true
  def handle_info({:account_deleted, _user}, socket) do
    {:noreply, socket |> push_patch(to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({:group_deleted, _group}, socket) do
    {:noreply, socket |> push_patch(to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({:message_sent, _message}, socket) do
    # Local increment for own messages
    {:noreply,
     socket
     |> update(:total_messages_count, &(&1 + 1))}
  end

  @impl true
  def handle_info({:groups_deleted, _struct}, socket) do
    {:noreply, socket |> push_patch(to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    oldest_message_id = socket.assigns.oldest_message_id

    if not is_nil(oldest_message_id) do
      case Mosslet.GroupMessages.get_message!(oldest_message_id) do
        nil ->
          # Message was deleted, reset to load from beginning
          messages = GroupMessages.get_previous_n_messages(nil, socket.assigns.group.id, 5)

          {:noreply,
           socket
           |> stream_batch_insert(:messages, messages, at: 0)
           |> assign_oldest_message_id(List.first(messages))
           |> assign_scrolled_to_top("true")}

        oldest_message ->
          messages =
            GroupMessages.get_previous_n_messages(
              oldest_message.inserted_at,
              socket.assigns.group.id,
              5
            )

          {:noreply,
           socket
           |> stream_batch_insert(:messages, messages, at: 0)
           |> assign_oldest_message_id(List.first(messages))
           |> assign_scrolled_to_top("true")}
      end
    else
      messages = GroupMessages.get_previous_n_messages(nil, socket.assigns.group.id, 5)

      {:noreply,
       socket
       |> stream_batch_insert(:messages, messages, at: 0)
       |> assign_oldest_message_id(List.first(messages))
       |> assign_scrolled_to_top("true")}
    end
  end

  @impl true
  def handle_event("unpin_scrollbar_from_top", _params, socket) do
    {:noreply,
     socket
     |> assign_scrolled_to_top("false")}
  end

  @impl true
  def handle_event("delete_message", %{"item_id" => message_id}, socket) do
    {:noreply, delete_message(socket, message_id)}
  end

  @impl true
  def handle_event("leave_group", %{"id" => id}, socket) do
    user_group = Groups.get_user_group!(id)

    if can_delete_user_group?(user_group, socket.assigns.current_user) do
      case Groups.delete_user_group(user_group) do
        {:ok, _user_group} ->
          {:noreply,
           socket
           |> clear_flash(:success)
           |> put_flash(
             :success,
             "You have succesfully left the group."
           )
           |> push_navigate(to: ~p"/app/groups")}

        {:error, message} ->
          {:noreply,
           socket
           |> put_flash(:warning, message)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:warning, "You do not have permission to do this.")
       |> push_navigate(to: ~p"/app/groups")}
    end
  end

  @impl true
  def handle_event("blur-memory", %{"id" => id}, socket) do
    memory = Memories.get_memory!(id)
    user = socket.assigns.current_user

    {:ok, memory} =
      Memories.blur_memory(
        memory,
        %{
          "shared_users" =>
            Enum.into(memory.shared_users, [], fn shared_user ->
              if shared_user.user_id == user.id,
                do: put_in(shared_user.blur, blur_shared_user(shared_user))

              put_in(shared_user.current_user_id, user.id)
              Map.from_struct(shared_user)
            end)
        },
        user,
        blur: true
      )

    {:noreply, stream_insert(socket, :memories, memory, at: -1)}
  end

  def handle_event("fav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user

    if user.id not in post.favs_list do
      {:ok, post} = Timeline.inc_favs(post)

      Timeline.update_post_fav(post, %{favs_list: List.insert_at(post.favs_list, 0, user.id)},
        user: user
      )

      {:noreply, push_patch(socket, to: socket.assigns.return_post_url)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("unfav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user

    if user.id in post.favs_list do
      {:ok, post} = Timeline.decr_favs(post)

      Timeline.update_post_fav(post, %{favs_list: List.delete(post.favs_list, user.id)},
        user: user
      )

      {:noreply, push_patch(socket, to: socket.assigns.return_post_url)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reply", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user
    group = socket.assigns.group

    if current_user do
      {:noreply,
       socket
       |> assign(:live_action, :reply)
       |> assign(:current_post, post)
       |> assign(:reply, %Reply{})
       |> push_patch(to: "/app/groups/#{group.id}/posts/#{post.id}/reply")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit-reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    post = Timeline.get_post!(reply.post_id)
    current_user = socket.assigns.current_user

    if current_user do
      {:noreply,
       socket
       |> assign(:live_action, :reply_edit)
       |> assign(:post, post)
       |> assign(:reply, reply)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_group", %{"id" => id}, socket) do
    group = Groups.get_group!(id)

    current_user = socket.assigns.current_user

    if can_delete_group?(group, current_user) do
      case Groups.delete_group(group) do
        {:ok, _group} ->
          {:noreply,
           socket
           |> put_flash(:success, "Group deleted successfully.")
           |> push_navigate(to: ~p"/app/groups")}

        {:error, message} ->
          {:noreply,
           socket
           |> put_flash(:warning, message)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:warning, "You do not have permission to delete this group.")
       |> push_navigate(to: ~p"/app/groups")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user
    group = socket.assigns.group

    user_group = Groups.get_user_group_for_group_and_user(group, user)

    if post.user_id == user.id || user_group.role in [:admin, :moderator, :owner] do
      {:ok, post} = Timeline.delete_post(post, user: user)
      notify_self({:deleted, post})

      socket = put_flash(socket, :success, "Post deleted successfully.")
      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :warning, "You do not have permission.")}
    end
  end

  @impl true
  def handle_event("delete-reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    user = socket.assigns.current_user

    # The creator of the post can delete any replies for it.
    # this gives them the ability to moderate replies to their posts
    if user && (user.id == reply.user_id || user.id == reply.post.user_id) do
      case Timeline.delete_reply(reply, user: user) do
        {:ok, reply} ->
          notify_self({:deleted, reply})

          {:noreply,
           put_flash(socket, :success, "Reply deleted successfully.")
           |> push_patch(to: socket.assigns.return_post_url)}

        {:error, message} ->
          {:noreply, put_flash(socket, :warning, message)}
      end
    else
      {:noreply,
       put_flash(socket, :warning, "You do not have permission to perform this action.")}
    end
  end

  @impl true
  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user
    current_user_group = socket.assigns.current_user_group

    if post.user_id == user.id || current_user_group.role in [:owner, :admin, :moderator] do
      {:ok, post} = Timeline.delete_group_post(post, user: user, user_group: current_user_group)
      notify_self({:deleted, post})

      socket = put_flash(socket, :success, "Post deleted successfully.")
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp blur_shared_user(shared_user) do
    if shared_user.blur do
      false
    else
      true
    end
  end

  def insert_new_message(socket, message) do
    socket
    |> stream_insert(:messages, GroupMessages.preload_message_sender(message))
    |> update(:total_messages_count, &(&1 + 1))
  end

  def insert_updated_message(socket, message) do
    # For updated messages, don't change the count - just update the stream
    socket
    |> stream_insert(:messages, GroupMessages.preload_message_sender(message), at: -1)
  end

  def insert_deleted_message(socket, message) do
    socket
    |> stream_delete(:messages, message)
    |> update(:total_messages_count, &max(&1 - 1, 0))
  end

  def assign_active_group_messages(socket) do
    messages = GroupMessages.last_ten_messages_for(socket.assigns.group.id)
    messages_list = Enum.with_index(messages, fn element, index -> {index, element} end)

    if Enum.empty?(messages) do
      socket
      |> assign(:messages_list, messages_list)
      |> assign(:total_messages_count, 0)
      |> stream(:messages, messages)
      |> assign(:oldest_message_id, nil)
    else
      socket
      |> assign(:messages_list, messages_list)
      |> assign(
        :total_messages_count,
        GroupMessages.get_message_count_for_group(socket.assigns.group.id)
      )
      |> stream(:messages, messages)
      |> assign(:oldest_message_id, List.first(messages).id)
    end
  end

  def assign_active_group(socket) do
    assign(socket, :group, nil)
  end

  def assign_scrolled_to_top(socket, scrolled_to_top \\ "false") do
    assign(socket, :scrolled_to_top, scrolled_to_top)
  end

  def assign_oldest_message_id(socket, message) do
    if is_nil(message) do
      assign(socket, :oldest_message_id, message)
    else
      assign(socket, :oldest_message_id, message.id)
    end
  end

  def assign_is_editing_message(socket, is_editing \\ nil) do
    assign(socket, :is_editing_message, is_editing)
  end

  def assign_last_user_message(%{assigns: %{current_user: current_user}} = socket, message)
      when current_user.id == message.sender_id do
    assign(socket, :message, message)
  end

  def assign_last_user_message(socket, _message) do
    socket
  end

  def assign_last_user_message(%{assigns: %{group: nil}} = socket) do
    assign(socket, :message, %Groups.GroupMessage{})
  end

  def assign_last_user_message(%{assigns: %{group: group, current_user: current_user}} = socket) do
    assign(socket, :message, get_last_user_message_for_group(group.id, current_user.id))
  end

  def delete_message(socket, message_id) do
    message = GroupMessages.get_message!(message_id)
    GroupMessages.delete_message(message)
    # Don't delete from stream or update count here - wait for broadcast
    socket
  end

  def get_last_user_message_for_group(group_id, current_user_id) do
    GroupMessages.last_user_message_for_group(group_id, current_user_id) || %Groups.GroupMessage{}
  end

  defp page_title(:show), do: "Show Group"
  defp page_title(:edit), do: "Edit Group"
  defp page_title(:slide_over), do: "Show Group"
  defp page_title(:posts), do: "Show Group Posts"
  defp page_title(:memories), do: "Show Group Memories"
  defp page_title(:reply), do: "Show Group Post"

  defp notify_self(msg), do: send(self(), {__MODULE__, msg})
end
