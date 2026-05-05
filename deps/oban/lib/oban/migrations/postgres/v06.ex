defmodule Oban.Migrations.Postgres.V06 do
  @moduledoc false

  use Ecto.Migration

  def up(_opts) do
    # This used to modify oban_beats, which aren't included anymore
    :ok
  end

  def down(_opts) do
    # This used to modify oban_beats, which aren't included anymore
    :ok
  end
end
