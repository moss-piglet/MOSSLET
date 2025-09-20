defmodule Mosslet.Repo.Local.Migrations.AddUserStatusSystem do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Personal status fields (encrypted with user_key like other personal data)
      # Enum field (plaintext system data)
      add :status, :string, default: "offline"
      # Encrypted status message (user_key)
      add :status_message, :binary
      # Hash for searching status messages
      add :status_message_hash, :binary
      # Timestamp (plaintext system data)
      add :status_updated_at, :naive_datetime
      # System flag (plaintext)
      add :auto_status, :boolean, default: true

      # Activity tracking for auto-status
      # Timestamp (plaintext system data)
      add :last_activity_at, :naive_datetime
      # Timestamp for post activity
      add :last_post_at, :naive_datetime
    end

    # Update connections table to include status in shared profile data
    # This follows the same pattern as connection.username, connection.email, etc.
    alter table(:connections) do
      # Connection-shared status (encrypted with conn_key for sharing with connections)
      # Current status visible to connections
      add :status, :string, default: "offline"
      # Encrypted status message (conn_key)
      add :status_message, :binary
      # Hash for connection status messages
      add :status_message_hash, :binary
      # When status was last updated
      add :status_updated_at, :naive_datetime
    end

    # Add indexes for performance
    create index(:users, [:status])
    create index(:users, [:status_updated_at])
    create index(:users, [:last_activity_at])
    create index(:users, [:auto_status])
    create index(:connections, [:status])
    create index(:connections, [:status_updated_at])
  end
end
