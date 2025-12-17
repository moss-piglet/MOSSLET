defmodule Mosslet.Platform.Security.Keychain.Linux do
  @moduledoc """
  Linux Secret Service API adapter.

  Uses libsecret / Secret Service API (GNOME Keyring, KWallet)
  to securely store the device encryption key.

  ## Implementation Notes

  This module uses NIFs or Port to interact with Secret Service.
  For initial implementation, we delegate to the Stub adapter.

  TODO: Implement native Linux integration via:
  - NIF using libsecret
  - Port calling secret-tool CLI
  - D-Bus interface to Secret Service
  """
  @behaviour Mosslet.Platform.Security.Keychain

  alias Mosslet.Platform.Security.Keychain.Stub

  @impl true
  def get(identifier) do
    # TODO: Implement Secret Service lookup
    # secret-tool lookup service mosslet key <identifier>
    Stub.get(identifier)
  end

  @impl true
  def store(identifier, secret) do
    # TODO: Implement Secret Service storage
    # echo <secret> | secret-tool store --label='Mosslet' service mosslet key <identifier>
    Stub.store(identifier, secret)
  end

  @impl true
  def delete(identifier) do
    # TODO: Implement Secret Service deletion
    # secret-tool clear service mosslet key <identifier>
    Stub.delete(identifier)
  end
end
