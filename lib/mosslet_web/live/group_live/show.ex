defmodule MossletWeb.GroupLive.Show do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.GroupMessages
  alias MossletWeb.GroupLive.{Group, GroupMessage.EditForm}
  alias MossletWeb.GroupLive.ChatSupport
  alias Mosslet.Timeline
  alias Mosslet.Timeline.Reply

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    if connected?(socket) do
      Accounts.subscribe_account_deleted()
      Groups.private_subscribe(current_scope.user)
      Groups.public_subscribe()
      Groups.group_subscribe(Groups.get_group(id))
    end

    socket =
      assign(
        socket,
        :user_connections,
        decrypt_user_connections(
          Accounts.get_all_confirmed_user_connections(current_scope.user.id),
          current_scope.user,
          current_scope.key
        )
      )

    {:ok,
     socket
     |> assign(:slide_over, false)
     |> assign(:slide_over_content, "")
     |> assign(:current_page, :circles)
     |> assign(:show_markdown_guide, false)
     |> assign_active_group()
     |> ChatSupport.assign_scrolled_to_top()
     |> ChatSupport.assign_last_user_message(), layout: {MossletWeb.Layouts, :app}}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _uri, socket) do
    current_scope = socket.assigns.current_scope
    group = Groups.get_group(id)

    # if the group is deleted we redirect everyone currently viewing it.
    if is_nil(group) do
      {:noreply,
       socket
       |> put_flash(:info, "This circle cannot be viewed or no longer exists.")
       |> push_navigate(to: ~p"/app/circles")}
    else
      maybe_redirect_org_circle(group, socket) || show_personal_circle(group, params, socket)
    end
  end

  # Org (business/family) circles live in the org dashboard, NOT the personal
  # Circles realm (Task #221 — "the org dashboard is the complete operating
  # surface"). If someone lands here for an org circle (e.g. an old link), send
  # them to the org-scoped route. Returns nil for personal circles.
  defp maybe_redirect_org_circle(%{org_id: org_id} = group, socket) when not is_nil(org_id) do
    case Mosslet.Orgs.get_org_by_id(org_id) do
      %{type: :business, slug: slug} ->
        {:noreply, push_navigate(socket, to: ~p"/app/business/#{slug}/circles/#{group.id}")}

      %{slug: slug} ->
        # Family (and any future org type) — keep them in the org realm.
        {:noreply, push_navigate(socket, to: ~p"/app/family/#{slug}")}

      _ ->
        nil
    end
  end

  defp maybe_redirect_org_circle(_group, _socket), do: nil

  defp show_personal_circle(group, params, socket) do
    current_scope = socket.assigns.current_scope
    user_group = get_user_group(group, current_scope.user)

    {:noreply,
     socket
     |> assign(:group, group)
     |> assign(:current_user_group, user_group)
     |> assign(
       :group_metadata,
       pre_decrypt_group_metadata(group, user_group, current_scope.user, current_scope.key)
     )
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> stream(:user_groups, Groups.list_user_groups(group))
     |> ChatSupport.assign_active_group_messages()
     |> ChatSupport.assign_last_user_message()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    if not is_nil(socket.assigns.current_user_group) &&
         socket.assigns.current_user_group.confirmed_at do
      GroupMessages.mark_mentions_as_read(
        socket.assigns.current_user_group.id,
        socket.assigns.group.id
      )

      socket
      |> assign(page_title: "Viewing Circle")
    else
      socket
      |> put_flash(:info, "You don't have permission to view this circle or it does not exist.")
      |> push_navigate(to: ~p"/app/circles")
    end
  end

  defp apply_action(socket, :edit, _params) do
    if can_edit_group?(
         socket.assigns.current_user_group,
         socket.assigns.current_scope.user
       ) do
      socket
      |> assign(:page_title, "Edit Circle")
    else
      socket
      |> put_flash(:info, "You do not have permission to edit this circle.")
      |> push_patch(to: ~p"/app/circles")
    end
  end

  @impl true
  def handle_info(%{event: "new_message"} = msg, socket) do
    {:halt, socket} = ChatSupport.handle_chat_info(msg, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "updated_message"} = msg, socket) do
    {:halt, socket} = ChatSupport.handle_chat_info(msg, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "deleted_message"} = msg, socket) do
    {:halt, socket} = ChatSupport.handle_chat_info(msg, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({MossletWeb.GroupLive.FormComponent, {:saved, group}}, socket) do
    {:noreply, assign(socket, :group, group)}
  end

  @impl true
  def handle_info({MossletWeb.GroupLive.Show, {:deleted, post}}, socket) do
    if post.user_id == socket.assigns.current_scope.user.id do
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
    if user_group.user_id != socket.assigns.current_scope.user.id do
      {:noreply, push_navigate(socket, to: ~p"/app/circles/#{user_group.group_id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_updated_member, group}, socket) do
    {:noreply, assign(socket, :group, group) |> push_patch(to: ~p"/app/circles/#{group}")}
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
  def handle_info({:message_sent, _message} = msg, socket) do
    {:halt, socket} = ChatSupport.handle_chat_info(msg, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:groups_deleted, _struct}, socket) do
    {:noreply, socket |> push_patch(to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({:group_joined, group}, socket) do
    if group.id == socket.assigns.group.id do
      {:noreply, assign(socket, :group, group)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_kicked, {group, kicked_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      if kicked_user_id == socket.assigns.current_scope.user.id do
        {:noreply,
         socket
         |> put_flash(:info, "You have been removed from this circle.")
         |> push_navigate(to: ~p"/app/circles")}
      else
        {:noreply, assign(socket, :group, group)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_blocked, {group, blocked_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      if blocked_user_id == socket.assigns.current_scope.user.id do
        {:noreply,
         socket
         |> put_flash(:info, "You have been removed from this circle.")
         |> push_navigate(to: ~p"/app/circles")}
      else
        blocked_users = Groups.list_blocked_users(group.id)

        {:noreply,
         socket
         |> assign(:group, group)
         |> assign(:blocked_users, blocked_users)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_unblocked, {group, _target_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      blocked_users = Groups.list_blocked_users(group.id)

      {:noreply,
       socket
       |> assign(:group, group)
       |> assign(:blocked_users, blocked_users)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more", params, socket) do
    {:halt, socket} = ChatSupport.handle_chat_event("load_more", params, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("unpin_scrollbar_from_top", params, socket) do
    {:halt, socket} = ChatSupport.handle_chat_event("unpin_scrollbar_from_top", params, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, true)}
  end

  @impl true
  def handle_event("close_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, false)}
  end

  @impl true
  def handle_event("mark_mention_read", params, socket) do
    {:halt, socket} = ChatSupport.handle_chat_event("mark_mention_read", params, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_message", params, socket) do
    {:halt, socket} = ChatSupport.handle_chat_event("delete_message", params, socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_group", %{"id" => id}, socket) do
    user_group = Groups.get_user_group!(id)

    if can_delete_user_group?(user_group, socket.assigns.current_scope.user) do
      case Groups.delete_user_group(user_group) do
        {:ok, _user_group} ->
          {:noreply,
           socket
           |> clear_flash(:success)
           |> put_flash(
             :success,
             "You have succesfully left the circle."
           )
           |> push_navigate(to: ~p"/app/circles")}

        {:error, message} ->
          {:noreply,
           socket
           |> put_flash(:warning, message)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:warning, "You do not have permission to do this.")
       |> push_navigate(to: ~p"/app/circles")}
    end
  end

  @impl true
  def handle_event("fav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_scope = socket.assigns.current_scope

    if current_scope.user.id not in post.favs_list do
      {:ok, post} = Timeline.inc_favs(post)

      Timeline.update_post_fav(
        post,
        %{favs_list: List.insert_at(post.favs_list, 0, current_scope.user.id)},
        user: current_scope.user
      )

      {:noreply, push_patch(socket, to: socket.assigns.return_post_url)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("unfav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_scope = socket.assigns.current_scope

    if current_scope.user.id in post.favs_list do
      {:ok, post} = Timeline.decr_favs(post)

      Timeline.update_post_fav(
        post,
        %{favs_list: List.delete(post.favs_list, current_scope.user.id)},
        user: current_scope.user
      )

      {:noreply, push_patch(socket, to: socket.assigns.return_post_url)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reply", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_scope = socket.assigns.current_scope
    group = socket.assigns.group

    if current_scope.user do
      {:noreply,
       socket
       |> assign(:live_action, :reply)
       |> assign(:current_post, post)
       |> assign(:reply, %Reply{})
       |> push_patch(to: "/app/circles/#{group.id}/posts/#{post.id}/reply")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit-reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    post = Timeline.get_post!(reply.post_id)
    current_scope = socket.assigns.current_scope

    if current_scope.user do
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

    current_scope = socket.assigns.current_scope

    if can_delete_group?(group, current_scope.user) do
      case Groups.delete_group(group) do
        {:ok, _group} ->
          {:noreply,
           socket
           |> put_flash(:success, "Circle deleted successfully.")
           |> push_navigate(to: ~p"/app/circles")}

        {:error, message} ->
          {:noreply,
           socket
           |> put_flash(:warning, message)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:warning, "You do not have permission to delete this circle.")
       |> push_navigate(to: ~p"/app/circles")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_scope = socket.assigns.current_scope
    group = socket.assigns.group

    user_group = Groups.get_user_group_for_group_and_user(group, current_scope.user)

    if post.user_id == current_scope.user.id || user_group.role in [:admin, :moderator, :owner] do
      {:ok, post} = Timeline.delete_post(post, user: current_scope.user)
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
    current_scope = socket.assigns.current_scope

    # The creator of the post can delete any replies for it.
    # this gives them the ability to moderate replies to their posts
    if current_scope.user &&
         (current_scope.user.id == reply.user_id || current_scope.user.id == reply.post.user_id) do
      case Timeline.delete_reply(reply, user: current_scope.user) do
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
    current_scope = socket.assigns.current_scope
    current_user_group = socket.assigns.current_user_group

    if post.user_id == current_scope.user.id ||
         current_user_group.role in [:owner, :admin, :moderator] do
      {:ok, post} =
        Timeline.delete_group_post(post, user: current_scope.user, user_group: current_user_group)

      notify_self({:deleted, post})

      socket = put_flash(socket, :success, "Post deleted successfully.")
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def assign_active_group(socket) do
    assign(socket, :group, nil)
  end

  defp page_title(:show), do: "Show Group"
  defp page_title(:edit), do: "Edit Group"
  defp page_title(:slide_over), do: "Show Group"
  defp page_title(:posts), do: "Show Group Posts"
  defp page_title(:reply), do: "Show Group Post"

  defp notify_self(msg), do: send(self(), {__MODULE__, msg})
end
