defmodule Mosslet.Encrypted.MapList do
  @moduledoc """
  Cloak.Ecto module for implementing encryption
  functionality for list of maps fields.

  Stores the list as JSON in an encrypted binary field.
  """

  use Cloak.Ecto.Type, vault: Mosslet.Vault

  def cast(closure) when is_function(closure, 0) do
    cast(closure.())
  end

  def cast(nil), do: {:ok, nil}

  def cast(value) when is_list(value) do
    if Enum.all?(value, &is_map/1) do
      {:ok, value}
    else
      :error
    end
  end

  def cast(_), do: :error

  def before_encrypt(value) do
    Jason.encode!(value)
  end

  def after_decrypt(json) do
    Jason.decode!(json)
  end
end
