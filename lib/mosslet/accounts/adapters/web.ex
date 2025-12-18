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

  require Logger

  alias Mosslet.Encrypted
  alias Mosslet.Groups.Group
  alias Mosslet.Memories.{Memory, Remark, UserMemory}
  alias Mosslet.Timeline.{Post, Reply, UserPost}

  alias Mosslet.Accounts.{
    Connection,
    User,
    UserBlock,
    UserConnection,
    UserToken,
    UserTOTP
  }

  @impl true
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email_hash: email)
    if User.valid_password?(user, password), do: user
  end

  @impl true
  def register_user(%Ecto.Changeset{} = user_changeset, c_attrs \\ %{}) do
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
    |> case do
      {:ok, %{insert_user: user, insert_connection: _conn}} ->
        {:ok, user}

      {:error, :insert_user, changeset, _map} ->
        {:error, changeset}

      {:error, :insert_connection, changeset, _map} ->
        {:error, changeset}
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
  def confirm_user!(user) do
    if Application.get_env(:mosslet, :env) in [:dev, :test] do
      with {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
        user
      end
    else
      user
    end
  end

  @impl true
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction_on_primary(confirm_user_multi(user)) do
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
            {:ok, upd_uconn |> Repo.preload([:user, :connection]),
             ins_uconn |> Repo.preload([:user, :connection])}

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
    query =
      from b in UserBlock,
        where: b.blocker_id == ^user.id,
        preload: [:blocked],
        order_by: [desc: b.inserted_at]

    Repo.all(query)
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
        {:ok, Enum.map(uconns, fn uc -> Repo.preload(uc, [:user, :connection]) end)}

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
        {:ok, uconn |> Repo.preload([:user, :connection])}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def update_user_profile(_user, conn, changeset) do
    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_connection, fn _ -> changeset end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_connection: updated_conn}} ->
        {:ok, updated_conn}

      {:error, :update_connection, changeset, _} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_user_name(_user, conn, user_changeset, c_attrs) do
    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_user, fn _ -> user_changeset end)
         |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
           Connection.update_name_changeset(conn, %{
             name: c_attrs.c_name,
             name_hash: c_attrs.c_name_hash
           })
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_user: user, update_connection: conn}} ->
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
  def update_user_username(_user, conn, user_changeset, c_attrs) do
    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_user, fn _ -> user_changeset end)
         |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
           Connection.update_username_changeset(conn, %{
             username: c_attrs.c_username,
             username_hash: c_attrs.c_username_hash
           })
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_user: user, update_connection: conn}} ->
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
  def update_user_visibility(user, attrs, opts) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        user
        |> User.visibility_changeset(attrs, opts)
        |> Repo.update()
      end)

    case return do
      {:ok, user} ->
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_user_password(user, changeset) do
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
  def update_user_avatar(_user, conn, changeset, c_attrs, opts) do
    result =
      if opts[:delete_avatar] do
        Ecto.Multi.new()
        |> Ecto.Multi.update(:update_user, changeset)
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
        |> Ecto.Multi.update(:update_user, changeset)
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
        {:ok, block, existing_block != nil}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @impl true
  def unblock_user(blocker, blocked_user) do
    block = Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user.id)

    if block do
      case Repo.transaction_on_primary(fn ->
             Repo.delete(block)
           end) do
        {:ok, {:ok, deleted_block}} ->
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
    query =
      from b in UserBlock,
        where: b.blocker_id == ^blocker.id and b.blocked_id == ^blocked_user.id

    Repo.exists?(query)
  end

  @impl true
  def get_user_block(blocker, blocked_user_id) when is_binary(blocked_user_id) do
    Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user_id)
  end

  @impl true
  def delete_user_account(_user, _password, changeset) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete(:user, changeset)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{user: user}} ->
        {:ok, user}

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  @impl true
  def deliver_user_reset_password_instructions(user_token) do
    case Repo.transaction_on_primary(fn ->
           Repo.insert!(user_token)
         end) do
      {:ok, user_token} -> {:ok, user_token}
      {:error, reason} -> {:error, reason}
    end
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
  def insert_user_confirmation_token(user_token) do
    case Repo.transaction_on_primary(fn ->
           Repo.insert(user_token)
         end) do
      {:ok, {:ok, token}} -> {:ok, token}
      {:ok, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
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

    case Repo.transaction_on_primary(fn ->
           conn
           |> Connection.profile_changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, conn}} -> {:ok, conn}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @impl true
  def delete_user_profile(changeset) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:conn, changeset)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{conn: updated_conn}} ->
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
  def update_user_onboarding_profile(_user, conn, user_changeset, c_attrs) do
    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_user, fn _ -> user_changeset end)
         |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
           Connection.update_name_changeset(conn, %{
             name: c_attrs.c_name,
             name_hash: c_attrs.c_name_hash
           })
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_user: user, update_connection: conn}} ->
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
    context = "change:#{d_email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         {:ok, result} <-
           Repo.transaction_on_primary(fn ->
             case Repo.one(query) do
               %UserToken{sent_to: email} ->
                 case user_email_multi(user, email, context, key) |> Repo.transaction() do
                   {:ok, %{connection: conn}} -> {:ok, conn}
                   {:error, _} -> {:error, :transaction_failed}
                 end

               nil ->
                 {:error, :token_not_found}
             end
           end) do
      case result do
        {:ok, conn} -> {:ok, conn}
        {:error, reason} -> {:error, reason}
      end
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
  def insert_user_email_change_token(user_token) do
    case Repo.transaction_on_primary(fn ->
           Repo.insert(user_token)
         end) do
      {:ok, {:ok, token}} -> {:ok, token}
      {:ok, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def suspend_user(%User{} = user, %User{is_admin?: true} = admin_user) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.admin_suspension_changeset(%{"is_suspended?" => true}, admin_user)
           |> Repo.update()
         end) do
      {:ok, {:ok, suspended_user}} ->
        {:ok, suspended_user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  def suspend_user(_user, _non_admin_user), do: {:error, :unauthorized}

  @impl true
  def create_visibility_group(user, group_attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           fresh_user = Repo.get(User, user.id)

           fresh_user
           |> User.add_visibility_group_changeset(group_attrs, opts)
           |> Repo.update()
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
  def update_visibility_group(user, group_id, group_attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           fresh_user = Repo.get(User, user.id)

           group_changesets =
             Enum.map(fresh_user.visibility_groups || [], fn group ->
               if group.id == group_id do
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
        {:ok, updated_user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @impl true
  def get_user_visibility_groups_with_connections(user) do
    Repo.get(User, user.id)
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

  @impl true
  def get_all_user_connections_from_shared_item(item, current_user) do
    Repo.all(
      from uc in UserConnection,
        join: c in Connection,
        on: c.user_id == ^item.user_id,
        where: uc.user_id == ^current_user.id
    )
  end

  @impl true
  def update_user_forgot_password(user, attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.forgot_password_changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} ->
        {:ok, user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_user_oban_reset_token_id(user, attrs, opts) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        user
        |> User.oban_reset_token_id_changeset(attrs, opts)
        |> Repo.update()
      end)

    case return do
      {:ok, user} ->
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_user_admin(user, _attrs, _opts) do
    admin_email = Encrypted.Session.admin_email()
    admin = Repo.get_by(User, email_hash: admin_email)

    if admin && user.id == admin.id do
      {:ok, return} =
        Repo.transaction_on_primary(fn ->
          user
          |> User.toggle_admin_status_changeset()
          |> Repo.update()
        end)

      case return do
        {:ok, user} ->
          {:ok, user}

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      nil
    end
  end

  @impl true
  def update_last_signed_in_info(user, ip, key) do
    Repo.transaction_on_primary(fn ->
      user
      |> User.last_signed_in_changeset(ip, key)
      |> Repo.update!()
    end)
  end

  @impl true
  def preload_org_data(user, current_org_slug) do
    user = Repo.preload(user, :orgs)

    if current_org_slug do
      %{user | current_org: Enum.find(user.orgs, &(&1.slug == current_org_slug))}
    else
      user
    end
  end

  @impl true
  def preload_user_connection(user_connection, preloads) do
    Repo.preload(user_connection, preloads)
  end

  @impl true
  def preload_connection_assocs(connection, preloads) do
    Repo.preload(connection, preloads)
  end

  # ============================================================================
  # Delete User Data Functions (thin wrappers)
  # ============================================================================

  @impl true
  def delete_all_user_connections(user_id) do
    query =
      from(uc in UserConnection, where: uc.user_id == ^user_id or uc.reverse_user_id == ^user_id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_user_connections, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{delete_all_user_connections: {count, _}}} -> {:ok, count}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_groups(user_id) do
    query = from(g in Group, where: g.user_id == ^user_id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_groups, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{delete_all_groups: {count, _}}} -> {:ok, count}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_memories(user_id) do
    query = from(m in Memory, where: m.user_id == ^user_id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_memories, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{delete_all_memories: {count, _}}} -> {:ok, count}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_posts(user_id) do
    query = from(p in Post, where: p.user_id == ^user_id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_posts, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{delete_all_posts: {count, _}}} -> {:ok, count}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_user_memories(uconn) do
    query =
      from(
        um in UserMemory,
        inner_join: m in Memory,
        on: um.memory_id == m.id,
        where: m.user_id == ^uconn.reverse_user_id and ^uconn.user_id == um.user_id
      )

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_user_memories, query)
    |> Ecto.Multi.run(:cleanup_memory_shared_users, fn _repo, _changes ->
      cleanup_shared_users_from_memories(uconn.user_id, uconn.reverse_user_id)
    end)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, _changes} -> {:ok, :deleted}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_user_posts(uconn) do
    query =
      from(
        up in UserPost,
        inner_join: p in Post,
        on: up.post_id == p.id,
        where: p.user_id == ^uconn.reverse_user_id and ^uconn.user_id == up.user_id
      )

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_user_posts, query)
    |> Ecto.Multi.run(:cleanup_post_shared_users, fn _repo, _changes ->
      cleanup_shared_users_from_posts(uconn.user_id, uconn.reverse_user_id)
    end)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, _changes} -> {:ok, :deleted}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_remarks(user_id) do
    query = from(r in Remark, where: r.user_id == ^user_id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_remarks, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{delete_all_remarks: {count, _}}} -> {:ok, count}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_replies(user_id) do
    query = from(r in Reply, where: r.user_id == ^user_id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_replies, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{delete_all_replies: {count, _}}} -> {:ok, count}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @impl true
  def cleanup_shared_users_from_posts(uconn_user_id, uconn_reverse_user_id) do
    posts_to_clean =
      from(p in Post, where: p.user_id == ^uconn_reverse_user_id)
      |> Repo.all()

    posts_to_clean
    |> Enum.filter(fn post ->
      Enum.any?(post.shared_users, fn shared_user ->
        shared_user.user_id == uconn_user_id
      end)
    end)
    |> Enum.each(fn post ->
      updated_shared_users =
        Enum.reject(post.shared_users, fn shared_user ->
          shared_user.user_id == uconn_user_id
        end)

      post
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:shared_users, updated_shared_users)
      |> Repo.update()
    end)

    {:ok, :cleaned}
  end

  @impl true
  def cleanup_shared_users_from_memories(uconn_user_id, uconn_reverse_user_id) do
    memories_to_clean =
      from(m in Memory, where: m.user_id == ^uconn_reverse_user_id)
      |> Repo.all()

    memories_to_clean
    |> Enum.filter(fn memory ->
      Enum.any?(memory.shared_users, fn shared_user ->
        shared_user.user_id == uconn_user_id
      end)
    end)
    |> Enum.each(fn memory ->
      updated_shared_users =
        Enum.reject(memory.shared_users, fn shared_user ->
          shared_user.user_id == uconn_user_id
        end)

      memory
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:shared_users, updated_shared_users)
      |> Repo.update()
    end)

    {:ok, :cleaned}
  end

  @impl true
  def get_all_memories_for_user(user_id) do
    from(m in Memory, where: m.user_id == ^user_id)
    |> Repo.all()
  end

  @impl true
  def get_all_posts_for_user(user_id) do
    from(p in Post, where: p.user_id == ^user_id, preload: [replies: :post])
    |> Repo.all()
  end

  @impl true
  def get_all_replies_for_user(user_id) do
    from(r in Reply, where: r.user_id == ^user_id, preload: [:post])
    |> Repo.all()
  end
end
