defmodule Mosslet.Logs do
  @moduledoc """
  A context file for CRUDing logs.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Logs.Adapters.Web`
  - Native (Desktop/Mobile): API calls via `Mosslet.Logs.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.

  Note: Logs are primarily a server-side concern for audit/analytics.
  Native apps send log events to the server via API.
  """

  alias Mosslet.Logs.Log
  alias Mosslet.Platform

  require Logger

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.Logs.Adapters.Web
    end
  end

  def get(id), do: adapter().get(id)

  def create(attrs \\ %{}) do
    case adapter().create(attrs) do
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
      user_type: params[:user_type] || if(is_admin?, do: "admin", else: "user"),
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

  def exists?(params), do: adapter().exists?(params)

  def get_last_log_of_user(user) do
    adapter().get_last_log_of_user(user.id)
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
    adapter().delete_logs_older_than(days)
  end

  @doc """
  Deletes logs containing sensitive metadata for privacy compliance.

  This specifically targets logs with email addresses or other PII.
  Returns the number of deleted records.
  """
  def delete_sensitive_logs do
    adapter().delete_sensitive_logs()
  end

  @doc """
  Deletes all logs for a specific user. Useful for user deletion/GDPR compliance.

  Returns the number of deleted records.
  """
  def delete_user_logs(user_id) do
    adapter().delete_user_logs(user_id)
  end
end
