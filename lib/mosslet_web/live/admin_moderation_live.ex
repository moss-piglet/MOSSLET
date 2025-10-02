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
      <div class="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800">
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <%!-- Header with calming design and better visual hierarchy --%>
          <div class="mb-8 md:flex md:items-center md:justify-between">
            <div class="min-w-0 flex-1">
              <div class="flex items-center space-x-3 mb-2">
                <div class="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/30 dark:to-teal-900/30">
                  <.phx_icon name="hero-shield-check" class="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
                </div>
                <h1 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
                  Content Moderation
                </h1>
              </div>
              <p class="text-sm text-slate-600 dark:text-slate-400 ml-13">
                Review and manage community reports with care and attention
              </p>
            </div>

            <div class="mt-6 flex flex-col space-y-3 sm:mt-4 sm:flex-row sm:space-y-0 sm:space-x-3 md:mt-0">
              <.liquid_button
                variant="secondary"
                color="emerald"
                phx-click="refresh_reports"
                icon="hero-arrow-path"
                size="sm"
                shimmer="page"
              >
                Refresh Reports
              </.liquid_button>

              <.liquid_button
                navigate={~p"/admin/dash"}
                variant="primary"
                color="indigo"
                icon="hero-chart-bar"
                size="sm"
                shimmer="page"
              >
                Dashboard
              </.liquid_button>
            </div>
          </div>

          <%!-- Enhanced Filter Bar with better mobile layout --%>
          <div class="mb-8 rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg overflow-hidden">
            <div class="px-5 py-4 border-b border-slate-200/60 dark:border-slate-700/60 bg-slate-50/50 dark:bg-slate-700/25">
              <h3 class="text-sm font-medium text-slate-900 dark:text-slate-100 flex items-center">
                <.phx_icon name="hero-funnel" class="h-4 w-4 mr-2 text-slate-500" />
                Filter Reports
              </h3>
            </div>
            <.form phx-change="filter_changed" class="p-5">
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div class="space-y-2">
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">Status</label>
                  <.liquid_filter_select
                    name="status"
                    value={@filter_status}
                    options={[
                      {"", "All Statuses"},
                      {"pending", "Pending Review"},
                      {"reviewed", "Under Review"},
                      {"resolved", "Resolved"},
                      {"dismissed", "Dismissed"}
                    ]}
                  />
                </div>

                <div class="space-y-2">
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">Severity</label>
                  <.liquid_filter_select
                    name="severity"
                    value={@filter_severity}
                    options={[
                      {"", "All Levels"},
                      {"critical", "Critical"},
                      {"high", "High"},
                      {"medium", "Medium"},
                      {"low", "Low"}
                    ]}
                  />
                </div>

                <div class="space-y-2">
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">Type</label>
                  <.liquid_filter_select
                    name="report_type"
                    value={@filter_type}
                    options={[
                      {"", "All Types"},
                      {"content", "Content Issue"},
                      {"harassment", "Harassment"},
                      {"spam", "Spam"},
                      {"other", "Other"}
                    ]}
                  />
                </div>
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
        "delete_reported_reply",
        %{"reply_id" => reply_id, "report_id" => report_id},
        socket
      ) do
    with reply when not is_nil(reply) <- Timeline.get_reply!(reply_id),
         {:ok, _deleted_reply} <- Timeline.delete_reply(reply, user: socket.assigns.current_user),
         report when not is_nil(report) <- Timeline.get_post_report(report_id),
         {:ok, updated_report} <-
           Timeline.update_post_report(
             report,
             %{"status" => "resolved"},
             socket.assigns.current_user
           ) do
      socket =
        socket
        |> put_flash(:info, "Reply deleted and report resolved")
        |> stream_insert(:reports, updated_report)

      {:noreply, socket}
    else
      _error ->
        socket = put_flash(socket, :error, "Failed to delete reply")
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
    <div class="p-6 lg:p-8 space-y-6">
      <%!-- Report Header with calmer spacing and colors --%>
      <div class="flex flex-col space-y-4 sm:flex-row sm:items-start sm:justify-between sm:space-y-0">
        <div class="flex flex-wrap items-center gap-2">
          <%!-- Severity Badge with softer colors --%>
          <div class={[
            "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset",
            soft_severity_color_class(@report.severity)
          ]}>
            <.phx_icon name={severity_icon(@report.severity)} class="h-3 w-3 mr-1.5" />
            {@report.severity |> to_string() |> String.capitalize()}
          </div>

          <%!-- Status Badge with softer colors --%>
          <div class={[
            "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset",
            soft_status_color_class(@report.status)
          ]}>
            <.phx_icon name={status_icon(@report.status)} class="h-3 w-3 mr-1.5" />
            {@report.status |> to_string() |> String.capitalize()}
          </div>

          <%!-- Content Type Badge --%>
          <div class={[
            "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset",
            if(@report.reply_id, do: "bg-purple-50 text-purple-700 ring-purple-200 dark:bg-purple-900/20 dark:text-purple-300 dark:ring-purple-800/30", else: "bg-blue-50 text-blue-700 ring-blue-200 dark:bg-blue-900/20 dark:text-blue-300 dark:ring-blue-800/30")
          ]}>
            <.phx_icon name={content_type_icon(@report)} class="h-3 w-3 mr-1.5" />
            {if @report.reply_id, do: "Reply Report", else: "Post Report"}
          </div>
        </div>

        <div class="text-sm text-slate-500 dark:text-slate-400 flex items-center">
          <.phx_icon name="hero-clock" class="h-4 w-4 mr-1.5" />
          {Calendar.strftime(@report.inserted_at, "%b %d, %Y at %I:%M %p")}
        </div>
      </div>

      <%!-- Report Content with better typography and spacing --%>
      <div class="space-y-4">
        <%!-- Enhanced ID Information with better mobile/desktop layout --%>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 text-sm">
          <%!-- Reporter Information --%>
          <div class="rounded-lg bg-blue-50 dark:bg-blue-900/10 p-3 border border-blue-200 dark:border-blue-800">
            <div class="flex items-center mb-1">
              <.phx_icon name="hero-user" class="h-4 w-4 mr-2 text-blue-500" />
              <span class="font-semibold text-blue-900 dark:text-blue-100">Reporter</span>
            </div>
            <span class="font-mono text-xs bg-white dark:bg-slate-800 px-2 py-1 rounded border">
              {@report.reporter.id |> String.slice(0..7)}...
            </span>
          </div>

          <%!-- Reported User Information --%>
          <div class="rounded-lg bg-rose-50 dark:bg-rose-900/10 p-3 border border-rose-200 dark:border-rose-800">
            <div class="flex items-center mb-1">
              <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 mr-2 text-rose-500" />
              <span class="font-semibold text-rose-900 dark:text-rose-100">Reported User</span>
            </div>
            <span class="font-mono text-xs bg-white dark:bg-slate-800 px-2 py-1 rounded border">
              {@report.reported_user.id |> String.slice(0..7)}...
            </span>
          </div>

          <%!-- Content Information (Post or Reply) --%>
          <%= if @report.reply_id do %>
            <div class="rounded-lg bg-purple-50 dark:bg-purple-900/10 p-3 border border-purple-200 dark:border-purple-800">
              <div class="flex items-center mb-1">
                <.phx_icon name="hero-chat-bubble-left" class="h-4 w-4 mr-2 text-purple-500" />
                <span class="font-semibold text-purple-900 dark:text-purple-100">Reply Report</span>
              </div>
              <div class="space-y-1">
                <div class="text-xs text-purple-700 dark:text-purple-300">Reply:</div>
                <span class="font-mono text-xs bg-white dark:bg-slate-800 px-2 py-1 rounded border">
                  {@report.reply_id |> String.slice(0..7)}...
                </span>
                <div class="text-xs text-purple-700 dark:text-purple-300 mt-1">In Post:</div>
                <span class="font-mono text-xs bg-white dark:bg-slate-800 px-2 py-1 rounded border">
                  {@report.post.id |> String.slice(0..7)}...
                </span>
              </div>
            </div>
          <% else %>
            <div class="rounded-lg bg-emerald-50 dark:bg-emerald-900/10 p-3 border border-emerald-200 dark:border-emerald-800">
              <div class="flex items-center mb-1">
                <.phx_icon name="hero-document-text" class="h-4 w-4 mr-2 text-emerald-500" />
                <span class="font-semibold text-emerald-900 dark:text-emerald-100">Post Report</span>
              </div>
              <span class="font-mono text-xs bg-white dark:bg-slate-800 px-2 py-1 rounded border">
                {@report.post.id |> String.slice(0..7)}...
              </span>
            </div>
          <% end %>
        </div>

        <%!-- Report Reason with better contrast --%>
        <div class="rounded-lg bg-slate-50 dark:bg-slate-800/50 p-4 border border-slate-200 dark:border-slate-700">
          <div class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-2">Report Reason</div>
          <div class="text-sm text-slate-700 dark:text-slate-300 leading-relaxed">
            {decrypt_report_reason(@report, @current_user)}
          </div>
        </div>

        <%!-- Additional Details if present --%>
        <%= if @report.details do %>
          <div class="rounded-lg bg-amber-50 dark:bg-amber-900/10 p-4 border border-amber-200 dark:border-amber-800">
            <div class="text-sm font-semibold text-amber-900 dark:text-amber-100 mb-2 flex items-center">
              <.phx_icon name="hero-document-text" class="h-4 w-4 mr-2" />
              Additional Details
            </div>
            <div class="text-sm text-amber-800 dark:text-amber-200 leading-relaxed">
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
            <%= if @report.reply_id do %>
              <.liquid_button
                size="sm"
                color="amber"
                variant="ghost"
                phx-click="delete_reported_reply"
                phx-value-reply_id={@report.reply_id}
                phx-value-report_id={@report.id}
                data-confirm="Are you sure you want to delete this reply? This action cannot be undone."
                icon="hero-trash"
              >
                Delete Reply
              </.liquid_button>
            <% else %>
              <.liquid_button
                size="sm"
                color="amber"
                variant="ghost"
                phx-click="delete_reported_post"
                phx-value-post_id={@report.post.id}
                phx-value-report_id={@report.id}
                data-confirm="Are you sure you want to delete this post? This action cannot be undone."
                icon="hero-trash"
              >
                Delete Post
              </.liquid_button>
            <% end %>

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

  # Enhanced helper functions for calmer, more accessible styling

  # Softer severity colors that are easier on the eyes
  defp soft_severity_color_class(:critical),
    do:
      "bg-red-50 text-red-700 ring-red-200 dark:bg-red-900/20 dark:text-red-300 dark:ring-red-800/30"

  defp soft_severity_color_class(:high),
    do:
      "bg-orange-50 text-orange-700 ring-orange-200 dark:bg-orange-900/20 dark:text-orange-300 dark:ring-orange-800/30"

  defp soft_severity_color_class(:medium),
    do:
      "bg-yellow-50 text-yellow-700 ring-yellow-200 dark:bg-yellow-900/20 dark:text-yellow-300 dark:ring-yellow-800/30"

  defp soft_severity_color_class(:low),
    do:
      "bg-emerald-50 text-emerald-700 ring-emerald-200 dark:bg-emerald-900/20 dark:text-emerald-300 dark:ring-emerald-800/30"

  # Softer status colors
  defp soft_status_color_class(:pending),
    do:
      "bg-amber-50 text-amber-700 ring-amber-200 dark:bg-amber-900/20 dark:text-amber-300 dark:ring-amber-800/30"

  defp soft_status_color_class(:reviewed),
    do:
      "bg-blue-50 text-blue-700 ring-blue-200 dark:bg-blue-900/20 dark:text-blue-300 dark:ring-blue-800/30"

  defp soft_status_color_class(:resolved),
    do:
      "bg-emerald-50 text-emerald-700 ring-emerald-200 dark:bg-emerald-900/20 dark:text-emerald-300 dark:ring-emerald-800/30"

  defp soft_status_color_class(:dismissed),
    do:
      "bg-slate-50 text-slate-700 ring-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:ring-slate-700"

  # Icon helpers for better visual hierarchy
  defp severity_icon(:critical), do: "hero-exclamation-triangle"
  defp severity_icon(:high), do: "hero-exclamation-circle"
  defp severity_icon(:medium), do: "hero-information-circle"
  defp severity_icon(:low), do: "hero-check-circle"

  defp status_icon(:pending), do: "hero-clock"
  defp status_icon(:reviewed), do: "hero-eye"
  defp status_icon(:resolved), do: "hero-check-circle"
  defp status_icon(:dismissed), do: "hero-x-circle"

  defp type_icon(:content), do: "hero-document-text"
  defp type_icon(:harassment), do: "hero-exclamation-triangle"
  defp type_icon(:spam), do: "hero-no-symbol"
  defp type_icon(:other), do: "hero-ellipsis-horizontal-circle"

  # Helper for content type (post vs reply) icon
  defp content_type_icon(report) do
    if report.reply_id, do: "hero-chat-bubble-left", else: "hero-document-text"
  end

  # Keep original color functions for backwards compatibility
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
