defmodule MossletWeb.DataTable.FilterSet do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias MossletWeb.DataTable.Filter

  embedded_schema do
    embeds_many(:filters, Filter, on_replace: :delete)
  end

  def changeset(filter_set, params \\ %{}) do
    filter_set
    |> cast(params, [])
    |> cast_embed(:filters)
  end

  def validate(changeset) do
    apply_action(changeset, :validate)
  end
end
