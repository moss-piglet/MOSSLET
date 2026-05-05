defmodule Oban.Migrations.Postgres.V09 do
  @moduledoc false

  use Ecto.Migration

  def up(%{prefix: prefix, quoted_prefix: quoted}) do
    alter table(:oban_jobs, prefix: prefix) do
      add_if_not_exists(:meta, :map, default: %{})
      add_if_not_exists(:cancelled_at, :utc_datetime_usec)
    end

    execute "ALTER TYPE #{quoted}.oban_job_state ADD VALUE IF NOT EXISTS 'cancelled'"

    create_if_not_exists index(:oban_jobs, [:state, :queue, :priority, :scheduled_at, :id],
                           prefix: prefix
                         )
  end

  def down(%{prefix: prefix, quoted_prefix: quoted}) do
    alter table(:oban_jobs, prefix: prefix) do
      remove_if_exists(:meta, :map)
      remove_if_exists(:cancelled_at, :utc_datetime_usec)
    end

    execute "UPDATE #{quoted}.oban_jobs SET state = 'discarded' WHERE state = 'cancelled'"
  end
end
