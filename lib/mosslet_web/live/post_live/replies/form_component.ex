defmodule MossletWeb.PostLive.Replies.FormComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias Mosslet.Timeline
  alias Mosslet.Timeline.Reply

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.page_header title="Reply" />

      <.p :if={@action == :reply}>Create a new reply to the following post:</.p>
      <.p :if={@action == :reply_edit}>Edit your reply to the following post:</.p>

      <.p>
        <div class="px-4 py-5 mt-4 sm:px-0 sm:py-0 max-h-24 overflow-y-auto">
          <dl class="space-y-0 divide-y divide-gray-200 dark:divide-gray-700 border border-secondary-600 dark:border-secondary-400 rounded-md">
            <div class="sm:flex px-6 py-5">
              <dt class="text-sm font-medium text-secondary-700 dark:text-secondary-200 sm:w-40 sm:flex-shrink-0 lg:w-48">
                Body
              </dt>

              <dd
                id={"post-body-#{@post.id}-reply-form"}
                phx-hook="TrixContentPostHook"
                class="post-body"
                phx-update="ignore"
              >
                {html_block(
                  decr_item(@post.body, @user, get_post_key(@post, @user), @key, @post, "body")
                )}
              </dd>
            </div>
          </dl>
        </div>
      </.p>

      <.simple_form
        for={@form}
        id="reply-form"
        phx-target={@myself}
        phx-change="validate_reply"
        phx-submit="save_reply"
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

        <div :if={@action == :reply} id="ignore-trix-editor_reply" phx-update="ignore">
          <trix-editor
            input="trix-editor_reply"
            placeholder="Reply to this Post"
            class="trix-content max-h-64 overflow-y-auto"
            required
          >
          </trix-editor>
        </div>

        <.phx_input
          :if={@action == :reply}
          field={@form[:image_urls]}
          name={@form[:image_urls].name}
          value={@form[:image_urls].value}
          type="hidden"
        />

        <.phx_input
          :if={@action == :reply}
          id="trix-editor_reply"
          field={@form[:body]}
          name={@form[:body].name}
          phx-hook="TrixEditor"
          type="hidden"
        />

        <div
          :if={@action == :reply_edit && get_shared_item_identity_atom(@reply, @user) == :self}
          id="ignore-trix-editor_reply_edit"
          phx-update="ignore"
        >
          <trix-editor
            input="trix-editor_reply_edit"
            class="trix-content max-h-64 overflow-y-auto"
            required
          >
          </trix-editor>
        </div>

        <.phx_input
          :if={@action == :reply_edit}
          field={@form[:image_urls]}
          name={@form[:image_urls].name}
          value={@form[:image_urls].value}
          type="hidden"
        />

        <.phx_input
          :if={@action == :reply_edit && get_shared_item_identity_atom(@reply, @user) == :self}
          id="trix-editor_reply_edit"
          field={@form[:body]}
          value={
            @body || decr_item(@reply.body, @user, get_post_key(@post, @user), @key, @post, "body")
          }
          phx-hook="TrixEditor"
          type="hidden"
        />

        <:actions>
          <.button
            :if={@form.source.valid? && !@uploads_in_progress}
            phx-disable-with="Replying..."
            class="rounded-full"
          >
            Reply
          </.button>

          <button
            :if={!@form.source.valid?}
            type="submit"
            class="inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white shadow-sm opacity-20"
            disabled
          >
            Reply
          </button>
          <button
            :if={@uploads_in_progress}
            type="submit"
            class="inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white shadow-sm opacity-20"
            disabled
          >
            Updating...
          </button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{post: post, reply: reply} = assigns, socket) do
    user = assigns.user
    key = assigns.key

    # when trix editor is being updated it calls this update function
    # so we need to be checking whether to update the changeset
    # because validate won't be called yet
    params = if socket.assigns[:form], do: socket.assigns[:form].source.changes, else: %{}
    params = if params, do: params, else: %{}

    changeset =
      Timeline.change_reply(reply, params,
        key: key,
        visibility: post.visibility,
        group_id: post.group_id,
        post_key: get_post_key(post, user)
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:image_urls, assigns.image_urls)
     |> assign(:body, nil)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate_reply", %{"reply" => reply_params}, socket) do
    reply_params =
      reply_params
      |> Map.put("image_urls", socket.assigns.image_urls)

    changeset =
      socket.assigns.reply
      |> Timeline.change_reply(reply_params, user: socket.assigns.user)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:body, reply_params["body"])
     |> assign_form(changeset)}
  end

  def handle_event("save_reply", %{"reply" => reply_params}, socket) do
    if connected?(socket) do
      reply_params =
        reply_params
        |> Map.put("image_urls", socket.assigns.image_urls)
        |> Map.put("image_urls_updated_at", NaiveDateTime.utc_now())

      save_reply(socket, socket.assigns.action, reply_params)
    else
      {:noreply,
       socket
       |> put_flash(
         :warning,
         "You are not connected to the internet. Please refresh your page and try again."
       )
       |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp save_reply(socket, :reply_edit, reply_params) do
    if can_edit?(socket.assigns.user, socket.assigns.reply) do
      user = socket.assigns.user
      key = socket.assigns.key
      reply = socket.assigns.reply
      post = socket.assigns.post
      trix_key = socket.assigns[:trix_key]

      case Timeline.update_reply(reply, reply_params,
             update_reply: true,
             encrypt_reply: true,
             visibility: reply.visibility,
             trix_key: trix_key,
             post_key: get_post_key(post, user),
             group_id: reply_params["group_id"] || reply_params[:group_id],
             user: user,
             key: key
           ) do
        {:ok, reply} ->
          notify_parent({:updated, reply})

          {:noreply,
           socket
           |> assign(
             :form,
             to_form(Timeline.change_reply(%Reply{}, %{}, user: user))
           )
           |> assign(:image_urls, [])
           |> assign(:trix_key, nil)
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
    trix_key = socket.assigns[:trix_key]

    if reply_params["user_id"] == user.id do
      case Timeline.create_reply(reply_params,
             update_reply: true,
             encrypt_reply: true,
             visibility: post.visibility,
             post: post,
             trix_key: trix_key,
             post_key: get_post_key(post, user),
             group_id: reply_params["group_id"] || reply_params[:group_id],
             user: user,
             key: key
           ) do
        {:ok, reply} ->
          notify_parent({:saved, reply})

          {:noreply,
           socket
           |> assign(
             :form,
             to_form(Timeline.change_reply(%Reply{}, %{}, user: user))
           )
           |> assign(:image_urls, [])
           |> assign(:trix_key, nil)
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
