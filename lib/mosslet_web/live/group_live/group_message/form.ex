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
        id="group-message-form"
        class="flex items-end gap-2 sm:gap-3"
      >
        <div class="flex-1 min-w-0">
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
              "block w-full resize-none border-0 bg-white/95 dark:bg-slate-800/80 text-slate-900 dark:text-slate-100 placeholder:text-slate-400 dark:placeholder:text-slate-500 focus:ring-2 focus:ring-teal-500/50 dark:focus:ring-teal-400/50 focus:ring-offset-0 rounded-xl py-2.5 sm:py-3 px-3 sm:px-4 shadow-sm border border-slate-200/60 dark:border-slate-700/60 text-sm leading-relaxed max-h-24 sm:max-h-32 backdrop-blur-sm transition-all duration-200 focus:border-teal-300 dark:focus:border-teal-600 focus:shadow-md focus:shadow-teal-500/10"
            ]}
          />
        </div>

        <.phx_input type="hidden" field={@message_form[:group_id]} value={@group_id} />
        <.phx_input type="hidden" field={@message_form[:sender_id]} value={@sender_id} />

        <button
          type="submit"
          class="group/btn relative flex-shrink-0 inline-flex items-center justify-center w-10 h-10 sm:w-11 sm:h-11 rounded-xl overflow-hidden transition-all duration-200 ease-out transform-gpu hover:scale-105 active:scale-95 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2 focus:ring-offset-white dark:focus:ring-offset-slate-800"
        >
          <div class="absolute inset-0 bg-gradient-to-br from-teal-500 to-emerald-500 group-hover/btn:from-teal-400 group-hover/btn:to-emerald-400 transition-all duration-200">
          </div>
          <div class="absolute inset-0 opacity-0 group-hover/btn:opacity-100 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover/btn:translate-x-full transition-all duration-500 ease-out">
          </div>
          <.phx_icon name="hero-paper-airplane" class="relative w-5 h-5 text-white" />
          <span class="sr-only">Send message</span>
        </button>
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
        send(self(), {:message_sent, message})
        {:noreply, assign_form(socket)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
end
