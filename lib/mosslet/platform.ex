defmodule Mosslet.Platform do
  @moduledoc """
  Platform detection and abstraction for Mosslet.

  Detects whether the app is running as:
  - `:web` - Traditional server deployment (Fly.io)
  - `:macos` - Native macOS desktop app
  - `:windows` - Native Windows desktop app
  - `:linux` - Native Linux desktop app
  - `:ios` - Native iOS mobile app
  - `:android` - Native Android mobile app

  This enables the same Phoenix/LiveView codebase to run in different
  deployment modes with platform-specific behavior.

  ## Detection Logic

  The platform is determined by the `MOSSLET_DESKTOP` environment variable:
  - If `MOSSLET_DESKTOP=true`, we're running as a native app and use Desktop.OS.type()
  - Otherwise, we're running as a web server

  This prevents false positives when the Desktop library is loaded during development
  but we're actually running as a web server.
  """

  @type platform :: :web | :macos | :windows | :linux | :ios | :android

  @doc """
  Returns the current platform type.

  ## Examples

      iex> Mosslet.Platform.type()
      :web

      # On a native macOS app (with MOSSLET_DESKTOP=true):
      iex> Mosslet.Platform.type()
      :macos
  """
  @spec type() :: platform()
  def type do
    cond do
      desktop_mode?() and desktop_available?() ->
        normalize_desktop_type(Desktop.OS.type())

      true ->
        :web
    end
  end

  @doc """
  Returns true if running as a native desktop/mobile app.
  """
  @spec native?() :: boolean()
  def native? do
    type() != :web
  end

  @doc """
  Returns true if running as a web server (traditional deployment).
  """
  @spec web?() :: boolean()
  def web? do
    type() == :web
  end

  @doc """
  Returns true if running on a desktop platform (macOS, Windows, Linux).
  """
  @spec desktop?() :: boolean()
  def desktop? do
    type() in [:macos, :windows, :linux]
  end

  @doc """
  Returns true if running on a mobile platform (iOS, Android).
  """
  @spec mobile?() :: boolean()
  def mobile? do
    type() in [:ios, :android]
  end

  @doc """
  Returns true if running on an Apple platform (macOS, iOS).
  """
  @spec apple?() :: boolean()
  def apple? do
    type() in [:macos, :ios]
  end

  @doc """
  Returns the appropriate billing provider module for the current platform.

  - iOS uses Apple In-App Purchase
  - Android uses Google Play Billing
  - All other platforms use Stripe
  """
  @spec billing_provider() :: module()
  def billing_provider do
    case type() do
      :ios -> Mosslet.Billing.Providers.AppleIAP
      :android -> Mosslet.Billing.Providers.GooglePlay
      _ -> Mosslet.Billing.Providers.Stripe
    end
  end

  @doc """
  Returns true if the platform requires in-app purchase billing.
  """
  @spec requires_iap?() :: boolean()
  def requires_iap? do
    type() in [:ios, :android]
  end

  @doc """
  Returns true if the platform supports Stripe payments directly.
  """
  @spec supports_stripe?() :: boolean()
  def supports_stripe? do
    not requires_iap?()
  end

  @doc """
  Returns true if encryption happens locally on the device (zero-knowledge).

  For native apps, enacl encryption runs on the device, meaning the server
  never sees plaintext data. For web, encryption happens server-side.
  """
  @spec zero_knowledge?() :: boolean()
  def zero_knowledge? do
    native?()
  end

  @doc """
  Returns the database adapter type for the current platform.

  - Native apps use SQLite for local storage
  - Web uses Postgres on the server
  """
  @spec database_type() :: :sqlite | :postgres
  def database_type do
    if native?(), do: :sqlite, else: :postgres
  end

  @doc """
  Returns platform-specific features and capabilities.
  """
  @spec capabilities() :: map()
  def capabilities do
    %{
      platform: type(),
      native: native?(),
      zero_knowledge: zero_knowledge?(),
      database: database_type(),
      billing_provider: billing_provider(),
      supports_push_notifications: native?(),
      supports_background_sync: native?(),
      supports_offline_mode: native?(),
      supports_file_picker: native?(),
      supports_deep_links: native?()
    }
  end

  defp desktop_mode? do
    System.get_env("MOSSLET_DESKTOP") == "true"
  end

  defp desktop_available? do
    Code.ensure_loaded?(Desktop.OS) and function_exported?(Desktop.OS, :type, 0)
  end

  defp normalize_desktop_type(type) do
    case type do
      MacOS -> :macos
      Windows -> :windows
      Linux -> :linux
      IOS -> :ios
      Android -> :android
      other -> other
    end
  end
end
