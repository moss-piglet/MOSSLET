defmodule MossletWeb.PublicLive.Safety do
  @moduledoc """
  Public `/safety` page: area-aware crisis & safety resources.

  Deliberately **public** so it is reachable without signing in and is
  structurally impossible for a guardian to co-read (guardianship co-read only
  ever covers a managed member's own ZK content — never this page). It points
  people, especially managed family members and minors, to established,
  independent help organizations and government agencies rather than routing an
  abuse report through MOSSLET itself.

  Data and the US ZIP→state resolver live in `Mosslet.Safety`. The ZIP is
  resolved in-memory to choose a region label and is never stored or sent
  anywhere.
  """
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  alias Mosslet.Safety

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:safety}
      container_max_width={@max_width}
      socket={@socket}
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <div class="isolate">
          <%!-- Hero --%>
          <div class="relative isolate">
            <div class="absolute inset-0 -z-10 overflow-hidden" aria-hidden="true">
              <div class="absolute left-1/2 top-0 -translate-x-1/2 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-16 pt-36 sm:pt-48 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-2xl text-center">
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    You're not alone
                  </h1>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400">
                    If you feel unsafe, controlled, or hurt — including by a parent, guardian, or
                    anyone close to you — confidential help is available. Below are trusted
                    organizations and government agencies that can support you directly.
                  </p>
                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 to-emerald-400 shadow-sm shadow-emerald-500/30">
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Emergency banner --%>
          <div class="mx-auto max-w-4xl px-6 lg:px-8">
            <div
              role="alert"
              class="flex items-start gap-3 rounded-xl border-l-4 border-rose-500 bg-rose-50 dark:bg-rose-900/20 p-4"
            >
              <.phx_icon
                name="hero-exclamation-triangle"
                class="size-6 flex-shrink-0 text-rose-600 dark:text-rose-400"
              />
              <p class="text-sm text-rose-800 dark:text-rose-200">
                <strong>In immediate danger?</strong>
                Contact your local emergency services right away —
                <strong>call 911 in the United States</strong>
                (or your country's emergency number). Your safety comes first.
              </p>
            </div>
          </div>

          <%!-- Area search --%>
          <div class="mx-auto mt-16 max-w-4xl px-6 lg:px-8">
            <.liquid_card padding="lg">
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-teal-500 to-emerald-500">
                    <.phx_icon name="hero-map-pin" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-semibold">
                    Find help in your area
                  </span>
                </div>
              </:title>

              <p class="mb-6 text-slate-600 dark:text-slate-400 leading-relaxed">
                Choose your country (and, in the US, enter your ZIP code) to see relevant resources.
                We don't store or share what you enter — it just helps us point you to the right place.
              </p>

              <.form
                for={@form}
                id="safety-area-form"
                phx-change="select_country"
                phx-submit="find"
                class="grid grid-cols-1 gap-4 sm:grid-cols-[1fr_1fr_auto] sm:items-end"
              >
                <.phx_input
                  field={@form[:country]}
                  type="select"
                  label="Country"
                  options={Safety.countries()}
                />

                <.phx_input
                  :if={@country == "US"}
                  field={@form[:query]}
                  type="text"
                  label="ZIP code (optional)"
                  placeholder="e.g. 94103"
                  inputmode="numeric"
                  autocomplete="postal-code"
                />

                <.liquid_button type="submit" icon="hero-magnifying-glass" class="sm:mb-0.5">
                  Find resources
                </.liquid_button>
              </.form>

              <p
                :if={@region}
                class="mt-4 inline-flex items-center gap-1.5 text-sm font-medium text-emerald-700 dark:text-emerald-300"
              >
                <.phx_icon name="hero-check-circle" class="size-4" />
                Showing resources relevant to {@region}.
              </p>
            </.liquid_card>
          </div>

          <%!-- Results --%>
          <div class="mx-auto mt-12 max-w-7xl px-6 lg:px-8">
            <div class="mx-auto max-w-4xl">
              <h2 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
                {@results_heading}
              </h2>
              <p class="mt-2 text-slate-600 dark:text-slate-400">
                These services are free and confidential unless noted. You can reach out for yourself
                or for someone you're worried about.
              </p>

              <div class="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">
                <.resource_card :for={r <- @resources} resource={r} />
              </div>

              <%!-- Worldwide fallback (always offered when showing US, since US
                    residents may need to help someone abroad) --%>
              <div :if={@show_global?} class="mt-16">
                <h2 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
                  Outside the United States
                </h2>
                <p class="mt-2 text-slate-600 dark:text-slate-400">
                  These directories find verified, local support lines in your own country and are
                  kept up to date by the organizations that run them.
                </p>
                <div class="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">
                  <.resource_card :for={r <- Safety.global_resources()} resource={r} />
                </div>
              </div>
            </div>
          </div>

          <%!-- MOSSLET's own stance --%>
          <div class="mx-auto mt-24 max-w-4xl px-6 lg:px-8">
            <.liquid_card padding="lg">
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-indigo-500 to-blue-500">
                    <.phx_icon name="hero-shield-check" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-indigo-500 to-blue-500 bg-clip-text text-transparent font-semibold">
                    Where MOSSLET stands
                  </span>
                </div>
              </:title>

              <div class="space-y-4 text-slate-600 dark:text-slate-400 leading-relaxed">
                <p>
                  Family guardianship on MOSSLET is <strong>consent-based co-reading</strong>, never
                  surveillance. There is no master key and no hidden way for anyone — including
                  MOSSLET — to read your content. A guardian can only read what you choose to share,
                  using their own key, and you can always see exactly who that is.
                </p>
                <p>
                  If you're a managed family member, you can <strong>pause sharing</strong>
                  new content with a guardian at any time from your family dashboard's transparency
                  panel. Using guardianship to control, coerce, monitor, or harvest a family member
                  is a serious violation of our
                  <.link
                    navigate={~p"/terms"}
                    class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 underline decoration-emerald-500/30"
                  >
                    Terms of Service
                  </.link>
                  — and the resources above can help you if it's happening to you.
                </p>
                <p>
                  Have a question for our team? Email
                  <.link
                    href="mailto:support@mosslet.com"
                    class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500"
                  >
                    support@mosslet.com
                  </.link>
                  or visit our
                  <.link
                    navigate={~p"/support"}
                    class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 underline decoration-emerald-500/30"
                  >
                    Support page
                  </.link>
                  . For your safety, please use the dedicated crisis and abuse organizations above
                  for anything urgent — they're trained and available around the clock.
                </p>
              </div>
            </.liquid_card>
          </div>
        </div>
      </div>

      <div class="pb-24"></div>
    </.layout>
    """
  end

  attr :resource, :map, required: true

  defp resource_card(assigns) do
    ~H"""
    <div class="group relative overflow-hidden rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg shadow-slate-900/10 dark:shadow-slate-900/30 transition-all duration-300 ease-out hover:scale-[1.02] hover:shadow-2xl hover:shadow-emerald-500/10">
      <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 group-hover:opacity-100">
      </div>

      <div class="relative p-6">
        <div class="flex items-start gap-3">
          <div class={[
            "flex size-10 flex-shrink-0 items-center justify-center rounded-lg bg-gradient-to-r",
            @resource.gradient
          ]}>
            <.phx_icon name={@resource.icon} class="size-6 text-white" />
          </div>
          <div class="min-w-0">
            <h3 class="text-lg font-bold leading-tight text-slate-900 dark:text-slate-100">
              {@resource.name}
            </h3>
          </div>
        </div>

        <p class="mt-3 text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
          {@resource.description}
        </p>

        <div class="mt-4 flex flex-wrap items-center gap-2">
          <a
            :if={@resource.phone}
            href={"tel:" <> String.replace(@resource.phone, ~r/[^0-9+]/, "")}
            class="inline-flex items-center gap-1.5 rounded-full bg-emerald-100 dark:bg-emerald-900/30 px-3 py-1.5 text-sm font-semibold text-emerald-800 dark:text-emerald-200 transition-colors hover:bg-emerald-200 dark:hover:bg-emerald-800/40"
          >
            <.phx_icon name="hero-phone" class="size-4" /> {@resource.phone}
          </a>
          <span
            :if={@resource.text}
            class="inline-flex items-center gap-1.5 rounded-full bg-teal-100 dark:bg-teal-900/30 px-3 py-1.5 text-sm font-semibold text-teal-800 dark:text-teal-200"
          >
            <.phx_icon name="hero-chat-bubble-left-right" class="size-4" /> {@resource.text}
          </span>
          <.link
            href={@resource.url}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-1.5 rounded-full border border-slate-300 dark:border-slate-600 px-3 py-1.5 text-sm font-semibold text-slate-700 dark:text-slate-300 transition-colors hover:border-emerald-500 hover:text-emerald-700 dark:hover:text-emerald-300"
          >
            Visit website <.phx_icon name="hero-arrow-top-right-on-square" class="size-4" />
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Safety & Help")
     |> assign_new(:meta_description, fn ->
       "If you feel unsafe or are being hurt or controlled — including by a guardian — confidential help is available. Find trusted crisis and abuse-support organizations and government agencies in your area."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/support/support_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Trusted safety and crisis resources for anyone who feels unsafe or controlled"
     )
     |> apply_area("US", "")}
  end

  @impl true
  def handle_event("select_country", %{"area" => %{"country" => country} = params}, socket) do
    {:noreply, apply_area(socket, country, Map.get(params, "query", ""))}
  end

  @impl true
  def handle_event("find", %{"area" => %{"country" => country} = params}, socket) do
    {:noreply, apply_area(socket, country, Map.get(params, "query", ""))}
  end

  # Recompute the form + visible resources for a chosen country/ZIP. The ZIP is
  # used only to derive a friendly region label; it is never persisted.
  defp apply_area(socket, country, query) do
    {resources, region, show_global?, heading} =
      if Safety.us?(country) do
        region =
          case Safety.resolve_us_state(query) do
            {:ok, state} -> state <> ", United States"
            :error -> nil
          end

        {Safety.us_resources(), region, true, "United States resources"}
      else
        label = country_label(country)
        {Safety.global_resources(), label, false, "Resources for #{label}"}
      end

    socket
    |> assign(:country, country)
    |> assign(:region, region)
    |> assign(:resources, resources)
    |> assign(:show_global?, show_global?)
    |> assign(:results_heading, heading)
    |> assign(:form, to_form(%{"country" => country, "query" => query}, as: :area))
  end

  defp country_label(code) do
    Safety.countries()
    |> Enum.find_value("your area", fn {label, c} -> if c == code, do: label end)
  end
end
