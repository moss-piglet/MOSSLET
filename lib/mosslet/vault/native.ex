defmodule Mosslet.Vault.Native do
  @moduledoc """
  Cloak Vault for native device cache encryption.

  Uses a device-specific AES-256-GCM key stored in the OS keychain.
  This provides a symmetric encryption layer for locally cached data,
  adding post-quantum resistance on top of the existing enacl layer.

  ## Architecture

  ```
  Cloud Vault:   enacl blob → Cloak (CLOAK_KEY from env) → Postgres
  Native Vault:  enacl blob → Cloak (device key from keychain) → SQLite
  ```

  ## Key Management

  Unlike the cloud Vault which uses environment variables, this vault
  retrieves its key from the OS-native keychain at runtime:

  - macOS: Keychain Services
  - Windows: DPAPI / Credential Manager
  - Linux: Secret Service API
  - iOS/Android: Native keystores

  ## Key Rotation

  No rotation needed - the device key is:
  - Unique per device (never shared)
  - Stored in OS-protected keychain
  - Only protects disposable cache data
  - Lost when device is wiped (cache rebuilds from cloud)

  ## Usage

  This vault is only started on native platforms. On web, the standard
  `Mosslet.Vault` is used for Postgres data, and no cache encryption is needed.
  """
  use Cloak.Vault, otp_app: :mosslet

  alias Mosslet.Platform
  alias Mosslet.Platform.Security

  @impl GenServer
  def init(config) do
    case get_device_key() do
      {:ok, key} ->
        ciphers = [
          {:default, {Cloak.Ciphers.AES.GCM, tag: "NATIVE.V1", key: key}}
        ]

        config = Keyword.put(config, :ciphers, ciphers)
        {:ok, config}

      {:error, reason} ->
        {:stop, {:device_key_error, reason}}
    end
  end

  @doc """
  Returns true if this vault should be started (only on native platforms).
  """
  def should_start? do
    Platform.native?()
  end

  @doc """
  Returns the current cipher tag.
  """
  def current_cipher_tag do
    "NATIVE.V1"
  end

  defp get_device_key do
    Security.get_or_create_device_key()
  end
end
