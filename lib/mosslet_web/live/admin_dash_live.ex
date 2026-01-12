defmodule MossletWeb.AdminDashLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Memories
  alias Mosslet.Timeline

  alias Mosslet.Repo

  def render(assigns) do
    ~H"""
    <.layout
      current_page={:admin_dashboard}
      sidebar_current_page={:admin_dashboard}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50 via-slate-50 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800">
        <div class="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8">
          <header class="mb-6">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div class="flex items-center gap-3">
                <div class="flex h-11 w-11 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 shadow-lg shadow-indigo-500/20">
                  <.phx_icon name="hero-chart-bar" class="h-6 w-6 text-white" />
                </div>
                <div>
                  <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
                    Admin Dashboard
                  </h1>
                  <p class="text-sm text-slate-500 dark:text-slate-400">
                    System overview and statistics
                  </p>
                </div>
              </div>

              <div class="flex flex-wrap items-center gap-2">
                <.link
                  navigate={~p"/admin/moderation"}
                  class="inline-flex h-9 items-center justify-center gap-2 rounded-lg bg-white/80 dark:bg-slate-800/80 px-3 text-sm font-medium text-slate-700 dark:text-slate-300 shadow-sm border border-slate-200/60 dark:border-slate-700/60 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
                >
                  <.phx_icon name="hero-shield-check" class="h-4 w-4 shrink-0" /> Moderation
                </.link>
                <.link
                  navigate={~p"/admin/key-rotation"}
                  class="inline-flex h-9 items-center justify-center gap-2 rounded-lg bg-white/80 dark:bg-slate-800/80 px-3 text-sm font-medium text-slate-700 dark:text-slate-300 shadow-sm border border-slate-200/60 dark:border-slate-700/60 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
                >
                  <.phx_icon name="hero-key" class="h-4 w-4 shrink-0" /> Key Rotation
                </.link>
                <.link
                  navigate={~p"/admin/bot-defense"}
                  class="inline-flex h-9 items-center justify-center gap-2 rounded-lg bg-white/80 dark:bg-slate-800/80 px-3 text-sm font-medium text-slate-700 dark:text-slate-300 shadow-sm border border-slate-200/60 dark:border-slate-700/60 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
                >
                  <.phx_icon name="hero-shield-exclamation" class="h-4 w-4 shrink-0" /> Bot Defense
                </.link>
                <.link
                  navigate={~p"/admin/backups"}
                  class="inline-flex h-9 items-center justify-center gap-2 rounded-lg bg-white/80 dark:bg-slate-800/80 px-3 text-sm font-medium text-slate-700 dark:text-slate-300 shadow-sm border border-slate-200/60 dark:border-slate-700/60 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
                >
                  <.phx_icon name="hero-server-stack" class="h-4 w-4 shrink-0" /> Backups
                </.link>
              </div>
            </div>
          </header>

          <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3 xl:grid-cols-5">
            <.stat_card
              title="Total Accounts"
              value={@user_count}
              icon="hero-users"
              color="blue"
            />
            <.stat_card
              title="Confirmed"
              value={@confirmed_user_count}
              icon="hero-check-badge"
              color="emerald"
            />
            <.stat_card
              title="Paid Members"
              value={@paid_count}
              icon="hero-currency-dollar"
              color="amber"
            />
            <.stat_card
              title="Memories"
              value={@memory_count}
              icon="hero-photo"
              color="purple"
            />
            <.stat_card
              title="Posts"
              value={@post_count}
              icon="hero-document-text"
              color="rose"
            />
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  attr :title, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "slate"

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
  defp stat_icon_bg("amber"), do: "bg-amber-100 dark:bg-amber-900/50"
  defp stat_icon_bg("purple"), do: "bg-purple-100 dark:bg-purple-900/50"
  defp stat_icon_bg("rose"), do: "bg-rose-100 dark:bg-rose-900/50"
  defp stat_icon_bg(_), do: "bg-slate-100 dark:bg-slate-700/50"

  defp stat_icon_color("blue"), do: "text-blue-600 dark:text-blue-400"
  defp stat_icon_color("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp stat_icon_color("amber"), do: "text-amber-600 dark:text-amber-400"
  defp stat_icon_color("purple"), do: "text-purple-600 dark:text-purple-400"
  defp stat_icon_color("rose"), do: "text-rose-600 dark:text-rose-400"
  defp stat_icon_color(_), do: "text-slate-600 dark:text-slate-400"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Accounts.admin_subscribe(socket.assigns.current_scope.user)
      Memories.admin_subscribe(socket.assigns.current_scope.user)
      Timeline.admin_subscribe(socket.assigns.current_scope.user)
    end

    socket =
      socket
      |> assign(:user_count, Accounts.count_all_users())
      |> assign(:confirmed_user_count, Accounts.count_all_confirmed_users())
      |> assign(:memory_count, Memories.count_all_memories())
      |> assign(:post_count, Timeline.count_all_posts())
      |> assign(:paid_count, get_active_payment_intents())

    {:ok, socket |> assign(:page_title, "Admin Dashboard")}
  end

  def handle_info({:account_registered, _user}, socket) do
    {:noreply, assign(socket, :user_count, socket.assigns.user_count + 1)}
  end

  def handle_info({:account_confirmed, _user}, socket) do
    {:noreply, assign(socket, :confirmed_user_count, socket.assigns.confirmed_user_count + 1)}
  end

  def handle_info({:account_deleted, _user}, socket) do
    {:noreply,
     socket
     |> assign(:user_count, socket.assigns.user_count - 1)
     |> assign(:confirmed_user_count, socket.assigns.confirmed_user_count - 1)}
  end

  def handle_info({:memory_created, _memory}, socket) do
    {:noreply, assign(socket, :memory_count, socket.assigns.memory_count + 1)}
  end

  def handle_info({:memory_deleted, _memory}, socket) do
    {:noreply, assign(socket, :memory_count, socket.assigns.memory_count - 1)}
  end

  def handle_info({:post_created, _post}, socket) do
    {:noreply, assign(socket, :post_count, socket.assigns.post_count + 1)}
  end

  def handle_info({:post_deleted, _post}, socket) do
    {:noreply, assign(socket, :post_count, socket.assigns.post_count - 1)}
  end

  defp get_active_payment_intents() do
    users = Repo.all(User) |> Repo.preload(customer: :payment_intents)

    Enum.filter(users, fn user ->
      user.customer && user.customer.payment_intents &&
        Enum.any?(user.customer.payment_intents, fn intent ->
          intent.status == "succeeded"
        end)
    end)
    |> Enum.count()
  end
end
