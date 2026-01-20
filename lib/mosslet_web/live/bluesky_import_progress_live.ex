defmodule MossletWeb.BlueskyImportProgressLive do
  @moduledoc """
  Sticky LiveView component that shows Bluesky import progress.

  This is rendered in the app layout and subscribes to import progress
  via PubSub, so users see progress regardless of which page they're on.
  """
  use Phoenix.LiveView, layout: false

  import MossletWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: MossletWeb.Endpoint,
    router: MossletWeb.Router,
    statics: MossletWeb.static_paths()

  alias Mosslet.Bluesky.ImportTask

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    if connected?(socket) && user_id do
      ImportTask.subscribe(user_id)
    end

    {:ok, assign(socket, progress: nil, dismissed: false, user_id: user_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      :if={@progress && !@dismissed}
      id="bluesky-import-progress"
      class="fixed bottom-4 right-4 z-50 w-80 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-sky-200 dark:border-sky-700 overflow-hidden"
      phx-hook="BlueskyImportProgress"
    >
      <div class="px-4 py-3">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="text-lg">🦋</span>
            <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
              {status_text(@progress.status)}
            </span>
          </div>
          <button
            :if={@progress.status in [:completed, :failed]}
            type="button"
            phx-click="dismiss"
            class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
          >
            <.phx_icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>

        <%= if @progress.status == :importing do %>
          <div class="space-y-2">
            <div class="flex justify-between text-xs text-slate-600 dark:text-slate-400">
              <span>Importing posts...</span>
              <span>{@progress.imported} / {@progress.total}</span>
            </div>
            <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-1.5">
              <div
                class="bg-gradient-to-r from-sky-400 to-blue-500 h-1.5 rounded-full transition-all duration-300"
                style={"width: #{progress_percent(@progress)}%"}
              >
              </div>
            </div>
            <p
              :if={@progress[:current_post]}
              class="text-xs text-slate-500 dark:text-slate-400 truncate"
            >
              {@progress.current_post}
            </p>
          </div>
        <% end %>

        <%= if @progress.status == :completed do %>
          <p class="text-sm text-emerald-600 dark:text-emerald-400">
            <.phx_icon name="hero-check-circle" class="h-4 w-4 inline" />
            {@progress.imported} posts imported successfully
          </p>
        <% end %>

        <%= if @progress.status == :failed do %>
          <p class="text-sm text-rose-600 dark:text-rose-400">
            <.phx_icon name="hero-exclamation-circle" class="h-4 w-4 inline" /> Import failed
          </p>
        <% end %>

        <%= if @progress.status == :started do %>
          <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
            <.phx_icon name="hero-arrow-path" class="h-4 w-4 animate-spin" />
            <span>Starting import...</span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("dismiss", _params, socket) do
    {:noreply, assign(socket, dismissed: true, progress: nil)}
  end

  @impl true
  def handle_info({:bluesky_import_progress, progress}, socket) do
    socket =
      socket
      |> assign(progress: progress)
      |> assign(dismissed: false)

    {:noreply, socket}
  end

  defp status_text(:started), do: "Bluesky Import"
  defp status_text(:importing), do: "Importing from Bluesky"
  defp status_text(:completed), do: "Import Complete"
  defp status_text(:failed), do: "Import Failed"

  defp progress_percent(%{imported: imported, total: total}) when total > 0 do
    round(imported / total * 100)
  end

  defp progress_percent(_), do: 0
end
