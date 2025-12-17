defmodule Mosslet.Platform.Security.Keychain do
  @moduledoc """
  Behaviour for platform-specific keychain adapters.

  Each platform implements secure storage differently:
  - macOS/iOS: Keychain Services
  - Windows: DPAPI / Credential Manager
  - Linux: Secret Service API (libsecret)
  - Android: Keystore

  All adapters must implement the same interface for storing,
  retrieving, and deleting binary secrets.
  """

  @doc """
  Retrieves a secret from the keychain by identifier.

  Returns `{:ok, binary}` if found, `:not_found` if the key doesn't exist,
  or `{:error, reason}` on failure.
  """
  @callback get(identifier :: String.t()) :: {:ok, binary()} | :not_found | {:error, atom()}

  @doc """
  Stores a secret in the keychain with the given identifier.

  Returns `:ok` on success or `{:error, reason}` on failure.
  The secret should be stored with appropriate security attributes
  (e.g., non-syncing on Apple platforms).
  """
  @callback store(identifier :: String.t(), secret :: binary()) :: :ok | {:error, atom()}

  @doc """
  Deletes a secret from the keychain by identifier.

  Returns `:ok` on success (including if the key didn't exist)
  or `{:error, reason}` on failure.
  """
  @callback delete(identifier :: String.t()) :: :ok | {:error, atom()}
end
