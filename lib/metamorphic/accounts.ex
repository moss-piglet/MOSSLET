defmodule Metamorphic.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  alias Metamorphic.Repo

  alias Metamorphic.Accounts.{Connection, User, UserConnection, UserToken, UserNotifier, UserTOTP}
  alias Metamorphic.Encrypted

  ## Preloads

  def preload_connection(%User{} = user) do
    user |> Repo.preload([:connection])
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email_hash: email)
  end

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username_hash: username)
  end

  @doc """
  Get user by username. This checks to make sure
  the current user is not the user be searched for
  and does not having a pending UserConnection.

  This is used to send connection requests and we
  don't want people to send themselves requests.
  """
  def get_user_by_username(user, username) when is_binary(username) and is_struct(user) do
    new_user =
      from(u in User,
        where: u.id != ^user.id,
        where: u.visibility == :public or u.visibility == :connections
      )
      |> Repo.get_by(username_hash: username)

    cond do
      not is_nil(new_user) && !has_user_connection?(new_user, user) ->
        new_user

      true ->
        nil
    end
  end

  @doc """
  Get user by username to share a post with.
  This checks to make sure the current_user_id
  is not the user be searched for and HAS a
  confirmed UserConnection.
  """
  def get_shared_user_by_username(user_id, username)
      when is_binary(username) and is_binary(user_id) do
    new_user =
      from(u in User,
        where: u.id != ^user_id
      )
      |> Repo.get_by(username_hash: username)

    cond do
      not is_nil(new_user) && has_confirmed_user_connection?(new_user, user_id) ->
        new_user

      true ->
        nil
    end
  end

  def get_shared_user_by_username(_, _username), do: nil

  @doc """
  Get user by email. This checks to make sure
  the current user is not the user be searched for.

  This is used to send connection requests and we
  don't want people to send themselves requests.
  """
  def get_user_by_email(user, email) when is_binary(email) do
    new_user =
      from(u in User,
        where: u.id != ^user.id,
        where: u.visibility == :public or u.visibility == :connections
      )
      |> Repo.get_by(email_hash: email)

    cond do
      not is_nil(new_user) && !has_user_connection?(new_user, user) ->
        new_user

      true ->
        nil
    end
  end

  def has_user_connection?(%User{} = user, current_user) do
    query =
      Repo.all(
        from uc in UserConnection,
          where: uc.user_id == ^user.id and uc.reverse_user_id == ^current_user.id,
          or_where: uc.reverse_user_id == ^user.id and uc.user_id == ^current_user.id
      )

    cond do
      Enum.empty?(query) ->
        false

      !Enum.empty?(query) ->
        true
    end
  end

  def has_confirmed_user_connection?(%User{} = user, current_user_id) do
    query =
      Repo.all(
        from uc in UserConnection,
          where:
            uc.user_id == ^user.id and uc.reverse_user_id == ^current_user_id and
              not is_nil(uc.confirmed_at),
          or_where:
            uc.reverse_user_id == ^user.id and uc.user_id == ^current_user_id and
              not is_nil(uc.confirmed_at)
      )

    cond do
      Enum.empty?(query) ->
        false

      !Enum.empty?(query) ->
        true
    end
  end

  def has_any_user_connections?(user) do
    unless is_nil(user) do
      uconns =
        Repo.all(
          from uc in UserConnection,
            where: uc.user_id == ^user.id or uc.reverse_user_id == ^user.id,
            where: not is_nil(uc.confirmed_at)
        )

      cond do
        Enum.empty?(uconns) ->
          false

        !Enum.empty?(uconns) ->
          true
      end
    end
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email_hash: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)
  def get_user(id), do: Repo.get(User, id)

  def get_user_with_preloads(id) do
    Repo.one(from u in User, where: u.id == ^id, preload: [:connection, :user_connections])
  end

  def get_user_from_profile_slug!(slug) do
    Repo.one!(
      from u in User, where: u.username_hash == ^slug, preload: [:connection, :user_connections]
    )
  end

  def get_user_from_profile_slug(slug) do
    Repo.one(
      from u in User, where: u.username_hash == ^slug, preload: [:connection, :user_connections]
    )
  end

  def get_connection!(id), do: Repo.get!(Connection, id)

  def get_user_connection!(id),
    do: Repo.get!(UserConnection, id) |> Repo.preload([:connection, :user])

  def get_both_user_connections_between_users!(user_id, reverse_user_id) do
    Repo.all(
      from uc in UserConnection,
        where: uc.user_id == ^user_id and uc.reverse_user_id == ^reverse_user_id,
        or_where: uc.user_id == ^reverse_user_id and uc.reverse_user_id == ^user_id,
        preload: [:user, :connection]
    )
  end

  def get_user_connection_between_users!(user_id, current_user_id) do
    unless is_nil(user_id) do
      Repo.one(
        from uc in UserConnection,
          where: uc.user_id == ^current_user_id,
          where: uc.user_id == ^user_id and uc.reverse_user_id == ^current_user_id,
          or_where: uc.user_id == ^current_user_id and uc.reverse_user_id == ^user_id,
          preload: [:user, :connection]
      )
    end
  end

  def get_user_connection_between_users(user, current_user) do
    unless is_nil(user) do
      Repo.one(
        from uc in UserConnection,
          where: uc.user_id == ^current_user.id,
          where: uc.user_id == ^user.id and uc.reverse_user_id == ^current_user.id,
          or_where: uc.user_id == ^current_user.id and uc.reverse_user_id == ^user.id,
          preload: [:user, :connection]
      )
    end
  end

  def get_all_user_connections(id) do
    Repo.all(
      from uc in UserConnection,
        where: uc.user_id == ^id or uc.reverse_user_id == ^id
    )
  end

  def get_user_connection_from_shared_item(item, current_user) do
    Repo.one(
      from uc in UserConnection,
        join: c in Connection,
        on: c.user_id == ^item.user_id,
        where: uc.user_id == ^current_user.id,
        where: uc.connection_id == c.id,
        preload: [:user, :connection]
    )
  end

  def get_all_user_connections_from_shared_item(item, current_user) do
    Repo.all(
      from uc in UserConnection,
        join: c in Connection,
        on: c.user_id == ^item.user_id,
        where: uc.user_id == ^current_user.id
    )
  end

  def get_user_from_post(post) do
    Repo.one(
      from u in User,
        where: ^post.user_id == u.id,
        preload: [:connection]
    )
  end

  def get_connection_from_item(item, _current_user) do
    Repo.one(
      from c in Connection,
        join: u in User,
        on: u.id == c.user_id,
        where: c.user_id == ^item.user_id,
        preload: [:user_connections]
    )
  end

  @doc """
  Lists all users.
  """
  def list_all_users() do
    Repo.all(User)
  end

  @doc """
  Counts all users.
  """
  def count_all_users() do
    query = from u in User, where: not u.is_admin?
    Repo.aggregate(query, :count)
  end

  @doc """
  Lists all confirmed users.
  """
  def list_all_confirmed_users() do
    Repo.all(from u in User, where: not is_nil(u.confirmed_at))
  end

  @doc """
  Counts all confirmed users.
  """
  def count_all_confirmed_users() do
    query =
      from u in User,
        where: not u.is_admin?,
        where: not is_nil(u.confirmed_at)

    Repo.aggregate(query, :count)
  end

  @doc """
  List user's user_connections. These are
  connections that have been confirmed.
  """
  def list_user_connections(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    from(uc in UserConnection,
      where: uc.user_id == ^user.id,
      where: not is_nil(uc.confirmed_at),
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: uc.inserted_at],
      preload: [:user, :connection]
    )
    |> Repo.all()
  end

  @doc """
  List's the users's arrival connections. These
  are connections that have not been confirmed.
  """
  def list_user_arrival_connections(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    from(uc in UserConnection,
      where: uc.user_id == ^user.id,
      where: is_nil(uc.confirmed_at),
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: uc.inserted_at],
      preload: [:user, :connection]
    )
    |> Repo.all()
  end

  ## User registration

  @doc """
  Registers a user and creates its
  associated connection record.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(%Ecto.Changeset{} = user, c_attrs \\ %{}) do
    {:ok, {:ok, user}} =
      Repo.transaction_on_primary(fn ->
        {:ok, %{insert_user: user, insert_connection: _conn}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user, user)
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

        {:ok, user}
      end)

    {:ok, user}
    |> broadcast_admin(:account_registered)

    {:ok, user}
  end

  def create_user_connection(attrs, opts) do
    {:ok, {:ok, uconn}} =
      Repo.transaction_on_primary(fn ->
        %UserConnection{}
        |> UserConnection.changeset(attrs, opts)
        |> Repo.insert()
      end)

    {:ok, uconn |> Repo.preload([:user, :connection])}
    |> broadcast(:uconn_created)
  end

  def update_user_connection(uconn, attrs, opts) do
    {:ok, {:ok, uconn}} =
      Repo.transaction_on_primary(fn ->
        uconn
        |> UserConnection.edit_changeset(attrs, opts)
        |> Repo.update()
      end)

    {:ok, uconn |> Repo.preload([:user, :connection])}
    |> broadcast(:uconn_updated)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  def update_user_onboarding(user, attrs \\ %{}, opts \\ []) do
    {:ok, {:ok, user}} =
      Repo.transaction_on_primary(fn ->
        user
        |> User.onboarding_changeset(attrs, opts)
        |> Repo.update()
      end)

    {:ok, user}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_connection changes.

  ## Examples

      iex> change_user_connection(uconn)
      %Ecto.Changeset{data: %UserConnection{}}

  """
  def change_user_connection(%UserConnection{} = uconn, attrs \\ %{}, opts \\ []) do
    UserConnection.changeset(uconn, attrs, opts)
  end

  def edit_user_connection(%UserConnection{} = uconn, attrs \\ %{}, opts \\ []) do
    UserConnection.edit_changeset(uconn, attrs, opts)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user name.

  ## Examples

      iex> change_user_name(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_name(user, attrs \\ %{}) do
    User.name_changeset(user, attrs, validate_name: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user username.

  ## Examples

      iex> change_user_username(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_username(user, attrs \\ %{}) do
    User.username_changeset(user, attrs, validate_username: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user profile.

  ## Examples

      iex> change_user_profile(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_profile(connection, attrs \\ %{}, opts \\ []) do
    Connection.profile_changeset(connection, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user visibility.

  ## Examples

      iex> change_user_visibility(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_visibility(user, attrs \\ %{}) do
    User.visibility_changeset(user, attrs, validate_visibility: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user's is_forgot_pwd? boolean.

  ## Examples

      iex> change_user_forgot_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_forgot_password(user, attrs \\ %{}) do
    User.forgot_password_changeset(user, attrs, [])
  end

  def update_user_forgot_password(user, attrs \\ %{}, opts \\ []) do
    {:ok, {:ok, user}} =
      Repo.transaction_on_primary(fn ->
        user
        |> User.forgot_password_changeset(attrs, opts)
        |> Repo.update()
      end)

    {:ok, user}
  end

  def update_user_profile(user, attrs \\ %{}, opts \\ []) do
    conn = get_connection!(user.connection.id)
    uconns = get_all_user_connections(user.id)

    {:ok, %{update_connection: conn}} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:update_connection, fn _ ->
        Connection.profile_changeset(conn, attrs, opts)
      end)
      |> Repo.transaction_on_primary()

    cond do
      conn.profile.visibility == :public ->
        broadcast_public_connection(conn, :uconn_updated)
        broadcast_connection(conn, :uconn_updated)
        broadcast_public_user_connections(uconns, :uconn_updated)
        {:ok, conn}

      true ->
        broadcast_connection(conn, :uconn_updated)
        broadcast_public_user_connections(uconns, :uconn_updated)
        {:ok, conn}
    end
  end

  def create_user_profile(user, attrs \\ %{}, opts \\ []) do
    conn = get_connection!(user.connection.id)

    {:ok, {:ok, conn}} =
      Repo.transaction_on_primary(fn ->
        conn
        |> Connection.profile_changeset(attrs, opts)
        |> Repo.update()
      end)

    broadcast_connection(conn, :uconn_updated)

    {:ok, conn}
  end

  def update_user_name(user, attrs \\ %{}, opts \\ []) do
    {:ok, {:ok, user}} =
      Repo.transaction_on_primary(fn ->
        changeset = User.name_changeset(user, attrs, opts)
        conn = get_connection!(user.connection.id)
        c_attrs = Map.get(changeset.changes, :connection_map, %{c_name: nil})

        {:ok, %{update_user: user, update_connection: conn}} =
          Ecto.Multi.new()
          |> Ecto.Multi.update(:update_user, fn _ ->
            User.name_changeset(user, attrs, opts)
          end)
          |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
            Connection.update_name_changeset(conn, %{
              name: c_attrs.c_name
            })
          end)
          |> Repo.transaction_on_primary()

        broadcast_connection(conn, :uconn_name_updated)

        {:ok, user}
      end)

    {:ok, user}
  end

  def update_user_username(user, attrs \\ %{}, opts \\ []) do
    {:ok, {:ok, user}} =
      Repo.transaction_on_primary(fn ->
        changeset = User.username_changeset(user, attrs, opts)
        conn = get_connection!(user.connection.id)
        c_attrs = changeset.changes.connection_map

        {:ok, %{update_user: user, update_connection: conn}} =
          Ecto.Multi.new()
          |> Ecto.Multi.update(:update_user, fn _ ->
            User.username_changeset(user, attrs, opts)
          end)
          |> Ecto.Multi.update(:update_connection, fn %{update_user: _user} ->
            Connection.update_username_changeset(conn, %{
              username: c_attrs.c_username,
              username_hash: c_attrs.c_username_hash
            })
          end)
          |> Repo.transaction_on_primary()

        broadcast_connection(conn, :uconn_username_updated)

        {:ok, user}
      end)

    {:ok, user}
  end

  def update_user_visibility(user, attrs \\ %{}, opts \\ []) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        user
        |> User.visibility_changeset(attrs, opts)
        |> Repo.update()
      end)

    case return do
      {:ok, user} ->
        conn = get_connection!(user.connection.id)
        broadcast_connection(conn, :uconn_visibility_updated)

        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user_admin(user, _attrs \\ %{}, _opts \\ []) do
    admin_email = Encrypted.Session.admin_email()
    admin = get_user_by_email(admin_email)

    if user.id == admin.id do
      {:ok, return} =
        Repo.transaction_on_primary(fn ->
          user
          |> User.admin_changeset()
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

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user tokens.

  ## Examples

      iex> change_user_tokens(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_tokens(user, attrs \\ %{}) do
    User.tokens_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user avatar changes.

  ## Examples

      iex> change_user_avatar(uconn)
      %Ecto.Changeset{data: %UserConnection{}}

  """
  def change_user_avatar(%User{} = user, attrs \\ %{}, opts \\ []) do
    User.avatar_changeset(user, attrs, opts ++ [validate_avatar: false])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for deleting the user account.

  ## Examples

      iex> change_user_delete_account(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_delete_account(user, attrs \\ %{}) do
    User.delete_account_changeset(user, attrs, delete_account: false)
  end

  def delete_user_account(user, password, attrs \\ %{}, opts \\ []) do
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
        {:ok, user}
        |> broadcast_admin(:account_deleted)

        uconns
        |> broadcast_user_connections(:uconn_deleted)

        uconns
        |> broadcast_public_user_connections(:public_uconn_deleted)

        {:ok, user}

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  def delete_user_profile(user, conn) do
    changeset =
      conn
      |> Connection.profile_changeset(%{profile: nil})

    uconns = get_all_user_connections(user.id)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:conn, changeset)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{conn: conn}} ->
        conn
        |> broadcast_public_connection(:user_profile_deleted)

        uconns
        |> broadcast_user_connections(:uconn_updated)

        uconns
        |> broadcast_public_user_connections(:public_uconn_updated)

        {:ok, conn}

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs, opts \\ []) do
    user
    |> User.email_changeset(attrs, opts)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, d_email, token, key) do
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

  @doc """
  Updates the user ai tokens.
  """
  def update_user_tokens(user, attrs) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.tokens_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} ->
        {:ok, user}

      {:error, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates the user avatar.
  """
  def update_user_avatar(user, attrs, opts \\ []) do
    {:ok, {:ok, user, conn}} =
      Repo.transaction_on_primary(fn ->
        conn = get_connection!(user.connection.id)

        changeset =
          cond do
            opts[:delete_avatar] ->
              user
              |> User.delete_avatar_changeset(%{avatar_url: attrs[:avatar_url]}, opts)

            true ->
              user
              |> User.avatar_changeset(%{avatar_url: attrs[:avatar_url]}, opts)
          end

        c_attrs = changeset.changes.connection_map

        {:ok, %{update_user: user, update_connection: conn}} =
          cond do
            opts[:delete_avatar] ->
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

            true ->
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

        broadcast_connection(conn, :uconn_avatar_updated)

        {:ok, user, conn}
      end)

    {:ok, user, conn}
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

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(
        %User{} = user,
        current_email,
        temp_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} =
      UserToken.build_email_token(user, temp_email, "change:#{current_email}")

    Repo.insert!(user_token)

    UserNotifier.deliver_update_email_instructions(
      user,
      temp_email,
      update_email_url_fun.(encoded_token)
    )
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts ++ [hash_password: false])
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
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

  ## 2FA / TOTP (Time based One Time Password)

  def two_factor_auth_enabled?(user) do
    !!get_user_totp(user)
  end

  @doc """
  Gets the %UserTOTP{} entry, if any.
  """
  def get_user_totp(user) do
    Repo.get_by(UserTOTP, user_id: user.id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing user TOTP.

  ## Examples

      iex> change_user_totp(%UserTOTP{})
      %Ecto.Changeset{data: %UserTOTP{}}

  """
  def change_user_totp(totp, attrs \\ %{}) do
    UserTOTP.changeset(totp, attrs)
  end

  @doc """
  Updates the TOTP secret.

  The secret is a random 20 bytes binary that is used to generate the QR Code to
  enable 2FA using auth applications. It will only be updated if the OTP code
  sent is valid.

  ## Examples

      iex> upsert_user_totp(%UserTOTP{secret: <<...>>}, code: "123456")
      {:ok, %Ecto.Changeset{data: %UserTOTP{}}}

  """
  def upsert_user_totp(totp, attrs) do
    totp_changeset =
      totp
      |> UserTOTP.changeset(attrs)
      |> UserTOTP.ensure_backup_codes()
      # If we are updating, let's make sure the secret
      # in the struct propagates to the changeset.
      |> Ecto.Changeset.force_change(:secret, totp.secret)

    Repo.insert_or_update(totp_changeset)
  end

  @doc """
  Regenerates the user backup codes for totp.

  ## Examples

      iex> regenerate_user_totp_backup_codes(%UserTOTP{})
      %UserTOTP{backup_codes: [...]}

  """
  def regenerate_user_totp_backup_codes(totp) do
    totp
    |> Ecto.Changeset.change()
    |> UserTOTP.regenerate_backup_codes()
    |> Repo.update!()
  end

  @doc """
  Disables the TOTP configuration for the given user.
  """
  def delete_user_totp(user_totp) do
    {:ok, {:ok, _user_totp}} =
      Repo.transaction_on_primary(fn ->
        Repo.delete!(user_totp)
      end)
  end

  @doc """
  Validates if the given TOTP code is valid.
  """
  def validate_user_totp(user, code) do
    totp = Repo.get_by!(UserTOTP, user_id: user.id)

    cond do
      UserTOTP.valid_totp?(totp, code) ->
        :valid_totp

      changeset = UserTOTP.validate_backup_code(totp, code) ->
        totp = Repo.update!(changeset)
        {:valid_backup_code, Enum.count(totp.backup_codes, &is_nil(&1.used_at))}

      true ->
        :invalid
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    Repo.one(query)
    |> Repo.preload([:connection])
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    {:ok, {_count, _user_tokens}} =
      Repo.transaction_on_primary(fn ->
        Repo.delete_all(UserToken.token_and_context_query(token, "session"))
      end)

    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, email, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, email, "confirm")
      Repo.insert!(user_token)

      UserNotifier.deliver_confirmation_instructions(
        user,
        email,
        confirmation_url_fun.(encoded_token)
      )
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
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

  def confirm_user_connection(uconn, attrs, opts \\ []) do
    {:ok, {:ok, upd_uconn, ins_uconn}} =
      Repo.transaction_on_primary(fn ->
        {:ok, %{update_uconn: upd_uconn, insert_uconn: ins_uconn}} =
          Ecto.Multi.new()
          |> Ecto.Multi.update(:update_uconn, UserConnection.confirm_changeset(uconn))
          |> Ecto.Multi.insert(
            :insert_uconn,
            UserConnection.changeset(%UserConnection{}, attrs, opts)
          )
          |> Repo.transaction_on_primary()

        {:ok, %{upd_insert_uconn: ins_uconn}} =
          Ecto.Multi.new()
          |> Ecto.Multi.update(:upd_insert_uconn, UserConnection.confirm_changeset(ins_uconn))
          |> Repo.transaction_on_primary()

        {:ok, ins_uconn} =
          {:ok, ins_uconn |> Repo.preload([:user, :connection])}
          |> broadcast(:uconn_confirmed)

        {:ok, upd_uconn} =
          {:ok, upd_uconn |> Repo.preload([:user, :connection])}
          |> broadcast(:uconn_confirmed)

        {:ok, upd_uconn, ins_uconn}
      end)

    {:ok, upd_uconn, ins_uconn}
  end

  def delete_user_connection(%UserConnection{} = uconn) do
    {:ok, {:ok, uconn}} =
      Repo.transaction_on_primary(fn ->
        Repo.delete(uconn)
      end)

    {:ok, uconn}
    |> broadcast(:uconn_deleted)
  end

  def delete_both_user_connections(%UserConnection{} = uconn) do
    {:ok, {_count, uconns}} =
      Repo.transaction_on_primary(fn ->
        Repo.delete_all(
          from uc in UserConnection,
            where: uc.id == ^uconn.id,
            or_where:
              uc.reverse_user_id == ^uconn.user_id and uc.user_id == ^uconn.reverse_user_id,
            or_where:
              uc.user_id == ^uconn.reverse_user_id and uc.reverse_user_id == ^uconn.user_id,
            select: uc
        )
      end)

    uconns
    |> broadcast_user_connections(:uconn_deleted)

    {:ok, uconns}
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, email, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, email, "reset_password")
    Repo.insert!(user_token)

    UserNotifier.deliver_reset_password_instructions(
      user,
      email,
      reset_password_url_fun.(encoded_token)
    )
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs, opts \\ []) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs, opts))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  defp broadcast({:ok, %UserConnection{} = uconn}, event) do
    Phoenix.PubSub.broadcast(Metamorphic.PubSub, "accounts:#{uconn.user_id}", {event, uconn})
    {:ok, uconn}
  end

  defp broadcast_admin({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Metamorphic.PubSub, "admin:accounts", {event, struct})
    {:ok, struct}
  end

  defp broadcast_public({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Metamorphic.PubSub, "accounts", {event, struct})
    {:ok, struct}
  end

  defp broadcast_user_connections(uconns, event) when is_list(uconns) do
    Enum.each(uconns, fn uconn ->
      {:ok, _uconn} =
        {:ok, uconn |> Repo.preload([:user, :connection])}
        |> broadcast(event)
    end)
  end

  defp broadcast_connection(conn, event) do
    conn = conn |> Repo.preload([:user_connections])

    Enum.each(conn.user_connections, fn uconn ->
      {:ok, _uconn} =
        {:ok, uconn |> Repo.preload([:user, :connection])}
        |> broadcast(event)
    end)
  end

  defp broadcast_public_connection(conn, event) do
    broadcast_public({:ok, conn}, event)
  end

  defp broadcast_public_user_connections(uconns, event) when is_list(uconns) do
    Enum.each(uconns, fn uconn ->
      {:ok, _uconn} =
        {:ok, uconn |> Repo.preload([:user, :connection])}
        |> broadcast_public(event)
    end)
  end

  def private_subscribe(user) do
    Phoenix.PubSub.subscribe(Metamorphic.PubSub, "accounts:#{user.id}")
  end

  def subscribe() do
    Phoenix.PubSub.subscribe(Metamorphic.PubSub, "accounts")
  end

  def admin_subscribe(user) do
    if user.is_admin? do
      Phoenix.PubSub.subscribe(Metamorphic.PubSub, "admin:accounts")
    end
  end
end
