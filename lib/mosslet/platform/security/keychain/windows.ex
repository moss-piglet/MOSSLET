defmodule Mosslet.Platform.Security.Keychain.Windows do
  @moduledoc """
  Windows Credential Manager / DPAPI adapter.

  Uses Windows Data Protection API (DPAPI) or Credential Manager
  to securely store the device encryption key.

  ## Implementation Notes

  This module uses NIFs or Port to interact with Windows security APIs.
  For initial implementation, we delegate to the Stub adapter.

  TODO: Implement native Windows integration via:
  - NIF using Windows CryptoAPI
  - Port calling PowerShell/cmdkey
  - Erlang/Elixir Windows credential library
  """
  @behaviour Mosslet.Platform.Security.Keychain

  alias Mosslet.Platform.Security.Keychain.Stub

  @impl true
  def get(identifier) do
    # TODO: Implement Windows Credential Manager lookup
    Stub.get(identifier)
  end

  @impl true
  def store(identifier, secret) do
    # TODO: Implement Windows Credential Manager storage
    Stub.store(identifier, secret)
  end

  @impl true
  def delete(identifier) do
    # TODO: Implement Windows Credential Manager deletion
    Stub.delete(identifier)
  end
end
