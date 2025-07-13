defmodule MossletWeb.UserConnectionLive.Show do
  use MossletWeb, :live_view

  require Logger

  alias Phoenix.LiveView.AsyncResult

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Groups
  alias Mosslet.Memories
  alias Mosslet.Memories.Memory

  alias Mosslet.Timeline
  alias Mosslet.Timeline.{Post, Reply}

  import MossletWeb.UserConnectionLive.Components

  @post_page_default 1
  @post_per_page_default 5
  @folder "uploads/trix"

  def mount(_params, _session, socket) do
    changeset =
      Timeline.change_post(%Post{}, %{}, user: socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:posts, AsyncResult.loading())
     |> assign(:groups, AsyncResult.loading())
     |> assign(:post_form, to_form(changeset))
     |> assign(:post_loading_count, 0)
     |> assign(:post_loading, false)
     |> assign(:post_loading_done, false)
     |> assign(:image_urls, [])
     |> assign(:uploads_in_progress, false)
     |> assign(:delete_post_from_cloud_message, nil)
     |> assign(:delete_reply_from_cloud_message, nil)
     |> assign(:finished_loading_post_list, [])}
  end

  def handle_params(%{"id" => id} = params, _url, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Accounts.private_subscribe(current_user)
      Accounts.subscribe_account_deleted()
      Groups.private_subscribe(current_user)
      Timeline.private_subscribe(current_user)
      Timeline.private_reply_subscribe(current_user)
      Timeline.connections_subscribe(current_user)
      Timeline.connections_reply_subscribe(current_user)
    end

    user_connection = Accounts.get_user_connection!(id)

    post_page = param_to_integer(params["post_page"], @post_page_default)

    post_per_page =
      param_to_integer(params["post_per_page"], @post_per_page_default) |> limit_post_per_page()

    options = %{
      post_sort_by: :inserted_at,
      post_sort_order: :desc,
      post_page: post_page,
      post_per_page: post_per_page,
      current_user_id: current_user.id
    }

    # create the return_url with memory and post pagination options
    url = construct_return_url(user_connection, options)

    socket =
      socket
      |> assign(:return_url, url)
      |> assign(:options, options)
      |> assign(:user_connection, user_connection)
      |> assign(:post_form, socket.assigns[:post_form])
      |> start_async(:fetch_posts, fn ->
        Timeline.list_shared_posts(user_connection.reverse_user_id, current_user.id, options)
      end)
      |> start_async(:fetch_groups, fn ->
        Groups.filter_groups_with_users(user_connection.reverse_user_id, current_user.id, %{
          sort_by: :inserted_at,
          sort_order: :desc
        })
      end)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    if socket.assigns.user_connection.id == id do
      socket
      |> assign(:page_title, "Edit Connection")
    else
      socket
      |> assign(:page_title, "Edit Connection")
      |> assign(:user_connection, Accounts.get_user_connection!(id))
    end
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Show Connection")
  end

  def handle_async(:update_post_body, {:ok, {message, _post}}, socket) do
    socket =
      socket
      |> put_flash(:info, "Update post body successful!")
      |> assign(:post_image_processing, AsyncResult.ok(message))

    if message === "updated" do
      {:noreply,
       push_event(socket, "update-post-body-complete", %{
         response: "success",
         message: message
       })}
    else
      {:noreply,
       push_event(socket, "update-post-body-complete", %{
         response: "failed",
         message: message
       })}
    end
  end

  def handle_async(:update_post_body, {:exit, reason}, socket) do
    {:noreply,
     assign(socket, :post_image_processing, AsyncResult.failed(%AsyncResult{}, {:exit, reason}))}
  end

  def handle_async(:update_reply_body, {:ok, {message, _post}}, socket) do
    socket =
      socket
      |> put_flash(:info, "Update reply body successful!")
      |> assign(:reply_image_processing, AsyncResult.ok(message))

    if message === "updated" do
      {:noreply,
       push_event(socket, "update-reply-body-complete", %{
         response: "success",
         message: message
       })}
    else
      {:noreply,
       push_event(socket, "update-reply-body-complete", %{
         response: "failed",
         message: message
       })}
    end
  end

  def handle_async(:update_reply_body, {:exit, reason}, socket) do
    {:noreply,
     assign(socket, :reply_image_processing, AsyncResult.failed(%AsyncResult{}, {:exit, reason}))}
  end

  def handle_async(:delete_post_from_cloud, {:ok, message}, socket) do
    %{delete_post_from_cloud_message: del_message} = socket.assigns

    {:noreply,
     assign(socket, :delete_post_from_cloud_message, AsyncResult.ok(del_message, message))}
  end

  def handle_async(:delete_post_from_cloud, {:exit, reason}, socket) do
    %{delete_post_from_cloud_message: del_message} = socket.assigns

    socket =
      socket
      |> clear_flash(:warning)
      |> put_flash(:warning, "Post image(s) could not be deleted from cloud: #{inspect(reason)}")

    {:noreply,
     assign(
       socket,
       :delete_post_from_cloud_message,
       AsyncResult.failed(del_message, {:exit, reason})
     )}
  end

  def handle_async(:delete_reply_from_cloud, {:ok, message}, socket) do
    {:noreply, assign(socket, :delete_reply_from_cloud_message, AsyncResult.ok(message))}
  end

  def handle_async(:delete_reply_from_cloud, {:exit, reason}, socket) do
    %{delete_reply_from_cloud_message: del_message} = socket.assigns

    socket =
      socket
      |> clear_flash(:warning)
      |> put_flash(:warning, "Reply image(s) could not be deleted from cloud: #{inspect(reason)}")

    {:noreply,
     assign(
       socket,
       :delete_reply_from_cloud_message,
       AsyncResult.failed(del_message, {:exit, reason})
     )}
  end

  def handle_async(:fetch_posts, {:ok, fetched_posts}, socket) do
    %{posts: posts} = socket.assigns
    current_user = socket.assigns.current_user
    user_connection = socket.assigns.user_connection
    key = socket.assigns.key
    # the user_connection belongs to the current_user
    user = Accounts.get_user!(user_connection.reverse_user_id)

    post_loading_list = Enum.with_index(fetched_posts, fn element, index -> {index, element} end)

    socket =
      socket
      |> assign(
        :post_shared_users,
        decrypt_shared_user_connections(
          Accounts.get_all_confirmed_user_connections(current_user.id),
          current_user,
          key,
          :post
        )
      )
      |> assign(:post_loading_list, post_loading_list)
      |> assign(:post_count, Timeline.shared_between_users_post_count(user.id, current_user.id))
      |> assign(:posts, AsyncResult.ok(posts, fetched_posts))
      |> stream(:posts, fetched_posts, reset: true)

    {:noreply, socket}
  end

  def handle_async(:fetch_groups, {:ok, fetched_groups}, socket) do
    %{groups: groups} = socket.assigns

    socket =
      socket
      |> assign(:groups, AsyncResult.ok(groups, fetched_groups))
      |> stream(:groups, fetched_groups, reset: true)

    {:noreply, socket}
  end

  def handle_async(:fetch_posts, {:exit, reason}, socket) do
    %{posts: posts} = socket.assigns

    socket =
      socket
      |> assign(:post_loading_list, [])
      |> stream(:posts, AsyncResult.failed(posts, {:exit, reason}))

    {:noreply, socket}
  end

  def handle_async(:fetch_groups, {:exit, reason}, socket) do
    %{groups: groups} = socket.assigns

    socket =
      socket
      |> assign(:post_loading_list, [])
      |> stream(:groups, AsyncResult.failed(groups, {:exit, reason}))

    {:noreply, socket}
  end

  def handle_info({:memory_created, _memory}, socket) do
    return_url = socket.assigns.return_url
    {:noreply, socket |> push_patch(to: return_url)}
  end

  def handle_info({:memory_deleted, memory}, socket) do
    return_url = socket.assigns.return_url
    current_user = socket.assigns.current_user

    if memory.user_id != current_user.id do
      {:noreply, push_patch(socket, to: return_url)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_created, post}, socket) do
    if post.user_id != socket.assigns.current_user.id && post.visibility == :connections &&
         is_nil(post.group_id) do
      {:noreply,
       socket
       |> push_patch(to: socket.assigns.return_url)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_reposted, post}, socket) do
    # this is handling the broadcasted message
    # so it will be a different user than the current user
    # if the post is not deleted directly by the current user
    if socket.assigns.current_user.id == post.user_id do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> stream_insert(:posts, post, at: 0)
       |> push_patch(to: socket.assigns.return_url)}
    end
  end

  def handle_info({:post_updated, post}, socket) do
    {:noreply, stream_insert(socket, :posts, post)}
  end

  def handle_info({:post_deleted, post}, socket) do
    {:noreply,
     socket
     |> stream_delete(:posts, post)
     |> push_patch(to: socket.assigns.return_url)}
  end

  def handle_info({:remark_created, _remark}, socket) do
    {:noreply, socket}
  end

  def handle_info({:reply_created, post, reply}, socket) do
    if socket.assigns.current_user.id == reply.user_id do
      {:noreply, socket}
    else
      # we update the post in the stream to add the reply
      {:noreply, socket |> stream_insert(:posts, post, at: -1)}
    end
  end

  def handle_info({:reply_updated, post, reply}, socket) do
    if socket.assigns.current_user.id == reply.user_id do
      {:noreply, socket}
    else
      # we update the post in the stream to update the reply
      {:noreply, socket |> stream_insert(:posts, post, at: -1)}
    end
  end

  def handle_info({:reply_deleted, post, _reply}, socket) do
    # we update the post in the stream to remove the reply
    {:noreply, socket |> stream_insert(:posts, post, at: -1)}
  end

  def handle_info({:repost_deleted, post}, socket) do
    current_user = socket.assigns.current_user
    # this is handling the broadcasted message
    # so it will be a different user than the current user
    # if the post is not deleted directly by the current user
    if current_user.id != post.user_id && current_user.id in post.reposts_list do
      {:noreply,
       socket
       |> stream_delete(:posts, post)
       |> push_patch(to: socket.assigns.return_url)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:uconn_updated, uconn}, socket) do
    cond do
      uconn.user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply, socket |> push_patch(to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  def handle_info({_ref, {"get_user_avatar", post_id, post_list, _user_id}}, socket) do
    post_loading_count = socket.assigns.post_loading_count
    finished_loading_post_list = socket.assigns.finished_loading_post_list

    cond do
      post_loading_count < Enum.count(post_list) - 1 ->
        socket =
          socket
          |> assign(:post_loading, true)
          |> assign(:post_loading_count, post_loading_count + 1)
          |> assign(
            :finished_loading_post_list,
            [post_id | finished_loading_post_list] |> Enum.uniq()
          )

        post = Timeline.get_post!(post_id)

        {:noreply, stream_insert(socket, :posts, post, at: -1)}

      post_loading_count == Enum.count(post_list) - 1 ->
        finished_loading_post_list = [post_id | finished_loading_post_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:post_loading, false)
          |> assign(
            :finished_loading_post_list,
            [post_id | finished_loading_post_list] |> Enum.uniq()
          )

        if Enum.count(finished_loading_post_list) == Enum.count(post_list) do
          post = Timeline.get_post!(post_id)

          socket =
            socket
            |> assign(:post_loading_count, 0)
            |> assign(:post_loading, false)
            |> assign(:post_loading_done, true)
            |> assign(:finished_loading_post_list, [])

          {:noreply, stream_insert(socket, :posts, post, at: -1)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:post_loading, true)
          |> assign(
            :finished_loading_post_list,
            [post_id | finished_loading_post_list] |> Enum.uniq()
          )

        {:noreply, socket}
    end
  end

  def handle_info({_ref, {"get_user_memory", memory_id, memory_list, _user_id}}, socket) do
    memory_loading_count = socket.assigns.memory_loading_count
    finished_loading_list = socket.assigns.finished_loading_list

    cond do
      memory_loading_count < Enum.count(memory_list) - 1 ->
        socket =
          socket
          |> assign(:memory_loading, true)
          |> assign(:memory_loading_count, memory_loading_count + 1)
          |> assign(:finished_loading_list, [memory_id | finished_loading_list] |> Enum.uniq())

        memory = Memories.get_memory!(memory_id)

        {:noreply, stream_insert(socket, :memories, memory, at: -1, reset: true)}

      memory_loading_count == Enum.count(memory_list) - 1 ->
        finished_loading_list = [memory_id | finished_loading_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:memory_loading, false)
          |> assign(:finished_loading_list, [memory_id | finished_loading_list] |> Enum.uniq())

        if Enum.count(finished_loading_list) == Enum.count(memory_list) do
          memory = Memories.get_memory!(memory_id)

          socket =
            socket
            |> assign(:memory_loading_count, 0)
            |> assign(:memory_loading, false)
            |> assign(:memory_loading_done, true)
            |> assign(:finished_loading_list, [])

          {:noreply, stream_insert(socket, :memories, memory, at: -1)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:memory_loading, true)
          |> assign(:finished_loading_list, [memory_id | finished_loading_list] |> Enum.uniq())

        {:noreply, socket}
    end
  end

  def handle_info({_ref, {:ok, :memory_deleted_from_storj, info}}, socket) do
    socket =
      socket
      |> clear_flash(:success)
      |> put_flash(:success, info)

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event("edit_user_connection", %{"id" => id, "return_url" => return_url}, socket) do
    if socket.assigns.user_connection.id == id do
      {:noreply,
       socket
       |> assign(:live_action, :edit)
       |> assign(:return_url, return_url)}
    else
      {:noreply,
       socket
       |> assign(:live_action, :edit)
       |> assign(:return_url, return_url)
       |> assign(:user_connection, Accounts.get_user_connection!(id))}
    end
  end

  def handle_event(
        "new_memory",
        %{"url" => return_url, "username" => username, "email" => email},
        socket
      ) do
    # we assign the user from the user_connection to the
    # new_memory_shared_user to programatically enforce only sharing a memory
    # with the user from the user_connection
    #
    # the shared_user assign is for the UI
    user_connection = socket.assigns.user_connection
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:live_action, :new_memory)
      |> assign(:return_url, return_url)
      |> assign(:memory, %Memory{})
      |> assign(:group, "")
      |> assign(:groups_for_memory, [])
      |> assign(:selector, "connections")
      |> assign(:new_memory_shared_user_list, [
        %Memory.SharedUser{
          id: nil,
          username: username,
          user_id: user_connection.reverse_user_id,
          sender_id: current_user.id
        }
      ])
      |> assign(:shared_user, %{
        username: username,
        user_id: user_connection.reverse_user_id,
        email: email
      })

    {:noreply, socket}
  end

  def handle_event("edit_post", %{"id" => id, "url" => return_url}, socket) do
    # we assign the post to be editted to a new variable
    # to not interrupt the new_post_form
    post = Timeline.get_post!(id)

    socket =
      socket
      |> assign(:live_action, :post_edit)
      |> assign(:return_url, return_url)
      |> assign(:post, post)
      |> assign(:image_urls, if(post.image_urls, do: post.image_urls, else: []))

    {:noreply, socket}
  end

  def handle_event("reply", %{"id" => id, "url" => return_url}, socket) do
    post = Timeline.get_post!(id)

    socket =
      socket
      |> assign(:live_action, :reply)
      |> assign(:return_url, return_url)
      |> assign(:post, post)
      |> assign(:reply, %Reply{})
      |> assign(:image_urls, [])

    {:noreply, socket}
  end

  def handle_event("edit_reply", %{"id" => id, "url" => return_url}, socket) do
    reply = Timeline.get_reply!(id)

    socket =
      socket
      |> assign(:live_action, :reply_edit)
      |> assign(:return_url, return_url)
      |> assign(:post, reply.post)
      |> assign(:reply, reply)
      |> assign(:image_urls, if(reply.image_urls, do: reply.image_urls, else: []))

    {:noreply, socket}
  end

  def handle_event("delete_reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # The creator of the post can delete any replies for it.
    # this gives them the ability to moderate replies to their posts
    if current_user.id == reply.user_id || current_user.id == reply.post.user_id do
      post = Timeline.get_post!(reply.post_id)
      user_post = Timeline.get_user_post(post, current_user)

      case Timeline.delete_reply(reply, user: current_user) do
        {:ok, reply} ->
          socket =
            socket
            |> put_flash(:success, "Reply deleted successfully.")
            |> assign(:delete_reply_from_cloud_message, AsyncResult.loading())
            |> start_async(
              :delete_reply_from_cloud,
              fn ->
                delete_reply_from_cloud(
                  reply,
                  user_post,
                  current_user,
                  key
                )
              end
            )

          {:noreply, push_patch(socket, to: socket.assigns.return_url)}

        {:error, message} ->
          {:noreply, put_flash(socket, :warning, message)}
      end
    else
      {:noreply, put_flash(socket, :warning, "You do not have permission to delete this Reply.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    uconn = Accounts.get_user_connection!(id)

    if uconn.user_id == socket.assigns.current_user.id do
      case Accounts.delete_both_user_connections(uconn) do
        {:ok, _uconns} ->
          {:noreply, socket |> push_navigate(to: ~p"/app/users/connections")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user
    return_url = socket.assigns.return_url
    key = socket.assigns.key

    if post.user_id == current_user.id do
      user_post = Timeline.get_user_post(post, current_user)
      replies = post.replies

      case Timeline.delete_post(post, user: current_user) do
        {:ok, post} ->
          socket =
            socket
            |> put_flash(:success, "Post deleted successfully.")
            |> assign(:delete_post_from_cloud_message, AsyncResult.loading())
            |> start_async(
              :delete_post_from_cloud,
              fn ->
                delete_post_from_cloud(
                  post,
                  user_post,
                  current_user,
                  key
                )
              end
            )
            |> start_async(
              :delete_reply_from_cloud,
              fn ->
                delete_replies_from_cloud(
                  replies,
                  user_post,
                  current_user,
                  key
                )
              end
            )

          {:noreply, push_patch(socket, to: return_url)}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You are not authorized to delete this post.")}
    end
  end

  def handle_event("fav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user
    return_url = socket.assigns.return_url

    if current_user.id not in post.favs_list do
      {:ok, post} = Timeline.inc_favs(post)

      case Timeline.update_post_fav(
             post,
             %{favs_list: List.insert_at(post.favs_list, 0, current_user.id)},
             user: current_user
           ) do
        {:ok, _post} ->
          socket =
            socket
            |> clear_flash()
            |> put_flash(:success, "Post favorited successfully.")
            |> push_patch(to: return_url)

          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("unfav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user
    return_url = socket.assigns.return_url

    if current_user.id in post.favs_list do
      {:ok, post} = Timeline.decr_favs(post)

      case Timeline.update_post_fav(
             post,
             %{favs_list: List.delete(post.favs_list, current_user.id)},
             user: current_user
           ) do
        {:ok, _post} ->
          socket =
            socket
            |> clear_flash()
            |> put_flash(:success, "Post unfavorited successfully.")
            |> push_patch(to: return_url)

          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("repost", %{"id" => id, "body" => body, "username" => username}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user
    # Add the post_key to the opts as the trix_key.
    #
    # This way, if there are any images in the post, then
    # we will correctly reuse the trix_key from the original
    # post to decrypt the images (this way we don't have to
    # duplicate the images in storage).
    #
    # Also, it's a repost, so it is essentially a duplicate post
    # and thus the duplicate use of the same key.
    post_key = get_post_key(post, user)
    key = socket.assigns.key
    post_shared_users = socket.assigns.post_shared_users
    return_url = socket.assigns.return_url

    if post.user_id != user.id && user.id not in post.reposts_list do
      # the image urls are now encrypted so we need to decrypt them
      repost_params =
        %{
          body: body,
          username: username,
          favs_list: post.favs_list,
          reposts_list: post.reposts_list,
          favs_count: post.favs_count,
          reposts_count: post.reposts_count,
          user_id: user.id,
          original_post_id: post.id,
          visibility: post.visibility,
          image_urls: decrypt_image_urls_for_repost(post, user, key),
          image_urls_updated_at: post.image_urls_updated_at,
          shared_users: [%{}],
          repost: true
        }
        |> add_shared_users_list(post_shared_users)

      case Timeline.create_repost(repost_params, user: user, key: key, trix_key: post_key) do
        {:ok, _repost} ->
          {:ok, post} = Timeline.inc_reposts(post)

          {:ok, _post} =
            Timeline.update_post_repost(
              post,
              %{
                reposts_list: List.insert_at(post.reposts_list, 0, user.id)
              },
              user: user
            )

          socket =
            socket
            |> put_flash(:success, "Post reposted successfully.")

          {:noreply, push_navigate(socket, to: return_url)}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         "You have already reposted this post or do not have permission to repost."
       )}
    end
  end

  def handle_event("blur-memory", %{"id" => id}, socket) do
    memory = Memories.get_memory!(id)
    current_user = socket.assigns.current_user

    {:ok, memory} =
      Memories.blur_memory(
        memory,
        %{
          "shared_users" =>
            Enum.into(memory.shared_users, [], fn shared_user ->
              if shared_user.user_id == current_user.id,
                do: put_in(shared_user.blur, blur_shared_user(shared_user))

              put_in(shared_user.current_user_id, current_user.id)
              Map.from_struct(shared_user)
            end)
        },
        current_user,
        blur: true
      )

    {:noreply, stream_insert(socket, :memories, memory, at: -1)}
  end

  def handle_event("validate_post", %{"post_params" => post_params}, socket) do
    current_user = socket.assigns.current_user

    post_params =
      post_params
      |> Map.put("image_urls", socket.assigns.image_urls)
      |> add_user_to_shared_users_list()

    changeset = Timeline.change_post(%Post{}, post_params, user: current_user)

    socket =
      socket
      |> assign(:post_form, to_form(changeset, action: :validate))

    {:noreply, socket}
  end

  def handle_event("save_post", %{"post_params" => post_params}, socket) do
    if connected?(socket) do
      post_params =
        post_params
        |> Map.put("image_urls", socket.assigns.image_urls)
        |> Map.put("image_urls_updated_at", NaiveDateTime.utc_now())
        |> add_user_to_shared_users_list()

      current_user = socket.assigns.current_user
      key = socket.assigns.key
      trix_key = socket.assigns[:trix_key]

      if post_params["user_id"] == current_user.id do
        case Timeline.create_post(post_params, user: current_user, key: key, trix_key: trix_key) do
          {:ok, _post} ->
            socket =
              socket
              |> assign(:trix_key, nil)
              |> assign(
                :post_form,
                to_form(Timeline.change_post(%Post{}, %{}, user: current_user))
              )
              |> assign(:image_urls, [])
              |> put_flash(:success, "Post created successfully")
              |> push_navigate(to: socket.assigns.return_url)

            {:noreply, socket}

          {:error, changeset} ->
            socket =
              socket
              |> assign(:post_form, to_form(changeset, action: :validate))
              |> put_flash(:error, "#{changeset.message}")
              |> push_patch(to: socket.assigns.return_url)

            {:noreply, socket}
        end
      else
        {:noreply,
         socket
         |> put_flash(:warning, "You do not have permission to create this post.")
         |> push_patch(to: socket.assigns.return_url)}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :warning,
         "You are not connected to the internet. Please refresh your page and try again."
       )
       |> push_patch(to: socket.assigns.return_url)}
    end
  end

  def handle_event("uploads_in_progress", %{"flag" => flag}, socket) do
    socket =
      socket
      |> assign(:uploads_in_progress, flag)

    {:noreply, socket}
  end

  def handle_event("file_too_large", %{"message" => message, "flag" => flag}, socket) do
    socket = assign(socket, :uploads_in_progress, flag)
    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event("nsfw", %{"message" => message, "flag" => flag}, socket) do
    socket =
      socket
      |> assign(:uploads_in_progress, flag)
      |> put_flash(:warning, message)

    {:noreply, socket}
  end

  def handle_event("remove_files", %{"flag" => flag}, socket) do
    # we want to clear any existing warning messages in the flash
    socket =
      socket
      |> clear_flash(:warning)
      |> assign(:uploads_in_progress, flag)

    {:noreply, socket}
  end

  def handle_event("error_uploading", %{"message" => message, "flag" => flag}, socket) do
    socket = assign(socket, :uploads_in_progress, flag)
    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event(
        "error_removing",
        %{"message" => message, "url" => url, "flag" => flag},
        socket
      ) do
    Logger.error("Error removing Trix image in UserConnectionLive.Show")
    Logger.debug(inspect(url))
    Logger.error("Error removing Trix image in UserConnectionLive.Show: #{url}")
    socket = assign(socket, :uploads_in_progress, flag)

    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event("trix_key", _params, socket) do
    current_user = socket.assigns.current_user
    # we check if there's a post assigned to the socket,
    # if so, then we can infer that it's a Reply being
    # created and the trix_key will be the already saved
    # post_key (it'll also already be encrypted as well)
    post = socket.assigns[:post]

    trix_key =
      Map.get(socket.assigns, :trix_key, generate_and_encrypt_trix_key(current_user, post))

    socket =
      socket
      |> assign(:trix_key, trix_key)

    {:reply, %{response: "success", trix_key: trix_key}, socket}
  end

  def handle_event(
        "decrypt_post_images",
        %{"sources" => sources, "post_id" => post_id} = _params,
        socket
      ) do
    memories_bucket = Encrypted.Session.memories_bucket()
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    post_id =
      if String.contains?(post_id, "-reply-form"),
        do: String.split(post_id, "-reply-form") |> List.first(),
        else: post_id

    post = Timeline.get_post!(post_id)
    post_key = get_post_key(post, current_user)

    images =
      Enum.map(sources, fn source ->
        file_key = get_file_key_from_remove_event(source)
        ext = get_ext_from_file_key(source)
        file_path = "#{@folder}/#{file_key}.#{ext}"

        case get_s3_object(memories_bucket, file_path) do
          {:ok, %{body: e_obj}} ->
            decrypt_image_for_trix(e_obj, current_user, post_key, key, post, "body", ext)

          {:error, error} ->
            Logger.info("Error getting Post images from cloud in TimelineLive.Index")
            Logger.debug(inspect(error))
            Logger.error(error)
            nil
        end
      end)
      |> List.flatten()
      |> Enum.filter(fn source -> !is_nil(source) end)

    if decrypted_image_binaries_for_trix?(images) do
      {:reply, %{response: "success", decrypted_binaries: images}, socket}
    else
      {:reply, %{response: "failed", decrypted_binaries: []}, socket}
    end
  end

  def handle_event(
        "decrypt_reply_images",
        %{"sources" => sources, "reply_id" => reply_id} = _params,
        socket
      ) do
    memories_bucket = Encrypted.Session.memories_bucket()
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    reply = Timeline.get_reply!(reply_id)
    post = Timeline.get_post!(reply.post_id)
    post_key = get_post_key(post, current_user)

    images =
      Enum.map(sources, fn source ->
        file_key = get_file_key_from_remove_event(source)
        ext = get_ext_from_file_key(source)
        file_path = "#{@folder}/#{file_key}.#{ext}"

        case get_s3_object(memories_bucket, file_path) do
          {:ok, %{body: e_obj}} ->
            decrypt_image_for_trix(e_obj, current_user, post_key, key, reply, "body", ext)

          {:error, error} ->
            Logger.info("Error getting Reply images from cloud in TimelineLive.Index")
            Logger.debug(inspect(error))
            Logger.error(error)
            nil
        end
      end)
      |> List.flatten()
      |> Enum.filter(fn source -> !is_nil(source) end)

    if decrypted_image_binaries_for_trix?(images) do
      {:reply, %{response: "success", decrypted_binaries: images}, socket}
    else
      {:reply, %{response: "failed", decrypted_binaries: []}, socket}
    end
  end

  def handle_event(
        "add_image_urls",
        %{"preview_url" => preview_url, "content_type" => content_type},
        socket
      ) do
    file_ext = ext(content_type)
    file_key = get_file_key(preview_url)
    file_path = "#{@folder}/#{file_key}.#{file_ext}"
    image_urls = socket.assigns.image_urls

    socket =
      socket
      |> assign(:image_urls, [file_path | image_urls] |> Enum.uniq())

    {:reply, %{response: "success"}, socket}
  end

  def handle_event(
        "remove_image_urls",
        %{"preview_url" => preview_url, "content_type" => content_type},
        socket
      ) do
    file_ext = ext(content_type)
    file_key = get_file_key_from_remove_event(preview_url)
    file_path = "#{@folder}/#{file_key}.#{file_ext}"
    image_urls = socket.assigns.image_urls

    updated_urls = Enum.reject(image_urls, fn url -> url == file_path end)

    {:reply, %{response: "success"}, assign(socket, :image_urls, updated_urls)}
  end

  @doc """
  We only generate a signed_url if the post's url has expired. We then
  send the presigned_url back to the client.
  """
  def handle_event("generate_signed_urls", %{"src_list" => src_list}, socket) do
    presigned_url_list =
      Enum.map(src_list, fn src ->
        file_key_with_ext = get_file_key_with_ext(src)

        file_path = get_file_path_for_s3(file_key_with_ext)

        case generate_presigned_url(:get, file_path) do
          {:ok, presigned_url} ->
            presigned_url

          _error ->
            "error"
        end
      end)

    if "error" in presigned_url_list do
      {:reply, %{response: "failed"}, socket}
    else
      {:reply, %{response: "success", presigned_url_list: presigned_url_list}, socket}
    end
  end

  # This event comes in from the client side and updates the body of a post
  # to store the updated presigned_urls for any images.

  # The body, username, and avatar_url are all stored encrypted. So, we need
  # to decrypt the username and avatar_url before updating the post (the
  # body is being sent to use from the client already decrypted).

  def handle_event("update_post_body", %{"body" => body, "id" => id}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    post = Timeline.get_post!(id)

    # Trim any added \n characters from the client html
    body =
      if body && is_list(body), do: List.to_string(body) |> String.trim(), else: String.trim(body)

    socket =
      socket
      |> assign(:post_image_processing, AsyncResult.loading())
      |> start_async(:update_post_body, fn ->
        update_post_body(post, body, current_user, key)
      end)

    {:noreply, socket}
  end

  def handle_event("update_reply_body", %{"body" => body, "id" => id}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    reply = Timeline.get_reply!(id)

    # Trim any added \n characters from the client html
    body =
      if body && is_list(body), do: List.to_string(body) |> String.trim(), else: String.trim(body)

    socket =
      socket
      |> assign(:reply_image_processing, AsyncResult.loading())
      |> start_async(:update_reply_body, fn ->
        update_reply_body(reply, body, current_user, key)
      end)

    {:noreply, socket}
  end

  def handle_event("log_error", %{"error" => error} = error_message, socket) do
    Logger.warning("Trix Error in UserConnectionLive.Show")
    Logger.debug(inspect(error_message))
    Logger.error(error)

    {:noreply, socket}
  end

  defp update_post_body(post, body, current_user, key) do
    # We have to decrypt the username, and avatar url (if it exists)
    # we already have the decrypted new body html in `body` and
    # just have to update the post with these options (I think *fingers crossed*)
    post_key = get_post_key(post, current_user)

    username =
      decr_item(
        post.username,
        current_user,
        post_key,
        key,
        post,
        "username"
      )

    avatar_url =
      if post.avatar_url do
        decr_item(
          post.avatar_url,
          current_user,
          post_key,
          key,
          post,
          "body"
        )
      end

    post_params =
      if avatar_url do
        %{
          "username" => username,
          "body" => body,
          "avatar_url" => avatar_url,
          "visibility" => post.visibility,
          "group_id" => post.group_id,
          "image_urls_updated_at" => NaiveDateTime.utc_now()
        }
      else
        %{
          "username" => username,
          "body" => body,
          "visibility" => post.visibility,
          "group_id" => post.group_id,
          "image_urls_updated_at" => NaiveDateTime.utc_now()
        }
      end

    case Timeline.update_post(post, post_params,
           update_post: true,
           post_key: post_key,
           user: current_user,
           key: key
         ) do
      {:ok, post} ->
        {"updated", post}

      {:error, error} ->
        {"error", error}
    end
  end

  defp update_reply_body(reply, body, current_user, key) do
    # We have to decrypt the username, and avatar url (if it exists)
    # we already have the decrypted new body html in `body` and
    # just have to update the post with these options (I think *fingers crossed*)
    post = Timeline.get_post!(reply.post_id)
    post_key = get_post_key(post, current_user)

    username =
      decr_item(
        reply.username,
        current_user,
        post_key,
        key,
        reply,
        "username"
      )

    reply_params =
      %{
        "username" => username,
        "body" => body,
        "visibility" => reply.visibility,
        "post_id" => reply.post_id,
        "user_id" => reply.user_id,
        "image_urls_updated_at" => NaiveDateTime.utc_now()
      }

    case Timeline.update_reply(reply, reply_params,
           update_reply: true,
           encrypt_reply: true,
           visibility: reply.visibility,
           post_key: post_key,
           group_id: nil,
           user: current_user,
           key: key
         ) do
      {:ok, reply} ->
        {"updated", reply}

      {:error, error} ->
        {"error", error}
    end
  end

  defp delete_post_from_cloud(post, user_post, current_user, key) when is_struct(post) do
    # we only want to delete the images if the post is not a repost
    # and if the post contains image urls
    if !post.repost && is_list(post.image_urls) do
      d_image_urls =
        Enum.map(post.image_urls, fn e_image_url ->
          # decrypt the image url
          decr_item(
            e_image_url,
            current_user,
            user_post.key,
            key,
            post,
            "body"
          )
        end)

      case delete_object_storage_post_worker(%{"urls" => d_image_urls}) do
        {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
          :ok

        rest ->
          Logger.info(
            "Error deleting Post images from the cloud in UserConnectionLive.Show context."
          )

          Logger.info(inspect(rest))
          Logger.error(rest)
          {:error, "There was an error deleting Post data from the cloud."}
      end
    else
      :ok
    end
  end

  defp delete_post_from_cloud(nil, _user_post, _current_user, _key), do: :ok

  defp delete_reply_from_cloud(reply, user_post, current_user, key) when is_struct(reply) do
    # we only want to delete the images if the reply contains image_urls
    if is_list(reply.image_urls) && !Enum.empty?(reply.image_urls) do
      d_image_urls =
        Enum.map(reply.image_urls, fn e_image_url ->
          # decrypt the image url
          decr_item(
            e_image_url,
            current_user,
            user_post.key,
            key,
            reply,
            "body"
          )
        end)

      case delete_object_storage_reply_worker(%{"urls" => d_image_urls}) do
        {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
          :ok

        rest ->
          Logger.info(
            "Error deleting Reply images from the cloud in UserConnectionLive.Show context."
          )

          Logger.info(inspect(rest))
          Logger.error(rest)
          {:error, "There was an error deleting Reply data from the cloud."}
      end
    else
      :ok
    end
  end

  defp delete_reply_from_cloud(nil, _user_post, _current_user, _key), do: :ok

  defp delete_replies_from_cloud(replies, user_post, current_user, key) when is_list(replies) do
    # we only want to delete the images if the reply contains image_urls
    for reply <- replies do
      if is_list(reply.image_urls) && !Enum.empty?(reply.image_urls) do
        d_image_urls =
          Enum.map(reply.image_urls, fn e_image_url ->
            # decrypt the image url
            decr_item(
              e_image_url,
              current_user,
              user_post.key,
              key,
              reply,
              "body"
            )
          end)

        case delete_object_storage_post_worker(%{"urls" => d_image_urls}) do
          {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
            :ok

          rest ->
            Logger.info(
              "Error deleting Reply images from the cloud in UserConnectionLive.Show context."
            )

            Logger.info(inspect(rest))
            Logger.error(rest)
            {:error, "There was an error deleting Reply data from the cloud."}
        end
      else
        :ok
      end
    end
  end

  defp delete_replies_from_cloud(nil, _user_post, _current_user, _key), do: :ok

  defp delete_object_storage_post_worker(params) do
    params
    |> Mosslet.Workers.DeleteObjectStoragePostWorker.new()
    |> Oban.insert()
  end

  defp delete_object_storage_reply_worker(params) do
    params
    |> Mosslet.Workers.DeleteObjectStorageReplyWorker.new()
    |> Oban.insert()
  end

  # In this function, we are only posting to the user
  # for the user_connection page we are viewing. So,
  # we only ever need to add one user to the shared_users list.
  defp add_user_to_shared_users_list(post_params) do
    post_params
    |> Map.put("shared_users", [
      %{
        id: nil,
        sender_id: post_params["user_id"],
        username: post_params["shared_user_username"],
        user_id: post_params["shared_user_id"]
      }
    ])
  end

  # When post is being shared with all connections, the
  # shared_users is a list of SharedUser structs.
  #
  # When adding shared_users from a repost, we need to update
  # the shared_users list with the current_user's shared users.
  defp add_shared_users_list(repost_params, shared_users) do
    Map.update(
      repost_params,
      :shared_users,
      Enum.map(shared_users, fn shared_user ->
        Map.from_struct(shared_user)
      end),
      fn _shared_users_list ->
        Enum.map(shared_users, fn shared_user ->
          Map.from_struct(shared_user)
        end)
      end
    )
  end

  defp blur_shared_user(shared_user) do
    if shared_user.blur do
      false
    else
      true
    end
  end

  defp param_to_integer(nil, default), do: default

  defp param_to_integer(param, default) do
    case Integer.parse(param) do
      {number, _} -> number
      :error -> default
    end
  end

  defp limit_post_per_page(per_page) when is_integer(per_page) do
    if per_page > 4, do: 4, else: per_page
  end

  defp construct_return_url(user_connection, options) do
    if options.post_page == @post_page_default &&
         options.post_per_page == @post_per_page_default,
       do: ~p"/app/users/connections/#{user_connection}",
       else: ~p"/app/users/connections/#{user_connection}?#{options}"
  end

  defp get_file_key(url) do
    url |> String.split("/") |> List.last()
  end

  defp get_file_key_from_remove_event(url) do
    url
    |> String.split("/")
    |> List.last()
    |> String.split(".")
    |> List.first()
  end

  defp ext(content_type) do
    [ext | _] = MIME.extensions(content_type)
    ext
  end
end
