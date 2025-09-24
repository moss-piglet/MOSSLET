defmodule Mosslet.Repo.Local.Migrations.AddFavsToReplies do
  use Ecto.Migration

  def change do
    alter table(:replies) do
      add :favs_list, {:array, :binary_id}, default: []
      add :favs_count, :integer, default: 0
    end
  end
end
