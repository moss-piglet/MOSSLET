defmodule Mosslet.Repo.Local.Migrations.RemoveOldLastSignedInFieldOnUsersForEncryption do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :last_signed_in_ip
    end

    rename table(:users), :encrypted_last_signed_in_ip, to: :last_signed_in_ip
  end
end
