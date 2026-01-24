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
       export_error: nil,
       show_delete_bluesky_modal: false,
       delete_bluesky_password_form: to_form(%{"password" => ""}, as: :delete_bluesky_password),
       delete_bluesky_error: nil,
       dev_preview_mode: nil,
       expanded_sections: MapSet.new()
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
        <div class="mb-6 flex items-center gap-3 rounded-lg border border-amber-200 dark:border-amber-800/50 bg-amber-50 dark:bg-amber-900/20 px-4 py-3 max-w-3xl">
          <.phx_icon
            name="hero-wrench-screwdriver"
            class="h-5 w-5 text-amber-600 dark:text-amber-400 flex-shrink-0"
          />
          <p class="text-sm text-amber-800 dark:text-amber-200">
            <span class="font-semibold">Under Construction</span>
            — Bluesky integration is actively being developed. Some features may be incomplete, not work, or change. Reach out to us anytime at support@mosslet.com. We're excited to support comprehensive interoperability! 🦋
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

        <.dev_preview_toggle
          :if={Mosslet.config(:env) == :dev}
          bluesky_account={@bluesky_account}
          dev_preview_mode={@dev_preview_mode}
        />

        <div class="space-y-6 max-w-3xl">
          <%= if show_connected_card?(@bluesky_account, @dev_preview_mode) do %>
            <.connected_account_card
              account={preview_account(@bluesky_account, @dev_preview_mode)}
              sync_form={preview_sync_form(@sync_form, @dev_preview_mode)}
              expanded_sections={@expanded_sections}
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

      <.delete_bluesky_account_modal
        :if={@show_delete_bluesky_modal}
        delete_bluesky_password_form={@delete_bluesky_password_form}
        delete_bluesky_error={@delete_bluesky_error}
        account={@bluesky_account}
      />
    </.layout>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :expanded, :boolean, default: false
  attr :section, :atom, required: true
  attr :variant, :string, default: "default"
  slot :inner_block, required: true

  defp collapsible_section(assigns) do
    ~H"""
    <div class={[
      "border-t pt-4",
      if(@variant == "danger",
        do: "border-rose-200 dark:border-rose-800/50",
        else: "border-sky-200 dark:border-sky-700"
      )
    ]}>
      <button
        type="button"
        phx-click="toggle_section"
        phx-value-section={@section}
        class="w-full flex items-center justify-between group"
      >
        <h3 class={[
          "text-sm font-medium flex items-center gap-2",
          if(@variant == "danger",
            do: "text-rose-700 dark:text-rose-300",
            else: "text-slate-900 dark:text-slate-100"
          )
        ]}>
          <.phx_icon
            name={@icon}
            class={[
              "h-4 w-4",
              if(@variant == "danger",
                do: "text-rose-500 dark:text-rose-400",
                else: "text-sky-500 dark:text-sky-400"
              )
            ]}
          />
          {@title}
        </h3>
        <.phx_icon
          name="hero-chevron-down"
          class={[
            "h-4 w-4 transition-transform duration-200",
            if(@expanded, do: "rotate-180"),
            if(@variant == "danger",
              do: "text-rose-400 dark:text-rose-500",
              else:
                "text-slate-400 dark:text-slate-500 group-hover:text-slate-600 dark:group-hover:text-slate-300"
            )
          ]}
        />
      </button>
      <div
        id={@id}
        class={[
          "transition-all duration-200 ease-in-out",
          if(@expanded,
            do: "max-h-[32rem] overflow-y-auto opacity-100 mt-4",
            else: "max-h-0 overflow-hidden opacity-0"
          )
        ]}
      >
        {render_slot(@inner_block)}
      </div>
    </div>
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

  defp delete_bluesky_account_modal(assigns) do
    ~H"""
    <div
      id="delete-bluesky-modal"
      class="fixed inset-0 z-50 overflow-y-auto"
      aria-labelledby="delete-bluesky-modal-title"
      role="dialog"
      aria-modal="true"
    >
      <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
        <div
          class="fixed inset-0 bg-slate-900/50 dark:bg-slate-900/75 transition-opacity"
          phx-click="close_delete_bluesky_modal"
        >
        </div>

        <div class="relative transform overflow-hidden rounded-lg bg-white dark:bg-slate-800 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
          <div class="px-4 pb-4 pt-5 sm:p-6">
            <div class="sm:flex sm:items-start">
              <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-rose-100 dark:bg-rose-900/30 sm:mx-0 sm:h-10 sm:w-10">
                <.phx_icon
                  name="hero-exclamation-triangle"
                  class="h-6 w-6 text-rose-600 dark:text-rose-400"
                />
              </div>
              <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left flex-1">
                <h3
                  class="text-base font-semibold leading-6 text-slate-900 dark:text-slate-100"
                  id="delete-bluesky-modal-title"
                >
                  Permanently Delete Bluesky Account
                </h3>
                <div class="mt-2">
                  <p class="text-sm text-slate-500 dark:text-slate-400">
                    This will permanently delete your Bluesky account
                    <strong class="text-slate-700 dark:text-slate-300">
                      @{@account && @account.handle}
                    </strong>
                    from Bluesky's servers. This action cannot be undone.
                  </p>
                  <div class="mt-3 p-3 bg-rose-50 dark:bg-rose-900/20 rounded-lg border border-rose-200 dark:border-rose-700">
                    <div class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-exclamation-triangle"
                        class="h-5 w-5 text-rose-600 dark:text-rose-400 flex-shrink-0 mt-0.5"
                      />
                      <div class="text-xs text-rose-700 dark:text-rose-300 space-y-1">
                        <p><strong>This will:</strong></p>
                        <ul class="list-disc list-inside space-y-0.5">
                          <li>Delete all your posts on Bluesky</li>
                          <li>Delete your followers and following lists</li>
                          <li>Delete your Bluesky profile permanently</li>
                          <li>Make your handle available for others to claim</li>
                        </ul>
                      </div>
                    </div>
                  </div>
                  <div class="mt-3 p-3 bg-sky-50 dark:bg-sky-900/20 rounded-lg border border-sky-200 dark:border-sky-700">
                    <div class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-check-circle"
                        class="h-5 w-5 text-sky-600 dark:text-sky-400 flex-shrink-0 mt-0.5"
                      />
                      <div class="text-xs text-sky-700 dark:text-sky-300">
                        <strong>Your Mosslet account will remain intact.</strong>
                        Any posts you've imported from Bluesky will stay on Mosslet.
                      </div>
                    </div>
                  </div>
                </div>

                <%= if @delete_bluesky_error do %>
                  <div class="mt-3 p-3 bg-rose-50 dark:bg-rose-900/20 rounded-lg border border-rose-200 dark:border-rose-700">
                    <p class="text-sm text-rose-600 dark:text-rose-400">
                      <.phx_icon name="hero-exclamation-circle" class="h-4 w-4 inline" />
                      {@delete_bluesky_error}
                    </p>
                  </div>
                <% end %>

                <.form
                  id="delete-bluesky-password-form"
                  for={@delete_bluesky_password_form}
                  phx-submit="confirm_delete_bluesky_account"
                  class="mt-4"
                >
                  <div>
                    <label
                      for="delete_bluesky_password_password"
                      class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
                    >
                      Mosslet Password
                    </label>
                    <.phx_input
                      field={@delete_bluesky_password_form[:password]}
                      type="password"
                      placeholder="Enter your password to confirm"
                      class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-rose-500 focus:border-transparent"
                      autocomplete="current-password"
                    />
                  </div>

                  <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse gap-3">
                    <DesignSystem.liquid_button
                      type="submit"
                      variant="primary"
                      color="rose"
                      icon="hero-trash"
                    >
                      Delete Bluesky Account
                    </DesignSystem.liquid_button>
                    <DesignSystem.liquid_button
                      type="button"
                      variant="secondary"
                      color="slate"
                      phx-click="close_delete_bluesky_modal"
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

  defp dev_preview_toggle(assigns) do
    ~H"""
    <div class="mb-6 flex items-center gap-3 rounded-lg border border-purple-200 dark:border-purple-800/50 bg-purple-50 dark:bg-purple-900/20 px-4 py-3 max-w-3xl">
      <.phx_icon
        name="hero-beaker"
        class="h-5 w-5 text-purple-600 dark:text-purple-400 flex-shrink-0"
      />
      <div class="flex-1">
        <p class="text-sm text-purple-800 dark:text-purple-200">
          <span class="font-semibold">Dev Preview</span> — Toggle UI state for testing/a11y review
        </p>
      </div>
      <div class="flex items-center gap-2">
        <button
          type="button"
          phx-click="set_dev_preview"
          phx-value-mode=""
          class={[
            "px-2 py-1 text-xs font-medium rounded transition-colors",
            if(@dev_preview_mode == nil,
              do: "bg-purple-600 text-white",
              else:
                "bg-purple-200 dark:bg-purple-800 text-purple-700 dark:text-purple-300 hover:bg-purple-300 dark:hover:bg-purple-700"
            )
          ]}
        >
          Actual
        </button>
        <button
          type="button"
          phx-click="set_dev_preview"
          phx-value-mode="connected"
          class={[
            "px-2 py-1 text-xs font-medium rounded transition-colors",
            if(@dev_preview_mode == :connected,
              do: "bg-purple-600 text-white",
              else:
                "bg-purple-200 dark:bg-purple-800 text-purple-700 dark:text-purple-300 hover:bg-purple-300 dark:hover:bg-purple-700"
            )
          ]}
        >
          Connected
        </button>
        <button
          type="button"
          phx-click="set_dev_preview"
          phx-value-mode="disconnected"
          class={[
            "px-2 py-1 text-xs font-medium rounded transition-colors",
            if(@dev_preview_mode == :disconnected,
              do: "bg-purple-600 text-white",
              else:
                "bg-purple-200 dark:bg-purple-800 text-purple-700 dark:text-purple-300 hover:bg-purple-300 dark:hover:bg-purple-700"
            )
          ]}
        >
          Disconnected
        </button>
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
          <.form
            id="sync-settings-form"
            for={@sync_form}
            phx-change="update_sync_settings"
            class="space-y-4"
          >
            <div class={[
              "relative rounded-xl p-4 transition-all duration-200",
              if(@sync_form[:sync_enabled].value,
                do:
                  "bg-gradient-to-r from-sky-50 to-blue-50 dark:from-sky-900/30 dark:to-blue-900/20 ring-1 ring-sky-200 dark:ring-sky-700",
                else: "bg-slate-50 dark:bg-slate-800/50 ring-1 ring-slate-200 dark:ring-slate-700"
              )
            ]}>
              <label class="flex items-center justify-between cursor-pointer">
                <div class="flex items-center gap-3">
                  <div class={[
                    "flex h-9 w-9 items-center justify-center rounded-lg transition-colors duration-200",
                    if(@sync_form[:sync_enabled].value,
                      do: "bg-gradient-to-br from-sky-500 to-blue-600",
                      else: "bg-slate-300 dark:bg-slate-600"
                    )
                  ]}>
                    <.phx_icon
                      name={
                        if(@sync_form[:sync_enabled].value, do: "hero-arrow-path", else: "hero-pause")
                      }
                      class="h-5 w-5 text-white"
                    />
                  </div>
                  <div>
                    <span class="block text-sm font-semibold text-slate-900 dark:text-slate-100">
                      Bluesky Sync
                    </span>
                    <span class={[
                      "text-xs",
                      if(@sync_form[:sync_enabled].value,
                        do: "text-sky-600 dark:text-sky-400",
                        else: "text-slate-500 dark:text-slate-400"
                      )
                    ]}>
                      {if @sync_form[:sync_enabled].value,
                        do: "Active — syncing enabled",
                        else: "Paused — sync disabled"}
                    </span>
                  </div>
                </div>
                <div class="relative">
                  <input type="hidden" name="sync[sync_enabled]" value="off" />
                  <input
                    type="checkbox"
                    name="sync[sync_enabled]"
                    value="on"
                    checked={@sync_form[:sync_enabled].value}
                    class="sr-only peer"
                  />
                  <div class={[
                    "w-12 h-7 rounded-full transition-colors duration-200 peer-focus:ring-2 peer-focus:ring-sky-500 peer-focus:ring-offset-2 dark:peer-focus:ring-offset-slate-800",
                    if(@sync_form[:sync_enabled].value,
                      do: "bg-gradient-to-r from-sky-500 to-blue-600",
                      else: "bg-slate-300 dark:bg-slate-600"
                    )
                  ]}>
                  </div>
                  <div class={[
                    "absolute top-1 left-1 w-5 h-5 bg-white rounded-full shadow-md transform transition-transform duration-200",
                    if(@sync_form[:sync_enabled].value, do: "translate-x-5", else: "translate-x-0")
                  ]}>
                  </div>
                </div>
              </label>
            </div>

            <div
              id="sync-options"
              class={[
                "overflow-hidden transition-all duration-300 ease-in-out",
                if(@sync_form[:sync_enabled].value,
                  do: "max-h-[500px] opacity-100",
                  else: "max-h-0 opacity-0"
                )
              ]}
            >
              <div class="pt-2 space-y-3 pl-1">
                <p class="text-xs font-medium uppercase tracking-wide text-slate-500 dark:text-slate-400 mb-3">
                  Sync Options
                </p>

                <label class="flex items-start gap-3 cursor-pointer group">
                  <input type="hidden" name="sync[sync_posts_to_bsky]" value="off" />
                  <input
                    type="checkbox"
                    name="sync[sync_posts_to_bsky]"
                    value="on"
                    checked={@sync_form[:sync_posts_to_bsky].value}
                    class="h-4 w-4 mt-0.5 rounded border-slate-300 dark:border-slate-600 text-sky-600 focus:ring-sky-500 transition-colors"
                  />
                  <div>
                    <span class="text-sm text-slate-700 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-slate-100 transition-colors font-medium">
                      Sync Mosslet posts to Bluesky
                    </span>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                      <%= if @sync_form[:sync_posts_to_bsky].value do %>
                        Your <strong>public</strong>
                        Mosslet posts will automatically be shared to Bluesky. Private posts and posts visible only to connections are never synced.
                      <% else %>
                        When enabled, your public Mosslet posts will be shared to Bluesky automatically.
                      <% end %>
                    </p>
                  </div>
                </label>

                <label class="flex items-start gap-3 cursor-pointer group">
                  <input type="hidden" name="sync[sync_posts_from_bsky]" value="off" />
                  <input
                    type="checkbox"
                    name="sync[sync_posts_from_bsky]"
                    value="on"
                    checked={@sync_form[:sync_posts_from_bsky].value}
                    class="h-4 w-4 mt-0.5 rounded border-slate-300 dark:border-slate-600 text-sky-600 focus:ring-sky-500 transition-colors"
                  />
                  <div>
                    <span class="text-sm text-slate-700 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-slate-100 transition-colors font-medium">
                      Import posts from Bluesky
                    </span>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                      <%= if @sync_form[:sync_posts_from_bsky].value do %>
                        Your Bluesky posts will be imported to Mosslet periodically. Use the visibility setting below to control who can see them.
                      <% else %>
                        When enabled, your Bluesky posts will be imported and stored encrypted on Mosslet.
                      <% end %>
                    </p>
                  </div>
                </label>

                <div class={[
                  "ml-7 mt-2 transition-opacity duration-200",
                  if(!@sync_form[:sync_posts_from_bsky].value, do: "opacity-50 pointer-events-none")
                ]}>
                  <label
                    for="sync_import_visibility"
                    class="block text-xs font-medium text-slate-600 dark:text-slate-400 mb-1"
                  >
                    Import visibility
                  </label>
                  <select
                    id="sync_import_visibility"
                    name="sync[import_visibility]"
                    disabled={!@sync_form[:sync_posts_from_bsky].value}
                    class="w-48 text-sm px-2 py-1.5 rounded-md border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-2 focus:ring-sky-500 focus:border-transparent disabled:opacity-50"
                  >
                    <option
                      value="private"
                      selected={@sync_form[:import_visibility].value == :private}
                    >
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

                <label class="flex items-start gap-3 cursor-pointer group">
                  <input type="hidden" name="sync[auto_delete_from_bsky]" value="off" />
                  <input
                    type="checkbox"
                    name="sync[auto_delete_from_bsky]"
                    value="on"
                    checked={@sync_form[:auto_delete_from_bsky].value}
                    class="h-4 w-4 mt-0.5 rounded border-slate-300 dark:border-slate-600 text-sky-600 focus:ring-sky-500 transition-colors"
                  />
                  <div>
                    <span class="text-sm text-slate-700 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-slate-100 transition-colors font-medium">
                      Auto-delete from Bluesky when deleted on Mosslet
                    </span>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                      <%= if @sync_form[:auto_delete_from_bsky].value do %>
                        When you delete a synced post on Mosslet, it will also be removed from Bluesky.
                      <% else %>
                        When enabled, deleting a synced post on Mosslet will also delete it from Bluesky.
                      <% end %>
                    </p>
                  </div>
                </label>

                <div class="mt-4 p-3 rounded-lg bg-sky-50 dark:bg-sky-900/20 border border-sky-200 dark:border-sky-800">
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-information-circle"
                      class="h-4 w-4 text-sky-600 dark:text-sky-400 mt-0.5 shrink-0"
                    />
                    <div class="text-xs text-sky-700 dark:text-sky-300">
                      <p class="font-medium mb-1">Current sync behavior:</p>
                      <ul class="space-y-0.5 text-sky-700 dark:text-sky-300">
                        <%= if @sync_form[:sync_posts_to_bsky].value do %>
                          <li>• Public posts you create on Mosslet will appear on Bluesky</li>
                        <% end %>
                        <%= if @sync_form[:sync_posts_from_bsky].value do %>
                          <li>
                            • Bluesky posts are imported as {@sync_form[:import_visibility].value} posts on Mosslet
                          </li>
                        <% end %>
                        <%= if @sync_form[:auto_delete_from_bsky].value do %>
                          <li>• Deleting synced posts on Mosslet removes them from Bluesky</li>
                        <% end %>
                        <%= if !@sync_form[:sync_posts_to_bsky].value && !@sync_form[:sync_posts_from_bsky].value do %>
                          <li>• No automatic syncing is active. Use manual sync buttons below.</li>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </.form>
        </div>

        <.collapsible_section
          id="manual-sync"
          title="Manual Sync"
          icon="hero-arrow-path"
          expanded={MapSet.member?(@expanded_sections, :manual_sync)}
          section={:manual_sync}
        >
          <div class="flex flex-wrap gap-3">
            <DesignSystem.liquid_button
              variant="secondary"
              color="blue"
              icon="hero-arrow-down-tray"
              phx-click="trigger_import"
              disabled={!@sync_form[:sync_enabled].value}
            >
              Import from Bluesky
            </DesignSystem.liquid_button>
            <DesignSystem.liquid_button
              variant="secondary"
              color="blue"
              icon="hero-arrow-up-tray"
              phx-click="trigger_export"
              disabled={!@sync_form[:sync_enabled].value}
            >
              Export Public Posts
            </DesignSystem.liquid_button>
            <DesignSystem.liquid_button
              variant="secondary"
              color="emerald"
              icon="hero-cloud-arrow-up"
              phx-click="show_export_all_modal"
              disabled={!@sync_form[:sync_enabled].value}
            >
              Export All Posts
            </DesignSystem.liquid_button>
          </div>
          <p class="mt-3 text-xs text-slate-500 dark:text-slate-400">
            Use these buttons to trigger an immediate sync, even if automatic sync options are disabled.
          </p>
        </.collapsible_section>

        <.collapsible_section
          id="account-management"
          title="Account Management"
          icon="hero-cog-6-tooth"
          expanded={MapSet.member?(@expanded_sections, :account_management)}
          section={:account_management}
        >
          <div class="flex flex-wrap gap-3">
            <DesignSystem.liquid_button
              variant="secondary"
              color="slate"
              icon="hero-link-slash"
              phx-click="disconnect_account"
              data-confirm="Are you sure you want to disconnect your Bluesky account? Your synced posts will remain on both platforms."
            >
              Disconnect Account
            </DesignSystem.liquid_button>
          </div>
          <p class="mt-3 text-xs text-slate-500 dark:text-slate-400">
            Disconnecting removes the link between Mosslet and Bluesky. Your Bluesky account remains active.
          </p>
        </.collapsible_section>

        <.collapsible_section
          id="feature-coverage"
          title="Feature Coverage"
          icon="hero-clipboard-document-check"
          expanded={MapSet.member?(@expanded_sections, :feature_coverage)}
          section={:feature_coverage}
        >
          <div class="space-y-4">
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wide text-emerald-600 dark:text-emerald-400 mb-2 flex items-center gap-1.5">
                <.phx_icon name="hero-check-circle" class="h-4 w-4" /> Supported
              </h4>
              <ul class="space-y-1.5 text-sm text-slate-600 dark:text-slate-400">
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-emerald-500 flex-shrink-0"></span>
                  Text posts import & export
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-emerald-500 flex-shrink-0"></span>
                  Link preview cards
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-emerald-500 flex-shrink-0"></span>
                  Hashtags & mentions
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-emerald-500 flex-shrink-0"></span>
                  Likes & bookmarks import
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-emerald-500 flex-shrink-0"></span>
                  Post deletion
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-emerald-500 flex-shrink-0"></span>
                  Account deletion
                </li>
              </ul>
            </div>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wide text-sky-600 dark:text-sky-400 mb-2 flex items-center gap-1.5">
                <.phx_icon name="hero-wrench-screwdriver" class="h-4 w-4" /> Partial Support
              </h4>
              <ul class="space-y-1.5 text-sm text-slate-600 dark:text-slate-400">
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-sky-500 flex-shrink-0"></span>
                  Reply export (replies to imported Bluesky posts)
                </li>
              </ul>
            </div>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wide text-purple-600 dark:text-purple-400 mb-2 flex items-center gap-1.5">
                <.phx_icon name="hero-clock" class="h-4 w-4" /> Pending Support
              </h4>
              <ul class="space-y-1.5 text-sm text-slate-600 dark:text-slate-400">
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-purple-500 flex-shrink-0"></span>
                  Content warning sync
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-purple-500 flex-shrink-0"></span>
                  Image attachments
                </li>
              </ul>
            </div>
            <div>
              <h4 class="text-xs font-semibold uppercase tracking-wide text-amber-600 dark:text-amber-400 mb-2 flex items-center gap-1.5">
                <.phx_icon name="hero-light-bulb" class="h-4 w-4" /> Considering
              </h4>
              <ul class="space-y-1.5 text-sm text-slate-600 dark:text-slate-400">
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-amber-500 flex-shrink-0"></span>
                  Quote posts
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-amber-500 flex-shrink-0"></span>
                  Reply thread import
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-amber-500 flex-shrink-0"></span>
                  Video attachments
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-amber-500 flex-shrink-0"></span>
                  Followers & following import
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-amber-500 flex-shrink-0"></span> Reposts
                </li>
                <li class="flex items-center gap-2">
                  <span class="h-1.5 w-1.5 rounded-full bg-amber-500 flex-shrink-0"></span>
                  List management
                </li>
              </ul>
            </div>
          </div>
        </.collapsible_section>

        <.collapsible_section
          id="danger-zone"
          title="Danger Zone"
          icon="hero-exclamation-triangle"
          expanded={MapSet.member?(@expanded_sections, :danger_zone)}
          section={:danger_zone}
          variant="danger"
        >
          <p class="text-xs text-slate-600 dark:text-slate-400 mb-3">
            Permanently delete your Bluesky account. Your Mosslet account and imported posts will remain.
          </p>
          <DesignSystem.liquid_button
            variant="secondary"
            color="rose"
            icon="hero-trash"
            phx-click="show_delete_bluesky_modal"
          >
            Delete Bluesky Account
          </DesignSystem.liquid_button>
        </.collapsible_section>
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
  def handle_event("toggle_section", %{"section" => section}, socket) do
    section_atom = String.to_existing_atom(section)
    expanded = socket.assigns.expanded_sections

    expanded =
      if MapSet.member?(expanded, section_atom) do
        MapSet.delete(expanded, section_atom)
      else
        MapSet.put(expanded, section_atom)
      end

    {:noreply, assign(socket, expanded_sections: expanded)}
  end

  def handle_event("set_dev_preview", %{"mode" => mode}, socket) do
    dev_preview_mode =
      case mode do
        "connected" -> :connected
        "disconnected" -> :disconnected
        _ -> nil
      end

    sync_form =
      if dev_preview_mode == :connected and socket.assigns.sync_form == nil do
        build_dummy_sync_form()
      else
        socket.assigns.sync_form
      end

    {:noreply, assign(socket, dev_preview_mode: dev_preview_mode, sync_form: sync_form)}
  end

  @impl true
  def handle_event("update_sync_settings", params, socket) do
    account = socket.assigns.bluesky_account
    sync_params = params["sync"] || %{}

    attrs = %{
      sync_enabled: sync_params["sync_enabled"] == "on",
      sync_posts_to_bsky: sync_params["sync_posts_to_bsky"] == "on",
      sync_posts_from_bsky: sync_params["sync_posts_from_bsky"] == "on",
      auto_delete_from_bsky: sync_params["auto_delete_from_bsky"] == "on",
      import_visibility: parse_visibility(sync_params["import_visibility"])
    }

    case Bluesky.update_sync_settings(account, attrs) do
      {:ok, updated_account} ->
        {:noreply,
         socket
         |> assign(bluesky_account: updated_account)
         |> assign(sync_form: build_sync_form(updated_account))
         |> put_flash(:info, "Sync settings updated.")}

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

  def handle_event("show_delete_bluesky_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(show_delete_bluesky_modal: true)
     |> assign(delete_bluesky_error: nil)
     |> assign(
       delete_bluesky_password_form: to_form(%{"password" => ""}, as: :delete_bluesky_password)
     )}
  end

  def handle_event("close_delete_bluesky_modal", _params, socket) do
    {:noreply, assign(socket, show_delete_bluesky_modal: false, delete_bluesky_error: nil)}
  end

  def handle_event(
        "confirm_delete_bluesky_account",
        %{"delete_bluesky_password" => %{"password" => password}},
        socket
      ) do
    user = socket.assigns.current_scope.user
    account = socket.assigns.bluesky_account

    if User.valid_password?(user, password) do
      case delete_bluesky_account_on_pds(account) do
        :ok ->
          case Bluesky.delete_account(account) do
            {:ok, _} ->
              {:noreply,
               socket
               |> assign(
                 show_delete_bluesky_modal: false,
                 delete_bluesky_error: nil,
                 bluesky_account: nil,
                 sync_form: nil
               )
               |> put_flash(:success, "Your Bluesky account has been permanently deleted.")}

            {:error, _} ->
              {:noreply,
               assign(socket,
                 delete_bluesky_error:
                   "Bluesky account deleted but failed to remove local connection. Please disconnect manually."
               )}
          end

        {:error, :token_refresh_failed} ->
          {:noreply,
           assign(socket,
             delete_bluesky_error:
               "Session expired. Please disconnect and reconnect your Bluesky account first."
           )}

        {:error, reason} ->
          {:noreply,
           assign(socket,
             delete_bluesky_error: "Failed to delete Bluesky account: #{inspect(reason)}"
           )}
      end
    else
      {:noreply, assign(socket, delete_bluesky_error: "Invalid password. Please try again.")}
    end
  end

  defp delete_bluesky_account_on_pds(account) do
    alias Mosslet.Bluesky.Client

    pds_url = account.pds_url || "https://bsky.social"

    case Client.delete_bluesky_account(account.access_jwt, account.did, pds_url: pds_url) do
      :ok ->
        :ok

      {:error, {401, _}} ->
        case refresh_and_retry_delete(account, pds_url) do
          :ok -> :ok
          error -> error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp refresh_and_retry_delete(account, pds_url) do
    alias Mosslet.Bluesky.Client

    signing_key =
      case account.signing_key do
        nil -> nil
        json -> Jason.decode!(json)
      end

    refresh_result =
      if signing_key do
        Client.refresh_oauth_session(account.refresh_jwt, signing_key, pds_url: pds_url)
      else
        Client.refresh_session(account.refresh_jwt, pds_url: pds_url)
      end

    case refresh_result do
      {:ok, tokens} ->
        new_access = tokens[:access_token] || tokens[:access_jwt]

        case Client.delete_bluesky_account(new_access, account.did, pds_url: pds_url) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, _} ->
        {:error, :token_refresh_failed}
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

  defp show_connected_card?(bluesky_account, dev_preview_mode) do
    case dev_preview_mode do
      :connected -> true
      :disconnected -> false
      nil -> bluesky_account != nil
    end
  end

  defp preview_account(bluesky_account, dev_preview_mode) do
    case dev_preview_mode do
      :connected when is_nil(bluesky_account) -> build_dummy_account()
      _ -> bluesky_account
    end
  end

  defp preview_sync_form(sync_form, dev_preview_mode) do
    case dev_preview_mode do
      :connected when is_nil(sync_form) -> build_dummy_sync_form()
      _ -> sync_form
    end
  end

  defp build_dummy_account do
    %{
      handle: "preview.bsky.social",
      last_synced_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
    }
  end

  defp build_dummy_sync_form do
    to_form(
      %{
        "sync_enabled" => true,
        "sync_posts_to_bsky" => true,
        "sync_posts_from_bsky" => true,
        "auto_delete_from_bsky" => false,
        "import_visibility" => :private
      },
      as: :sync
    )
  end
end
