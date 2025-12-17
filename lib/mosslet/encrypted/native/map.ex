defmodule Mosslet.Encrypted.Native.Map do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for map fields.
  """
  use Cloak.Ecto.Map, vault: Mosslet.Vault.Native
end
