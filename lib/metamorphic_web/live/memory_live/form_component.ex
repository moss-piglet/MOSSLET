defmodule MetamorphicWeb.MemoryLive.FormComponent do
  use MetamorphicWeb, :live_component

  alias Metamorphic.Encrypted
  alias Metamorphic.Extensions.MemoryProcessor
  alias Metamorphic.Memories

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle :if={@action == :new}>Use this form to create a new memory.</:subtitle>
        <:subtitle :if={@action == :edit}>Use this form to edit your existing memory.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="memory-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:user_id]} type="hidden" value={@user.id} />
        <.input field={@form[:id]} type="hidden" value={@memory.id} />
        <.input field={@form[:username]} type="hidden" value={decr(@user.username, @user, @key)} />
        <.input
          :if={@action != :edit}
          field={@form[:visibility]}
          type="select"
          options={Ecto.Enum.values(Memories.Memory, :visibility)}
          label="Visibility"
          required
        />

        <div
          :if={@selector == "connections" && @action != :edit && has_any_user_connections?(@user)}
          class="space-y-4 mb-6"
        >
          <p class="font-light text-zinc-800">
            Add or remove people to share with (you must be connected to them). To share with all of your connections, use the "x" to remove any open fields:
          </p>

          <div id="shared_users" phx-hook="SortableInputsFor" class="space-y-2">
            <.inputs_for :let={f_nested} field={@form[:shared_users]}>
              <div class="relative flex space-x-2 drag-item">
                <input type="hidden" name="memory[shared_users_order][]" value={f_nested.index} />
                <.input type="hidden" field={f_nested[:sender_id]} value={@user.id} />
                <.input
                  type="text"
                  field={f_nested[:username]}
                  placeholder="Enter username"
                  autocomplete="off"
                />
                <label class="cursor-pointer">
                  <input
                    type="checkbox"
                    name="memory[shared_users_delete][]"
                    value={f_nested.index}
                    class="hidden"
                  />

                  <.icon name="hero-x-mark" class="w-6 h-6 absolute top-4" />
                </label>
              </div>
            </.inputs_for>
          </div>

          <label class="block cursor-pointer">
            <input type="checkbox" name="memory[shared_users_order][]" class="hidden" />
            <.icon name="hero-plus-circle" /> add more
          </label>

          <input type="hidden" name="memory[shared_users_delete][]" />
        </div>

        <div :if={@action == :new} class="col-span-full">
          <div
            class="mt-2 flex justify-center rounded-lg border border-dashed border-zinc-900/25 px-6 py-10"
            phx-drop-target={@uploads.memory.ref}
          >
            <div :if={Enum.empty?(@uploads.memory.entries)} class="text-center">
              <svg
                class="mx-auto h-12 w-12 text-zinc-300"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M1.5 6a2.25 2.25 0 012.25-2.25h16.5A2.25 2.25 0 0122.5 6v12a2.25 2.25 0 01-2.25 2.25H3.75A2.25 2.25 0 011.5 18V6zM3 16.06V18c0 .414.336.75.75.75h16.5A.75.75 0 0021 18v-1.94l-2.69-2.689a1.5 1.5 0 00-2.12 0l-.88.879.97.97a.75.75 0 11-1.06 1.06l-5.16-5.159a1.5 1.5 0 00-2.12 0L3 16.061zm10.125-7.81a1.125 1.125 0 112.25 0 1.125 1.125 0 01-2.25 0z"
                  clip-rule="evenodd"
                />
              </svg>
              <div class="mt-4 flex text-sm leading-6 text-zinc-600">
                <label
                  for={@uploads.memory.ref}
                  class="relative cursor-pointer rounded-md bg-white font-semibold text-brand-600 focus-within:outline-none focus-within:ring-2 focus-within:ring-brand-600 focus-within:ring-offset-2 hover:text-brand-500"
                >
                  <span>Upload a memory</span>
                </label>
                <p class="pl-1">or drag and drop</p>
              </div>
              <p class="text-xs leading-5 text-zinc-600">
                PNG, JPEG, JPG up to <%= @uploads.memory.max_file_size / 1_000_000 %>MB
              </p>
            </div>
            <div
              :for={entry <- @uploads.memory.entries}
              :if={!Enum.empty?(@uploads.memory.entries)}
              class="text-center text-brand-600"
            >
              <.live_img_preview entry={entry} width={100} />
              <div class="w-full">
                <div class="text-left mb-2 text-xs font-semibold inline-block text-brand-600">
                  <%= entry.progress %>%
                </div>
                <div class="flex h-2 overflow-hidden text-base bg-brand-200 rounded-lg mb-4">
                  <span
                    style={"width: #{entry.progress}%"}
                    class="shadow-md bg-brand-500 transition-transform"
                  >
                  </span>
                </div>
              </div>

              <.link phx-click="cancel" phx-target={@myself} phx-value-ref={entry.ref}>
                <.icon name="hero-x-circle" class="h-6 w-6" />
              </.link>
            </div>
          </div>
          <.error :for={err <- upload_errors(@uploads.memory)}>
            <%= error_to_string(err) %>
          </.error>
        </div>
        <.live_file_input :if={@action == :new} upload={@uploads.memory} />

        <.input :if={@action == :new} field={@form[:blurb]} type="textarea" label="Blurb" />
        <.input
          :if={@action == :edit && @memory.visibility == :private}
          field={@form[:blurb]}
          type="textarea"
          label="Blurb"
          value={decr_item(@memory.blurb, @user, get_memory_key(@memory), @key, @memory)}
        />
        <.input
          :if={@action == :edit && @memory.visibility == :public}
          field={@form[:blurb]}
          type="textarea"
          label="Blurb"
          value={decr_item(@memory.blurb, @user, get_memory_key(@memory), @key, @memory)}
        />
        <.input
          :if={@action == :edit && get_shared_item_identity_atom(@memory, @user) == :self}
          field={@form[:blurb]}
          type="textarea"
          label="Blurb"
          value={decr_item(@memory.blurb, @user, get_memory_key(@memory), @key, @memory)}
        />
        <:actions>
          <.button
            :if={@form.source.valid? && !Enum.empty?(@uploads.memory.entries) && @action == :new}
            phx-disable-with="Creating..."
          >
            Create Memory
          </.button>
          <.button
            :if={!@form.source.valid? || (Enum.empty?(@uploads.memory.entries) && @action == :new)}
            disabled
            class="opacity-25"
          >
            Create Memory
          </.button>
          <.button :if={@form.source.valid? && @action == :edit} phx-disable-with="Creating...">
            Update Memory
          </.button>
          <.button :if={!@form.source.valid? && @action == :edit} disabled class="opacity-25">
            Update Memory
          </.button>
        </:actions>
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
        accept: ~w(.png .jpeg .jpg),
        max_file_size: 10_000_000,
        auto_upload: true,
        temporary_assigns: [uploaded_files: []]
      )

    if :edit == Map.get(assigns, :action) && memory != nil do
      {:ok,
       socket
       |> assign(:memory_key, get_memory_key(memory))
       |> assign(
         :selector,
         Atom.to_string(memory.visibility)
       )
       |> assign(assigns)
       |> assign_form(changeset)}
    else
      {:ok,
       socket
       |> assign(assigns)
       |> assign(:selector, Map.get(assigns, :selector, "private"))
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :memory, ref)}
  end

  @impl true
  def handle_event("validate", %{"memory" => memory_params}, socket) do
    changeset =
      socket.assigns.memory
      |> Memories.change_memory(memory_params, user: socket.assigns.user)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign_form(changeset) |> assign(:selector, memory_params["visibility"])}
  end

  def handle_event("save", %{"memory" => memory_params}, socket) do
    save_memory(socket, socket.assigns.action, memory_params)
  end

  defp save_memory(socket, :new, memory_params) do
    if Memories.get_count(socket.assigns.user) < socket.assigns.plan_memories do
      user = socket.assigns.user
      key = socket.assigns.key
      memories_bucket = Encrypted.Session.memories_bucket()

      memory_url_tuple_list =
        consume_uploaded_entries(
          socket,
          :memory,
          fn %{path: path} = _meta, entry ->
            # Check the mime_type to avoid malicious file naming
            mime_type = ExMarcel.MimeType.for({:path, path})

            cond do
              mime_type in ["image/jpeg", "image/jpg", "image/png"] ->
                with {:ok, blob} <-
                       Image.open!(path)
                       |> Image.write(:memory,
                         suffix: ".#{file_ext(entry)}"
                       ),
                     {:ok, e_blob} <- prepare_encrypted_blob(blob, user, key),
                     {:ok, file_path} <- prepare_file_path(entry, user.id) do
                  make_aws_requests(entry, memories_bucket, file_path, e_blob, user, key)
                end

              true ->
                {:postpone, :error}
            end
          end
        )

      cond do
        :error in memory_url_tuple_list ->
          err_msg = "Incorrect file type."
          {:noreply, put_flash(socket, :error, err_msg)}

        :error not in memory_url_tuple_list ->
          # Get the file path & e_blob from the tuple.
          [{entry, file_path, e_blob}] = memory_url_tuple_list

          memory_params =
            memory_params
            |> Map.put("memory_url", file_path)
            |> Map.put("size", entry.client_size)
            |> Map.put("type", entry.client_type)

          case Memories.create_memory(memory_params, user: user, key: key) do
            {:ok, conn, memory} ->
              # Put the encrypted memory blob in ets under the
              # user's connection id.
              MemoryProcessor.put_ets_memory(
                "user:#{memory_params["user_id"]}-memory:#{memory_params["id"]}-key:#{conn.id}",
                e_blob
              )

              notify_parent({:saved, memory})

              info = "Your memory has been created successfully."

              memory_form =
                memory
                |> Memories.change_memory(memory_params)
                |> to_form()

              {:noreply,
               socket
               |> put_flash(:success, info)
               |> assign(memory_form: memory_form)
               |> push_navigate(to: ~p"/memories")}

            _rest ->
              {:noreply, socket}
          end
      end
    else
      info =
        "You have uploaded your maximum number of Memories for your current subscription plan. Please upgrade your subscription or delete some Memories to upload more."

      {:noreply,
       socket
       |> put_flash(
         :info,
         info
       )
       |> push_navigate(to: ~p"/memories")}
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

  ## PRIVATE & AWS

  defp file_ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{ext}"
  end

  defp filename(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{entry.uuid}.#{ext}"
  end

  defp prepare_file_path(entry, user_id) do
    {:ok, "uploads/user/#{user_id}/memories/#{filename(entry)}"}
  end

  defp prepare_encrypted_blob(blob, user, key) do
    {:ok, d_conn_key} =
      Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

    encrypted_avatar_blob = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: blob})

    cond do
      is_binary(encrypted_avatar_blob) ->
        {:ok, encrypted_avatar_blob}

      true ->
        {:error, encrypted_avatar_blob}
    end
  end

  defp make_aws_requests(entry, memories_bucket, file_path, e_blob, _user, _key) do
    with {:ok, _resp} <- ex_aws_put_request(memories_bucket, file_path, e_blob) do
      # Return the encrypted_blob in the tuple for putting
      # the encrypted avatar into ets.
      {:ok, {entry, file_path, e_blob}}
    else
      _rest ->
        ex_aws_put_request(memories_bucket, file_path, e_blob)
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
