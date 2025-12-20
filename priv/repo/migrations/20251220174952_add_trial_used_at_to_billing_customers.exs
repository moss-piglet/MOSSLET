defmodule Mosslet.Repo.Local.Migrations.AddTrialUsedAtToBillingCustomers do
  use Ecto.Migration

  def change do
    alter table(:billing_customers) do
      add :trial_used_at, :utc_datetime
    end
  end
end
