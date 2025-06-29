defmodule Mosslet.Encrypted.Date do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for date fields.
  """
  use Cloak.Ecto.Date, vault: Mosslet.Vault
end
