defmodule MossletWeb.DeleteAccountLive do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  import Mosslet.FileUploads.Storj

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Billing.Subscriptions.Subscription
  alias MossletWeb.DesignSystem

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:delete_account}
      sidebar_current_page={:delete_account}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-rose-500 to-pink-500 bg-clip-text text-transparent">
              Delete Account
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Permanently delete your MOSSLET account and all associated data.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-rose-400 via-pink-400 to-rose-400 shadow-sm shadow-rose-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-2xl">
          <%!-- Warning Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-rose-50/50 to-pink-50/30 dark:from-rose-900/20 dark:to-pink-900/10 border-rose-200/60 dark:border-rose-700/60">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-rose-100 via-pink-50 to-rose-100 dark:from-rose-900/30 dark:via-pink-900/25 dark:to-rose-900/30">
                  <.phx_icon
                    name="hero-exclamation-triangle"
                    class="h-4 w-4 text-rose-600 dark:text-rose-400"
                  />
                </div>
                <span class="text-rose-800 dark:text-rose-200">Critical Warning</span>
              </div>
            </:title>

            <div class="space-y-4">
              <div class="bg-gradient-to-r from-rose-100/80 to-pink-100/80 dark:from-rose-900/30 dark:to-pink-900/30 rounded-xl p-4 border border-rose-200/60 dark:border-rose-700/60">
                <p class="text-rose-700 dark:text-rose-300 font-medium">
                  ⚠️ This action cannot be undone and will immediately:
                </p>
                <ul class="mt-3 space-y-2 text-rose-700 dark:text-rose-300">
                  <li class="flex items-start gap-2">
                    <.phx_icon name="hero-x-mark" class="h-4 w-4 text-rose-500 mt-0.5 flex-shrink-0" />
                    <span>Delete all your personal data in real-time</span>
                  </li>
                  <li class="flex items-start gap-2">
                    <.phx_icon name="hero-x-mark" class="h-4 w-4 text-rose-500 mt-0.5 flex-shrink-0" />
                    <span>Remove all connections and social links</span>
                  </li>
                  <li class="flex items-start gap-2">
                    <.phx_icon name="hero-x-mark" class="h-4 w-4 text-rose-500 mt-0.5 flex-shrink-0" />
                    <span>Cancel any active subscription</span>
                  </li>
                  <li class="flex items-start gap-2">
                    <.phx_icon name="hero-x-mark" class="h-4 w-4 text-rose-500 mt-0.5 flex-shrink-0" />
                    <span>Delete your Stripe customer account</span>
                  </li>
                  <li class="flex items-start gap-2">
                    <.phx_icon name="hero-x-mark" class="h-4 w-4 text-rose-500 mt-0.5 flex-shrink-0" />
                    <span>Remove all uploaded files and memories</span>
                  </li>
                </ul>
              </div>

              <div class="bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10 rounded-xl p-4 border border-emerald-200/60 dark:border-emerald-700/60">
                <div class="flex items-start gap-3">
                  <.phx_icon
                    name="hero-light-bulb"
                    class="h-5 w-5 mt-0.5 text-emerald-600 dark:text-emerald-400 flex-shrink-0"
                  />
                  <div class="space-y-3">
                    <h3 class="font-medium text-sm text-emerald-800 dark:text-emerald-200">
                      Consider These Alternatives First
                    </h3>
                    <div class="space-y-2">
                      <DesignSystem.liquid_button
                        href="/app/users/manage-data"
                        variant="secondary"
                        color="emerald"
                        size="sm"
                        icon="hero-trash"
                        class="w-full justify-center"
                      >
                        Delete selected data only
                      </DesignSystem.liquid_button>
                      <DesignSystem.liquid_button
                        :if={@current_scope.user.visibility !== :private}
                        href="/app/users/edit-visibility"
                        variant="secondary"
                        color="blue"
                        size="sm"
                        icon="hero-eye-slash"
                        class="w-full justify-center"
                      >
                        Make your profile private
                      </DesignSystem.liquid_button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Delete Account Form Card --%>
          <DesignSystem.liquid_card class="border-slate-200/60 dark:border-slate-700/60">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700">
                  <.phx_icon name="hero-key" class="h-4 w-4 text-slate-600 dark:text-slate-400" />
                </div>
                <span class="text-slate-900 dark:text-slate-100">Confirm Account Deletion</span>
              </div>
            </:title>

            <.form
              for={@form}
              id="delete_account_form"
              phx-change="validate_delete_account"
              phx-submit="delete_account"
              class="space-y-8"
            >
              <%!-- Hidden ID field --%>
              <input type="hidden" name="user[id]" value={@current_scope.user.id} />

              <%!-- Simplified security notice --%>
              <div class="bg-slate-50 dark:bg-slate-800/50 rounded-xl p-4 border border-slate-200/60 dark:border-slate-700/60">
                <div class="flex items-start gap-3">
                  <div class="flex-shrink-0">
                    <.phx_icon
                      name="hero-shield-check"
                      class="h-5 w-5 text-slate-600 dark:text-slate-400 mt-0.5"
                    />
                  </div>
                  <div class="space-y-1">
                    <h3 class="text-sm font-medium text-slate-800 dark:text-slate-200">
                      Security Verification Required
                    </h3>
                    <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                      Enter your current password to verify your identity and confirm this action.
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Password input section with enhanced UX --%>
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <label
                    for="current-password-for-delete-account"
                    class="block text-sm font-medium text-slate-900 dark:text-slate-100"
                  >
                    Current Password <span class="text-rose-500 ml-1">*</span>
                  </label>
                </div>

                <div class="group relative">
                  <%!-- Enhanced liquid background effect on focus --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-rose-50/30 via-pink-50/40 to-rose-50/30 dark:from-rose-900/15 dark:via-pink-900/20 dark:to-rose-900/15 group-focus-within:opacity-100 rounded-xl">
                  </div>

                  <%!-- Enhanced shimmer effect on focus --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-rose-200/30 to-transparent dark:via-rose-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
                  </div>

                  <%!-- Focus ring with liquid metal styling --%>
                  <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-rose-500 via-pink-500 to-rose-500 dark:from-rose-400 dark:via-pink-400 dark:to-rose-400 group-focus-within:opacity-100 blur-sm">
                  </div>

                  <%!-- Secondary focus ring for better definition --%>
                  <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-rose-500 dark:border-rose-400 group-focus-within:opacity-100">
                  </div>

                  <%!-- Password input with enhanced accessibility and rose theme --%>
                  <input
                    type="password"
                    id="current-password-for-delete-account"
                    name="user[current_password]"
                    value={@current_password}
                    required
                    autocomplete="current-password"
                    placeholder="Enter your current password to confirm"
                    aria-describedby="password-help"
                    class={[
                      "relative block w-full rounded-xl px-4 py-3 pr-12 text-slate-900 dark:text-slate-100",
                      "bg-slate-50 dark:bg-slate-900 placeholder:text-slate-500 dark:placeholder:text-slate-400",
                      "border-2 border-slate-200 dark:border-slate-700",
                      "hover:border-slate-300 dark:hover:border-slate-600",
                      "focus:border-rose-500 dark:focus:border-rose-400",
                      "focus:outline-none focus:ring-0",
                      "transition-all duration-200 ease-out",
                      "sm:text-sm sm:leading-6",
                      "shadow-sm focus:shadow-lg focus:shadow-rose-500/10",
                      "focus:bg-white dark:focus:bg-slate-800"
                    ]}
                  />

                  <%!-- Enhanced Show/Hide Password Toggle --%>
                  <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                    <button
                      type="button"
                      id="eye"
                      aria-label="Show password"
                      data-tippy-content="Show password"
                      phx-hook="TippyHook"
                      class="group/toggle p-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-all duration-200"
                      phx-click={
                        JS.set_attribute({"type", "text"}, to: "#current-password-for-delete-account")
                        |> JS.remove_class("hidden", to: "#eye-slash")
                        |> JS.add_class("hidden", to: "#eye")
                      }
                    >
                      <.phx_icon
                        name="hero-eye"
                        class="h-4 w-4 group-hover/toggle:scale-110 transition-transform duration-200"
                      />
                    </button>
                    <button
                      type="button"
                      id="eye-slash"
                      aria-label="Hide password"
                      data-tippy-content="Hide password"
                      phx-hook="TippyHook"
                      class="hidden group/toggle p-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-all duration-200"
                      phx-click={
                        JS.set_attribute({"type", "password"},
                          to: "#current-password-for-delete-account"
                        )
                        |> JS.add_class("hidden", to: "#eye-slash")
                        |> JS.remove_class("hidden", to: "#eye")
                      }
                    >
                      <.phx_icon
                        name="hero-eye-slash"
                        class="h-4 w-4 group-hover/toggle:scale-110 transition-transform duration-200"
                      />
                    </button>
                  </div>
                </div>

                <%!-- Helper text --%>
                <p
                  id="password-help"
                  class="text-xs text-slate-500 dark:text-slate-400 leading-relaxed"
                >
                  Use the same password you use to sign in to your MOSSLET account.
                </p>
              </div>

              <%!-- Action Buttons --%>
              <div class="flex flex-col sm:flex-row sm:justify-between gap-4 pt-6 border-t border-slate-200/60 dark:border-slate-700/60">
                <DesignSystem.liquid_button
                  href="/app/users/edit-details"
                  variant="secondary"
                  color="slate"
                  icon="hero-arrow-left"
                  class="w-full sm:w-auto"
                >
                  Cancel
                </DesignSystem.liquid_button>

                <DesignSystem.liquid_button
                  type="submit"
                  color="rose"
                  icon="hero-trash"
                  class="w-full sm:w-auto"
                  phx-disable-with="Deleting Account..."
                >
                  Delete My Account Forever
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <%!-- Additional Support Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10 border-blue-200/60 dark:border-blue-700/60">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-lifebuoy"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">Need Help?</span>
              </div>
            </:title>

            <div class="space-y-6">
              <p class="text-blue-700 dark:text-blue-300 leading-relaxed">
                If you're having issues with your account or just need to take a break,
                our human support team is here to help find a solution that works for you.
              </p>

              <%!-- Enhanced button layout with clear hierarchy --%>
              <div class="space-y-3">
                <%!-- Primary support action --%>
                <DesignSystem.liquid_button
                  href="mailto:support@mosslet.com"
                  variant="primary"
                  color="blue"
                  size="md"
                  icon="hero-envelope"
                  class="w-full justify-center"
                >
                  Contact Human Support
                </DesignSystem.liquid_button>

                <%!-- Secondary action with subtle styling --%>
                <div class="relative">
                  <div class="absolute inset-0 flex items-center">
                    <div class="w-full border-t border-blue-200/40 dark:border-blue-700/40"></div>
                  </div>
                  <div class="relative flex justify-center text-xs">
                    <span class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10 px-2 text-blue-700 dark:text-blue-300 font-medium">
                      or
                    </span>
                  </div>
                </div>

                <DesignSystem.liquid_button
                  href="/support"
                  variant="ghost"
                  color="blue"
                  size="sm"
                  icon="hero-book-open"
                  class="w-full justify-center"
                >
                  Browse Support Center
                </DesignSystem.liquid_button>
              </div>

              <%!-- Additional context with liquid styling --%>
              <div class="bg-gradient-to-r from-blue-100/80 to-cyan-100/80 dark:from-blue-900/30 dark:to-cyan-900/30 rounded-xl p-4 border border-blue-200/60 dark:border-blue-700/60">
                <p class="text-sm text-blue-700 dark:text-blue-300 text-center">
                  <.phx_icon name="hero-sparkles" class="h-4 w-4 inline mr-1" />
                  We're real people who actually want to help
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    {:ok,
     assign(socket,
       page_title: "Settings",
       current_password: nil,
       source: socket.assigns.live_action,
       billing_provider: billing_provider(),
       form: to_form(Accounts.change_user_delete_account(current_user))
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, maybe_load_provider_data(socket)}
  end

  def handle_event(
        "validate_delete_account",
        %{"user" => user_params},
        socket
      ) do
    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_delete_account(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     assign(socket,
       form: form,
       current_password: user_params["current_password"]
     )}
  end

  def handle_event(
        "delete_account",
        %{"user" => user_params},
        socket
      ) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    # if a stripe account hasn't been created yet
    stripe_customer_id =
      if user.customer && user.customer.provider_customer_id do
        Mosslet.Encrypted.Users.Utils.decrypt_user_data(
          user.customer.provider_customer_id,
          user,
          key
        )
      else
        nil
      end

    # Cancel Stripe subscription.
    case Accounts.delete_user_account(user, user_params["current_password"], user_params) do
      {:ok, user} ->
        case cancel_subscription(user, socket) do
          :canceled ->
            if stripe_customer_id do
              with {:ok, _deleted_stripe_customer} <-
                     Stripe.Customer.delete(stripe_customer_id) do
                if Map.get(user, :avatar_url) do
                  avatars_bucket = Encrypted.Session.avatars_bucket()
                  memories_bucket = Encrypted.Session.memories_bucket()
                  d_url = decr_avatar(user.connection.avatar_url, user, user.conn_key, key)
                  profile = Map.get(user.connection, :profile)

                  # Handle deleting the object storage avatar and memories async.
                  if profile do
                    profile_avatar_url =
                      decr_avatar(profile.avatar_url, user, profile.profile_key, key)

                    with {:ok, _resp} <-
                           ex_aws_delete_request(
                             memories_bucket,
                             "uploads/user/#{user.id}/memories/**"
                           ),
                         {:ok, _resp} <-
                           ex_aws_delete_request(avatars_bucket, d_url),
                         {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, profile_avatar_url) do
                      socket =
                        socket
                        |> put_flash(
                          :success,
                          "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                        )
                        |> redirect(to: ~p"/")

                      {:noreply, socket}
                    else
                      _rest ->
                        ex_aws_delete_request(
                          memories_bucket,
                          "uploads/user/#{user.id}/memories/**"
                        )

                        ex_aws_delete_request(avatars_bucket, d_url)
                        ex_aws_delete_request(avatars_bucket, profile_avatar_url)

                        socket =
                          socket
                          |> put_flash(
                            :success,
                            "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                          )
                          |> redirect(to: ~p"/")

                        {:noreply, socket}
                    end
                  else
                    with {:ok, _resp} <-
                           ex_aws_delete_request(
                             memories_bucket,
                             "uploads/user/#{user.id}/memories/**"
                           ),
                         {:ok, _resp} <-
                           ex_aws_delete_request(avatars_bucket, d_url) do
                      socket =
                        socket
                        |> put_flash(
                          :success,
                          "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                        )
                        |> redirect(to: ~p"/")

                      {:noreply, socket}
                    else
                      _rest ->
                        ex_aws_delete_request(
                          memories_bucket,
                          "uploads/user/#{user.id}/memories/**"
                        )

                        ex_aws_delete_request(avatars_bucket, d_url)

                        socket =
                          socket
                          |> put_flash(
                            :success,
                            "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                          )
                          |> redirect(to: ~p"/")

                        {:noreply, socket}
                    end
                  end
                else
                  # No user avatar

                  socket =
                    socket
                    |> put_flash(
                      :success,
                      "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                    )
                    |> redirect(to: ~p"/")

                  {:noreply, socket}
                end
              else
                error ->
                  Logger.error(
                    "Error deleting Stripe Customer upon account deletion #{inspect(error)}"
                  )

                  Logger.debug(
                    "Error deleting Stripe Customer upon account deletion #{inspect(error)}"
                  )

                  socket =
                    socket
                    |> put_flash(
                      :info,
                      "Account deleted successfully but there was an error deleting your Stripe account. Please reach out to support@mosslet.com to ensure your Stripe account is deleted. We're sorry for any inconvenience."
                    )
                    |> redirect(to: ~p"/")

                  {:noreply, socket}
              end
            else
              # there is no stripe account
              if Map.get(user, :avatar_url) do
                avatars_bucket = Encrypted.Session.avatars_bucket()
                memories_bucket = Encrypted.Session.memories_bucket()
                d_url = decr_avatar(user.connection.avatar_url, user, user.conn_key, key)
                profile = Map.get(user.connection, :profile)

                # Handle deleting the object storage avatar and memories async.
                if profile do
                  profile_avatar_url =
                    decr_avatar(profile.avatar_url, user, profile.profile_key, key)

                  with {:ok, _resp} <-
                         ex_aws_delete_request(
                           memories_bucket,
                           "uploads/user/#{user.id}/memories/**"
                         ),
                       {:ok, _resp} <-
                         ex_aws_delete_request(avatars_bucket, d_url),
                       {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, profile_avatar_url) do
                    socket =
                      socket
                      |> put_flash(
                        :success,
                        "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                      )
                      |> redirect(to: ~p"/")

                    {:noreply, socket}
                  else
                    _rest ->
                      ex_aws_delete_request(
                        memories_bucket,
                        "uploads/user/#{user.id}/memories/**"
                      )

                      ex_aws_delete_request(avatars_bucket, d_url)
                      ex_aws_delete_request(avatars_bucket, profile_avatar_url)

                      socket =
                        socket
                        |> put_flash(
                          :success,
                          "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                        )
                        |> redirect(to: ~p"/")

                      {:noreply, socket}
                  end
                else
                  with {:ok, _resp} <-
                         ex_aws_delete_request(
                           memories_bucket,
                           "uploads/user/#{user.id}/memories/**"
                         ),
                       {:ok, _resp} <-
                         ex_aws_delete_request(avatars_bucket, d_url) do
                    socket =
                      socket
                      |> put_flash(
                        :success,
                        "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                      )
                      |> redirect(to: ~p"/")

                    {:noreply, socket}
                  else
                    _rest ->
                      ex_aws_delete_request(
                        memories_bucket,
                        "uploads/user/#{user.id}/memories/**"
                      )

                      ex_aws_delete_request(avatars_bucket, d_url)

                      socket =
                        socket
                        |> put_flash(
                          :success,
                          "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                        )
                        |> redirect(to: ~p"/")

                      {:noreply, socket}
                  end
                end
              else
                # No user avatar

                socket =
                  socket
                  |> put_flash(
                    :success,
                    "Your account and data were deleted successfully, it's all gone (even from Stripe). Thank you for trusting us with your attention, data, and time — come back whenever you want. ✌️"
                  )
                  |> redirect(to: ~p"/")

                {:noreply, socket}
              end
            end

          _error ->
            socket =
              socket
              |> put_flash(
                :info,
                "Account deleted successfully but there was an error canceling your subscription. Please reach out to support@mosslet.com to ensure your subscription was canceled. We're sorry for any inconvenience."
              )
              |> redirect(to: ~p"/")

            {:noreply, socket}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp cancel_subscription(_user, %{assigns: assigns} = socket) do
    provider_sub = assigns.provider_subscription_async.result

    if is_nil(provider_sub) do
      # Subscription doesn't exist, or is already canceled.
      :canceled
    else
      with {:ok, provider_subscription} <- billing_provider().cancel_subscription(provider_sub.id),
           %Subscription{} = subscription <-
             Subscriptions.get_subscription_by_provider_subscription_id(provider_subscription.id),
           {:ok, _suscription} <- Subscriptions.cancel_subscription(subscription) do
        :canceled
      else
        nil ->
          :canceled

        {:error, _reason} ->
          {
            :noreply,
            socket
            |> put_flash(:error, gettext("Something went wrong."))
            |> maybe_load_provider_data()
          }
      end
    end
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp maybe_load_provider_data(socket) do
    subscription = socket.assigns[:subscription]

    assign_async(socket, [:provider_subscription_async, :provider_product_async], fn ->
      case subscription do
        nil ->
          {:ok, %{provider_subscription_async: nil, provider_product_async: nil}}

        subscription ->
          {:ok, provider_subscription} =
            billing_provider().retrieve_subscription(subscription.provider_subscription_id)

          {:ok, provider_product} =
            provider_subscription
            |> billing_provider().get_subscription_product()
            |> billing_provider().retrieve_product()

          {:ok,
           %{
             provider_subscription_async: provider_subscription,
             provider_product_async: provider_product
           }}
      end
    end)
  end
end
