defmodule MossletWeb.GroupLive.GroupMessage.EditForm do
  @moduledoc """
  Edit form for group messages.

  Non-public groups use browser-side ZK encryption via GroupMessageEditFormHook:
  the JS hook populates the textarea with decrypted content (from the already-
  rendered message DOM), encrypts on submit, and pushes "update_encrypted".

  Public groups use the legacy path: server decrypts content for display and
  re-encrypts on save.
  """
  use MossletWeb, :live_component
  alias Mosslet.GroupMessages
  alias Mosslet.Groups.GroupMessage

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_decrypted_content()
     |> assign_form()}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.phx_modal id="edit_message">
        <.simple_form
          for={@message_form}
          id="edit-group-message-form"
          phx-hook="GroupMessageEditFormHook"
          phx-submit={JS.push("update") |> phx_hide_modal("edit_message")}
          phx-target={@myself}
          data-public={to_string(@public?)}
          data-sealed-group-key={not @public? && @user_group_key}
          data-message-id={@message.id}
        >
          <.input
            id="edit_group_message_content"
            autocomplete="off"
            field={@message_form[:content]}
          />
          <:actions>
            <.button>save</.button>
          </:actions>
        </.simple_form>
      </.phx_modal>
    </div>
    """
  end

  # ZK path: browser sends pre-encrypted ciphertext for non-public groups
  def handle_event("update_encrypted", %{"encrypted_content" => encrypted_content}, socket) do
    if socket.assigns.public? do
      {:noreply, socket}
    else
      case GroupMessages.update_message(socket.assigns.message, %{content: encrypted_content},
             encrypted_content: encrypted_content
           ) do
        {:ok, _message} -> {:noreply, socket}
        {:error, _changeset} -> {:noreply, socket}
      end
    end
  end

  # Legacy path: server-side encryption for public groups
  def handle_event("update", %{"group_message" => %{"content" => content}}, socket) do
    case GroupMessages.update_message(
           socket.assigns.message,
           %{content: content},
           user_group_key: socket.assigns.user_group_key,
           user: socket.assigns.current_scope.user,
           key: socket.assigns.current_scope.key,
           public?: socket.assigns.public?
         ) do
      {:ok, _message} -> {:noreply, socket}
      {:error, _changeset} -> {:noreply, socket}
    end
  end

  # For public groups, decrypt the message content server-side so the form
  # shows plaintext. For non-public groups, the JS hook populates the textarea
  # with the already-decrypted content from the message DOM element.
  defp assign_decrypted_content(%{assigns: %{message: %{id: nil}}} = socket) do
    assign(socket, :decrypted_content, nil)
  end

  defp assign_decrypted_content(socket) do
    %{message: message, public?: public?} = socket.assigns

    decrypted =
      if public? && message.content do
        with key when is_binary(key) <-
               Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(
                 socket.assigns.user_group_key
               ),
             {:ok, plaintext} <-
               Mosslet.Encrypted.Utils.decrypt(%{key: key, payload: message.content}) do
          plaintext
        else
          _ -> nil
        end
      end

    assign(socket, :decrypted_content, decrypted)
  end

  defp assign_form(
         %{assigns: %{message: %GroupMessage{} = message, decrypted_content: decrypted}} = socket
       ) do
    # Use decrypted content for public groups (server-decrypted), empty for
    # non-public (JS hook will populate from the rendered message DOM)
    form_message =
      if decrypted do
        %GroupMessage{message | content: decrypted}
      else
        # For non-public groups, start with empty content — the JS hook
        # populates the textarea from the already-decrypted DOM element
        %GroupMessage{message | content: nil}
      end

    assign(socket, :message_form, to_form(GroupMessages.change_message(form_message)))
  end
end
