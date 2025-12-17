defmodule Mosslet.Encrypted.Native.Date do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for date fields.
  """
  use Cloak.Ecto.Date, vault: Mosslet.Vault.Native
end
