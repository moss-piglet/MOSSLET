defmodule Mosslet.Repo.Migrations.AddFlyPostgresProc do
  use Ecto.Migration

  # Neutralized after the fly_postgres removal (we now run on Fly Managed
  # Postgres and `Repo.transaction_on_primary/1` is a plain transaction shim).
  # The original migration called `Fly.Postgres.Migrations.V01.up/0`, but that
  # module no longer exists, which broke fresh DB creation (e.g. test DB setup).
  # Kept as a no-op to preserve the migration history/version ordering.
  def up, do: :ok

  def down, do: :ok
end
