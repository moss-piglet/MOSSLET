defmodule MossletWeb.DataTable.Filter do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:field, :string)
    field(:op, :string)
    field(:value, :string)
  end

  def changeset(zone, attrs) do
    cast(zone, attrs, [
      :field,
      :op,
      :value
    ])
  end
end
