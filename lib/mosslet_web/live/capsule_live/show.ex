defmodule MossletWeb.CapsuleLive.Show do
  @moduledoc """
  Open and read a delivered letter from your past self.

  Delivery is gated purely on the plaintext `deliver_on` metadata: a sealed
  letter (deliver_on in the future) can never be opened here — the server
  refuses before any ciphertext is handed to the browser. Once delivered, the
  letter's title/body are decrypted in the browser via `DecryptCapsule`.
  """
  use MossletWeb, :live_view

  alias Mosslet.Capsules
  alias MossletWeb.CapsuleLive.Stationery
  alias MossletWeb.Helpers.JournalHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="focus"
      current_scope={@current_scope}
      current_page={:capsules}
      back_path={~p"/app/capsules"}
    >
      <div
        id={"decrypt-capsule-#{@capsule.id}"}
        phx-hook="DecryptCapsule"
        data-capsule-id={@capsule.id}
        data-sealed-user-key={@current_scope.user.user_key}
        data-encrypted-title={@capsule.title}
        data-encrypted-body={@capsule.body}
        class="hidden"
      />

      <div
        class="max-w-2xl mx-auto pb-16"
        x-data="{ open: false }"
        x-init="setTimeout(() => open = true, 350)"
      >
        <%!-- Envelope flap / opening cue --%>
        <div class="text-center mb-6">
          <div
            class={[
              "inline-flex items-center justify-center h-14 w-14 rounded-2xl transition-all duration-700",
              theme(@capsule.stationery).envelope
            ]}
            x-bind:class="open ? 'scale-100 rotate-0' : 'scale-90 -rotate-6'"
          >
            <.phx_icon
              name="hero-envelope-open"
              class={["h-7 w-7", theme(@capsule.stationery).accent]}
            />
          </div>
          <p class="mt-3 text-sm text-slate-500 dark:text-slate-400">
            You sealed this letter on {format_date(@capsule.sealed_at)}. It arrived {arrived_phrase(
              @capsule.deliver_on,
              @local_today
            )}.
          </p>
        </div>

        <%!-- The letter, revealed --%>
        <article
          x-show="open"
          x-transition:enter="transition ease-out duration-700"
          x-transition:enter-start="opacity-0 translate-y-6 scale-95"
          x-transition:enter-end="opacity-100 translate-y-0 scale-100"
          class={[
            "rounded-2xl border border-slate-200/60 dark:border-slate-700/60 shadow-xl p-6 sm:p-10",
            theme(@capsule.stationery).paper
          ]}
        >
          <h1
            data-decrypt-capsule-title={@capsule.id}
            class="text-2xl font-semibold mb-6"
          >
            <span class="opacity-40">Opening your letter…</span>
          </h1>
          <div
            data-decrypt-capsule-body-prose={@capsule.id}
            class="prose prose-slate dark:prose-invert max-w-none prose-lg prose-p:leading-relaxed"
          >
          </div>

          <div class="mt-8 pt-6 border-t border-slate-300/40 dark:border-slate-600/40 text-sm italic opacity-70">
            — with love, from a past you
          </div>
        </article>

        <%!-- Actions --%>
        <div class="mt-8 flex items-center justify-between">
          <.link
            phx-click="delete"
            data-confirm="Delete this letter forever? This can't be undone."
            class="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-rose-600 dark:text-rose-400 hover:text-rose-700 dark:hover:text-rose-300 transition-colors"
          >
            <.phx_icon name="hero-trash" class="h-4 w-4" /> Delete
          </.link>
          <.link
            navigate={~p"/app/capsules/new"}
            class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
          >
            <.phx_icon name="hero-pencil-square" class="h-4 w-4" /> Write another
          </.link>
        </div>
      </div>
    </.layout>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user
    local_today = JournalHelpers.get_local_today(socket)

    case Capsules.get_capsule(id, user) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That letter couldn't be found.")
         |> push_navigate(to: ~p"/app/capsules")}

      capsule ->
        if Capsules.delivered?(capsule, local_today) do
          # Metadata-only side effect: mark as read. Never touches content.
          {:ok, capsule} =
            case Capsules.mark_opened(capsule, user) do
              {:ok, updated} -> {:ok, updated}
              _ -> {:ok, capsule}
            end

          {:ok,
           socket
           |> assign(:page_title, "Your letter")
           |> assign(:local_today, local_today)
           |> assign(:capsule, capsule)}
        else
          {:ok,
           socket
           |> put_flash(:info, "That letter is still sealed. It opens on its delivery date.")
           |> push_navigate(to: ~p"/app/capsules")}
        end
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    user = socket.assigns.current_scope.user

    case Capsules.delete_capsule(socket.assigns.capsule, user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Letter deleted.")
         |> push_navigate(to: ~p"/app/capsules")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not delete that letter.")}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp theme(stationery), do: Stationery.theme(stationery)

  defp format_date(nil), do: "an earlier day"

  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%B %-d, %Y")
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%B %-d, %Y")

  defp arrived_phrase(%Date{} = deliver_on, today) do
    cond do
      deliver_on == today -> "today"
      Date.diff(today, deliver_on) < 7 -> "this week"
      true -> "on #{Calendar.strftime(deliver_on, "%B %-d, %Y")}"
    end
  end
end
