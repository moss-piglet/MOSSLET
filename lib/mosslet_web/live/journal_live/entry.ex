defmodule MossletWeb.JournalLive.Entry do
  @moduledoc """
  Journal entry view - for creating, viewing, and editing journal entries.
  Uses a distraction-free focus layout with auto-save functionality.
  """
  use MossletWeb, :live_view

  alias Mosslet.Journal
  alias Mosslet.Journal.AI, as: JournalAI
  alias Mosslet.Journal.JournalEntry

  @auto_save_delay_ms 2_000

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @live_action == :show do %>
      <.layout
        type="reader"
        current_scope={@current_scope}
        current_page={:journal}
        back_path={~p"/app/journal"}
        prev_path={@prev_path}
        next_path={@next_path}
      >
        <div class="max-w-2xl mx-auto">
          <div class="space-y-6">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <time class="text-sm text-slate-500 dark:text-slate-400">
                  {format_date(@entry.entry_date)}
                </time>
                <span :if={@entry.mood} class="text-2xl">{mood_emoji(@entry.mood)}</span>
                <button
                  phx-click="toggle_favorite"
                  class={[
                    "text-xl transition-colors",
                    if(@entry.is_favorite,
                      do: "text-amber-500",
                      else: "text-slate-300 dark:text-slate-600 hover:text-amber-400"
                    )
                  ]}
                >
                  {if @entry.is_favorite, do: "★", else: "☆"}
                </button>
              </div>
              <.link
                navigate={~p"/app/journal/#{@entry.id}/edit"}
                class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
              >
                <.phx_icon name="hero-pencil" class="h-4 w-4" /> Edit
              </.link>
            </div>

            <h1
              :if={@decrypted_title}
              class="text-2xl font-semibold text-slate-900 dark:text-slate-100"
            >
              {@decrypted_title}
            </h1>

            <div class="prose prose-slate dark:prose-invert max-w-none">
              <p class="text-lg text-slate-700 dark:text-slate-300 leading-relaxed whitespace-pre-wrap">
                {@decrypted_body}
              </p>
            </div>

            <div class="pt-4 border-t border-slate-200 dark:border-slate-700 text-sm text-slate-500 dark:text-slate-400">
              {@entry.word_count} words
            </div>
          </div>
        </div>
      </.layout>
    <% else %>
      <.layout
        type="focus"
        current_scope={@current_scope}
        current_page={:journal}
        back_path={~p"/app/journal"}
        has_unsaved_changes={@has_unsaved_changes}
        saving={@saving}
      >
        <div class="max-w-2xl mx-auto">
          <h1 class="sr-only">
            {if @live_action == :new, do: "New Journal Entry", else: "Edit Journal Entry"}
          </h1>
          <.form
            :if={@live_action in [:new, :edit]}
            for={@form}
            id="journal-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-6"
          >
            <div class="flex items-center gap-3 mb-6">
              <time class="text-sm text-slate-500 dark:text-slate-400">
                {format_date(@entry_date)}
              </time>
              <select
                name="journal_entry[mood]"
                aria-label="Select mood"
                class="text-2xl bg-transparent border-none focus:ring-0 cursor-pointer"
              >
                <option value="" selected={is_nil(@form[:mood].value)}>😶</option>
                <option value="grateful" selected={@form[:mood].value == :grateful}>🙏</option>
                <option value="happy" selected={@form[:mood].value == :happy}>😊</option>
                <option value="calm" selected={@form[:mood].value == :calm}>😌</option>
                <option value="neutral" selected={@form[:mood].value == :neutral}>😐</option>
                <option value="anxious" selected={@form[:mood].value == :anxious}>😰</option>
                <option value="sad" selected={@form[:mood].value == :sad}>😢</option>
                <option value="angry" selected={@form[:mood].value == :angry}>😠</option>
              </select>
              <button
                type="button"
                phx-click="get_prompt"
                disabled={@loading_prompt || @prompt_cooldown}
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-900/30 rounded-lg hover:bg-teal-100 dark:hover:bg-teal-900/50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                <.phx_icon name="hero-sparkles" class="h-3.5 w-3.5" />
                {if @loading_prompt, do: "Getting prompt...", else: "Inspire me"}
              </button>
            </div>

            <div
              :if={@ai_prompt}
              class="mb-6 p-4 bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/20 dark:to-emerald-900/20 rounded-xl border border-teal-100 dark:border-teal-800"
            >
              <div class="flex items-start gap-3">
                <span class="text-lg">✨</span>
                <div class="flex-1">
                  <p class="text-sm text-teal-800 dark:text-teal-200 leading-relaxed">
                    {@ai_prompt}
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="dismiss_prompt"
                  class="text-teal-400 hover:text-teal-600 dark:hover:text-teal-300"
                >
                  <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                </button>
              </div>
            </div>

            <div>
              <input
                type="text"
                name="journal_entry[title]"
                value={@form[:title].value}
                placeholder="Title (optional)"
                class="w-full text-2xl font-semibold text-slate-900 dark:text-slate-100 bg-transparent border-none focus:ring-0 placeholder-slate-400 dark:placeholder-slate-500"
                autocomplete="off"
              />
            </div>

            <div>
              <textarea
                name="journal_entry[body]"
                placeholder="What's on your mind?"
                phx-hook="AutoResize"
                id="journal-body"
                class="w-full min-h-[400px] text-lg text-slate-700 dark:text-slate-300 bg-transparent border-none focus:ring-0 resize-none placeholder-slate-400 dark:placeholder-slate-500 leading-relaxed overflow-hidden"
              >{@form[:body].value}</textarea>
            </div>

            <div class="flex items-center justify-between pt-4 border-t border-slate-200 dark:border-slate-700">
              <div class="flex items-center gap-3 text-sm text-slate-500 dark:text-slate-400">
                <span>{@word_count} words</span>
                <span :if={@saving} class="flex items-center gap-1.5 text-teal-600 dark:text-teal-400">
                  <span class="inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent">
                  </span>
                  Saving...
                </span>
                <span
                  :if={@last_saved_at && !@saving && !@has_unsaved_changes}
                  class="text-emerald-600 dark:text-emerald-400"
                >
                  ✓ Saved
                </span>
              </div>
              <div class="flex items-center gap-3">
                <.link
                  :if={@live_action == :edit}
                  phx-click="delete"
                  data-confirm="Are you sure you want to delete this entry?"
                  class="px-4 py-2 text-sm font-medium text-red-600 dark:text-red-400 hover:text-red-700 dark:hover:text-red-300 transition-colors"
                >
                  Delete
                </.link>
                <button
                  type="submit"
                  disabled={!@form.source.valid? || @saving}
                  class="px-6 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
                >
                  {if @live_action == :new, do: "Save", else: "Update"}
                </button>
              </div>
            </div>
          </.form>
        </div>
      </.layout>
    <% end %>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:key, key)
     |> assign(:entry_date, Date.utc_today())
     |> assign(:word_count, 0)
     |> assign(:ai_prompt, nil)
     |> assign(:loading_prompt, false)
     |> assign(:prompt_cooldown, false)
     |> assign(:has_unsaved_changes, false)
     |> assign(:saving, false)
     |> assign(:last_saved_at, nil)
     |> assign(:auto_save_timer, nil)
     |> assign(:pending_params, nil)
     |> assign(:prev_path, nil)
     |> assign(:next_path, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    changeset = Journal.change_journal_entry(%JournalEntry{})

    socket
    |> assign(:page_title, "New Entry")
    |> assign(:entry, nil)
    |> assign(:form, to_form(changeset, as: :journal_entry))
    |> assign(:has_unsaved_changes, false)
    |> assign(:last_saved_at, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    user = socket.assigns.user
    key = socket.assigns.key

    case Journal.get_journal_entry(id, user) do
      nil ->
        socket
        |> put_flash(:error, "Entry not found")
        |> push_navigate(to: ~p"/app/journal")

      entry ->
        decrypted = Journal.decrypt_entry(entry, user, key)

        changeset =
          Journal.change_journal_entry(entry, %{title: decrypted.title, body: decrypted.body})

        socket
        |> assign(:page_title, "Edit Entry")
        |> assign(:entry, entry)
        |> assign(:entry_date, entry.entry_date)
        |> assign(:word_count, entry.word_count)
        |> assign(:form, to_form(changeset, as: :journal_entry))
        |> assign(:has_unsaved_changes, false)
        |> assign(:last_saved_at, nil)
    end
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    user = socket.assigns.user
    key = socket.assigns.key

    case Journal.get_journal_entry(id, user) do
      nil ->
        socket
        |> put_flash(:error, "Entry not found")
        |> push_navigate(to: ~p"/app/journal")

      entry ->
        decrypted = Journal.decrypt_entry(entry, user, key)
        adjacent = Journal.get_adjacent_entries(entry, user)

        prev_path = if adjacent.prev_id, do: ~p"/app/journal/#{adjacent.prev_id}", else: nil
        next_path = if adjacent.next_id, do: ~p"/app/journal/#{adjacent.next_id}", else: nil

        socket
        |> assign(:page_title, decrypted.title || "Journal Entry")
        |> assign(:entry, entry)
        |> assign(:decrypted_title, decrypted.title)
        |> assign(:decrypted_body, decrypted.body)
        |> assign(:prev_path, prev_path)
        |> assign(:next_path, next_path)
    end
  end

  @impl true
  def handle_event("validate", %{"journal_entry" => params}, socket) do
    body = params["body"] || ""
    word_count = body |> String.split(~r/\s+/, trim: true) |> length()

    changeset =
      %JournalEntry{}
      |> Journal.change_journal_entry(params)
      |> Map.put(:action, :validate)

    socket = cancel_auto_save_timer(socket)

    timer_ref = Process.send_after(self(), :auto_save, @auto_save_delay_ms)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, as: :journal_entry))
     |> assign(:word_count, word_count)
     |> assign(:has_unsaved_changes, true)
     |> assign(:auto_save_timer, timer_ref)
     |> assign(:pending_params, params)}
  end

  @impl true
  def handle_event("save", %{"journal_entry" => params}, socket) do
    socket = cancel_auto_save_timer(socket)
    save_entry(socket, socket.assigns.live_action, params, navigate: true)
  end

  @impl true
  def handle_event("delete", _params, socket) do
    entry = socket.assigns.entry
    user = socket.assigns.user

    case Journal.delete_journal_entry(entry, user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Entry deleted")
         |> push_navigate(to: ~p"/app/journal")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete entry")}
    end
  end

  @impl true
  def handle_event("toggle_favorite", _params, socket) do
    entry = socket.assigns.entry
    user = socket.assigns.user

    case Journal.toggle_favorite(entry, user) do
      {:ok, updated_entry} ->
        {:noreply, assign(socket, :entry, updated_entry)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("get_prompt", _params, socket) do
    user = socket.assigns.user
    mood = socket.assigns.form[:mood].value

    case JournalAI.can_generate_prompt?(user.id) do
      {:ok, _remaining} ->
        send(self(), {:fetch_prompt, mood})
        Process.send_after(self(), :clear_cooldown, JournalAI.prompt_cooldown_seconds() * 1000)

        {:noreply,
         socket
         |> assign(:loading_prompt, true)
         |> assign(:prompt_cooldown, true)}

      {:error, :limit_reached} ->
        {:noreply,
         socket
         |> assign(:ai_prompt, JournalAI.random_fallback_prompt())}
    end
  end

  @impl true
  def handle_event("dismiss_prompt", _params, socket) do
    {:noreply, assign(socket, :ai_prompt, nil)}
  end

  @impl true
  def handle_info(:auto_save, socket) do
    params = socket.assigns.pending_params

    if params && socket.assigns.has_unsaved_changes do
      save_entry(socket, socket.assigns.live_action, params, navigate: false)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:fetch_prompt, mood}, socket) do
    user = socket.assigns.user

    prompt =
      case JournalAI.generate_prompt(mood: mood) do
        {:ok, text} ->
          JournalAI.increment_prompt_count(user.id)
          text

        {:error, _} ->
          JournalAI.random_fallback_prompt()
      end

    {:noreply,
     socket
     |> assign(:ai_prompt, prompt)
     |> assign(:loading_prompt, false)}
  end

  @impl true
  def handle_info(:clear_cooldown, socket) do
    {:noreply, assign(socket, :prompt_cooldown, false)}
  end

  defp save_entry(socket, :new, params, opts) do
    user = socket.assigns.user
    key = socket.assigns.key

    socket = assign(socket, :saving, true)

    case Journal.create_journal_entry(user, params, key) do
      {:ok, entry} ->
        socket =
          socket
          |> assign(:saving, false)
          |> assign(:has_unsaved_changes, false)
          |> assign(:last_saved_at, DateTime.utc_now())
          |> assign(:entry, entry)
          |> assign(:pending_params, nil)

        if opts[:navigate] do
          {:noreply,
           socket
           |> put_flash(:info, "Entry saved")
           |> push_navigate(to: ~p"/app/journal/#{entry.id}")}
        else
          {:noreply,
           socket
           |> push_patch(to: ~p"/app/journal/#{entry.id}/edit", replace: true)}
        end

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> assign(:form, to_form(changeset, as: :journal_entry))}
    end
  end

  defp save_entry(socket, :edit, params, opts) do
    entry = socket.assigns.entry
    user = socket.assigns.user
    key = socket.assigns.key

    socket = assign(socket, :saving, true)

    case Journal.update_journal_entry(entry, params, user, key) do
      {:ok, updated_entry} ->
        socket =
          socket
          |> assign(:saving, false)
          |> assign(:has_unsaved_changes, false)
          |> assign(:last_saved_at, DateTime.utc_now())
          |> assign(:entry, updated_entry)
          |> assign(:pending_params, nil)

        if opts[:navigate] do
          {:noreply,
           socket
           |> put_flash(:info, "Entry updated")
           |> push_navigate(to: ~p"/app/journal/#{updated_entry.id}")}
        else
          {:noreply, socket}
        end

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> assign(:form, to_form(changeset, as: :journal_entry))}
    end
  end

  defp cancel_auto_save_timer(socket) do
    if socket.assigns.auto_save_timer do
      Process.cancel_timer(socket.assigns.auto_save_timer)
    end

    assign(socket, :auto_save_timer, nil)
  end

  defp format_date(date) do
    today = Date.utc_today()

    cond do
      date == today -> "Today"
      date == Date.add(today, -1) -> "Yesterday"
      true -> Calendar.strftime(date, "%A, %B %d, %Y")
    end
  end

  defp mood_emoji(:grateful), do: "🙏"
  defp mood_emoji(:happy), do: "😊"
  defp mood_emoji(:calm), do: "😌"
  defp mood_emoji(:neutral), do: "😐"
  defp mood_emoji(:anxious), do: "😰"
  defp mood_emoji(:sad), do: "😢"
  defp mood_emoji(:angry), do: "😠"
  defp mood_emoji(_), do: ""
end
