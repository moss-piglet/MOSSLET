defmodule MossletWeb.EditDeviceUnlockLive do
  @moduledoc """
  Device unlock (WebAuthn PRF) settings — board #362 phase (c) / #365.

  Lets a user opt in to binding `user_key` to a device's secure enclave via the
  WebAuthn PRF extension, flipping the unlock gate from OR (password) to AND
  (password AND enrolled device). See `docs/WEBAUTHN_PRF_DESIGN.md`.

  Enrollment is HARD-GATED on a confirmed recovery key (design §4 / #364): once
  the password-only wrap is deleted, the 256-bit recovery code is the only
  device-loss fallback. The enroll CTA is hidden/disabled unless
  `recovery_key_hash` is present.

  All crypto happens in `PrfEnrollmentHook`; this LiveView only ever receives
  and stores OPAQUE blobs (invariant I6).
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(
       page_title: "Settings",
       error_message: nil,
       working?: false
     )
     |> assign_wrap_state(user)}
  end

  defp assign_wrap_state(socket, user) do
    has_recovery_key? =
      is_binary(user.recovery_key_hash) and user.recovery_key_hash != ""

    wraps = Accounts.list_user_key_wraps(user)
    prf_wraps = Enum.filter(wraps, &(&1.kind == :prf))

    assign(socket,
      has_recovery_key?: has_recovery_key?,
      prf_enrolled?: prf_wraps != [],
      prf_wraps: prf_wraps
    )
  end

  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:edit_device_unlock}
      sidebar_current_page={:edit_device_unlock}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Device Unlock
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Bind your account to this device with a passkey, so unlocking requires
              your password <span class="font-semibold">and</span> this device.
            </p>
          </div>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div
          id="prf-device-unlock"
          phx-hook="PrfEnrollmentHook"
          class="space-y-8 max-w-3xl"
        >
          <%!-- Error banner --%>
          <div
            :if={@error_message}
            id="prf-error"
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

          <%!-- Recovery-key gate notice --%>
          <div
            :if={!@has_recovery_key?}
            id="prf-recovery-gate"
            class="p-4 rounded-xl bg-amber-50 border border-amber-200 dark:bg-amber-900/20 dark:border-amber-800/50"
          >
            <div class="flex items-start gap-3">
              <.phx_icon
                name="hero-shield-exclamation"
                class="w-5 h-5 text-amber-600 dark:text-amber-400 mt-0.5 flex-shrink-0"
              />
              <div class="space-y-2 text-sm text-amber-700 dark:text-amber-300">
                <p class="font-medium text-amber-800 dark:text-amber-200">
                  Set up a recovery key first
                </p>
                <p>
                  Device unlock deletes your password-only door. Your recovery key is
                  the only fallback if you lose this device, so you must set one up
                  before enabling device unlock.
                </p>
                <.link
                  navigate={~p"/app/users/change-forgot-password"}
                  class="inline-flex font-semibold text-amber-800 dark:text-amber-200 underline"
                >
                  Go to Account Recovery
                </.link>
              </div>
            </div>
          </div>

          <%!-- Status card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class={[
                  "relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden",
                  if(@prf_enrolled?,
                    do:
                      "bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30",
                    else:
                      "bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-900/30 dark:via-slate-800/25 dark:to-slate-900/30"
                  )
                ]}>
                  <.phx_icon
                    name="hero-finger-print"
                    class={[
                      "h-4 w-4",
                      if(@prf_enrolled?,
                        do: "text-emerald-600 dark:text-emerald-400",
                        else: "text-slate-500 dark:text-slate-400"
                      )
                    ]}
                  />
                </div>
                <span>Device Unlock</span>
                <span class={[
                  "inline-flex px-2.5 py-0.5 text-xs rounded-lg font-medium",
                  if(@prf_enrolled?,
                    do:
                      "bg-gradient-to-r from-emerald-100 to-teal-200 text-emerald-800 dark:from-emerald-800 dark:to-teal-700 dark:text-emerald-200 border border-emerald-300 dark:border-emerald-600",
                    else:
                      "bg-gradient-to-r from-slate-100 to-slate-200 text-slate-700 dark:from-slate-700 dark:to-slate-600 dark:text-slate-300 border border-slate-300 dark:border-slate-500"
                  )
                ]}>
                  {if @prf_enrolled?, do: "Enabled", else: "Not enabled"}
                </span>
              </div>
            </:title>

            <div class="space-y-6">
              <%!-- Enrolled device list --%>
              <div :if={@prf_enrolled?} class="space-y-3">
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  Unlocking this account now requires your password and an enrolled
                  device (or your recovery key).
                </p>
                <ul id="prf-device-list" class="divide-y divide-slate-200 dark:divide-slate-700">
                  <li
                    :for={wrap <- @prf_wraps}
                    id={"prf-wrap-#{wrap.id}"}
                    class="flex items-center justify-between py-3"
                  >
                    <div class="flex items-center gap-3">
                      <.phx_icon
                        name="hero-finger-print"
                        class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
                      />
                      <div>
                        <p class="text-sm font-medium text-slate-800 dark:text-slate-200">
                          {ecosystem_label(wrap.ecosystem_hint)}
                        </p>
                        <p class="text-xs text-slate-500 dark:text-slate-500">
                          Enrolled {Calendar.strftime(wrap.inserted_at, "%B %d, %Y")}
                        </p>
                      </div>
                    </div>
                    <button
                      type="button"
                      id={"prf-remove-#{wrap.id}"}
                      phx-click="start_unenroll"
                      phx-value-id={wrap.id}
                      disabled={@working?}
                      data-confirm="Remove this device? If it's the last one, your account returns to password-only unlock."
                      class="rounded-lg py-1.5 px-3 text-xs font-semibold text-rose-700 dark:text-rose-300 border border-rose-200 dark:border-rose-800 hover:bg-rose-50 dark:hover:bg-rose-900/20 transition-colors disabled:opacity-50"
                    >
                      Remove
                    </button>
                  </li>
                </ul>
              </div>

              <div :if={!@prf_enrolled?}>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  Device unlock is not enabled. Your account currently unlocks with your
                  password alone. Enabling it makes a stolen password insufficient on its
                  own.
                </p>
              </div>

              <%!-- Password confirm + CTA --%>
              <div class="space-y-3 pt-2">
                <label
                  for="prf_password"
                  class="block text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  Confirm your password
                </label>
                <input
                  type="password"
                  name="prf_password"
                  id="prf_password"
                  autocomplete="current-password"
                  placeholder="Your account password"
                  class="block w-full rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 shadow-sm focus:border-emerald-500 focus:ring-emerald-500 sm:text-sm"
                />

                <div class="flex flex-col sm:flex-row gap-3 pt-2">
                  <button
                    :if={!@prf_enrolled?}
                    type="button"
                    id="prf-enroll-btn"
                    phx-click="start_enroll"
                    disabled={!@has_recovery_key? || @working?}
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
                    <span :if={@working?}>Enabling...</span>
                    <span :if={!@working?}>Enable device unlock</span>
                  </button>

                  <button
                    :if={@prf_enrolled?}
                    type="button"
                    id="prf-add-device-btn"
                    phx-click="start_enroll"
                    disabled={@working?}
                    class={[
                      "rounded-xl py-3 px-6 text-sm font-semibold",
                      "bg-gradient-to-r from-teal-500 to-emerald-500",
                      "hover:from-teal-600 hover:to-emerald-600",
                      "text-white shadow-lg shadow-emerald-500/25",
                      "transition-all duration-200 ease-out transform-gpu",
                      "disabled:opacity-50 disabled:cursor-not-allowed"
                    ]}
                  >
                    <span :if={@working?}>Working...</span>
                    <span :if={!@working?}>Enroll another device</span>
                  </button>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- How it works --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">How Device Unlock Works</span>
              </div>
            </:title>

            <div class="space-y-4 text-sm text-blue-700 dark:text-blue-300">
              <p>
                Your device's secure enclave produces a secret that is combined with your
                password to unlock your data. The server only ever stores an opaque
                encrypted blob — never your password, the device secret, or your keys.
              </p>
              <div class="space-y-2">
                <div class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-check-circle"
                    class="h-4 w-4 mt-0.5 text-blue-500 dark:text-blue-400 flex-shrink-0"
                  />
                  <span>A stolen password alone can no longer unlock your account</span>
                </div>
                <div class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-check-circle"
                    class="h-4 w-4 mt-0.5 text-blue-500 dark:text-blue-400 flex-shrink-0"
                  />
                  <span>Your recovery key still works if you lose this device</span>
                </div>
                <div class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-check-circle"
                    class="h-4 w-4 mt-0.5 text-blue-500 dark:text-blue-400 flex-shrink-0"
                  />
                  <span>Removing your last device restores password-only unlock</span>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  # --- Enroll ---------------------------------------------------------------

  def handle_event("start_enroll", _params, socket) do
    if socket.assigns.has_recovery_key? do
      user = socket.assigns.current_scope.user

      {:noreply,
       socket
       |> assign(working?: true, error_message: nil)
       |> push_event("prf_enroll", %{user_id: user.id, user_name: "Mosslet account"})}
    else
      {:noreply,
       assign(socket,
         error_message: "Set up a recovery key before enabling device unlock."
       )}
    end
  end

  def handle_event("prf_enrolled", params, socket) do
    user = socket.assigns.current_scope.user

    attrs = %{
      wrapped_user_key: params["wrapped_user_key"],
      wrap_salt: params["wrap_salt"],
      credential_id: params["credential_id"],
      prf_salt: params["prf_salt"],
      ecosystem_hint: params["ecosystem_hint"]
    }

    case Accounts.enroll_prf_wrap(user, attrs) do
      {:ok, _wrap} ->
        {:noreply,
         socket
         |> assign(working?: false, error_message: nil)
         |> assign_wrap_state(user)
         |> put_flash(:success, "Device unlock enabled for this device.")}

      {:error, :recovery_key_required} ->
        {:noreply,
         assign(socket,
           working?: false,
           error_message: "Set up a recovery key before enabling device unlock."
         )}

      {:error, _reason} ->
        {:noreply,
         assign(socket,
           working?: false,
           error_message: "Failed to enable device unlock. Please try again."
         )}
    end
  end

  # --- Un-enroll ------------------------------------------------------------

  def handle_event("start_unenroll", %{"id" => wrap_id}, socket) do
    last_device? = length(socket.assigns.prf_wraps) <= 1

    {:noreply,
     socket
     |> assign(working?: true, error_message: nil)
     |> push_event("prf_unenroll", %{wrap_id: wrap_id, last_device: last_device?})}
  end

  def handle_event("prf_unenrolled", params, socket) do
    user = socket.assigns.current_scope.user

    password_wrap =
      case params do
        %{"wrapped_user_key" => wuk, "wrap_salt" => salt}
        when is_binary(wuk) and is_binary(salt) ->
          %{wrapped_user_key: wuk, wrap_salt: salt}

        _ ->
          nil
      end

    case Accounts.unenroll_prf_wrap(user, params["wrap_id"], password_wrap) do
      {:ok, result} ->
        message =
          case result do
            :unenrolled -> "Device removed. Your account is back to password-only unlock."
            :still_enrolled -> "Device removed."
          end

        {:noreply,
         socket
         |> assign(working?: false, error_message: nil)
         |> assign_wrap_state(user)
         |> put_flash(:success, message)}

      {:error, :password_wrap_required} ->
        {:noreply,
         assign(socket,
           working?: false,
           error_message: "Please enter your password to remove your last device."
         )}

      {:error, _reason} ->
        {:noreply,
         assign(socket,
           working?: false,
           error_message: "Failed to remove the device. Please try again."
         )}
    end
  end

  def handle_event("prf_error", %{"error" => error}, socket) do
    {:noreply, assign(socket, working?: false, error_message: error)}
  end

  defp ecosystem_label("apple"), do: "Apple device"
  defp ecosystem_label("google"), do: "Google / Android device"
  defp ecosystem_label(_), do: "This device"
end
