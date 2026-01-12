defmodule MossletWeb.AdminBackupsLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Backups
  alias Mosslet.Workers.DatabaseBackupWorker

  def render(assigns) do
    ~H"""
    <.layout
      current_page={:admin_backups}
      sidebar_current_page={:admin_backups}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50 via-slate-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800">
        <div class="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
          <header class="mb-6">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div class="flex items-center gap-3">
                <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 shadow-lg shadow-emerald-500/20">
                  <.phx_icon name="hero-server-stack" class="h-6 w-6 text-white" />
                </div>
                <div>
                  <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
                    Database Backups
                  </h1>
                  <p class="text-sm text-slate-500 dark:text-slate-400">
                    Automated daily backups with smart retention
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-2">
                <.link
                  navigate={~p"/admin/dash"}
                  class="inline-flex items-center gap-2 rounded-lg bg-white/80 dark:bg-slate-800/80 px-3 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 shadow-sm border border-slate-200/60 dark:border-slate-700/60 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
                >
                  <.phx_icon name="hero-arrow-left" class="h-4 w-4" /> Dashboard
                </.link>
                <button
                  phx-click="trigger_backup"
                  disabled={@backup_in_progress}
                  class={[
                    "inline-flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium shadow-sm transition-colors",
                    @backup_in_progress &&
                      "bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300 cursor-not-allowed",
                    !@backup_in_progress && "bg-emerald-700 text-white hover:bg-emerald-800"
                  ]}
                >
                  <.phx_icon
                    name={if @backup_in_progress, do: "hero-arrow-path", else: "hero-plus"}
                    class={["h-4 w-4", @backup_in_progress && "animate-spin"]}
                  />
                  {if @backup_in_progress, do: "Backup in progress...", else: "Manual Backup"}
                </button>
              </div>
            </div>
          </header>

          <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4 mb-6">
            <.stat_card
              title="Total Backups"
              value={@stats.total}
              icon="hero-archive-box"
              color="blue"
            />
            <.stat_card
              title="Completed"
              value={@stats.completed}
              icon="hero-check-circle"
              color="emerald"
            />
            <.stat_card
              title="Failed"
              value={@stats.failed}
              icon="hero-x-circle"
              color="rose"
            />
            <.stat_card
              title="Total Size"
              value={format_size(@total_size)}
              icon="hero-circle-stack"
              color="purple"
              is_text={true}
            />
          </div>

          <div class="rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm overflow-hidden">
            <div class="px-4 py-3 border-b border-slate-200/60 dark:border-slate-700/60">
              <h2 class="text-sm font-semibold text-slate-900 dark:text-slate-100">Recent Backups</h2>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                Retention: 7 daily + 4 weekly backups
              </p>
            </div>

            <div
              class="divide-y divide-slate-200/60 dark:divide-slate-700/60"
              id="backups-list"
              phx-update="stream"
            >
              <div
                :for={{dom_id, backup} <- @streams.backups}
                id={dom_id}
                class="px-4 py-3 flex items-center justify-between hover:bg-slate-50/50 dark:hover:bg-slate-700/30 transition-colors"
              >
                <div class="flex items-center gap-3 min-w-0">
                  <div class={[
                    "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg",
                    status_bg(backup.status)
                  ]}>
                    <.phx_icon
                      name={status_icon(backup.status)}
                      class={["h-4 w-4", status_color(backup.status)]}
                    />
                  </div>
                  <div class="min-w-0">
                    <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                      {backup.filename}
                    </p>
                    <div class="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
                      <span>{format_datetime(backup.inserted_at)}</span>
                      <span>•</span>
                      <span class={[
                        "inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium",
                        type_badge_class(backup.backup_type)
                      ]}>
                        {backup.backup_type}
                      </span>
                      <span :if={backup.size_bytes > 0}>•</span>
                      <span :if={backup.size_bytes > 0}>{format_size(backup.size_bytes)}</span>
                    </div>
                    <p
                      :if={backup.error_message}
                      class="text-xs text-rose-600 dark:text-rose-400 mt-0.5 truncate"
                    >
                      {backup.error_message}
                    </p>
                  </div>
                </div>
                <div :if={backup.status == "completed"} class="shrink-0 flex items-center gap-1">
                  <button
                    phx-click="download_backup"
                    phx-value-id={backup.id}
                    class="inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
                  >
                    <.phx_icon name="hero-arrow-down-tray" class="h-3.5 w-3.5" /> Download
                  </button>
                  <button
                    phx-click="delete_backup"
                    phx-value-id={backup.id}
                    data-confirm="Are you sure you want to delete this backup?"
                    aria-label="Delete backup"
                    class="inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-medium text-rose-600 dark:text-rose-400 hover:text-rose-800 dark:hover:text-rose-300 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-colors"
                  >
                    <.phx_icon name="hero-trash" class="h-3.5 w-3.5" />
                  </button>
                </div>
                <div :if={backup.status == "failed"} class="shrink-0 flex items-center gap-1">
                  <button
                    phx-click="retry_backup"
                    phx-value-id={backup.id}
                    class="inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-medium text-amber-600 dark:text-amber-400 hover:text-amber-800 dark:hover:text-amber-300 hover:bg-amber-50 dark:hover:bg-amber-900/30 transition-colors"
                  >
                    <.phx_icon name="hero-arrow-path" class="h-3.5 w-3.5" /> Retry
                  </button>
                  <button
                    phx-click="delete_backup"
                    phx-value-id={backup.id}
                    data-confirm="Are you sure you want to delete this backup record?"
                    aria-label="Delete backup"
                    class="inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs font-medium text-rose-600 dark:text-rose-400 hover:text-rose-800 dark:hover:text-rose-300 hover:bg-rose-50 dark:hover:bg-rose-900/30 transition-colors"
                  >
                    <.phx_icon name="hero-trash" class="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            </div>

            <div :if={@streams.backups == []} class="px-4 py-12 text-center">
              <.phx_icon
                name="hero-archive-box"
                class="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600"
              />
              <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">No backups yet</p>
              <p class="text-xs text-slate-400 dark:text-slate-500">
                Backups run automatically daily at 3 AM UTC
              </p>
            </div>
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "slate"
  attr :is_text, :boolean, default: false

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-sm p-4 sm:p-5">
      <div class="flex items-center gap-3">
        <div class={[
          "flex h-10 w-10 sm:h-11 sm:w-11 shrink-0 items-center justify-center rounded-lg",
          stat_icon_bg(@color)
        ]}>
          <.phx_icon name={@icon} class={["h-5 w-5 sm:h-6 sm:w-6", stat_icon_color(@color)]} />
        </div>
        <div class="min-w-0">
          <p class="text-xs sm:text-sm font-medium text-slate-500 dark:text-slate-400 truncate">
            {@title}
          </p>
          <p class="text-xl sm:text-2xl font-bold text-slate-900 dark:text-slate-100">
            {@value}
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp stat_icon_bg("blue"), do: "bg-blue-100 dark:bg-blue-900/50"
  defp stat_icon_bg("emerald"), do: "bg-emerald-100 dark:bg-emerald-900/50"
  defp stat_icon_bg("rose"), do: "bg-rose-100 dark:bg-rose-900/50"
  defp stat_icon_bg("purple"), do: "bg-purple-100 dark:bg-purple-900/50"
  defp stat_icon_bg(_), do: "bg-slate-100 dark:bg-slate-700/50"

  defp stat_icon_color("blue"), do: "text-blue-600 dark:text-blue-400"
  defp stat_icon_color("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp stat_icon_color("rose"), do: "text-rose-600 dark:text-rose-400"
  defp stat_icon_color("purple"), do: "text-purple-600 dark:text-purple-400"
  defp stat_icon_color(_), do: "text-slate-600 dark:text-slate-400"

  defp status_icon("completed"), do: "hero-check-circle"
  defp status_icon("failed"), do: "hero-x-circle"
  defp status_icon("in_progress"), do: "hero-arrow-path"
  defp status_icon(_), do: "hero-question-mark-circle"

  defp status_bg("completed"), do: "bg-emerald-100 dark:bg-emerald-900/50"
  defp status_bg("failed"), do: "bg-rose-100 dark:bg-rose-900/50"
  defp status_bg("in_progress"), do: "bg-amber-100 dark:bg-amber-900/50"
  defp status_bg(_), do: "bg-slate-100 dark:bg-slate-700/50"

  defp status_color("completed"), do: "text-emerald-600 dark:text-emerald-400"
  defp status_color("failed"), do: "text-rose-600 dark:text-rose-400"
  defp status_color("in_progress"), do: "text-amber-600 dark:text-amber-400 animate-spin"
  defp status_color(_), do: "text-slate-600 dark:text-slate-400"

  defp type_badge_class("manual"),
    do: "bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300"

  defp type_badge_class(_),
    do: "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"

  defp format_size(bytes) when is_integer(bytes) and bytes < 1024, do: "#{bytes} B"

  defp format_size(bytes) when is_integer(bytes) and bytes < 1_048_576,
    do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_size(bytes) when is_integer(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_size(_), do: "0 B"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %H:%M UTC")
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "backups")
      Process.send_after(self(), :refresh_stats, 5000)
    end

    backups = Backups.list_backups(limit: 20)
    status_counts = Backups.count_backups_by_status()

    socket =
      socket
      |> assign(:page_title, "Database Backups")
      |> assign(:stats, %{
        total: Enum.sum(Map.values(status_counts)),
        completed: Map.get(status_counts, "completed", 0),
        failed: Map.get(status_counts, "failed", 0)
      })
      |> assign(:total_size, Backups.total_backup_size())
      |> assign(:backup_in_progress, has_backup_in_progress?(status_counts))
      |> stream(:backups, backups)

    {:ok, socket}
  end

  defp has_backup_in_progress?(status_counts) do
    Map.get(status_counts, "in_progress", 0) > 0
  end

  def handle_event("trigger_backup", _params, socket) do
    case DatabaseBackupWorker.enqueue_manual_backup() do
      {:ok, _job} ->
        {:noreply,
         socket
         |> assign(:backup_in_progress, true)
         |> put_flash(:info, "Manual backup started")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start backup")}
    end
  end

  def handle_event("download_backup", %{"id" => id}, socket) do
    backup = Backups.get_backup!(id)

    case Backups.get_download_url(backup) do
      {:ok, url} ->
        {:noreply, redirect(socket, external: url)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to generate download URL")}
    end
  end

  def handle_event("delete_backup", %{"id" => id}, socket) do
    backup = Backups.get_backup!(id)

    case Backups.delete_backup(backup) do
      {:ok, _} ->
        {:noreply,
         socket
         |> stream_delete(:backups, backup)
         |> refresh_stats()
         |> put_flash(:info, "Backup deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete backup")}
    end
  end

  def handle_event("retry_backup", %{"id" => id}, socket) do
    backup = Backups.get_backup!(id)
    Backups.delete_backup(backup)

    case DatabaseBackupWorker.enqueue_manual_backup() do
      {:ok, _job} ->
        {:noreply,
         socket
         |> stream_delete(:backups, backup)
         |> assign(:backup_in_progress, true)
         |> put_flash(:info, "Retrying backup...")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start backup")}
    end
  end

  def handle_info(:refresh_stats, socket) do
    status_counts = Backups.count_backups_by_status()

    socket =
      socket
      |> assign(:stats, %{
        total: Enum.sum(Map.values(status_counts)),
        completed: Map.get(status_counts, "completed", 0),
        failed: Map.get(status_counts, "failed", 0)
      })
      |> assign(:total_size, Backups.total_backup_size())
      |> assign(:backup_in_progress, has_backup_in_progress?(status_counts))

    if connected?(socket) do
      Process.send_after(self(), :refresh_stats, 5000)
    end

    {:noreply, socket}
  end

  def handle_info({:backup_completed, backup}, socket) do
    {:noreply,
     socket
     |> stream_insert(:backups, backup, at: 0)
     |> refresh_stats()}
  end

  def handle_info({:backup_failed, backup}, socket) do
    {:noreply,
     socket
     |> stream_insert(:backups, backup, at: 0)
     |> refresh_stats()}
  end

  defp refresh_stats(socket) do
    status_counts = Backups.count_backups_by_status()

    socket
    |> assign(:stats, %{
      total: Enum.sum(Map.values(status_counts)),
      completed: Map.get(status_counts, "completed", 0),
      failed: Map.get(status_counts, "failed", 0)
    })
    |> assign(:total_size, Backups.total_backup_size())
    |> assign(:backup_in_progress, has_backup_in_progress?(status_counts))
  end
end
