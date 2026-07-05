defmodule MossletWeb.UnlockSessionLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  @impl true
  def mount(_params, session, socket) do
    user_token = session["user_token"]
    user = if user_token, do: Accounts.get_user_by_session_token(user_token)

    cond do
      is_nil(user) ->
        {:ok,
         socket
         |> put_flash(:error, "Please log in.")
         |> redirect(to: ~p"/auth/sign_in")}

      true ->
        {:ok,
         assign(socket,
           page_title: "Unlock Session",
           user: user,
           key_hash: user.key_hash,
           prf_enrolled?: Accounts.prf_enrolled?(user),
           has_recovery_key?: Accounts.has_recovery_key?(user),
           prf_payload: prf_payload(user),
           form: to_form(%{}, as: :unlock),
           trigger_submit: false,
           recovery_trigger?: false,
           recovery_rc: nil,
           recovery_error: nil,
           recovery_working?: false,
           prf_unlock_error: nil
         )}
    end
  end

  # OPAQUE per-authenticator unlock doors for enrolled accounts (board #370).
  # Same shape the /api/auth/salt endpoint serves — every field is a blob the
  # browser produced (I6). Non-enrolled users get an empty payload and the
  # legacy key_hash password path is used unchanged.
  defp prf_payload(user) do
    wraps =
      user
      |> Accounts.list_user_key_wraps()
      |> Enum.filter(&(&1.kind == :prf))
      |> Enum.map(fn wrap ->
        %{
          id: wrap.id,
          credential_id: wrap.credential_id,
          prf_salt: wrap.prf_salt,
          wrap_salt: wrap.wrap_salt,
          wrapped_user_key: wrap.wrapped_user_key
        }
      end)

    Jason.encode!(%{enrolled: wraps != [], wraps: wraps})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 via-teal-50/30 to-emerald-50/20 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800 px-4 sm:px-6 lg:px-8">
      <div class="w-full max-w-md">
        <div class="bg-white/70 dark:bg-slate-800/70 backdrop-blur-xl rounded-2xl shadow-xl shadow-slate-200/50 dark:shadow-slate-900/50 border border-white/50 dark:border-slate-700/50 p-8 sm:p-10">
          <%!-- Header --%>
          <div class="text-center mb-8">
            <%!-- Org-branded ACCENT (Task #240 / #243). Shown only on a live org
                  subdomain host. ACCENT only + persistent "Secured by MOSSLET";
                  no logo here (the session is locked — no key holder yet). --%>
            <div
              :if={@subdomain_org_live? && @subdomain_org}
              id="org-branded-unlock"
              class="mb-6 flex flex-col items-center gap-2"
            >
              <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/50 dark:border-emerald-700/30">
                <.phx_icon
                  name="hero-building-office-2"
                  class="size-4 text-emerald-600 dark:text-emerald-400"
                />
                <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
                  {@subdomain_org.name}
                </span>
              </div>
              <p class="inline-flex items-center gap-1 text-xs text-slate-400 dark:text-slate-500">
                <.phx_icon name="hero-lock-closed" class="size-3" /> Secured by MOSSLET
              </p>
            </div>

            <div class="mb-6">
              <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/20 dark:to-emerald-900/20 border border-teal-200/50 dark:border-teal-700/30 mb-4">
                <.phx_icon
                  name="hero-lock-closed"
                  class="w-5 h-5 text-teal-600 dark:text-teal-400"
                />
                <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
                  Session Locked
                </span>
              </div>
            </div>

            <h1 class={[
              "text-3xl sm:text-4xl font-bold tracking-tight leading-tight mb-3",
              "bg-gradient-to-r from-teal-500 to-emerald-500",
              "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
              "bg-clip-text text-transparent"
            ]}>
              Welcome back!
            </h1>

            <p class="text-base text-slate-600 dark:text-slate-300">
              <%= if @prf_enrolled? do %>
                Enter your password, then confirm with this device to unlock
              <% else %>
                Enter your password to unlock your encrypted content
              <% end %>
            </p>
          </div>

          <%!-- PRF unlock couldn't complete on this device (enrolled account).
                Honest guidance — no password-only door exists here, so a wrong
                password and a not-enrolled device look the same. --%>
          <div
            :if={@prf_unlock_error}
            id="prf-unlock-error"
            role="alert"
            aria-live="assertive"
            class="mb-6 p-4 rounded-xl bg-amber-50 border border-amber-200 dark:bg-amber-900/20 dark:border-amber-800/50"
          >
            <div class="flex items-start gap-3">
              <.phx_icon
                name="hero-exclamation-triangle"
                class="w-5 h-5 text-amber-600 dark:text-amber-400 mt-0.5 flex-shrink-0"
              />
              <p class="text-sm text-amber-700 dark:text-amber-300">{@prf_unlock_error}</p>
            </div>
          </div>

          <%!-- Unlock form with UnlockHook for browser-side key derivation --%>
          <.form
            for={@form}
            id="unlock_form"
            action={~p"/auth/unlock"}
            phx-hook="UnlockHook"
            phx-trigger-action={@trigger_submit}
            phx-submit="unlock"
            data-key-hash={@key_hash}
            data-prf={@prf_payload}
            data-encrypted-private-key={@user.key_pair["private"]}
            data-encrypted-pq-private-key={@user.encrypted_pq_private_key}
            class="space-y-6"
          >
            <%!-- PRF unlock fields (board #370). Declared server-side so they
                  survive LiveView DOM patches — the UnlockHook only sets their
                  VALUE after a successful on-device KDF(password‖prf) unwrap,
                  then submits the form directly. Empty for non-enrolled/password
                  submits, so the legacy key_hash path is byte-for-byte unchanged. --%>
            <input type="hidden" name="unlock[user_key]" />
            <input type="hidden" name="unlock[wrap_id]" />

            <div>
              <label
                for="unlock-password"
                class="block text-sm font-semibold leading-6 text-zinc-800 dark:text-white mb-2"
              >
                Password<span class="text-red-500"> *</span>
              </label>
              <input
                type="password"
                name="unlock[password]"
                id="unlock-password"
                required
                autofocus
                autocomplete="current-password"
                placeholder="Enter your password"
                class={[
                  "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                  "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                  "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                  "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                  "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                  "transition-all duration-200 ease-out",
                  "hover:ring-emerald-400/50 dark:hover:ring-emerald-500/50",
                  "text-base sm:text-sm sm:leading-6"
                ]}
              />
              <p
                :if={@prf_enrolled?}
                class="mt-2 flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400"
              >
                <.phx_icon name="hero-finger-print" class="w-3.5 h-3.5 shrink-0" />
                Device Unlock is on — you'll confirm with your passkey (Face ID, Touch ID, or security key).
              </p>
            </div>

            <button
              type="submit"
              class={[
                "w-full px-6 py-3.5 rounded-xl font-semibold text-white",
                "bg-gradient-to-r from-teal-500 to-emerald-500",
                "hover:from-teal-600 hover:to-emerald-600",
                "dark:from-teal-600 dark:to-emerald-600",
                "dark:hover:from-teal-500 dark:hover:to-emerald-500",
                "shadow-lg shadow-teal-500/25 dark:shadow-teal-900/30",
                "hover:shadow-xl hover:shadow-teal-500/30",
                "transform transition-all duration-300 ease-out",
                "hover:scale-[1.02] active:scale-[0.98]",
                "focus:outline-none focus:ring-4 focus:ring-teal-500/50"
              ]}
            >
              <span class="flex items-center justify-center gap-2">
                <.phx_icon
                  name={if @prf_enrolled?, do: "hero-finger-print", else: "hero-lock-open"}
                  class="h-5 w-5"
                />
                <span>{if @prf_enrolled?, do: "Unlock with your device", else: "Unlock Session"}</span>
              </span>
            </button>
          </.form>

          <%!-- New-device bootstrap (board #366, design §8): an enrolled account
                on a device with no local passkey can't unlock via PRF above.
                Offer a recovery-key unlock, then invite enrolling this device. --%>
          <div :if={@prf_enrolled? && @has_recovery_key?} class="mt-6">
            <details id="recovery-unlock-details" class="group" open={@prf_unlock_error != nil}>
              <summary class="cursor-pointer list-none text-center text-sm font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors">
                New device? Unlock with your recovery key
              </summary>

              <div class="mt-4 space-y-4">
                <p class="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                  This account requires an enrolled device to unlock with your password.
                  If this device isn't enrolled yet, unlock with your recovery key — then
                  you can add this device from Device Unlock settings.
                </p>

                <div
                  :if={@recovery_error}
                  id="recovery-unlock-error"
                  class="p-3 rounded-lg bg-rose-50 border border-rose-200 dark:bg-rose-900/20 dark:border-rose-800/50 text-sm text-rose-700 dark:text-rose-300"
                >
                  {@recovery_error}
                </div>

                <.form
                  for={@form}
                  id="recovery_unlock_form"
                  action={~p"/auth/unlock"}
                  phx-hook="RecoveryUnlockHook"
                  phx-trigger-action={@recovery_trigger?}
                  data-encrypted-recovery-private-key={@user.encrypted_recovery_private_key}
                  data-public-key={@user.key_pair["public"]}
                  data-encrypted-user-key={@user.user_key}
                  class="space-y-3"
                >
                  <input type="hidden" name="unlock[user_key]" />
                  <input type="hidden" name="unlock[rc]" value={@recovery_rc} />
                  <input type="hidden" name="unlock[wrap_id]" value="recovery" />

                  <label for="recovery-key-input" class="sr-only">Recovery key</label>
                  <input
                    type="text"
                    name="recovery_key"
                    id="recovery-key-input"
                    autocomplete="off"
                    spellcheck="false"
                    placeholder="Enter your recovery key"
                    class="block w-full rounded-xl border-0 py-3 px-4 text-slate-900 dark:text-white bg-white/80 dark:bg-slate-700/80 ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50 focus:ring-2 focus:ring-inset focus:ring-emerald-500/50 text-sm"
                  />

                  <button
                    type="submit"
                    id="recovery-unlock-btn"
                    disabled={@recovery_working?}
                    class="w-full px-6 py-3 rounded-xl font-semibold text-teal-700 dark:text-teal-300 border border-teal-300 dark:border-teal-700 hover:bg-teal-50 dark:hover:bg-teal-900/20 transition-colors disabled:opacity-50"
                  >
                    <span :if={@recovery_working?}>Unlocking…</span>
                    <span :if={!@recovery_working?}>Unlock with recovery key</span>
                  </button>
                </.form>
              </div>
            </details>
          </div>

          <%!-- Footer --%>
          <div class="space-y-3 pt-6 mt-6 border-t border-slate-200 dark:border-slate-700/50">
            <p class="text-center text-sm text-slate-600 dark:text-slate-400">
              Not you?
              <.link
                href={~p"/auth/sign_out"}
                method="delete"
                class="font-semibold text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors duration-200"
              >
                Sign out
              </.link>
            </p>

            <div class="mt-4 p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700/50">
              <div class="flex gap-3">
                <.phx_icon
                  name="hero-shield-check"
                  class="h-5 w-5 text-teal-600 dark:text-teal-400 shrink-0 mt-0.5"
                />
                <div>
                  <h2 class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-1">
                    Auto-lock enabled
                  </h2>
                  <p class="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                    Your encrypted data is automatically locked when your browser session expires. This prevents unauthorized access to your personal information.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("unlock", %{"unlock" => %{"password" => _password}}, socket) do
    # The actual password verification happens server-side via the form action.
    # We just trigger the form submission (which the UnlockHook has already
    # intercepted to derive the user_key before submitting).
    {:noreply, assign(socket, trigger_submit: true)}
  end

  # Enrolled account, but the browser couldn't unlock `user_key` via
  # KDF(password‖prf) on this device (board #370/#371): wrong password, or this
  # device's passkey isn't enrolled / can't produce the PRF (different ecosystem,
  # a not-yet-enrolled phone, or a passkey manager like 1Password declining).
  # There is NO password-only door to fall back to, so we DON'T POST (that would
  # only yield a misleading "Invalid password"). Show honest guidance and reveal
  # the recovery-key unlock, from which the user can add this device.
  def handle_event("prf_unlock_unavailable", _params, socket) do
    message =
      if socket.assigns.has_recovery_key? do
        "We couldn't unlock on this device. Double-check your password. If this device isn't set up yet, unlock with your recovery key below — then you can add it from Device Unlock settings."
      else
        "We couldn't unlock on this device. Double-check your password, or unlock on a device you've already enrolled."
      end

    {:noreply, assign(socket, prf_unlock_error: message)}
  end

  # New-device recovery unlock (board #366). The hook has already recovered
  # `user_key` on-device (never sent here — I6) and placed it in the hidden
  # `unlock[user_key]` field. We only Argon2-verify the recovery secret (exactly
  # the existing recovery model — never stored), and on success mint a fresh
  # recovery-confirmation token so the user can immediately enroll THIS device
  # after unlocking, then trigger the form POST to the unlock controller.
  @impl true
  def handle_event("recovery_unlock_verify", %{"recovery_secret" => secret}, socket)
      when is_binary(secret) do
    user = socket.assigns.user

    case Accounts.verify_recovery_secret(user, secret) do
      :ok ->
        rc = Accounts.sign_recovery_confirmation(user)

        {:reply, %{ok: true},
         socket
         |> assign(recovery_rc: rc, recovery_error: nil, recovery_working?: true)}

      :error ->
        {:reply, %{ok: false},
         assign(socket,
           recovery_working?: false,
           recovery_error: "That recovery key wasn't recognized. Please check it and try again."
         )}
    end
  end

  def handle_event("recovery_unlock_ready", _params, socket) do
    # Hook has populated the hidden user_key field and is ready to POST.
    {:noreply, assign(socket, recovery_trigger?: true)}
  end

  def handle_event("recovery_unlock_error", %{"error" => error}, socket) do
    {:noreply, assign(socket, recovery_working?: false, recovery_error: error)}
  end
end
