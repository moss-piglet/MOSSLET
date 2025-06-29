defmodule MossletWeb.GroupLive.Replies.FormComponent do
  @moduledoc """
  The form component for replies to
  Group posts.
  """
  use MossletWeb, :live_component

  alias Mosslet.Timeline

  @doc """
  This form component is displayed in the
  slide over within the group show page.

  Formatting needs to fit the compressed slide over.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.page_header title={@title} />

      <.p :if={@action == :reply}>Create a new reply to the following post:</.p>
      <.p :if={@action == :reply_edit}>Edit your reply to the following post:</.p>

      <.p>
        <div class="px-4 py-5 mt-4">
          <dl class="space-y-0 divide-y divide-gray-200 dark:divide-gray-700 border border-secondary-600 dark:border-secondary-400 rounded-md">
            <div class="px-6 py-5">
              <dt class="text-sm font-medium text-secondary-700 dark:text-secondary-200">
                Username
              </dt>
              <dd class="mt-1 font-light text-sm text-gray-900 dark:text-gray-100">
                {decr_item(
                  @post.username,
                  @user,
                  get_post_key(@post, @user),
                  @key,
                  @post,
                  "username"
                )}
              </dd>
            </div>

            <div class="px-6 py-5">
              <dt class="text-sm font-medium text-secondary-700 dark:text-secondary-200">
                Date
              </dt>
              <dd class="mt-1 font-light text-sm text-gray-900 dark:text-gray-100 ">
                <.local_time_full id={"modal-#{@post.id}"} at={@post.updated_at} />
              </dd>
            </div>
            <div class="px-6 py-5">
              <dt class="text-sm font-medium text-secondary-700 dark:text-secondary-200">
                Body
              </dt>
              <dd class="mt-1 font-light text-sm text-gray-900 dark:text-gray-100 ">
                {decr_item(@post.body, @user, get_post_key(@post, @user), @key, @post, "body")}
              </dd>
            </div>
          </dl>
        </div>
      </.p>

      <.simple_form
        for={@form}
        id="reply-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.field field={@form[:user_id]} type="hidden" value={@user.id} />
        <.field field={@form[:post_id]} type="hidden" value={@post.id} />
        <.field field={@form[:group_id]} type="hidden" value={@post.group_id} />
        <.field field={@form[:visibility]} type="hidden" value={@post.visibility} />
        <.field
          :if={@action == :reply}
          field={@form[:username]}
          type="hidden"
          value={decr(@user.username, @user, @key)}
        />
        <.field
          :if={@action == :reply_edit}
          field={@form[:username]}
          type="hidden"
          value={decr(@user.username, @user, @key)}
        />

        <.field
          :if={@action == :reply}
          field={@form[:body]}
          type="textarea"
          label="Your reply"
          {alpine_autofocus()}
        />
        <.field
          :if={@action == :reply_edit && @post.visibility == :private}
          field={@form[:body]}
          type="textarea"
          label="Body"
          value={decr_item(@reply.body, @user, get_post_key(@post, @user), @key, @post, "body")}
          {alpine_autofocus()}
        />
        <.field
          :if={@action == :reply_edit && @post.visibility == :public}
          field={@form[:body]}
          type="textarea"
          label="Your reply"
          value={decr_item(@reply.body, @user, get_post_key(@post), @key, @post, "body")}
          {alpine_autofocus()}
        />
        <.field
          :if={@action == :reply_edit && get_shared_item_identity_atom(@reply, @user) == :self}
          field={@form[:body]}
          type="textarea"
          label="Body"
          value={decr_item(@reply.body, @user, get_post_key(@post, @user), @key, @post, "body")}
          {alpine_autofocus()}
        />
        <:actions>
          <.button :if={@form.source.valid?} phx-disable-with="Replying..." class="rounded-full">
            Reply
          </.button>
          <.button :if={!@form.source.valid?} disabled class="rounded-full">Reply</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{post: post, reply: reply} = assigns, socket) do
    user = assigns.user
    key = assigns.key

    changeset =
      Timeline.change_reply(reply, %{},
        key: key,
        visibility: post.visibility,
        group_id: post.group_id,
        post_key: get_post_key(post, user)
      )

    {:ok,
     socket
     |> assign(:live_action, assigns.action)
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"reply" => reply_params}, socket) do
    changeset =
      socket.assigns.reply
      |> Timeline.change_reply(reply_params, user: socket.assigns.user)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign_form(changeset)}
  end

  def handle_event("save", %{"reply" => reply_params}, socket) do
    save_reply(socket, socket.assigns.action, reply_params)
  end

  defp save_reply(socket, :reply_edit, reply_params) do
    if can_edit?(socket.assigns.user, socket.assigns.reply) do
      user = socket.assigns.user
      key = socket.assigns.key
      reply = socket.assigns.reply
      post = socket.assigns.post

      case Timeline.update_reply(reply, reply_params,
             update_reply: true,
             encrypt_reply: true,
             post_key: get_post_key(post, user),
             group_id: reply_params["group_id"] || reply_params[:group_id],
             user: user,
             key: key
           ) do
        {:ok, post} ->
          notify_parent({:updated, post})

          {:noreply,
           socket
           |> put_flash(:success, "Reply updated successfully")
           |> push_patch(to: socket.assigns.patch)}
      end
    else
      {:noreply, socket}
    end
  end

  defp save_reply(socket, :reply, reply_params) do
    user = socket.assigns.user
    key = socket.assigns.key
    post = socket.assigns.post

    if reply_params["user_id"] == user.id do
      case Timeline.create_reply(reply_params,
             update_reply: true,
             encrypt_reply: true,
             post: post,
             post_key: get_post_key(post, user),
             group_id: reply_params["group_id"] || reply_params[:group_id],
             user: user,
             key: key
           ) do
        {:ok, reply} ->
          notify_parent({:saved, reply})

          {:noreply,
           socket
           |> put_flash(:success, "Reply created successfully")
           |> push_patch(to: socket.assigns.patch)}
      end
    else
      {:noreply, socket}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
