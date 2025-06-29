defmodule Mosslet.Encrypted.IntegerList do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for integer-list fields.
  """
  use Cloak.Ecto.IntegerList, vault: Mosslet.Vault
end
