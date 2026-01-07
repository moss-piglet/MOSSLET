defmodule MossletWeb.JournalLive.Index do
  @moduledoc """
  Journal index - displays list of journal entries with stats.
  """
  use MossletWeb, :live_view

  alias Mosslet.Journal
  alias Mosslet.Journal.AI, as: JournalAI

  @impl true
  def render(assigns) do
    ~H"""
    <.layout type="sidebar" current_scope={@current_scope} current_page={:journal}>
      <div class="max-w-4xl mx-auto">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div>
            <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
              Journal
            </h1>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Your private space for reflection
            </p>
          </div>

          <.link
            navigate={~p"/app/journal/new"}
            class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
          >
            <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> New Entry
          </.link>
        </div>

        <div class="grid grid-cols-3 gap-4 mb-8">
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="text-2xl font-bold text-slate-900 dark:text-slate-100">
              {@entry_count}
            </div>
            <div class="text-sm text-slate-600 dark:text-slate-400">Entries</div>
          </div>
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="text-2xl font-bold text-slate-900 dark:text-slate-100">
              {@total_words}
            </div>
            <div class="text-sm text-slate-600 dark:text-slate-400">Words</div>
          </div>
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="text-2xl font-bold text-emerald-600 dark:text-emerald-400">
              {@streak} 🔥
            </div>
            <div class="text-sm text-slate-600 dark:text-slate-400">Day streak</div>
          </div>
        </div>

        <div
          :if={@entry_count >= 3}
          class="mb-8 p-4 bg-gradient-to-r from-violet-50 to-purple-50 dark:from-violet-900/20 dark:to-purple-900/20 rounded-xl border border-violet-100 dark:border-violet-800"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-start gap-3 flex-1">
              <span class="text-lg">🔮</span>
              <div class="flex-1">
                <h2 class="text-sm font-medium text-violet-800 dark:text-violet-200 mb-1">
                  Mood Insights
                </h2>
                <p
                  :if={@mood_insight}
                  class="text-sm text-violet-700 dark:text-violet-300 leading-relaxed"
                >
                  {@mood_insight}
                </p>
                <p :if={@loading_insights} class="text-sm text-violet-600 dark:text-violet-400 italic">
                  Analyzing your mood patterns...
                </p>
              </div>
            </div>
            <button
              :if={!@loading_insights}
              type="button"
              phx-click="refresh_insights"
              class="text-violet-400 hover:text-violet-600 dark:hover:text-violet-300"
              title="Refresh insights"
            >
              <.phx_icon name="hero-arrow-path" class="h-4 w-4" />
            </button>
          </div>
        </div>

        <div :if={@entries == []} class="text-center py-16">
          <.phx_icon
            name="hero-book-open"
            class="h-12 w-12 mx-auto text-slate-400 dark:text-slate-500 mb-4"
          />
          <h2 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2">
            Start your journal
          </h2>
          <p class="text-slate-600 dark:text-slate-400 mb-6">
            Capture your thoughts, feelings, and moments in a private space.
          </p>
          <.link
            navigate={~p"/app/journal/new"}
            class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
          >
            <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> Write your first entry
          </.link>
        </div>

        <div :if={@entries != []} class="space-y-3">
          <div
            :for={entry <- @entries}
            class="group bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700 hover:border-emerald-300 dark:hover:border-emerald-600 transition-colors cursor-pointer"
            phx-click={JS.navigate(~p"/app/journal/#{entry.id}")}
          >
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                  <h2 class="text-base font-medium text-slate-900 dark:text-slate-100 truncate">
                    {entry.decrypted_title || "Untitled"}
                  </h2>
                  <span
                    :if={entry.is_favorite}
                    class="text-amber-500"
                    title="Favorite"
                  >
                    ★
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2">
                  {truncate_body(entry.decrypted_body)}
                </p>
              </div>
              <div class="flex flex-col items-end gap-1 flex-shrink-0">
                <time class="text-xs text-slate-500 dark:text-slate-400">
                  {format_date(entry.entry_date)}
                </time>
                <span
                  :if={entry.mood}
                  class="text-lg"
                  title={Atom.to_string(entry.mood)}
                >
                  {mood_emoji(entry.mood)}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div :if={@has_more} class="mt-6 text-center">
          <button
            phx-click="load_more"
            class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
          >
            Load more
          </button>
        </div>
      </div>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    entries = Journal.list_journal_entries(user, limit: 20)
    decrypted_entries = decrypt_entries(entries, user, key)
    entry_count = Journal.count_entries(user)

    socket =
      socket
      |> assign(:page_title, "Journal")
      |> assign(:entries, decrypted_entries)
      |> assign(:entry_count, entry_count)
      |> assign(:total_words, Journal.total_word_count(user))
      |> assign(:streak, Journal.streak_days(user))
      |> assign(:offset, 20)
      |> assign(:has_more, length(entries) == 20)
      |> assign(:mood_insight, nil)
      |> assign(:loading_insights, false)

    if connected?(socket) && entry_count >= 3 do
      send(self(), :fetch_mood_insights)
      {:ok, assign(socket, :loading_insights, true)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    offset = socket.assigns.offset

    new_entries = Journal.list_journal_entries(user, limit: 20, offset: offset)
    decrypted_new = decrypt_entries(new_entries, user, key)

    {:noreply,
     socket
     |> assign(:entries, socket.assigns.entries ++ decrypted_new)
     |> assign(:offset, offset + 20)
     |> assign(:has_more, length(new_entries) == 20)}
  end

  @impl true
  def handle_event("refresh_insights", _params, socket) do
    send(self(), :fetch_mood_insights)
    {:noreply, assign(socket, :loading_insights, true)}
  end

  @impl true
  def handle_info(:fetch_mood_insights, socket) do
    user = socket.assigns.current_scope.user
    recent_entries = Journal.list_journal_entries(user, limit: 14)

    insight =
      case JournalAI.generate_mood_insights(recent_entries) do
        {:ok, text} -> text
        {:error, _} -> "Keep journaling! More entries help me understand your patterns better."
      end

    {:noreply,
     socket
     |> assign(:mood_insight, insight)
     |> assign(:loading_insights, false)}
  end

  defp decrypt_entries(entries, user, key) do
    Enum.map(entries, fn entry ->
      decrypted = Journal.decrypt_entry(entry, user, key)

      entry
      |> Map.put(:decrypted_title, decrypted.title)
      |> Map.put(:decrypted_body, decrypted.body)
    end)
  end

  defp truncate_body(nil), do: ""

  defp truncate_body(body) do
    if String.length(body) > 150 do
      String.slice(body, 0, 150) <> "..."
    else
      body
    end
  end

  defp format_date(date) do
    today = Date.utc_today()

    cond do
      date == today -> "Today"
      date == Date.add(today, -1) -> "Yesterday"
      true -> Calendar.strftime(date, "%b %d, %Y")
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
