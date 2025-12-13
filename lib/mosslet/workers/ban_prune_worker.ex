defmodule Mosslet.Workers.BanPruneWorker do
  @moduledoc """
  Oban worker that prunes old IP bans to prevent database bloat.

  Bans older than the retention period (default 90 days) are removed.
  This keeps the bans table manageable while retaining recent security data.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Mosslet.Security.IpBan
  alias Mosslet.Repo
  import Ecto.Query

  require Logger

  @default_retention_days 90

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    retention_days = Map.get(args, "retention_days", @default_retention_days)
    cutoff = DateTime.add(DateTime.utc_now(), -retention_days, :day)

    {:ok, {count, _}} =
      Repo.transaction_on_primary(fn ->
        from(b in IpBan, where: b.inserted_at < ^cutoff)
        |> Repo.delete_all()
      end)

    if count > 0 do
      Logger.info("[BanPruneWorker] Pruned #{count} bans older than #{retention_days} days")
    end

    :ok
  end
end
