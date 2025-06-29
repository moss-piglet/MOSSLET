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
    <.layout current_page={:admin_dashboard} current_user={@current_user} key={@key} type="sidebar">
      <.container>
        <div class="pt-6 md:flex md:items-center md:justify-between">
          <div class="min-w-0 flex-1">
            <h2 class="text-2xl/7 font-bold text-gray-900 dark:text-gray-50 sm:truncate sm:text-3xl sm:tracking-tight">
              Admin Dashboard
            </h2>
          </div>
          <div class="mt-4 flex md:mt-0 md:ml-4">
            <%!--
            <button
              type="button"
              class="inline-flex items-center rounded-md bg-background-50 px-3 py-2 text-sm font-semibold text-gray-900 shadow-xs ring-1 ring-gray-300 ring-inset hover:bg-gray-50"
            >
              Edit
            </button>
            <button
              type="button"
              class="ml-3 inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-xs hover:bg-indigo-700 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            >
              Publish
            </button>
            --%>
          </div>
        </div>

        <div class="pt-6">
          <h3 class="text-base font-semibold leading-6 text-gray-900 dark:text-gray-50">Stats</h3>
          <dl class="mt-5 grid grid-cols-1 gap-5 sm:grid-cols-3">
            <div class="overflow-hidden rounded-lg bg-white dark:bg-gray-800 px-4 py-5 shadow sm:p-6">
              <dt class="truncate text-sm font-medium text-gray-500 dark:text-gray-400">
                Total Accounts
              </dt>
              <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900 dark:text-gray-50">
                {@user_count}
              </dd>
            </div>
            <div class="overflow-hidden rounded-lg bg-white dark:bg-gray-800 px-4 py-5 shadow sm:p-6">
              <dt class="truncate text-sm font-medium text-gray-500 dark:text-gray-400">
                Total Confirmed
              </dt>
              <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900 dark:text-gray-50">
                {@confirmed_user_count}
              </dd>
            </div>
            <div class="overflow-hidden rounded-lg bg-white dark:bg-gray-800 px-4 py-5 shadow sm:p-6">
              <dt class="truncate text-sm font-medium text-gray-500 dark:text-gray-400">
                Total Paid Members
              </dt>
              <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900 dark:text-gray-50">
                {@paid_count}
              </dd>
            </div>
            <div class="overflow-hidden rounded-lg bg-white dark:bg-gray-800 px-4 py-5 shadow sm:p-6">
              <dt class="truncate text-sm font-medium text-gray-500 dark:text-gray-400">
                Total Memories
              </dt>
              <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900 dark:text-gray-50">
                {@memory_count}
              </dd>
            </div>
            <div class="overflow-hidden rounded-lg bg-white dark:bg-gray-800 px-4 py-5 shadow sm:p-6">
              <dt class="truncate text-sm font-medium text-gray-500 dark:text-gray-400">
                Total Posts
              </dt>
              <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900 dark:text-gray-50">
                {@post_count}
              </dd>
            </div>
          </dl>
        </div>
      </.container>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Accounts.admin_subscribe(socket.assigns.current_user)
      Memories.admin_subscribe(socket.assigns.current_user)
      Timeline.admin_subscribe(socket.assigns.current_user)
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
