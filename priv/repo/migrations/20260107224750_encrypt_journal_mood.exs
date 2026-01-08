defmodule Mosslet.Repo.Local.Migrations.EncryptJournalMood do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE journal_entries ALTER COLUMN mood TYPE bytea USING NULL"
  end

  def down do
    execute "ALTER TABLE journal_entries ALTER COLUMN mood TYPE varchar USING NULL"
  end
end
