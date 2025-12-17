defmodule Mosslet.Encrypted.Native.Binary do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for binary fields.
  """
  use Cloak.Ecto.Binary, vault: Mosslet.Vault.Native
end
