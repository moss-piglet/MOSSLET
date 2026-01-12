defmodule Mosslet.Backups.DatabaseBackup do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "database_backups" do
    field :filename, :string
    field :storage_key, :string
    field :size_bytes, :integer
    field :status, :string, default: "in_progress"
    field :backup_type, :string, default: "scheduled"
    field :error_message, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(backup, attrs) do
    backup
    |> cast(attrs, [
      :filename,
      :storage_key,
      :size_bytes,
      :status,
      :backup_type,
      :error_message,
      :metadata
    ])
    |> validate_required([:filename, :storage_key, :status, :backup_type])
    |> validate_inclusion(:status, ~w(in_progress completed failed))
    |> validate_inclusion(:backup_type, ~w(scheduled manual))
  end
end
