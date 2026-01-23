defmodule MossletWeb.BlueskySettingsLive do
  @moduledoc """
  Settings page for connecting and managing Bluesky account integration.
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts.User
  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.ExportTask
  alias Mosslet.Bluesky.ImportTask
  alias MossletWeb.DesignSystem

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    bluesky_account = Bluesky.get_account_for_user(user.id)

    {:ok,
     assign(socket,
       page_title: "Settings",
       bluesky_account: bluesky_account,
       sync_form: build_sync_form(bluesky_account),
       show_export_modal: false,
       export_password_form: to_form(%{"password" => ""}, as: :export_password),
       export_error: nil
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
        <div class="mb-6 flex items-center gap-3 rounded-lg border border-amber-200 dark:border-amber-800/50 bg-amber-50 dark:bg-amber-900/20 px-4 py-3">
          <.phx_icon
            name="hero-wrench-screwdriver"
            class="h-5 w-5 text-amber-600 dark:text-amber-400 flex-shrink-0"
          />
          <p class="text-sm text-amber-800 dark:text-amber-200">
            <span class="font-semibold">Under Construction</span>
            — Bluesky integration is actively being developed. Some features may be incomplete or change.
          </p>
        </div>

        <div class="mb-8">
          <div class="mb-6">
            <h1 class="text-2xl font-bold tracking-tight sm:text-3xl bg-gradient-to-r from-sky-500 to-blue-600 bg-clip-text text-transparent">
              Bluesky Integration
            </h1>
            <p class="mt-2 text-base text-slate-600 dark:text-slate-400">
              Import your Bluesky posts, export to Bluesky, or migrate completely and delete your Bluesky account.
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
            <.connect_with_oauth_card />
          <% end %>

          <.about_bluesky_card />
        </div>
      </DesignSystem.liquid_container>

      <.export_all_modal
        :if={@show_export_modal}
        export_password_form={@export_password_form}
        export_error={@export_error}
      />
    </.layout>
    """
  end

  defp export_all_modal(assigns) do
    ~H"""
    <div
      id="export-all-modal"
      class="fixed inset-0 z-50 overflow-y-auto"
      aria-labelledby="export-modal-title"
      role="dialog"
      aria-modal="true"
    >
      <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
        <div
          class="fixed inset-0 bg-slate-900/50 dark:bg-slate-900/75 transition-opacity"
          phx-click="close_export_modal"
        >
        </div>

        <div class="relative transform overflow-hidden rounded-lg bg-white dark:bg-slate-800 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
          <div class="px-4 pb-4 pt-5 sm:p-6">
            <div class="sm:flex sm:items-start">
              <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-900/30 sm:mx-0 sm:h-10 sm:w-10">
                <.phx_icon
                  name="hero-shield-exclamation"
                  class="h-6 w-6 text-amber-600 dark:text-amber-400"
                />
              </div>
              <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left flex-1">
                <h3
                  class="text-base font-semibold leading-6 text-slate-900 dark:text-slate-100"
                  id="export-modal-title"
                >
                  Export All Posts to Bluesky
                </h3>
                <div class="mt-2">
                  <p class="text-sm text-slate-500 dark:text-slate-400">
                    This will export all your Mosslet posts to your connected Bluesky account.
                    Please confirm your password to continue.
                  </p>
                  <div class="mt-3 p-3 bg-amber-50 dark:bg-amber-900/20 rounded-lg border border-amber-200 dark:border-amber-700">
                    <div class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-information-circle"
                        class="h-5 w-5 text-amber-600 dark:text-amber-400 flex-shrink-0 mt-0.5"
                      />
                      <div class="text-xs text-amber-700 dark:text-amber-300">
                        <strong>Privacy Note:</strong> Posts will be published publicly on Bluesky.
                        Private and connections-only posts will need to be decrypted during this session.
                      </div>
                    </div>
                  </div>
                </div>

                <%= if @export_error do %>
                  <div class="mt-3 p-3 bg-rose-50 dark:bg-rose-900/20 rounded-lg border border-rose-200 dark:border-rose-700">
                    <p class="text-sm text-rose-600 dark:text-rose-400">
                      <.phx_icon name="hero-exclamation-circle" class="h-4 w-4 inline" />
                      {@export_error}
                    </p>
                  </div>
                <% end %>

                <.form
                  id="export-password-form"
                  for={@export_password_form}
                  phx-submit="confirm_export_all"
                  class="mt-4"
                >
                  <div>
                    <label
                      for="export_password_password"
                      class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
                    >
                      Mosslet Password
                    </label>
                    <.phx_input
                      field={@export_password_form[:password]}
                      type="password"
                      placeholder="Enter your password"
                      class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-sky-500 focus:border-transparent"
                      autocomplete="current-password"
                    />
                  </div>

                  <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse gap-3">
                    <DesignSystem.liquid_button
                      type="submit"
                      variant="primary"
                      color="blue"
                      icon="hero-arrow-up-tray"
                    >
                      Export All Posts
                    </DesignSystem.liquid_button>
                    <DesignSystem.liquid_button
                      type="button"
                      variant="secondary"
                      color="slate"
                      phx-click="close_export_modal"
                    >
                      Cancel
                    </DesignSystem.liquid_button>
                  </div>
                </.form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp connect_with_oauth_card(assigns) do
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
          Connect your Bluesky account to import your posts, export content to Bluesky, or fully migrate and delete your Bluesky account.
          You'll be redirected to Bluesky to authorize the connection securely.
        </p>

        <div class="bg-sky-100 dark:bg-sky-900/30 rounded-lg p-4 border border-sky-200 dark:border-sky-700">
          <div class="flex items-start gap-3">
            <.phx_icon
              name="hero-information-circle"
              class="h-5 w-5 mt-0.5 text-sky-600 dark:text-sky-400 flex-shrink-0"
            />
            <div class="space-y-2 text-sm text-sky-700 dark:text-sky-300">
              <p>
                <strong>Don't have a Bluesky account?</strong>
                No problem! You can create one during the authorization process.
              </p>
            </div>
          </div>
        </div>

        <a
          href={~p"/app/oauth/bluesky/authorize"}
          class="inline-flex items-center justify-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-gradient-to-r from-sky-500 to-blue-600 hover:from-sky-600 hover:to-blue-700 rounded-lg shadow-sm transition-all"
        >
          <.phx_icon name="hero-arrow-right-end-on-rectangle" class="h-4 w-4" /> Connect with Bluesky
        </a>
      </div>
    </DesignSystem.liquid_card>
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

              <div class={[
                "ml-7 mt-2",
                if(!@sync_form[:sync_enabled].value || !@sync_form[:sync_posts_from_bsky].value,
                  do: "opacity-50"
                )
              ]}>
                <label class="block text-xs font-medium text-slate-600 dark:text-slate-400 mb-1">
                  Import visibility
                </label>
                <select
                  name="sync[import_visibility]"
                  disabled={
                    !@sync_form[:sync_enabled].value || !@sync_form[:sync_posts_from_bsky].value
                  }
                  class="w-48 text-sm px-2 py-1.5 rounded-md border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-sky-500 focus:border-transparent disabled:opacity-50"
                >
                  <option value="private" selected={@sync_form[:import_visibility].value == :private}>
                    🔒 Private (only you)
                  </option>
                  <option
                    value="connections"
                    selected={@sync_form[:import_visibility].value == :connections}
                  >
                    👥 Connections
                  </option>
                  <option value="public" selected={@sync_form[:import_visibility].value == :public}>
                    🌐 Public
                  </option>
                </select>
                <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                  <%= case @sync_form[:import_visibility].value do %>
                    <% :private -> %>
                      Posts are encrypted for your eyes only
                    <% :connections -> %>
                      Visible to your Mosslet connections
                    <% :public -> %>
                      Publicly visible on Mosslet
                  <% end %>
                </p>
              </div>

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
          <h4 class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-4">
            Manual Sync
          </h4>
          <div class="flex flex-wrap gap-3">
            <DesignSystem.liquid_button
              variant="secondary"
              color="blue"
              icon="hero-arrow-down-tray"
              phx-click="trigger_import"
              disabled={!@sync_form[:sync_enabled].value || !@sync_form[:sync_posts_from_bsky].value}
            >
              Import from Bluesky
            </DesignSystem.liquid_button>
            <DesignSystem.liquid_button
              variant="secondary"
              color="blue"
              icon="hero-arrow-up-tray"
              phx-click="trigger_export"
              disabled={!@sync_form[:sync_enabled].value || !@sync_form[:sync_posts_to_bsky].value}
            >
              Export Public Posts
            </DesignSystem.liquid_button>
            <DesignSystem.liquid_button
              variant="secondary"
              color="emerald"
              icon="hero-cloud-arrow-up"
              phx-click="show_export_all_modal"
              disabled={!@sync_form[:sync_enabled].value || !@sync_form[:sync_posts_to_bsky].value}
            >
              Export All Posts
            </DesignSystem.liquid_button>
          </div>
          <p class="mt-2 text-xs text-slate-500 dark:text-slate-400">
            Sync runs automatically in the background. Use these buttons to trigger an immediate sync.
          </p>
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
          Mosslet gives you full control over your Bluesky data. By connecting your account,
          you can:
        </p>

        <ul class="space-y-2">
          <li class="flex items-start gap-2">
            <.phx_icon
              name="hero-arrow-down-circle"
              class="h-5 w-5 mt-0.5 text-sky-500 flex-shrink-0"
            />
            <span>Import your Bluesky posts to Mosslet with encrypted storage</span>
          </li>
          <li class="flex items-start gap-2">
            <.phx_icon name="hero-arrow-up-circle" class="h-5 w-5 mt-0.5 text-sky-500 flex-shrink-0" />
            <span>Export your Mosslet posts to Bluesky</span>
          </li>
          <li class="flex items-start gap-2">
            <.phx_icon name="hero-trash" class="h-5 w-5 mt-0.5 text-sky-500 flex-shrink-0" />
            <span>Delete your Bluesky account after importing your posts to Mosslet</span>
          </li>
          <li class="flex items-start gap-2">
            <.phx_icon name="hero-shield-check" class="h-5 w-5 mt-0.5 text-sky-500 flex-shrink-0" />
            <span>Keep control with encrypted storage and full data portability</span>
          </li>
        </ul>

        <div class="pt-4 border-t border-slate-200 dark:border-slate-700">
          <p class="text-sm">
            <strong class="text-slate-700 dark:text-slate-300">Privacy note:</strong>
            Posts imported from Bluesky are stored encrypted on Mosslet. You can choose to make them private, visible to connections, or public.
          </p>
        </div>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  @impl true
  def handle_event("update_sync_settings", %{"sync" => params}, socket) do
    account = socket.assigns.bluesky_account

    attrs = %{
      sync_enabled: params["sync_enabled"] == "true",
      sync_posts_to_bsky: params["sync_posts_to_bsky"] == "true",
      sync_posts_from_bsky: params["sync_posts_from_bsky"] == "true",
      auto_delete_from_bsky: params["auto_delete_from_bsky"] == "true",
      import_visibility: parse_visibility(params["import_visibility"])
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

  def handle_event("trigger_import", _params, socket) do
    account = socket.assigns.bluesky_account
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case account.import_visibility do
      :public ->
        case Bluesky.Workers.ImportSyncWorker.enqueue_import(account.id) do
          {:ok, _job} ->
            {:noreply,
             socket
             |> put_flash(:success, "Import from Bluesky started. Check your timeline shortly.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to start import. Please try again.")}
        end

      _private_or_connections ->
        case ImportTask.start(account, user, key) do
          {:ok, _pid} ->
            {:noreply,
             socket
             |> assign(import_progress: %{status: :started, imported: 0, total: 0})
             |> put_flash(
               :info,
               "Import started. You can navigate away - progress will continue."
             )}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to start import. Please try again.")}
        end
    end
  end

  def handle_event("trigger_export", _params, socket) do
    account = socket.assigns.bluesky_account

    case Bluesky.Workers.ExportSyncWorker.enqueue_export(account.id) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:success, "Export to Bluesky started. Your public posts will sync shortly.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start export. Please try again.")}
    end
  end

  def handle_event("show_export_all_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(show_export_modal: true)
     |> assign(export_error: nil)
     |> assign(export_password_form: to_form(%{"password" => ""}, as: :export_password))}
  end

  def handle_event("close_export_modal", _params, socket) do
    {:noreply, assign(socket, show_export_modal: false, export_error: nil)}
  end

  def handle_event(
        "confirm_export_all",
        %{"export_password" => %{"password" => password}},
        socket
      ) do
    user = socket.assigns.current_scope.user
    account = socket.assigns.bluesky_account
    key = socket.assigns.current_scope.key

    if User.valid_password?(user, password) do
      case ExportTask.start(account, user, key) do
        {:ok, _pid} ->
          {:noreply,
           socket
           |> assign(show_export_modal: false, export_error: nil)
           |> put_flash(:info, "Export started. You can navigate away - progress will continue.")}

        {:error, _} ->
          {:noreply, assign(socket, export_error: "Failed to start export. Please try again.")}
      end
    else
      {:noreply, assign(socket, export_error: "Invalid password. Please try again.")}
    end
  end

  defp build_sync_form(nil), do: nil

  defp build_sync_form(account) do
    to_form(
      %{
        "sync_enabled" => account.sync_enabled,
        "sync_posts_to_bsky" => account.sync_posts_to_bsky,
        "sync_posts_from_bsky" => account.sync_posts_from_bsky,
        "auto_delete_from_bsky" => account.auto_delete_from_bsky,
        "import_visibility" => account.import_visibility
      },
      as: :sync
    )
  end

  defp parse_visibility("public"), do: :public
  defp parse_visibility("private"), do: :private
  defp parse_visibility("connections"), do: :connections
  defp parse_visibility(_), do: :private

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
