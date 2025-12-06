defmodule MossletWeb.AdminBotDefenseLive do
  @moduledoc """
  Admin LiveView for managing bot defense and IP bans.
  """
  use MossletWeb, :live_view

  alias Mosslet.Security.BotDefense

  @impl true
  def render(assigns) do
    ~H"""
    <.layout current_page={:admin_bot_defense} current_user={@current_user} key={@key} type="sidebar">
      <div class="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
        <div class="md:flex md:items-center md:justify-between">
          <div class="min-w-0 flex-1 flex items-center gap-3">
            <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-br from-rose-500 to-pink-600 shadow-lg shadow-rose-500/20">
              <.phx_icon name="hero-bug-ant" class="h-6 w-6 text-white" />
            </div>
            <div>
              <h1 class="text-2xl font-bold tracking-tight text-gray-900 dark:text-gray-50">
                Bot Defense
              </h1>
              <p class="text-sm text-gray-500 dark:text-gray-400">
                Monitor and manage IP bans to protect against malicious traffic.
              </p>
            </div>
          </div>
        </div>

        <div class="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <.stat_card title="Total Bans" value={@stats.total_bans} />
          <.stat_card title="Blocked Requests" value={@stats.total_blocked_requests} />
          <.stat_card title="Manual Bans" value={Map.get(@stats.by_source, :manual, 0)} />
          <.stat_card title="Auto Bans" value={auto_bans(@stats.by_source)} />
        </div>

        <div class="mt-8 rounded-xl bg-white dark:bg-gray-800 p-6 shadow-sm ring-1 ring-gray-900/5 dark:ring-gray-700">
          <div class="mb-5">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-50">
              Ban an IP Address
            </h2>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
              Manually block an IP from accessing the application.
            </p>
          </div>
          <.form for={@ban_form} phx-submit="ban_ip" id="ban-ip-form">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <div>
                <.phx_input
                  field={@ban_form[:ip]}
                  type="text"
                  label="IP Address"
                  placeholder="192.168.1.1"
                  class="block w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2.5 text-gray-900 dark:text-gray-100 placeholder-gray-400 focus:border-indigo-500 focus:ring-indigo-500"
                />
              </div>
              <div>
                <.phx_input
                  field={@ban_form[:reason]}
                  type="text"
                  label="Reason"
                  placeholder="Optional reason"
                  class="block w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2.5 text-gray-900 dark:text-gray-100 placeholder-gray-400 focus:border-indigo-500 focus:ring-indigo-500"
                />
              </div>
              <div>
                <.phx_input
                  field={@ban_form[:duration]}
                  type="select"
                  label="Duration"
                  options={duration_options()}
                  class="block w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2.5 text-gray-900 dark:text-gray-100 focus:border-indigo-500 focus:ring-indigo-500"
                />
              </div>
              <div class="flex items-end">
                <button
                  type="submit"
                  class="w-full inline-flex items-center justify-center rounded-lg bg-red-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-red-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600 transition-colors"
                >
                  <.phx_icon name="hero-shield-exclamation" class="w-4 h-4 mr-2" /> Ban IP
                </button>
              </div>
            </div>
          </.form>
        </div>

        <div class="mt-8 rounded-xl bg-white dark:bg-gray-800 shadow-sm ring-1 ring-gray-900/5 dark:ring-gray-700 overflow-hidden">
          <div class="border-b border-gray-200 dark:border-gray-700 px-6 py-5">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-50">
                  Active Bans
                </h2>
                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  Currently blocked IP addresses and their details.
                </p>
              </div>
              <div class="sm:min-w-[200px]">
                <.form for={@filter_form} phx-change="filter" id="filter-form">
                  <.phx_input
                    field={@filter_form[:source]}
                    type="select"
                    label="Filter by Source"
                    options={source_filter_options()}
                    class="block w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2.5 text-sm text-gray-900 dark:text-gray-100 focus:border-indigo-500 focus:ring-indigo-500"
                  />
                </.form>
              </div>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-800">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    IP Hash
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Source
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Reason
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Blocked
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Expires
                  </th>
                  <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
                    Created
                  </th>
                  <th class="relative px-4 py-3">
                    <span class="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody
                id="bans-list"
                phx-update="stream"
                class="divide-y divide-gray-200 dark:divide-gray-700 bg-white dark:bg-gray-900"
              >
                <tr
                  :for={{dom_id, ban} <- @streams.bans}
                  id={dom_id}
                  class="hover:bg-gray-50 dark:hover:bg-gray-800"
                >
                  <td class="whitespace-nowrap px-4 py-3 text-sm font-mono text-gray-500 dark:text-gray-400">
                    {truncate_hash(ban.ip_hash)}
                  </td>
                  <td class="whitespace-nowrap px-4 py-3">
                    <.source_badge source={ban.source} />
                  </td>
                  <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100 max-w-xs truncate">
                    {ban.reason || "-"}
                  </td>
                  <td class="whitespace-nowrap px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
                    {ban.request_count}
                  </td>
                  <td class="whitespace-nowrap px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
                    {format_expires(ban.expires_at)}
                  </td>
                  <td class="whitespace-nowrap px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
                    {format_datetime(ban.inserted_at)}
                  </td>
                  <td class="whitespace-nowrap px-4 py-3 text-right text-sm">
                    <button
                      phx-click="unban"
                      phx-value-id={ban.id}
                      data-confirm="Are you sure you want to unban this IP?"
                      class="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-300"
                    >
                      Unban
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
            <div
              :if={@bans_empty?}
              class="px-6 py-12 text-center"
            >
              <.phx_icon
                name="hero-shield-check"
                class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500"
              />
              <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-gray-100">
                No bans found
              </h3>
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                No IP addresses are currently banned.
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

  defp stat_card(assigns) do
    ~H"""
    <dl class="overflow-hidden rounded-lg bg-white dark:bg-gray-800 px-4 py-5 shadow sm:p-6">
      <dt class="truncate text-sm font-medium text-gray-500 dark:text-gray-400">
        {@title}
      </dt>
      <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900 dark:text-gray-50">
        {@value}
      </dd>
    </dl>
    """
  end

  attr :source, :atom, required: true

  defp source_badge(assigns) do
    colors = %{
      manual: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200",
      rate_limit: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200",
      honeypot: "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200",
      cloud_ip: "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200",
      suspicious: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
    }

    assigns = assign(assigns, :colors, Map.get(colors, assigns.source, colors.manual))

    ~H"""
    <span class={["inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium", @colors]}>
      {@source}
    </span>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      BotDefense.subscribe()
    end

    stats = BotDefense.get_stats()
    bans = BotDefense.list_bans()

    socket =
      socket
      |> assign(:page_title, "Bot Defense")
      |> assign(:stats, stats)
      |> assign(:bans_empty?, bans == [])
      |> assign(:ban_form, to_form(%{"ip" => "", "reason" => "", "duration" => "1_hour"}))
      |> assign(:filter_form, to_form(%{"source" => ""}))
      |> assign(:current_filter, nil)
      |> stream(:bans, bans)

    {:ok, socket}
  end

  @impl true
  def handle_event("ban_ip", %{"ip" => ip, "reason" => reason, "duration" => duration}, socket) do
    case parse_ip(ip) do
      {:ok, ip_tuple} ->
        expires_at = parse_duration(duration)

        opts = [
          reason: if(reason != "", do: reason, else: nil),
          source: :manual,
          expires_at: expires_at,
          banned_by_id: socket.assigns.current_user.id
        ]

        case BotDefense.ban_ip(ip_tuple, opts) do
          {:ok, _ban} ->
            socket =
              socket
              |> put_flash(:info, "IP #{ip} has been banned.")
              |> assign(:ban_form, to_form(%{"ip" => "", "reason" => "", "duration" => "1_hour"}))

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to ban IP.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid IP address format.")}
    end
  end

  def handle_event("unban", %{"id" => id}, socket) do
    ban = Mosslet.Repo.get(Mosslet.Security.IpBan, id)

    if ban do
      case Mosslet.Repo.transaction_on_primary(fn ->
             Mosslet.Repo.delete(ban)
           end) do
        {:ok, {:ok, _}} ->
          :ets.delete(:bot_defense_bans, ban.ip_hash)

          socket =
            socket
            |> stream_delete(:bans, ban)
            |> assign(:stats, BotDefense.get_stats())
            |> put_flash(:info, "IP unbanned successfully.")

          {:noreply, socket}

        _ ->
          {:noreply, put_flash(socket, :error, "Failed to unban IP.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Ban not found.")}
    end
  end

  def handle_event("filter", %{"source" => source}, socket) do
    source_atom = if source == "", do: nil, else: String.to_existing_atom(source)
    bans = BotDefense.list_bans(source: source_atom)

    socket =
      socket
      |> assign(:current_filter, source_atom)
      |> assign(:bans_empty?, bans == [])
      |> stream(:bans, bans, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ip_banned, ban}, socket) do
    socket =
      socket
      |> stream_insert(:bans, ban, at: 0)
      |> assign(:stats, BotDefense.get_stats())
      |> assign(:bans_empty?, false)

    {:noreply, socket}
  end

  def handle_info({:ip_unbanned, _ip}, socket) do
    {:noreply, assign(socket, :stats, BotDefense.get_stats())}
  end

  defp parse_ip(ip_string) do
    case :inet.parse_address(String.to_charlist(ip_string)) do
      {:ok, ip_tuple} -> {:ok, ip_tuple}
      {:error, _} -> {:error, :invalid}
    end
  end

  defp parse_duration("permanent"), do: nil

  defp parse_duration(duration) do
    minutes =
      case duration do
        "1_hour" -> 60
        "6_hours" -> 360
        "1_day" -> 1440
        "1_week" -> 10080
        "1_month" -> 43200
        _ -> 60
      end

    DateTime.add(DateTime.utc_now(), minutes, :minute)
  end

  defp duration_options do
    [
      {"1 Hour", "1_hour"},
      {"6 Hours", "6_hours"},
      {"1 Day", "1_day"},
      {"1 Week", "1_week"},
      {"1 Month", "1_month"},
      {"Permanent", "permanent"}
    ]
  end

  defp source_filter_options do
    [
      {"All Sources", ""},
      {"Manual", "manual"},
      {"Rate Limit", "rate_limit"},
      {"Honeypot", "honeypot"},
      {"Cloud IP", "cloud_ip"},
      {"Suspicious", "suspicious"}
    ]
  end

  defp auto_bans(by_source) do
    Map.get(by_source, :rate_limit, 0) +
      Map.get(by_source, :honeypot, 0) +
      Map.get(by_source, :cloud_ip, 0) +
      Map.get(by_source, :suspicious, 0)
  end

  defp truncate_hash(hash) when is_binary(hash) do
    hash
    |> Base.encode16(case: :lower)
    |> String.slice(0, 12)
    |> Kernel.<>("...")
  end

  defp truncate_hash(_), do: "-"

  defp format_expires(nil), do: "Never"

  defp format_expires(datetime) do
    if DateTime.compare(datetime, DateTime.utc_now()) == :gt do
      DateTime.to_string(datetime) |> String.slice(0, 16)
    else
      "Expired"
    end
  end

  defp format_datetime(datetime) do
    datetime
    |> NaiveDateTime.to_string()
    |> String.slice(0, 16)
  end
end
