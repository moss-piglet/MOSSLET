defmodule MossletWeb.API.StatusController do
  @moduledoc """
  API endpoints for user status operations.

  Handles status updates, visibility settings, and activity tracking.
  All encrypted data is passed through as-is - native apps handle
  encryption/decryption locally for zero-knowledge operation.
  """
  use MossletWeb, :controller

  alias Mosslet.Statuses

  action_fallback MossletWeb.API.FallbackController

  def update_status(conn, params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "status" => params["status"],
      "status_message" => decode_binary(params["status_message"]),
      "connection_map" => decode_connection_map(params["connection_map"])
    }

    case Statuses.update_user_status(user, attrs, key: session_key, user: user) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Status updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_status_visibility(conn, params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "status_visibility" => params["status_visibility"],
      "show_online_presence" => params["show_online_presence"],
      "status_visible_to_groups" => params["status_visible_to_groups"],
      "status_visible_to_users" => params["status_visible_to_users"],
      "presence_visible_to_groups" => params["presence_visible_to_groups"],
      "presence_visible_to_users" => params["presence_visible_to_users"],
      "connection_map" => decode_connection_map(params["connection_map"])
    }

    case Statuses.update_user_status_visibility(user, attrs, key: session_key, user: user) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Status visibility updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def track_activity(conn, params) do
    user = conn.assigns.current_user

    activity_type =
      case params["activity_type"] do
        "post" -> :post
        "interaction" -> :interaction
        _ -> :general
      end

    case Statuses.track_user_activity(user, activity_type) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Activity tracked successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp serialize_user(user) do
    %{
      id: user.id,
      status: user.status,
      status_message: encode_binary(user.status_message),
      status_updated_at: user.status_updated_at,
      status_visibility: user.status_visibility,
      show_online_presence: user.show_online_presence,
      last_activity_at: user.last_activity_at,
      last_post_at: user.last_post_at,
      auto_status: user.auto_status,
      updated_at: user.updated_at
    }
  end

  defp encode_binary(nil), do: nil
  defp encode_binary(data) when is_binary(data), do: Base.encode64(data)

  defp decode_binary(nil), do: nil

  defp decode_binary(data) when is_binary(data) do
    case Base.decode64(data) do
      {:ok, decoded} -> decoded
      :error -> data
    end
  end

  defp decode_connection_map(nil), do: %{}

  defp decode_connection_map(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {"c_status", v}, acc ->
        Map.put(acc, :c_status, v)

      {"c_status_message", v}, acc ->
        Map.put(acc, :c_status_message, decode_binary(v))

      {"c_status_message_hash", v}, acc ->
        Map.put(acc, :c_status_message_hash, decode_binary(v))

      {"c_status_updated_at", v}, acc ->
        Map.put(acc, :c_status_updated_at, parse_datetime(v))

      {"c_status_visibility", v}, acc ->
        Map.put(acc, :c_status_visibility, v)

      {"c_show_online_presence", v}, acc ->
        Map.put(acc, :c_show_online_presence, v)

      {"c_status_visible_to_groups", v}, acc ->
        Map.put(acc, :c_status_visible_to_groups, v)

      {"c_status_visible_to_users", v}, acc ->
        Map.put(acc, :c_status_visible_to_users, v)

      {"c_status_visible_to_groups_user_ids", v}, acc ->
        Map.put(acc, :c_status_visible_to_groups_user_ids, v)

      {"c_presence_visible_to_groups", v}, acc ->
        Map.put(acc, :c_presence_visible_to_groups, v)

      {"c_presence_visible_to_users", v}, acc ->
        Map.put(acc, :c_presence_visible_to_users, v)

      {"c_presence_visible_to_groups_user_ids", v}, acc ->
        Map.put(acc, :c_presence_visible_to_groups_user_ids, v)

      _, acc ->
        acc
    end)
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(dt) when is_struct(dt, NaiveDateTime), do: dt

  defp parse_datetime(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end
end
