defmodule MossletWeb.PostLive.FormComponent do
  use MossletWeb, :live_component

  alias Mosslet.Groups
  alias Mosslet.Timeline
  alias Mosslet.Timeline.Post

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.page_header title={@title} />

      <.p :if={@action == :new}>
        Use this form to create a new post.
      </.p>
      <.p :if={@action == :new} class="my-4">
        <.phx_icon name="hero-question-mark-circle" class="size-5" /> Leave the
        <span class="italic font-semibold text-emerald-600 dark:text-emerald-400">
          Add people to share with
        </span>
        selection blank to share with everyone you are connected to.
      </.p>
      <.p :if={@action == :edit}>Use this form to edit your existing post.</.p>

      <.simple_form
        for={@form}
        id="post-form-modal"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.field field={@form[:user_id]} type="hidden" value={@user.id} />
        <.field
          :if={@action == :new}
          field={@form[:username]}
          type="hidden"
          value={decr(@user.username, @user, @key)}
        />
        <.field
          :if={@action == :new_group}
          field={@form[:username]}
          type="hidden"
          value={decr(@user.username, @user, @key)}
        />
        <.field
          :if={@action == :edit}
          field={@form[:username]}
          type="hidden"
          value={decr(@user.username, @user, @key)}
        />
        <.field
          :if={@action not in [:new_group, :edit]}
          field={@form[:visibility]}
          type="hidden"
          value="connections"
        />

        <.field
          :if={@action == :new_group}
          field={@form[:group_id]}
          type="hidden"
          label="Group"
          value={@group.id}
        />
        <.field
          :if={@action == :new_group}
          field={@form[:visibility]}
          type="hidden"
          value={:connections}
        />

        <.field
          :if={@action == :new_group}
          field={@form[:group]}
          type="text"
          label="Group"
          value={
            decr_item(
              @group.name,
              @user,
              Groups.get_user_group_for_group_and_user(@group, @user).key,
              @key,
              @group
            )
          }
          disabled
        />

        <.live_select
          :if={
            @action in [:new] && @selector == "connections" && !Enum.empty?(@group_list) &&
              Enum.empty?(@user_list)
          }
          id="group-select"
          field={@form[:groups]}
          phx-target={@myself}
          phx-focus="set-group-default"
          label="Add a group to share with"
          options={@group_list}
          allow_clear={true}
          placeholder="Click or start typing to select group..."
          dropdown_extra_class="max-h-60 overflow-y-scroll"
        >
          <:option :let={option}>
            <div class="flex">
              {option.label}
            </div>
          </:option>
          <:tag :let={option}>
            {option.label}
          </:tag>
        </.live_select>

        <.live_select
          :if={
            @action in [:new] && @selector == "connections" && has_any_user_connections?(@user) &&
              (@group == "" || is_nil(@group))
          }
          id="post-user-select"
          field={@form[:shared_users]}
          mode={:tags}
          phx-target={@myself}
          phx-focus="set-user-default"
          label="Add people to share with"
          value_mapper={&value_mapper/1}
          clear_button_class="pl-1 text-red-600 hover:text-red-500"
          placeholder="Click to select people or leave blank..."
          dropdown_extra_class="max-h-60 overflow-y-scroll"
        >
          <:option :let={option}>
            <div class="flex">
              <.phx_avatar
                class="mr-2 h-6 w-6 rounded-full"
                src={
                  maybe_get_avatar_src(
                    get_uconn_for_users!(option.value.user_id, @user.id),
                    @user,
                    @key,
                    []
                  )
                }
              />{option.label}
            </div>
          </:option>
          <:tag :let={option}>
            <.phx_avatar
              class="mr-2 h-6 w-6 rounded-full"
              src={
                maybe_get_avatar_src(
                  get_uconn_for_users!(option.value.user_id, @user.id),
                  @user,
                  @key,
                  []
                )
              }
            />{option.label}
          </:tag>
        </.live_select>

        <div :if={
          @action in [:edit] && @selector == "connections" && has_any_user_connections?(@user) &&
            @group == "" && @form.data.shared_users == []
        }>
          <.badge label="Sharing with all of your connections" class="rounded-full" />
        </div>

        <div :if={@action in [:edit] && @group}>
          <.p>
            Sharing with group:
            <.badge
              label={
                decr_item(
                  @group.name,
                  @user,
                  Groups.get_user_group_for_group_and_user(@group, @user).key,
                  @key,
                  @group
                )
              }
              class="rounded-full"
            />
          </.p>
        </div>

        <div
          :if={
            @action in [:edit] && @selector == "connections" && has_any_user_connections?(@user) &&
              @group == "" && @user_list != []
          }
          class="space-x-2"
        >
          <.h5 label="Sharing with" class="rounded-full" />
          <div
            :for={option <- @user_list}
            class="inline-flex bg-gray-100 dark:bg-blue-600 rounded-md py-1 px-1.5"
          >
            <div :if={option.value.user_id != @user.id} class="flex text-gray-700 dark:text-gray-200">
              <.avatar
                class="mr-2 h-6 w-6 rounded-full"
                src={
                  maybe_get_user_avatar(get_uconn_for_users!(option.value.user_id, @user.id), @key)
                }
              />{option.label}
            </div>
            <div :if={option.value.user_id == @user.id} class="flex text-gray-700 dark:text-gray-200">
              <.avatar class="mr-2 h-6 w-6 rounded-full" src={maybe_get_user_avatar(@user, @key)} />{option.label}
            </div>
          </div>
        </div>

        <div :if={@action == :new} id="ignore-trix-editor_new" phx-update="ignore">
          <trix-editor input="trix-editor_new" class="trix-content max-h-64 overflow-y-auto" required>
          </trix-editor>
        </div>

        <.phx_input
          :if={@action == :new}
          field={@form[:image_urls]}
          name={@form[:image_urls].name}
          value={@form[:image_urls].value}
          type="hidden"
        />

        <.phx_input
          :if={@action == :new}
          id="trix-editor_new"
          field={@form[:body]}
          name={@form[:body].name}
          value={@form[:body].value}
          phx-hook="TrixEditor"
          type="hidden"
        />

        <div
          :if={@action == :edit && get_shared_item_identity_atom(@post, @user) == :self}
          id="ignore-trix-editor_edit"
          phx-update="ignore"
        >
          <trix-editor input="trix-editor_edit" class="trix-content max-h-64 overflow-y-auto" required>
          </trix-editor>
        </div>

        <.phx_input
          :if={@action == :edit}
          field={@form[:image_urls]}
          name={@form[:image_urls].name}
          value={@form[:image_urls].value}
          type="hidden"
        />

        <.phx_input
          :if={@action == :edit && get_shared_item_identity_atom(@post, @user) == :self}
          id="trix-editor_edit"
          field={@form[:body]}
          name={@form[:body].name}
          value={
            @body || decr_item(@post.body, @user, get_post_key(@post, @user), @key, @post, "body")
          }
          phx-hook="TrixEditor"
          type="hidden"
        />

        <:actions>
          <div class="group inline-flex items-start space-x-2 text-sm text-gray-500 dark:text-emerald-500">
            <.phx_icon
              name="hero-heart-solid"
              class="size-5 shrink-0 text-gray-400 dark:text-emerald-500"
            />
            <span>Your words are important.</span>
          </div>
          <.button
            :if={@form.source.valid? && !@uploads_in_progress}
            phx-disable-with="Saving..."
            class="rounded-full"
          >
            Save Post
          </.button>

          <button
            :if={!@form.source.valid?}
            type="submit"
            class="inline-flex items-center justify-center rounded-full bg-gray-600 dark:bg-gray-400 px-3 py-2 text-sm font-semibold text-white shadow-sm opacity-20"
            disabled
          >
            Save Post
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
  def update(%{post: post} = assigns, socket) do
    post = Timeline.preload_group(post)
    # when trix editor is being updated it calls this update function
    # so we need to be checking whether to update the changeset
    # because validate won't be called yet
    params = if socket.assigns[:form], do: socket.assigns[:form].source.changes, else: %{}

    params =
      if params do
        params
        |> Map.put(:shared_users, params[:shared_users][:changes] || [])
      else
        %{}
      end

    changeset =
      Timeline.change_post(post, params, user: assigns.user)

    group = Map.get(assigns, :group, Map.get(post, :group, nil))
    key = assigns.key

    if :edit == Map.get(assigns, :action) && post != nil do
      user_list = post.shared_users |> value_mapper_list(assigns.user, key)

      changeset =
        Timeline.change_post(
          post,
          %{
            shared_users:
              Enum.into(user_list, [], fn item ->
                %{
                  id: item.value.id,
                  sender_id: item.value.sender_id,
                  username: item.value.username,
                  user_id: item.value.user_id
                }
              end)
          },
          user: assigns.user
        )

      {:ok,
       socket
       |> assign(:post_key, get_post_key(post, assigns.user))
       |> assign(
         :selector,
         Atom.to_string(post.visibility)
       )
       |> assign(:image_urls, assigns.image_urls)
       |> assign(assigns)
       |> assign(:post, post)
       |> assign(:body, nil)
       |> assign(:trix_key, assigns.trix_key)
       |> assign(:group, group)
       |> assign(:user_list, user_list)
       |> assign_form(changeset)}
    else
      {:ok,
       socket
       |> assign(assigns)
       |> assign(:post, post)
       |> assign(:image_urls, assigns.image_urls)
       |> assign(:user_list, [])
       |> assign(:body, nil)
       |> assign(:trix_key, assigns.trix_key)
       |> assign(
         :group_list,
         build_group_list_for_user(assigns.groups, assigns.user, assigns.key)
       )
       |> assign(:selector, Map.get(assigns, :selector, "connections"))
       |> assign(:group, group)
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    post = socket.assigns.post
    user = socket.assigns.user

    post_params =
      post_params
      |> Map.put("image_urls", socket.assigns.image_urls)

    changeset =
      if post_params["shared_users"] do
        post_params =
          post_params
          |> decode_shared_users_list()

        post
        |> Timeline.change_post(post_params, user: user)
      else
        post
        |> Timeline.change_post(post_params, user: user)
      end

    if post_params["shared_users"] || :edit == Map.get(socket.assigns, :action) do
      user_list =
        socket.assigns.post.shared_users
        |> value_mapper_list(socket.assigns.user, socket.assigns.key)

      {:noreply,
       socket
       |> assign_form(changeset)
       |> assign(:body, post_params["body"])
       |> assign(
         :selector,
         post_params["visibility"] || Atom.to_string(socket.assigns.post.visibility)
       )
       |> assign(:group, post_params["groups"] || socket.assigns.group || nil)
       |> assign(:user_list, post_params["shared_users"] || user_list)}
    else
      {:noreply,
       socket
       |> assign_form(changeset)
       |> assign(
         :selector,
         post_params["visibility"] || Atom.to_string(socket.assigns.post.visibility)
       )
       |> assign(:group, post_params["groups"] || socket.assigns.group || nil)
       |> assign(:user_list, post_params["shared_users"] || [])}
    end
  end

  @impl true
  def handle_event("live_select_change", %{"id" => id, "text" => text}, socket) do
    if id == "group-select" do
      options =
        if text == "" do
          socket.assigns.group_list
        else
          socket.assigns.group_list
          |> Enum.filter(&(String.downcase(&1[:key]) |> String.contains?(String.downcase(text))))
        end

      send_update(LiveSelect.Component, options: options, id: id)

      {:noreply, socket}
    else
      # work with embedded SharedUser schema for LiveSelect
      options =
        socket.assigns.shared_users
        |> Enum.filter(&(String.downcase(&1.username) |> String.contains?(String.downcase(text))))
        |> Enum.map(&value_mapper/1)

      send_update(LiveSelect.Component, options: options, id: id)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set-group-default", %{"id" => id}, socket) do
    options = socket.assigns.group_list

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-group-default", %{"id" => id, "text" => text}, socket) do
    options =
      if text == "" do
        socket.assigns.group_list
      else
        socket.assigns.group_list
        |> Enum.filter(&(String.downcase(&1[:key]) |> String.contains?(String.downcase(text))))
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-user-default", %{"id" => id}, socket) do
    options =
      socket.assigns.shared_users
      |> Enum.map(&value_mapper/1)

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-user-default", %{"id" => id, "text" => text}, socket) do
    options =
      if text == "" do
        socket.assigns.shared_users
      else
        socket.assigns.shared_users
        |> Enum.filter(&(String.downcase(&1[:label]) |> String.contains?(String.downcase(text))))
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    if connected?(socket) do
      post_params =
        if post_params["shared_users"] do
          post_params
          |> decode_shared_users_list()
        else
          if post_params["visibility"] == "connections" do
            shared_users = socket.assigns.shared_users

            post_params
            |> add_shared_users_list(shared_users)
          else
            post_params
          end
        end

      post_params =
        post_params
        |> Map.put("image_urls", socket.assigns.image_urls)
        |> Map.put("image_urls_updated_at", NaiveDateTime.utc_now())

      save_post(socket, socket.assigns.action, post_params)
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

  defp save_post(socket, :edit, post_params) do
    if can_edit?(socket.assigns.user, socket.assigns.post) do
      user = socket.assigns.user
      key = socket.assigns.key
      trix_key = socket.assigns[:trix_key]

      case Timeline.update_post(socket.assigns.post, post_params,
             update_post: true,
             post_key: socket.assigns.post_key,
             user: user,
             key: key,
             trix_key: trix_key
           ) do
        {:ok, post} ->
          notify_parent({:updated, post})

          {:noreply,
           socket
           |> assign(:trix_key, nil)
           |> assign(
             :form,
             to_form(Timeline.change_post(%Post{}, %{}, user: user))
           )
           |> assign(:image_urls, [])
           |> put_flash(:success, "Post updated successfully")
           |> push_patch(to: socket.assigns.patch)}
      end
    else
      {:noreply, socket}
    end
  end

  defp save_post(socket, :new, post_params) do
    user = socket.assigns.user
    key = socket.assigns.key
    trix_key = socket.assigns[:trix_key]

    if post_params["user_id"] == user.id do
      case Timeline.create_post(post_params, user: user, key: key, trix_key: trix_key) do
        {:ok, post} ->
          notify_parent({:saved, post})

          {:noreply,
           socket
           |> assign(:trix_key, nil)
           |> assign(
             :form,
             to_form(Timeline.change_post(%Post{}, %{}, user: user))
           )
           |> assign(:image_urls, [])
           |> put_flash(:success, "Post created successfully")
           |> push_navigate(to: socket.assigns.patch)}
      end
    else
      {:noreply, socket}
    end
  end

  defp save_post(socket, :new_group, post_params) do
    user = socket.assigns.user
    key = socket.assigns.key

    if post_params["user_id"] == user.id do
      case Timeline.create_post(post_params, user: user, key: key) do
        {:ok, post} ->
          notify_parent({:saved, post})

          {:noreply,
           socket
           |> put_flash(:success, "Post created successfully")
           |> push_patch(to: socket.assigns.patch)}
      end
    else
      {:noreply, socket}
    end
  end

  # When post is being shared with all connections, the
  # shared_users is a list of SharedUser structs.
  defp add_shared_users_list(post_params, shared_users) do
    Map.update(
      post_params,
      "shared_users",
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

  defp decode_shared_users_list(post_params) do
    Map.update(post_params, "shared_users", post_params["shared_users"], fn shared_users_list ->
      Enum.map(shared_users_list, fn value ->
        {:ok, value} = Jason.decode(value)
        value
      end)
    end)
  end

  defp build_group_list_for_user(groups, current_user, key) when is_list(groups) do
    Enum.into(groups, [], fn group ->
      user_group = get_user_group(group, current_user)

      [
        key: decr_item(group.name, current_user, user_group.key, key, group),
        value: group.id
      ]
    end)
  end

  defp value_mapper(%Post.SharedUser{username: username} = value) do
    %{label: username, value: value}
  end

  defp value_mapper(value) do
    {:ok, value} = Jason.decode(value)

    %{
      label: value["username"],
      value: %Post.SharedUser{
        id: value["id"],
        sender_id: value["sender_id"],
        user_id: value["user_id"],
        username: value["username"]
      }
    }
  end

  defp value_mapper_list(value, user, key) when is_list(value) do
    Enum.into(value, [], fn struct ->
      uconn = get_uconn_for_users!(struct.user_id, user.id)

      username =
        if is_nil(uconn) do
          decr(user.username, user, key)
        else
          decr_uconn(uconn.connection.username, user, uconn.key, key)
        end

      %{
        label: username,
        value: %Post.SharedUser{
          id: struct.id,
          sender_id: user.id,
          user_id: struct.user_id,
          username: username
        }
      }
    end)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, action: :validate)
    assign(socket, :form, form)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
