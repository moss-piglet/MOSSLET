defmodule Mosslet.Repo.Local.Migrations.AddObanResetTokenIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :oban_reset_token_id, :integer
    end
  end
end
