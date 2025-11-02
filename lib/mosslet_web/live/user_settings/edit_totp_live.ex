defmodule MossletWeb.EditTotpLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias MossletWeb.DesignSystem

  @qrcode_size 264

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(backup_codes: nil, current_password: nil)
      |> reset_assigns(Accounts.get_user_totp(socket.assigns.current_user))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout current_user={@current_user} current_page={:edit_totp} key={@key} type="sidebar">
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              2FA Security
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Enhance your account security with two-factor authentication.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-2xl">
          <%!-- 2FA Status Card --%>
          <%= if @current_totp do %>
            <DesignSystem.liquid_card class="bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10">
              <:title>
                <div class="flex items-center gap-3">
                  <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30">
                    <.phx_icon
                      name="hero-check-badge"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                  </div>
                  <span class="text-emerald-800 dark:text-emerald-200">2FA Enabled</span>
                </div>
              </:title>

              <div class="space-y-4">
                <p class="text-emerald-700 dark:text-emerald-300">
                  Your account is protected with two-factor authentication. To view your backup codes or change your 2FA device, enter your password in the form below.
                </p>
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                  <span class="text-sm text-emerald-600 dark:text-emerald-400">
                    Keep your backup codes safe for emergency access
                  </span>
                </div>
              </div>
            </DesignSystem.liquid_card>
          <% end %>

          <%!-- Security Benefits Card --%>
          <%= if !@current_totp do %>
            <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
              <:title>
                <div class="flex items-center gap-3">
                  <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                    <.phx_icon
                      name="hero-shield-check"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                  </div>
                  <span class="text-blue-800 dark:text-blue-200">Enhanced Security</span>
                </div>
              </:title>

              <div class="space-y-4">
                <p class="text-blue-700 dark:text-blue-300">
                  Two-factor authentication adds an extra layer of security to your account by requiring a second form of verification.
                </p>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="space-y-2">
                    <div class="flex items-center gap-2">
                      <.phx_icon
                        name="hero-check-circle"
                        class="h-4 w-4 text-blue-600 dark:text-blue-400"
                      />
                      <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                        Prevents unauthorized access
                      </span>
                    </div>
                  </div>
                  <div class="space-y-2">
                    <div class="flex items-center gap-2">
                      <.phx_icon
                        name="hero-check-circle"
                        class="h-4 w-4 text-blue-600 dark:text-blue-400"
                      />
                      <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                        Works with any TOTP app
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </DesignSystem.liquid_card>
          <% end %>

          <%!-- Main 2FA Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/30 dark:via-emerald-900/25 dark:to-teal-900/30">
                  <.phx_icon
                    name="hero-device-phone-mobile"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                </div>
                <span>Two-Factor Authentication</span>
              </div>
            </:title>

            <.backup_codes
              :if={@backup_codes}
              id="backup-codes-component"
              backup_codes={@backup_codes}
              editing_totp={@editing_totp}
            />

            <%= if @editing_totp do %>
              <.totp_form
                totp_form={@totp_form}
                current_totp={@current_totp}
                secret_display={@secret_display}
                qrcode_uri={@qrcode_uri}
                editing_totp={@editing_totp}
              />
            <% else %>
              <.enable_form
                current_totp={@current_totp}
                user_form={@user_form}
                current_password={@current_password}
              />
            <% end %>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  def totp_form(assigns) do
    ~H"""
    <div class="space-y-8">
      <%!-- Instructions Card --%>
      <DesignSystem.liquid_card class="bg-gradient-to-br from-purple-50/50 to-violet-50/30 dark:from-purple-900/20 dark:to-violet-900/10">
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
              <.phx_icon
                name="hero-information-circle"
                class="h-4 w-4 text-purple-600 dark:text-purple-400"
              />
            </div>
            <span class="text-purple-800 dark:text-purple-200">Setup Instructions</span>
          </div>
        </:title>

        <div class="space-y-4">
          <%= if @secret_display == :as_text do %>
            <p class="text-purple-700 dark:text-purple-300">
              To {if @current_totp, do: "change", else: "enable"} two-factor authentication, enter the secret below into your two-factor authentication app.
            </p>

            <div class="flex items-center justify-center py-6">
              <div class="p-6 border-2 border-dashed border-purple-300 dark:border-purple-600 rounded-xl bg-purple-50/50 dark:bg-purple-900/20">
                <div
                  class="text-xl font-mono font-bold text-purple-800 dark:text-purple-200 text-center tracking-wider"
                  id="totp-secret"
                >
                  {format_secret(@editing_totp.secret)}
                </div>
              </div>
            </div>

            <div class="flex items-center justify-center">
              <DesignSystem.liquid_button
                variant="ghost"
                color="purple"
                size="sm"
                icon="hero-qr-code"
                phx-click="display_secret_as_qrcode"
              >
                Show QR Code Instead
              </DesignSystem.liquid_button>
            </div>
          <% else %>
            <p class="text-purple-700 dark:text-purple-300">
              To {if @current_totp, do: "change", else: "enable"} two-factor authentication, scan the QR code below with your authenticator app, then enter the verification code.
            </p>

            <div class="flex justify-center py-6">
              <div class="p-4 bg-white dark:bg-slate-800 rounded-xl border border-purple-200 dark:border-purple-700 shadow-lg">
                {generate_qrcode(@qrcode_uri)}
              </div>
            </div>

            <div class="flex items-center justify-center">
              <DesignSystem.liquid_button
                variant="ghost"
                color="purple"
                size="sm"
                icon="hero-key"
                phx-click="display_secret_as_text"
              >
                Enter Secret Manually
              </DesignSystem.liquid_button>
            </div>
          <% end %>
        </div>
      </DesignSystem.liquid_card>

      <%!-- Verification Form --%>
      <.form for={@totp_form} id="form-update-totp" phx-submit="update_totp" class="space-y-6">
        <%!-- Authentication Code Input --%>
        <div class="space-y-3">
          <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
            Authentication Code <span class="text-rose-500 ml-1">*</span>
          </label>

          <div class="group relative">
            <%!-- Enhanced liquid background effect on focus --%>
            <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl">
            </div>

            <%!-- Enhanced shimmer effect on focus --%>
            <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
            </div>

            <%!-- Focus ring with liquid metal styling --%>
            <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
            </div>

            <%!-- Secondary focus ring for better definition --%>
            <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
            </div>

            <input
              type="text"
              id="user_totp_code"
              name="user_totp[code]"
              required
              autocomplete="one-time-code"
              inputmode="numeric"
              pattern="[0-9]{6}"
              maxlength="6"
              class={[
                "relative block w-full rounded-xl px-4 py-3 text-slate-900 dark:text-slate-100",
                "bg-slate-50 dark:bg-slate-900 placeholder:text-slate-500 dark:placeholder:text-slate-400",
                "border-2 border-slate-200 dark:border-slate-700",
                "hover:border-slate-300 dark:hover:border-slate-600",
                "focus:border-emerald-500 dark:focus:border-emerald-400",
                "focus:outline-none focus:ring-0",
                "transition-all duration-200 ease-out",
                "text-center text-2xl font-mono tracking-widest",
                "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
                "focus:bg-white dark:focus:bg-slate-800"
              ]}
              placeholder="123456"
              value={@totp_form[:code].value}
            />
          </div>

          <p class="text-sm text-slate-600 dark:text-slate-400 text-center">
            Enter the 6-digit code from your authenticator app
          </p>
        </div>

        <%!-- Action buttons --%>
        <div class="flex flex-col sm:flex-row justify-between gap-4 pt-4">
          <DesignSystem.liquid_button
            type="button"
            variant="ghost"
            color="slate"
            phx-click="cancel_totp"
            icon="hero-x-mark"
          >
            Cancel
          </DesignSystem.liquid_button>

          <DesignSystem.liquid_button
            id={if @current_totp, do: "verify-update-button", else: "verify-enable-button"}
            type="submit"
            phx-disable-with="Verifying..."
            icon="hero-shield-check"
          >
            Verify & {if @current_totp, do: "Update", else: "Enable"}
          </DesignSystem.liquid_button>
        </div>
      </.form>

      <%!-- Additional Options for Existing 2FA --%>
      <%= if @current_totp do %>
        <DesignSystem.liquid_card class="bg-gradient-to-br from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10">
          <:title>
            <div class="flex items-center gap-3">
              <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
                <.phx_icon
                  name="hero-cog-6-tooth"
                  class="h-4 w-4 text-amber-600 dark:text-amber-400"
                />
              </div>
              <span class="text-amber-800 dark:text-amber-200">Additional Options</span>
            </div>
          </:title>

          <div class="space-y-4">
            <p class="text-amber-700 dark:text-amber-300">
              Manage your two-factor authentication settings and backup codes.
            </p>
            <div class="flex flex-col sm:flex-row gap-3">
              <DesignSystem.liquid_button
                variant="secondary"
                color="amber"
                size="sm"
                icon="hero-key"
                phx-click="show_backup_codes"
              >
                View Backup Codes
              </DesignSystem.liquid_button>
              <DesignSystem.liquid_button
                variant="ghost"
                color="rose"
                size="sm"
                icon="hero-shield-exclamation"
                phx-click="disable_totp"
                data-confirm="Are you sure you want to disable Two-factor authentication? This will make your account less secure."
              >
                Disable 2FA
              </DesignSystem.liquid_button>
            </div>
          </div>
        </DesignSystem.liquid_card>
      <% end %>
    </div>
    """
  end

  def enable_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Information Section --%>
      <div class="space-y-4">
        <p class="text-slate-700 dark:text-slate-300">
          <%= if @current_totp do %>
            Enter your current password to change your 2FA device, view your backup codes, or generate new backup codes (which will invalidate your current ones).
          <% else %>
            Enter your current password to enable two-factor authentication and secure your account.
          <% end %>
        </p>
      </div>

      <.form
        id="form-submit-totp"
        for={@user_form}
        phx-submit="submit_totp"
        phx-change="change_totp"
        class="space-y-6"
      >
        <%!-- Current Password Section --%>
        <div class="space-y-3">
          <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
            Current Password <span class="text-rose-500 ml-1">*</span>
          </label>

          <div class="group relative">
            <%!-- Enhanced liquid background effect on focus --%>
            <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl">
            </div>

            <%!-- Enhanced shimmer effect on focus --%>
            <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
            </div>

            <%!-- Focus ring with liquid metal styling --%>
            <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
            </div>

            <%!-- Secondary focus ring for better definition --%>
            <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
            </div>

            <%!-- Password input with show/hide functionality --%>
            <input
              type="password"
              id="user_current_password_2fa"
              name="user[current_password]"
              required
              autocomplete="current-password"
              class={[
                "relative block w-full rounded-xl px-4 py-3 pr-12 text-slate-900 dark:text-slate-100",
                "bg-slate-50 dark:bg-slate-900 placeholder:text-slate-500 dark:placeholder:text-slate-400",
                "border-2 border-slate-200 dark:border-slate-700",
                "hover:border-slate-300 dark:hover:border-slate-600",
                "focus:border-emerald-500 dark:focus:border-emerald-400",
                "focus:outline-none focus:ring-0",
                "transition-all duration-200 ease-out",
                "sm:text-sm sm:leading-6",
                "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
                "focus:bg-white dark:focus:bg-slate-800"
              ]}
              placeholder="Enter your current password"
              value={@current_password}
            />

            <%!-- Show/Hide password buttons with liquid styling --%>
            <div class="absolute inset-y-0 right-0 flex items-center pr-3">
              <button
                type="button"
                id="eye-2fa-password"
                data-tippy-content="Show password"
                phx-hook="TippyHook"
                class="group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                phx-click={
                  JS.set_attribute({"type", "text"}, to: "#user_current_password_2fa")
                  |> JS.remove_class("hidden", to: "#eye-slash-2fa-password")
                  |> JS.add_class("hidden", to: "#eye-2fa-password")
                }
              >
                <.phx_icon
                  name="hero-eye"
                  class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                />
              </button>
              <button
                type="button"
                id="eye-slash-2fa-password"
                data-tippy-content="Hide password"
                phx-hook="TippyHook"
                class="hidden group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                phx-click={
                  JS.set_attribute({"type", "password"}, to: "#user_current_password_2fa")
                  |> JS.add_class("hidden", to: "#eye-slash-2fa-password")
                  |> JS.remove_class("hidden", to: "#eye-2fa-password")
                }
              >
                <.phx_icon
                  name="hero-eye-slash"
                  class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                />
              </button>
            </div>
          </div>
        </div>

        <%!-- Submit Button --%>
        <div class="flex justify-end pt-4">
          <DesignSystem.liquid_button
            type="submit"
            phx-disable-with="Verifying..."
            icon="hero-shield-check"
          >
            {if @current_totp, do: "Change 2FA Device", else: "Enable 2FA"}
          </DesignSystem.liquid_button>
        </div>
      </.form>
    </div>
    """
  end

  def backup_codes(assigns) do
    ~H"""
    <DesignSystem.liquid_modal
      id="backup-codes-modal"
      show={@backup_codes != nil}
      on_cancel={Phoenix.LiveView.JS.push("hide_backup_codes")}
    >
      <:title>Backup Codes</:title>

      <div class="space-y-6">
        <%!-- Information Card --%>
        <DesignSystem.liquid_card class="bg-gradient-to-br from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10">
          <:title>
            <div class="flex items-center gap-3">
              <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
                <.phx_icon
                  name="hero-exclamation-triangle"
                  class="h-4 w-4 text-amber-600 dark:text-amber-400"
                />
              </div>
              <span class="text-amber-800 dark:text-amber-200">Important Information</span>
            </div>
          </:title>

          <div class="space-y-3">
            <p class="text-amber-700 dark:text-amber-300">
              Two-factor authentication is enabled. In case you lose access to your phone, you will need one of the backup codes below.
            </p>
            <p class="text-sm font-semibold text-amber-800 dark:text-amber-200">
              ⚠️ Keep these backup codes safe and secure. You can generate new codes at any time.
            </p>
          </div>
        </DesignSystem.liquid_card>

        <%!-- Backup Codes Grid --%>
        <div class="space-y-4">
          <h4 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            Your Backup Codes
          </h4>
          <div id="backup-codes-list" class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <%= for backup_code <- @backup_codes do %>
              <div class={[
                "flex items-center justify-center p-4 rounded-xl border-2 transition-colors duration-200",
                if(backup_code.used_at,
                  do: "bg-slate-100 dark:bg-slate-800 border-slate-300 dark:border-slate-600",
                  else:
                    "bg-emerald-50 dark:bg-emerald-900/20 border-emerald-200 dark:border-emerald-700"
                )
              ]}>
                <div class={[
                  "font-mono text-lg font-bold text-center tracking-wider",
                  if(backup_code.used_at,
                    do: "text-slate-500 dark:text-slate-400 line-through",
                    else: "text-emerald-700 dark:text-emerald-300"
                  )
                ]}>
                  {backup_code.code}
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Action Buttons --%>
        <div class="flex flex-col items-center gap-4 pt-6">
          <%!-- Copy to Clipboard Button --%>
          <DesignSystem.liquid_button
            type="button"
            variant="primary"
            color="blue"
            icon="hero-clipboard-document-list"
            id="copy-backup-codes-btn"
            data-clipboard-copy={JS.push("clipcopy")}
            data-copy-text={
              Enum.map(@backup_codes, fn code -> if code.used_at, do: nil, else: code.code end)
              |> Enum.filter(& &1)
              |> Enum.join(" ")
            }
            phx-click={JS.dispatch("phx:clipcopy", to: "#copy-backup-codes-btn")}
          >
            Copy All Codes
          </DesignSystem.liquid_button>

          <%!-- Regenerate Codes Button (if editing) --%>
          <%= if @editing_totp do %>
            <DesignSystem.liquid_button
              type="button"
              variant="secondary"
              color="amber"
              size="sm"
              icon="hero-arrow-path"
              phx-click="regenerate_backup_codes"
              data-confirm="Are you sure? This will generate new backup codes and invalidate the old ones."
            >
              Regenerate Codes
            </DesignSystem.liquid_button>
          <% end %>
        </div>
      </div>
    </DesignSystem.liquid_modal>
    """
  end

  @impl true
  def handle_event("clipcopy", _, socket) do
    fun_emojis = ["🎉", "✨", "🚀", "💫", "⭐", "🌟", "🎊", "💯", "🔥", "🎯"]
    emoji = Enum.random(fun_emojis)

    {:noreply,
     socket
     |> put_flash(:info, "Backup codes copied to clipboard successfully! #{emoji}")}
  end

  def handle_event("show_backup_codes", _, socket) do
    backup_codes =
      case socket.assigns.editing_totp do
        nil -> socket.assigns.current_totp.backup_codes
        editing_totp -> editing_totp.backup_codes
      end

    {:noreply, assign(socket, :backup_codes, backup_codes)}
  end

  @impl true
  def handle_event("hide_backup_codes", _, socket) do
    {:noreply, assign(socket, :backup_codes, nil)}
  end

  @impl true
  def handle_event("regenerate_backup_codes", _, socket) do
    {:ok, totp} = Accounts.regenerate_user_totp_backup_codes(socket.assigns.editing_totp)

    # Ensure consistent state by updating both backup_codes and editing_totp
    # and temporarily hide/show the modal to force a clean re-render
    socket =
      socket
      # Hide modal first
      |> assign(:backup_codes, nil)
      |> assign(:editing_totp, totp)

    # Use send/2 to schedule showing the modal again after a brief delay
    Process.send_after(self(), :show_regenerated_codes, 50)

    # Removed totp.regenerate_backup_codes logging - not security essential

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_totp", %{"user_totp" => params}, socket) do
    editing_totp = socket.assigns.editing_totp
    # Only log enable, not update
    log_type = if is_nil(editing_totp.id), do: "totp.enable", else: nil

    case Accounts.upsert_user_totp(editing_totp, params) do
      {:ok, current_totp} ->
        if log_type do
          Mosslet.Logs.log_async(log_type, %{user: socket.assigns.current_user})
        end

        {:noreply,
         socket
         |> reset_assigns(current_totp)
         |> assign(:backup_codes, current_totp.backup_codes)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:warning, "The code you entered is incorrect. Please try again.")
         |> assign(totp_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("disable_totp", _, socket) do
    Accounts.delete_user_totp(socket.assigns.editing_totp)
    Mosslet.Logs.log_async("totp.disable", %{user: socket.assigns.current_user})
    {:noreply, reset_assigns(socket, nil)}
  end

  @impl true
  def handle_event("display_secret_as_qrcode", _, socket) do
    {:noreply, assign(socket, :secret_display, :as_qrcode)}
  end

  @impl true
  def handle_event("display_secret_as_text", _, socket) do
    {:noreply, assign(socket, :secret_display, :as_text)}
  end

  @impl true
  def handle_event("change_totp", %{"user" => %{"current_password" => current_password}}, socket) do
    {:noreply, assign_user_form(socket, current_password)}
  end

  @impl true
  def handle_event("submit_totp", %{"user" => %{"current_password" => current_password}}, socket) do
    socket = assign_user_form(socket, current_password)

    if socket.assigns.user_form.source.valid? do
      user = socket.assigns.current_user
      editing_totp = socket.assigns.current_totp || %Accounts.UserTOTP{user_id: user.id}
      app = Mosslet.config(:app_name)
      secret = NimbleTOTP.secret()
      qrcode_uri = NimbleTOTP.otpauth_uri("#{app}:#{user.email}", secret, issuer: app)

      editing_totp = %{editing_totp | secret: secret}
      totp_form = editing_totp |> Accounts.change_user_totp() |> to_form()

      socket =
        socket
        |> assign(:editing_totp, editing_totp)
        |> assign(:totp_form, totp_form)
        |> assign(:qrcode_uri, qrcode_uri)

      {:noreply, socket}
    else
      # Show warning flash when password validation fails and reassign form to maintain state
      {:noreply,
       socket
       |> put_flash(:warning, "The password you entered is incorrect. Please try again.")}

      # |> assign_user_form(current_password)}
    end
  end

  @impl true
  def handle_event("submit_totp", _params, socket) do
    # Handle other submit_totp events that don't match the expected pattern
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_totp", _, socket) do
    {:noreply, reset_assigns(socket, socket.assigns.current_totp)}
  end

  @impl true
  def handle_info(:show_regenerated_codes, socket) do
    # Show the modal again with the new codes
    {:noreply, assign(socket, :backup_codes, socket.assigns.editing_totp.backup_codes)}
  end

  defp reset_assigns(socket, totp) do
    socket
    |> assign(:current_totp, totp)
    |> assign(:secret_display, :as_qrcode)
    |> assign(:editing_totp, nil)
    |> assign(:totp_form, nil)
    |> assign(:qrcode_uri, nil)
    |> assign_user_form(nil)
  end

  defp assign_user_form(socket, current_password) do
    user = socket.assigns.current_user
    user_form = user |> Accounts.validate_user_current_password(current_password) |> to_form()

    socket
    |> assign(:current_password, current_password)
    |> assign(:user_form, user_form)
  end

  defp generate_qrcode(uri) do
    uri
    |> EQRCode.encode()
    |> EQRCode.svg(width: @qrcode_size)
    |> raw()
  end

  defp format_secret(secret) do
    secret
    |> Base.encode32(padding: false)
    |> String.graphemes()
    |> Enum.map(&maybe_highlight_digit/1)
    |> Enum.chunk_every(4)
    |> Enum.intersperse(" ")
    |> raw()
  end

  defp maybe_highlight_digit(char) do
    case Integer.parse(char) do
      :error -> char
      _ -> ~s(<span class="text-primary-600 dark:text-primary-400">#{char}</span>)
    end
  end
end
