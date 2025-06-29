defmodule Mosslet.Repo.Local.Migrations.CreateGroupMessages do
  use Ecto.Migration

  def change do
    create table(:group_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :binary

      add :sender_id, references(:user_groups, type: :binary_id, on_delete: :delete_all),
        null: false

      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end
  end
end
