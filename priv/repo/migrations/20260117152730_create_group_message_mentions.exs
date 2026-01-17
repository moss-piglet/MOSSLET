defmodule Mosslet.Repo.Local.Migrations.CreateGroupMessageMentions do
  use Ecto.Migration

  def change do
    create table(:group_message_mentions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :read_at, :naive_datetime

      add :group_message_id,
          references(:group_messages, on_delete: :delete_all, type: :binary_id), null: false

      add :mentioned_user_group_id,
          references(:user_groups, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:group_message_mentions, [:group_message_id])
    create index(:group_message_mentions, [:mentioned_user_group_id])
    create unique_index(:group_message_mentions, [:group_message_id, :mentioned_user_group_id])

    create index(:group_message_mentions, [:mentioned_user_group_id, :read_at],
             where: "read_at IS NULL",
             name: :group_message_mentions_unread_index
           )
  end
end
