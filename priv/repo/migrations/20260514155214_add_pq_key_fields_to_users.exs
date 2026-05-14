defmodule Mosslet.Repo.Migrations.AddPqKeyFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :pq_public_key, :binary
      add :encrypted_pq_private_key, :binary
    end
  end
end
