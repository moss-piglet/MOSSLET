defmodule Mosslet.Platform.Security do
  @moduledoc """
  Device-specific security operations for native apps.

  Manages the device encryption key and HMAC secret used to add a Cloak-style
  AES-256-GCM encryption layer to locally cached data. This provides:

  - Defense-in-depth (attacker must break both enacl AND device key)
  - Post-quantum resistance for data at rest (AES-256 is quantum-resistant)
  - Consistency with cloud architecture (both use symmetric wrapping)

  ## Key Storage

  The device keys are stored in OS-native secure storage:
  - macOS: Keychain Services (non-syncing)
  - Windows: DPAPI / Credential Manager
  - Linux: Secret Service API (libsecret)
  - iOS: Keychain (device-only, not iCloud)
  - Android: Keystore

  ## Key Lifecycle

  - Generated once per device on first app launch
  - Never transmitted or synced between devices
  - Lost when device is wiped (cache rebuilds from cloud)
  - No admin rotation needed - key is device-local

  ## Security Model

  ```
  Device theft scenario:
    Attacker has: physical device + SQLite file
    Attacker needs: OS credentials to access keychain + user password for enacl
    Result: Data protected by two independent layers
  ```
  """

  alias Mosslet.Platform

  @encryption_key_identifier "mosslet_device_encryption_key"
  @hmac_secret_identifier "mosslet_device_hmac_secret"
  @key_length 32

  @doc """
  Gets or generates the device encryption key.

  Returns `{:ok, key}` where key is a 32-byte binary suitable for AES-256-GCM.
  The key is retrieved from the OS keychain if it exists, or generated and
  stored if this is the first run.

  On web platform, returns `{:error, :not_native}`.
  """
  @spec get_or_create_device_key() :: {:ok, binary()} | {:error, atom()}
  def get_or_create_device_key do
    get_or_create_keychain_secret(@encryption_key_identifier)
  end

  @doc """
  Gets or generates the device HMAC secret.

  Returns `{:ok, secret}` where secret is a 32-byte binary suitable for HMAC-SHA512.
  The secret is retrieved from the OS keychain if it exists, or generated and
  stored if this is the first run.

  On web platform, returns `{:error, :not_native}`.
  """
  @spec get_or_create_hmac_secret() :: {:ok, binary()} | {:error, atom()}
  def get_or_create_hmac_secret do
    get_or_create_keychain_secret(@hmac_secret_identifier)
  end

  @doc """
  Checks if a device encryption key exists in the keychain.
  """
  @spec device_key_exists?() :: boolean()
  def device_key_exists? do
    keychain_secret_exists?(@encryption_key_identifier)
  end

  @doc """
  Checks if a device HMAC secret exists in the keychain.
  """
  @spec hmac_secret_exists?() :: boolean()
  def hmac_secret_exists? do
    keychain_secret_exists?(@hmac_secret_identifier)
  end

  @doc """
  Deletes the device encryption key from the keychain.

  This will make all locally cached data unreadable. Use with caution.
  A new key will be generated on next access, and cache will rebuild from cloud.
  """
  @spec delete_device_key() :: :ok | {:error, atom()}
  def delete_device_key do
    keychain_adapter().delete(@encryption_key_identifier)
  end

  @doc """
  Deletes the device HMAC secret from the keychain.
  """
  @spec delete_hmac_secret() :: :ok | {:error, atom()}
  def delete_hmac_secret do
    keychain_adapter().delete(@hmac_secret_identifier)
  end

  @doc """
  Deletes all device security keys from the keychain.
  """
  @spec delete_all_keys() :: :ok | {:error, atom()}
  def delete_all_keys do
    with :ok <- delete_device_key(),
         :ok <- delete_hmac_secret() do
      :ok
    end
  end

  @doc """
  Returns the keychain adapter module for the current platform.
  """
  @spec keychain_adapter() :: module()
  def keychain_adapter do
    case Platform.type() do
      :macos -> Mosslet.Platform.Security.Keychain.MacOS
      :ios -> Mosslet.Platform.Security.Keychain.MacOS
      :windows -> Mosslet.Platform.Security.Keychain.Windows
      :linux -> Mosslet.Platform.Security.Keychain.Linux
      :android -> Mosslet.Platform.Security.Keychain.Android
      :web -> Mosslet.Platform.Security.Keychain.Stub
    end
  end

  defp get_or_create_keychain_secret(identifier) do
    if Platform.native?() do
      case keychain_adapter().get(identifier) do
        {:ok, key} -> {:ok, key}
        :not_found -> generate_and_store_secret(identifier)
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :not_native}
    end
  end

  defp keychain_secret_exists?(identifier) do
    case keychain_adapter().get(identifier) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp generate_and_store_secret(identifier) do
    secret = :crypto.strong_rand_bytes(@key_length)

    case keychain_adapter().store(identifier, secret) do
      :ok -> {:ok, secret}
      {:error, reason} -> {:error, reason}
    end
  end
end
