defmodule Mosslet.Encrypted.Native.Time do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for time fields.
  """
  use Cloak.Ecto.Time, vault: Mosslet.Vault.Native
end
