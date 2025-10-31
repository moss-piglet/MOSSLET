defmodule Mosslet.Accounts do
  @moduledoc """
  The Accounts context.
  """
  require Logger

  import Ecto.Query, warn: false

  alias Mosslet.Repo

  alias Mosslet.Accounts.{
    Connection,
    User,
    UserBlock,
    UserConnection,
    UserToken,
    UserNotifier,
    UserTOTP
  }

  alias Mosslet.Billing.Plans
  alias Mosslet.Encrypted
  alias Mosslet.Groups
  alias Mosslet.Groups.Group
  alias Mosslet.Memories.{Memory, Remark, UserMemory}
  alias Mosslet.Timeline.{Post, Reply, UserPost}
  alias Mosslet.Timeline
  alias Mosslet.Logs
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
  the current user is not the user being searched for
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
      when is_binary(username) do
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

  def get_user_connection(id),
    do: Repo.get(UserConnection, id) |> Repo.preload([:connection, :user])

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

  @doc """
  Currently returns the user_connection for the user_id
  coming from the associated `user_id` on a %UserGroup{} and the current_user_id.

  We check if the ids are the same when building the member list
  for a group. We also return `nil` as some users in the group
  may not be connected to each other.
  """
  def get_user_connection_for_user_group(user_id, current_user_id) do
    UserConnection
    |> where([uc], uc.user_id == ^user_id and uc.reverse_user_id == ^current_user_id)
    |> Repo.one()
  end

  def get_user_connection_for_reply_shared_users(reply_user_id, current_user_id) do
    UserConnection
    |> where([uc], uc.user_id == ^current_user_id and uc.reverse_user_id == ^reply_user_id)
    |> where([uc], not is_nil(uc.confirmed_at))
    |> preload([:connection])
    |> Repo.one()
  end

  @doc """
  Currently returns the user_connection for the current_user that is
  connected to the `user_id` as the reverse user.
  """
  def get_current_user_connection_between_users!(user_id, current_user_id) do
    Repo.one!(
      from uc in UserConnection,
        where: uc.user_id == ^current_user_id and uc.reverse_user_id == ^user_id,
        preload: [:user, :connection]
    )
  end

  @doc """
  Gets the %UserConnection{} for the current_user where
  the user_connection.user_id == current_user_id and the
  user_id == the user_connection.reverse_user_id.
  """
  def get_user_connection_between_users!(user_id, current_user_id) do
    unless is_nil(user_id) do
      Repo.one!(
        from uc in UserConnection,
          where: uc.user_id == ^current_user_id and uc.reverse_user_id == ^user_id,
          preload: [:user, :connection]
      )
    end
  end

  @doc """
  Gets the %UserConnection{} for the current_user where
  the user_connection.user_id == current_user_id and the
  user_id == the user_connection.reverse_user_id.
  """
  def get_user_connection_between_users(user_id, current_user_id) do
    unless is_nil(user_id) do
      UserConnection
      |> where([uc], uc.user_id == ^current_user_id and uc.reverse_user_id == ^user_id)
      |> preload([:user, :connection])
      |> Repo.one()
    end
  end

  def validate_users_in_connection(user_connection_id, current_user_id) do
    user_connection = get_user_connection!(user_connection_id)
    current_user_id in [user_connection.user_id, user_connection.reverse_user_id]
  end

  def get_all_user_connections(id) do
    Repo.all(
      from uc in UserConnection,
        where: uc.user_id == ^id or uc.reverse_user_id == ^id
    )
    |> Repo.preload([:connection])
    |> Enum.filter(fn uconn -> uconn.connection.user_id != id end)
  end

  def get_all_confirmed_user_connections(id) do
    Repo.all(
      from uc in UserConnection,
        where: uc.user_id == ^id or uc.reverse_user_id == ^id,
        where: not is_nil(uc.confirmed_at)
    )
    |> Repo.preload([:user, :connection])
    |> Enum.filter(fn uconn -> uconn.connection.user_id != id end)
  end

  def get_user_connection_from_shared_item(item, current_user) do
    UserConnection
    |> join(:inner, [uc], c in Connection, on: uc.connection_id == c.id)
    |> where([uc, c], c.user_id == ^item.user_id)
    |> where([uc, c], uc.user_id == ^current_user.id)
    |> preload([:connection, :user, :reverse_user])
    |> Repo.one()
  end

  @doc """
  Gets the permission settings that the POST AUTHOR has given to the CURRENT USER.

  When Dino views Isabella's post, this returns Isabella's user_connection settings
  that define what permissions Isabella has granted to Dino.

  This is the correct query for checking download permissions:
  - Find Isabella's connection TO Dino
  - Check if Isabella has enabled photos?: true for Dino
  """
  def get_post_author_permissions_for_viewer(item, current_user) do
    UserConnection
    |> join(:inner, [uc], c in Connection, on: uc.connection_id == c.id)
    # Current user's connection
    |> where([uc, c], c.user_id == ^current_user.id)
    # Post author's user_connection
    |> where([uc, c], uc.user_id == ^item.user_id)
    |> preload([:connection, :user, :reverse_user])
    |> Repo.one()
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

  def get_user_from_item(item) do
    Repo.one(
      from u in User,
        where: ^item.user_id == u.id,
        preload: [:connection]
    )
  end

  def get_user_from_item!(item) do
    Repo.one!(
      from u in User,
        where: ^item.user_id == u.id,
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
  Returns the list of UserConnections based
  on the selected filters. TODO: complete
  additional filter options.
  """
  def filter_user_connections(_filter, user) do
    # Get list of blocked user IDs to exclude from connections
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

  @doc """
  Returns the list of UserConnections based
  on the selected filters. TODO: complete
  additional filter options.
  """
  def filter_user_arrivals(_filter, user) do
    UserConnection
    |> where_user(user)
    |> where_not_confirmed()
    |> order_by([uc], desc: uc.inserted_at)
    |> preload([:connection])
    |> Repo.all()
  end

  @doc """
  Searches for UserConnections by label hash.
  This function searches for connections where the label matches
  the search query (case-insensitive exact match).
  """
  def search_user_connections(user, search_query) when is_binary(search_query) do
    # Normalize the search query for comparison with label_hash
    normalized_query = String.downcase(String.trim(search_query))

    if String.length(normalized_query) > 0 do
      # Get list of blocked user IDs to exclude from search results
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
      # If search query is empty, return all connections
      filter_user_connections(%{}, user)
    end
  end

  # query that scopes a UserConnection to a User.
  #
  # When a UserConnection is created and confirmed
  # between two users, each user gets a UserConnection
  # linked to them by their id as the UserConnection.user_id
  # and the other user is linked as the `reverse_user_id`.
  # So we only need to pull the UserConnection where the
  # current_user's `id` matches the `user_id` of the UserConnection.
  #
  # This is taking a %User{}.
  defp where_user(query, %User{} = user) do
    from(uc in query,
      where: uc.user_id == ^user.id
    )
  end

  defp where_user(query, _user), do: query

  # makes sure the UserConnection has been confirmed
  defp where_confirmed(query) do
    from(uc in query,
      where: not is_nil(uc.confirmed_at)
    )
  end

  # makes sure the UserConnection has been confirmed
  defp where_not_confirmed(query) do
    from(uc in query,
      where: is_nil(uc.confirmed_at)
    )
  end

  # excludes connections to blocked users
  defp where_not_blocked(query, blocked_user_ids) when is_list(blocked_user_ids) do
    case blocked_user_ids do
      [] ->
        query

      ids ->
        from(uc in query,
          where: uc.reverse_user_id not in ^ids
        )
    end
  end

  @doc """
  Starting query for listing user_connections arrivals for
  a current_user.
  """
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

  @doc """
  Gets the total count of a user's user_connection arrivals.
  """
  def arrivals_count(user) do
    query =
      from uc in UserConnection,
        where: uc.user_id == ^user.id,
        where: is_nil(uc.confirmed_at)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
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
    case Repo.transaction_on_primary(fn ->
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
         end) do
      {:ok, {:ok, %{insert_user: user, insert_connection: _conn}}} ->
        {:ok, user}
        |> broadcast_admin(:account_registered)

        {:ok, user}

      {:ok, {:error, :insert_user, changeset, _map}} ->
        {:error, changeset}

      {:ok, error} ->
        {:error, error}
    end
  end

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

      rest ->
        Logger.warning("Error updating user connection")
        Logger.debug("Error updating user connection: #{inspect(rest)}")
        {:error, "error"}
    end
  end

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

      rest ->
        Logger.warning("Error updating user connection")
        Logger.debug("Error updating user connection: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_user_connection_zen(uconn, attrs, opts) do
    current_user = Keyword.get(opts, :user) || uconn.user
    key = Keyword.get(opts, :key)
    new_zen_value = Map.get(attrs, :zen?, Map.get(attrs, "zen?"))

    # Get the target user ID (the person being muted/unmuted)
    target_user_id =
      if uconn.user_id == current_user.id,
        do: uconn.reverse_user_id,
        else: uconn.user_id

    case Repo.transaction_on_primary(fn ->
           Ecto.Multi.new()
           |> Ecto.Multi.update(:update_connection, fn _ ->
             uconn
             |> UserConnection.zen_changeset(attrs)
           end)
           |> Ecto.Multi.run(:update_timeline_prefs, fn _repo,
                                                        %{update_connection: _updated_uconn} ->
             if current_user && key do
               # Get or create timeline preferences
               timeline_prefs =
                 Timeline.get_user_timeline_preference(current_user) ||
                   %Timeline.UserTimelinePreference{user_id: current_user.id}

               # Get current decrypted muted users
               current_muted_users =
                 if timeline_prefs.muted_users && length(timeline_prefs.muted_users) > 0 do
                   Enum.map(timeline_prefs.muted_users, fn encrypted_user_id ->
                     Mosslet.Encrypted.Users.Utils.decrypt_user_data(
                       encrypted_user_id,
                       current_user,
                       key
                     )
                   end)
                   |> Enum.reject(&is_nil/1)
                 else
                   []
                 end

               # Update muted users list based on zen status
               new_muted_users =
                 if new_zen_value do
                   # Muting - add target user if not already muted
                   if target_user_id not in current_muted_users do
                     [target_user_id | current_muted_users]
                   else
                     current_muted_users
                   end
                 else
                   # Unmuting - remove target user
                   List.delete(current_muted_users, target_user_id)
                 end

               # Encrypt the updated muted users list
               encrypted_muted_users =
                 Enum.map(new_muted_users, fn user_id ->
                   Mosslet.Encrypted.Users.Utils.encrypt_user_data(user_id, current_user, key)
                 end)

               # Update timeline preferences
               attrs = %{muted_users: encrypted_muted_users}
               changeset = Timeline.UserTimelinePreference.changeset(timeline_prefs, attrs)

               case timeline_prefs do
                 %{id: nil} -> Repo.insert(changeset)
                 _ -> Repo.update(changeset)
               end
             else
               {:ok, :skipped}
             end
           end)
           |> Repo.transaction_on_primary()
         end) do
      {:ok, {:ok, %{update_connection: uconn, update_timeline_prefs: _}}} ->
        {:ok, uconn |> Repo.preload([:user, :connection])}
        |> broadcast(:uconn_updated)

      {:ok, {:error, :update_connection, changeset, _}} ->
        {:error, changeset}

      {:ok, {:error, :update_timeline_prefs, reason, _}} ->
        Logger.warning("Failed to update timeline preferences: #{inspect(reason)}")
        {:error, "Failed to sync mute status with content filters"}

      rest ->
        Logger.warning("Error updating user connection zen status")
        Logger.debug("Error updating user connection zen: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_user_connection_photos(uconn, attrs, _opts) do
    case Repo.transaction_on_primary(fn ->
           uconn
           |> UserConnection.photos_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, uconn}} ->
        updated_uconn = uconn |> Repo.preload([:user, :connection])

        # Broadcast to both the user who owns the connection AND the user whose permissions changed
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

      rest ->
        Logger.warning("Error updating user connection")
        Logger.debug("Error updating user connection: #{inspect(rest)}")
        {:error, "error"}
    end
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
    case Repo.transaction_on_primary(fn ->
           user
           |> User.onboarding_changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} ->
        {:ok, user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
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

  def change_user_connection_label(%UserConnection{} = uconn, attrs \\ %{}, opts \\ []) do
    UserConnection.label_changeset(uconn, attrs, opts)
  end

  # This may be deprecated
  def edit_user_connection(%UserConnection{} = uconn, attrs \\ %{}, opts \\ []) do
    UserConnection.changeset(uconn, attrs, opts)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user name.

  ## Examples

      iex> change_user_name(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_name(user, attrs \\ %{}, opts \\ []) do
    User.name_changeset(user, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user username.

  ## Examples

      iex> change_user_username(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_username(user, attrs \\ %{}, opts \\ []) do
    User.username_changeset(user, attrs, opts)
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
    Returns an `%Ecto.Changeset{}` for changing the user status visibility.

    ## Examples

        iex> change_user_status_visibility(user, attrs, opts)
        %Ecto.Changeset{data: %User{}}
  """
  def change_user_status_visibility(user, attrs \\ %{}, opts \\ []) do
    User.status_visibility_changeset(user, attrs, user: opts[:user], key: opts[:key])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user status.

  ## Examples

      iex> change_user_status(user, attrs, opts)
      %Ecto.Changeset{data: %User{}}
  """
  def change_user_status(user, attrs \\ %{}, opts \\ []) do
    User.status_changeset(user, attrs, opts)
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

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user's notifications boolean.

  ## Examples

      iex> change_user_notifications(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_notifications(user, attrs \\ %{}) do
    User.notifications_changeset(user, attrs, [])
  end

  def update_user_notifications(user, attrs \\ %{}, opts \\ []) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.notifications_changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} ->
        {:ok, user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
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
        Groups.maybe_update_name_for_user_groups(user, %{encrypted_name: c_attrs.c_name},
          key: opts[:key]
        )

        if user.connection.profile do
          profile_attrs = Map.put(attrs, "id", user.connection.id)

          profile_attrs =
            profile_attrs
            |> Map.put("profile", %{
              "username" => MossletWeb.Helpers.decr(user.username, user, opts[:key]),
              "temp_username" => MossletWeb.Helpers.decr(user.username, user, opts[:key]),
              "name" => attrs["name"],
              "email" => MossletWeb.Helpers.decr(user.email, user, opts[:key]),
              "visibility" => user.visibility,
              "about" => decrypt_profile_about(user, opts[:key])
            })

          profile_attrs =
            Map.put(
              profile_attrs,
              "profile",
              Map.put(profile_attrs["profile"], "opts_map", %{
                user: opts[:user],
                key: opts[:key],
                update_profile: true,
                encrypt: true
              })
            )

          with {:ok, conn} <-
                 update_user_profile(user, profile_attrs,
                   key: opts[:key],
                   user: opts[:user],
                   update_profile: true,
                   encrypt: true
                 ) do
            broadcast_connection(conn, :uconn_name_updated)

            {:ok, user}
          end
        else
          broadcast_connection(conn, :uconn_name_updated)

          {:ok, user}
        end

      {:error, :update_user, changeset, _map} ->
        {:error, changeset}

      {:error, :update_connection, changeset, _map} ->
        {:error, changeset}

      {:error, :update_user, _, :update_connection, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating user name")
        Logger.debug("Error updating user name: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  # includes name updates and marketing notification changes
  # for onboarding
  def update_user_onboarding_profile(user, attrs \\ %{}, opts \\ []) do
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
        # we broadcast
        broadcast_connection(conn, :uconn_name_updated)

        Groups.maybe_update_name_for_user_groups(user, %{encrypted_name: c_attrs.c_name},
          key: opts[:key]
        )

        # return {:ok, user}
        {:ok, user}

      {:error, :update_user, changeset, _map} ->
        {:error, changeset}

      {:error, :update_connection, changeset, _map} ->
        {:error, changeset}

      {:error, :update_user, _, :update_connection, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating user onboarding profile")
        Logger.debug("Error updating user onboarding profile: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_user_username(user, attrs \\ %{}, opts \\ []) do
    changeset = User.username_changeset(user, attrs, opts)
    conn = get_connection!(user.connection.id)

    c_attrs =
      changeset.changes.connection_map

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
        if user.connection.profile do
          profile_attrs = Map.put(attrs, "id", user.connection.id)

          profile_attrs =
            profile_attrs
            |> Map.put("profile", %{
              "username" => attrs["username"],
              "temp_username" => attrs["username"],
              "name" => MossletWeb.Helpers.decr(user.name, user, opts[:key]),
              "email" => MossletWeb.Helpers.decr(user.email, user, opts[:key]),
              "visibility" => user.visibility,
              "about" => decrypt_profile_about(user, opts[:key])
            })

          profile_attrs =
            Map.put(
              profile_attrs,
              "profile",
              Map.put(profile_attrs["profile"], "opts_map", %{
                user: opts[:user],
                key: opts[:key],
                update_profile: true,
                encrypt: true
              })
            )

          with {:ok, conn} <-
                 update_user_profile(user, profile_attrs,
                   key: opts[:key],
                   user: opts[:user],
                   update_profile: true,
                   encrypt: true
                 ) do
            broadcast_connection(conn, :uconn_username_updated)

            {:ok, user}
          end
        else
          broadcast_connection(conn, :uconn_username_updated)

          {:ok, user}
        end

      {:error, :update_user, changeset, _map} ->
        {:error, changeset}

      {:error, :update_connection, changeset, _map} ->
        {:error, changeset}

      {:error, :update_user, _, :update_connection, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating user username")
        Logger.debug("Error updating user username: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_user_oban_reset_token_id(user, attrs \\ %{}, opts \\ []) do
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

  def update_user_visibility(user, attrs \\ %{}, opts \\ []) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        user
        |> User.visibility_changeset(attrs, opts)
        |> Repo.update()
      end)

    case return do
      {:ok, user} ->
        if user.connection.profile do
          profile_attrs = Map.put(attrs, "id", user.connection.id)

          profile_attrs =
            profile_attrs
            |> Map.put("profile", %{
              "username" => MossletWeb.Helpers.decr(user.username, user, opts[:key]),
              "temp_username" => MossletWeb.Helpers.decr(user.username, user, opts[:key]),
              "name" => MossletWeb.Helpers.decr(user.name, user, opts[:key]),
              "email" => MossletWeb.Helpers.decr(user.email, user, opts[:key]),
              "visibility" => attrs["visibility"],
              "about" => decrypt_profile_about(user, opts[:key])
            })

          profile_attrs =
            Map.put(
              profile_attrs,
              "profile",
              Map.put(profile_attrs["profile"], "opts_map", %{
                user: user,
                key: opts[:key],
                update_profile: true,
                encrypt: true
              })
            )

          with {:ok, conn} <-
                 update_user_profile(user, profile_attrs,
                   key: opts[:key],
                   user: user,
                   update_profile: true,
                   encrypt: true
                 ) do
            broadcast_connection(conn, :uconn_visibility_updated)

            {:ok, user}
          end
        else
          broadcast_connection(user.connection, :uconn_visibility_updated)

          {:ok, user}
        end

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

  @doc """
  Dummy function to update a user as an admin to
  placehold for function in
  notification_subscriptions.ex.
  """
  def update_user_as_admin(user, _attrs \\ %{}) do
    if user, do: {:ok, user}, else: {:error, %Ecto.Changeset{}}
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

  def change_user_onboarding(user, attrs \\ %{}, opts \\ []) do
    User.profile_changeset(user, attrs, opts)
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

  @doc """
  Returns an `%Ecto.Changeset{}` for deleting the user data.

  ## Examples

      iex> change_user_delete_data(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_delete_data(user, attrs \\ %{}) do
    User.delete_data_changeset(user, attrs, delete_data: false)
  end

  @doc """
  Deletes a user's account.
  """
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
        |> broadcast_account_deleted(:account_deleted)

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes the data for a particular user without
  deleting their account.

  The key is the user's session key.
  """
  def delete_user_data(user, password, key, attrs \\ %{}, opts \\ []) do
    changeset =
      user
      |> User.delete_data_changeset(attrs, opts)
      |> User.validate_current_password(password)
      |> Map.put(:action, :delete)

    if changeset.valid? do
      delete_data_query(user, attrs, key)
    else
      {:error, changeset}
    end
  end

  defp delete_data_query(user, attrs, key) do
    data = Map.get(attrs, "data", "")

    if data == "" do
      {:ok, nil}
    else
      Enum.each(data, fn string ->
        delete_data_filter(user, attrs, key, string)
      end)
    end
  end

  defp delete_data_filter(user, attrs, key, "user_connections") do
    query =
      from(uc in UserConnection, where: uc.user_id == ^user.id or uc.reverse_user_id == ^user.id)

    uconns = get_all_user_connections(user.id)

    Enum.each(uconns, fn uconn ->
      delete_data_filter(uconn, attrs, key, "user_memories")
      delete_data_filter(uconn, attrs, key, "user_posts")
    end)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_user_connections, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, _return} ->
        uconns
        |> broadcast_user_connections(:uconn_deleted)

        uconns
        |> broadcast_public_user_connections(:public_uconn_deleted)

      {:error, error} ->
        {:error, error}

      _rest ->
        {:error, "There was an error deleting all user connections."}
    end
  end

  defp delete_data_filter(user, _attrs, _key, "groups") do
    query = from(g in Group, where: g.user_id == ^user.id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_group, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, _return} ->
        Phoenix.PubSub.broadcast(Mosslet.PubSub, "groups", {:groups_deleted, nil})

      _rest ->
        {:error, "There was an error deleting all groups."}
    end
  end

  defp delete_data_filter(user, _attrs, key, "memories") do
    query = from(m in Memory, where: m.user_id == ^user.id)
    memories = Repo.all(query)
    urls = get_urls_from_deleted_memories(user, key, memories)
    # TODO: update to be an Oban.Job
    Mosslet.Memories.make_async_aws_requests(urls)
    uconns = get_all_user_connections(user.id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_memories, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, _return} ->
        uconns
        |> broadcast_user_connections(:memories_deleted)

      _rest ->
        {:error, "There was an error deleting all memories."}
    end
  end

  # when deleting all posts, we also get the relevant reply_urls
  # to delete those from the cloud as well. The actual replies will
  # be deleted from the db based on their association to the post
  defp delete_data_filter(user, _attrs, key, "posts") do
    query = from(p in Post, where: p.user_id == ^user.id, preload: [replies: :post])
    posts = Repo.all(query)
    uconns = get_all_user_connections(user.id)
    replies = get_all_replies_from_posts(posts)
    reply_urls = get_urls_from_deleted_replies(user, key, replies)

    urls = get_urls_from_deleted_posts(user, key, posts)

    case delete_object_storage_post_worker(%{"urls" => urls}) do
      {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
        # delete the reply urls related to the posts from the cloud
        delete_object_storage_reply_worker(%{"urls" => reply_urls})
        del_query = from(p in Post, where: p.user_id == ^user.id)

        Ecto.Multi.new()
        |> Ecto.Multi.delete_all(:delete_all_post, del_query)
        |> Repo.transaction_on_primary()
        |> case do
          {:ok, _return} ->
            uconns
            |> broadcast_user_connections(:posts_deleted)

          rest ->
            Logger.info("Error deleting all Posts in Accounts context.")
            Logger.info(inspect(rest))
            Logger.error(rest)
            {:error, "There was an error deleting all posts."}
        end

      rest ->
        Logger.info("Error deleting all Post data from the cloud in Accounts context.")
        Logger.info(inspect(rest))
        Logger.error(rest)
        {:error, "There was an error deleting post data from the cloud."}
    end
  end

  defp delete_data_filter(uconn, _attrs, _key, "user_memories") do
    query =
      from(
        um in UserMemory,
        inner_join: m in Memory,
        on: um.memory_id == m.id,
        where: m.user_id == ^uconn.reverse_user_id and ^uconn.user_id == um.user_id
      )

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_user_memories, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, _return} ->
        :ok

      _rest ->
        {:error, "There was an error deleting all user memories."}
    end
  end

  defp delete_data_filter(uconn, _attrs, _key, "user_posts") do
    query =
      from(
        up in UserPost,
        inner_join: p in Post,
        on: up.post_id == p.id,
        where: p.user_id == ^uconn.reverse_user_id and ^uconn.user_id == up.user_id
      )

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_user_post, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, _return} ->
        :ok

      _rest ->
        {:error, "There was an error deleting all user posts."}
    end
  end

  defp delete_data_filter(user, _attrs, _key, "remarks") do
    query = from(r in Remark, where: r.user_id == ^user.id)
    uconns = get_all_user_connections(user.id)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_all_remark, query)
    |> Repo.transaction_on_primary()
    |> case do
      {:ok, _return} ->
        uconns
        |> broadcast_user_connections(:remarks_deleted)

      _rest ->
        {:error, "There was an error deleting all remarks."}
    end
  end

  defp delete_data_filter(user, _attrs, key, "replies") do
    query = from(r in Reply, where: r.user_id == ^user.id, preload: [:post])
    replies = Repo.all(query)
    uconns = get_all_user_connections(user.id)
    urls = get_urls_from_deleted_replies(user, key, replies)

    case delete_object_storage_reply_worker(%{"urls" => urls}) do
      {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
        del_query = from(r in Reply, where: r.user_id == ^user.id)

        Ecto.Multi.new()
        |> Ecto.Multi.delete_all(:delete_all_reply, del_query)
        |> Repo.transaction_on_primary()
        |> case do
          {:ok, _return} ->
            uconns
            |> broadcast_user_connections(:replies_deleted)

          rest ->
            Logger.info("Error deleting all Replies in Accounts context.")
            Logger.info(inspect(rest))
            Logger.error(rest)
            {:error, "There was an error deleting all Replies."}
        end

      rest ->
        Logger.info("Error deleting all Reply data from the cloud in Accounts context.")
        Logger.info(inspect(rest))
        Logger.error(rest)
        {:error, "There was an error deleting reply data from the cloud."}
    end
  end

  defp get_urls_from_deleted_posts(user, key, posts) when is_list(posts) do
    # loop through each post
    Enum.map(posts, fn post ->
      # we don't delete the original post urls (in case it belongs to another user)
      if !post.repost && is_list(post.image_urls) do
        # then through each image_url and decrypt
        Enum.map(post.image_urls, fn e_image_url ->
          MossletWeb.Helpers.decr_item(
            e_image_url,
            user,
            MossletWeb.Helpers.get_post_key(post, user),
            key,
            post
          )
        end)
      end
    end)
    |> List.flatten()
    |> Enum.filter(fn url -> !is_nil(url) end)
  end

  defp get_urls_from_deleted_replies(user, key, replies) when is_list(replies) do
    # loop through each reply
    Enum.map(replies, fn reply ->
      # we don't delete the original reply urls (in case it belongs to another user)
      if is_list(reply.image_urls) && !Enum.empty?(reply.image_urls) do
        # then through each image_url and decrypt
        Enum.map(reply.image_urls, fn e_image_url ->
          MossletWeb.Helpers.decr_item(
            e_image_url,
            user,
            MossletWeb.Helpers.get_post_key(reply.post, user),
            key,
            reply
          )
        end)
      end
    end)
    |> List.flatten()
    |> Enum.filter(fn url -> !is_nil(url) end)
  end

  # We use this when deleting all posts to get an replies that
  # a post may have and then use that list of replies to get their
  # urls to delete any reply-related urls from the cloud.
  #
  # The replies themselves will already be deleted from the db based
  # on the cascading nature of the association to the post
  defp get_all_replies_from_posts(posts) when is_list(posts) do
    # loop through each post
    Enum.map(posts, fn post ->
      # we don't delete the original post reply urls (in case it belongs to another user)
      if !post.repost && is_list(post.replies) && !Enum.empty?(post.replies) do
        # loop through each reply for the image urls
        Enum.map(post.replies, fn reply ->
          reply
        end)
      end
    end)
    |> List.flatten()
    |> Enum.filter(fn reply -> !is_nil(reply) end)
  end

  defp get_all_replies_from_posts(_replies), do: nil

  defp get_urls_from_deleted_memories(user, key, memories) when is_list(memories) do
    Enum.map(memories, fn memory ->
      MossletWeb.Helpers.decr_item(
        memory.memory_url,
        user,
        MossletWeb.Helpers.get_memory_key(memory, user),
        key,
        memory
      )
    end)
  end

  defp delete_object_storage_post_worker(params) do
    params
    |> Mosslet.Workers.DeleteObjectStoragePostWorker.new()
    |> Oban.insert()
  end

  defp delete_object_storage_reply_worker(params) do
    params
    |> Mosslet.Workers.DeleteObjectStorageReplyWorker.new()
    |> Oban.insert()
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
  Emulates that the e-mail will change without actually changing
  it in the database. Used for email changes and no passwords.

  ## Examples

      iex> check_if_can_change_user_email(user, valid_password, %{email: "valid_email@gmail.com"})
      {:ok, %User{}}

      iex> check_if_can_change_user_email(user, invalid_password, %{email: "valid_email@gmail.com"})
      {:error, %Ecto.Changeset{}}

      iex> check_if_can_change_user_email(user, valid_password, %{email: "existing_users_email@gmail.com"})
      {:error, %Ecto.Changeset{}}

  """
  def check_if_can_change_user_email(user, password, attrs \\ %{}) do
    user
    |> User.email_changeset(attrs)
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
      if user.connection.profile do
        profile_attrs = Map.put(%{}, "id", user.connection.id)

        profile_attrs =
          profile_attrs
          |> Map.put("profile", %{
            "username" => MossletWeb.Helpers.decr(user.username, user, key),
            "temp_username" => MossletWeb.Helpers.decr(user.username, user, key),
            "name" => MossletWeb.Helpers.decr(user.username, user, key),
            "email" => email,
            "visibility" => user.visibility,
            "about" => decrypt_profile_about(user, key)
          })

        profile_attrs =
          Map.put(
            profile_attrs,
            "profile",
            Map.put(profile_attrs["profile"], "opts_map", %{
              user: user,
              key: key,
              update_profile: true,
              encrypt: true
            })
          )

        with {:ok, conn} <-
               update_user_profile(user, profile_attrs,
                 key: key,
                 user: user,
                 update_profile: true,
                 encrypt: true
               ) do
          broadcast_connection(conn, :uconn_email_updated)
          :ok
        end
      else
        broadcast_connection(conn, :uconn_email_updated)
        :ok
      end
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

    case maybe_delete_existing_avatar(user, attrs, conn, c_attrs, opts) do
      {:ok, %{update_user: user, update_connection: conn}} ->
        broadcast_connection(conn, :uconn_avatar_updated)
        {:ok, user, conn}

      {:error, :update_user, changeset, _map} ->
        {:error, changeset}

      {:error, :update_connection, changeset, _map} ->
        {:error, changeset}

      {:error, :update_user, _, :update_connection, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating user avatar")
        Logger.debug("Error updating user avatar: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  defp maybe_delete_existing_avatar(user, attrs, conn, c_attrs, opts) do
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
  Delivers the update email instructions to the given user. The email is delivered
  to the current_email address.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, new_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(
        %User{} = user,
        current_email,
        new_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
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

    return =
      Repo.transaction_on_primary(fn ->
        Repo.insert_or_update(totp_changeset)
      end)

    case return do
      {:ok, {:ok, user_totp}} -> {:ok, user_totp}
      {:ok, {:error, changeset}} -> {:error, changeset}
    end
  end

  @doc """
  Regenerates the user backup codes for totp.

  ## Examples

      iex> regenerate_user_totp_backup_codes(%UserTOTP{})
      %UserTOTP{backup_codes: [...]}

  """
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

  @doc """
  Disables the TOTP configuration for the given user.
  """
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

  @doc """
  Validates if the given TOTP code is valid.
  """
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

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)

    Repo.transaction_on_primary(fn ->
      Repo.insert!(user_token)
    end)

    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    Repo.one(query)
    |> Repo.preload([:connection, :customer])
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

      iex> deliver_user_confirmation_instructions(user, &url(~p"/auth/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/auth/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, email, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
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

  @doc """
  Confirms a user without checking any tokens. Used
  with passwordless / Ueberauth.
  """

  def confirm_user!(%User{confirmed_at: nil} = user) do
    with {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      user
    end
  end

  def confirm_user!(user), do: user

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

          rest ->
            Logger.warning("Error confirming user_connection second level")
            Logger.debug("Error confirming user_connection second level: #{inspect(rest)}")
            {:error, "error"}
        end

      {:ok, {:ok, {:error, changeset}}} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error confirming user_connection first level")
        Logger.debug("Error confirming user_connection first level: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def delete_user_connection(%UserConnection{} = uconn) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(uconn)
         end) do
      {:ok, {:ok, uconn}} ->
        delete_data_filter(uconn, %{}, nil, "user_memories")
        delete_data_filter(uconn, %{}, nil, "user_posts")

        {:ok, uconn}
        |> broadcast(:uconn_deleted)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error deleting user_connection")
        Logger.debug("Error deleting user_connection: #{inspect(rest)}")
        {:error, "error"}
    end
  end

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
        Enum.each(uconns, fn uconn ->
          delete_data_filter(uconn, %{}, nil, "user_memories")
          delete_data_filter(uconn, %{}, nil, "user_posts")
        end)

        uconns
        |> broadcast_user_connections(:uconn_deleted)

        {:ok, uconns}

      rest ->
        Logger.warning("Error deleting user_connection")
        Logger.debug("Error deleting user_connection: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset-password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, email, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
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
      _rest -> nil
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

  # Status broadcasting functions
  def broadcast_user_status({:ok, %User{} = user}, event) do
    # Broadcast to user's own channel for real-time updates
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "user_status:#{user.id}", {event, user})

    # Privacy-aware broadcasting to connections based on status_visibility
    broadcast_status_to_authorized_users(user, event)

    {:ok, user}
  end

  defp broadcast({:ok, %UserConnection{} = uconn}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "accounts:#{uconn.user_id}", {event, uconn})
    {:ok, uconn}
  end

  # Privacy-aware status broadcasting function
  defp broadcast_status_to_authorized_users(user, event) do
    case {user.status_visibility, event} do
      # Special case: always broadcast status_visibility_updated to connections
      # so they know to update their UI when someone's visibility changes
      {_, :status_visibility_updated} ->
        broadcast_status_to_all_connections(user, event)

      {:nobody, _} ->
        # No broadcasting to connections for status updates when visibility is nobody
        :ok

      {:connections, _} ->
        # Broadcast to all connections
        broadcast_status_to_all_connections(user, event)

      {:specific_groups, _} ->
        # Broadcast only to users in specific groups
        broadcast_status_to_specific_groups(user, event)

      {:specific_users, _} ->
        # Broadcast only to specific users
        broadcast_status_to_specific_users(user, event)

      {:public, _} ->
        # For public status, broadcast to all connections (could also broadcast to public channel)
        broadcast_status_to_all_connections(user, event)

      _ ->
        # Default: no broadcasting
        :ok
    end
  end

  defp broadcast_status_to_all_connections(user, event) do
    # Get all user connections for this user
    user_connections = get_all_user_connections(user.id)

    Enum.each(user_connections, fn user_connection ->
      # Determine which user to notify (the other user in the connection)
      target_user_id =
        if user_connection.user_id == user.id do
          user_connection.reverse_user_id
        else
          user_connection.user_id
        end

      # Broadcast to the connection's status updates channel
      Phoenix.PubSub.broadcast(
        Mosslet.PubSub,
        "connection_status:#{target_user_id}",
        {event, user}
      )
    end)
  end

  defp broadcast_status_to_specific_users(user, event) do
    # Get the list of specific users from user.status_visible_to_users (encrypted)
    # This would need to be decrypted, but for now we'll implement a simpler approach
    # by broadcasting to all connections and letting the frontend handle visibility
    broadcast_status_to_all_connections(user, event)
  end

  defp broadcast_status_to_specific_groups(user, event) do
    # Similar to specific users, but for groups
    # For now, broadcast to all connections
    broadcast_status_to_all_connections(user, event)
  end

  defp broadcast_admin({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "admin:accounts", {event, struct})
    {:ok, struct}
  end

  defp broadcast_public({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "accounts", {event, struct})
    {:ok, struct}
  end

  defp broadcast_account_deleted({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "account_deleted", {event, struct})

    {:ok, struct}
  end

  defp broadcast_user_connections(uconns, event) when is_list(uconns) do
    Enum.each(uconns, fn uconn ->
      {:ok, uconn |> Repo.preload([:user, :connection])}
      |> broadcast(event)
    end)
  end

  defp broadcast_connection(conn, event) do
    conn = conn |> Repo.preload([:user_connections])
    broadcast_user_connections(conn.user_connections, event)
  end

  defp broadcast_public_connection(conn, event) do
    broadcast_public({:ok, conn}, event)
  end

  defp broadcast_public_user_connections(uconns, event) when is_list(uconns) do
    Enum.each(uconns, fn uconn ->
      {:ok, uconn |> Repo.preload([:user, :connection])}
      |> broadcast_public(event)
    end)
  end

  def private_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "accounts:#{user.id}")
  end

  def subscribe() do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "accounts")
  end

  def subscribe_account_deleted() do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "account_deleted")
  end

  def subscribe_user_status(user_id) when is_binary(user_id) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "user_status:#{user_id}")
  end

  def subscribe_user_status(%User{id: user_id}) do
    subscribe_user_status(user_id)
  end

  def subscribe_connection_status(user_id) when is_binary(user_id) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "connection_status:#{user_id}")
  end

  def subscribe_connection_status(%User{id: user_id}) do
    subscribe_connection_status(user_id)
  end

  def admin_subscribe(user) do
    if user.is_admin? do
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "admin:accounts")
    end
  end

  def block_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "blocks:#{user.id}")
  end

  # from Mosslet
  def update_last_signed_in_info(user, ip, key) do
    user
    |> User.last_signed_in_changeset(ip, key)
    |> Repo.update()
  end

  def preload_org_data(user, current_org_slug \\ nil) do
    user = Repo.preload(user, :orgs)

    if current_org_slug do
      %{user | current_org: Enum.find(user.orgs, &(&1.slug == current_org_slug))}
    else
      user
    end
  end

  @doc """
  Returns a User changeset that is valid if the current password is valid.

  It returns a changeset. The changeset has an action if the current password
  is not nil.
  """
  def validate_user_current_password(user, current_password) do
    user
    |> Ecto.Changeset.change()
    |> User.validate_current_password(current_password)
    |> attach_action_if_current_password(current_password)
  end

  defp attach_action_if_current_password(changeset, nil), do: changeset

  defp attach_action_if_current_password(changeset, _),
    do: Map.replace!(changeset, :action, :validate)

  # User lifecyle actions - these allow you to hook into certain user events and do secondary tasks like create logs, send Slack messages etc.
  def user_lifecycle_action(action, user, opts \\ %{})

  def user_lifecycle_action("after_confirm_email", user, _) do
    Logs.log_async("confirm_email", %{user: user})
    Mosslet.Orgs.sync_user_invitations(user)
  end

  def user_lifecycle_action("after_sign_in", user, %{ip: ip, key: key}) do
    Logs.log_async("sign_in", %{user: user})
    {:ok, user} = update_last_signed_in_info(user, ip, key)
    Mosslet.MailBluster.sync_user_async(user)
  end

  def user_lifecycle_action("after_impersonate_user", user, %{
        ip: ip,
        target_user_id: target_user_id,
        key: key
      }) do
    Logs.log_async("impersonate_user", %{user: user, target_user_id: target_user_id})
    update_last_signed_in_info(user, ip, key)
  end

  def user_lifecycle_action("after_restore_impersonator", user, %{
        ip: ip,
        target_user_id: target_user_id,
        key: key
      }) do
    Logs.log_async("restore_impersonator", %{user: user, target_user_id: target_user_id})
    update_last_signed_in_info(user, ip, key)
  end

  def user_lifecycle_action("after_update_profile", user, _) do
    Logs.log_async("update_profile", %{user: user})
    Mosslet.MailBluster.sync_user_async(user)
  end

  def user_lifecycle_action("after_confirm_new_email", user, _) do
    Logs.log_async("confirm_new_email", %{user: user})
    Mosslet.Orgs.sync_user_invitations(user)
  end

  def user_lifecycle_action("request_new_email", user, %{new_email: new_email}) do
    Logs.log_async("request_new_email", %{user: user, metadata: %{new_email: new_email}})
  end

  def user_lifecycle_action("after_passwordless_pin_sent", user, %{pin: pin}) do
    Logs.log_async("passwordless_pin_sent", %{user: user})

    # Allow devs to see the pin in the server logs to sign in with
    if Mosslet.config(:env) == :dev do
      Logger.info("----------- PIN ------------")
      Logger.info(pin)
    end
  end

  def user_lifecycle_action("billing.after_click_subscribe_button", user, %{
        plan: plan,
        customer: customer,
        billing_provider: billing_provider,
        billing_provider_session: billing_provider_session
      }) do
    Mosslet.Slack.message("""
    :scream_cat: #{user.name} has clicked a subscribe button for "#{plan.id}"...
    """)

    Logs.log_async("billing.click_subscribe_button", %{
      user: user,
      customer: customer,
      org: if(customer.org_id, do: customer.org),
      metadata: %{
        plan_id: plan.id,
        billing_provider: billing_provider,
        billing_provider_session_id: billing_provider_session.id
      }
    })
  end

  def user_lifecycle_action("billing.create_subscription", user, %{
        subscription: subscription,
        customer: customer
      }) do
    plan = Plans.get_plan_by_subscription!(subscription)

    Mosslet.Slack.message("""
    :moneybag: #{user.name} (##{user.id}) just purchased a subscription!
    **Plan:** "#{plan.id}"
    """)

    Logs.log_async("billing.subscribe_subscription", %{
      customer: customer,
      user_id: customer.user_id,
      org_id: customer.org_id,
      metadata: %{
        subscription_id: subscription.id,
        plan_id: plan.id
      }
    })
  end

  def user_lifecycle_action("billing.update_subscription", user, %{
        subscription: subscription,
        customer: customer
      }) do
    Mosslet.Slack.message("""
    #{user.name} (##{user.id}) just updated a subscription for the plan: "#{subscription.plan_id}"
    """)

    Logs.log_async("billing.update_subscription", %{
      customer: customer,
      user_id: customer.user_id,
      org_id: customer.org_id,
      metadata: %{
        subscription_id: subscription.id,
        plan_id: subscription.plan_id
      }
    })
  end

  def user_lifecycle_action("billing.create_payment_intent", user, %{
        payment_intent: payment_intent,
        customer: customer
      }) do
    Mosslet.Slack.message("""
    :moneybag: #{user.name} (##{user.id}) just purchased a membership!
    """)

    Logs.log_async("billing.create_payment_intent", %{
      customer: customer,
      user_id: customer.user_id,
      org_id: customer.org_id,
      metadata: %{
        payment_intent_id: payment_intent.id,
        customer_id: payment_intent.customer
      }
    })
  end

  def user_lifecycle_action("billing.update_payment_intent", user, %{
        payment_intent: payment_intent,
        customer: customer
      }) do
    Mosslet.Slack.message("""
    #{user.name} (##{user.id}) just updated a payment_intent: "#{payment_intent.id}"
    """)

    Logs.log_async("billing.update_payment_intent", %{
      customer: customer,
      user_id: customer.user_id,
      org_id: customer.org_id,
      metadata: %{
        payment_intent_id: payment_intent.id,
        customer_id: payment_intent.customer
      }
    })
  end

  def user_lifecycle_action("billing.cancel_subscription", user, %{
        subscription: subscription,
        customer: customer
      }) do
    Mosslet.Slack.message("""
    #{user.name} (##{user.id}) just cancelled a subscription for the plan: "#{subscription.plan_id}"
    """)

    Logs.log_async("billing.cancel_subscription", %{
      customer: customer,
      user_id: customer.user_id,
      org_id: customer.org_id,
      metadata: %{
        subscription_id: subscription.id,
        plan_id: subscription.plan_id
      }
    })
  end

  def user_lifecycle_action("billing.more_than_one_active_subscription_warning", _user, %{
        subscription: subscription,
        customer: customer,
        active_subscriptions_count: active_subscriptions_count
      }) do
    Mosslet.Slack.message("""
    :exclamation: *Customer #{customer.id} now has #{active_subscriptions_count} active subscriptions.* They may have been double charged. This is possible if Stripe processes multiple purchases in multiple tabs.
    Stripe Customer: #{customer.provider_customer_id}
    Stripe Subscription: #{subscription.provider_subscription_id}
    """)

    Logs.log_async("billing.more_than_one_active_subscription_warning", %{
      user_id: customer.user_id,
      org_id: customer.org_id,
      metadata: %{
        subscription_id: subscription.id,
        plan_id: subscription.plan_id
      }
    })
  end

  # we need to have a key to decrypt the user's name
  def user_lifecycle_action("after_register", user, key, %{registration_type: registration_type}) do
    Logs.log_async("register", %{
      user: user,
      metadata: %{registration_type: registration_type}
    })

    Mosslet.Orgs.sync_user_invitations(user)

    Mosslet.Slack.message("""
    :bust_in_silhouette: *A new user joined!*
    *Name*: #{MossletWeb.Helpers.user_name(user, key)}

    #{MossletWeb.Router.Helpers.admin_dash_url(MossletWeb.Endpoint, :index)}
    """)
  end

  defp decrypt_profile_about(user, key) do
    profile = Map.get(user.connection, :profile)

    cond do
      profile && not is_nil(profile.about) ->
        cond do
          profile.visibility == :public ->
            Encrypted.Users.Utils.decrypt_public_item(profile.about, profile.profile_key)

          profile.visibility == :private ->
            MossletWeb.Helpers.decr_item(profile.about, user, profile.profile_key, key, profile)

          profile.visibility == :connections ->
            MossletWeb.Helpers.decr_item(
              profile.about,
              user,
              profile.profile_key,
              key,
              profile
            )

          true ->
            profile.about
        end

      true ->
        nil
    end
  end

  ## Blocking Management

  @doc """
  Blocks a user.

  ## Examples

      iex> block_user(blocker, blocked_user, %{
      ...>   reason: "Inappropriate content",
      ...>   block_type: :full
      ...> })
      {:ok, %UserBlock{}}
  """
  def block_user(blocker, blocked_user, attrs \\ %{}, opts \\ []) do
    attrs =
      attrs
      |> Map.put("blocker_id", blocker.id)
      |> Map.put("blocked_id", blocked_user.id)

    # Check if block already exists
    existing_block = Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user.id)

    case Repo.transaction_on_primary(fn ->
           if existing_block do
             # Update existing block
             existing_block
             |> UserBlock.changeset(attrs, opts)
             |> Repo.update()
           else
             # Create new block
             %UserBlock{}
             |> UserBlock.changeset(attrs, opts)
             |> Repo.insert()
           end
         end) do
      {:ok, {:ok, block}} ->
        # Broadcast block creation/update for real-time filtering
        event = if existing_block, do: :user_block_updated, else: :user_blocked

        # Broadcast to both the blocker AND the blocked user for bidirectional real-time updates
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

  @doc """
  Unblocks a user.
  """
  def unblock_user(blocker, blocked_user) do
    block = Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user.id)

    if block do
      case Repo.transaction_on_primary(fn ->
             Repo.delete(block)
           end) do
        {:ok, {:ok, deleted_block}} ->
          # Broadcast to both the blocker AND the blocked user for bidirectional real-time updates
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

  @doc """
  Gets a specific user block if it exists.
  """
  def get_user_block(blocker, blocked_user_id) when is_binary(blocked_user_id) do
    Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user_id)
  end

  @doc """
  Checks if a user has blocked another user.
  """
  def user_blocked?(blocker, blocked_user) do
    query =
      from b in UserBlock,
        where: b.blocker_id == ^blocker.id and b.blocked_id == ^blocked_user.id

    Repo.exists?(query)
  end

  @doc """
  Gets all users blocked by a user.
  """
  def list_blocked_users(user) do
    query =
      from b in UserBlock,
        where: b.blocker_id == ^user.id,
        preload: [:blocked],
        order_by: [desc: b.inserted_at]

    Repo.all(query)
  end

  ## Status Management

  @doc """
  Updates a user's status and status message following the dual-update pattern.
  """
  def update_user_status(user, attrs, opts \\ []) do
    Mosslet.Statuses.update_user_status(user, attrs, opts)
  end

  @doc """
  Tracks user activity and potentially updates auto-status.
  """
  def track_user_activity(user, activity_type \\ :general) do
    Mosslet.Statuses.track_user_activity(user, activity_type)
  end

  @doc """
  Gets the visible status for a user as seen by another user.
  """
  def get_user_status_for_connection(user, viewing_user, session_key) do
    Mosslet.Statuses.get_user_status_for_connection(user, viewing_user, session_key)
  end

  @doc """
  Suspends a user account (admin function).
  """
  def suspend_user(%User{} = user, %User{} = admin_user) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.admin_suspension_changeset(%{"is_suspended?" => true}, admin_user)
           |> Repo.update()
         end) do
      {:ok, {:ok, suspended_user}} ->
        # Broadcast suspension for real-time updates
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

  def suspend_user(_user, _non_admin_user) do
    {:error, :unauthorized}
  end

  @doc """
  Creates a visibility group for a user.
  """
  def create_visibility_group(user, group_params, opts \\ []) do
    # Prepare the group data for encryption
    group_attrs = %{
      "temp_name" => group_params["name"],
      "temp_description" => group_params["description"] || "",
      "color" => String.to_existing_atom(group_params["color"] || "teal"),
      "temp_connection_ids" => group_params["connection_ids"] || []
    }

    case Repo.transaction_on_primary(fn ->
           # CRITICAL: Get fresh user data from DB to avoid stale embedded data
           fresh_user = Repo.get(User, user.id)

           fresh_user
           |> User.add_visibility_group_changeset(group_attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_user}} ->
        # Broadcast update for real-time UI updates
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

  @doc """
  Updates an existing visibility group for a user.
  """
  def update_visibility_group(user, group_id, group_params, opts \\ []) do
    case Repo.transaction_on_primary(fn ->
           # Get fresh user data from DB to avoid stale embedded data
           fresh_user = Repo.get(User, user.id)

           # Find the group to update and create changesets for all groups
           group_changesets =
             Enum.map(fresh_user.visibility_groups || [], fn group ->
               if group.id == group_id do
                 # Prepare the group data for encryption
                 group_attrs = %{
                   "temp_name" => group_params["name"],
                   "temp_description" => group_params["description"] || "",
                   "color" => String.to_existing_atom(group_params["color"] || "teal"),
                   "temp_connection_ids" => group_params["connection_ids"] || []
                 }

                 # Create a changeset for the group being updated
                 User.visibility_group_changeset(group, group_attrs, opts)
               else
                 # For groups not being updated, pass them through unchanged
                 group
               end
             end)

           # Update user with the group changesets using put_embed
           fresh_user
           |> Ecto.Changeset.change()
           |> Ecto.Changeset.put_embed(:visibility_groups, group_changesets)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_user}} ->
        # Broadcast update for real-time UI updates
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

  @doc """
  Deletes a visibility group from a user.
  """
  def delete_visibility_group(user, group_id) do
    case Repo.transaction_on_primary(fn ->
           # Get user with current visibility groups
           user_with_groups = Repo.get(User, user.id)

           # Filter out the group to delete
           updated_groups =
             Enum.reject(user_with_groups.visibility_groups || [], fn group ->
               group.id == group_id
             end)

           # Update user with remaining groups
           user_with_groups
           |> Ecto.Changeset.change()
           |> Ecto.Changeset.put_embed(:visibility_groups, updated_groups)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_user}} ->
        # Broadcast update for real-time UI updates
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

  @doc """
  Gets all visibility groups from the user's visibility groups.
  Returns the user's visibility groups with connection details for proper decryption.
  """
  def get_user_visibility_groups_with_connections(user) do
    # Get user with visibility groups (no preload needed for embedded schemas)
    user_with_groups = Repo.get(User, user.id)

    # Transform visibility groups to match the expected format for templates
    Enum.map(user_with_groups.visibility_groups || [], fn group ->
      # For each group, return the group data with empty user_connections
      # The actual count should come from group.connection_ids
      %{group: group, user: user_with_groups, user_connections: []}
    end)
  end
end
