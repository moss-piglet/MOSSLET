defmodule MossletWeb.BlueskyExportProgressLive do
  @moduledoc """
  Sticky LiveView component that shows Bluesky export progress.

  This is rendered in the app layout and subscribes to export progress
  via PubSub, so users see progress regardless of which page they're on.
  """
  use Phoenix.LiveView, layout: false

  import MossletWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: MossletWeb.Endpoint,
    router: MossletWeb.Router,
    statics: MossletWeb.static_paths()

  alias Mosslet.Bluesky.ExportTask

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    if connected?(socket) && user_id do
      ExportTask.subscribe(user_id)
    end

    {:ok, assign(socket, progress: nil, dismissed: false, user_id: user_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      :if={@progress && !@dismissed}
      id="bluesky-export-progress"
      class="fixed bottom-4 right-4 z-50 w-80 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-emerald-200 dark:border-emerald-700 overflow-hidden"
      phx-hook="BlueskyExportProgress"
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

        <%= if @progress.status == :started do %>
          <div class="space-y-2">
            <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
              <.phx_icon name="hero-arrow-path" class="h-4 w-4 animate-spin" />
              <span>Starting export...</span>
            </div>
            <.sync_steps current_step={:starting} />
          </div>
        <% end %>

        <%= if @progress.status == :checking_deleted do %>
          <div class="space-y-2">
            <div class="flex justify-between text-xs text-slate-600 dark:text-slate-400">
              <span>Checking for deleted posts...</span>
              <span>{@progress.exported} / {@progress.total}</span>
            </div>
            <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-1.5">
              <div
                class="bg-gradient-to-r from-amber-400 to-orange-500 h-1.5 rounded-full transition-all duration-300"
                style={"width: #{progress_percent(@progress)}%"}
              >
              </div>
            </div>
            <.sync_steps current_step={:checking} />
          </div>
        <% end %>

        <%= if @progress.status == :exporting do %>
          <div class="space-y-2">
            <div class="flex justify-between text-xs text-slate-600 dark:text-slate-400">
              <span>Exporting posts...</span>
              <span>{@progress.exported} / {@progress.total}</span>
            </div>
            <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-1.5">
              <div
                class="bg-gradient-to-r from-emerald-400 to-teal-500 h-1.5 rounded-full transition-all duration-300"
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
            <.sync_steps current_step={:posts} />
          </div>
        <% end %>

        <%= if @progress.status == :syncing_likes do %>
          <div class="space-y-2">
            <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
              <.phx_icon name="hero-arrow-path" class="h-4 w-4 animate-spin" />
              <span>Syncing likes to Bluesky...</span>
            </div>
            <.sync_steps current_step={:likes} />
          </div>
        <% end %>

        <%= if @progress.status == :syncing_bookmarks do %>
          <div class="space-y-2">
            <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
              <.phx_icon name="hero-arrow-path" class="h-4 w-4 animate-spin" />
              <span>Syncing bookmarks to Bluesky...</span>
            </div>
            <.sync_steps current_step={:bookmarks} />
          </div>
        <% end %>

        <%= if @progress.status == :completed do %>
          <div class="space-y-2">
            <p class="text-sm text-emerald-600 dark:text-emerald-400">
              <.phx_icon name="hero-check-circle" class="h-4 w-4 inline" />
              {@progress.exported} posts exported successfully
            </p>
            <.sync_steps current_step={:done} />
          </div>
        <% end %>

        <%= if @progress.status == :failed do %>
          <p class="text-sm text-rose-600 dark:text-rose-400">
            <.phx_icon name="hero-exclamation-circle" class="h-4 w-4 inline" /> Export failed
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  defp sync_steps(assigns) do
    ~H"""
    <div class="mt-2 pt-2 border-t border-slate-200 dark:border-slate-700">
      <div class="flex items-center gap-3 text-xs">
        <.step_indicator step={:posts} current={@current_step} label="Posts" />
        <.step_indicator step={:likes} current={@current_step} label="Likes" />
        <.step_indicator step={:bookmarks} current={@current_step} label="Bookmarks" />
      </div>
    </div>
    """
  end

  defp step_indicator(assigns) do
    status = step_status(assigns.step, assigns.current_step)
    assigns = assign(assigns, :status, status)

    ~H"""
    <div class="flex items-center gap-1">
      <%= case @status do %>
        <% :done -> %>
          <.phx_icon name="hero-check-circle-solid" class="h-3.5 w-3.5 text-emerald-500" />
        <% :active -> %>
          <.phx_icon name="hero-arrow-path" class="h-3.5 w-3.5 text-emerald-500 animate-spin" />
        <% :pending -> %>
          <div class="h-3.5 w-3.5 rounded-full border border-slate-300 dark:border-slate-600"></div>
      <% end %>
      <span class={[
        "text-slate-500 dark:text-slate-400",
        @status == :active && "text-emerald-600 dark:text-emerald-400 font-medium"
      ]}>
        {@label}
      </span>
    </div>
    """
  end

  defp step_status(step, current_step) do
    steps_order = [:starting, :checking, :posts, :likes, :bookmarks, :done]
    step_index = Enum.find_index(steps_order, &(&1 == step))
    current_index = Enum.find_index(steps_order, &(&1 == current_step))

    cond do
      current_step == :done -> :done
      step == current_step -> :active
      step == :posts and current_step in [:starting, :checking] -> :active
      step_index < current_index -> :done
      true -> :pending
    end
  end

  @impl true
  def handle_event("dismiss", _params, socket) do
    {:noreply, assign(socket, dismissed: true, progress: nil)}
  end

  @impl true
  def handle_info({:bluesky_export_progress, progress}, socket) do
    socket =
      socket
      |> assign(progress: progress)
      |> assign(dismissed: false)

    {:noreply, socket}
  end

  defp status_text(:started), do: "Bluesky Export"
  defp status_text(:checking_deleted), do: "Checking Deleted Posts"
  defp status_text(:exporting), do: "Exporting to Bluesky"
  defp status_text(:syncing_likes), do: "Syncing Likes"
  defp status_text(:syncing_bookmarks), do: "Syncing Bookmarks"
  defp status_text(:completed), do: "Export Complete"
  defp status_text(:failed), do: "Export Failed"

  defp progress_percent(%{exported: exported, total: total}) when total > 0 do
    round(exported / total * 100)
  end

  defp progress_percent(_), do: 0
end
