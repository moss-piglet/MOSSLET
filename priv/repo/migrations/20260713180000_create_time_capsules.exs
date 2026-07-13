defmodule Mosslet.Repo.Migrations.CreateTimeCapsules do
  use Ecto.Migration

  @moduledoc """
  Time Capsules — encrypted "letters to your future self".

  ZK boundary: title/body are browser-encrypted with the user's user_key and
  stored as opaque ciphertext (:binary). The server NEVER sees the plaintext.

  The ONLY server-visible/queryable field is `deliver_on` (a plain date) plus
  lifecycle metadata (`sealed_at`, `opened_at`) and a cosmetic `stationery`
  enum used purely for letter styling. Visibility and the "a capsule opens
  today" notification are gated on this metadata alone.
  """

  def change do
    create table(:time_capsules, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Browser-encrypted (user_key) — opaque ciphertext, never read server-side.
      add :title, :binary
      add :body, :binary, null: false

      # Plaintext metadata — the ONLY thing the server sees/gates on.
      add :deliver_on, :date, null: false
      add :sealed_at, :utc_datetime
      # When the calm "a capsule opens today" delivery notification fired.
      # Null = not yet notified (delivery worker idempotency gate).
      add :notified_at, :utc_datetime
      # When the recipient actually opened/read the delivered letter.
      add :opened_at, :utc_datetime

      # Cosmetic letter styling (no content). Nullable; defaults handled in schema.
      add :stationery, :string

      add :word_count, :integer, default: 0

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:time_capsules, [:user_id])
    # Delivery worker scans by deliver_on for capsules not yet delivered.
    create index(:time_capsules, [:deliver_on])
    create index(:time_capsules, [:user_id, :deliver_on])
  end
end
