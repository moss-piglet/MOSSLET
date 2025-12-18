defmodule Mosslet.Accounts.Adapters.Web do
  @moduledoc """
  Web adapter for account operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes. It preserves all
  existing functionality from the original Accounts context.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Accounts.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Repo

  alias Mosslet.Accounts.{
    Connection,
    User,
    UserConnection,
    UserToken
  }

  @impl true
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email_hash: email)
    if User.valid_password?(user, password), do: user
  end

  @impl true
  def register_user(%Ecto.Changeset{} = user_changeset, c_attrs \\ %{}) do
    case Repo.transaction_on_primary(fn ->
           Ecto.Multi.new()
           |> Ecto.Multi.insert(:insert_user, user_changeset)
           |> Ecto.Multi.insert(:insert_connection, fn %{insert_user: user} ->
             Connection.register_changeset(%Connection{}, %{
               email: c_attrs.c_email,
               email_hash: c_attrs.c_email_hash,
               username: c_attrs.c_username,
               username_hash: c_attrs.c_username_hash
             })
             |> Ecto.Changeset.put_assoc(:user, user)
           end)
           |> Repo.transaction_on_primary()
         end) do
      {:ok, {:ok, %{insert_user: user, insert_connection: _conn}}} ->
        broadcast_admin({:ok, user}, :account_registered)
        {:ok, user}

      {:ok, {:error, :insert_user, changeset, _map}} ->
        {:error, changeset}

      {:ok, error} ->
        {:error, error}
    end
  end

  @impl true
  def get_user(id), do: Repo.get(User, id)

  @impl true
  def get_user!(id), do: Repo.get!(User, id)

  @impl true
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email_hash: email)
  end

  @impl true
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username_hash: username)
  end

  @impl true
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    Repo.one(query)
    |> Repo.preload([:connection, :customer])
  end

  @impl true
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)

    Repo.transaction_on_primary(fn ->
      Repo.insert!(user_token)
    end)

    token
  end

  @impl true
  def delete_user_session_token(token) do
    {:ok, {_count, _user_tokens}} =
      Repo.transaction_on_primary(fn ->
        Repo.delete_all(UserToken.token_and_context_query(token, "session"))
      end)

    :ok
  end

  @impl true
  def get_user_with_preloads(id) do
    Repo.one(from u in User, where: u.id == ^id, preload: [:connection, :user_connections])
  end

  @impl true
  def get_user_from_profile_slug(slug) do
    Repo.one(
      from u in User, where: u.username_hash == ^slug, preload: [:connection, :user_connections]
    )
  end

  @impl true
  def get_user_from_profile_slug!(slug) do
    Repo.one!(
      from u in User, where: u.username_hash == ^slug, preload: [:connection, :user_connections]
    )
  end

  @impl true
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction_on_primary(confirm_user_multi(user)) do
      broadcast_admin({:ok, user}, :account_confirmed)
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  @impl true
  def get_connection(id), do: Repo.get(Connection, id)

  @impl true
  def get_connection!(id), do: Repo.get!(Connection, id)

  @impl true
  def get_user_connection(id) do
    Repo.get(UserConnection, id) |> Repo.preload([:connection, :user])
  end

  @impl true
  def get_user_connection!(id) do
    Repo.get!(UserConnection, id) |> Repo.preload([:connection, :user])
  end

  @impl true
  def create_user_connection(attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           %UserConnection{}
           |> UserConnection.changeset(attrs, opts)
           |> Repo.insert()
         end) do
      {:ok, {:ok, uconn}} ->
        {:ok, uconn |> Repo.preload([:user, :connection])}
        |> broadcast(:uconn_created)

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_user_connection(uconn, attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           uconn
           |> UserConnection.changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, uconn}} ->
        {:ok, uconn |> Repo.preload([:user, :connection])}
        |> broadcast(:uconn_updated)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def delete_user_connection(%UserConnection{} = uconn) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(uconn)
         end) do
      {:ok, {:ok, uconn}} ->
        {:ok, uconn}
        |> broadcast(:uconn_deleted)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def confirm_user_connection(uconn, attrs, opts \\ []) do
    case Repo.transaction_on_primary(fn ->
           Ecto.Multi.new()
           |> Ecto.Multi.update(:update_uconn, UserConnection.confirm_changeset(uconn))
           |> Ecto.Multi.insert(
             :insert_uconn,
             UserConnection.changeset(%UserConnection{}, attrs, opts)
           )
           |> Repo.transaction_on_primary()
         end) do
      {:ok, {:ok, %{update_uconn: upd_uconn, insert_uconn: ins_uconn}}} ->
        case Ecto.Multi.new()
             |> Ecto.Multi.update(
               :upd_insert_uconn,
               UserConnection.confirm_changeset(ins_uconn)
             )
             |> Repo.transaction_on_primary() do
          {:ok, %{upd_insert_uconn: ins_uconn}} ->
            broadcast_user_connections([upd_uconn, ins_uconn], :uconn_confirmed)
            {:ok, upd_uconn, ins_uconn}

          {:ok, {:error, changeset}} ->
            {:error, changeset}

          _rest ->
            {:error, "error"}
        end

      {:ok, {:ok, {:error, changeset}}} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def filter_user_connections(_filter, user) do
    blocked_user_ids =
      user
      |> list_blocked_users()
      |> Enum.map(& &1.blocked_id)

    UserConnection
    |> where_user(user)
    |> where_confirmed()
    |> where_not_blocked(blocked_user_ids)
    |> order_by([uc], desc: uc.confirmed_at)
    |> preload([:connection])
    |> Repo.all()
  end

  @impl true
  def list_user_connections_for_sync(user, opts \\ []) do
    since = opts[:since]

    query =
      from(uc in UserConnection,
        join: c in assoc(uc, :connection),
        where: uc.user_id == ^user.id,
        where: not is_nil(uc.confirmed_at),
        order_by: [desc: c.updated_at],
        preload: [:connection]
      )

    query =
      if since do
        from([uc, c] in query, where: c.updated_at > ^since)
      else
        query
      end

    Repo.all(query)
  end

  defp where_user(query, %User{} = user) do
    from(uc in query, where: uc.user_id == ^user.id)
  end

  defp where_user(query, _user), do: query

  defp where_confirmed(query) do
    from(uc in query, where: not is_nil(uc.confirmed_at))
  end

  defp where_not_blocked(query, blocked_user_ids) when is_list(blocked_user_ids) do
    case blocked_user_ids do
      [] -> query
      ids -> from(uc in query, where: uc.reverse_user_id not in ^ids)
    end
  end

  defp list_blocked_users(user) do
    alias Mosslet.Accounts.UserBlock

    query =
      from b in UserBlock,
        where: b.blocker_id == ^user.id,
        preload: [:blocked],
        order_by: [desc: b.inserted_at]

    Repo.all(query)
  end

  defp broadcast({:ok, %UserConnection{} = uconn}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "accounts:#{uconn.user_id}", {event, uconn})
    {:ok, uconn}
  end

  defp broadcast_admin({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "admin:accounts", {event, struct})
    {:ok, struct}
  end

  defp broadcast_user_connections(uconns, event) when is_list(uconns) do
    Enum.each(uconns, fn uconn ->
      {:ok, uconn |> Repo.preload([:user, :connection])}
      |> broadcast(event)
    end)
  end

  @impl true
  def preload_connection(%User{} = user) do
    user |> Repo.preload([:connection])
  end

  @impl true
  def has_user_connection?(%User{} = user, current_user) do
    query =
      from uc in UserConnection,
        where: uc.user_id == ^user.id and uc.reverse_user_id == ^current_user.id,
        or_where: uc.reverse_user_id == ^user.id and uc.user_id == ^current_user.id

    Repo.exists?(query)
  end

  @impl true
  def has_confirmed_user_connection?(%User{} = user, current_user_id) do
    query =
      from uc in UserConnection,
        where:
          uc.user_id == ^user.id and uc.reverse_user_id == ^current_user_id and
            not is_nil(uc.confirmed_at),
        or_where:
          uc.reverse_user_id == ^user.id and uc.user_id == ^current_user_id and
            not is_nil(uc.confirmed_at)

    Repo.exists?(query)
  end

  @impl true
  def has_any_user_connections?(nil), do: nil

  def has_any_user_connections?(user) do
    query =
      from uc in UserConnection,
        where: uc.user_id == ^user.id or uc.reverse_user_id == ^user.id,
        where: not is_nil(uc.confirmed_at)

    Repo.exists?(query)
  end

  @impl true
  def filter_user_arrivals(_filter, user) do
    UserConnection
    |> where_user(user)
    |> where_not_confirmed()
    |> order_by([uc], desc: uc.inserted_at)
    |> preload([:connection])
    |> Repo.all()
  end

  @impl true
  def arrivals_count(user) do
    query =
      from uc in UserConnection,
        where: uc.user_id == ^user.id,
        where: is_nil(uc.confirmed_at)

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def list_user_arrivals_connections(user, options) do
    from(uc in UserConnection,
      where: uc.user_id == ^user.id,
      where: is_nil(uc.confirmed_at),
      preload: [:user, :connection]
    )
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @impl true
  def delete_both_user_connections(%UserConnection{} = uconn) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete_all(
             from uc in UserConnection,
               where: uc.id == ^uconn.id,
               or_where:
                 uc.reverse_user_id == ^uconn.user_id and uc.user_id == ^uconn.reverse_user_id,
               or_where:
                 uc.user_id == ^uconn.reverse_user_id and uc.reverse_user_id == ^uconn.user_id,
               select: uc
           )
         end) do
      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:ok, {_count, uconns}} ->
        broadcast_user_connections(uconns, :uconn_deleted)
        {:ok, uconns}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def get_all_user_connections(id) do
    Repo.all(
      from uc in UserConnection,
        where: uc.user_id == ^id or uc.reverse_user_id == ^id
    )
    |> Repo.preload([:connection])
    |> Enum.filter(fn uconn -> uconn.connection.user_id != id end)
  end

  @impl true
  def get_all_confirmed_user_connections(id) do
    Repo.all(
      from uc in UserConnection,
        where: uc.user_id == ^id or uc.reverse_user_id == ^id,
        where: not is_nil(uc.confirmed_at)
    )
    |> Repo.preload([:user, :connection])
    |> Enum.filter(fn uconn -> uconn.connection.user_id != id end)
  end

  @impl true
  def search_user_connections(user, search_query) when is_binary(search_query) do
    normalized_query = String.downcase(String.trim(search_query))

    if String.length(normalized_query) > 0 do
      blocked_user_ids =
        user
        |> list_blocked_users()
        |> Enum.map(& &1.blocked_id)

      UserConnection
      |> where_user(user)
      |> where_confirmed()
      |> where_not_blocked(blocked_user_ids)
      |> where([uc], uc.label_hash == ^normalized_query)
      |> order_by([uc], desc: uc.confirmed_at)
      |> preload([:connection])
      |> Repo.all()
    else
      filter_user_connections(%{}, user)
    end
  end

  defp where_not_confirmed(query) do
    from(uc in query, where: is_nil(uc.confirmed_at))
  end

  defp sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, _options), do: query

  defp paginate(query, %{page: page, per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, _options), do: query
end
