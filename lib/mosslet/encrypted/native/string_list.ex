defmodule Mosslet.Encrypted.Native.StringList do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for string-list fields.
  """
  use Cloak.Ecto.StringList, vault: Mosslet.Vault.Native
end
