defmodule Mosslet.Repo.Local.Migrations.AddReqDetailsToUserConnection do
  use Ecto.Migration

  def change do
    alter table(:user_connections) do
      add :request_username, :binary
      add :request_email, :binary
      add :request_username_hash, :binary
      add :request_email_hash, :binary
    end

    create unique_index(:user_connections, [:connection_id, :user_id, :request_username_hash])
    create unique_index(:user_connections, [:connection_id, :user_id, :request_email_hash])
  end
end
