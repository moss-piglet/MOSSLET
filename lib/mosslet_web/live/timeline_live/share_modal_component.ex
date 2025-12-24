defmodule MossletWeb.TimelineLive.ShareModalComponent do
  use MossletWeb, :live_component

  import MossletWeb.CoreComponents, only: [phx_icon: 1, phx_input: 1]

  import MossletWeb.DesignSystem,
    only: [liquid_button: 1, liquid_modal: 1, liquid_avatar: 1, get_connection_avatar_src: 3]

  alias Mosslet.Accounts.Scope
  alias Mosslet.Timeline.UserPost
  alias Phoenix.LiveView.JS

  @max_note_length UserPost.share_note_max_length()

  def update(assigns, socket) do
    current_user =
      case assigns[:current_scope] do
        %Scope{user: user} -> user
        _ -> assigns[:current_user]
      end

    key =
      case assigns[:current_scope] do
        %Scope{key: k} -> k
        _ -> assigns[:key]
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_user, current_user)
     |> assign(:key, key)
     |> assign_new(:selected_user_ids, fn -> MapSet.new() end)
     |> assign_new(:search_query, fn -> "" end)
     |> assign_new(:form, fn -> build_form(%{}) end)}
  end

  defp build_form(params) do
    UserPost.share_note_changeset(params)
    |> to_form(as: :share)
  end

  def handle_event("toggle_user", %{"user-id" => user_id}, socket) do
    selected = socket.assigns.selected_user_ids

    updated =
      if MapSet.member?(selected, user_id) do
        MapSet.delete(selected, user_id)
      else
        MapSet.put(selected, user_id)
      end

    {:noreply, assign(socket, :selected_user_ids, updated)}
  end

  def handle_event("validate", %{"share" => params}, socket) do
    form =
      UserPost.share_note_changeset(params)
      |> Map.put(:action, :validate)
      |> to_form(as: :share)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("search_connections", %{"search" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  def handle_event("submit_share", %{"share" => params}, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_user_ids)

    if Enum.empty?(selected_ids) do
      {:noreply, socket}
    else
      changeset = UserPost.share_note_changeset(params)

      if changeset.valid? do
        note = Ecto.Changeset.get_field(changeset, :share_note) || ""

        send(
          self(),
          {:submit_share,
           %{
             post_id: socket.assigns.post_id,
             selected_user_ids: selected_ids,
             note: note,
             body: socket.assigns.body,
             username: socket.assigns.username
           }}
        )

        {:noreply,
         socket
         |> assign(:selected_user_ids, MapSet.new())
         |> assign(:form, build_form(%{}))
         |> push_event("restore-body-scroll", %{})}
      else
        form =
          changeset
          |> Map.put(:action, :validate)
          |> to_form(as: :share)

        {:noreply, assign(socket, :form, form)}
      end
    end
  end

  def handle_event("close_modal", _params, socket) do
    send(self(), {:close_share_modal, %{}})

    {:noreply,
     socket
     |> assign(:show, false)
     |> assign(:selected_user_ids, MapSet.new())
     |> assign(:form, build_form(%{}))}
  end

  defp filtered_connections(connections, search_query) do
    if search_query == "" do
      connections
    else
      query = String.downcase(search_query)

      Enum.filter(connections, fn conn ->
        String.contains?(String.downcase(conn.username || ""), query)
      end)
    end
  end

  defp find_user_connection(user_connections, user_id) do
    Enum.find(user_connections, fn uc ->
      uc.connection.user_id == user_id || uc.reverse_user_id == user_id
    end)
  end

  def render(assigns) do
    filtered = filtered_connections(assigns.connections, assigns.search_query)
    assigns = assign(assigns, :filtered_connections, filtered)
    assigns = assign(assigns, :max_note_length, @max_note_length)

    ~H"""
    <div id="share-modal-component-container" class="share-modal-component">
      <%= if @show do %>
        <.liquid_modal
          id={"share-post-modal-#{@post_id}"}
          show={@show}
          on_cancel={JS.push("close_share_modal", target: "#timeline-container")}
          size="lg"
        >
          <:title>
            <div class="flex items-center gap-3">
              <div class="p-2.5 rounded-xl bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/30 dark:to-teal-900/30">
                <.phx_icon
                  name="hero-paper-airplane"
                  class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
                />
              </div>
              <div>
                <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                  Share with...
                </h3>
                <p class="text-sm text-emerald-700 dark:text-emerald-400">
                  Choose who you'd like to share this with
                </p>
              </div>
            </div>
          </:title>

          <.form
            for={@form}
            id={"share-form-#{@post_id}"}
            phx-change="validate"
            phx-submit="submit_share"
            phx-target={@myself}
            class="space-y-6"
          >
            <div class="p-4 bg-emerald-50/50 dark:bg-emerald-900/20 rounded-xl border border-emerald-200/50 dark:border-emerald-700/30">
              <div class="flex gap-3">
                <.phx_icon
                  name="hero-heart"
                  class="h-5 w-5 text-emerald-600 dark:text-emerald-400 flex-shrink-0 mt-0.5"
                />
                <p class="text-sm text-emerald-800 dark:text-emerald-200">
                  Share thoughtfully with the people who would appreciate this most.
                  They'll see it came from you with care.
                </p>
              </div>
            </div>

            <div class="space-y-2">
              <label
                for={"share-note-#{@post_id}"}
                class="block text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                Add a personal note (optional)
              </label>
              <div class="relative">
                <.phx_input
                  field={@form[:share_note]}
                  type="textarea"
                  id={"share-note-#{@post_id}"}
                  rows="2"
                  maxlength={@max_note_length}
                  phx-debounce="300"
                  phx-hook="CharacterCounter"
                  data-limit={@max_note_length}
                  class="w-full px-4 py-3 pr-20 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-all duration-200 resize-none"
                  placeholder="I thought you'd enjoy this..."
                />
                <div
                  phx-update="ignore"
                  class="absolute bottom-3.5 right-3 transition-all duration-300 ease-out char-counter-hidden"
                  id={"share-note-char-counter-#{@post_id}"}
                >
                  <span class="text-xs text-emerald-600 dark:text-emerald-400 bg-white/95 dark:bg-slate-800/95 px-2 py-1 rounded-full backdrop-blur-sm border border-emerald-200/60 dark:border-emerald-700/60 shadow-sm">
                    <span class="js-char-count">0</span>/{@max_note_length}
                  </span>
                </div>
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Your note will appear with the shared post (max {@max_note_length} characters)
              </p>
            </div>

            <div class="space-y-3">
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
                Select connections to share with
              </label>

              <div class="relative">
                <.phx_icon
                  name="hero-magnifying-glass"
                  class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400"
                />
                <input
                  type="text"
                  name="search"
                  phx-change="search_connections"
                  phx-target={@myself}
                  phx-debounce="150"
                  class="w-full pl-10 pr-4 py-2.5 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-all duration-200"
                  placeholder="Search connections..."
                  value={@search_query}
                />
              </div>

              <div class="max-h-64 overflow-y-auto rounded-xl border border-slate-200 dark:border-slate-700 divide-y divide-slate-100 dark:divide-slate-700/50">
                <%= if Enum.empty?(@filtered_connections) do %>
                  <div class="p-6 text-center">
                    <.phx_icon
                      name="hero-user-group"
                      class="h-8 w-8 text-slate-400 mx-auto mb-2"
                    />
                    <p class="text-sm text-slate-500 dark:text-slate-400">
                      <%= if @search_query != "" do %>
                        No connections match your search
                      <% else %>
                        No connections available to share with
                      <% end %>
                    </p>
                  </div>
                <% else %>
                  <%= for conn <- @filtered_connections do %>
                    <% user_connection = find_user_connection(@user_connections, conn.user_id) %>
                    <% avatar_src =
                      if user_connection,
                        do: get_connection_avatar_src(user_connection, @current_user, @key),
                        else: nil %>
                    <button
                      type="button"
                      phx-click="toggle_user"
                      phx-value-user-id={conn.user_id}
                      phx-target={@myself}
                      class={[
                        "w-full flex items-center gap-3 p-3 transition-all duration-200",
                        "hover:bg-slate-50 dark:hover:bg-slate-800/50",
                        if(MapSet.member?(@selected_user_ids, conn.user_id),
                          do: "bg-emerald-50 dark:bg-emerald-900/20 border-l-4 border-emerald-500",
                          else: "bg-white dark:bg-slate-800/30"
                        )
                      ]}
                    >
                      <.liquid_avatar
                        name={conn.username}
                        src={avatar_src}
                        size="sm"
                        show_status={false}
                      />
                      <span class="flex-1 text-left text-sm font-medium text-slate-900 dark:text-slate-100">
                        {conn.username}
                      </span>
                      <div class={[
                        "w-5 h-5 rounded-full border-2 flex items-center justify-center transition-all duration-200",
                        if(MapSet.member?(@selected_user_ids, conn.user_id),
                          do: "bg-emerald-500 border-emerald-500",
                          else: "border-slate-300 dark:border-slate-600"
                        )
                      ]}>
                        <.phx_icon
                          :if={MapSet.member?(@selected_user_ids, conn.user_id)}
                          name="hero-check"
                          class="h-3 w-3 text-white"
                        />
                      </div>
                    </button>
                  <% end %>
                <% end %>
              </div>

              <%= if MapSet.size(@selected_user_ids) > 0 do %>
                <p class="text-sm text-emerald-600 dark:text-emerald-400">
                  <.phx_icon name="hero-check-circle" class="h-4 w-4 inline mr-1" />
                  {MapSet.size(@selected_user_ids)} {if MapSet.size(@selected_user_ids) == 1,
                    do: "person",
                    else: "people"} selected
                </p>
              <% end %>
            </div>

            <div class="flex justify-end gap-3 pt-2">
              <.liquid_button
                type="button"
                variant="ghost"
                color="slate"
                phx-click={JS.exec("data-cancel", to: "#share-post-modal-#{@post_id}")}
              >
                Cancel
              </.liquid_button>
              <.liquid_button
                type="submit"
                color="emerald"
                icon="hero-paper-airplane"
                disabled={MapSet.size(@selected_user_ids) == 0 || !@form.source.valid?}
                class={
                  if MapSet.size(@selected_user_ids) == 0,
                    do: "opacity-50 cursor-not-allowed"
                }
              >
                Share with {MapSet.size(@selected_user_ids)} {if MapSet.size(@selected_user_ids) ==
                                                                   1,
                                                                 do: "person",
                                                                 else: "people"}
              </.liquid_button>
            </div>
          </.form>
        </.liquid_modal>
      <% end %>
    </div>
    """
  end
end
