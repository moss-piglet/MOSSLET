defmodule Mosslet.Encrypted.Integer do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for integer fields.
  """
  use Cloak.Ecto.Integer, vault: Mosslet.Vault
end
