defmodule Mosslet.Statuses.Adapters.Native do
  @moduledoc """
  Native adapter for status operations on desktop/mobile apps.

  This adapter communicates with the cloud server via HTTP API and
  caches data locally in SQLite for offline support.

  ## Flow

  1. API calls go to Fly.io server
  2. Server validates and returns data
  3. Data cached locally for offline access
  4. Offline operations queued for sync

  ## Zero-Knowledge

  All encryption/decryption happens locally on the device.
  The server only sees encrypted blobs.
  """

  @behaviour Mosslet.Statuses.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync

  @impl true
  def update_user_status_multi(_user_changeset, _connection, _connection_attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user" => user_data}} <- Client.update_user_status(token, %{}) do
        {:ok, deserialize_user(user_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_error_message(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("status", "update", %{})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_status_visibility(_user, _changeset) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user" => user_data}} <- Client.update_user_status_visibility(token, %{}) do
        {:ok, deserialize_user(user_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_error_message(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot update status visibility"}
    end
  end

  @impl true
  def update_connection_status_visibility(_connection, _attrs) do
    :ok
  end

  @impl true
  def update_user_activity(_user, _changeset) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user" => user_data}} <- Client.track_user_activity(token, %{}) do
        {:ok, deserialize_user(user_data)}
      else
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot track activity"}
    end
  end

  @impl true
  def preload_connection(user) do
    user
  end

  defp deserialize_user(nil), do: nil

  defp deserialize_user(data) when is_map(data) do
    status =
      case data["status"] || data[:status] do
        nil -> :offline
        s when is_atom(s) -> s
        s when is_binary(s) -> String.to_existing_atom(s)
      end

    %Mosslet.Accounts.User{
      id: data["id"] || data[:id],
      status: status,
      status_message: data["status_message"] || data[:status_message],
      status_updated_at:
        parse_naive_datetime(data["status_updated_at"] || data[:status_updated_at]),
      connection: deserialize_connection(data["connection"] || data[:connection])
    }
  end

  defp deserialize_connection(nil), do: nil

  defp deserialize_connection(data) when is_map(data) do
    status =
      case data["status"] || data[:status] do
        nil -> :offline
        s when is_atom(s) -> s
        s when is_binary(s) -> String.to_existing_atom(s)
      end

    %Mosslet.Accounts.Connection{
      id: data["id"] || data[:id],
      status: status,
      status_message: data["status_message"] || data[:status_message],
      status_updated_at:
        parse_naive_datetime(data["status_updated_at"] || data[:status_updated_at])
    }
  end

  defp parse_naive_datetime(nil), do: nil

  defp parse_naive_datetime(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_naive_datetime(dt), do: dt

  defp build_error_message(errors) when is_map(errors) do
    errors
    |> Enum.map(fn {field, messages} ->
      "#{field}: #{Enum.join(List.wrap(messages), ", ")}"
    end)
    |> Enum.join("; ")
  end

  defp build_error_message(_), do: "Unknown error"
end
