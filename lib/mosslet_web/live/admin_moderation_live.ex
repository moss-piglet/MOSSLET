defmodule MossletWeb.AdminModerationLive do
  @moduledoc """
  Admin moderation dashboard for reviewing and managing content reports.

  Features:
  - Real-time report notifications via PubSub
  - Liquid metal design consistent with app theme
  - Server-key decryption for admin review
  - Bulk actions and filtering
  - Performance optimized for distributed Fly.io architecture
  """
  use MossletWeb, :live_view

  alias Mosslet.Timeline

  # Import liquid design components
  import MossletWeb.DesignSystem

  def render(assigns) do
    ~H"""
    <.layout current_page={:admin_moderation} current_user={@current_user} key={@key} type="sidebar">
      <div class="min-h-screen bg-slate-50 dark:bg-slate-900">
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <%!-- Header --%>
          <div class="mb-8 md:flex md:items-center md:justify-between">
            <div class="min-w-0 flex-1">
              <h1 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
                Content Moderation
              </h1>
              <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
                Review and manage community reports
              </p>
            </div>

            <div class="mt-4 flex space-x-2 md:mt-0">
              <.liquid_button
                variant="ghost"
                color="slate"
                phx-click="refresh_reports"
                icon="hero-arrow-path"
              >
                Refresh
              </.liquid_button>

              <.liquid_button
                navigate={~p"/admin/dash"}
                variant="secondary"
                color="indigo"
                icon="hero-chart-bar"
              >
                Dashboard
              </.liquid_button>
            </div>
          </div>

          <%!-- Filter Bar --%>
          <div class="mb-6 rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg p-4">
            <div class="flex flex-wrap gap-3">
              <div class="flex items-center space-x-2">
                <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Status:</label>
                <select
                  class="rounded-lg border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-sm"
                  phx-change="filter_status"
                  name="status"
                >
                  <option value="">All</option>
                  <option value="pending" selected={@filter_status == "pending"}>Pending</option>
                  <option value="reviewed" selected={@filter_status == "reviewed"}>Reviewed</option>
                  <option value="resolved" selected={@filter_status == "resolved"}>Resolved</option>
                  <option value="dismissed" selected={@filter_status == "dismissed"}>
                    Dismissed
                  </option>
                </select>
              </div>

              <div class="flex items-center space-x-2">
                <label class="text-sm font-medium text-slate-700 dark:text-slate-300">
                  Severity:
                </label>
                <select
                  class="rounded-lg border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-sm"
                  phx-change="filter_severity"
                  name="severity"
                >
                  <option value="">All</option>
                  <option value="critical" selected={@filter_severity == "critical"}>Critical</option>
                  <option value="high" selected={@filter_severity == "high"}>High</option>
                  <option value="medium" selected={@filter_severity == "medium"}>Medium</option>
                  <option value="low" selected={@filter_severity == "low"}>Low</option>
                </select>
              </div>

              <div class="flex items-center space-x-2">
                <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Type:</label>
                <select
                  class="rounded-lg border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-sm"
                  phx-change="filter_type"
                  name="report_type"
                >
                  <option value="">All</option>
                  <option value="content" selected={@filter_type == "content"}>Content</option>
                  <option value="harassment" selected={@filter_type == "harassment"}>
                    Harassment
                  </option>
                  <option value="spam" selected={@filter_type == "spam"}>Spam</option>
                  <option value="other" selected={@filter_type == "other"}>Other</option>
                </select>
              </div>
            </div>
          </div>

          <%!-- Reports List --%>
          <div id="reports" phx-update="stream">
            <%!-- Empty state using CSS only:block pattern --%>
            <div class="hidden only:block rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg p-8 text-center">
              <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-700">
                <.phx_icon
                  name="hero-shield-check"
                  class="h-6 w-6 text-slate-600 dark:text-slate-400"
                />
              </div>
              <h3 class="mt-2 text-sm font-semibold text-slate-900 dark:text-slate-100">
                No reports
              </h3>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                No reports match your current filters.
              </p>
            </div>

            <%!-- Stream items --%>
            <div
              :for={{id, report} <- @streams.reports}
              id={id}
              class="rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg mb-4"
            >
              <.report_card report={report} current_user={@current_user} />
            </div>
          </div>

          <%!-- Load More Button --%>
          <div :if={@loaded_reports_count >= 10} class="mt-8 flex justify-center">
            <.liquid_button
              :if={!@load_more_loading}
              variant="secondary"
              color="slate"
              phx-click="load_more_reports"
              icon="hero-arrow-down"
            >
              Load More Reports
            </.liquid_button>

            <.liquid_button
              :if={@load_more_loading}
              variant="secondary"
              color="slate"
              disabled
            >
              <div class="flex items-center space-x-2">
                <div class="animate-spin rounded-full h-4 w-4 border-2 border-slate-300 border-t-slate-600">
                </div>
                <span>Loading...</span>
              </div>
            </.liquid_button>
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Timeline.admin_subscribe(socket.assigns.current_user)
    end

    socket =
      socket
      |> assign(:page_title, "Admin Moderation")
      |> assign(:filter_status, "pending")
      |> assign(:filter_severity, "")
      |> assign(:filter_type, "")
      |> assign(:current_page, 1)
      |> assign(:load_more_loading, false)
      |> assign(:loaded_reports_count, 0)
      |> stream(:reports, [])
      |> load_reports()

    {:ok, socket}
  end

  # PubSub event handlers
  def handle_info({:report_created, report}, socket) do
    # Add new report to the top of the stream
    {:noreply, stream_insert(socket, :reports, report, at: 0)}
  end

  def handle_info({:report_updated, updated_report}, socket) do
    # Update the report in the stream
    {:noreply, stream_insert(socket, :reports, updated_report)}
  end

  # Filter event handlers
  def handle_event("filter_status", %{"status" => status}, socket) do
    socket =
      socket
      |> assign(:filter_status, status)
      |> assign(:current_page, 1)
      |> assign(:loaded_reports_count, 0)
      |> load_reports()

    {:noreply, socket}
  end

  def handle_event("filter_severity", %{"severity" => severity}, socket) do
    socket =
      socket
      |> assign(:filter_severity, severity)
      |> assign(:current_page, 1)
      |> assign(:loaded_reports_count, 0)
      |> load_reports()

    {:noreply, socket}
  end

  def handle_event("filter_type", %{"report_type" => report_type}, socket) do
    socket =
      socket
      |> assign(:filter_type, report_type)
      |> assign(:current_page, 1)
      |> assign(:loaded_reports_count, 0)
      |> load_reports()

    {:noreply, socket}
  end

  def handle_event("load_more_reports", _params, socket) do
    current_page = socket.assigns.current_page
    next_page = current_page + 1

    socket = assign(socket, :load_more_loading, true)

    # Load more reports
    filters = build_filters(socket.assigns)
    additional_filters = Keyword.put(filters, :page, next_page)
    new_reports = Timeline.list_post_reports(additional_filters)

    socket =
      socket
      |> assign(:current_page, next_page)
      |> assign(:loaded_reports_count, socket.assigns.loaded_reports_count + length(new_reports))
      |> assign(:load_more_loading, false)
      # Simple stream insertion!
      |> stream(:reports, new_reports)

    {:noreply, socket}
  end

  def handle_event("refresh_reports", _params, socket) do
    socket =
      socket
      |> assign(:current_page, 1)
      |> assign(:loaded_reports_count, 0)
      |> load_reports()

    {:noreply, socket}
  end

  def handle_event(
        "update_report_status",
        %{"report_id" => report_id, "status" => status},
        socket
      ) do
    case Timeline.get_post_report(report_id) do
      nil ->
        socket = put_flash(socket, :error, "Report not found")
        {:noreply, socket}

      report ->
        case Timeline.update_post_report(
               report,
               %{"status" => status},
               socket.assigns.current_user
             ) do
          {:ok, _updated_report} ->
            socket =
              socket
              |> put_flash(:info, "Report status updated to #{status}")
              |> load_reports()

            {:noreply, socket}

          {:error, _changeset} ->
            socket = put_flash(socket, :error, "Failed to update report")
            {:noreply, socket}
        end
    end
  end

  # Private helpers
  defp load_reports(socket) do
    filters = build_filters(socket.assigns)
    reports = Timeline.list_post_reports(filters)

    socket
    |> assign(:loaded_reports_count, length(reports))
    |> stream(:reports, reports, reset: true)
  end

  defp build_filters(assigns) do
    []
    |> maybe_add_filter(:status, assigns.filter_status)
    |> maybe_add_filter(:severity, assigns.filter_severity)
    |> maybe_add_filter(:report_type, assigns.filter_type)
    # 10 reports per page
    |> Keyword.put(:limit, 10)
    |> Keyword.put(:page, assigns[:current_page] || 1)
  end

  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Keyword.put(filters, key, String.to_atom(value))

  # Report card component
  attr :report, :map, required: true
  attr :current_user, :map, required: true

  defp report_card(assigns) do
    ~H"""
    <div class="p-6">
      <%!-- Report Header --%>
      <div class="flex items-start justify-between">
        <div class="flex items-start space-x-3">
          <%!-- Severity Badge --%>
          <div class={[
            "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
            severity_color_class(@report.severity)
          ]}>
            {@report.severity |> to_string() |> String.capitalize()}
          </div>

          <%!-- Status Badge --%>
          <div class={[
            "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
            status_color_class(@report.status)
          ]}>
            {@report.status |> to_string() |> String.capitalize()}
          </div>

          <%!-- Type Badge --%>
          <div class="inline-flex items-center rounded-full bg-slate-100 dark:bg-slate-700 px-2.5 py-0.5 text-xs font-medium text-slate-800 dark:text-slate-200">
            {@report.report_type |> to_string() |> String.capitalize()}
          </div>
        </div>

        <div class="text-sm text-slate-500 dark:text-slate-400">
          {Calendar.strftime(@report.inserted_at, "%b %d, %Y at %I:%M %p")}
        </div>
      </div>

      <%!-- Report Content --%>
      <div class="mt-4">
        <div class="text-sm text-slate-600 dark:text-slate-400">
          <strong>Reporter:</strong> {@report.reporter.email} |
          <strong>Reported User:</strong> {@report.reported_user.email}
        </div>

        <div class="mt-2">
          <div class="text-sm font-medium text-slate-900 dark:text-slate-100">Reason:</div>
          <div class="mt-1 text-sm text-slate-700 dark:text-slate-300">
            {decrypt_report_reason(@report, @current_user)}
          </div>
        </div>

        <%= if @report.details do %>
          <div class="mt-2">
            <div class="text-sm font-medium text-slate-900 dark:text-slate-100">Details:</div>
            <div class="mt-1 text-sm text-slate-700 dark:text-slate-300">
              {decrypt_report_details(@report, @current_user)}
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Actions --%>
      <%= if @report.status == :pending do %>
        <div class="mt-6 flex space-x-3">
          <.liquid_button
            size="sm"
            color="emerald"
            phx-click="update_report_status"
            phx-value-report_id={@report.id}
            phx-value-status="reviewed"
          >
            Mark Reviewed
          </.liquid_button>

          <.liquid_button
            size="sm"
            color="blue"
            phx-click="update_report_status"
            phx-value-report_id={@report.id}
            phx-value-status="resolved"
          >
            Resolve
          </.liquid_button>

          <.liquid_button
            size="sm"
            color="slate"
            variant="ghost"
            phx-click="update_report_status"
            phx-value-report_id={@report.id}
            phx-value-status="dismissed"
          >
            Dismiss
          </.liquid_button>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions for styling
  defp severity_color_class(:critical),
    do: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"

  defp severity_color_class(:high),
    do: "bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400"

  defp severity_color_class(:medium),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"

  defp severity_color_class(:low),
    do: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"

  defp status_color_class(:pending),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"

  defp status_color_class(:reviewed),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400"

  defp status_color_class(:resolved),
    do: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"

  defp status_color_class(:dismissed),
    do: "bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300"

  # Server-key decryption helpers (admin-only) using existing helper
  defp decrypt_report_reason(report, current_user) do
    if current_user.is_admin? and report.reason do
      case decr_public_item(report.reason, get_report_key(report)) do
        decrypted when is_binary(decrypted) -> decrypted
        _ -> "[Decryption failed]"
      end
    else
      "[Encrypted]"
    end
  end

  defp decrypt_report_details(report, current_user) do
    if current_user.is_admin? and report.details do
      case decr_public_item(report.details, get_report_key(report)) do
        decrypted when is_binary(decrypted) -> decrypted
        _ -> "[Decryption failed]"
      end
    else
      "[Encrypted]"
    end
  end

  defp get_report_key(report) do
    report.user_post_report.key
  end
end
