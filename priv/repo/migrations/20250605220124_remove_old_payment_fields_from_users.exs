defmodule Mosslet.Repo.Local.Migrations.RemoveOldPaymentFieldsFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :payment_type
      remove :payment_id
      remove :payment_last_four
    end

    rename table(:users), :encrypted_payment_type, to: :payment_type
    rename table(:users), :encrypted_payment_id, to: :payment_id
    rename table(:users), :encrypted_payment_last_four, to: :payment_last_four
  end
end
