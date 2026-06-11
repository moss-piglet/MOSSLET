defmodule Mosslet.Repo.Migrations.CreateOrgsGuardianships do
  use Ecto.Migration

  def change do
    create table(:orgs_guardianships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all), null: false

      add :guardian_membership_id,
          references(:orgs_memberships, type: :binary_id, on_delete: :delete_all),
          null: false

      add :managed_membership_id,
          references(:orgs_memberships, type: :binary_id, on_delete: :delete_all),
          null: false

      # Plaintext system enum (non-sensitive) per encryption architecture guidelines.
      #   :pending  -> awaiting managed-member consent (no co-sealing yet)
      #   :active   -> consented, co-sealing on
      #   :paused   -> privacy toggle ON (stop future co-seals)
      #   :declined -> managed member refused (never co-sealed)
      add :status, :string, null: false, default: "pending"

      # false only when the managed member cannot self-consent (a minor account
      # the family admin set up). Such links may start :active.
      add :requires_consent, :boolean, null: false, default: true

      add :established_at, :utc_datetime
      add :consented_at, :utc_datetime
      add :paused_at, :utc_datetime

      timestamps()
    end

    create unique_index(:orgs_guardianships, [:guardian_membership_id, :managed_membership_id],
             name: :orgs_guardianships_guardian_managed_index
           )

    create index(:orgs_guardianships, [:org_id])
    create index(:orgs_guardianships, [:managed_membership_id])
    create index(:orgs_guardianships, [:guardian_membership_id])
  end
end
