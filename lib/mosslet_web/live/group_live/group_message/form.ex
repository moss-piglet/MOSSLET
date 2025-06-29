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
    <div class="pt-6">
      <div class="min-w-0 flex-1">
        <.form
          for={@message_form}
          phx-submit="save"
          phx-change="update"
          phx-target={@myself}
          class="relative"
        >
          <div class="overflow-hidden rounded-lg shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-emerald-300 focus-within:ring-2 focus-within:ring-primary-600">
            <div class="pl-3">
              <label for="message_form[content]" class="sr-only">Add new message to group</label>
              <.phx_input
                autocomplete="off"
                phx-keydown={show_modal("edit_message")}
                phx-key="ArrowUp"
                phx-focus="unpin_scrollbar_from_top"
                field={@message_form[:content]}
                type="textarea"
                placeholder="Add a new message to this group"
                apply_classes?={true}
                phx-debounce="500"
                classes="block w-full resize-none border-0 bg-transparent py-1.5 text-gray-900 dark:text-gray-100 placeholder:text-gray-500 dark:placeholder:text-gray-400 focus:ring-0 sm:text-sm sm:leading-6"
              />
            </div>
            <.phx_input type="hidden" field={@message_form[:group_id]} value={@group_id} />
            <.phx_input type="hidden" field={@message_form[:sender_id]} value={@sender_id} />
            <!-- Spacer element to match the height of the toolbar -->
            <div class="py-2" aria-hidden="true">
              <!-- Matches height of button in toolbar (1px border + 36px content height) -->
              <div class="py-px">
                <div class="h-9"></div>
              </div>
            </div>
          </div>

          <div class="absolute inset-x-0 bottom-0 flex justify-between py-2 pl-3 pr-2">
            <div></div>
            <div class="flex-shrink-0">
              <.phx_button type="submit" class="inline-flex rounded-full">
                Message
              </.phx_button>
            </div>
          </div>
        </.form>
      </div>
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
    GroupMessages.create_message(
      %{
        content: content,
        group_id: socket.assigns.group_id,
        sender_id: socket.assigns.sender_id
      },
      user_group_key: socket.assigns.user_group_key,
      user: socket.assigns.current_user,
      key: socket.assigns.key
    )

    {:noreply, assign_form(socket)}
  end
end
