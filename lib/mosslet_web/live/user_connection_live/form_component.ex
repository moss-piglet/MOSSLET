defmodule MossletWeb.UserConnectionLive.FormComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias Mosslet.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-6 py-6 bg-white dark:bg-gray-900 rounded-lg shadow-sm">
      <div class="mb-6">
        <h2 class="text-xl font-semibold leading-7 text-gray-900 dark:text-white">
          {@title}
        </h2>
        <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
          <span :if={@action == :new}>
            Connect with someone new to start sharing memories and posts.
          </span>
          <span :if={@action == :edit}>Update your connection settings and preferences.</span>
        </p>
      </div>

      <.form
        :if={@action == :new}
        for={@form}
        id="uconn-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <.phx_input field={@form[:connection_id]} type="hidden" value={@user.connection.id} />
        <.phx_input field={@form[:user_id]} type="hidden" value={@recipient_id} />
        <.phx_input field={@form[:reverse_user_id]} type="hidden" value={@user.id} />
        <.phx_input field={@form[:request_username]} type="hidden" value={@request_username} />
        <.phx_input field={@form[:request_email]} type="hidden" value={@request_email} />
        <.phx_input field={@form[:key]} type="hidden" value={@recipient_key} />
        <.phx_input field={@form[:label]} type="hidden" />

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.phx_input
            field={@form[:temp_label]}
            type="text"
            label="Label"
            placeholder="Family, friend, partner, et al"
            apply_classes?={true}
            classes="block w-full rounded-md border-0 py-2 px-3 text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800"
            {alpine_autofocus()}
          />

          <.phx_input
            field={@form[:color]}
            type="color_select"
            label="Color"
            prompt="Choose label color"
            options={
              Enum.map(Ecto.Enum.values(Accounts.UserConnection, :color), fn x ->
                [
                  key: x |> Atom.to_string() |> String.capitalize(),
                  value: x
                ]
              end)
            }
          />
        </div>

        <.phx_input
          field={@form[:selector]}
          type="select"
          label="Find by"
          prompt="Choose how to find"
          options={[Username: "username", Email: "email"]}
          apply_classes?={true}
          classes="block w-full rounded-md border-0 py-2 px-3 text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800"
        />

        <.phx_input
          :if={@selector == "email"}
          field={@form[:email]}
          type="email"
          label="Email"
          autocomplete="off"
          phx-debounce="500"
          placeholder="Enter their email address"
          apply_classes?={true}
          classes="block w-full rounded-md border-0 py-2 px-3 text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800"
        />

        <.phx_input
          :if={@selector == "username"}
          field={@form[:username]}
          type="text"
          label="Username"
          autocomplete="off"
          phx-debounce="500"
          placeholder="Enter their username"
          apply_classes?={true}
          classes="block w-full rounded-md border-0 py-2 px-3 text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800"
        />

        <div class="flex justify-end pt-6">
          <button
            :if={@form.source.valid?}
            type="submit"
            class="inline-flex items-center rounded-full bg-gradient-to-r from-teal-500 to-emerald-500 px-6 py-3 text-sm font-semibold text-white shadow-lg hover:scale-105 transform transition-all duration-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
            phx-disable-with="Sending..."
          >
            <.phx_icon name="hero-paper-airplane" class="size-4 mr-2" /> Send Connection Request
          </button>
          <button
            :if={!@form.source.valid?}
            type="submit"
            disabled
            class="inline-flex items-center opacity-50 cursor-not-allowed rounded-full py-3 px-6 text-sm font-semibold bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 shadow-sm"
          >
            <.phx_icon name="hero-paper-airplane" class="size-4 mr-2" /> Send Connection Request
          </button>
        </div>
      </.form>

      <.form
        :if={@action == :edit}
        for={@form}
        id="uconn-edit-form"
        phx-target={@myself}
        phx-change="validate_update"
        phx-submit="update"
        class="space-y-6"
      >
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.phx_input
            field={@form[:temp_label]}
            type="text"
            label="New label"
            value={@temp_label}
            placeholder="Family, friend, partner, et al"
            apply_classes?={true}
            classes="block w-full rounded-md border-0 py-2 px-3 text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-gray-600 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-emerald-600 sm:text-sm sm:leading-6 dark:bg-gray-800"
          />

          <.phx_input
            field={@form[:color]}
            type="color_select"
            label="Color"
            prompt="Choose label color"
            options={
              Enum.map(Ecto.Enum.values(Accounts.UserConnection, :color), fn x ->
                [
                  key: x |> Atom.to_string() |> String.capitalize(),
                  value: x
                ]
              end)
            }
          />
        </div>

        <.phx_input
          field={@form[:photos?]}
          type="checkbox"
          label="Memory mode"
        >
          <:description_block>
            Allow this person to be able to download and save any Memories you share with them.
          </:description_block>
        </.phx_input>

        <.phx_input field={@form[:label]} type="hidden" />
        <.phx_input field={@form[:id]} type="hidden" value={@uconn.id} />

        <div class="flex justify-end pt-6">
          <button
            :if={@form.source.valid?}
            type="submit"
            class="inline-flex items-center rounded-full bg-gradient-to-r from-teal-500 to-emerald-500 px-6 py-3 text-sm font-semibold text-white shadow-lg hover:scale-105 transform transition-all duration-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
            phx-disable-with="Updating..."
          >
            <.phx_icon name="hero-check" class="size-4 mr-2" /> Update Connection
          </button>
          <button
            :if={!@form.source.valid?}
            type="submit"
            disabled
            class="inline-flex items-center opacity-50 cursor-not-allowed rounded-full py-3 px-6 text-sm font-semibold bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 shadow-sm"
          >
            <.phx_icon name="hero-check" class="size-4 mr-2" /> Update Connection
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{uconn: uconn} = assigns, socket) do
    changeset = Accounts.change_user_connection(uconn, %{}, selector: nil)
    current_user = assigns.user
    key = assigns.key

    if :edit == Map.get(assigns, :action) do
      {:ok,
       socket
       |> assign(:temp_label, decr_uconn(uconn.label, current_user, uconn.key, key))
       |> assign(assigns)
       |> assign_form(changeset)}
    else
      {:ok,
       socket
       |> assign(:recipient_key, nil)
       |> assign(:recipient_id, nil)
       |> assign(:request_email, nil)
       |> assign(:request_username, nil)
       |> assign(:temp_label, nil)
       |> assign(:selector, nil)
       |> assign(assigns)
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("validate_update", %{"user_connection" => uconn_params}, socket) do
    user = socket.assigns.user
    key = socket.assigns.key
    temp_label = socket.assigns.temp_label

    changeset =
      socket.assigns.uconn
      |> Accounts.edit_user_connection(uconn_params,
        selector: nil,
        user: user,
        key: key,
        conn_key: decr_attrs_key(user.conn_key, user, socket.assigns.key)
      )
      |> Map.put(:action, :validate)

    if Map.has_key?(changeset.changes, :user_id) do
      {:noreply,
       socket
       |> assign_form(changeset)
       |> assign(:temp_label, Ecto.Changeset.get_change(changeset, :temp_label) || temp_label)}
    else
      {:noreply,
       socket
       |> assign(:temp_label, Ecto.Changeset.get_change(changeset, :temp_label) || temp_label)
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"user_connection" => uconn_params}, socket) do
    user = socket.assigns.user
    key = socket.assigns.key

    changeset =
      socket.assigns.uconn
      |> Accounts.change_user_connection(uconn_params,
        selector: uconn_params["selector"],
        user: user,
        key: key
      )
      |> Map.put(:action, :validate)

    if Map.has_key?(changeset.changes, :user_id) do
      {:noreply,
       socket
       |> assign_form(changeset)
       |> assign(:request_email, changeset.changes.request_email)
       |> assign(:request_username, changeset.changes.request_username)
       |> assign(:recipient_key, changeset.changes.key)
       |> assign(:recipient_id, changeset.changes.user_id)
       |> assign(:temp_label, Ecto.Changeset.get_change(changeset, :temp_label))
       |> assign(:selector, uconn_params["selector"])}
    else
      {:noreply,
       socket
       |> assign_form(changeset)
       |> assign(:selector, uconn_params["selector"])}
    end
  end

  @impl true
  def handle_event("save", %{"user_connection" => uconn_params}, socket) do
    user = socket.assigns.user
    key = socket.assigns.key

    case Accounts.create_user_connection(uconn_params, user: user, key: key) do
      {:ok, uconn} ->
        notify_parent({:saved, uconn})

        {:noreply,
         socket
         |> put_flash(:success, "Connection request sent successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("update", %{"user_connection" => uconn_params}, socket) do
    user = socket.assigns.user
    key = socket.assigns.key
    uconn = Accounts.get_user_connection!(uconn_params["id"])
    d_conn_key = decr_attrs_key(uconn.key, user, key)

    case Accounts.update_user_connection(uconn, uconn_params,
           user: user,
           key: key,
           conn_key: d_conn_key,
           temp_label: uconn_params["temp_label"]
         ) do
      {:ok, _uconn} ->
        # notify_parent({:updated, uconn})

        {:noreply,
         socket
         |> clear_flash(:success)
         |> put_flash(:success, "Connection updated successfully.")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
