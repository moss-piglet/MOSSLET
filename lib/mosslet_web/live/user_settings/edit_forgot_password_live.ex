defmodule MossletWeb.EditForgotPasswordLive do
  @moduledoc """
  Recovery key setup page.

  Uses the RecoveryKeySetupHook for browser-side key generation:
  1. User clicks "Generate Recovery Key"
  2. Browser generates recovery key + encrypts private key backup
  3. Server stores Argon2 hash + encrypted blob
  4. Recovery key shown once to user (never stored)
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias MossletWeb.DesignSystem

  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user

    has_recovery_key? =
      is_binary(user.recovery_key_hash) and user.recovery_key_hash != ""

    # When the user is routed here to enroll a device (board #364), we must prove
    # they can still produce their recovery key BEFORE letting them delete the
    # password-only door. `confirm_for` carries the enrollment return target.
    confirm_for = if params["confirm_for"] == "device-unlock", do: "device-unlock", else: nil

    {:ok,
     assign(socket,
       page_title: "Settings",
       has_recovery_key?: has_recovery_key?,
       recovery_key_created_at: user.recovery_key_created_at,
       recovery_key_display: nil,
       recovery_key_confirmed?: false,
       generating?: false,
       confirm_for: confirm_for,
       confirming?: false,
       error_message: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:edit_forgot_password}
      sidebar_current_page={:edit_forgot_password}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Account Recovery
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Set up a recovery key to regain access if you forget your password.
            </p>
          </div>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div id="recovery-key-setup" phx-hook="RecoveryKeySetupHook" class="space-y-8 max-w-3xl">
          <%!-- Error banner --%>
          <div
            :if={@error_message}
            class="p-4 rounded-xl bg-rose-50 border border-rose-200 dark:bg-rose-900/20 dark:border-rose-800/50"
          >
            <div class="flex items-start gap-3">
              <.phx_icon
                name="hero-exclamation-triangle"
                class="w-5 h-5 text-rose-600 dark:text-rose-400 mt-0.5 flex-shrink-0"
              />
              <p class="text-sm text-rose-700 dark:text-rose-300">{@error_message}</p>
            </div>
          </div>

          <%!-- Confirm existing recovery key (routed from device-unlock, #364) --%>
          <div :if={@confirm_for == "device-unlock" && @has_recovery_key? && !@recovery_key_display}>
            <DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-3">
                  <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
                    <.phx_icon
                      name="hero-lock-closed"
                      class="h-4 w-4 text-amber-600 dark:text-amber-400"
                    />
                  </div>
                  <span>Confirm your recovery key</span>
                </div>
              </:title>

              <div class="space-y-6">
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  Enabling device unlock deletes your password-only door, so your recovery
                  key becomes your only fallback if you lose this device. Enter it below to
                  confirm you can still produce it, then continue to enrollment.
                </p>

                <form
                  id="recovery-key-confirm-form"
                  phx-hook="RecoveryKeyConfirmHook"
                  class="space-y-4"
                >
                  <div>
                    <label
                      for="confirm-recovery-key"
                      class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
                    >
                      Recovery Key
                    </label>
                    <input
                      type="text"
                      id="confirm-recovery-key"
                      name="recovery_key"
                      required
                      autocomplete="off"
                      placeholder="XXXXX-XXXXX-XXXXX-XXXXX-..."
                      class="block w-full rounded-xl border-slate-300 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 font-mono shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                    />
                  </div>
                  <button
                    type="submit"
                    id="confirm-recovery-key-btn"
                    disabled={@confirming?}
                    class={[
                      "rounded-xl py-3 px-6 text-sm font-semibold",
                      "bg-gradient-to-r from-teal-500 to-emerald-500",
                      "hover:from-teal-600 hover:to-emerald-600",
                      "text-white shadow-lg shadow-emerald-500/25",
                      "transition-all duration-200 ease-out transform-gpu",
                      "hover:scale-[1.02] active:scale-[0.98]",
                      "disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                    ]}
                  >
                    <span :if={@confirming?}>Confirming...</span>
                    <span :if={!@confirming?}>Confirm and continue</span>
                  </button>
                </form>
              </div>
            </DesignSystem.liquid_card>
          </div>

          <%!-- Recovery key display (shown once after generation) --%>
          <div :if={@recovery_key_display && !@recovery_key_confirmed?}>
            <DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-3">
                  <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
                    <.phx_icon name="hero-key" class="h-4 w-4 text-amber-600 dark:text-amber-400" />
                  </div>
                  <span>Your Recovery Key</span>
                </div>
              </:title>

              <div class="space-y-6">
                <div class="p-4 rounded-lg bg-gradient-to-br from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10 border border-amber-200 dark:border-amber-700">
                  <div class="flex items-start gap-3">
                    <.phx_icon
                      name="hero-exclamation-triangle"
                      class="h-5 w-5 mt-0.5 text-amber-600 dark:text-amber-400 flex-shrink-0"
                    />
                    <div class="space-y-2">
                      <h3 class="font-medium text-sm text-amber-800 dark:text-amber-200">
                        Write this down now — it will not be shown again
                      </h3>
                      <p class="text-sm text-amber-700 dark:text-amber-300 leading-relaxed">
                        Store this key in a safe place (password manager, printed copy in a safe, etc.).
                        You will need it to recover your account if you forget your password.
                      </p>
                    </div>
                  </div>
                </div>

                <div class="p-6 rounded-xl bg-slate-50 dark:bg-slate-800/80 border-2 border-dashed border-slate-300 dark:border-slate-600 text-center">
                  <code class="text-lg font-mono font-bold text-slate-900 dark:text-slate-100 tracking-wider select-all break-all leading-relaxed">
                    {@recovery_key_display}
                  </code>
                </div>

                <div class="flex gap-4">
                  <button
                    type="button"
                    phx-click="confirm_recovery_key"
                    class={[
                      "flex-1 rounded-xl py-3 px-6 text-sm font-semibold",
                      "bg-gradient-to-r from-teal-500 to-emerald-500",
                      "hover:from-teal-600 hover:to-emerald-600",
                      "text-white shadow-lg shadow-emerald-500/25",
                      "transition-all duration-200 ease-out transform-gpu",
                      "hover:scale-[1.02] active:scale-[0.98]"
                    ]}
                  >
                    I've saved my recovery key
                  </button>
                </div>
              </div>
            </DesignSystem.liquid_card>
          </div>

          <%!-- Success state (key confirmed) --%>
          <div :if={@recovery_key_confirmed?}>
            <DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-3">
                  <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                  </div>
                  <span>Recovery Key Active</span>
                </div>
              </:title>

              <p class="text-sm text-slate-600 dark:text-slate-400">
                Your recovery key has been set up. If you ever forget your password,
                you can use it on the login page to regain access to your account.
              </p>
            </DesignSystem.liquid_card>
          </div>

          <%!-- Current status --%>
          <div :if={!@recovery_key_display || @recovery_key_confirmed?}>
            <DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-3">
                  <div class={[
                    "relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden",
                    if(@has_recovery_key?,
                      do:
                        "bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30",
                      else:
                        "bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-900/30 dark:via-slate-800/25 dark:to-slate-900/30"
                    )
                  ]}>
                    <.phx_icon
                      name={
                        if @has_recovery_key?,
                          do: "hero-shield-check",
                          else: "hero-shield-exclamation"
                      }
                      class={[
                        "h-4 w-4",
                        if(@has_recovery_key?,
                          do: "text-emerald-600 dark:text-emerald-400",
                          else: "text-slate-500 dark:text-slate-400"
                        )
                      ]}
                    />
                  </div>
                  <span>Recovery Status</span>
                  <span class={[
                    "inline-flex px-2.5 py-0.5 text-xs rounded-lg font-medium",
                    if(@has_recovery_key?,
                      do:
                        "bg-gradient-to-r from-emerald-100 to-teal-200 text-emerald-800 dark:from-emerald-800 dark:to-teal-700 dark:text-emerald-200 border border-emerald-300 dark:border-emerald-600",
                      else:
                        "bg-gradient-to-r from-slate-100 to-slate-200 text-slate-700 dark:from-slate-700 dark:to-slate-600 dark:text-slate-300 border border-slate-300 dark:border-slate-500"
                    )
                  ]}>
                    {if @has_recovery_key?, do: "Active", else: "Not set up"}
                  </span>
                </div>
              </:title>

              <div class="space-y-4">
                <div :if={@has_recovery_key?} class="space-y-3">
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    Your recovery key is active. If you forget your password, you can use your
                    recovery key on the login page to regain access.
                  </p>
                  <p :if={@recovery_key_created_at} class="text-xs text-slate-500 dark:text-slate-500">
                    Set up {Calendar.strftime(@recovery_key_created_at, "%B %d, %Y")}
                  </p>
                </div>

                <div :if={!@has_recovery_key?}>
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    No recovery key is set up. If you forget your password, you will
                    permanently lose access to your encrypted data. We strongly recommend
                    setting up a recovery key.
                  </p>
                </div>

                <div class="flex flex-col sm:flex-row gap-3 pt-2">
                  <button
                    type="button"
                    phx-click="start_generate"
                    disabled={@generating?}
                    class={[
                      "rounded-xl py-3 px-6 text-sm font-semibold",
                      "bg-gradient-to-r from-teal-500 to-emerald-500",
                      "hover:from-teal-600 hover:to-emerald-600",
                      "text-white shadow-lg shadow-emerald-500/25",
                      "transition-all duration-200 ease-out transform-gpu",
                      "hover:scale-[1.02] active:scale-[0.98]",
                      "disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                    ]}
                  >
                    <span :if={@generating?}>Generating...</span>
                    <span :if={!@generating? && @has_recovery_key?}>Regenerate Recovery Key</span>
                    <span :if={!@generating? && !@has_recovery_key?}>Generate Recovery Key</span>
                  </button>

                  <button
                    :if={@has_recovery_key?}
                    type="button"
                    phx-click="disable_recovery"
                    data-confirm="Are you sure? Without a recovery key, forgetting your password means permanently losing access to your encrypted data."
                    class={[
                      "rounded-xl py-3 px-6 text-sm font-semibold",
                      "bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-200",
                      "border border-slate-300 dark:border-slate-600",
                      "hover:bg-slate-50 dark:hover:bg-slate-600",
                      "transition-all duration-200 ease-out"
                    ]}
                  >
                    Disable Recovery
                  </button>
                </div>
              </div>
            </DesignSystem.liquid_card>
          </div>

          <%!-- How It Works Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">How Recovery Keys Work</span>
              </div>
            </:title>

            <div class="space-y-4 text-sm text-blue-700 dark:text-blue-300">
              <p>
                Your recovery key is generated entirely in your browser. The server
                never sees the raw key — only an encrypted backup of your private key
                and a hash for verification.
              </p>
              <div class="space-y-2">
                <div class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-check-circle"
                    class="h-4 w-4 mt-0.5 text-blue-500 dark:text-blue-400 flex-shrink-0"
                  />
                  <span>The recovery key is shown once and never stored anywhere</span>
                </div>
                <div class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-check-circle"
                    class="h-4 w-4 mt-0.5 text-blue-500 dark:text-blue-400 flex-shrink-0"
                  />
                  <span>Using the recovery key consumes it — you must generate a new one after</span>
                </div>
                <div class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-check-circle"
                    class="h-4 w-4 mt-0.5 text-blue-500 dark:text-blue-400 flex-shrink-0"
                  />
                  <span>We cannot recover your data without your password or recovery key</span>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  # User clicks "Generate Recovery Key" — trigger the JS hook
  def handle_event("start_generate", _params, socket) do
    {:noreply,
     socket
     |> assign(generating?: true, error_message: nil)
     |> push_event("generate_recovery_key", %{})}
  end

  # JS hook generated the key and sent the encrypted data
  def handle_event(
        "recovery_key_generated",
        %{
          "recovery_secret" => recovery_secret,
          "encrypted_recovery_private_key" => encrypted_recovery_private_key,
          "recovery_key_display" => recovery_key_display
        },
        socket
      ) do
    user = socket.assigns.current_scope.user

    case Accounts.setup_recovery_key(user, recovery_secret, encrypted_recovery_private_key) do
      {:ok, _user} ->
        {:noreply,
         assign(socket,
           generating?: false,
           has_recovery_key?: true,
           recovery_key_display: recovery_key_display,
           recovery_key_confirmed?: false,
           recovery_key_created_at: DateTime.utc_now(),
           error_message: nil
         )}

      {:error, _changeset} ->
        {:noreply,
         assign(socket,
           generating?: false,
           error_message: "Failed to save recovery key. Please try again."
         )}
    end
  end

  # JS hook reported an error
  def handle_event("recovery_key_error", %{"error" => error}, socket) do
    {:noreply, assign(socket, generating?: false, error_message: error)}
  end

  # --- Confirm existing recovery key (routed from device-unlock, #364) ------

  # RecoveryKeyConfirmHook converted the typed recovery key to its raw secret.
  # We Argon2-verify it against the stored hash (I6: server only ever verifies,
  # never persists the secret), and on success mint a short-lived confirmation
  # token and continue to device-unlock enrollment.
  def handle_event("verify_recovery_secret", %{"recovery_secret" => secret}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.verify_recovery_secret(user, secret) do
      :ok ->
        token = Accounts.sign_recovery_confirmation(user)

        {:noreply,
         socket
         |> assign(confirming?: false, error_message: nil)
         |> push_navigate(to: ~p"/app/users/device-unlock?#{[rc: token]}")}

      :error ->
        {:noreply,
         assign(socket,
           confirming?: false,
           error_message: "That recovery key didn't match. Please check it and try again."
         )}
    end
  end

  def handle_event("recovery_confirm_error", %{"error" => error}, socket) do
    {:noreply, assign(socket, confirming?: false, error_message: error)}
  end

  # User confirms they've saved the recovery key
  def handle_event("confirm_recovery_key", _params, socket) do
    user = socket.assigns.current_scope.user

    # A freshly-generated key was just shown to (and saved by) the user this
    # session — possession is proven. If they were routed here to enroll a
    # device (#364), mint the confirmation token and continue to enrollment.
    if socket.assigns.confirm_for == "device-unlock" do
      token = Accounts.sign_recovery_confirmation(user)

      {:noreply,
       socket
       |> assign(recovery_key_confirmed?: true, recovery_key_display: nil)
       |> push_navigate(to: ~p"/app/users/device-unlock?#{[rc: token]}")}
    else
      {:noreply,
       socket
       |> assign(recovery_key_confirmed?: true, recovery_key_display: nil)
       |> put_flash(:success, "Recovery key has been set up successfully.")}
    end
  end

  # User wants to disable recovery
  def handle_event("disable_recovery", _params, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.clear_recovery_key(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(
           has_recovery_key?: false,
           recovery_key_display: nil,
           recovery_key_confirmed?: false,
           recovery_key_created_at: nil
         )
         |> put_flash(:success, "Recovery key has been removed.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to disable recovery. Please try again.")}
    end
  end
end
