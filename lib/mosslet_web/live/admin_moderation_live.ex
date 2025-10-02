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
  alias Mosslet.Accounts

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
            <.form phx-change="filter_changed" class="flex flex-wrap gap-3">
              <div class="flex items-center space-x-2">
                <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Status:</label>
                <select
                  class="rounded-lg border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-sm"
                  name="status"
                  value={@filter_status}
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
                  name="severity"
                  value={@filter_severity}
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
                  name="report_type"
                  value={@filter_type}
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
            </.form>
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
              <.report_card
                report={report}
                current_user={@current_user}
                reporter_stats={@reporter_stats}
                reported_user_stats={@reported_user_stats}
              />
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
      |> assign(:filter_status, "")
      |> assign(:filter_severity, "")
      |> assign(:filter_type, "")
      |> assign(:current_page, 1)
      |> assign(:load_more_loading, false)
      |> assign(:loaded_reports_count, 0)
      |> assign(:reporter_stats, %{})
      |> assign(:reported_user_stats, %{})
      |> stream(:reports, [])
      |> load_reports()

    {:ok, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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
  def handle_event("filter_changed", params, socket) do
    # Handle form-based filter changes
    socket =
      socket
      |> assign(:filter_status, Map.get(params, "status", socket.assigns.filter_status))
      |> assign(:filter_severity, Map.get(params, "severity", socket.assigns.filter_severity))
      |> assign(:filter_type, Map.get(params, "report_type", socket.assigns.filter_type))
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

  def handle_event(
        "delete_reported_post",
        %{"post_id" => post_id, "report_id" => report_id},
        socket
      ) do
    with post when not is_nil(post) <- Timeline.get_post(post_id),
         {:ok, _deleted_post} <- Timeline.delete_post(post, socket.assigns.current_user),
         report when not is_nil(report) <- Timeline.get_post_report(report_id),
         {:ok, updated_report} <-
           Timeline.update_post_report(
             report,
             %{"status" => "resolved"},
             socket.assigns.current_user
           ) do
      socket =
        socket
        |> put_flash(:info, "Post deleted and report resolved")
        |> stream_insert(:reports, updated_report)

      {:noreply, socket}
    else
      _error ->
        socket = put_flash(socket, :error, "Failed to delete post")
        {:noreply, socket}
    end
  end

  def handle_event(
        "suspend_reported_user",
        %{"user_id" => user_id, "report_id" => report_id},
        socket
      ) do
    with user when not is_nil(user) <- Accounts.get_user(user_id),
         {:ok, _suspended_user} <- Accounts.suspend_user(user, socket.assigns.current_user),
         report when not is_nil(report) <- Timeline.get_post_report(report_id),
         {:ok, updated_report} <-
           Timeline.update_post_report(
             report,
             %{"status" => "resolved"},
             socket.assigns.current_user
           ) do
      socket =
        socket
        |> put_flash(:info, "User suspended and report resolved")
        |> stream_insert(:reports, updated_report)

      {:noreply, socket}
    else
      _error ->
        socket = put_flash(socket, :error, "Failed to suspend user")
        {:noreply, socket}
    end
  end

  def handle_event("investigate_reporter", %{"reporter_id" => reporter_id}, socket) do
    # Toggle reporter stats - if already showing, hide them; if not showing, load and show
    current_stats = socket.assigns.reporter_stats

    if Map.has_key?(current_stats, reporter_id) do
      # Hide stats if already showing
      updated_stats = Map.delete(current_stats, reporter_id)

      socket =
        socket
        |> assign(:reporter_stats, updated_stats)
        |> refresh_reports_stream()

      {:noreply, socket}
    else
      # Show stats if not already showing
      case Timeline.get_reporter_statistics(reporter_id) do
        {:ok, stats} ->
          updated_stats = Map.put(current_stats, reporter_id, stats)

          socket =
            socket
            |> assign(:reporter_stats, updated_stats)
            |> refresh_reports_stream()

          {:noreply, socket}

        _error ->
          socket = put_flash(socket, :error, "Could not retrieve reporter statistics")
          {:noreply, socket}
      end
    end
  end

  def handle_event("investigate_reported_user", %{"reported_user_id" => reported_user_id}, socket) do
    # Toggle reported user stats - if already showing, hide them; if not showing, load and show
    current_stats = socket.assigns.reported_user_stats

    if Map.has_key?(current_stats, reported_user_id) do
      # Hide stats if already showing
      updated_stats = Map.delete(current_stats, reported_user_id)

      socket =
        socket
        |> assign(:reported_user_stats, updated_stats)
        |> refresh_reports_stream()

      {:noreply, socket}
    else
      # Show stats if not already showing
      case Timeline.get_reported_user_statistics(reported_user_id) do
        {:ok, stats} ->
          updated_stats = Map.put(current_stats, reported_user_id, stats)

          socket =
            socket
            |> assign(:reported_user_stats, updated_stats)
            |> refresh_reports_stream()

          {:noreply, socket}

        _error ->
          socket = put_flash(socket, :error, "Could not retrieve reported user statistics")
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

  # Helper to refresh the reports stream to trigger re-render with updated statistics
  defp refresh_reports_stream(socket) do
    # Get current reports and re-stream them to trigger re-render
    filters = build_filters(socket.assigns)
    reports = Timeline.list_post_reports(filters)

    stream(socket, :reports, reports, reset: true)
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
  attr :reporter_stats, :map, default: %{}
  attr :reported_user_stats, :map, default: %{}

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
          <strong>Reporter:</strong> {@report.reporter.id} |
          <strong>Reported User:</strong> {@report.reported_user.id}
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

      <%!-- Actions - Show for all statuses with contextual options --%>
      <div class="mt-6 space-y-4">
        <!-- Status Change Actions -->
        <div class="flex flex-wrap gap-3">
          <%= if @report.status != :pending do %>
            <.liquid_button
              size="sm"
              color="amber"
              phx-click="update_report_status"
              phx-value-report_id={@report.id}
              phx-value-status="pending"
              icon="hero-arrow-uturn-left"
            >
              Reopen
            </.liquid_button>
          <% end %>

          <%= if @report.status != :reviewed do %>
            <.liquid_button
              size="sm"
              color="emerald"
              phx-click="update_report_status"
              phx-value-report_id={@report.id}
              phx-value-status="reviewed"
            >
              Mark Reviewed
            </.liquid_button>
          <% end %>

          <%= if @report.status != :resolved do %>
            <.liquid_button
              size="sm"
              color="blue"
              phx-click="update_report_status"
              phx-value-report_id={@report.id}
              phx-value-status="resolved"
            >
              Resolve
            </.liquid_button>
          <% end %>

          <%= if @report.status != :dismissed do %>
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
          <% end %>
        </div>
        
    <!-- Advanced Moderation Actions (Available for all except dismissed) -->
        <%= if @report.status != :dismissed do %>
          <div class="flex flex-wrap gap-3 pt-3 border-t border-slate-200 dark:border-slate-700">
            <.liquid_button
              size="sm"
              color="amber"
              phx-click="delete_reported_post"
              phx-value-post_id={@report.post.id}
              phx-value-report_id={@report.id}
              data-confirm="Are you sure you want to delete this post? This action cannot be undone."
              icon="hero-trash"
            >
              Delete Post
            </.liquid_button>

            <.liquid_button
              size="sm"
              color="rose"
              phx-click="suspend_reported_user"
              phx-value-user_id={@report.reported_user.id}
              phx-value-report_id={@report.id}
              data-confirm="Are you sure you want to suspend this user?"
              icon="hero-no-symbol"
            >
              Suspend User
            </.liquid_button>

            <.liquid_button
              size="sm"
              color="purple"
              variant="ghost"
              phx-click="investigate_reporter"
              phx-value-reporter_id={@report.reporter.id}
              icon="hero-magnifying-glass"
            >
              {if Map.has_key?(@reporter_stats || %{}, @report.reporter.id),
                do: "Hide Reporter Stats",
                else: "Check Reporter"}
            </.liquid_button>

            <.liquid_button
              size="sm"
              color="indigo"
              variant="ghost"
              phx-click="investigate_reported_user"
              phx-value-reported_user_id={@report.reported_user.id}
              icon="hero-user-circle"
            >
              {if Map.has_key?(@reported_user_stats || %{}, @report.reported_user.id),
                do: "Hide User Stats",
                else: "Check Reported User"}
            </.liquid_button>
          </div>

          <%!-- Reporter Statistics Collapsible Display --%>
          <%= if Map.has_key?(@reporter_stats || %{}, @report.reporter.id) do %>
            <.liquid_collapsible_reporter_stats
              stats={@reporter_stats[@report.reporter.id]}
              reporter_id={@report.reporter.id}
            />
          <% end %>

          <%!-- Reported User Statistics Collapsible Display --%>
          <%= if Map.has_key?(@reported_user_stats || %{}, @report.reported_user.id) do %>
            <.liquid_collapsible_reported_user_stats
              stats={@reported_user_stats[@report.reported_user.id]}
              reported_user_id={@report.reported_user.id}
            />
          <% end %>
        <% end %>
      </div>
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

  # Server-key decryption helpers (admin-only)
  defp decrypt_report_reason(report, current_user) do
    if current_user.is_admin? and report.reason do
      case get_report_key(report) do
        nil ->
          "[No decryption key available]"

        key ->
          case decr_public_item(report.reason, key) do
            decrypted when is_binary(decrypted) -> decrypted
            _ -> "[Decryption failed]"
          end
      end
    else
      "[Encrypted]"
    end
  end

  defp decrypt_report_details(report, current_user) do
    if current_user.is_admin? and report.details do
      case get_report_key(report) do
        nil ->
          "[No decryption key available]"

        key ->
          case decr_public_item(report.details, key) do
            decrypted when is_binary(decrypted) -> decrypted
            _ -> "[Decryption failed]"
          end
      end
    else
      "[Encrypted]"
    end
  end

  defp get_report_key(report) do
    # Defensive check for loaded association
    case report.user_post_report do
      %Ecto.Association.NotLoaded{} -> nil
      nil -> nil
      user_post_report -> user_post_report.key
    end
  end

  # Collapsible reporter statistics display with liquid metal styling
  attr :stats, :map, required: true
  attr :reporter_id, :string, required: true

  defp liquid_collapsible_reporter_stats(assigns) do
    ~H"""
    <div class="mt-4 rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden">
      <div class="bg-slate-50 dark:bg-slate-700/50 px-4 py-3">
        <div class="flex items-center justify-between">
          <h4 class="text-sm font-medium text-slate-900 dark:text-slate-100">
            Reporter Analysis
          </h4>
          <div class={[
            "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
            if(@stats.suspicious?,
              do: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400",
              else: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
            )
          ]}>
            {if @stats.suspicious?, do: "⚠️ FLAGGED", else: "✅ LEGITIMATE"}
          </div>
        </div>
      </div>

      <div class="bg-white dark:bg-slate-800 px-4 py-3 space-y-2">
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span class="font-medium text-slate-600 dark:text-slate-400">Total Reports:</span>
            <span class="ml-2 text-slate-900 dark:text-slate-100">{@stats.total_reports}</span>
          </div>
          <div>
            <span class="font-medium text-slate-600 dark:text-slate-400">This Week:</span>
            <span class="ml-2 text-slate-900 dark:text-slate-100">{@stats.recent_reports}</span>
          </div>
          <div>
            <span class="font-medium text-slate-600 dark:text-slate-400">Dismissal Rate:</span>
            <span class={[
              "ml-2 font-medium",
              if(@stats.dismissal_rate > 50,
                do: "text-red-600 dark:text-red-400",
                else: "text-slate-900 dark:text-slate-100"
              )
            ]}>
              {@stats.dismissal_rate}%
            </span>
          </div>
          <div>
            <span class="font-medium text-slate-600 dark:text-slate-400">Pattern:</span>
            <span class="ml-2 text-slate-900 dark:text-slate-100">
              {if @stats.suspicious?, do: "High false reports", else: "Normal activity"}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Collapsible reported user statistics display with liquid metal styling
  attr :stats, :map, required: true
  attr :reported_user_id, :string, required: true

  defp liquid_collapsible_reported_user_stats(assigns) do
    ~H"""
    <div class="mt-4 rounded-lg border border-orange-200 dark:border-orange-700 overflow-hidden">
      <div class="bg-orange-50 dark:bg-orange-900/20 px-4 py-3">
        <div class="flex items-center justify-between">
          <h4 class="text-sm font-medium text-slate-900 dark:text-slate-100">
            Reported User Analysis
          </h4>
          <div class={[
            "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
            if(@stats.high_risk?,
              do: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400",
              else: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400"
            )
          ]}>
            {if @stats.high_risk?, do: "⚠️ HIGH RISK", else: "✅ LOW RISK"}
          </div>
        </div>
      </div>

      <div class="bg-white dark:bg-slate-800 px-4 py-3 space-y-2">
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span class="font-medium text-slate-600 dark:text-slate-400">
              Total Reports Received:
            </span>
            <span class="ml-2 text-slate-900 dark:text-slate-100">
              {@stats.total_reports_received}
            </span>
          </div>
          <div>
            <span class="font-medium text-slate-600 dark:text-slate-400">This Week:</span>
            <span class="ml-2 text-slate-900 dark:text-slate-100">
              {@stats.recent_reports_received}
            </span>
          </div>
          <div>
            <span class="font-medium text-slate-600 dark:text-slate-400">Violation Rate:</span>
            <span class={[
              "ml-2 font-medium",
              if(@stats.violation_rate > 30,
                do: "text-red-600 dark:text-red-400",
                else: "text-slate-900 dark:text-slate-100"
              )
            ]}>
              {@stats.violation_rate}%
            </span>
          </div>
          <div>
            <span class="font-medium text-slate-600 dark:text-slate-400">Status:</span>
            <span class="ml-2 text-slate-900 dark:text-slate-100">
              {if @stats.high_risk?, do: "Frequent violations", else: "Good standing"}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
