defmodule Mosslet.Repo.Migrations.AddMosskeysIndexToKeyHistoryEntries do
  use Ecto.Migration

  # Transparency-log anchoring bookkeeping.
  #
  # When a key-history entry is published to the mosskeys transparency log, the
  # log returns the entry's global tree `index`. Recording it here lets us:
  #
  #   - find entries that still need publishing (`WHERE mosskeys_index IS NULL`)
  #     — the backfill worker's query, which also heals every entry written
  #     while the publish path was misconfigured;
  #   - keep publishing idempotent at OUR layer too (already idempotent
  #     server-side on mosskeys' content `dedup_key`).
  #
  # Pure bookkeeping, never read by clients; the entry content stays
  # append-only. Online-safe (additive nullable column, no default/backfill).
  def change do
    alter table(:key_history_entries) do
      add :mosskeys_index, :integer
    end

    # Partial index keeps the backfill scan (`WHERE mosskeys_index IS NULL`)
    # to only the rows that still need publishing.
    create index(:key_history_entries, [:mosskeys_index],
             where: "mosskeys_index IS NULL",
             name: :key_history_entries_unanchored_index
           )
  end
end
