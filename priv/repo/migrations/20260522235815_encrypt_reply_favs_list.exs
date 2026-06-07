defmodule Mosslet.Repo.Migrations.EncryptReplyFavsList do
  use Ecto.Migration

  def change do
    alter table(:replies) do
      # Replace the plaintext uuid[] column with an encrypted binary column.
      # Existing favs_list data (5 rows) will be lost — the favs_count column
      # is retained and stays accurate, so the UI still shows correct counts.
      # The encrypted column will be populated on the next fav toggle.
      remove :favs_list, {:array, :uuid}, default: []

      add :favs_list, :binary
      add :favs_list_hash, :binary
    end
  end
end
