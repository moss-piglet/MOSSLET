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
           form: to_form(%{}, as: :unlock),
           trigger_submit: false
         )}
    end
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
              Enter your password to unlock your encrypted content
            </p>
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
            data-encrypted-private-key={@user.key_pair["private"]}
            data-encrypted-pq-private-key={@user.encrypted_pq_private_key}
            class="space-y-6"
          >
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
                <.phx_icon name="hero-lock-open" class="h-5 w-5" />
                <span>Unlock Session</span>
              </span>
            </button>
          </.form>

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
end
