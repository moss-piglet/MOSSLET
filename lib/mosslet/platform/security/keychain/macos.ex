defmodule Mosslet.Platform.Security.Keychain.MacOS do
  @moduledoc """
  macOS/iOS Keychain Services adapter.

  Uses the macOS Keychain to securely store the device encryption key.
  The key is stored with `kSecAttrSynchronizable = false` to prevent
  iCloud Keychain sync (each device should have its own key).

  ## Implementation Notes

  This module uses NIFs or Port to interact with Keychain Services.
  For initial implementation, we delegate to the Stub adapter.

  TODO: Implement native Keychain integration via:
  - NIF using Security.framework
  - Port calling `security` CLI tool
  - Erlang/Elixir keychain library
  """
  @behaviour Mosslet.Platform.Security.Keychain

  alias Mosslet.Platform.Security.Keychain.Stub

  @impl true
  def get(identifier) do
    # TODO: Implement native Keychain lookup
    # security find-generic-password -a mosslet -s <identifier> -w
    Stub.get(identifier)
  end

  @impl true
  def store(identifier, secret) do
    # TODO: Implement native Keychain storage
    # security add-generic-password -a mosslet -s <identifier> -w <base64_secret>
    # With kSecAttrSynchronizable = false
    Stub.store(identifier, secret)
  end

  @impl true
  def delete(identifier) do
    # TODO: Implement native Keychain deletion
    # security delete-generic-password -a mosslet -s <identifier>
    Stub.delete(identifier)
  end
end
