defmodule MossletWeb.UserConnectionLive.FormComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias Mosslet.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.page_header title={@title} />

      <div class="pb-4">
        <.p :if={@action == :new}>Use this form to request a new connection.</.p>
        <.p :if={@action == :edit}>Use this form to edit your existing connection.</.p>
      </div>
      <.form
        :if={@action == :new}
        for={@form}
        id="uconn-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.field field={@form[:connection_id]} type="hidden" value={@user.connection.id} />
        <.field field={@form[:user_id]} type="hidden" value={@recipient_id} />
        <.field field={@form[:reverse_user_id]} type="hidden" value={@user.id} />
        <.field field={@form[:request_username]} type="hidden" value={@request_username} />
        <.field field={@form[:request_email]} type="hidden" value={@request_email} />
        <.field field={@form[:key]} type="hidden" value={@recipient_key} />
        <.field field={@form[:label]} type="hidden" />

        <div class="inline-flex items-center space-x-4 dark:text-gray-300">
          <.field
            field={@form[:temp_label]}
            type="text"
            label="Label"
            placeholder="Family, friend, partner, et al"
            {alpine_autofocus()}
          />

          <.field
            field={@form[:color]}
            type="select"
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
            data-label="label"
          />
        </div>

        <.field
          field={@form[:selector]}
          type="select"
          label="Find by"
          prompt="Choose how to find"
          options={[Username: "username", Email: "email"]}
        />

        <.field
          :if={@selector == "email"}
          field={@form[:email]}
          type="email"
          label="Email"
          autocomplete="off"
          phx-debounce="500"
        />

        <.field
          :if={@selector == "username"}
          field={@form[:username]}
          type="text"
          label="Username"
          autocomplete="off"
          phx-debounce="500"
        />

        <.button :if={@form.source.valid?} class="rounded-full" phx-disable-with="Sending...">
          Send
        </.button>
        <.button :if={!@form.source.valid?} disabled class="opacity-25 rounded-full">
          Send
        </.button>
      </.form>

      <.form
        :if={@action == :edit}
        for={@form}
        id="uconn-edit-form"
        phx-target={@myself}
        phx-change="validate_update"
        phx-submit="update"
      >
        <div class="inline-flex items-center space-x-4">
          <.field
            field={@form[:temp_label]}
            type="text"
            label="New label"
            value={@temp_label}
            placeholder="Family, friend, partner, et al"
          />

          <.field
            field={@form[:color]}
            type="select"
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
            data-label="label"
          />
        </div>
        <.field
          field={@form[:photos?]}
          type="checkbox"
          label="Memory mode"
          help_text="Allow this person to be able to download and save any Memories you share with them."
        />

        <.field field={@form[:label]} type="hidden" />
        <.field field={@form[:id]} type="hidden" value={@uconn.id} />

        <.button :if={@form.source.valid?} class="rounded-full" phx-disable-with="Updating...">
          Update
        </.button>
        <.button :if={!@form.source.valid?} disabled class="opacity-25 rounded-full">
          Update
        </.button>
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
