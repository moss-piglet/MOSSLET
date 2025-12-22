defmodule Mosslet.Repo.Local.Migrations.AddAvailableAtToCommissions do
  use Ecto.Migration

  def change do
    alter table(:billing_commissions) do
      add :available_at, :utc_datetime
    end

    create index(:billing_commissions, [:available_at])
    create index(:billing_commissions, [:status, :available_at])
  end
end
