defmodule MossletWeb.UserAccountRecoveryLive do
  @moduledoc """
  Account recovery page — unauthenticated.

  Users enter their email + recovery key + new password. The AccountRecoveryHook
  handles the crypto entirely in the browser:

  1. Converts human-readable recovery key to secret
  2. POSTs to /api/auth/recovery-data for verification
  3. Decrypts private key using recovery secret
  4. Re-derives session key from new password
  5. Re-encrypts private key with new session key
  6. Pushes new key material back to the server
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Recover Account",
       status_message: nil,
       error_message: nil,
       success?: false
     )}
  end

  def render(assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Recover Account">
      <:logo>
        <.logo class="h-8 transition-transform duration-300 ease-out transform hover:scale-105" />
      </:logo>
      <:top_right>
        <MossletWeb.Layouts.theme_toggle />
      </:top_right>

      <div class="text-center mb-8 sm:mb-10">
        <div class="mb-6">
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/20 dark:to-emerald-900/20 border border-teal-200/50 dark:border-teal-700/30 mb-4">
            <span class="text-2xl">🔑</span>
            <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
              Recovery key
            </span>
          </div>
        </div>

        <h1 class={[
          "text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-tight mb-4",
          "bg-gradient-to-r from-teal-500 to-emerald-500",
          "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
          "bg-clip-text text-transparent"
        ]}>
          Recover your account
        </h1>

        <p :if={!@success?} class="text-lg text-slate-600 dark:text-slate-300 max-w-md mx-auto">
          Enter your email, recovery key, and a new password.
        </p>
      </div>

      <%!-- Error banner --%>
      <div
        :if={@error_message}
        class="mb-6 p-4 rounded-xl bg-rose-50 border border-rose-200 dark:bg-rose-900/20 dark:border-rose-800/50"
      >
        <div class="flex items-start gap-3">
          <.phx_icon
            name="hero-exclamation-triangle"
            class="w-5 h-5 text-rose-600 dark:text-rose-400 mt-0.5 flex-shrink-0"
          />
          <p class="text-sm text-rose-700 dark:text-rose-300">{@error_message}</p>
        </div>
      </div>

      <%!-- Status message --%>
      <div
        :if={@status_message}
        class="mb-6 p-4 rounded-xl bg-blue-50 border border-blue-200 dark:bg-blue-900/20 dark:border-blue-800/50"
      >
        <div class="flex items-center gap-3">
          <div class="animate-spin h-4 w-4 border-2 border-blue-500 border-t-transparent rounded-full">
          </div>
          <p class="text-sm text-blue-700 dark:text-blue-300">{@status_message}</p>
        </div>
      </div>

      <%!-- Success state --%>
      <div :if={@success?} class="space-y-6">
        <div class="p-6 rounded-xl bg-emerald-50 border border-emerald-200 dark:bg-emerald-900/20 dark:border-emerald-800/50 text-center">
          <.phx_icon
            name="hero-check-circle"
            class="w-12 h-12 text-emerald-500 dark:text-emerald-400 mx-auto mb-4"
          />
          <h2 class="text-xl font-bold text-emerald-800 dark:text-emerald-200 mb-2">
            Password reset successfully
          </h2>
          <p class="text-sm text-emerald-700 dark:text-emerald-300 mb-4">
            Your recovery key has been consumed. We recommend setting up a new
            recovery key in Settings after signing in.
          </p>
          <.link
            navigate={~p"/auth/sign_in"}
            class={[
              "inline-flex items-center gap-2 rounded-xl py-3 px-6 text-sm font-semibold",
              "bg-gradient-to-r from-teal-500 to-emerald-500",
              "hover:from-teal-600 hover:to-emerald-600",
              "text-white shadow-lg shadow-emerald-500/25",
              "transition-all duration-200"
            ]}
          >
            Sign in with your new password
          </.link>
        </div>
      </div>

      <%!-- Recovery form --%>
      <div :if={!@success?}>
        <form
          id="account-recovery-form"
          phx-hook="AccountRecoveryHook"
          class="space-y-6"
          phx-submit="noop"
        >
          <div class="space-y-4">
            <div>
              <label
                for="recovery-email"
                class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
              >
                Email
              </label>
              <input
                type="email"
                id="recovery-email"
                name="recovery[email]"
                required
                autocomplete="email"
                placeholder="Enter your email"
                class={[
                  "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                  "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                  "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                  "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                  "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                  "text-base sm:text-sm sm:leading-6"
                ]}
              />
            </div>

            <div>
              <label
                for="recovery-key"
                class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
              >
                Recovery Key
              </label>
              <input
                type="text"
                id="recovery-key"
                name="recovery[recovery_key]"
                required
                autocomplete="off"
                placeholder="XXXXX-XXXXX-XXXXX-XXXXX-..."
                class={[
                  "block w-full rounded-xl border-0 py-4 px-4 font-mono text-slate-900 dark:text-white",
                  "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                  "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                  "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                  "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                  "text-base sm:text-sm sm:leading-6"
                ]}
              />
            </div>

            <div>
              <label
                for="recovery-password"
                class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
              >
                New Password
              </label>
              <input
                type="password"
                id="recovery-password"
                name="recovery[password]"
                required
                autocomplete="new-password"
                minlength="12"
                placeholder="At least 12 characters"
                class={[
                  "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                  "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                  "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                  "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                  "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                  "text-base sm:text-sm sm:leading-6"
                ]}
              />
            </div>

            <div>
              <label
                for="recovery-password-confirmation"
                class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
              >
                Confirm Password
              </label>
              <input
                type="password"
                id="recovery-password-confirmation"
                name="recovery[password_confirmation]"
                required
                autocomplete="new-password"
                minlength="12"
                placeholder="Confirm your new password"
                class={[
                  "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                  "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                  "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                  "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                  "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                  "text-base sm:text-sm sm:leading-6"
                ]}
              />
            </div>
          </div>

          <button
            type="submit"
            class={[
              "w-full rounded-xl py-4 px-6 text-base font-semibold",
              "bg-gradient-to-r from-teal-500 to-emerald-500",
              "hover:from-teal-600 hover:to-emerald-600",
              "text-white shadow-lg shadow-emerald-500/25",
              "transition-all duration-200 ease-out transform-gpu",
              "hover:scale-[1.02] active:scale-[0.98]"
            ]}
          >
            Recover Account
          </button>
        </form>

        <%!-- Footer links --%>
        <div class="mt-6 pt-6 border-t border-slate-200/50 dark:border-slate-700/50">
          <div class="flex flex-col sm:flex-row items-center sm:justify-between gap-4 text-center sm:text-left">
            <.link
              navigate={~p"/auth/sign_in"}
              class="inline-flex items-center gap-2 text-sm font-medium text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400 transition-colors duration-200"
            >
              <.phx_icon name="hero-arrow-left" class="w-4 h-4" /> Back to sign in
            </.link>
            <.link
              navigate={~p"/auth/reset-password"}
              class="inline-flex items-center gap-2 text-sm font-medium text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400 transition-colors duration-200"
            >
              Use email reset instead
            </.link>
          </div>
        </div>
      </div>
    </.mosslet_auth_layout>
    """
  end

  # The AccountRecoveryHook handles all crypto client-side.
  # It pushes events back to the LiveView for status updates.

  def handle_event("noop", _params, socket), do: {:noreply, socket}

  def handle_event("recovery_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, status_message: status, error_message: nil)}
  end

  def handle_event("recovery_error", %{"error" => error}, socket) do
    {:noreply, assign(socket, error_message: error, status_message: nil)}
  end

  def handle_event(
        "recovery_complete",
        %{
          "email" => email,
          "recovery_secret" => recovery_secret,
          "new_password" => new_password,
          "new_key_hash" => new_key_hash,
          "new_encrypted_private_key" => new_encrypted_private_key
        },
        socket
      ) do
    case Accounts.reset_password_with_recovery(
           email,
           recovery_secret,
           new_password,
           new_key_hash,
           new_encrypted_private_key
         ) do
      {:ok, _user} ->
        {:noreply,
         assign(socket,
           success?: true,
           status_message: nil,
           error_message: nil
         )}

      {:error, :invalid_recovery_key} ->
        {:noreply,
         assign(socket,
           error_message: "Invalid recovery key or email. Please try again.",
           status_message: nil
         )}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         assign(socket,
           error_message:
             "Password does not meet requirements. Please use at least 12 characters.",
           status_message: nil
         )}
    end
  end
end
