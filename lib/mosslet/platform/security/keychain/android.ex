defmodule Mosslet.Platform.Security.Keychain.Android do
  @moduledoc """
  Android Keystore adapter.

  Uses Android Keystore system to securely store the device encryption key.
  The key is hardware-backed on supported devices.

  ## Implementation Notes

  This module requires JNI/Native bridge to interact with Android Keystore.
  For initial implementation, we delegate to the Stub adapter.

  TODO: Implement native Android integration via:
  - JNI bridge to Android Keystore API
  - Native code in the Android wrapper project
  """
  @behaviour Mosslet.Platform.Security.Keychain

  alias Mosslet.Platform.Security.Keychain.Stub

  @impl true
  def get(identifier) do
    # TODO: Implement Android Keystore lookup via JNI
    Stub.get(identifier)
  end

  @impl true
  def store(identifier, secret) do
    # TODO: Implement Android Keystore storage via JNI
    Stub.store(identifier, secret)
  end

  @impl true
  def delete(identifier) do
    # TODO: Implement Android Keystore deletion via JNI
    Stub.delete(identifier)
  end
end
