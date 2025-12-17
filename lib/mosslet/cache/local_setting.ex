defmodule Mosslet.Cache.LocalSetting do
  @moduledoc """
  Schema for storing local-only settings and preferences.

  These settings are device-specific and don't sync to the cloud.
  Examples: last sync timestamp, UI preferences, etc.

  Sensitive values are encrypted with the device-specific key.

  Fields:
  - `key` - Setting identifier (unique)
  - `value` - Setting value (encrypted with device key)
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted.Native

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "local_settings" do
    field :key, :string
    field :value, Native.Binary

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
