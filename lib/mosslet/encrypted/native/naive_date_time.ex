defmodule Mosslet.Encrypted.Native.NaiveDateTime do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for naive-date-time fields.
  """
  use Cloak.Ecto.NaiveDateTime, vault: Mosslet.Vault.Native
end
