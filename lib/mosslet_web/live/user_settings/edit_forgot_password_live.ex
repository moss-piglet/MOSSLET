defmodule MossletWeb.EditForgotPasswordLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       form: to_form(Accounts.change_user_visibility(socket.assigns.current_user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.layout
      current_user={@current_user}
      current_page={:edit_forgot_password}
      key={@key}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Account Recovery
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Choose between maximum privacy or convenience for password recovery.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-3xl">
          <%!-- Current Status Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class={[
                  "relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden",
                  if(@current_user.is_forgot_pwd?,
                    do:
                      "bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30",
                    else:
                      "bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30"
                  )
                ]}>
                  <.phx_icon
                    name={if @current_user.is_forgot_pwd?, do: "hero-key", else: "hero-lock-closed"}
                    class={[
                      "h-4 w-4",
                      if(@current_user.is_forgot_pwd?,
                        do: "text-blue-600 dark:text-blue-400",
                        else: "text-emerald-600 dark:text-emerald-400"
                      )
                    ]}
                  />
                </div>
                <span>Current Setting</span>
                <span class={[
                  "inline-flex px-2.5 py-0.5 text-xs rounded-lg font-medium",
                  if(@current_user.is_forgot_pwd?,
                    do:
                      "bg-gradient-to-r from-blue-100 to-cyan-200 text-blue-800 dark:from-blue-800 dark:to-cyan-700 dark:text-blue-200 border border-blue-300 dark:border-blue-600",
                    else:
                      "bg-gradient-to-r from-emerald-100 to-teal-200 text-emerald-800 dark:from-emerald-800 dark:to-teal-700 dark:text-emerald-200 border border-emerald-300 dark:border-emerald-600"
                  )
                ]}>
                  {if @current_user.is_forgot_pwd?, do: "Maximum Convenience", else: "Maximum Privacy"}
                </span>
              </div>
            </:title>

            <div class="space-y-6">
              <%!-- Current status explanation --%>
              <div class={[
                "p-4 rounded-lg border",
                if(@current_user.is_forgot_pwd?,
                  do:
                    "bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10 border-blue-200 dark:border-blue-700",
                  else:
                    "bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10 border-emerald-200 dark:border-emerald-700"
                )
              ]}>
                <div class="flex items-start gap-3">
                  <.phx_icon
                    name={if @current_user.is_forgot_pwd?, do: "hero-key", else: "hero-shield-check"}
                    class={[
                      "h-5 w-5 mt-0.5 flex-shrink-0",
                      if(@current_user.is_forgot_pwd?,
                        do: "text-blue-600 dark:text-blue-400",
                        else: "text-emerald-600 dark:text-emerald-400"
                      )
                    ]}
                  />
                  <div class="space-y-2">
                    <h4 class={[
                      "font-medium text-sm",
                      if(@current_user.is_forgot_pwd?,
                        do: "text-blue-800 dark:text-blue-200",
                        else: "text-emerald-800 dark:text-emerald-200"
                      )
                    ]}>
                      {if @current_user.is_forgot_pwd?,
                        do: "Maximum Convenience Mode",
                        else: "Maximum Privacy Mode"}
                    </h4>
                    <p class={[
                      "text-sm leading-relaxed",
                      if(@current_user.is_forgot_pwd?,
                        do: "text-blue-700 dark:text-blue-300",
                        else: "text-emerald-700 dark:text-emerald-300"
                      )
                    ]}>
                      <span :if={!@current_user.is_forgot_pwd?}>
                        Total privacy! You cannot regain access to your account if you forget your password. Your password is used to derive the cryptographic key that protects your data.
                      </span>
                      <span :if={@current_user.is_forgot_pwd?}>
                        Total convenience! You can easily recover your account using the "Forgot Password" feature. An encrypted recovery key is stored securely on our servers for your peace of mind.
                      </span>
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Additional information --%>
              <div class="space-y-3">
                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  <span :if={!@current_user.is_forgot_pwd?}>
                    If you feel your password may have been compromised, you can change it in the
                    <.link
                      navigate={~p"/app/users/change-password"}
                      class="font-medium text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300 transition-colors duration-200"
                    >
                      Password Settings
                    </.link>
                    section. This will generate new encryption keys for your account.
                  </span>
                  <span :if={@current_user.is_forgot_pwd?}>
                    Your account remains protected with strong encryption. However, it may be possible for authorities to request access to your recovery key if required by law.
                  </span>
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Setting Change Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon name="hero-cog-6-tooth" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
                </div>
                Change Recovery Setting
              </div>
            </:title>

            <div class="space-y-6">
              <%!-- What happens section --%>
              <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 border border-slate-200 dark:border-slate-700">
                <h4 class="font-medium text-sm text-slate-900 dark:text-slate-100 mb-3">
                  What happens when you change this setting:
                </h4>
                <div class="space-y-2 text-sm text-slate-600 dark:text-slate-400">
                  <div :if={!@current_user.is_forgot_pwd?} class="space-y-2">
                    <p class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-arrow-right"
                        class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                      />
                      <span>Your encrypted recovery key will be securely stored on our servers</span>
                    </p>
                    <p class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-arrow-right"
                        class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                      />
                      <span>You'll be able to use "Forgot Password" on the login page</span>
                    </p>
                    <p class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-arrow-right"
                        class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                      />
                      <span>Your data remains encrypted and secure</span>
                    </p>
                  </div>
                  <div :if={@current_user.is_forgot_pwd?} class="space-y-2">
                    <p class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-arrow-right"
                        class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                      />
                      <span>Your encrypted recovery key will be removed from our servers</span>
                    </p>
                    <p class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-arrow-right"
                        class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                      />
                      <span>Password recovery will no longer be possible</span>
                    </p>
                    <p class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-arrow-right"
                        class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                      />
                      <span>Only your password can derive the key to unlock your data</span>
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Checkbox form --%>
              <.form
                id="change_forgot_password_form"
                for={@form}
                phx-change="update_forgot_password"
                class="space-y-6"
              >
                <DesignSystem.liquid_checkbox
                  field={@form[:is_forgot_pwd?]}
                  label={
                    if @current_user.is_forgot_pwd?,
                      do: "Disable password recovery (maximum privacy)",
                      else: "Enable password recovery (convenience)"
                  }
                  help={
                    if @current_user.is_forgot_pwd?,
                      do:
                        "This will remove your recovery key from our servers. You can re-enable this feature anytime to store your key again.",
                      else: "This will securely store your account recovery key on our servers."
                  }
                />
              </.form>

              <%!-- Warning message --%>
              <div class="bg-gradient-to-br from-rose-50/50 to-pink-50/30 dark:from-rose-900/20 dark:to-pink-900/10 border border-rose-200 dark:border-rose-700 rounded-lg p-4">
                <div class="flex items-start gap-3">
                  <.phx_icon
                    name="hero-exclamation-triangle"
                    class="h-5 w-5 mt-0.5 text-rose-600 dark:text-rose-400 flex-shrink-0"
                  />
                  <div class="space-y-2">
                    <h4 class="font-medium text-sm text-rose-800 dark:text-rose-200">
                      Important Security Consideration
                    </h4>
                    <p class="text-sm text-rose-700 dark:text-rose-300 leading-relaxed">
                      This choice affects the security model of your account. Consider your needs carefully:
                      <strong class="font-medium">Maximum Privacy</strong>
                      means only you can derive the cryptographic keys to access your data (we can't help if you forget your password), while
                      <strong class="font-medium">Maximum Convenience</strong>
                      provides easy recovery but requires trust in our secure storage.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Security Best Practices Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">Security Recommendations</span>
              </div>
            </:title>

            <div class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Use a strong, unique password
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Never reuse this password elsewhere
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Store your password securely
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Use a password manager you trust
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Keep your recovery email updated
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Even with maximum privacy enabled
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Consider the trade-offs
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Privacy vs. convenience for your use case
                  </p>
                </div>
              </div>

              <div class="pt-4 border-t border-blue-200 dark:border-blue-700">
                <p class="text-sm text-blue-700 dark:text-blue-300">
                  <span class="font-medium">Pro tip:</span>
                  Whatever you choose, make sure you have a reliable way to remember or store your password.
                  Your MOSSLET account's security depends on it.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  def handle_event("validate_forgot_password", %{"user" => user_params}, socket) do
    forgot_password_form =
      socket.assigns.current_user
      |> Accounts.change_user_forgot_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, forgot_password_form: forgot_password_form)}
  end

  def handle_event("update_forgot_password", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    if user && user.confirmed_at do
      case Accounts.update_user_forgot_password(user, user_params,
             change_forgot_password: true,
             key: key,
             user: user
           ) do
        {:ok, user} ->
          forgot_password_form =
            user
            |> Accounts.change_user_forgot_password(user_params)
            |> to_form()

          info = "Your password recovery setting has been updated successfully."

          {:noreply,
           socket
           |> put_flash(:success, info)
           |> assign(forgot_password_form: forgot_password_form)
           |> push_navigate(to: ~p"/app/users/change-forgot-password")}

        {:error, _changeset} ->
          info = "Your password recovery setting could not be updated. Please try again later."

          {:noreply,
           socket
           |> put_flash(:error, info)
           |> push_navigate(to: ~p"/app/users/change-forgot-password")}
      end
    else
      info = "Woops, you need to confirm your account first."

      {:noreply,
       socket
       |> put_flash(:error, info)
       |> push_navigate(to: ~p"/app/users/change-forgot-password")}
    end
  end
end
