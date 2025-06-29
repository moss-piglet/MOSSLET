defmodule Mosslet.Encrypted.Float do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for float fields.
  """
  use Cloak.Ecto.Float, vault: Mosslet.Vault
end
