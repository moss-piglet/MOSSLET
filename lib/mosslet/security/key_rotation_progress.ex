defmodule Mosslet.Security.KeyRotationProgress do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "key_rotation_progress" do
    field :schema_name, :string
    field :table_name, :string
    field :from_cipher_tag, :string
    field :to_cipher_tag, :string
    field :rotation_id, Ecto.UUID
    field :total_records, :integer, default: 0
    field :processed_records, :integer, default: 0
    field :failed_records, :integer, default: 0
    field :last_processed_id, :binary_id
    field :status, :string, default: "pending"
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :error_log, :string

    timestamps()
  end

  @statuses ~w(pending in_progress completed failed stalled cancelled)

  def changeset(progress, attrs) do
    progress
    |> cast(attrs, [
      :schema_name,
      :table_name,
      :from_cipher_tag,
      :to_cipher_tag,
      :rotation_id,
      :total_records,
      :processed_records,
      :failed_records,
      :last_processed_id,
      :status,
      :started_at,
      :completed_at,
      :error_log
    ])
    |> validate_required([:schema_name, :table_name, :from_cipher_tag, :to_cipher_tag])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:schema_name, :from_cipher_tag, :to_cipher_tag],
      name: :key_rotation_progress_schema_name_from_cipher_tag_to_cipher_tag
    )
  end

  def progress_percentage(%__MODULE__{total_records: 0}), do: 0

  def progress_percentage(%__MODULE__{total_records: total, processed_records: processed}) do
    round(processed / total * 100)
  end
end
