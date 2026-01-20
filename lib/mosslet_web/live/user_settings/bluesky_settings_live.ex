defmodule MossletWeb.BlueskySettingsLive do
  @moduledoc """
  Settings page for connecting and managing Bluesky account integration.
  """
  use MossletWeb, :live_view

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.Client
  alias MossletWeb.DesignSystem

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    bluesky_account = Bluesky.get_account_for_user(user.id)

    {:ok,
     assign(socket,
       page_title: "Settings",
       bluesky_account: bluesky_account,
       connect_form: to_form(%{"handle" => "", "app_password" => ""}, as: :connect),
       sync_form: build_sync_form(bluesky_account),
       connecting: false,
       connection_error: nil,
       show_app_password_help: false
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:bluesky_settings}
      sidebar_current_page={:bluesky_settings}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-8">
        <div class="mb-8">
          <div class="mb-6">
            <h1 class="text-2xl font-bold tracking-tight sm:text-3xl bg-gradient-to-r from-sky-500 to-blue-600 bg-clip-text text-transparent">
              Bluesky Integration
            </h1>
            <p class="mt-2 text-base text-slate-600 dark:text-slate-400">
              Connect your Bluesky account to sync posts between platforms.
            </p>
          </div>
          <div class="h-1 w-20 rounded-full bg-gradient-to-r from-sky-400 via-blue-500 to-sky-400 shadow-sm shadow-sky-500/30">
          </div>
        </div>

        <div class="space-y-6 max-w-3xl">
          <%= if @bluesky_account do %>
            <.connected_account_card
              account={@bluesky_account}
              sync_form={@sync_form}
            />
          <% else %>
            <.connect_account_card
              connect_form={@connect_form}
              connecting={@connecting}
              connection_error={@connection_error}
              show_app_password_help={@show_app_password_help}
            />
          <% end %>

          <.about_bluesky_card />
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  defp connected_account_card(assigns) do
    ~H"""
    <DesignSystem.liquid_card class="bg-gradient-to-br from-sky-50/50 to-blue-50/30 dark:from-sky-900/20 dark:to-blue-900/10">
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-sky-100 via-blue-50 to-sky-100 dark:from-sky-900/30 dark:via-blue-900/25 dark:to-sky-900/30">
            <.phx_icon
              name="hero-check-circle"
              class="h-4 w-4 text-sky-600 dark:text-sky-400"
            />
          </div>
          <span class="text-sky-800 dark:text-sky-200">Connected Account</span>
        </div>
      </:title>

      <div class="space-y-6">
        <div class="flex items-center gap-4">
          <div class="h-12 w-12 rounded-full bg-gradient-to-br from-sky-400 to-blue-500 flex items-center justify-center">
            <.phx_icon name="hero-cloud" class="h-6 w-6 text-white" />
          </div>
          <div>
            <p class="font-medium text-slate-900 dark:text-slate-100">
              @{@account.handle}
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              Connected · Last synced {format_last_sync(@account.last_synced_at)}
            </p>
          </div>
        </div>

        <div class="border-t border-sky-200 dark:border-sky-700 pt-6">
          <h4 class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-4">
            Sync Settings
          </h4>

          <.form
            id="sync-settings-form"
            for={@sync_form}
            phx-change="update_sync_settings"
            class="space-y-4"
          >
            <div class="space-y-3">
              <label class="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  name="sync[sync_enabled]"
                  checked={@sync_form[:sync_enabled].value}
                  class="h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500"
                />
                <span class="text-sm text-slate-700 dark:text-slate-300">
                  Enable sync (master switch)
                </span>
              </label>

              <label class="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  name="sync[sync_posts_to_bsky]"
                  checked={@sync_form[:sync_posts_to_bsky].value}
                  disabled={!@sync_form[:sync_enabled].value}
                  class="h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500 disabled:opacity-50"
                />
                <span class={[
                  "text-sm",
                  if(@sync_form[:sync_enabled].value,
                    do: "text-slate-700 dark:text-slate-300",
                    else: "text-slate-400 dark:text-slate-500"
                  )
                ]}>
                  Sync Mosslet posts to Bluesky
                </span>
              </label>

              <label class="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  name="sync[sync_posts_from_bsky]"
                  checked={@sync_form[:sync_posts_from_bsky].value}
                  disabled={!@sync_form[:sync_enabled].value}
                  class="h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500 disabled:opacity-50"
                />
                <span class={[
                  "text-sm",
                  if(@sync_form[:sync_enabled].value,
                    do: "text-slate-700 dark:text-slate-300",
                    else: "text-slate-400 dark:text-slate-500"
                  )
                ]}>
                  Import posts from Bluesky
                </span>
              </label>

              <label class="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  name="sync[auto_delete_from_bsky]"
                  checked={@sync_form[:auto_delete_from_bsky].value}
                  disabled={!@sync_form[:sync_enabled].value}
                  class="h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500 disabled:opacity-50"
                />
                <span class={[
                  "text-sm",
                  if(@sync_form[:sync_enabled].value,
                    do: "text-slate-700 dark:text-slate-300",
                    else: "text-slate-400 dark:text-slate-500"
                  )
                ]}>
                  Auto-delete from Bluesky when deleted on Mosslet
                </span>
              </label>
            </div>
          </.form>
        </div>

        <div class="border-t border-sky-200 dark:border-sky-700 pt-6">
          <DesignSystem.liquid_button
            variant="secondary"
            color="rose"
            icon="hero-link-slash"
            phx-click="disconnect_account"
            data-confirm="Are you sure you want to disconnect your Bluesky account? Your synced posts will remain on both platforms."
          >
            Disconnect Account
          </DesignSystem.liquid_button>
        </div>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  defp connect_account_card(assigns) do
    ~H"""
    <DesignSystem.liquid_card class="bg-gradient-to-br from-sky-50/50 to-blue-50/30 dark:from-sky-900/20 dark:to-blue-900/10">
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-sky-100 via-blue-50 to-sky-100 dark:from-sky-900/30 dark:via-blue-900/25 dark:to-sky-900/30">
            <.phx_icon
              name="hero-cloud"
              class="h-4 w-4 text-sky-600 dark:text-sky-400"
            />
          </div>
          <span class="text-sky-800 dark:text-sky-200">Connect Bluesky Account</span>
        </div>
      </:title>

      <div class="space-y-6">
        <p class="text-slate-600 dark:text-slate-400">
          Connect your Bluesky account to cross-post and import content. You'll need an
          <button
            type="button"
            phx-click="toggle_app_password_help"
            class="text-sky-600 dark:text-sky-400 underline hover:text-sky-700 dark:hover:text-sky-300"
          >
            App Password
          </button>
          from Bluesky (not your main password).
        </p>

        <%= if @show_app_password_help do %>
          <div class="bg-sky-100 dark:bg-sky-900/30 rounded-lg p-4 border border-sky-200 dark:border-sky-700">
            <div class="flex items-start gap-3">
              <.phx_icon
                name="hero-information-circle"
                class="h-5 w-5 mt-0.5 text-sky-600 dark:text-sky-400 flex-shrink-0"
              />
              <div class="space-y-2">
                <span class="font-medium text-sm text-sky-800 dark:text-sky-200">
                  How to get an App Password
                </span>
                <ol class="text-sm text-sky-700 dark:text-sky-300 space-y-1 list-decimal list-inside">
                  <li>
                    Go to
                    <a href="https://bsky.app/settings" target="_blank" class="underline">
                      bsky.app/settings
                    </a>
                  </li>
                  <li>Click "Privacy and security"</li>
                  <li>Click "App passwords"</li>
                  <li>Click "Add App Password"</li>
                  <li>Name it "Mosslet" and copy the password</li>
                </ol>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @connection_error do %>
          <div class="bg-rose-100 dark:bg-rose-900/30 rounded-lg p-4 border border-rose-200 dark:border-rose-700">
            <div class="flex items-start gap-3">
              <.phx_icon
                name="hero-exclamation-triangle"
                class="h-5 w-5 mt-0.5 text-rose-600 dark:text-rose-400 flex-shrink-0"
              />
              <div>
                <span class="font-medium text-sm text-rose-800 dark:text-rose-200">
                  Connection Failed
                </span>
                <p class="text-sm text-rose-700 dark:text-rose-300 mt-1">
                  {@connection_error}
                </p>
              </div>
            </div>
          </div>
        <% end %>

        <.form
          id="connect-bluesky-form"
          for={@connect_form}
          phx-submit="connect_account"
          class="space-y-4"
        >
          <div>
            <label
              for="connect_handle"
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Bluesky Handle
            </label>
            <.phx_input
              field={@connect_form[:handle]}
              type="text"
              placeholder="yourname.bsky.social"
              class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-sky-500 focus:border-transparent"
              disabled={@connecting}
            />
          </div>

          <div>
            <label
              for="connect_app_password"
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              App Password
            </label>
            <.phx_input
              field={@connect_form[:app_password]}
              type="password"
              placeholder="xxxx-xxxx-xxxx-xxxx"
              class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-sky-500 focus:border-transparent"
              disabled={@connecting}
            />
          </div>

          <DesignSystem.liquid_button
            type="submit"
            variant="primary"
            color="blue"
            icon={if @connecting, do: "hero-arrow-path", else: "hero-link"}
            disabled={@connecting}
            class={if @connecting, do: "animate-pulse"}
          >
            {if @connecting, do: "Connecting...", else: "Connect Account"}
          </DesignSystem.liquid_button>
        </.form>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  defp about_bluesky_card(assigns) do
    ~H"""
    <DesignSystem.liquid_card class="bg-gradient-to-br from-slate-50/50 to-gray-50/30 dark:from-slate-900/20 dark:to-gray-900/10">
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-slate-100 via-gray-50 to-slate-100 dark:from-slate-900/30 dark:via-gray-900/25 dark:to-slate-900/30">
            <.phx_icon
              name="hero-question-mark-circle"
              class="h-4 w-4 text-slate-600 dark:text-slate-400"
            />
          </div>
          <span class="text-slate-800 dark:text-slate-200">About Bluesky Sync</span>
        </div>
      </:title>

      <div class="space-y-4 text-slate-600 dark:text-slate-400">
        <p>
          Bluesky is a decentralized social network built on the AT Protocol. By connecting your account,
          you can:
        </p>

        <ul class="space-y-2">
          <li class="flex items-start gap-2">
            <.phx_icon name="hero-arrow-up-circle" class="h-5 w-5 mt-0.5 text-sky-500 flex-shrink-0" />
            <span>Cross-post your Mosslet posts to Bluesky automatically</span>
          </li>
          <li class="flex items-start gap-2">
            <.phx_icon
              name="hero-arrow-down-circle"
              class="h-5 w-5 mt-0.5 text-sky-500 flex-shrink-0"
            />
            <span>Import your Bluesky posts to Mosslet for backup</span>
          </li>
          <li class="flex items-start gap-2">
            <.phx_icon name="hero-shield-check" class="h-5 w-5 mt-0.5 text-sky-500 flex-shrink-0" />
            <span>Keep control with encrypted storage on Mosslet</span>
          </li>
        </ul>

        <div class="pt-4 border-t border-slate-200 dark:border-slate-700">
          <p class="text-sm">
            <strong class="text-slate-700 dark:text-slate-300">Privacy note:</strong>
            Posts synced from Bluesky are stored encrypted on Mosslet. Only public posts can be synced to Bluesky.
          </p>
        </div>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  @impl true
  def handle_event("toggle_app_password_help", _params, socket) do
    {:noreply, assign(socket, show_app_password_help: !socket.assigns.show_app_password_help)}
  end

  def handle_event("connect_account", %{"connect" => params}, socket) do
    handle = String.trim(params["handle"] || "")
    app_password = String.trim(params["app_password"] || "")

    if handle == "" || app_password == "" do
      {:noreply,
       assign(socket, connection_error: "Please enter both your handle and app password.")}
    else
      socket = assign(socket, connecting: true, connection_error: nil)
      send(self(), {:do_connect, handle, app_password})
      {:noreply, socket}
    end
  end

  def handle_event("update_sync_settings", %{"sync" => params}, socket) do
    account = socket.assigns.bluesky_account

    attrs = %{
      sync_enabled: params["sync_enabled"] == "true",
      sync_posts_to_bsky: params["sync_posts_to_bsky"] == "true",
      sync_posts_from_bsky: params["sync_posts_from_bsky"] == "true",
      auto_delete_from_bsky: params["auto_delete_from_bsky"] == "true"
    }

    case Bluesky.update_sync_settings(account, attrs) do
      {:ok, updated_account} ->
        {:noreply,
         socket
         |> assign(bluesky_account: updated_account)
         |> assign(sync_form: build_sync_form(updated_account))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update sync settings.")}
    end
  end

  def handle_event("disconnect_account", _params, socket) do
    account = socket.assigns.bluesky_account

    case Bluesky.delete_account(account) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(bluesky_account: nil)
         |> assign(sync_form: nil)
         |> put_flash(:success, "Bluesky account disconnected successfully.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disconnect account.")}
    end
  end

  @impl true
  def handle_info({:do_connect, handle, app_password}, socket) do
    user = socket.assigns.current_scope.user

    case Client.create_session(handle, app_password) do
      {:ok, session} ->
        attrs = %{
          did: session.did,
          handle: session.handle,
          access_jwt: session.access_jwt,
          refresh_jwt: session.refresh_jwt,
          pds_url: "https://bsky.social"
        }

        case Bluesky.create_account(user, attrs) do
          {:ok, account} ->
            {:noreply,
             socket
             |> assign(bluesky_account: account)
             |> assign(sync_form: build_sync_form(account))
             |> assign(connecting: false)
             |> assign(connection_error: nil)
             |> put_flash(:success, "Successfully connected to Bluesky!")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> assign(connecting: false)
             |> assign(connection_error: "Failed to save account. Please try again.")}
        end

      {:error, {401, _}} ->
        {:noreply,
         socket
         |> assign(connecting: false)
         |> assign(
           connection_error: "Invalid handle or app password. Please check your credentials."
         )}

      {:error, {_status, %{message: message}}} when is_binary(message) ->
        {:noreply,
         socket
         |> assign(connecting: false)
         |> assign(connection_error: message)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(connecting: false)
         |> assign(connection_error: "Connection failed. Please try again later.")}
    end
  end

  defp build_sync_form(nil), do: nil

  defp build_sync_form(account) do
    to_form(
      %{
        "sync_enabled" => account.sync_enabled,
        "sync_posts_to_bsky" => account.sync_posts_to_bsky,
        "sync_posts_from_bsky" => account.sync_posts_from_bsky,
        "auto_delete_from_bsky" => account.auto_delete_from_bsky
      },
      as: :sync
    )
  end

  defp format_last_sync(nil), do: "never"

  defp format_last_sync(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604_800 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%B %d, %Y")
    end
  end
end
