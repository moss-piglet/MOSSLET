defmodule MossletWeb.CapsuleLive.Compose do
  @moduledoc """
  Write a letter to your future self and seal it in a time capsule.

  A distraction-free, stationery-styled writing surface. The letter's
  title/body are encrypted in the browser with the user_key (via the
  `CapsuleLetterFormHook`) before anything is sent — the server only ever
  learns the delivery date and cosmetic stationery, never the words.
  """
  use MossletWeb, :live_view

  alias Mosslet.Capsules
  alias Mosslet.Capsules.Capsule
  alias MossletWeb.CapsuleLive.Stationery

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="focus"
      current_scope={@current_scope}
      current_page={:capsules}
      back_path={~p"/app/capsules"}
      saving={@saving}
    >
      <:footer>
        <div class="flex items-center gap-3 text-sm text-slate-500 dark:text-slate-400">
          <span :if={@saving} class="flex items-center gap-1.5 text-teal-600 dark:text-teal-400">
            <span class="inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent"></span>
            Sealing...
          </span>
        </div>
        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/app/capsules"}
            class="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
          >
            Cancel
          </.link>
          <button
            type="button"
            id="capsule-seal-btn"
            phx-click="request_seal"
            disabled={@saving}
            class="inline-flex items-center gap-2 px-6 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
          >
            <.phx_icon name="hero-paper-airplane" class="h-4 w-4" /> Seal &amp; send
          </button>
        </div>
      </:footer>

      <div class="max-w-2xl mx-auto pb-16">
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center h-14 w-14 rounded-2xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/40 dark:to-emerald-900/30 mb-4">
            <.phx_icon name="hero-envelope" class="h-7 w-7 text-emerald-600 dark:text-emerald-400" />
          </div>
          <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
            A letter to your future self
          </h1>
          <p class="mt-2 text-sm text-slate-600 dark:text-slate-400">
            Write it now. We'll keep it sealed until the day you choose.
          </p>
        </div>

        <.form
          for={@form}
          id="capsule-form"
          phx-hook="CapsuleLetterFormHook"
          data-sealed-user-key={@current_scope.user.user_key}
          class="space-y-6"
        >
          <input type="hidden" name="capsule[stationery]" value={@stationery} />

          <%!-- Stationery picker --%>
          <div>
            <p class="text-xs font-medium uppercase tracking-wide text-slate-500 dark:text-slate-400 mb-2">
              Stationery
            </p>
            <div class="flex flex-wrap gap-2">
              <button
                :for={name <- Stationery.all()}
                type="button"
                phx-click="select_stationery"
                phx-value-stationery={name}
                title={Stationery.label(name)}
                aria-label={Stationery.label(name)}
                class={[
                  "h-8 w-8 rounded-full ring-2 ring-offset-2 ring-offset-white dark:ring-offset-slate-900 transition-all duration-200",
                  Stationery.theme(name).swatch,
                  if(@stationery == name,
                    do: "#{Stationery.theme(name).ring} scale-110",
                    else: "ring-transparent hover:scale-105"
                  )
                ]}
              ></button>
            </div>
          </div>

          <%!-- The letter --%>
          <div class={[
            "rounded-2xl border border-slate-200/60 dark:border-slate-700/60 shadow-lg p-6 sm:p-8 transition-colors duration-500",
            Stationery.theme(@stationery).paper
          ]}>
            <div id="capsule-title-container" phx-update="ignore">
              <input
                type="text"
                name="capsule[title]"
                placeholder="Dear future me…"
                id="capsule-title"
                class="w-full text-xl font-semibold bg-transparent border-none focus:ring-0 placeholder-slate-400/70 dark:placeholder-slate-500"
                autocomplete="off"
              />
            </div>
            <div id="capsule-body-container" phx-update="ignore" class="mt-4">
              <textarea
                name="capsule[body]"
                placeholder="What do you want to remember? What are you hoping for? Tell them everything…"
                phx-hook="AutoResize"
                id="capsule-body"
                class="w-full min-h-[16rem] text-lg leading-relaxed bg-transparent border-none focus:ring-0 resize-none placeholder-slate-400/70 dark:placeholder-slate-500 overflow-hidden"
              ></textarea>
            </div>
          </div>

          <%!-- Delivery date. Wrapped in phx-update="ignore" so the chosen date
                survives re-renders (stationery switches, opening the modal); the
                "sealed for" preview is updated client-side by the hook — no
                content or keystrokes are ever sent to the server. --%>
          <div class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/70 dark:bg-slate-800/70 p-5 space-y-3">
            <label
              for="capsule-deliver-on"
              class="flex items-center gap-2 text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              <.phx_icon name="hero-calendar-days" class="h-4 w-4 text-teal-600 dark:text-teal-400" />
              Deliver this letter on
            </label>
            <div id="capsule-date-container" phx-update="ignore">
              <input
                type="date"
                id="capsule-deliver-on"
                name="capsule[deliver_on]"
                value={@form[:deliver_on].value}
                min={@min_date}
                class="block w-full rounded-lg border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm focus:border-teal-500 focus:ring-teal-500 sm:text-sm"
              />
            </div>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              This capsule will stay sealed for <span id="capsule-seal-duration" class="font-medium">{@deliver_on_human}</span>.
            </p>
          </div>

          <%!-- Honest disclosure --%>
          <div class="bg-teal-50 dark:bg-teal-900/20 rounded-xl p-4 border border-teal-200 dark:border-teal-700">
            <div class="flex items-start gap-2 text-sm text-teal-700 dark:text-teal-300">
              <.phx_icon name="hero-lock-closed" class="h-4 w-4 mt-0.5 flex-shrink-0" />
              <span>
                Your letter is encrypted end-to-end in your browser before it's sealed.
                We can see only the <strong>date</strong> you choose — never a single word you write.
              </span>
            </div>
          </div>
        </.form>
      </div>

      <%!-- Beautiful confirmation modal (replaces window.confirm). Sealing is
            permanent until the delivery date, so we confirm intent. The actual
            seal is still a browser-encrypted submit of #capsule-form. --%>
      <.liquid_modal
        :if={@show_confirm}
        id="capsule-confirm-modal"
        show={@show_confirm}
        size="sm"
        on_cancel={
          MossletWeb.DesignSystem.liquid_hide_modal("capsule-confirm-modal") |> JS.push("cancel_seal")
        }
      >
        <:title>
          <div class="flex items-center gap-3">
            <div class="p-2 rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/40 dark:to-emerald-900/30">
              <.phx_icon
                name="hero-paper-airplane"
                class="size-5 text-emerald-600 dark:text-emerald-400"
              />
            </div>
            <span>Ready to send your letter?</span>
          </div>
        </:title>

        <div class="space-y-5">
          <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
            Once you seal it, this letter stays locked away until <span class="font-medium text-slate-800 dark:text-slate-200">{@deliver_on_display}</span>.
            You won't be able to read or edit it until then — that's the whole point. ✨
          </p>

          <div class="bg-teal-50 dark:bg-teal-900/20 rounded-xl p-3 border border-teal-200 dark:border-teal-700">
            <div class="flex items-start gap-2 text-xs text-teal-700 dark:text-teal-300">
              <.phx_icon name="hero-lock-closed" class="h-4 w-4 mt-0.5 flex-shrink-0" />
              <span>Encrypted in your browser. We only ever see the date — never your words.</span>
            </div>
          </div>

          <div class="flex justify-end gap-3 pt-1">
            <.liquid_button
              type="button"
              variant="ghost"
              color="slate"
              phx-click={
                MossletWeb.DesignSystem.liquid_hide_modal("capsule-confirm-modal")
                |> JS.push("cancel_seal")
              }
            >
              Keep writing
            </.liquid_button>
            <button
              type="submit"
              form="capsule-form"
              phx-click={MossletWeb.DesignSystem.liquid_hide_modal("capsule-confirm-modal")}
              class="inline-flex items-center gap-2 px-5 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-teal-500 to-emerald-500 rounded-xl shadow-sm hover:from-teal-600 hover:to-emerald-600 transition-all duration-200"
            >
              <.phx_icon name="hero-paper-airplane" class="h-4 w-4" /> Seal &amp; send
            </button>
          </div>
        </div>
      </.liquid_modal>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    default_deliver_on = Date.add(Date.utc_today(), 365)

    changeset =
      Capsule.changeset_zk(%Capsule{stationery: Stationery.default()}, %{
        "deliver_on" => default_deliver_on
      })

    {:ok,
     socket
     |> assign(:page_title, "Write a letter")
     |> assign(:stationery, Stationery.default())
     |> assign(:saving, false)
     |> assign(:show_confirm, false)
     |> assign(:min_date, Date.to_iso8601(Date.add(Date.utc_today(), 1)))
     |> assign(:deliver_on_human, humanize_until(default_deliver_on))
     |> assign(:deliver_on_display, format_display(default_deliver_on))
     |> assign(:form, to_form(changeset, as: :capsule))}
  end

  @impl true
  def handle_event("select_stationery", %{"stationery" => stationery}, socket) do
    stationery =
      if stationery in Stationery.all(), do: stationery, else: Stationery.default()

    {:noreply, assign(socket, :stationery, stationery)}
  end

  @impl true
  def handle_event("request_seal", params, socket) do
    # `date` is metadata (the delivery date) read from the input by the JS hook
    # before the click bubbles. Never any letter content.
    deliver_on = parse_date(params["date"])

    socket =
      if deliver_on do
        socket
        |> assign(:deliver_on_display, format_display(deliver_on))
        |> assign(:deliver_on_human, humanize_until(deliver_on))
      else
        socket
      end

    {:noreply, assign(socket, :show_confirm, true)}
  end

  @impl true
  def handle_event("cancel_seal", _params, socket) do
    {:noreply, assign(socket, :show_confirm, false)}
  end

  @impl true
  def handle_event("capsule_empty", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_confirm, false)
     |> put_flash(:error, "Write a few words to your future self first. ✍️")}
  end

  @impl true
  def handle_event("save_capsule_zk", params, socket) do
    user = socket.assigns.current_scope.user
    socket = assign(socket, :show_confirm, false)

    if is_nil(params["encrypted_body"]) do
      {:noreply,
       put_flash(socket, :error, "Your letter needs at least a few words before you seal it.")}
    else
      socket = assign(socket, :saving, true)

      attrs = %{
        "encrypted_title" => params["encrypted_title"],
        "encrypted_body" => params["encrypted_body"],
        "deliver_on" => params["deliver_on"],
        "stationery" => params["stationery"] || socket.assigns.stationery,
        "word_count" => params["word_count"] || 0
      }

      case Capsules.create_capsule_zk(user, attrs) do
        {:ok, _capsule} ->
          {:noreply,
           socket
           |> put_flash(:info, "Sealed. Your letter is on its way to a future you. ✉️")
           |> push_navigate(to: ~p"/app/capsules")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:saving, false)
           |> put_flash(:error, seal_error_message(changeset))}
      end
    end
  end

  @impl true
  def handle_event("capsule_encrypt_failed", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_confirm, false)
     |> put_flash(:error, "We couldn't seal your letter just now. Please try again.")}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp seal_error_message(changeset) do
    case changeset.errors[:deliver_on] do
      {msg, _} -> "Delivery date #{msg}."
      _ -> "We couldn't seal your letter. Please try again."
    end
  end

  defp format_display(%Date{} = date), do: Calendar.strftime(date, "%B %-d, %Y")

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp humanize_until(%Date{} = date) do
    days = Date.diff(date, Date.utc_today())

    cond do
      days <= 0 -> nil
      days < 7 -> quantify(days, "day")
      days < 45 -> quantify(round(days / 7), "week")
      days < 365 -> quantify(round(days / 30), "month")
      true -> quantify(round(days / 365), "year")
    end
  end

  defp quantify(1, unit), do: "1 #{unit}"
  defp quantify(n, unit), do: "#{n} #{unit}s"
end
