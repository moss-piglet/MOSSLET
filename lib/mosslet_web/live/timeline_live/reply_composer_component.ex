defmodule MossletWeb.TimelineLive.ReplyComposerComponent do
  @moduledoc """
  LiveComponent for the collapsible reply composer.
  Handles its own form state and events independently.
  """
  use MossletWeb, :live_component

  alias Mosslet.Timeline
  alias Mosslet.Timeline.Reply
  import MossletWeb.Helpers

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    # Create or update the reply form for this specific post
    form = get_or_create_reply_form(assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign(:form, form)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      id={"reply-composer-#{@post_id}"}
      class={[
        "hidden overflow-hidden transition-all duration-300 ease-out",
        "bg-gradient-to-br from-emerald-50/40 via-teal-50/30 to-cyan-50/40",
        "dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-cyan-900/20",
        "border border-emerald-200/60 dark:border-emerald-700/50",
        "rounded-xl shadow-lg shadow-emerald-500/10 dark:shadow-emerald-400/15",
        "mt-4 p-4",
        @class
      ]}
    >
      <div class="pt-4 border-t border-slate-200/50 dark:border-slate-700/50">
        <%!-- Reply context indicator --%>
        <div class="flex items-center gap-2 mb-4 pl-4">
          <div class="w-6 h-px bg-gradient-to-r from-emerald-300 to-teal-300 dark:from-emerald-600 dark:to-teal-600">
          </div>
          <.phx_icon
            name="hero-arrow-turn-down-right"
            class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
          />
          <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
            Reply to this post
          </span>
        </div>

        <%!-- Compact reply composer with liquid styling --%>
        <div class={[
          "relative rounded-xl overflow-hidden",
          "bg-gradient-to-br from-emerald-50/40 via-teal-50/30 to-cyan-50/40",
          "dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-cyan-900/20",
          "border border-emerald-200/60 dark:border-emerald-700/50",
          "shadow-lg shadow-emerald-500/10 dark:shadow-emerald-400/15",
          "focus-within:border-emerald-400/80 dark:focus-within:border-emerald-500/70",
          "focus-within:shadow-xl focus-within:shadow-emerald-500/20"
        ]}>
          <.form
            for={@form}
            id={"reply-form-composer-#{@post_id}"}
            phx-submit="save_reply"
            phx-change="validate_reply"
            phx-target={@myself}
          >
            <%!-- Subtle liquid background animation on focus --%>
            <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-emerald-100/30 via-teal-100/20 to-emerald-100/30 dark:from-emerald-800/20 dark:via-teal-800/15 dark:to-emerald-800/20 focus-within:opacity-100">
            </div>

            <div class="relative p-4">
              <div class="flex items-start gap-3">
                <%!-- User avatar (smaller for replies) --%>
                <MossletWeb.DesignSystem.liquid_avatar
                  src={@user_avatar}
                  name={@user_name}
                  size="sm"
                  class="flex-shrink-0"
                />

                <div class="flex-1 min-w-0">
                  <%!-- Hidden form fields with unique IDs --%>
                  <.phx_input
                    field={@form[:post_id]}
                    type="hidden"
                    id={"reply_post_id_#{@post_id}"}
                    name={@form[:post_id].name}
                    value={@post_id}
                  />
                  <.phx_input
                    field={@form[:user_id]}
                    type="hidden"
                    id={"reply_user_id_#{@post_id}"}
                    name={@form[:user_id].name}
                    value={@current_user.id}
                  />
                  <.phx_input
                    field={@form[:visibility]}
                    type="hidden"
                    id={"reply_visibility_#{@post_id}"}
                    name={@form[:visibility].name}
                    value={@visibility}
                  />
                  <.phx_input
                    field={@form[:username]}
                    type="hidden"
                    id={"reply_username_#{@post_id}"}
                    name={@form[:username].name}
                    value={@username}
                  />

                  <%!-- Reply textarea --%>
                  <div class="relative">
                    <textarea
                      id={"reply-textarea-#{@post_id}"}
                      name={@form[:body].name}
                      placeholder="Write a thoughtful reply..."
                      rows="2"
                      maxlength={@character_limit}
                      class="w-full resize-none border-0 bg-transparent text-slate-900 dark:text-slate-100 placeholder:text-emerald-600/70 dark:placeholder:text-emerald-400/70 text-base leading-relaxed focus:outline-none focus:ring-0"
                      phx-hook="CharacterCounter"
                      data-limit={@character_limit}
                      phx-debounce="300"
                      phx-target={@myself}
                    ><%= @form[:body].value %></textarea>

                    <%!-- Character counter for replies --%>
                    <div
                      class={[
                        "absolute bottom-1 right-1 transition-all duration-300 ease-out",
                        (@form[:body].value && String.trim(@form[:body].value) != "" && "opacity-100") ||
                          "opacity-0"
                      ]}
                      id={"reply-char-counter-#{@post_id}"}
                    >
                      <span class="text-xs text-emerald-600 dark:text-emerald-400 bg-white/95 dark:bg-slate-800/95 px-2 py-1 rounded-full backdrop-blur-sm border border-emerald-200/60 dark:border-emerald-700/60 shadow-sm">
                        <span class="js-char-count"><%= String.length(@form[:body].value || "") %></span>/{@character_limit}
                      </span>
                    </div>
                  </div>

                  <%!-- Reply actions --%>
                  <div class="flex items-center justify-between mt-3">
                    <div class="flex items-center gap-2">
                      <%!-- Optional: Reply privacy indicator --%>
                      <span class="text-xs text-emerald-600/80 dark:text-emerald-400/80 font-medium">
                        Reply visibility: Same as post
                      </span>
                    </div>

                    <div class="flex items-center gap-2">
                      <%!-- Cancel button --%>
                      <MossletWeb.DesignSystem.liquid_button
                        type="button"
                        variant="ghost"
                        size="sm"
                        color="slate"
                        phx-click="cancel_reply"
                        phx-target={@myself}
                        class="text-slate-600 dark:text-slate-400"
                      >
                        Cancel
                      </MossletWeb.DesignSystem.liquid_button>

                      <%!-- Reply submit button --%>
                      <MossletWeb.DesignSystem.liquid_button
                        type="submit"
                        size="sm"
                        color="emerald"
                        icon="hero-paper-airplane"
                        disabled={!@form[:body].value || String.trim(@form[:body].value) == ""}
                        phx-target={@myself}
                      >
                        Reply
                      </MossletWeb.DesignSystem.liquid_button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("validate_reply", %{"reply" => reply_params}, socket) do
    changeset = Timeline.change_reply(%Reply{}, reply_params)
    form = to_form(changeset, action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("cancel_reply", _params, socket) do
    # Reset the form to empty state
    changeset =
      Timeline.change_reply(%Reply{}, %{
        "body" => "",
        "post_id" => socket.assigns.post_id,
        "user_id" => socket.assigns.current_user.id,
        "username" => socket.assigns.username,
        "visibility" => socket.assigns.visibility
      })

    form = to_form(changeset)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save_reply", %{"reply" => reply_params}, socket) do
    post_id = socket.assigns.post_id
    visibility = socket.assigns.visibility
    # Send the reply creation to the parent LiveView
    send(self(), {:create_reply, reply_params, post_id, visibility})

    # Reset the form
    changeset =
      Timeline.change_reply(%Reply{}, %{
        "body" => "",
        "post_id" => post_id,
        "user_id" => socket.assigns.current_user.id,
        "username" => socket.assigns.username,
        "visibility" => visibility
      })

    form = to_form(changeset)

    {:noreply, assign(socket, :form, form)}
  end

  # Helper function to get or create reply form
  defp get_or_create_reply_form(assigns) do
    changeset =
      Timeline.change_reply(%Reply{}, %{
        "body" => "",
        "post_id" => assigns.post_id,
        "user_id" => assigns.current_user.id,
        "username" => assigns.username,
        "visibility" => assigns.visibility
      })

    to_form(changeset)
  end
end
