defmodule Mosslet.Logs do
  @moduledoc """
  A context file for CRUDing logs
  """

  import Ecto.Query, warn: false

  alias Mosslet.Extensions.Ecto.QueryExt
  alias Mosslet.Logs.Log
  alias Mosslet.Repo

  require Logger

  # Logs allow you to keep track of user activity.
  # This helps with both analytics and customer support (easy to look up a user and see what they've done)
  # If you don't want to store logs on your db, you could rewrite this file to send them to a 3rd
  # party service like https://www.datadoghq.com/

  def get(id), do: Repo.get(Log, id)

  def create(attrs \\ %{}) do
    case %Log{}
         |> Log.changeset(attrs)
         |> Repo.insert() do
      {:ok, log} ->
        MossletWeb.Endpoint.broadcast("logs", "new-log", log)
        {:ok, log}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def log(action, params) do
    action
    |> build(params)
    |> create()
  end

  def log_async(action, params) do
    Mosslet.BackgroundTask.run(fn ->
      log(action, params)
    end)
  end

  @doc """
  Builds a log from the given action and params.

  Examples:

      Mosslet.Logs.log("orgs.create_invitation", %{
        user: socket.assigns.current_user,
        target_user_id: nil,
        org_id: org.id,
      })

      # When one user performs an action on another user:
      Mosslet.Logs.log("orgs.delete_member", %{
        user: socket.assigns.current_user,
        target_user: member_user,
        org_id: org.id,
      })
  """
  def build(action, params) do
    user_id = if params[:user], do: params.user.id, else: params[:user_id]
    is_admin? = if params[:user], do: params.user.is_admin?, else: false

    org_id = if params[:org], do: params.org.id, else: params[:org_id]

    billing_customer_id =
      if params[:customer], do: params.customer.id, else: params[:billing_customer_id]

    target_user_id =
      if params[:target_user], do: params.target_user.id, else: params[:target_user_id]

    %{
      user_id: user_id,
      org_id: org_id,
      billing_customer_id: billing_customer_id,
      target_user_id: target_user_id,
      action: action,
      user_role: params[:user_role] || if(is_admin?, do: "admin", else: "user"),
      metadata: params[:metadata] || %{}
    }
  end

  @doc """
  Create a log as a multi.

  Examples:

      Ecto.Multi.new()
      |> Ecto.Multi.insert(:post, changeset)
      |> Logs.multi(fn %{post: post} ->
        Logs.build("post.insert", %{user: user, metadata: %{post_id: post.id}})
      end)
  """
  def multi(multi, fun) when is_function(fun) do
    multi
    |> Ecto.Multi.insert(:log, fn previous_multi_results ->
      log_params = fun.(previous_multi_results)
      Log.changeset(%Log{}, log_params)
    end)
    |> Ecto.Multi.run(:broadcast_log, fn _repo, %{log: log} ->
      MossletWeb.Endpoint.broadcast("logs", "new-log", log)
      {:ok, nil}
    end)
  end

  def exists?(params) do
    Log
    |> QueryBuilder.where(params)
    |> Mosslet.Repo.exists?()
  end

  def get_last_log_of_user(user) do
    user.id
    |> Mosslet.Logs.LogQuery.by_user()
    |> Mosslet.Logs.LogQuery.order_by(:newest)
    |> QueryExt.limit(1)
    |> Mosslet.Repo.one()
  end

  @doc """
  Deletes all logs older than the specified number of days.

  Returns the number of deleted records.

  ## Examples

      # Delete logs older than 7 days
      Logs.delete_logs_older_than(7)
      
      # Delete logs older than 30 days
      Logs.delete_logs_older_than(30)
  """
  def delete_logs_older_than(days) when is_integer(days) and days > 0 do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(l in Log, where: l.inserted_at < ^cutoff_date)
    |> Repo.delete_all()
  end

  @doc """
  Deletes logs containing sensitive metadata for privacy compliance.

  This specifically targets logs with email addresses or other PII.
  Returns the number of deleted records.
  """
  def delete_sensitive_logs do
    # Delete logs that contain email metadata (from before we removed email logging)
    from(l in Log,
      where: fragment("?->'new_email' IS NOT NULL", l.metadata)
    )
    |> Repo.delete_all()
  end

  @doc """
  Deletes all logs for a specific user. Useful for user deletion/GDPR compliance.

  Returns the number of deleted records.
  """
  def delete_user_logs(user_id) do
    from(l in Log,
      where: l.user_id == ^user_id or l.target_user_id == ^user_id
    )
    |> Repo.delete_all()
  end
end
