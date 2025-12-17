defmodule Mosslet.Platform.Security.Keychain.Stub do
  @moduledoc """
  Stub keychain adapter for development and web platform.

  Stores keys in memory (ETS) for development/testing purposes.
  NOT suitable for production native apps - use platform-specific adapters.

  This adapter is automatically used when:
  - Running in web mode (no keychain needed)
  - Running tests
  - Development without native keychain integration
  """
  @behaviour Mosslet.Platform.Security.Keychain

  @table_name :mosslet_keychain_stub

  @impl true
  def get(identifier) do
    ensure_table_exists()

    case :ets.lookup(@table_name, identifier) do
      [{^identifier, secret}] -> {:ok, secret}
      [] -> :not_found
    end
  end

  @impl true
  def store(identifier, secret) do
    ensure_table_exists()
    :ets.insert(@table_name, {identifier, secret})
    :ok
  end

  @impl true
  def delete(identifier) do
    ensure_table_exists()
    :ets.delete(@table_name, identifier)
    :ok
  end

  defp ensure_table_exists do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:named_table, :set, :public])

      _ref ->
        :ok
    end
  end
end
