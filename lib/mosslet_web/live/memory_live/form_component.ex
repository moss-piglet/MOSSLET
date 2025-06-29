defmodule MossletWeb.MemoryLive.FormComponent do
  use MossletWeb, :live_component

  alias Mosslet.Encrypted
  alias Mosslet.Extensions.MemoryProcessor
  alias MossletWeb.FileUploadComponents
  alias Mosslet.Memories
  alias Mosslet.Memories.Memory

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.page_header title={@title} />

      <div>
        <.p :if={@action == :new}>
          Use this form to create a new Memory.
        </.p>
        <.p :if={@action == :new} class="my-4">
          <.phx_icon name="hero-question-mark-circle" class="size-5" /> Leave the
          <span class="italic font-semibold text-emerald-600 dark:text-emerald-400">
            Add people to share with
          </span>
          selection blank to share with everyone you are connected to.
        </.p>
        <.p :if={@action == :new_memory}>
          Use this form to share a new Memory with @{decr_uconn(
            @user_connection.connection.username,
            @user,
            @user_connection.key,
            @key
          )}.
        </.p>
        <.p :if={@action == :edit}>Use this form to edit your existing Memory.</.p>
      </div>

      <.simple_form
        for={@form}
        id="memory-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.field field={@form[:user_id]} type="hidden" value={@user.id} />
        <.field field={@form[:id]} type="hidden" value={@memory.id} />
        <.field field={@form[:username]} type="hidden" value={decr(@user.username, @user, @key)} />

        <.field
          :if={@action in [:new, :new_memory]}
          field={@form[:visibility]}
          type="hidden"
          value="connections"
        />

        <div
          :if={
            @selector == "connections" && @action in [:new, :new_memory, :edit] &&
              has_any_user_connections?(@user)
          }
          class="space-y-4 mb-6"
        >
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
              @action in [:new] && @selector == "connections" &&
                (has_any_user_connections?(@user) &&
                   @group == "")
            }
            id="memory-user-select"
            field={@form[:shared_users]}
            mode={:tags}
            phx-target={@myself}
            phx-focus="set-user-default"
            label="Add people to share with"
            value_mapper={&value_mapper/1}
            clear_button_class="pl-1 text-red-600 hover:text-red-500"
            placeholder="Click or start typing to select people..."
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
            @action in [:new_memory] && @selector == "connections" &&
              (has_any_user_connections?(@user) &&
                 @group == "")
          }>
            <h2 class="font-semibold text-sm text-gray-800 dark:text-gray-100">Sharing with</h2>
          </div>
          <div
            :if={
              @action in [:new_memory] && @selector == "connections" &&
                (has_any_user_connections?(@user) &&
                   @group == "")
            }
            class="flex min-w-0 gap-x-4"
          >
            <.phx_avatar
              class="size-12 flex-none rounded-full bg-gray-50"
              src={maybe_get_avatar_src(@user_connection, @user, @key, [])}
              alt="shared user avatar"
            />
            <div class="min-w-0 flex-auto">
              <p class="text-sm/6 font-semibold text-gray-900 dark:text-gray-50">
                {@shared_user.username}
              </p>
              <p class="mt-1 truncate text-xs/5 text-gray-500 dark:text-gray-400">
                {@shared_user.email}
              </p>
            </div>
            <.field
              :if={@action == :new_memory}
              field={@form[:shared_user_username]}
              type="hidden"
              value={@shared_user.username}
            />
            <.field
              :if={@action == :new_memory}
              field={@form[:shared_user_id]}
              type="hidden"
              value={@shared_user.user_id}
            />
          </div>

          <.live_select
            :if={
              @action in [:edit] && @selector == "connections" && has_any_user_connections?(@user) &&
                @group == ""
            }
            id="memory-user-select"
            field={@form[:shared_users]}
            mode={:tags}
            phx-target={@myself}
            phx-focus="set-user-default"
            label="Update people shared with"
            value_mapper={&value_mapper/1}
            placeholder="Click or start typing to select people..."
            dropdown_extra_class="max-h-60 overflow-y-scroll"
          >
            <:option :let={option}>
              <div :if={option.value.user_id != @user.id} class="flex">
                <.phx_avatar
                  class="mr-2 h-6 w-6 rounded-full"
                  src={
                    maybe_get_user_avatar(get_uconn_for_users!(option.value.user_id, @user.id), @key)
                  }
                />{option.label}
              </div>
              <div :if={option.value.user_id == @user.id} class="flex">
                <.phx_avatar
                  class="mr-2 h-6 w-6 rounded-full"
                  src={maybe_get_user_avatar(@user, @key)}
                />{option.label}
              </div>
            </:option>
            <:tag :let={option}>
              <span :if={option.value.user_id != @user.id} class="inline-flex">
                <.phx_avatar
                  :if={option.value.user_id != @user.id}
                  class="mr-2 h-6 w-6 rounded-full"
                  src={
                    maybe_get_user_avatar(get_uconn_for_users!(option.value.user_id, @user.id), @key)
                  }
                />{option.label}
              </span>
              <span :if={option.value.user_id == @user.id} class="inline-flex">
                <.phx_avatar
                  class="mr-2 h-6 w-6 rounded-full"
                  src={maybe_get_user_avatar(@user, @key)}
                />{option.label}
              </span>
            </:tag>
          </.live_select>
        </div>

        <FileUploadComponents.image_input
          upload={@uploads.memory}
          label={gettext("Memory")}
          user={@user}
          key={@key}
          placeholder_icon={:photo}
          on_delete="clear_memory"
          automatic_help_text
        />

        <.field
          :if={@action == :new || :new_memory}
          field={@form[:blurb]}
          type="textarea"
          label="Blurb"
          phx-debounce="500"
          help_text="(optional) Write a short descriptive blurb for this Memory."
        />
        <.field
          :if={@action == :edit && @memory.visibility == :private}
          field={@form[:blurb]}
          type="textarea"
          label="Blurb"
          phx-debounce="500"
          value={decr_item(@memory.blurb, @user, get_memory_key(@memory), @key, @memory)}
        />
        <.field
          :if={@action == :edit && @memory.visibility == :public}
          field={@form[:blurb]}
          type="textarea"
          label="Blurb"
          phx-debounce="500"
          value={decr_item(@memory.blurb, @user, get_memory_key(@memory), @key, @memory)}
        />
        <.field
          :if={@action == :edit && get_shared_item_identity_atom(@memory, @user) == :self}
          field={@form[:blurb]}
          type="textarea"
          label="Blurb"
          phx-debounce="500"
          value={decr_item(@memory.blurb, @user, get_memory_key(@memory), @key, @memory)}
        />

        <.button
          :if={
            @form.source.valid? && !Enum.empty?(@uploads.memory.entries) &&
              @action in [:new, :new_memory] && Enum.empty?(@uploads.memory.errors)
          }
          phx-disable-with="Checking, encrypting, and creating..."
          class="rounded-full"
        >
          Create Memory
        </.button>
        <.button
          :if={
            !@form.source.valid? || !Enum.empty?(@uploads.memory.errors) ||
              (Enum.empty?(@uploads.memory.entries) && @action in [:new, :new_memory])
          }
          disabled
          class="opacity-25 rounded-full"
        >
          Create Memory
        </.button>
        <.button
          :if={@form.source.valid? && @action == :edit}
          phx-disable-with="Checking, encrypting, and creating..."
        >
          Update Memory
        </.button>
        <.button :if={!@form.source.valid? && @action == :edit} disabled class="opacity-25">
          Update Memory
        </.button>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{memory: memory} = assigns, socket) do
    changeset = Memories.change_memory(memory, %{}, user: assigns.user)

    socket =
      socket
      |> allow_upload(:memory,
        accept: ~w(.jpg .jpeg .png),
        max_file_size: 10_000_000,
        auto_upload: true,
        temporary_assigns: [uploaded_files: []]
      )

    if :edit == Map.get(assigns, :action) && memory != nil do
      user_list = memory.shared_users |> value_mapper_list(assigns.user, assigns.key)

      changeset =
        Memories.change_memory(memory, %{
          shared_users:
            Enum.into(user_list, [], fn item ->
              %{
                id: item.value.id,
                sender_id: item.value.sender_id,
                username: item.value.username,
                user_id: item.value.user_id
              }
            end)
        })

      {:ok,
       socket
       |> assign(:memory_key, get_memory_key(memory))
       |> assign(
         :selector,
         Atom.to_string(memory.visibility)
       )
       |> assign(assigns)
       |> assign(:group, "")
       |> assign(:user_list, user_list)
       |> assign_form(changeset)}
    else
      {:ok,
       socket
       |> assign(assigns)
       |> assign(:selector, Map.get(assigns, :selector, "connections"))
       |> assign(
         :group_list,
         build_group_list_for_user(assigns.groups, assigns.user, assigns.key)
       )
       |> assign(:user_list, build_user_list(assigns.shared_users, assigns.user))
       |> assign(:group, "")
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :memory, ref)}
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

  @impl true
  def handle_event("validate", %{"memory" => memory_params}, socket) do
    changeset =
      if memory_params["shared_users"] do
        memory_params =
          memory_params
          |> decode_shared_users_list()

        socket.assigns.memory
        |> Memories.change_memory(memory_params, user: socket.assigns.user)
        |> Map.put(:action, :validate)
      else
        socket.assigns.memory
        |> Memories.change_memory(memory_params, user: socket.assigns.user)
        |> Map.put(:action, :validate)
      end

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign(:selector, memory_params["visibility"])
     |> assign(:group, memory_params["groups"] || "")
     |> assign(:user_list, memory_params["shared_users"] || [])}
  end

  def handle_event("save", %{"memory" => memory_params}, socket) do
    memory_params =
      if memory_params["shared_users"] do
        memory_params
        |> decode_shared_users_list()
      else
        if memory_params["visibility"] == "connections" do
          shared_users = socket.assigns.shared_users

          memory_params
          |> add_shared_users_list(shared_users)
        else
          memory_params
        end
      end

    save_memory(socket, socket.assigns.action, memory_params)
  end

  defp save_memory(socket, :new, memory_params) do
    user = socket.assigns.user
    key = socket.assigns.key
    memories_bucket = Encrypted.Session.memories_bucket()
    options = socket.assigns[:options]

    # patch comes in from the User Connection show page
    return_url = socket.assigns.patch

    memory_url_tuple_list =
      consume_uploaded_entries(
        socket,
        :memory,
        fn %{path: path} = _meta, entry ->
          # Check the mime_type to avoid malicious file naming
          mime_type = ExMarcel.MimeType.for({:path, path})

          cond do
            mime_type in ["image/jpeg", "image/jpg", "image/png"] ->
              with {:ok, image_binary} <-
                     Image.open!(path)
                     |> check_for_safety(),
                   {:ok, blob} <-
                     Image.write(image_binary, :memory, suffix: ".#{file_ext(entry)}"),
                   {:ok, e_blob, d_conn_key} <- prepare_encrypted_blob(blob),
                   {:ok, file_path} <- prepare_file_path(entry, user.id) do
                make_aws_requests(
                  entry,
                  memories_bucket,
                  file_path,
                  e_blob,
                  d_conn_key,
                  user,
                  key
                )
              else
                {:nsfw, message} ->
                  {:postpone, {:nsfw, message}}

                {:error, message} ->
                  {:postpone, {:error, message}}
              end

            true ->
              {:postpone, {:error, "Incorrect file type."}}
          end
        end
      )

    case memory_url_tuple_list do
      [nsfw: message] ->
        {:noreply,
         socket
         |> put_flash(:warning, message)
         |> push_patch(to: return_url)}

      [error: message] ->
        {:noreply,
         socket
         |> put_flash(:warning, message)
         |> push_patch(to: return_url)}

      [:error] ->
        {:noreply,
         socket
         |> put_flash(:warning, "Incorrect file type.")
         |> push_patch(to: return_url)}

      [{entry, file_path, e_blob, d_conn_key}] ->
        # Return the encrypted blob and user_params map
        group_id = memory_params["groups"]

        memory_params =
          memory_params
          |> Map.put("memory_url", file_path)
          |> Map.put("size", entry.client_size)
          |> Map.put("type", entry.client_type)
          |> Map.put("group_id", group_id)

        maybe_create_public_memory(
          memory_params,
          user,
          key,
          d_conn_key,
          e_blob,
          options,
          return_url,
          socket
        )

      _rest ->
        {:noreply,
         socket
         |> put_flash(
           :warning,
           "There was an error trying to upload your image, please try a different image."
         )
         |> push_patch(to: return_url)}
    end
  end

  # used when saving a memory from the User Connection
  # show page.
  defp save_memory(socket, :new_memory, memory_params) do
    user = socket.assigns.user
    key = socket.assigns.key
    memories_bucket = Encrypted.Session.memories_bucket()
    options = socket.assigns[:options]

    # patch comes in from the User Connection show page
    return_url = socket.assigns.patch

    memory_url_tuple_list =
      consume_uploaded_entries(
        socket,
        :memory,
        fn %{path: path} = _meta, entry ->
          # Check the mime_type to avoid malicious file naming
          mime_type = ExMarcel.MimeType.for({:path, path})

          cond do
            mime_type in ["image/jpeg", "image/jpg", "image/png"] ->
              with {:ok, image_binary} <-
                     Image.open!(path)
                     |> check_for_safety(),
                   {:ok, blob} <-
                     Image.write(image_binary, :memory, suffix: ".#{file_ext(entry)}"),
                   {:ok, e_blob, d_conn_key} <- prepare_encrypted_blob(blob),
                   {:ok, file_path} <- prepare_file_path(entry, user.id) do
                make_aws_requests(
                  entry,
                  memories_bucket,
                  file_path,
                  e_blob,
                  d_conn_key,
                  user,
                  key
                )
              else
                {:nsfw, message} ->
                  {:postpone, {:nsfw, message}}

                {:error, message} ->
                  {:postpone, {:error, message}}
              end

            true ->
              {:postpone, {:error, "Incorrect file type."}}
          end
        end
      )

    case memory_url_tuple_list do
      [nsfw: message] ->
        {:noreply,
         socket
         |> put_flash(:warning, message)
         |> push_patch(to: return_url)}

      [error: message] ->
        {:noreply,
         socket
         |> put_flash(:warning, message)
         |> push_patch(to: return_url)}

      [:error] ->
        {:noreply,
         socket
         |> put_flash(:warning, "Incorrect file type.")
         |> push_patch(to: return_url)}

      [{entry, file_path, e_blob, d_conn_key}] ->
        # Return the encrypted blob and user_params map
        group_id = memory_params["groups"]

        memory_params =
          memory_params
          |> Map.put("memory_url", file_path)
          |> Map.put("size", entry.client_size)
          |> Map.put("type", entry.client_type)
          |> Map.put("group_id", group_id)

        maybe_create_public_memory(
          memory_params,
          user,
          key,
          d_conn_key,
          e_blob,
          options,
          return_url,
          socket
        )

      _rest ->
        {:noreply,
         socket
         |> put_flash(
           :warning,
           "There was an error trying to upload your image, please try a different image."
         )
         |> push_patch(to: return_url)}
    end
  end

  defp save_memory(socket, :edit, memory_params) do
    if can_edit?(socket.assigns.user, socket.assigns.memory) do
      user = socket.assigns.user
      key = socket.assigns.key

      case Memories.update_memory(socket.assigns.memory, memory_params,
             update_memory: true,
             memory_key: socket.assigns.memory_key,
             user: user,
             key: key
           ) do
        {:ok, memory} ->
          notify_parent({:updated, memory})

          {:noreply,
           socket
           |> put_flash(:success, "Memory updated successfully")
           |> push_navigate(to: socket.assigns.patch)}
      end
    else
      {:noreply, socket}
    end
  end

  defp maybe_create_public_memory(
         memory_params,
         user,
         key,
         d_conn_key,
         e_blob,
         options,
         return_url,
         socket
       ) do
    if memory_params["visibility"] == "public" || memory_params["visibility"] == :public do
      case Memories.create_public_memory(memory_params,
             user: user,
             key: key,
             temp_key: d_conn_key
           ) do
        {:ok, _conn, memory} ->
          # Put the encrypted memory blob in ets under the
          # user's user_memory id.
          user_memory = Memories.get_public_user_memory(memory)

          MemoryProcessor.put_ets_memory(
            "user:#{memory_params["user_id"]}-memory:#{memory_params["id"]}-key:#{user_memory.id}",
            e_blob
          )

          info = "Your public memory has been created successfully. View it on your profile page."

          # rebuild the memory_list
          memories = Memories.list_public_memories(socket.assigns.user, options)
          loading_list = Enum.with_index(memories, fn element, index -> {index, element} end)

          memory_form =
            memory
            |> Memories.change_memory(memory_params)
            |> to_form()

          {:noreply,
           socket
           |> put_flash(:success, info)
           |> assign(loading_list: loading_list)
           |> assign(memory_form: memory_form)
           |> push_patch(to: return_url)}

        _rest ->
          {:noreply, socket}
      end
    else
      case Memories.create_memory(memory_params, user: user, key: key, temp_key: d_conn_key) do
        {:ok, memory} ->
          # Put the encrypted memory blob in ets under the
          # user's user_memory id.
          # user_memory = Memories.get_user_memory(memory, user)

          # MemoryProcessor.put_ets_memory(
          #  "user:#{memory_params["user_id"]}-memory:#{memory_params["id"]}-key:#{user_memory.id}",
          #  e_blob
          # )

          if memory.group_id do
            info = "Your memory has been created successfully."

            {:noreply,
             socket
             |> put_flash(:success, info)
             |> push_navigate(to: ~p"/app/groups/#{memory.group_id}")}
          else
            # notify_parent({:saved, memory})

            info = "Your memory has been created successfully."

            # rebuild the memory_list
            # memories =
            # Memories.filter_memories_shared_with_current_user(socket.assigns.user.id, options)

            # loading_list = Enum.with_index(memories, fn element, index -> {index, element} end)

            memory_form =
              memory
              |> Memories.change_memory(memory_params)
              |> to_form()

            {:noreply,
             socket
             |> put_flash(:success, info)
             # |> assign(loading_list: loading_list)
             |> assign(memory_form: memory_form)
             |> push_patch(to: return_url)}
          end

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "There was an error creating your memory.")
           |> assign_form(changeset)
           |> push_patch(to: return_url)}
      end
    end
  end

  defp check_for_safety(image_binary) do
    Mosslet.AI.Images.check_for_safety(image_binary)
  end

  ## PRIVATE & AWS

  defp decode_shared_users_list(memory_params) do
    Map.update(
      memory_params,
      "shared_users",
      memory_params["shared_users"],
      fn shared_users_list ->
        Enum.map(shared_users_list, fn value ->
          {:ok, value} = Jason.decode(value)

          value
        end)
      end
    )
  end

  # When memory is being shared with all connections, the
  # shared_users is a list of SharedUser structs.
  defp add_shared_users_list(memory_params, shared_users) do
    Map.update(
      memory_params,
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

  defp build_group_list_for_user(groups, current_user, key) when is_list(groups) do
    Enum.into(groups, [], fn group ->
      user_group = get_user_group(group, current_user)

      [
        key: decr_item(group.name, current_user, user_group.key, key, group),
        value: group.id
      ]
    end)
  end

  # only used right now for :new_memory action which
  # is coming from the User Connection show page and
  # will have a list of who the memory is to be shared with.
  # the data is already decrypted from the User Connection show page.
  #
  # it's just to be shared with one user
  defp build_user_list(shared_users, current_user) do
    if is_nil(shared_users) do
      []
    else
      options =
        Enum.into(shared_users, [], fn shared_user ->
          {:ok, value} =
            %{
              id: nil,
              sender_id: current_user.id,
              username: shared_user.username,
              user_id: shared_user.user_id
            }
            |> Jason.encode()

          value
        end)

      send_update(LiveSelect.Component,
        id: "new-memory-user-select",
        value: options
      )

      options
    end
  end

  defp value_mapper(%Memory.SharedUser{username: username} = value) do
    %{label: username, value: value}
  end

  defp value_mapper(value) do
    {:ok, value} = Jason.decode(value)

    %{
      label: value["username"],
      value: %Memory.SharedUser{
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
      username = decr_uconn(uconn.connection.username, user, uconn.key, key)

      %{
        label: username,
        value: %Memory.SharedUser{
          id: struct.id,
          sender_id: user.id,
          user_id: struct.user_id,
          username: username
        }
      }
    end)
  end

  defp file_ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{ext}"
  end

  defp filename(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{entry.uuid}.#{ext}"
  end

  defp prepare_file_path(entry, connection_id) do
    {:ok, "uploads/user/#{connection_id}/memories/#{filename(entry)}"}
  end

  defp prepare_encrypted_blob(blob) do
    d_conn_key = Encrypted.Utils.generate_key()

    encrypted_avatar_blob = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: blob})

    {:ok, encrypted_avatar_blob, d_conn_key}
  end

  defp make_aws_requests(entry, memories_bucket, file_path, e_blob, d_conn_key, _user, _key) do
    case ex_aws_put_request(memories_bucket, file_path, e_blob) do
      # Return the encrypted_blob in the tuple for putting
      # the encrypted avatar into ets.
      {:ok, _resp} ->
        {:ok, {entry, file_path, e_blob, d_conn_key}}

      _rest ->
        ex_aws_put_request(memories_bucket, file_path, e_blob)
        {:ok, {entry, file_path, e_blob, d_conn_key}}
    end
  end

  defp ex_aws_put_request(memories_bucket, file_path, e_blob) do
    ExAws.S3.put_object(memories_bucket, file_path, e_blob)
    |> ExAws.request()
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
