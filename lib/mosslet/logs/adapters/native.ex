defmodule Mosslet.Logs.Adapters.Native do
  @moduledoc """
  Native adapter for log operations on desktop/mobile apps.

  This adapter communicates with the cloud server via HTTP API.
  Logs are primarily a server-side concern for audit/analytics.

  ## Flow

  1. Log events are sent to the server via API
  2. Server stores logs in Postgres
  3. Log queries return from server (admin only)

  ## Note

  Most log operations are server-only (admin analytics, audit trails).
  Native apps send log events but don't query them directly.
  """

  @behaviour Mosslet.Logs.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync

  @impl true
  def get(_id) do
    nil
  end

  @impl true
  def create(attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"log" => log_data}} <- Client.create_log(token, attrs) do
        {:ok, deserialize_log(log_data)}
      else
        {:error, reason} ->
          Logger.warning("Failed to create log: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.debug("Offline - log event not sent")
      {:ok, %Mosslet.Logs.Log{}}
    end
  end

  @impl true
  def exists?(_params) do
    false
  end

  @impl true
  def get_last_log_of_user(_user_id) do
    nil
  end

  @impl true
  def delete_logs_older_than(_days) do
    {0, nil}
  end

  @impl true
  def delete_sensitive_logs do
    {0, nil}
  end

  @impl true
  def delete_user_logs(_user_id) do
    {0, nil}
  end

  defp deserialize_log(nil), do: nil

  defp deserialize_log(data) when is_map(data) do
    %Mosslet.Logs.Log{
      id: data["id"] || data[:id],
      user_id: data["user_id"] || data[:user_id],
      org_id: data["org_id"] || data[:org_id],
      target_user_id: data["target_user_id"] || data[:target_user_id],
      billing_customer_id: data["billing_customer_id"] || data[:billing_customer_id],
      action: data["action"] || data[:action],
      user_type: data["user_type"] || data[:user_type] || "user",
      metadata: data["metadata"] || data[:metadata] || %{},
      inserted_at: parse_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(dt), do: dt
end
