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

  @impl true
  def list_blocked_users(user) do
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

  @impl true
  def get_user_by_username_for_connection(user, username) when is_binary(username) do
    new_user =
      from(u in User,
        where: u.id != ^user.id,
        where: u.visibility == :public or u.visibility == :connections
      )
      |> Repo.get_by(username_hash: username)

    cond do
      not is_nil(new_user) && !has_user_connection?(new_user, user) -> new_user
      true -> nil
    end
  end

  @impl true
  def get_user_by_email_for_connection(user, email) when is_binary(email) do
    new_user =
      from(u in User,
        where: u.id != ^user.id,
        where: u.visibility == :public or u.visibility == :connections
      )
      |> Repo.get_by(email_hash: email)

    cond do
      not is_nil(new_user) && !has_user_connection?(new_user, user) -> new_user
      true -> nil
    end
  end

  @impl true
  def get_both_user_connections_between_users!(user_id, reverse_user_id) do
    Repo.all(
      from uc in UserConnection,
        where: uc.user_id == ^user_id and uc.reverse_user_id == ^reverse_user_id,
        or_where: uc.user_id == ^reverse_user_id and uc.reverse_user_id == ^user_id,
        preload: [:user, :connection]
    )
  end

  @impl true
  def get_user_connection_between_users(user_id, current_user_id) do
    unless is_nil(user_id) do
      UserConnection
      |> where([uc], uc.user_id == ^current_user_id and uc.reverse_user_id == ^user_id)
      |> preload([:user, :connection])
      |> Repo.one()
    end
  end

  @impl true
  def get_user_connection_between_users!(user_id, current_user_id) do
    unless is_nil(user_id) do
      Repo.one!(
        from uc in UserConnection,
          where: uc.user_id == ^current_user_id and uc.reverse_user_id == ^user_id,
          preload: [:user, :connection]
      )
    end
  end

  @impl true
  def update_user_connection_label(uconn, attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           uconn
           |> UserConnection.label_changeset(attrs, opts)
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
  def update_user_connection_zen(uconn, attrs, _opts) do
    case Repo.transaction_on_primary(fn ->
           uconn
           |> UserConnection.zen_changeset(attrs)
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
  def update_user_connection_photos(uconn, attrs, _opts) do
    case Repo.transaction_on_primary(fn ->
           uconn
           |> UserConnection.photos_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, uconn}} ->
        updated_uconn = uconn |> Repo.preload([:user, :connection])

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "accounts:#{updated_uconn.user_id}",
          {:uconn_updated, updated_uconn}
        )

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "accounts:#{updated_uconn.reverse_user_id}",
          {:uconn_updated, updated_uconn}
        )

        {:ok, updated_uconn}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def update_user_profile(user, attrs, opts) do
    conn = get_connection!(user.connection.id)

    changeset = Connection.profile_changeset(conn, attrs, opts)

    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_connection, fn _ -> changeset end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_connection: updated_conn}} ->
        uconns = get_all_user_connections(user.id)
        broadcast_user_connections(uconns, :uconn_updated)
        {:ok, updated_conn}

      {:error, :update_connection, changeset, _} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_user_name(user, attrs, opts) do
    changeset = User.name_changeset(user, attrs, opts)
    conn = get_connection!(user.connection.id)
    c_attrs = Map.get(changeset.changes, :connection_map, %{c_name: nil, c_name_hash: nil})

    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_user, fn _ ->
           User.name_changeset(user, attrs, opts)
         end)
         |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
           Connection.update_name_changeset(conn, %{
             name: c_attrs.c_name,
             name_hash: c_attrs.c_name_hash
           })
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_user: user, update_connection: conn}} ->
        broadcast_connection(conn, :uconn_name_updated)
        {:ok, user}

      {:error, :update_user, changeset, _map} ->
        {:error, changeset}

      {:error, :update_connection, changeset, _map} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def update_user_username(user, attrs, opts) do
    changeset = User.username_changeset(user, attrs, opts)
    conn = get_connection!(user.connection.id)
    c_attrs = changeset.changes.connection_map

    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_user, fn _ ->
           User.username_changeset(user, attrs, opts)
         end)
         |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
           Connection.update_username_changeset(conn, %{
             username: c_attrs.c_username,
             username_hash: c_attrs.c_username_hash
           })
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_user: user, update_connection: conn}} ->
        broadcast_connection(conn, :uconn_username_updated)
        {:ok, user}

      {:error, :update_user, changeset, _map} ->
        {:error, changeset}

      {:error, :update_connection, changeset, _map} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def update_user_visibility(user, attrs, opts) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        user
        |> User.visibility_changeset(attrs, opts)
        |> Repo.update()
      end)

    case return do
      {:ok, user} ->
        broadcast_connection(user.connection, :uconn_visibility_updated)
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_user_password(user, password, attrs, opts) do
    changeset =
      user
      |> User.password_changeset(attrs, opts)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @impl true
  def reset_user_password(user, attrs, opts) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs, opts))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @impl true
  def update_user_avatar(user, attrs, opts) do
    conn = get_connection!(user.connection.id)

    changeset =
      if opts[:delete_avatar] do
        User.delete_avatar_changeset(user, %{avatar_url: attrs[:avatar_url]}, opts)
      else
        User.avatar_changeset(user, %{avatar_url: attrs[:avatar_url]}, opts)
      end

    c_attrs = changeset.changes.connection_map

    result =
      if opts[:delete_avatar] do
        Ecto.Multi.new()
        |> Ecto.Multi.update(:update_user, fn _ ->
          User.delete_avatar_changeset(user, attrs, opts)
        end)
        |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
          Connection.update_avatar_changeset(
            conn,
            %{
              avatar_url: c_attrs.c_avatar_url,
              avatar_url_hash: c_attrs.c_avatar_url_hash
            },
            opts
          )
        end)
        |> Repo.transaction_on_primary()
      else
        Ecto.Multi.new()
        |> Ecto.Multi.update(:update_user, fn _ ->
          User.avatar_changeset(user, attrs, opts)
        end)
        |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
          Connection.update_avatar_changeset(conn, %{
            avatar_url: c_attrs.c_avatar_url,
            avatar_url_hash: c_attrs.c_avatar_url_hash
          })
        end)
        |> Repo.transaction_on_primary()
      end

    case result do
      {:ok, %{update_user: user, update_connection: conn}} ->
        broadcast_connection(conn, :uconn_avatar_updated)
        {:ok, user, conn}

      {:error, :update_user, changeset, _map} ->
        {:error, changeset}

      {:error, :update_connection, changeset, _map} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def block_user(blocker, blocked_user, attrs, opts) do
    alias Mosslet.Accounts.UserBlock

    attrs =
      attrs
      |> Map.put("blocker_id", blocker.id)
      |> Map.put("blocked_id", blocked_user.id)

    existing_block = Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user.id)

    case Repo.transaction_on_primary(fn ->
           if existing_block do
             existing_block
             |> UserBlock.changeset(attrs, opts)
             |> Repo.update()
           else
             %UserBlock{}
             |> UserBlock.changeset(attrs, opts)
             |> Repo.insert()
           end
         end) do
      {:ok, {:ok, block}} ->
        event = if existing_block, do: :user_block_updated, else: :user_blocked

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "blocks:#{blocker.id}",
          {event, block}
        )

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "blocks:#{blocked_user.id}",
          {event, block}
        )

        {:ok, block}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @impl true
  def unblock_user(blocker, blocked_user) do
    alias Mosslet.Accounts.UserBlock

    block = Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user.id)

    if block do
      case Repo.transaction_on_primary(fn ->
             Repo.delete(block)
           end) do
        {:ok, {:ok, deleted_block}} ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "blocks:#{blocker.id}",
            {:user_unblocked, deleted_block}
          )

          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "blocks:#{blocked_user.id}",
            {:user_unblocked, deleted_block}
          )

          {:ok, deleted_block}

        {:ok, {:error, changeset}} ->
          {:error, changeset}

        error ->
          error
      end
    else
      {:error, :not_blocked}
    end
  end

  @impl true
  def user_blocked?(blocker, blocked_user) do
    alias Mosslet.Accounts.UserBlock

    query =
      from b in UserBlock,
        where: b.blocker_id == ^blocker.id and b.blocked_id == ^blocked_user.id

    Repo.exists?(query)
  end

  @impl true
  def get_user_block(blocker, blocked_user_id) when is_binary(blocked_user_id) do
    alias Mosslet.Accounts.UserBlock
    Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user_id)
  end

  @impl true
  def delete_user_account(user, password, attrs, opts) do
    changeset =
      user
      |> User.delete_account_changeset(attrs, opts)
      |> User.validate_current_password(password)

    uconns = get_all_user_connections(user.id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete(:user, changeset)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{user: user}} ->
        broadcast_admin({:ok, user}, :account_deleted)
        broadcast_user_connections(uconns, :uconn_deleted)
        {:ok, user}

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  @impl true
  def deliver_user_reset_password_instructions(user, email, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    alias Mosslet.Accounts.UserNotifier

    {encoded_token, user_token} = UserToken.build_email_token(user, email, "reset_password")

    Repo.transaction_on_primary(fn ->
      Repo.insert!(user_token)
    end)

    UserNotifier.deliver_reset_password_instructions(
      user,
      email,
      reset_password_url_fun.(encoded_token)
    )
  end

  @impl true
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _rest -> nil
    end
  end

  @impl true
  def deliver_user_confirmation_instructions(user, email, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    alias Mosslet.Accounts.UserNotifier

    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, email, "confirm")

      Repo.transaction_on_primary(fn ->
        Repo.insert!(user_token)
      end)

      UserNotifier.deliver_confirmation_instructions(
        user,
        email,
        confirmation_url_fun.(encoded_token)
      )
    end
  end

  defp broadcast_connection(conn, event) do
    conn = conn |> Repo.preload([:user_connections])

    filtered_user_connections =
      Enum.filter(conn.user_connections, fn uconn -> uconn.user_id != conn.user_id end)

    broadcast_user_connections(filtered_user_connections, event)
  end

  @impl true
  def get_shared_user_by_username(user_id, username) when is_binary(username) do
    new_user =
      from(u in User,
        where: u.id != ^user_id
      )
      |> Repo.get_by(username_hash: username)

    cond do
      not is_nil(new_user) && has_confirmed_user_connection?(new_user, user_id) -> new_user
      true -> nil
    end
  end

  def get_shared_user_by_username(_, _), do: nil

  @impl true
  def get_user_connection_for_user_group(user_id, current_user_id) do
    UserConnection
    |> where([uc], uc.user_id == ^user_id and uc.reverse_user_id == ^current_user_id)
    |> Repo.one()
  end

  @impl true
  def get_user_connection_for_reply_shared_users(reply_user_id, current_user_id) do
    UserConnection
    |> where([uc], uc.user_id == ^current_user_id and uc.reverse_user_id == ^reply_user_id)
    |> where([uc], not is_nil(uc.confirmed_at))
    |> preload([:connection])
    |> Repo.one()
  end

  @impl true
  def get_current_user_connection_between_users!(user_id, current_user_id) do
    Repo.one!(
      from uc in UserConnection,
        where: uc.user_id == ^current_user_id and uc.reverse_user_id == ^user_id,
        preload: [:user, :connection]
    )
  end

  @impl true
  def validate_users_in_connection(user_connection_id, current_user_id) do
    user_connection = get_user_connection!(user_connection_id)
    current_user_id in [user_connection.user_id, user_connection.reverse_user_id]
  end

  @impl true
  def get_user_connection_from_shared_item(item, current_user) do
    UserConnection
    |> join(:inner, [uc], c in Connection, on: uc.connection_id == c.id)
    |> where([uc, c], c.user_id == ^item.user_id)
    |> where([uc, c], uc.user_id == ^current_user.id)
    |> preload([:connection, :user, :reverse_user])
    |> Repo.one()
  end

  @impl true
  def get_post_author_permissions_for_viewer(item, current_user) do
    UserConnection
    |> join(:inner, [uc], c in Connection, on: uc.connection_id == c.id)
    |> where([uc, c], c.user_id == ^current_user.id)
    |> where([uc, c], uc.user_id == ^item.user_id)
    |> preload([:connection, :user, :reverse_user])
    |> Repo.one()
  end

  @impl true
  def get_user_from_post(post) do
    Repo.one(
      from u in User,
        where: ^post.user_id == u.id,
        preload: [:connection]
    )
  end

  @impl true
  def get_user_from_item(item) do
    Repo.one(
      from u in User,
        where: ^item.user_id == u.id,
        preload: [:connection]
    )
  end

  @impl true
  def get_user_from_item!(item) do
    Repo.one!(
      from u in User,
        where: ^item.user_id == u.id,
        preload: [:connection]
    )
  end

  @impl true
  def get_connection_from_item(item, _current_user) do
    Repo.one(
      from c in Connection,
        join: u in User,
        on: u.id == c.user_id,
        where: c.user_id == ^item.user_id,
        preload: [:user_connections]
    )
  end

  @impl true
  def list_all_users do
    Repo.all(User)
  end

  @impl true
  def count_all_users do
    query = from u in User, where: not u.is_admin?
    Repo.aggregate(query, :count)
  end

  @impl true
  def list_all_confirmed_users do
    Repo.all(from u in User, where: not is_nil(u.confirmed_at))
  end

  @impl true
  def count_all_confirmed_users do
    query =
      from u in User,
        where: not u.is_admin?,
        where: not is_nil(u.confirmed_at)

    Repo.aggregate(query, :count)
  end

  @impl true
  def create_user_profile(user, attrs, opts) do
    conn = get_connection!(user.connection.id)

    {:ok, {:ok, conn}} =
      Repo.transaction_on_primary(fn ->
        conn
        |> Connection.profile_changeset(attrs, opts)
        |> Repo.update()
      end)

    uconns = get_all_user_connections(user.id)
    broadcast_user_connections(uconns, :uconn_updated)

    {:ok, conn}
  end

  @impl true
  def delete_user_profile(user, conn) do
    changeset = Connection.profile_changeset(conn, %{profile: nil})
    uconns = get_all_user_connections(user.id)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:conn, changeset)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{conn: updated_conn}} ->
        broadcast_user_connections(uconns, :uconn_updated)
        {:ok, updated_conn}

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_user_onboarding(user, attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.onboarding_changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} -> {:ok, user}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def update_user_onboarding_profile(user, attrs, opts) do
    changeset = User.profile_changeset(user, attrs, opts)
    conn = get_connection!(user.connection.id)
    c_attrs = Map.get(changeset.changes, :connection_map, %{c_name: nil, c_name_hash: nil})

    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_user, fn _ ->
           User.profile_changeset(user, attrs, opts)
         end)
         |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
           Connection.update_name_changeset(conn, %{
             name: c_attrs.c_name,
             name_hash: c_attrs.c_name_hash
           })
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_user: user, update_connection: conn}} ->
        broadcast_connection(conn, :uconn_name_updated)
        {:ok, user}

      {:error, :update_user, changeset, _map} ->
        {:error, changeset}

      {:error, :update_connection, changeset, _map} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def update_user_notifications(user, attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.notifications_changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} -> {:ok, user}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def update_user_tokens(user, attrs) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.tokens_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} -> {:ok, user}
      {:error, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def update_user_email_notification_received_at(user, timestamp) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.email_notification_received_changeset(%{
             last_email_notification_received_at: timestamp
           })
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} -> {:ok, user}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def update_user_reply_notification_received_at(user, timestamp) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.reply_notification_received_changeset(%{
             last_reply_notification_received_at: timestamp
           })
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} -> {:ok, user}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def update_user_replies_seen_at(user, timestamp) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.replies_seen_changeset(%{
             last_replies_seen_at: timestamp
           })
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} -> {:ok, user}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def apply_user_email(user, password, attrs, opts) do
    user
    |> User.email_changeset(attrs, opts)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @impl true
  def check_if_can_change_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @impl true
  def update_user_email(user, d_email, token, key) do
    alias Mosslet.Accounts.UserNotifier

    context = "change:#{d_email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, %{user: _user, tokens: _tokens, connection: conn}} <-
           Repo.transaction_on_primary(user_email_multi(user, email, context, key)) do
      broadcast_connection(conn, :uconn_email_updated)
      :ok
    else
      _rest -> :error
    end
  end

  defp user_email_multi(user, email, context, key) do
    conn = get_connection!(user.connection.id)
    opts = [key: key, user: user]

    changeset =
      user
      |> User.email_changeset(%{email: email}, opts)
      |> User.confirm_changeset()

    c_attrs = changeset.changes.connection_map

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.update(:connection, fn %{user: _user} ->
      Connection.update_email_changeset(conn, %{
        email: c_attrs.c_email,
        email_hash: c_attrs.c_email_hash
      })
    end)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @impl true
  def deliver_user_update_email_instructions(user, current_email, new_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    alias Mosslet.Accounts.UserNotifier

    {encoded_token, user_token} =
      UserToken.build_email_token(user, new_email, "change:#{current_email}")

    Repo.transaction_on_primary(fn ->
      Repo.insert!(user_token)
    end)

    UserNotifier.deliver_update_email_notification(
      user,
      current_email,
      new_email,
      update_email_url_fun.(encoded_token)
    )

    UserNotifier.deliver_update_email_instructions(
      user,
      current_email,
      new_email,
      update_email_url_fun.(encoded_token)
    )
  end

  @impl true
  def suspend_user(%User{} = user, %User{is_admin?: true} = admin_user) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.admin_suspension_changeset(%{"is_suspended?" => true}, admin_user)
           |> Repo.update()
         end) do
      {:ok, {:ok, suspended_user}} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{user.id}",
          {:user_suspended, suspended_user}
        )

        {:ok, suspended_user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  def suspend_user(_user, _non_admin_user), do: {:error, :unauthorized}

  @impl true
  def create_visibility_group(user, group_params, opts) do
    group_attrs = %{
      "temp_name" => group_params["name"],
      "temp_description" => group_params["description"] || "",
      "color" => String.to_existing_atom(group_params["color"] || "teal"),
      "temp_connection_ids" => group_params["connection_ids"] || []
    }

    case Repo.transaction_on_primary(fn ->
           fresh_user = Repo.get(User, user.id)

           fresh_user
           |> User.add_visibility_group_changeset(group_attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_user}} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{user.id}",
          {:visibility_group_created, updated_user}
        )

        {:ok, updated_user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @impl true
  def update_visibility_group(user, group_id, group_params, opts) do
    case Repo.transaction_on_primary(fn ->
           fresh_user = Repo.get(User, user.id)

           group_changesets =
             Enum.map(fresh_user.visibility_groups || [], fn group ->
               if group.id == group_id do
                 group_attrs = %{
                   "temp_name" => group_params["name"],
                   "temp_description" => group_params["description"] || "",
                   "color" => String.to_existing_atom(group_params["color"] || "teal"),
                   "temp_connection_ids" => group_params["connection_ids"] || []
                 }

                 User.visibility_group_changeset(group, group_attrs, opts)
               else
                 group
               end
             end)

           fresh_user
           |> Ecto.Changeset.change()
           |> Ecto.Changeset.put_embed(:visibility_groups, group_changesets)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_user}} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{user.id}",
          {:visibility_group_updated, updated_user}
        )

        {:ok, updated_user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @impl true
  def delete_visibility_group(user, group_id) do
    case Repo.transaction_on_primary(fn ->
           user_with_groups = Repo.get(User, user.id)

           updated_groups =
             Enum.reject(user_with_groups.visibility_groups || [], fn group ->
               group.id == group_id
             end)

           user_with_groups
           |> Ecto.Changeset.change()
           |> Ecto.Changeset.put_embed(:visibility_groups, updated_groups)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_user}} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{user.id}",
          {:visibility_group_deleted, updated_user}
        )

        {:ok, updated_user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @impl true
  def get_user_visibility_groups_with_connections(user) do
    user_with_groups = Repo.get(User, user.id)

    Enum.map(user_with_groups.visibility_groups || [], fn group ->
      %{group: group, user: user_with_groups, user_connections: []}
    end)
  end

  @impl true
  def delete_user_data(user, password, _key, attrs, opts) do
    changeset =
      user
      |> User.delete_data_changeset(attrs, opts)
      |> User.validate_current_password(password)
      |> Map.put(:action, :delete)

    if changeset.valid? do
      {:ok, nil}
    else
      {:error, changeset}
    end
  end

  # ============================================================================
  # TOTP / 2FA Functions
  # ============================================================================

  alias Mosslet.Accounts.UserTOTP

  @impl true
  def two_factor_auth_enabled?(user) do
    !!get_user_totp(user)
  end

  @impl true
  def get_user_totp(user) do
    Repo.get_by(UserTOTP, user_id: user.id)
  end

  @impl true
  def change_user_totp(totp, attrs \\ %{}) do
    UserTOTP.changeset(totp, attrs)
  end

  @impl true
  def upsert_user_totp(totp, attrs) do
    totp_changeset =
      totp
      |> UserTOTP.changeset(attrs)
      |> UserTOTP.ensure_backup_codes()
      |> Ecto.Changeset.force_change(:secret, totp.secret)

    return =
      Repo.transaction_on_primary(fn ->
        Repo.insert_or_update(totp_changeset)
      end)

    case return do
      {:ok, {:ok, user_totp}} -> {:ok, user_totp}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def regenerate_user_totp_backup_codes(totp) do
    return =
      Repo.transaction_on_primary(fn ->
        totp
        |> Ecto.Changeset.change()
        |> UserTOTP.regenerate_backup_codes()
        |> Repo.update!()
      end)

    case return do
      {:ok, user_totp} -> {:ok, user_totp}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete_user_totp(user_totp) do
    return =
      Repo.transaction_on_primary(fn ->
        Repo.delete!(user_totp)
      end)

    case return do
      {:ok, user_totp} -> {:ok, user_totp}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def validate_user_totp(user, code) do
    totp = Repo.get_by!(UserTOTP, user_id: user.id)

    cond do
      UserTOTP.valid_totp?(totp, code) ->
        :valid_totp

      changeset = UserTOTP.validate_backup_code(totp, code) ->
        {:ok, {:ok, totp}} = Repo.transaction_on_primary(fn -> Repo.update!(changeset) end)
        {:valid_backup_code, Enum.count(totp.backup_codes, &is_nil(&1.used_at))}

      true ->
        :invalid
    end
  end
end
