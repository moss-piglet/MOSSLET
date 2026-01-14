defmodule MossletWeb.GroupLive.GroupMessage.Form do
  @moduledoc false
  use MossletWeb, :live_component
  import MossletWeb.CoreComponents
  import MossletWeb.DesignSystem, only: [liquid_markdown_guide_trigger: 1]

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
    <div class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 border-t border-slate-200/60 dark:border-slate-700/60 bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm">
      <.form
        for={@message_form}
        phx-submit="save"
        phx-change="update"
        phx-target={@myself}
        id="group-message-form"
        class="max-w-4xl mx-auto"
      >
        <div class="relative">
          <label for="message_form[content]" class="sr-only">Add new message to group</label>
          <.phx_input
            autocomplete="off"
            phx-keydown={show_modal("edit_message")}
            phx-key="ArrowUp"
            phx-focus="unpin_scrollbar_from_top"
            phx-hook="SubmitOnEnter"
            field={@message_form[:content]}
            type="textarea"
            placeholder="Type your message..."
            apply_classes?={true}
            phx-debounce="500"
            aria-label="Message input. Press Enter to send, Shift+Enter for new line"
            classes={[
              "block w-full resize-none bg-slate-50/60 dark:bg-slate-900/40 text-slate-900 dark:text-slate-100 placeholder:text-slate-400 dark:placeholder:text-slate-500 rounded-2xl py-3 pl-4 pr-28 text-base sm:text-sm leading-relaxed min-h-[48px] max-h-32 border border-slate-200/60 dark:border-slate-700/60 focus:border-teal-400/60 dark:focus:border-teal-500/60 focus:ring-2 focus:ring-teal-500/20 dark:focus:ring-teal-400/20 focus:outline-none transition-all duration-200"
            ]}
          />
          <div class="absolute right-2 bottom-2 flex items-center gap-1">
            <button
              type="button"
              id="group-message-emoji-button"
              class="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group"
              phx-hook="GroupMessageEmojiPicker"
              title="Add emoji"
            >
              <.phx_icon
                name="hero-face-smile"
                class="h-4 w-4 transition-transform duration-200 group-hover:scale-110"
              />
            </button>
            <.liquid_markdown_guide_trigger
              id="group-message-markdown-guide-trigger"
              on_click={JS.push("open_markdown_guide")}
              size="sm"
            />
            <button
              type="submit"
              class="group/btn inline-flex items-center justify-center gap-1.5 h-10 px-3 sm:px-4 rounded-xl bg-gradient-to-br from-teal-500 to-emerald-500 hover:from-teal-400 hover:to-emerald-400 text-white shadow-lg shadow-teal-500/25 hover:shadow-xl hover:shadow-teal-500/30 active:scale-95 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2 focus:ring-offset-white dark:focus:ring-offset-slate-800"
            >
              <span class="hidden sm:inline text-sm font-medium">Send</span>
              <.phx_icon name="hero-paper-airplane" class="w-4 h-4 sm:w-4 sm:h-4" />
              <span class="sr-only sm:hidden">Send message</span>
            </button>
          </div>
        </div>

        <.phx_input type="hidden" field={@message_form[:group_id]} value={@group_id} />
        <.phx_input type="hidden" field={@message_form[:sender_id]} value={@sender_id} />
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
           user: socket.assigns.current_scope.user,
           key: socket.assigns.current_scope.key,
           public?: socket.assigns[:public?]
         ) do
      {:ok, message} ->
        send(self(), {:message_sent, message})
        {:noreply, assign_form(socket)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
end
