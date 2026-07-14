defmodule MossletWeb.CapsuleLive.Index do
  @moduledoc """
  The time-capsule mailbox.

  Shows letters that have arrived (delivered — openable) and letters still
  sealed in the capsule (showing only the delivery date the server can see).
  Delivered letter titles are decrypted in the browser via `DecryptCapsule`;
  sealed letters stay mysterious until their day.
  """
  use MossletWeb, :live_view

  alias Mosslet.Capsules
  alias MossletWeb.Helpers.JournalHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="sidebar"
      current_scope={@current_scope}
      current_page={:capsules}
      sidebar_current_page={:capsules}
    >
      <div class="max-w-4xl mx-auto px-3 sm:px-6 pt-4 sm:pt-8 pb-24 sm:pb-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div>
            <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
              Time Capsule
            </h1>
            <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
              Letters to your future self — sealed until the day you choose
            </p>
          </div>

          <.link
            navigate={~p"/app/capsules/new"}
            class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
          >
            <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> Write a letter
          </.link>
        </div>

        <%!-- Empty state --%>
        <div
          :if={@delivered == [] and @sealed == []}
          class="text-center py-16 rounded-2xl border border-dashed border-slate-300 dark:border-slate-700"
        >
          <div class="inline-flex items-center justify-center h-16 w-16 rounded-2xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/40 dark:to-emerald-900/30 mb-4">
            <.phx_icon name="hero-envelope" class="h-8 w-8 text-emerald-600 dark:text-emerald-400" />
          </div>
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            Your capsule is empty
          </h2>
          <p class="mt-2 max-w-sm mx-auto text-sm text-slate-600 dark:text-slate-400">
            Write a letter to the person you'll be in a year — or ten. Seal it, and forget about it
            until it finds you again.
          </p>
          <.link
            navigate={~p"/app/capsules/new"}
            class="mt-6 inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
          >
            <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> Write your first letter
          </.link>
        </div>

        <%!-- Delivered letters (openable) --%>
        <section :if={@delivered != []} class="mb-10">
          <h2 class="flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400 mb-4">
            <.phx_icon name="hero-inbox-arrow-down" class="h-4 w-4" /> Arrived
            <span
              :if={@opening_today_count > 0}
              class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 normal-case tracking-normal font-medium"
            >
              {@opening_today_count} opening today
            </span>
          </h2>

          <div class="grid gap-4 sm:grid-cols-2">
            <.link
              :for={capsule <- @delivered}
              navigate={~p"/app/capsules/#{capsule.id}"}
              id={"capsule-#{capsule.id}"}
              class={[
                "group relative block rounded-2xl border p-5 shadow-sm transition-all duration-300 hover:shadow-lg hover:-translate-y-0.5",
                theme(capsule.stationery).paper,
                if(is_nil(capsule.opened_at),
                  do: "border-emerald-300 dark:border-emerald-700 ring-1 ring-emerald-300/50",
                  else: "border-slate-200/60 dark:border-slate-700/60"
                )
              ]}
            >
              <%!-- browser-decrypts the title into the target below --%>
              <div
                id={"decrypt-capsule-#{capsule.id}"}
                phx-hook="DecryptCapsule"
                data-capsule-id={capsule.id}
                data-sealed-user-key={@current_scope.user.user_key}
                data-encrypted-title={capsule.title}
                class="hidden"
              />
              <div class="flex items-start justify-between gap-3">
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-envelope-open"
                    class={["h-5 w-5", theme(capsule.stationery).accent]}
                  />
                  <span
                    :if={is_nil(capsule.opened_at)}
                    class="inline-flex px-2 py-0.5 text-[11px] font-medium rounded-full bg-emerald-600 text-white"
                  >
                    New
                  </span>
                </div>
                <time class="text-xs text-slate-500 dark:text-slate-400">
                  {format_date(capsule.deliver_on, @local_today)}
                </time>
              </div>
              <h3
                data-decrypt-capsule-title={capsule.id}
                class="mt-3 text-lg font-semibold line-clamp-2 min-h-[1.75rem]"
              >
                <span class="opacity-40">A letter to you…</span>
              </h3>
              <p class={["mt-2 text-sm font-medium", theme(capsule.stationery).accent]}>
                Open your letter →
              </p>
            </.link>
          </div>
        </section>

        <%!-- Sealed letters (mysterious; only the date is known) --%>
        <section :if={@sealed != []}>
          <h2 class="flex items-center gap-2 text-sm font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400 mb-4">
            <.phx_icon name="hero-lock-closed" class="h-4 w-4" /> In the capsule
          </h2>

          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div
              :for={capsule <- @sealed}
              id={"sealed-#{capsule.id}"}
              class={[
                "relative rounded-2xl border border-slate-200/60 dark:border-slate-700/60 p-5 shadow-sm overflow-hidden",
                theme(capsule.stationery).envelope
              ]}
            >
              <div class="flex items-center justify-between">
                <.phx_icon name="hero-envelope" class={["h-6 w-6", theme(capsule.stationery).accent]} />
                <.phx_icon name="hero-lock-closed" class="h-4 w-4 text-slate-400 dark:text-slate-500" />
              </div>
              <p class="mt-4 text-sm text-slate-600 dark:text-slate-300">
                A sealed letter, waiting.
              </p>
              <p class={["mt-1 text-sm font-semibold", theme(capsule.stationery).accent]}>
                Opens in {countdown(capsule.deliver_on, @local_today)}
              </p>
              <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                {format_date(capsule.deliver_on, @local_today)}
              </p>
            </div>
          </div>
        </section>
      </div>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    local_today = JournalHelpers.get_local_today(socket)

    delivered = Capsules.list_delivered(user, local_today)
    sealed = Capsules.list_sealed(user, local_today)
    opening_today_count = Capsules.count_opening_today(user, local_today)

    {:ok,
     socket
     |> assign(:page_title, "Time Capsule")
     |> assign(:local_today, local_today)
     |> assign(:delivered, delivered)
     |> assign(:sealed, sealed)
     |> assign(:opening_today_count, opening_today_count)}
  end

  defp theme(stationery), do: MossletWeb.CapsuleLive.Stationery.theme(stationery)

  defp format_date(date, today) do
    cond do
      date == today -> "Today"
      date == Date.add(today, -1) -> "Yesterday"
      true -> Calendar.strftime(date, "%B %-d, %Y")
    end
  end

  defp countdown(date, today) do
    days = Date.diff(date, today)

    cond do
      days <= 0 -> "today"
      days < 7 -> quantify(days, "day")
      days < 45 -> quantify(round(days / 7), "week")
      days < 365 -> quantify(round(days / 30), "month")
      true -> quantify(round(days / 365), "year")
    end
  end

  defp quantify(1, unit), do: "1 #{unit}"
  defp quantify(n, unit), do: "#{n} #{unit}s"
end
