defmodule MossletWeb.TimelineLive.NestedReplyComposerComponent do
  use MossletWeb, :live_component

  import MossletWeb.CoreComponents, only: [phx_input: 1, phx_icon: 1]
  import MossletWeb.DesignSystem, only: [liquid_button: 1]

  alias Mosslet.Accounts
  alias Mosslet.Timeline
  alias Mosslet.Timeline.Reply

  def update(assigns, socket) do
    # Ensure we have required assigns
    if assigns.parent_reply && assigns.post_id do
      # Get the post from the post_id
      post = Timeline.get_post!(assigns.post_id)

      # Create proper changeset form like main reply composer
      changeset =
        Timeline.change_reply(%Reply{}, %{
          "body" => "",
          "parent_reply_id" => assigns.parent_reply.id,
          "post_id" => assigns.post_id,
          "user_id" => assigns.current_user.id,
          "username" => MossletWeb.Helpers.user_name(assigns.current_user, assigns.key),
          "visibility" => post.visibility
        })

      form = to_form(changeset)
      character_limit = 280

      {:ok,
       socket
       |> assign(assigns)
       |> assign(:post, post)
       |> assign(:form, form)
       |> assign(:character_limit, character_limit)}
    else
      # Handle missing assigns gracefully
      {:ok, assign(socket, assigns)}
    end
  end

  def handle_event("validate_nested_reply", %{"reply" => reply_params}, socket) do
    changeset = Timeline.change_reply(%Reply{}, reply_params)
    form = to_form(changeset, action: :validate)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("cancel_nested_reply", _params, socket) do
    # Reset the form to empty state (clear the body)
    %{parent_reply: parent_reply, post: post, current_user: current_user, key: key} =
      socket.assigns

    changeset =
      Timeline.change_reply(%Reply{}, %{
        "body" => "",
        "parent_reply_id" => parent_reply.id,
        "post_id" => post.id,
        "user_id" => current_user.id,
        "username" => MossletWeb.Helpers.user_name(current_user, key),
        "visibility" => post.visibility
      })

    form = to_form(changeset)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit_nested_reply", %{"reply" => reply_params}, socket) do
    %{current_user: current_user, key: key, parent_reply: parent_reply, post: post} =
      socket.assigns

    # Get the post_key for encryption (same as parent post)
    post_key = MossletWeb.Helpers.get_post_key(post, current_user)

    # Create nested reply with parent_reply_id
    reply_attrs =
      Map.merge(reply_params, %{
        "user_id" => current_user.id,
        "username" => MossletWeb.Helpers.user_name(current_user, key),
        "post_id" => post.id,
        "parent_reply_id" => parent_reply.id,
        "visibility" => post.visibility
      })

    case Timeline.create_reply(reply_attrs,
           user: current_user,
           key: key,
           post: post,
           post_key: post_key,
           visibility: post.visibility
         ) do
      {:ok, _reply} ->
        # Track user activity for auto-status (reply creation is significant activity)
        Accounts.track_user_activity(current_user, :interaction)
        # Clear the form like main reply composer
        changeset =
          Timeline.change_reply(%Reply{}, %{
            "body" => "",
            "parent_reply_id" => parent_reply.id,
            "post_id" => post.id,
            "user_id" => current_user.id,
            "username" => MossletWeb.Helpers.user_name(current_user, key),
            "visibility" => post.visibility
          })

        form = to_form(changeset)

        # Use the hide-nested-reply-composer hook to close the composer after successful submission
        socket =
          socket
          |> assign(:form, form)

        # Send success message to parent LiveView
        send(self(), {:nested_reply_created, post.id, parent_reply.id})
        {:noreply, socket}

      {:error, _changeset} ->
        # Send error message to parent LiveView
        send(self(), {:nested_reply_error, "Failed to post reply. Please try again."})
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class={[
      "nested-reply-composer relative",
      "bg-gradient-to-br from-emerald-50/80 via-teal-50/60 to-cyan-50/40",
      "dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-cyan-900/10",
      "border border-emerald-200/60 dark:border-emerald-700/40",
      "rounded-xl p-4 backdrop-blur-sm",
      "shadow-sm hover:shadow-md transition-all duration-200",
      @class
    ]}>
      <%!-- Reply context header --%>
      <div class="flex items-center gap-2 mb-3 pb-2 border-b border-emerald-200/40 dark:border-emerald-700/30">
        <.phx_icon
          name="hero-arrow-uturn-left"
          class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
        />
        <span class="text-sm text-emerald-700 dark:text-emerald-300 font-medium">
          Replying to {"@#{@author_name}"}
        </span>
      </div>

      <%!-- Nested reply form --%>
      <.form
        for={@form}
        id={"nested-reply-form-#{@parent_reply.id}"}
        phx-submit="submit_nested_reply"
        phx-change="validate_nested_reply"
        phx-target={@myself}
        class="space-y-3"
        as={:reply}
      >
        <%!-- Hidden fields with unique IDs --%>
        <.phx_input
          field={@form[:parent_reply_id]}
          type="hidden"
          id={"nested_reply_parent_reply_id_#{@parent_reply.id}"}
          value={@parent_reply.id}
        />
        <.phx_input
          field={@form[:post_id]}
          type="hidden"
          id={"nested_reply_post_id_#{@parent_reply.id}"}
          value={@post.id}
        />
        <.phx_input
          field={@form[:user_id]}
          type="hidden"
          id={"nested_reply_user_id_#{@parent_reply.id}"}
          value={@current_user.id}
        />
        <.phx_input
          field={@form[:username]}
          type="hidden"
          id={"nested_reply_username_#{@parent_reply.id}"}
          value={MossletWeb.Helpers.user_name(@current_user, @key)}
        />
        <.phx_input
          field={@form[:visibility]}
          type="hidden"
          id={"nested_reply_visibility_#{@parent_reply.id}"}
          value={@post.visibility}
        />

        <%!-- Reply textarea with character counter --%>
        <div class="relative">
          <textarea
            id={"nested-reply-textarea-#{@parent_reply.id}"}
            name={@form[:body].name}
            placeholder="Write your reply..."
            rows="3"
            maxlength={@character_limit}
            class="w-full resize-none border-emerald-200/60 dark:border-emerald-700/40 focus:border-emerald-400 dark:focus:border-emerald-500 focus:ring-emerald-500/30 bg-white/80 dark:bg-slate-800/80 rounded-lg px-3 py-2"
            phx-hook="CharacterCounter"
            data-limit={@character_limit}
            phx-debounce="300"
            phx-target={@myself}
          ><%= @form[:body].value %></textarea>

          <%!-- Character counter --%>
          <div
            class={[
              "absolute bottom-4 right-2 transition-all duration-300 ease-out",
              (@form[:body].value && String.trim(@form[:body].value) != "" && "opacity-100") ||
                "opacity-0"
            ]}
            id={"nested-reply-char-counter-#{@parent_reply.id}"}
          >
            <span class="text-xs text-emerald-600 dark:text-emerald-400 bg-white/95 dark:bg-slate-800/95 px-2 py-1 rounded-full backdrop-blur-sm border border-emerald-200/60 dark:border-emerald-700/60 shadow-sm">
              <span class="js-char-count"><%= String.length(@form[:body].value || "") %></span>/{@character_limit}
            </span>
          </div>
        </div>

        <%!-- Action section with improved mobile/desktop visual hierarchy --%>
        <div class="pt-2">
          <%!-- Toolbar and action buttons row --%>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <%!-- Left side: Toolbar with emoji picker --%>
            <div class="flex items-center justify-center sm:justify-start gap-1">
              <button
                id={"nested-reply-emoji-picker-#{@parent_reply.id}"}
                type="button"
                class="p-1.5 rounded-lg text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50/50 dark:hover:bg-emerald-900/20 transition-all duration-200 ease-out group"
                phx-hook="ReplyEmojiPicker"
                data-target-textarea={"nested-reply-textarea-#{@parent_reply.id}"}
                title="Add emoji"
              >
                <.phx_icon
                  name="hero-face-smile"
                  class="h-4 w-4 transition-transform duration-200 group-hover:scale-110"
                />
              </button>
            </div>

            <%!-- Right side: Clear and Reply buttons --%>
            <div class="flex items-center gap-3">
              <.liquid_button
                :if={@form[:body].value && String.trim(@form[:body].value) != ""}
                type="button"
                variant="ghost"
                size="sm"
                color="slate"
                phx-click="cancel_nested_reply"
                phx-target={@myself}
                class="flex-1 sm:flex-none text-xs"
              >
                Clear
              </.liquid_button>

              <.liquid_button
                type="submit"
                size="sm"
                color="emerald"
                disabled={!@form[:body].value || String.trim(@form[:body].value) == ""}
                phx-target={@myself}
                class="flex-1 sm:flex-none text-xs px-4"
              >
                <.phx_icon name="hero-paper-airplane" class="h-3 w-3 mr-1" />
                <span class="hidden sm:inline">Reply</span>
                <span class="sm:hidden">Send</span>
              </.liquid_button>
            </div>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
