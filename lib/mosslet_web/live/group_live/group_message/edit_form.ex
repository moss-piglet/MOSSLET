defmodule MossletWeb.GroupLive.GroupMessage.EditForm do
  @moduledoc false
  use MossletWeb, :live_component
  alias Mosslet.GroupMessages

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form()}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.phx_modal id="edit_message">
        <.simple_form
          for={@message_form}
          phx-submit={JS.push("update") |> phx_hide_modal("edit_message")}
          phx-target={@myself}
        >
          <.input id="edit_group_message_content" autocomplete="off" field={@message_form[:content]} />
          <:actions>
            <.button>save</.button>
          </:actions>
        </.simple_form>
      </.phx_modal>
    </div>
    """
  end

  def handle_event("update", %{"group_message" => %{"content" => content}}, socket) do
    GroupMessages.update_message(socket.assigns.message, %{content: content})

    {:noreply, socket}
  end

  def assign_form(%{assigns: %{message: message}} = socket) do
    assign(socket, :message_form, to_form(GroupMessages.change_message(message)))
  end
end
