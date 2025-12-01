defmodule Mosslet.Repo.Local.Migrations.AddFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_signed_in_ip, :string
      add :last_signed_in_datetime, :utc_datetime
      add :calm_notifications, :boolean, null: false, default: true
    end

    create index(:users, [:is_deleted?, :is_suspended?])
  end
end
