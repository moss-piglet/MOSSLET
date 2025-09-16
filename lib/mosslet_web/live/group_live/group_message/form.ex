defmodule MossletWeb.GroupLive.GroupMessage.Form do
  @moduledoc false
  use MossletWeb, :live_component
  import MossletWeb.CoreComponents

  alias Mosslet.GroupMessages
  alias Mosslet.Groups.GroupMessage

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form()}
  end

  def assign_form(socket) do
    assign(socket, :message_form, to_form(GroupMessages.change_message(%GroupMessage{})))
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@message_form}
        phx-submit="save"
        phx-change="update"
        phx-target={@myself}
        class="flex items-end gap-3"
      >
        <div class="flex-1">
          <label for="message_form[content]" class="sr-only">Add new message to group</label>
          <.phx_input
            autocomplete="off"
            phx-keydown={show_modal("edit_message")}
            phx-key="ArrowUp"
            phx-focus="unpin_scrollbar_from_top"
            field={@message_form[:content]}
            type="textarea"
            placeholder="Type your message..."
            apply_classes?={true}
            phx-debounce="500"
            classes={[
              "block w-full resize-none border-0 bg-white dark:bg-gray-900/80 text-gray-900 dark:text-gray-100 placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:ring-2 focus:ring-emerald-500 dark:focus:ring-emerald-400 rounded-xl py-3 px-4 shadow-sm border border-gray-200 dark:border-gray-700 text-sm max-h-20"
            ]}
          />
        </div>

        <.phx_input type="hidden" field={@message_form[:group_id]} value={@group_id} />
        <.phx_input type="hidden" field={@message_form[:sender_id]} value={@sender_id} />

        <.phx_button
          type="submit"
          class="flex-shrink-0 inline-flex items-center justify-center w-10 h-10 bg-emerald-600 hover:bg-emerald-700 dark:bg-emerald-500 dark:hover:bg-emerald-600 text-white rounded-full transition-colors shadow-sm"
        >
          <.phx_icon name="hero-paper-airplane" class="w-5 h-5" />
          <span class="sr-only">Send message</span>
        </.phx_button>
      </.form>
    </div>
    """
  end

  def handle_event("update", %{"group_message" => %{"content" => content}}, socket) do
    {:noreply,
     socket
     |> assign(
       :message_form,
       to_form(GroupMessages.change_message(%GroupMessage{content: content}))
     )}
  end

  def handle_event("save", %{"group_message" => %{"content" => content}}, socket) do
    case GroupMessages.create_message(
           %{
             content: content,
             group_id: socket.assigns.group_id,
             sender_id: socket.assigns.sender_id
           },
           user_group_key: socket.assigns.user_group_key,
           user: socket.assigns.current_user,
           key: socket.assigns.key
         ) do
      {:ok, message} ->
        # Clear the form and notify parent to increment count
        send(self(), {:message_sent, message})
        {:noreply, assign_form(socket)}

      {:error, _changeset} ->
        # Keep the form as is if there was an error
        {:noreply, socket}
    end
  end
end
