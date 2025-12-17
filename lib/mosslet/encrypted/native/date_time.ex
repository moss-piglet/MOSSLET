defmodule Mosslet.Encrypted.Native.DateTime do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for date-time fields.
  """
  use Cloak.Ecto.DateTime, vault: Mosslet.Vault.Native
end
