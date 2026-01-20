defmodule MossletWeb.BlueskySettingsLive do
  @moduledoc """
  Settings page for connecting and managing Bluesky account integration.
  """
  use MossletWeb, :live_view

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.Client
  alias Mosslet.Encrypted.Users.Utils, as: EncryptedUtils
  alias MossletWeb.DesignSystem

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    bluesky_account = Bluesky.get_account_for_user(user.id)
    decrypted_email = EncryptedUtils.decrypt_user_data(user.email, user, key)

    {:ok,
     assign(socket,
       page_title: "Settings",
       bluesky_account: bluesky_account,
       connect_form: to_form(%{"handle" => "", "app_password" => ""}, as: :connect),
       create_form:
         to_form(
           %{
             "handle" => "",
             "email" => decrypted_email,
             "password" => "",
             "password_confirmation" => "",
             "invite_code" => ""
           },
           as: :create
         ),
       sync_form: build_sync_form(bluesky_account),
       mode: :connect,
       connecting: false,
       creating: false,
       connection_error: nil,
       creation_error: nil,
       show_app_password_help: false,
       invite_code_required: nil,
       handle_status: nil,
       checking_handle: false
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
            <.mode_toggle_card mode={@mode} />

            <%= if @mode == :connect do %>
              <.connect_account_card
                connect_form={@connect_form}
                connecting={@connecting}
                connection_error={@connection_error}
                show_app_password_help={@show_app_password_help}
              />
            <% else %>
              <.create_account_card
                create_form={@create_form}
                creating={@creating}
                creation_error={@creation_error}
                invite_code_required={@invite_code_required}
                handle_status={@handle_status}
                checking_handle={@checking_handle}
              />
            <% end %>
          <% end %>

          <.about_bluesky_card />
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  defp mode_toggle_card(assigns) do
    ~H"""
    <div class="flex rounded-lg bg-slate-100 dark:bg-slate-800 p-1">
      <button
        type="button"
        phx-click="set_mode"
        phx-value-mode="connect"
        class={[
          "flex-1 px-4 py-2 text-sm font-medium rounded-md transition-all",
          if(@mode == :connect,
            do: "bg-white dark:bg-slate-700 text-sky-700 dark:text-sky-400 shadow-sm",
            else: "text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
          )
        ]}
      >
        <.phx_icon name="hero-link" class="h-4 w-4 inline mr-1.5" /> Connect Existing
      </button>
      <button
        type="button"
        phx-click="set_mode"
        phx-value-mode="create"
        class={[
          "flex-1 px-4 py-2 text-sm font-medium rounded-md transition-all",
          if(@mode == :create,
            do: "bg-white dark:bg-slate-700 text-sky-700 dark:text-sky-400 shadow-sm",
            else: "text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
          )
        ]}
      >
        <.phx_icon name="hero-plus-circle" class="h-4 w-4 inline mr-1.5" /> Create New
      </button>
    </div>
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

  defp create_account_card(assigns) do
    ~H"""
    <DesignSystem.liquid_card class="bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10">
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30">
            <.phx_icon
              name="hero-plus-circle"
              class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
            />
          </div>
          <span class="text-emerald-800 dark:text-emerald-200">Create Bluesky Account</span>
        </div>
      </:title>

      <div class="space-y-6">
        <p class="text-slate-600 dark:text-slate-400">
          Create a new Bluesky account directly from Mosslet. Your account will be created on the
          official Bluesky network and automatically connected.
        </p>

        <%= if @creation_error do %>
          <div class="bg-rose-100 dark:bg-rose-900/30 rounded-lg p-4 border border-rose-200 dark:border-rose-700">
            <div class="flex items-start gap-3">
              <.phx_icon
                name="hero-exclamation-triangle"
                class="h-5 w-5 mt-0.5 text-rose-600 dark:text-rose-400 flex-shrink-0"
              />
              <div>
                <span class="font-medium text-sm text-rose-800 dark:text-rose-200">
                  Account Creation Failed
                </span>
                <p class="text-sm text-rose-700 dark:text-rose-300 mt-1">
                  {@creation_error}
                </p>
              </div>
            </div>
          </div>
        <% end %>

        <.form
          id="create-bluesky-form"
          for={@create_form}
          phx-submit="create_account"
          phx-change="validate_create"
          class="space-y-4"
        >
          <div>
            <label
              for="create_handle"
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Choose Your Handle
            </label>
            <div class="flex">
              <div class="relative flex-1">
                <.phx_input
                  field={@create_form[:handle]}
                  type="text"
                  placeholder="yourname"
                  phx-debounce="500"
                  class={[
                    "w-full px-3 py-2 rounded-l-lg border border-r-0 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:border-transparent",
                    cond do
                      @handle_status == :available -> "border-emerald-500 focus:ring-emerald-500"
                      @handle_status == :taken -> "border-rose-500 focus:ring-rose-500"
                      true -> "border-slate-300 dark:border-slate-600 focus:ring-emerald-500"
                    end
                  ]}
                  disabled={@creating}
                />
                <%= if @checking_handle do %>
                  <div class="absolute right-2 top-1/2 -translate-y-1/2">
                    <.phx_icon name="hero-arrow-path" class="h-4 w-4 text-slate-400 animate-spin" />
                  </div>
                <% end %>
                <%= if !@checking_handle && @handle_status == :available do %>
                  <div class="absolute right-2 top-1/2 -translate-y-1/2">
                    <.phx_icon name="hero-check-circle" class="h-4 w-4 text-emerald-500" />
                  </div>
                <% end %>
                <%= if !@checking_handle && @handle_status == :taken do %>
                  <div class="absolute right-2 top-1/2 -translate-y-1/2">
                    <.phx_icon name="hero-x-circle" class="h-4 w-4 text-rose-500" />
                  </div>
                <% end %>
              </div>
              <span class="inline-flex items-center px-3 rounded-r-lg border border-l-0 border-slate-300 dark:border-slate-600 bg-slate-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300 text-sm">
                .bsky.social
              </span>
            </div>
            <%= cond do %>
              <% @handle_status == :available -> %>
                <p class="mt-1 text-xs text-emerald-600 dark:text-emerald-400">
                  <.phx_icon name="hero-check" class="h-3 w-3 inline" /> This handle is available!
                </p>
              <% @handle_status == :taken -> %>
                <p class="mt-1 text-xs text-rose-600 dark:text-rose-400">
                  <.phx_icon name="hero-x-mark" class="h-3 w-3 inline" /> This handle is already taken
                </p>
              <% @handle_status == :invalid -> %>
                <p class="mt-1 text-xs text-rose-600 dark:text-rose-400">
                  <.phx_icon name="hero-exclamation-triangle" class="h-3 w-3 inline" />
                  Handle must be 3+ characters, letters and numbers only
                </p>
              <% true -> %>
                <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                  This will be your Bluesky identity (e.g., yourname.bsky.social)
                </p>
            <% end %>
          </div>

          <div>
            <label
              for="create_email"
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Email Address
            </label>
            <.phx_input
              field={@create_form[:email]}
              type="email"
              placeholder="you@example.com"
              class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
              disabled={@creating}
            />
          </div>

          <div>
            <label
              for="create_password"
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Password
            </label>
            <.phx_input
              field={@create_form[:password]}
              type="password"
              placeholder="At least 8 characters"
              class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
              disabled={@creating}
            />
          </div>

          <div>
            <label
              for="create_password_confirmation"
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Confirm Password
            </label>
            <.phx_input
              field={@create_form[:password_confirmation]}
              type="password"
              placeholder="Confirm your password"
              class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
              disabled={@creating}
            />
          </div>

          <%= if @invite_code_required do %>
            <div>
              <label
                for="create_invite_code"
                class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
              >
                Invite Code
              </label>
              <.phx_input
                field={@create_form[:invite_code]}
                type="text"
                placeholder="bsky-social-xxxxx-xxxxx"
                class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
                disabled={@creating}
              />
              <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                Bluesky currently requires an invite code. You can get one from an existing user.
              </p>
            </div>
          <% end %>

          <div class="bg-amber-50 dark:bg-amber-900/20 rounded-lg p-4 border border-amber-200 dark:border-amber-700">
            <div class="flex items-start gap-3">
              <.phx_icon
                name="hero-shield-check"
                class="h-5 w-5 mt-0.5 text-amber-600 dark:text-amber-400 flex-shrink-0"
              />
              <div class="text-sm text-amber-700 dark:text-amber-300">
                <strong>Privacy Note:</strong>
                This creates a real Bluesky account. Your posts synced to Bluesky will be public. Posts kept only on Mosslet remain encrypted and private.
              </div>
            </div>
          </div>

          <DesignSystem.liquid_button
            type="submit"
            variant="primary"
            color="emerald"
            icon={if @creating, do: "hero-arrow-path", else: "hero-plus-circle"}
            disabled={@creating}
            class={if @creating, do: "animate-pulse"}
          >
            {if @creating, do: "Creating Account...", else: "Create Bluesky Account"}
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

  def handle_event("set_mode", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)

    socket =
      if mode == :create && socket.assigns.invite_code_required == nil do
        send(self(), :check_invite_requirement)
        socket
      else
        socket
      end

    {:noreply, assign(socket, mode: mode, connection_error: nil, creation_error: nil)}
  end

  def handle_event("validate_create", %{"create" => params}, socket) do
    handle_raw = String.trim(params["handle"] || "")
    previous_handle = socket.assigns.create_form[:handle].value || ""

    socket = assign(socket, create_form: to_form(params, as: :create))

    socket =
      if handle_raw != previous_handle && handle_raw != "" do
        if valid_handle_format?(handle_raw) do
          send(self(), {:check_handle_availability, handle_raw})
          assign(socket, checking_handle: true, handle_status: nil)
        else
          assign(socket, checking_handle: false, handle_status: :invalid)
        end
      else
        if handle_raw == "" do
          assign(socket, checking_handle: false, handle_status: nil)
        else
          socket
        end
      end

    {:noreply, socket}
  end

  def handle_event("create_account", %{"create" => params}, socket) do
    handle_raw = String.trim(params["handle"] || "")
    email = String.trim(params["email"] || "")
    password = params["password"] || ""
    password_confirmation = params["password_confirmation"] || ""
    invite_code = String.trim(params["invite_code"] || "")

    handle =
      if String.contains?(handle_raw, ".") do
        handle_raw
      else
        "#{handle_raw}.bsky.social"
      end

    cond do
      handle_raw == "" ->
        {:noreply, assign(socket, creation_error: "Please choose a handle.")}

      email == "" ->
        {:noreply, assign(socket, creation_error: "Please enter your email address.")}

      String.length(password) < 8 ->
        {:noreply, assign(socket, creation_error: "Password must be at least 8 characters.")}

      password != password_confirmation ->
        {:noreply, assign(socket, creation_error: "Passwords do not match.")}

      socket.assigns.invite_code_required && invite_code == "" ->
        {:noreply, assign(socket, creation_error: "An invite code is required.")}

      true ->
        socket = assign(socket, creating: true, creation_error: nil)
        send(self(), {:do_create_account, handle, email, password, invite_code})
        {:noreply, socket}
    end
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
  def handle_info(:check_invite_requirement, socket) do
    case Client.describe_server() do
      {:ok, %{inviteCodeRequired: true}} ->
        {:noreply, assign(socket, invite_code_required: true)}

      {:ok, _} ->
        {:noreply, assign(socket, invite_code_required: false)}

      {:error, _} ->
        {:noreply, assign(socket, invite_code_required: false)}
    end
  end

  def handle_info({:check_handle_availability, handle_raw}, socket) do
    current_handle = socket.assigns.create_form[:handle].value || ""

    if handle_raw != current_handle do
      {:noreply, socket}
    else
      full_handle =
        if String.contains?(handle_raw, ".") do
          handle_raw
        else
          "#{handle_raw}.bsky.social"
        end

      status =
        case Client.resolve_handle(full_handle) do
          {:ok, %{did: _did}} -> :taken
          {:error, {400, _}} -> :available
          {:error, _} -> :available
        end

      if socket.assigns.create_form[:handle].value == handle_raw do
        {:noreply, assign(socket, checking_handle: false, handle_status: status)}
      else
        {:noreply, socket}
      end
    end
  end

  def handle_info({:do_create_account, handle, email, password, invite_code}, socket) do
    user = socket.assigns.current_scope.user

    opts = if invite_code != "", do: [invite_code: invite_code], else: []

    case Client.create_account(handle, email, password, opts) do
      {:ok, session} ->
        attrs = %{
          did: session.did,
          handle: session.handle,
          access_jwt: session.accessJwt,
          refresh_jwt: session.refreshJwt,
          pds_url: "https://bsky.social"
        }

        case Bluesky.create_account(user, attrs) do
          {:ok, account} ->
            {:noreply,
             socket
             |> assign(bluesky_account: account)
             |> assign(sync_form: build_sync_form(account))
             |> assign(creating: false)
             |> assign(creation_error: nil)
             |> put_flash(:success, "Bluesky account created and connected successfully!")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> assign(creating: false)
             |> assign(
               creation_error:
                 "Account created but failed to save. Please try connecting with your new credentials."
             )}
        end

      {:error, {400, %{message: message}}} when is_binary(message) ->
        {:noreply,
         socket
         |> assign(creating: false)
         |> assign(creation_error: message)}

      {:error, {_, %{message: "Handle already taken"}}} ->
        {:noreply,
         socket
         |> assign(creating: false)
         |> assign(creation_error: "This handle is already taken. Please choose a different one.")}

      {:error, {_, %{error: "InvalidInviteCode"}}} ->
        {:noreply,
         socket
         |> assign(creating: false)
         |> assign(creation_error: "Invalid invite code. Please check and try again.")}

      {:error, {_status, %{message: message}}} when is_binary(message) ->
        {:noreply,
         socket
         |> assign(creating: false)
         |> assign(creation_error: message)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(creating: false)
         |> assign(creation_error: "Account creation failed. Please try again later.")}
    end
  end

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

  defp valid_handle_format?(handle) do
    String.length(handle) >= 3 &&
      Regex.match?(~r/^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$/, handle)
  end
end
