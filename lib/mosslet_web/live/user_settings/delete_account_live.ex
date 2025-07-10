defmodule MossletWeb.DeleteAccountLive do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  import MossletWeb.UserSettingsLayoutComponent
  import Mosslet.FileUploads.Storj

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Billing.Subscriptions.Subscription

  @billing_provider Application.compile_env(:mosslet, :billing_provider)

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:delete_account} current_user={@current_user} key={@key}>
      <.form
        for={@form}
        id="delete_account_form"
        phx-change="validate_delete_account"
        phx-submit="delete_account"
        class="max-w-prose"
      >
        <div class="mx-auto pb-6">
          <span class="inline-flex">
            <.icon name="hero-exclamation-triangle" class="text-rose-700 dark:text-rose-600 h-6 w-6" />
            <.h2 class="ml-2 text-lg font-semibold leading-6 text-rose-700 dark:text-rose-600">
              Delete your account
            </.h2>
          </span>
          <.p class="mt-1 text-sm text-gray-700">
            Enter your current password below to delete your account and its data. All of your data will be deleted in real-time and any subscription will be canceled. This cannot be undone.
          </.p>
        </div>

        <.field field={@form[:id]} type="hidden" value={@current_user.id} required />
        <div id="passwordField" class="relative">
          <div id="pw-label-container" class="flex justify-between">
            <div id="pw-actions" class="absolute top-0 right-0">
              <button
                type="button"
                id="eye"
                data-tippy-content="Show password"
                phx-hook="TippyHook"
                phx-click={
                  JS.set_attribute({"type", "text"}, to: "#current-password-for-delete-account")
                  |> JS.remove_class("hidden", to: "#eye-slash")
                  |> JS.add_class("hidden", to: "#eye")
                }
              >
                <.icon name="hero-eye" class="h-5 w-5 dark:text-white cursor-pointer" />
              </button>
              <button
                type="button"
                id="eye-slash"
                x-data
                x-tooltip="Hide password"
                data-tippy-content="Hide password"
                phx-hook="TippyHook"
                class="hidden"
                phx-click={
                  JS.set_attribute({"type", "password"}, to: "#current-password-for-delete-account")
                  |> JS.add_class("hidden", to: "#eye-slash")
                  |> JS.remove_class("hidden", to: "#eye")
                }
              >
                <.icon name="hero-eye-slash" class="h-5 w-5  dark:text-white cursor-pointer" />
              </button>
            </div>
          </div>
        </div>
        <.field
          field={@form[:current_password]}
          type="password"
          label={gettext("Current password")}
          id="current-password-for-delete-account"
          value={@current_password}
          required
          {alpine_autofocus()}
        />

        <.button color="danger" class="rounded-full" phx-disable-with="Deleting...">
          Delete Account
        </.button>
      </.form>
    </.settings_layout>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    {:ok,
     assign(socket,
       page_title: "Settings",
       current_password: nil,
       source: socket.assigns.live_action,
       billing_provider: @billing_provider,
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
      socket.assigns.current_user
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
    user = socket.assigns.current_user
    key = socket.assigns.key

    # if a stripe account hasn't been created yet
    stripe_customer_id =
      if user.customer[:provider_customer_id] do
        Mosslet.Encrypted.Users.Utils.decrypt_user_data(
          user.customer[:provider_customer_id],
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

  defp cancel_subscription(user, %{assigns: assigns} = socket) do
    provider_sub = assigns.provider_subscription_async.result

    if is_nil(provider_sub) do
      # Subscription doesn't exist, or is already canceled.
      :canceled
    else
      with {:ok, provider_subscription} <- @billing_provider.cancel_subscription(provider_sub.id),
           %Subscription{} = subscription <-
             Subscriptions.get_subscription_by_provider_subscription_id(provider_subscription.id),
           {:ok, _suscription} <- Subscriptions.cancel_subscription(subscription) do
        Accounts.user_lifecycle_action(
          "billing.cancel_subscription",
          user,
          %{
            subscription: subscription,
            customer: assigns.customer
          }
        )

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
            @billing_provider.retrieve_subscription(subscription.provider_subscription_id)

          {:ok, provider_product} =
            provider_subscription
            |> @billing_provider.get_subscription_product()
            |> @billing_provider.retrieve_product()

          {:ok,
           %{
             provider_subscription_async: provider_subscription,
             provider_product_async: provider_product
           }}
      end
    end)
  end
end
