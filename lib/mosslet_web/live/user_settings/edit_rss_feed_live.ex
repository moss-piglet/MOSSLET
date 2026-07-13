defmodule MossletWeb.EditRssFeedLive do
  @moduledoc """
  RSS feed (syndication) settings (task #385).

  The feed is always PUBLIC-content-only — connections/private posts are
  browser-encrypted and can never be rendered server-side, so they are never
  in a feed. This screen controls two things:

    1. Whether the feed is published at all (`rss_feed_enabled`).
    2. Who sees the "copy RSS feed link" affordance on the user's public posts
       (`rss_feed_visibility`): nobody (manual sharing), connections, or everyone.
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     assign(socket,
       page_title: "RSS Feed",
       rss_form: to_form(Accounts.change_user_rss_feed(user)),
       rss_copied?: false
     )}
  end

  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:edit_rss_feed}
      sidebar_current_page={:edit_rss_feed}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-orange-500 to-amber-500 bg-clip-text text-transparent">
              RSS Feed
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Let people follow your public posts in any RSS reader — no account, no algorithm.
            </p>
          </div>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-orange-400 via-amber-400 to-yellow-400 shadow-sm shadow-orange-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-2xl">
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-orange-100 via-amber-50 to-orange-100 dark:from-orange-900/30 dark:via-amber-900/25 dark:to-orange-900/30">
                  <.phx_icon name="hero-rss" class="h-4 w-4 text-orange-600 dark:text-orange-400" />
                </div>
                <span>Your Feed</span>
                <span class={[
                  "inline-flex px-2.5 py-0.5 text-xs rounded-lg font-medium",
                  if(@current_user.rss_feed_enabled,
                    do:
                      "bg-gradient-to-r from-orange-100 to-amber-200 text-orange-800 dark:from-orange-800 dark:to-amber-700 dark:text-orange-200 border border-orange-300 dark:border-orange-600",
                    else:
                      "bg-gradient-to-r from-slate-100 to-slate-200 text-slate-800 dark:from-slate-700 dark:to-slate-600 dark:text-slate-200 border border-slate-300 dark:border-slate-600"
                  )
                ]}>
                  {if @current_user.rss_feed_enabled, do: "On", else: "Off"}
                </span>
              </div>
            </:title>

            <div class="space-y-6">
              <p class="text-sm leading-relaxed text-slate-600 dark:text-slate-400">
                Publish an RSS feed of your posts so anyone can follow you in their favorite
                reader — NetNewsWire, Feedly, Reeder, and others. Your feed auto-updates:
                whenever you share a new post, subscribers see it on their next refresh.
              </p>

              <div class="bg-amber-50 dark:bg-amber-900/20 rounded-lg p-4 border border-amber-200 dark:border-amber-700">
                <div class="flex items-start gap-2 text-sm text-amber-800 dark:text-amber-200">
                  <.phx_icon name="hero-lock-closed" class="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <span>
                    Your feed includes <strong>public posts only</strong>. Posts shared with
                    connections or kept private are encrypted end-to-end — not even we can read
                    them, and an RSS reader has no way to decrypt them. So they're never in a
                    feed. This keeps your private life private while letting your public voice
                    travel.
                  </span>
                </div>
              </div>

              <.form
                id="update_rss_feed_form"
                for={@rss_form}
                phx-change="toggle_rss_feed"
                class="space-y-6"
              >
                <DesignSystem.liquid_checkbox
                  field={@rss_form[:rss_feed_enabled]}
                  label="Publish a public RSS feed of my posts"
                  help={
                    if @current_user.rss_feed_enabled,
                      do:
                        "Turn off to immediately take your feed offline (existing links stop working).",
                      else: "Turn on to generate a private, unguessable feed link you can share."
                  }
                />
              </.form>

              <div
                :if={@current_user.rss_feed_enabled && @current_user.rss_feed_token}
                class="space-y-6"
              >
                <%!-- Recommendation: help subscribers find & recognize the author.
                The feed always works regardless — this only improves the profile
                click-through link. --%>
                <div
                  :if={!profile_publicly_viewable?(@current_user)}
                  class="rounded-xl p-4 bg-teal-50 dark:bg-teal-900/20 border border-teal-200 dark:border-teal-700"
                >
                  <div class="flex items-start gap-3">
                    <.phx_icon
                      name="hero-sparkles"
                      class="h-5 w-5 mt-0.5 shrink-0 text-teal-600 dark:text-teal-400"
                    />
                    <div class="min-w-0 space-y-2">
                      <%= if needs_profile?(@current_user) do %>
                        <p class="text-sm text-teal-800 dark:text-teal-200">
                          Your feed works and subscribers can read your public posts. To help
                          them recognize and follow you, consider setting up a public profile —
                          your feed links back to it.
                        </p>
                        <.link
                          navigate={~p"/app/users/edit-profile"}
                          class="inline-flex items-center gap-1.5 text-sm font-medium text-teal-700 dark:text-teal-300 hover:text-teal-800 dark:hover:text-teal-200"
                        >
                          <.phx_icon name="hero-user-circle" class="h-4 w-4" /> Set up your profile
                        </.link>
                      <% else %>
                        <p class="text-sm text-teal-800 dark:text-teal-200">
                          Your feed works and subscribers can read your public posts. But your
                          profile isn't public, so anonymous RSS readers won't be able to open
                          your profile page from the feed. Set your account visibility to
                          <span class="font-medium">Public</span>
                          if you'd like readers to find you there too.
                        </p>
                        <.link
                          navigate={~p"/app/users/edit-visibility"}
                          class="inline-flex items-center gap-1.5 text-sm font-medium text-teal-700 dark:text-teal-300 hover:text-teal-800 dark:hover:text-teal-200"
                        >
                          <.phx_icon name="hero-eye" class="h-4 w-4" /> Adjust account visibility
                        </.link>
                      <% end %>
                    </div>
                  </div>
                </div>

                <%!-- Feed URL + actions --%>
                <div class="space-y-4 p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700">
                  <div>
                    <label class="block text-sm font-medium text-slate-900 dark:text-slate-100 mb-2">
                      Your feed link
                    </label>
                    <div class="flex flex-col sm:flex-row gap-2">
                      <input
                        id="rss-feed-url"
                        type="text"
                        readonly
                        value={rss_feed_url(@current_user)}
                        class="flex-1 min-w-0 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 px-3 py-2 text-sm text-slate-700 dark:text-slate-300 font-mono truncate focus:outline-none focus:ring-2 focus:ring-orange-500"
                      />
                      <button
                        id="rss-feed-copy-btn"
                        type="button"
                        phx-hook="ClipboardHook"
                        data-content={rss_feed_url(@current_user)}
                        class="inline-flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300 text-sm font-medium hover:bg-orange-200 dark:hover:bg-orange-900/50 transition-colors cursor-pointer"
                      >
                        <.phx_icon
                          name={if @rss_copied?, do: "hero-check", else: "hero-clipboard-document"}
                          class="h-4 w-4"
                        />
                        <span>{if @rss_copied?, do: "Copied", else: "Copy"}</span>
                      </button>
                    </div>
                  </div>

                  <div class="flex flex-wrap items-center gap-4">
                    <.link
                      href={rss_feed_url(@current_user)}
                      target="_blank"
                      rel="noopener"
                      class="inline-flex items-center gap-1.5 text-sm font-medium text-orange-600 dark:text-orange-400 hover:text-orange-700 dark:hover:text-orange-300"
                    >
                      <.phx_icon name="hero-arrow-top-right-on-square" class="h-4 w-4" /> Preview feed
                    </.link>

                    <button
                      type="button"
                      phx-click="regenerate_rss_feed_token"
                      data-confirm="Regenerate your feed link? Your current link will stop working and anyone subscribed will need the new one."
                      class="inline-flex items-center gap-1.5 text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200"
                    >
                      <.phx_icon name="hero-arrow-path" class="h-4 w-4" /> Regenerate link
                    </button>
                  </div>
                </div>

                <%!-- Discoverability: who sees the copy-link button on your public posts --%>
                <div class="space-y-4">
                  <div>
                    <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                      Show a "Follow via RSS" button on my public posts
                    </h3>
                    <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
                      Choose who sees a one-tap button to copy your feed link on your public posts.
                      This only affects the button — you can always share the link yourself.
                    </p>
                  </div>

                  <fieldset class="space-y-3">
                    <.rss_visibility_option
                      value="public"
                      current={@current_user.rss_feed_visibility}
                      icon="hero-globe-alt"
                      title="Everyone"
                      description="Anyone viewing your public posts can copy your feed link."
                    />
                    <.rss_visibility_option
                      value="connections"
                      current={@current_user.rss_feed_visibility}
                      icon="hero-users"
                      title="Connections only"
                      description="Only your connections see the button on your public posts."
                    />
                    <.rss_visibility_option
                      value="private"
                      current={@current_user.rss_feed_visibility}
                      icon="hero-link"
                      title="Just the link (manual)"
                      description="No button appears anywhere. You share your feed link yourself."
                    />
                  </fieldset>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  attr :value, :string, required: true
  attr :current, :atom, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp rss_visibility_option(assigns) do
    assigns = assign(assigns, :selected?, to_string(assigns.current) == assigns.value)

    ~H"""
    <button
      type="button"
      phx-click="set_rss_visibility"
      phx-value-visibility={@value}
      aria-pressed={to_string(@selected?)}
      class={[
        "w-full flex items-start gap-3 p-4 rounded-xl border text-left transition-all",
        if(@selected?,
          do:
            "border-orange-400 dark:border-orange-500 bg-orange-50 dark:bg-orange-900/20 ring-1 ring-orange-400/50",
          else:
            "border-slate-200 dark:border-slate-700 hover:border-orange-300 dark:hover:border-orange-600 hover:bg-slate-50 dark:hover:bg-slate-800/50"
        )
      ]}
    >
      <div class={[
        "relative flex h-8 w-8 shrink-0 items-center justify-center rounded-lg",
        if(@selected?,
          do: "bg-orange-100 dark:bg-orange-900/40 text-orange-600 dark:text-orange-300",
          else: "bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400"
        )
      ]}>
        <.phx_icon name={@icon} class="h-4 w-4" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-slate-900 dark:text-slate-100">{@title}</span>
          <.phx_icon
            :if={@selected?}
            name="hero-check-circle-solid"
            class="h-4 w-4 text-orange-500"
          />
        </div>
        <p class="mt-0.5 text-sm text-slate-600 dark:text-slate-400">{@description}</p>
      </div>
    </button>
    """
  end

  def handle_event("toggle_rss_feed", %{"user" => user_params}, socket) do
    enabled = user_params["rss_feed_enabled"] == "true"

    case Accounts.update_rss_feed_enabled(socket.assigns.current_scope.user, enabled) do
      {:ok, user} ->
        info =
          if enabled,
            do: "Your public RSS feed is on. Share the link below.",
            else: "Your RSS feed is off and its link no longer works."

        {:noreply,
         socket
         |> update_current_user(user)
         |> assign(rss_form: to_form(Accounts.change_user_rss_feed(user)), rss_copied?: false)
         |> put_flash(:success, info)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(rss_form: to_form(changeset))
         |> put_flash(:error, "Could not update your RSS feed setting.")}
    end
  end

  def handle_event("set_rss_visibility", %{"visibility" => visibility}, socket) do
    visibility_atom = String.to_existing_atom(visibility)

    case Accounts.update_rss_feed_visibility(
           socket.assigns.current_scope.user,
           visibility_atom
         ) do
      {:ok, user} ->
        {:noreply,
         socket
         |> update_current_user(user)
         |> assign(rss_form: to_form(Accounts.change_user_rss_feed(user)))
         |> put_flash(:success, rss_visibility_flash(visibility_atom))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update your feed sharing setting.")}
    end
  end

  def handle_event("regenerate_rss_feed_token", _params, socket) do
    case Accounts.regenerate_rss_feed_token(socket.assigns.current_scope.user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> update_current_user(user)
         |> assign(rss_form: to_form(Accounts.change_user_rss_feed(user)), rss_copied?: false)
         |> put_flash(:success, "Generated a new feed link. Your old link no longer works.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not regenerate your feed link.")}
    end
  end

  def handle_event("clipboard_copied", _params, socket) do
    {:noreply, assign(socket, rss_copied?: true)}
  end

  defp rss_visibility_flash(:public),
    do: "Everyone can now copy your feed link from your public posts."

  defp rss_visibility_flash(:connections),
    do: "Only your connections can copy your feed link from your public posts."

  defp rss_visibility_flash(:private),
    do: "The follow button is hidden. Share your feed link manually."

  defp update_current_user(socket, user) do
    scope = %{socket.assigns.current_scope | user: user}
    assign(socket, current_scope: scope, current_user: user)
  end

  defp rss_feed_url(%{rss_feed_token: token}) when is_binary(token) do
    MossletWeb.Endpoint.url() <> "/feeds/#{token}.xml"
  end

  defp rss_feed_url(_), do: ""

  # Whether the author has a profile the feed can meaningfully link to. The feed
  # itself never depends on this — it only governs the profile click-through and
  # the recommendation nudge below.
  defp needs_profile?(user), do: is_nil(profile(user))

  defp profile_publicly_viewable?(user) do
    user.visibility == :public and match?(%{visibility: :public}, profile(user))
  end

  defp profile(%{connection: %{profile: profile}}), do: profile
  defp profile(_), do: nil
end
