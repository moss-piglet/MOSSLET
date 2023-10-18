defmodule Metamorphic.Repo.Migrations.UsersCustomerColumns do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :stripe_id, :string, null: true
      add :trial_ends_at, :utc_datetime, null: true
      add :payment_id, :string, null: true
      add :payment_type, :string, null: true
      add :payment_last_four, :string, size: 4, null: true
    end

    create unique_index(:users, [:stripe_id])
  end
end
