defmodule Mosslet.Logs.Adapters.Web do
  @moduledoc """
  Web adapter for log operations.

  This adapter uses direct Postgres access via `Mosslet.Repo`.
  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Logs.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Extensions.Ecto.QueryExt
  alias Mosslet.Logs.Log
  alias Mosslet.Repo

  @impl true
  def get(id), do: Repo.get(Log, id)

  @impl true
  def create(attrs) do
    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end

  @impl true
  def exists?(params) do
    Log
    |> QueryBuilder.where(params)
    |> Repo.exists?()
  end

  @impl true
  def get_last_log_of_user(user_id) do
    user_id
    |> Mosslet.Logs.LogQuery.by_user()
    |> Mosslet.Logs.LogQuery.order_by(:newest)
    |> QueryExt.limit(1)
    |> Repo.one()
  end

  @impl true
  def delete_logs_older_than(days) when is_integer(days) and days > 0 do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(l in Log, where: l.inserted_at < ^cutoff_date)
    |> Repo.delete_all()
  end

  @impl true
  def delete_sensitive_logs do
    from(l in Log,
      where: fragment("?->'new_email' IS NOT NULL", l.metadata)
    )
    |> Repo.delete_all()
  end

  @impl true
  def delete_user_logs(user_id) do
    from(l in Log,
      where: l.user_id == ^user_id or l.target_user_id == ^user_id
    )
    |> Repo.delete_all()
  end
end
