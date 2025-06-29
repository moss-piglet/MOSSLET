defmodule Mosslet.Encrypted.StringList do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for string-list fields.
  """
  use Cloak.Ecto.StringList, vault: Mosslet.Vault
end
