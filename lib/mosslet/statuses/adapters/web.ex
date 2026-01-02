defmodule Mosslet.Statuses.Adapters.Web do
  @moduledoc """
  Web adapter for status operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Statuses.Adapter

  alias Mosslet.Repo
  alias Mosslet.Accounts.Connection

  @impl true
  def update_user_status_multi(user_changeset, connection, connection_attrs) do
    case Ecto.Multi.new()
         |> Ecto.Multi.update(:user, user_changeset)
         |> Ecto.Multi.update(:update_connection, fn %{user: _user} ->
           Connection.update_status_changeset(connection, %{
             status: connection_attrs.c_status,
             status_message: connection_attrs.c_status_message,
             status_message_hash: connection_attrs.c_status_message_hash,
             status_updated_at: connection_attrs.c_status_updated_at
           })
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_connection: _connection, user: user}} ->
        {:ok, user |> Repo.preload(:connection)}

      {:ok, {:ok, {:error, changeset}}} ->
        {:error, changeset}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:error, :update_user, changeset, _} ->
        {:error, changeset}

      _error ->
        {:error, "Error updating user status"}
    end
  end

  @impl true
  def update_user_status_visibility(_user, changeset) do
    case Repo.transaction_on_primary(fn ->
           case Repo.update(changeset) do
             {:ok, updated_user} ->
               if updated_user.connection_map do
                 update_connection_status_visibility(
                   updated_user.connection,
                   updated_user.connection_map
                 )
               end

               {:ok, updated_user |> Repo.preload(:connection)}

             {:error, changeset} ->
               {:error, changeset}
           end
         end) do
      {:ok, {:ok, user}} ->
        {:ok, user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      _error ->
        {:error, "Error updating user status visibility"}
    end
  end

  @impl true
  def update_connection_status_visibility(connection, connection_map) do
    mapped_attrs = %{
      status_visibility: connection_map[:c_status_visibility],
      status_visible_to_groups: connection_map[:c_status_visible_to_groups],
      status_visible_to_users: connection_map[:c_status_visible_to_users],
      status_visible_to_groups_user_ids: connection_map[:c_status_visible_to_groups_user_ids],
      show_online_presence: connection_map[:c_show_online_presence],
      presence_visible_to_groups: connection_map[:c_presence_visible_to_groups],
      presence_visible_to_users: connection_map[:c_presence_visible_to_users],
      presence_visible_to_groups_user_ids: connection_map[:c_presence_visible_to_groups_user_ids]
    }

    case Repo.transaction_on_primary(fn ->
           connection
           |> Connection.update_status_visibility_changeset(mapped_attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, _connection}} -> :ok
      _ -> :error
    end
  end

  @impl true
  def update_user_activity(_user, changeset) do
    case Repo.transaction_on_primary(fn ->
           Repo.update(changeset)
         end) do
      {:ok, {:ok, updated_user}} ->
        {:ok, updated_user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @impl true
  def preload_connection(user) do
    Repo.preload(user, :connection)
  end
end
