defmodule MossletWeb.EditTotpLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts

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
    <.settings_layout current_page={:edit_totp} current_user={@current_user} key={@key}>
      <div class="max-w-prose">
        <.h3>{gettext("Two-factor authentication")}</.h3>

        <%= if @current_totp do %>
          <div class="flex items-center gap-2 mb-6">
            <.icon solid name="hero-check-badge" class="w-10 h-10 text-green-600 dark:text-green-400" />

            <div class="font-semibold dark:text-gray-100">
              {gettext("2FA Enabled")}
            </div>
          </div>
        <% end %>

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
      </div>
    </.settings_layout>
    """
  end

  def totp_form(assigns) do
    ~H"""
    <div class="mb-10">
      <%= if @secret_display == :as_text do %>
        <div class="prose prose-gray dark:prose-invert">
          <p>
            To {if @current_totp, do: "change", else: "enable"} two-factor authentication, enter the secret below into your two-factor authentication app in your phone.
          </p>
        </div>

        <div class="flex items-center justify-start px-4 py-8 sm:px-0">
          <div class="p-5 border-4 border-gray-300 border-dashed rounded-lg dark:border-gray-700">
            <div class="text-xl font-bold" id="totp-secret">
              {format_secret(@editing_totp.secret)}
            </div>
          </div>
        </div>

        <div class="prose prose-gray dark:prose-invert">
          <p>
            Or <a href="#" class="underline" phx-click="display_secret_as_qrcode">scan the QR Code</a>
            instead.
          </p>
        </div>
      <% else %>
        <div class="prose prose-gray dark:prose-invert">
          <p>
            To {if @current_totp, do: "change", else: "enable"} two-factor authentication, scan the image below with the two-factor authentication app in your phone and then enter the  authentication code at the bottom. If you can't use QR Code,
            <a href="#" class="underline" phx-click="display_secret_as_text">enter your secret</a>
            manually.
          </p>
        </div>

        <div class="mt-10 text-center">
          <div class="inline-block">
            {generate_qrcode(@qrcode_uri)}
          </div>
        </div>
      <% end %>
    </div>

    <.form for={@totp_form} id="form-update-totp" phx-submit="update_totp">
      <.field
        field={@totp_form[:code]}
        label="Authentication code"
        placeholder="eg. 123456"
        autocomplete="one-time-code"
      />

      <div class="flex justify-end gap-2">
        <.button type="submit" class="rounded-full" phx-disable-with="Verifying...">
          Verify code
        </.button>
        <.button
          id="cancel-totp"
          class="rounded-full"
          type="button"
          color="secondary"
          phx-click="cancel_totp"
        >
          Cancel
        </.button>
      </div>
    </.form>

    <%= if @current_totp do %>
      <div class="mt-10 prose prose-gray dark:prose-invert">
        <p>
          You may also
          <a href="#" id="show-backup" class="underline" phx-click="show_backup_codes">
            see your available backup codes
          </a>
          or
          <a
            href="#"
            id="disable-totp"
            phx-click="disable_totp"
            data-confirm="Are you sure you want to disable Two-factor authentication?"
          >
            disable two-factor authentication
          </a>
          altogether.
        </p>
      </div>
    <% end %>
    """
  end

  def enable_form(assigns) do
    ~H"""
    <.form id="form-submit-totp" for={@user_form} phx-submit="submit_totp" phx-change="change_totp">
      <div class="pb-4">
        <.p :if={@current_totp}>
          Enter your current password to change 2FA or view your backup codes
        </.p>
        <.p :if={!@current_totp}>
          Enter your current password to enable 2FA
        </.p>
      </div>
      <div id="passwordField" class="relative">
        <div id="pw-label-container" class="flex justify-between">
          <div id="pw-actions" class="absolute top-0 right-0">
            <button
              type="button"
              id="eye"
              data-tippy-content="Show password"
              phx-hook="TippyHook"
              phx-click={
                JS.set_attribute({"type", "text"}, to: "#password")
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
                JS.set_attribute({"type", "password"}, to: "#password")
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
        id="password"
        type="password"
        field={@user_form[:current_password]}
        value={@current_password}
        phx-debounce="blur"
        placeholder="Enter your password"
        autocomplete="current-password"
        {alpine_autofocus()}
      />

      <.button
        phx-disable-with="Verifying..."
        class="rounded-full"
        label={if @current_totp, do: "Change", else: "Enable"}
      />
    </.form>
    """
  end

  def backup_codes(assigns) do
    ~H"""
    <.modal
      id="backup-codes-modal"
      title="Backup codes"
      on_cancel={Phoenix.LiveView.JS.push("hide_backup_codes")}
    >
      <div class="prose prose-gray dark:prose-invert">
        <p>
          Two-factor authentication is enabled. In case you lose access to your
          phone, you will need one of the backup codes below. <b>Keep these backup codes safe</b>. You can also generate
          new codes at any time.
        </p>
      </div>

      <div id="backup-codes-list" class="grid grid-cols-1 gap-3 mt-5 mb-10 md:grid-cols-2">
        <%= for backup_code <- @backup_codes do %>
          <div class="flex items-center justify-center p-3 font-mono bg-gray-300 rounded dark:bg-gray-700">
            <h4>
              <%= if backup_code.used_at do %>
                <del class="line-through">{backup_code.code}</del>
              <% else %>
                {backup_code.code}
              <% end %>
            </h4>
          </div>
        <% end %>
      </div>

      <div class="flex justify-between">
        <%= if @editing_totp do %>
          <.button
            type="button"
            color="white"
            class="rounded-full"
            id="regenerate-backup"
            phx-click="regenerate_backup_codes"
            data-confirm="Are you sure? This will generate new backup codes and invalidate the old ones."
            label="Regenerate backup codes"
          />
        <% else %>
          <div></div>
        <% end %>

        <.button
          id="close-backup-codes"
          label="Close"
          class="rounded-full"
          phx-click={Phoenix.LiveView.JS.push("hide_backup_codes")}
        />
      </div>
    </.modal>
    """
  end

  @impl true
  def handle_event("show_backup_codes", _, socket) do
    {:noreply, assign(socket, :backup_codes, socket.assigns.editing_totp.backup_codes)}
  end

  @impl true
  def handle_event("hide_backup_codes", _, socket) do
    {:noreply, assign(socket, :backup_codes, nil)}
  end

  @impl true
  def handle_event("regenerate_backup_codes", _, socket) do
    {:ok, totp} = Accounts.regenerate_user_totp_backup_codes(socket.assigns.editing_totp)

    socket =
      socket
      |> assign(:backup_codes, totp.backup_codes)
      |> assign(:editing_totp, totp)

    Mosslet.Logs.log_async("totp.regenerate_backup_codes", %{
      user: socket.assigns.current_user
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_totp", %{"user_totp" => params}, socket) do
    editing_totp = socket.assigns.editing_totp
    log_type = if is_nil(editing_totp.id), do: "totp.enable", else: "totp.update"

    case Accounts.upsert_user_totp(editing_totp, params) do
      {:ok, current_totp} ->
        Mosslet.Logs.log_async(log_type, %{user: socket.assigns.current_user})

        {:noreply,
         socket
         |> reset_assigns(current_totp)
         |> assign(:backup_codes, current_totp.backup_codes)}

      {:error, changeset} ->
        {:noreply, assign(socket, totp_form: to_form(changeset))}
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
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_totp", _, socket) do
    {:noreply, reset_assigns(socket, socket.assigns.current_totp)}
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
