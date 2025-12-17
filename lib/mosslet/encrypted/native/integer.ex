defmodule Mosslet.Encrypted.Native.Integer do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for integer fields.
  """
  use Cloak.Ecto.Integer, vault: Mosslet.Vault.Native
end
