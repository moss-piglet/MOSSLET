defmodule Mosslet.Accounts do
  @moduledoc """
  The Accounts context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Accounts.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Accounts.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """
  require Logger

  import Ecto.Query, warn: false

  alias Mosslet.Platform

  alias Mosslet.Accounts.{
    Connection,
    User,
    UserConnection,
    UserToken,
    UserNotifier
  }

  alias Mosslet.Encrypted
  alias Mosslet.Groups
  alias Mosslet.Logs

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.Accounts.Adapters.Web
    end
  end

  ## Preloads

  def preload_connection(%User{} = user) do
    adapter().preload_connection(user)
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
    adapter().get_user_by_email(email)
  end

  def get_user_by_username(username) when is_binary(username) do
    adapter().get_user_by_username(username)
  end

  @doc """
  Get user by username. This checks to make sure
  the current user is not the user being searched for
  and does not having a pending UserConnection.

  This is used to send connection requests and we
  don't want people to send themselves requests.
  """
  def get_user_by_username(user, username) when is_binary(username) and is_struct(user) do
    adapter().get_user_by_username_for_connection(user, username)
  end

  @doc """
  Get user by username to share a post with.
  This checks to make sure the current_user_id
  is not the user be searched for and HAS a
  confirmed UserConnection.
  """
  def get_shared_user_by_username(user_id, username)
      when is_binary(username) do
    adapter().get_shared_user_by_username(user_id, username)
  end

  def get_shared_user_by_username(_, _username), do: nil

  @doc """
  Get user by email. This checks to make sure
  the current user is not the user be searched for.

  This is used to send connection requests and we
  don't want people to send themselves requests.
  """
  def get_user_by_email(user, email) when is_binary(email) do
    adapter().get_user_by_email_for_connection(user, email)
  end

  def has_user_connection?(%User{} = user, current_user) do
    adapter().has_user_connection?(user, current_user)
  end

  def has_confirmed_user_connection?(%User{} = user, current_user_id) do
    adapter().has_confirmed_user_connection?(user, current_user_id)
  end

  def has_any_user_connections?(user) do
    adapter().has_any_user_connections?(user)
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
    adapter().get_user_by_email_and_password(email, password)
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
  def get_user!(id), do: adapter().get_user!(id)
  def get_user(id), do: adapter().get_user(id)

  def get_user_with_preloads(id) do
    adapter().get_user_with_preloads(id)
  end

  def get_user_from_profile_slug!(slug) do
    adapter().get_user_from_profile_slug!(slug)
  end

  def get_user_from_profile_slug(slug) do
    adapter().get_user_from_profile_slug(slug)
  end

  def get_connection!(id), do: adapter().get_connection!(id)
  def get_connection(id), do: adapter().get_connection(id)

  def get_user_connection(id), do: adapter().get_user_connection(id)
  def get_user_connection!(id), do: adapter().get_user_connection!(id)

  def get_both_user_connections_between_users!(user_id, reverse_user_id) do
    adapter().get_both_user_connections_between_users!(user_id, reverse_user_id)
  end

  @doc """
  Currently returns the user_connection for the user_id
  coming from the associated `user_id` on a %UserGroup{} and the current_user_id.

  We check if the ids are the same when building the member list
  for a group. We also return `nil` as some users in the group
  may not be connected to each other.
  """
  def get_user_connection_for_user_group(user_id, current_user_id) do
    adapter().get_user_connection_for_user_group(user_id, current_user_id)
  end

  def get_user_connection_for_reply_shared_users(reply_user_id, current_user_id) do
    adapter().get_user_connection_for_reply_shared_users(reply_user_id, current_user_id)
  end

  @doc """
  Currently returns the user_connection for the current_user that is
  connected to the `user_id` as the reverse user.
  """
  def get_current_user_connection_between_users!(user_id, current_user_id) do
    adapter().get_current_user_connection_between_users!(user_id, current_user_id)
  end

  @doc """
  Gets the %UserConnection{} for the current_user where
  the user_connection.user_id == current_user_id and the
  user_id == the user_connection.reverse_user_id.
  """
  def get_user_connection_between_users!(user_id, current_user_id) do
    adapter().get_user_connection_between_users!(user_id, current_user_id)
  end

  @doc """
  Gets the %UserConnection{} for the current_user where
  the user_connection.user_id == current_user_id and the
  user_id == the user_connection.reverse_user_id.
  """
  def get_user_connection_between_users(user_id, current_user_id) do
    adapter().get_user_connection_between_users(user_id, current_user_id)
  end

  def validate_users_in_connection(user_connection_id, current_user_id) do
    adapter().validate_users_in_connection(user_connection_id, current_user_id)
  end

  def get_all_user_connections(id) do
    adapter().get_all_user_connections(id)
  end

  def get_all_confirmed_user_connections(id) do
    adapter().get_all_confirmed_user_connections(id)
  end

  def get_muted_connection_user_ids(user) do
    get_all_confirmed_user_connections(user.id)
    |> Enum.filter(fn conn -> conn.zen? == true end)
    |> Enum.map(fn conn -> conn.reverse_user_id end)
  end

  def get_user_connection_from_shared_item(item, current_user) do
    adapter().get_user_connection_from_shared_item(item, current_user)
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
    adapter().get_post_author_permissions_for_viewer(item, current_user)
  end

  def get_all_user_connections_from_shared_item(item, current_user) do
    adapter().get_all_user_connections_from_shared_item(item, current_user)
  end

  def get_user_from_post(post) do
    adapter().get_user_from_post(post)
  end

  def get_user_from_item(item) do
    adapter().get_user_from_item(item)
  end

  def get_user_from_item!(item) do
    adapter().get_user_from_item!(item)
  end

  def get_connection_from_item(item, current_user) do
    adapter().get_connection_from_item(item, current_user)
  end

  @doc """
  Lists all users.
  """
  def list_all_users() do
    adapter().list_all_users()
  end

  @doc """
  Counts all users.
  """
  def count_all_users() do
    adapter().count_all_users()
  end

  @doc """
  Lists all confirmed users.
  """
  def list_all_confirmed_users() do
    adapter().list_all_confirmed_users()
  end

  @doc """
  Counts all confirmed users.
  """
  def count_all_confirmed_users() do
    adapter().count_all_confirmed_users()
  end

  @doc """
  Returns the list of UserConnections based
  on the selected filters. TODO: complete
  additional filter options.
  """
  def filter_user_connections(filter, user) do
    adapter().filter_user_connections(filter, user)
  end

  @doc """
  Returns the list of UserConnections based
  on the selected filters. TODO: complete
  additional filter options.
  """
  def filter_user_arrivals(filter, user) do
    adapter().filter_user_arrivals(filter, user)
  end

  @doc """
  Searches for UserConnections by label hash.
  This function searches for connections where the label matches
  the search query (case-insensitive exact match).
  """
  def search_user_connections(user, search_query) when is_binary(search_query) do
    adapter().search_user_connections(user, search_query)
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
  @doc """
  Starting query for listing user_connections arrivals for
  a current_user.
  """
  def list_user_arrivals_connections(user, options) do
    adapter().list_user_arrivals_connections(user, options)
  end

  @doc """
  Gets the total count of a user's user_connection arrivals.
  """
  def arrivals_count(user) do
    adapter().arrivals_count(user)
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
    case adapter().register_user(user, c_attrs) do
      {:ok, user} ->
        broadcast_admin({:ok, user}, :account_registered)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_user_connection(attrs, opts) do
    case adapter().create_user_connection(attrs, opts) do
      {:ok, uconn} ->
        {:ok, uconn}
        |> broadcast(:uconn_created)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user_connection(uconn, attrs, opts) do
    case adapter().update_user_connection(uconn, attrs, opts) do
      {:ok, uconn} ->
        {:ok, uconn}
        |> broadcast(:uconn_updated)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user_connection_label(uconn, attrs, opts) do
    case adapter().update_user_connection_label(uconn, attrs, opts) do
      {:ok, uconn} ->
        {:ok, uconn}
        |> broadcast(:uconn_updated)

      {:error, error} ->
        {:error, error}
    end
  end

  def update_user_connection_zen(uconn, attrs, opts) do
    case adapter().update_user_connection_zen(uconn, attrs, opts) do
      {:ok, uconn} ->
        {:ok, uconn}
        |> broadcast(:uconn_updated)

      {:error, error} ->
        {:error, error}
    end
  end

  def update_user_connection_photos(uconn, attrs, opts) do
    case adapter().update_user_connection_photos(uconn, attrs, opts) do
      {:ok, updated_uconn} ->
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

      {:error, error} ->
        {:error, error}
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
    adapter().update_user_onboarding(user, attrs, opts)
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
    adapter().update_user_forgot_password(user, attrs, opts)
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
    adapter().update_user_notifications(user, attrs, opts)
  end

  @doc """
  Updates when a user last received an email notification.
  Used for daily email rate limiting.
  """
  def update_user_email_notification_received_at(user, timestamp \\ DateTime.utc_now()) do
    adapter().update_user_email_notification_received_at(user, timestamp)
  end

  def update_user_reply_notification_received_at(user, timestamp \\ DateTime.utc_now()) do
    adapter().update_user_reply_notification_received_at(user, timestamp)
  end

  def update_user_replies_seen_at(user, timestamp \\ DateTime.utc_now()) do
    adapter().update_user_replies_seen_at(user, timestamp)
  end

  def update_user_profile(user, attrs \\ %{}, opts \\ []) do
    conn = get_connection!(user.connection.id)
    uconns = get_all_user_connections(user.id)
    changeset = Connection.profile_changeset(conn, attrs, opts)

    old_website_url =
      if conn.profile, do: conn.profile.website_url, else: nil

    case adapter().update_user_profile(user, conn, changeset) do
      {:ok, updated_conn} ->
        new_website_url =
          if updated_conn.profile, do: updated_conn.profile.website_url, else: nil

        unless opts[:visibility_changed] do
          if old_website_url != new_website_url do
            if old_website_url != nil do
              clear_profile_preview_cache(conn, opts[:key])
              Mosslet.Accounts.Jobs.ProfilePreviewCleanupJob.schedule_cleanup(conn.id)
            end

            if new_website_url != nil && new_website_url != "" do
              Mosslet.Accounts.Jobs.ProfilePreviewFetchJob.schedule_fetch(conn.id)
            end
          end
        end

        cond do
          updated_conn.profile.visibility == :public ->
            broadcast_public_connection(updated_conn, :conn_updated)
            broadcast_connection(updated_conn, :uconn_updated)
            broadcast_public_user_connections(uconns, :uconn_updated)
            {:ok, updated_conn}

          true ->
            broadcast_connection(updated_conn, :uconn_updated)
            broadcast_public_user_connections(uconns, :uconn_updated)
            {:ok, updated_conn}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_user_profile(user, attrs \\ %{}, opts \\ []) do
    case adapter().create_user_profile(user, attrs, opts) do
      {:ok, conn} ->
        if conn.profile && conn.profile.website_url != nil && conn.profile.website_url != "" do
          Mosslet.Accounts.Jobs.ProfilePreviewFetchJob.schedule_fetch(conn.id)
        end

        broadcast_connection(conn, :uconn_updated)

        {:ok, conn}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user_name(user, attrs \\ %{}, opts \\ []) do
    changeset = User.name_changeset(user, attrs, opts)
    conn = adapter().get_connection!(user.connection.id)
    c_attrs = Map.get(changeset.changes, :connection_map, %{c_name: nil, c_name_hash: nil})

    case adapter().update_user_name(user, conn, changeset, c_attrs) do
      {:ok, updated_user, updated_conn} ->
        Groups.maybe_update_name_for_user_groups(updated_user, %{encrypted_name: c_attrs.c_name},
          key: opts[:key]
        )

        if updated_user.connection.profile do
          profile_attrs = Map.put(attrs, "id", updated_user.connection.id)

          profile_attrs =
            profile_attrs
            |> Map.put("profile", %{
              "username" =>
                MossletWeb.Helpers.decr(updated_user.username, updated_user, opts[:key]),
              "temp_username" =>
                MossletWeb.Helpers.decr(updated_user.username, updated_user, opts[:key]),
              "name" => attrs["name"],
              "email" => MossletWeb.Helpers.decr(updated_user.email, updated_user, opts[:key]),
              "visibility" => updated_user.visibility,
              "about" => decrypt_profile_about(updated_user, opts[:key]),
              "alternate_email" =>
                decrypt_profile_field(updated_user, opts[:key], :alternate_email),
              "website_url" => decrypt_profile_field(updated_user, opts[:key], :website_url),
              "website_label" => decrypt_profile_field(updated_user, opts[:key], :website_label)
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

          with {:ok, profile_conn} <-
                 update_user_profile(updated_user, profile_attrs,
                   key: opts[:key],
                   user: opts[:user],
                   update_profile: true,
                   encrypt: true
                 ) do
            broadcast_connection(profile_conn, :uconn_name_updated)

            {:ok, updated_user}
          end
        else
          broadcast_connection(updated_conn, :uconn_name_updated)

          {:ok, updated_user}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # includes name updates and marketing notification changes
  # for onboarding
  def update_user_onboarding_profile(user, attrs \\ %{}, opts \\ []) do
    changeset = User.profile_changeset(user, attrs, opts)
    conn = adapter().get_connection!(user.connection.id)
    c_attrs = Map.get(changeset.changes, :connection_map, %{c_name: nil, c_name_hash: nil})

    case adapter().update_user_onboarding_profile(user, conn, changeset, c_attrs) do
      {:ok, updated_user, updated_conn} ->
        broadcast_connection(updated_conn, :uconn_name_updated)

        Groups.maybe_update_name_for_user_groups(updated_user, %{encrypted_name: c_attrs.c_name},
          key: opts[:key]
        )

        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user_username(user, attrs \\ %{}, opts \\ []) do
    changeset = User.username_changeset(user, attrs, opts)
    conn = adapter().get_connection!(user.connection.id)
    c_attrs = changeset.changes.connection_map

    case adapter().update_user_username(user, conn, changeset, c_attrs) do
      {:ok, updated_user, updated_conn} ->
        if updated_user.connection.profile do
          profile_attrs = Map.put(attrs, "id", updated_user.connection.id)

          profile_attrs =
            profile_attrs
            |> Map.put("profile", %{
              "username" => attrs["username"],
              "temp_username" => attrs["username"],
              "name" => MossletWeb.Helpers.decr(updated_user.name, updated_user, opts[:key]),
              "email" => MossletWeb.Helpers.decr(updated_user.email, updated_user, opts[:key]),
              "visibility" => updated_user.visibility,
              "about" => decrypt_profile_about(updated_user, opts[:key]),
              "alternate_email" =>
                decrypt_profile_field(updated_user, opts[:key], :alternate_email),
              "website_url" => decrypt_profile_field(updated_user, opts[:key], :website_url),
              "website_label" => decrypt_profile_field(updated_user, opts[:key], :website_label)
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

          with {:ok, profile_conn} <-
                 update_user_profile(updated_user, profile_attrs,
                   key: opts[:key],
                   user: opts[:user],
                   update_profile: true,
                   encrypt: true
                 ) do
            broadcast_connection(profile_conn, :uconn_username_updated)

            {:ok, updated_user}
          end
        else
          broadcast_connection(updated_conn, :uconn_username_updated)

          {:ok, updated_user}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user_oban_reset_token_id(user, attrs \\ %{}, opts \\ []) do
    adapter().update_user_oban_reset_token_id(user, attrs, opts)
  end

  def update_user_visibility(user, attrs \\ %{}, opts \\ []) do
    case adapter().update_user_visibility(user, attrs, opts) do
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
              "about" => decrypt_profile_about(user, opts[:key]),
              "alternate_email" => decrypt_profile_field(user, opts[:key], :alternate_email),
              "website_url" => decrypt_profile_field(user, opts[:key], :website_url),
              "website_label" => decrypt_profile_field(user, opts[:key], :website_label)
            })

          profile_attrs =
            Map.put(
              profile_attrs,
              "profile",
              Map.put(profile_attrs["profile"], "opts_map", %{
                user: user,
                key: opts[:key],
                update_profile: true,
                encrypt: true,
                visibility_changed: true
              })
            )

          with {:ok, conn} <-
                 update_user_profile(user, profile_attrs,
                   key: opts[:key],
                   user: user,
                   update_profile: true,
                   encrypt: true,
                   visibility_changed: true
                 ) do
            if user.visibility == :public do
              broadcast_connection(conn, :uconn_visibility_updated)
              broadcast_public_connection(conn, :conn_visibility_updated)

              {:ok, user}
            else
              broadcast_connection(conn, :uconn_visibility_updated)
              {:ok, user}
            end
          end
        else
          if user.visibility == :public do
            broadcast_connection(user.connection, :uconn_visibility_updated)
            broadcast_public_connection(user.connection, :conn_visibility_updated)

            {:ok, user}
          else
            broadcast_connection(user.connection, :uconn_visibility_updated)
            {:ok, user}
          end
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_user_admin(user, attrs \\ %{}, opts \\ []) do
    admin_email = Encrypted.Session.admin_email()
    admin = get_user_by_email(admin_email)

    if admin && user.id == admin.id do
      adapter().update_user_admin(user, attrs, opts)
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
    conn = user.connection

    has_profile_website_url =
      conn && conn.profile && conn.profile.website_url != nil

    case adapter().delete_user_account(user, password, changeset) do
      {:ok, user} ->
        if has_profile_website_url do
          Mosslet.Extensions.URLPreviewServer.delete_cached_previews_for_connection(conn.id)
          Mosslet.Accounts.Jobs.ProfilePreviewCleanupJob.schedule_cleanup(conn.id)
        end

        {:ok, user}
        |> broadcast_admin(:account_deleted)

        uconns
        |> broadcast_user_connections(:uconn_deleted)

        uconns
        |> broadcast_public_user_connections(:public_uconn_deleted)

        {:ok, user}
        |> broadcast_account_deleted(:account_deleted)

      {:error, changeset} ->
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
      data
      |> Enum.filter(fn {_key, value} -> value == "true" end)
      |> Enum.each(fn {data_type, _value} ->
        delete_data_filter(user, attrs, key, data_type)
      end)
    end
  end

  defp delete_data_filter(user, attrs, key, "user_connections") do
    uconns = get_all_user_connections(user.id)

    Enum.each(uconns, fn uconn ->
      delete_data_filter(uconn, attrs, key, "user_memories")
      delete_data_filter(uconn, attrs, key, "user_posts")
    end)

    case adapter().delete_all_user_connections(user.id) do
      {:ok, _count} ->
        broadcast_user_connections(uconns, :uconn_deleted)
        broadcast_public_user_connections(uconns, :public_uconn_deleted)

      {:error, error} ->
        {:error, error}
    end
  end

  defp delete_data_filter(user, _attrs, _key, "groups") do
    case adapter().delete_all_groups(user.id) do
      {:ok, _count} ->
        Phoenix.PubSub.broadcast(Mosslet.PubSub, "groups", {:groups_deleted, nil})

      {:error, _reason} ->
        {:error, "There was an error deleting all groups."}
    end
  end

  defp delete_data_filter(user, _attrs, key, "memories") do
    memories = adapter().get_all_memories_for_user(user.id)
    urls = get_urls_from_deleted_memories(user, key, memories)
    Mosslet.Memories.make_async_aws_requests(urls)
    uconns = get_all_user_connections(user.id)

    case adapter().delete_all_memories(user.id) do
      {:ok, _count} ->
        broadcast_user_connections(uconns, :memories_deleted)

      {:error, _reason} ->
        {:error, "There was an error deleting all memories."}
    end
  end

  defp delete_data_filter(user, _attrs, key, "posts") do
    posts = adapter().get_all_posts_for_user(user.id)
    uconns = get_all_user_connections(user.id)
    replies = get_all_replies_from_posts(posts)
    reply_urls = get_urls_from_deleted_replies(user, key, replies)
    urls = get_urls_from_deleted_posts(user, key, posts)

    case delete_object_storage_post_worker(%{"urls" => urls}) do
      {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
        delete_object_storage_reply_worker(%{"urls" => reply_urls})

        case adapter().delete_all_posts(user.id) do
          {:ok, _count} ->
            broadcast_user_connections(uconns, :posts_deleted)

          {:error, reason} ->
            Logger.info("Error deleting all Posts in Accounts context.")
            Logger.info(inspect(reason))
            {:error, "There was an error deleting all posts."}
        end

      rest ->
        Logger.info("Error deleting all Post data from the cloud in Accounts context.")
        Logger.info(inspect(rest))
        {:error, "There was an error deleting post data from the cloud."}
    end
  end

  defp delete_data_filter(uconn, _attrs, _key, "user_memories") do
    case adapter().delete_all_user_memories(uconn) do
      {:ok, _} -> :ok
      {:error, _reason} -> {:error, "There was an error deleting all user memories."}
    end
  end

  defp delete_data_filter(uconn, _attrs, _key, "user_posts") do
    case adapter().delete_all_user_posts(uconn) do
      {:ok, _} -> :ok
      {:error, _reason} -> {:error, "There was an error deleting all user posts."}
    end
  end

  defp delete_data_filter(user, _attrs, _key, "remarks") do
    uconns = get_all_user_connections(user.id)

    case adapter().delete_all_remarks(user.id) do
      {:ok, _count} ->
        broadcast_user_connections(uconns, :remarks_deleted)

      {:error, _reason} ->
        {:error, "There was an error deleting all remarks."}
    end
  end

  defp delete_data_filter(user, _attrs, key, "replies") do
    replies = adapter().get_all_replies_for_user(user.id)
    uconns = get_all_user_connections(user.id)
    urls = get_urls_from_deleted_replies(user, key, replies)

    case delete_object_storage_reply_worker(%{"urls" => urls}) do
      {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
        case adapter().delete_all_replies(user.id) do
          {:ok, _count} ->
            broadcast_user_connections(uconns, :replies_deleted)

          {:error, reason} ->
            Logger.info("Error deleting all Replies in Accounts context.")
            Logger.info(inspect(reason))
            {:error, "There was an error deleting all Replies."}
        end

      rest ->
        Logger.info("Error deleting all Reply data from the cloud in Accounts context.")
        Logger.info(inspect(rest))
        {:error, "There was an error deleting reply data from the cloud."}
    end
  end

  defp delete_data_filter(user, _attrs, _key, "bookmarks") do
    case adapter().delete_all_bookmarks(user.id) do
      {:ok, _count} ->
        :ok

      {:error, _reason} ->
        {:error, "There was an error deleting all bookmarks."}
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
        Mosslet.Memories.get_user_memory(memory, user).key,
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
    has_website_url = conn.profile && conn.profile.website_url != nil
    uconns = get_all_user_connections(user.id)
    changeset = Connection.profile_changeset(conn, %{profile: nil})

    case adapter().delete_user_profile(changeset) do
      {:ok, updated_conn} ->
        if has_website_url do
          Mosslet.Extensions.URLPreviewServer.delete_cached_previews_for_connection(conn.id)
          Mosslet.Accounts.Jobs.ProfilePreviewCleanupJob.schedule_cleanup(conn.id)
        end

        updated_conn
        |> broadcast_public_connection(:user_profile_deleted)

        uconns
        |> broadcast_user_connections(:uconn_updated)

        uconns
        |> broadcast_public_user_connections(:public_uconn_updated)

        {:ok, updated_conn}

      {:error, changeset} ->
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
    case adapter().update_user_email(user, d_email, token, key) do
      {:ok, conn} ->
        if user.connection.profile do
          email = MossletWeb.Helpers.decr(conn.email, user, key)

          profile_attrs = Map.put(%{}, "id", user.connection.id)

          profile_attrs =
            profile_attrs
            |> Map.put("profile", %{
              "username" => MossletWeb.Helpers.decr(user.username, user, key),
              "temp_username" => MossletWeb.Helpers.decr(user.username, user, key),
              "name" => MossletWeb.Helpers.decr(user.username, user, key),
              "email" => email,
              "visibility" => user.visibility,
              "about" => decrypt_profile_about(user, key),
              "alternate_email" => decrypt_profile_field(user, key, :alternate_email),
              "website_url" => decrypt_profile_field(user, key, :website_url),
              "website_label" => decrypt_profile_field(user, key, :website_label)
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

      :error ->
        :error

      {:error, _reason} ->
        :error
    end
  end

  @doc """
  Updates the user ai tokens.
  """
  def update_user_tokens(user, attrs) do
    adapter().update_user_tokens(user, attrs)
  end

  @doc """
  Updates the user avatar.
  """
  def update_user_avatar(user, attrs, opts \\ []) do
    conn = adapter().get_connection!(user.connection.id)

    changeset =
      if opts[:delete_avatar] do
        User.delete_avatar_changeset(user, %{avatar_url: attrs[:avatar_url]}, opts)
      else
        User.avatar_changeset(user, %{avatar_url: attrs[:avatar_url]}, opts)
      end

    c_attrs = changeset.changes.connection_map

    case adapter().update_user_avatar(user, conn, changeset, c_attrs, opts) do
      {:ok, user, conn} ->
        broadcast_connection(conn, :uconn_avatar_updated)
        {:ok, user, conn}

      {:error, changeset} ->
        {:error, changeset}
    end
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

    case adapter().insert_user_email_change_token(user_token) do
      {:ok, _user_token} ->
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

      {:error, reason} ->
        {:error, reason}
    end
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

    adapter().update_user_password(user, changeset)
  end

  ## 2FA / TOTP (Time based One Time Password)

  def two_factor_auth_enabled?(user) do
    adapter().two_factor_auth_enabled?(user)
  end

  @doc """
  Gets the %UserTOTP{} entry, if any.
  """
  def get_user_totp(user) do
    adapter().get_user_totp(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing user TOTP.

  ## Examples

      iex> change_user_totp(%UserTOTP{})
      %Ecto.Changeset{data: %UserTOTP{}}

  """
  def change_user_totp(totp, attrs \\ %{}) do
    adapter().change_user_totp(totp, attrs)
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
    adapter().upsert_user_totp(totp, attrs)
  end

  @doc """
  Regenerates the user backup codes for totp.

  ## Examples

      iex> regenerate_user_totp_backup_codes(%UserTOTP{})
      %UserTOTP{backup_codes: [...]}

  """
  def regenerate_user_totp_backup_codes(totp) do
    adapter().regenerate_user_totp_backup_codes(totp)
  end

  @doc """
  Disables the TOTP configuration for the given user.
  """
  def delete_user_totp(user_totp) do
    adapter().delete_user_totp(user_totp)
  end

  @doc """
  Validates if the given TOTP code is valid.
  """
  def validate_user_totp(user, code) do
    adapter().validate_user_totp(user, code)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    adapter().generate_user_session_token(user)
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    adapter().get_user_by_session_token(token)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    adapter().delete_user_session_token(token)
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

      case adapter().insert_user_confirmation_token(user_token) do
        {:ok, _user_token} ->
          UserNotifier.deliver_confirmation_instructions(
            user,
            email,
            confirmation_url_fun.(encoded_token)
          )

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Confirms a user without checking any tokens. Used
  in tests.
  """
  def confirm_user!(%User{confirmed_at: nil} = user) do
    adapter().confirm_user!(user)
  end

  def confirm_user!(user), do: user

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    case adapter().confirm_user(token) do
      {:ok, user} ->
        broadcast_admin({:ok, user}, :account_confirmed)

      :error ->
        :error
    end
  end

  def confirm_user_connection(uconn, attrs, opts \\ []) do
    case adapter().confirm_user_connection(uconn, attrs, opts) do
      {:ok, upd_uconn, ins_uconn} ->
        broadcast_user_connections([upd_uconn, ins_uconn], :uconn_confirmed)
        {:ok, upd_uconn, ins_uconn}

      {:error, error} ->
        {:error, error}
    end
  end

  def delete_user_connection(%UserConnection{} = uconn) do
    case adapter().delete_user_connection(uconn) do
      {:ok, uconn} ->
        {:ok, uconn}
        |> broadcast(:uconn_deleted)

      {:error, error} ->
        {:error, error}
    end
  end

  def delete_both_user_connections(%UserConnection{} = uconn) do
    case adapter().delete_both_user_connections(uconn) do
      {:ok, uconns} ->
        broadcast_user_connections(uconns, :uconn_deleted)
        {:ok, uconns}

      {:error, error} ->
        {:error, error}
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

    case adapter().deliver_user_reset_password_instructions(user_token) do
      {:ok, _user_token} ->
        UserNotifier.deliver_reset_password_instructions(
          user,
          email,
          reset_password_url_fun.(encoded_token)
        )

      {:error, changeset} ->
        {:error, changeset}
    end
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
    adapter().get_user_by_reset_password_token(token)
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
    adapter().reset_user_password(user, attrs, opts)
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
  # we broadcast to the public channel as well to enable realtime changes (like removing status)
  # the UI of specific liveview handles whether to display based on status setting
  defp broadcast_status_to_authorized_users(user, event) do
    case {user.status_visibility, event} do
      {:nobody, _} ->
        # No broadcasting to connections for status updates when visibility is nobody
        # we have to broadcast to everyone as it could be removing the visibility
        broadcast_status_to_specific_users(user, event)
        broadcast_status_to_specific_groups(user, event)
        broadcast_status_to_public(user, event)

      {:connections, _} ->
        # Broadcast to all connections
        broadcast_status_to_all_connections(user, event)
        broadcast_status_to_public(user, event)

      {:specific_groups, _} ->
        # Broadcast only to users in specific groups
        broadcast_status_to_specific_groups(user, event)
        broadcast_status_to_public(user, event)

      {:specific_users, _} ->
        # Broadcast only to specific users
        broadcast_status_to_specific_users(user, event)
        broadcast_status_to_public(user, event)

      {:public, _} ->
        # For public status, broadcast to all connections (could also broadcast to public channel)
        broadcast_status_to_all_connections(user, event)
        broadcast_status_to_public(user, event)

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

  defp broadcast_status_to_public(user, event) do
    broadcast_public({:ok, user}, event)
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
      {:ok, adapter().preload_user_connection(uconn, [:user, :connection])}
      |> broadcast(event)
    end)
  end

  defp broadcast_connection(conn, event) do
    conn = adapter().preload_connection_assocs(conn, [:user_connections])

    filtered_user_connections =
      Enum.filter(conn.user_connections, fn uconn -> uconn.user_id != conn.user_id end)

    broadcast_user_connections(
      filtered_user_connections,
      event
    )
  end

  defp broadcast_public_connection(conn, event) do
    broadcast_public({:ok, conn}, event)
  end

  defp broadcast_public_user_connections(uconns, event) when is_list(uconns) do
    Enum.each(uconns, fn uconn ->
      {:ok, adapter().preload_user_connection(uconn, [:user, :connection])}
      |> broadcast_public(event)
    end)
  end

  def bulk_delete_all_user_connections(user_id) do
    uconns = get_all_user_connections(user_id)

    Enum.each(uconns, fn uconn ->
      adapter().delete_all_user_memories(uconn)
      adapter().delete_all_user_posts(uconn)
    end)

    case adapter().delete_all_user_connections(user_id) do
      {:ok, count} ->
        broadcast_user_connections(uconns, :uconn_deleted)
        broadcast_public_user_connections(uconns, :public_uconn_deleted)
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def bulk_delete_all_groups(user_id) do
    case adapter().delete_all_groups(user_id) do
      {:ok, count} ->
        Phoenix.PubSub.broadcast(Mosslet.PubSub, "groups", {:groups_deleted, nil})
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def bulk_delete_all_memories(user_id) do
    uconns = get_all_user_connections(user_id)

    case adapter().delete_all_memories(user_id) do
      {:ok, count} ->
        broadcast_user_connections(uconns, :memories_deleted)
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def bulk_delete_all_posts(user_id) do
    uconns = get_all_user_connections(user_id)

    case adapter().delete_all_posts(user_id) do
      {:ok, count} ->
        broadcast_user_connections(uconns, :posts_deleted)
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def bulk_delete_all_remarks(user_id) do
    uconns = get_all_user_connections(user_id)

    case adapter().delete_all_remarks(user_id) do
      {:ok, count} ->
        broadcast_user_connections(uconns, :remarks_deleted)
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def bulk_delete_all_replies(user_id) do
    uconns = get_all_user_connections(user_id)

    case adapter().delete_all_replies(user_id) do
      {:ok, count} ->
        broadcast_user_connections(uconns, :replies_deleted)
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def bulk_delete_all_bookmarks(user_id) do
    adapter().delete_all_bookmarks(user_id)
  end

  def bulk_delete_user_connection_memories(uconn) do
    adapter().delete_all_user_memories(uconn)
  end

  def bulk_delete_user_connection_posts(uconn) do
    adapter().delete_all_user_posts(uconn)
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
    adapter().update_last_signed_in_info(user, ip, key)
  end

  def preload_org_data(user, current_org_slug \\ nil) do
    adapter().preload_org_data(user, current_org_slug)
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
    # Removed confirm_email logging - not security essential
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
    # Removed update_profile logging - not security essential
    Mosslet.MailBluster.sync_user_async(user)
  end

  def user_lifecycle_action("after_confirm_new_email", user, _) do
    # Removed confirm_new_email logging - not security essential
    Mosslet.Orgs.sync_user_invitations(user)
  end

  def user_lifecycle_action("request_new_email", user, %{new_email: _new_email}) do
    Logs.log_async("request_new_email", %{user: user})
  end

  def user_lifecycle_action("after_register", user, _key, %{registration_type: _registration_type}) do
    Mosslet.Orgs.sync_user_invitations(user)
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

  defp decrypt_profile_field(user, key, field) do
    profile = Map.get(user.connection, :profile)

    case field do
      :alternate_email ->
        cond do
          profile && not is_nil(profile.alternate_email) ->
            cond do
              profile.visibility == :public ->
                Encrypted.Users.Utils.decrypt_public_item(
                  profile.alternate_email,
                  profile.profile_key
                )

              profile.visibility == :private ->
                MossletWeb.Helpers.decr_item(
                  profile.alternate_email,
                  user,
                  profile.profile_key,
                  key,
                  profile
                )

              profile.visibility == :connections ->
                MossletWeb.Helpers.decr_item(
                  profile.alternate_email,
                  user,
                  profile.profile_key,
                  key,
                  profile
                )

              true ->
                profile.alternate_email
            end

          true ->
            nil
        end

      :website_url ->
        cond do
          profile && not is_nil(profile.website_url) ->
            cond do
              profile.visibility == :public ->
                Encrypted.Users.Utils.decrypt_public_item(
                  profile.website_url,
                  profile.profile_key
                )

              profile.visibility == :private ->
                MossletWeb.Helpers.decr_item(
                  profile.website_url,
                  user,
                  profile.profile_key,
                  key,
                  profile
                )

              profile.visibility == :connections ->
                MossletWeb.Helpers.decr_item(
                  profile.website_url,
                  user,
                  profile.profile_key,
                  key,
                  profile
                )

              true ->
                profile.website_url
            end

          true ->
            nil
        end

      :website_label ->
        cond do
          profile && not is_nil(profile.website_label) ->
            cond do
              profile.visibility == :public ->
                Encrypted.Users.Utils.decrypt_public_item(
                  profile.website_label,
                  profile.profile_key
                )

              profile.visibility == :private ->
                MossletWeb.Helpers.decr_item(
                  profile.website_label,
                  user,
                  profile.profile_key,
                  key,
                  profile
                )

              profile.visibility == :connections ->
                MossletWeb.Helpers.decr_item(
                  profile.website_label,
                  user,
                  profile.profile_key,
                  key,
                  profile
                )

              true ->
                profile.website_label
            end

          true ->
            nil
        end
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

    case adapter().block_user(blocker, blocked_user, attrs, opts) do
      {:ok, block, was_update?} ->
        event = if was_update?, do: :user_block_updated, else: :user_blocked

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

      {:error, changeset} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Unblocks a user.
  """
  def unblock_user(blocker, blocked_user) do
    case adapter().unblock_user(blocker, blocked_user) do
      {:ok, deleted_block} ->
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

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a specific user block if it exists.
  """
  def get_user_block(blocker, blocked_user_id) when is_binary(blocked_user_id) do
    adapter().get_user_block(blocker, blocked_user_id)
  end

  @doc """
  Checks if a user has blocked another user.
  """
  def user_blocked?(blocker, blocked_user) do
    adapter().user_blocked?(blocker, blocked_user)
  end

  @doc """
  Gets all users blocked by a user.
  """
  def list_blocked_users(user) do
    adapter().list_blocked_users(user)
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
    case adapter().suspend_user(user, admin_user) do
      {:ok, suspended_user} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{user.id}",
          {:user_suspended, suspended_user}
        )

        {:ok, suspended_user}

      {:error, changeset} ->
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
    group_attrs = %{
      "temp_name" => group_params["name"],
      "temp_description" => group_params["description"] || "",
      "color" => String.to_existing_atom(group_params["color"] || "teal"),
      "temp_connection_ids" => group_params["connection_ids"] || []
    }

    case adapter().create_visibility_group(user, group_attrs, opts) do
      {:ok, updated_user} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{user.id}",
          {:visibility_group_created, updated_user}
        )

        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates an existing visibility group for a user.
  """
  def update_visibility_group(user, group_id, group_params, opts \\ []) do
    group_attrs = %{
      "temp_name" => group_params["name"],
      "temp_description" => group_params["description"] || "",
      "color" => String.to_existing_atom(group_params["color"] || "teal"),
      "temp_connection_ids" => group_params["connection_ids"] || []
    }

    case adapter().update_visibility_group(user, group_id, group_attrs, opts) do
      {:ok, updated_user} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{user.id}",
          {:visibility_group_updated, updated_user}
        )

        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a visibility group from a user.
  """
  def delete_visibility_group(user, group_id) do
    case adapter().delete_visibility_group(user, group_id) do
      {:ok, updated_user} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{user.id}",
          {:visibility_group_deleted, updated_user}
        )

        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets all visibility groups from the user's visibility groups.
  Returns the user's visibility groups with connection details for proper decryption.
  """
  def get_user_visibility_groups_with_connections(user) do
    user_with_groups = adapter().get_user_visibility_groups_with_connections(user)

    Enum.map(user_with_groups.visibility_groups || [], fn group ->
      %{group: group, user: user_with_groups, user_connections: []}
    end)
  end

  defp clear_profile_preview_cache(conn, key) do
    profile = conn.profile

    cond do
      is_nil(profile) || is_nil(profile.website_url) ->
        :ok

      profile.visibility == :public ->
        decrypted_url =
          Encrypted.Users.Utils.decrypt_public_item(profile.website_url, profile.profile_key)

        if decrypted_url do
          url_hash =
            :crypto.hash(:sha3_512, "#{decrypted_url}-#{conn.id}")
            |> Base.encode16(case: :lower)

          Mosslet.Extensions.URLPreviewServer.delete_cached_preview(url_hash)
        end

      true ->
        if key do
          profile_key = Encrypted.Users.Utils.decrypt_public_item_key(profile.profile_key)

          if profile_key do
            case Encrypted.Utils.decrypt(%{key: profile_key, payload: profile.website_url}) do
              {:ok, decrypted_url} ->
                url_hash =
                  :crypto.hash(:sha3_512, "#{decrypted_url}-#{conn.id}")
                  |> Base.encode16(case: :lower)

                Mosslet.Extensions.URLPreviewServer.delete_cached_preview(url_hash)

              _ ->
                :ok
            end
          end
        end
    end
  end

  @doc """
  Returns user connections for sync with desktop/mobile apps.

  Returns UserConnection records with associated connections, including encrypted
  data blobs that native apps decrypt locally.

  ## Options

  - `:since` - Only return connections updated after this timestamp
  """
  def list_user_connections_for_sync(user, opts \\ []) do
    adapter().list_user_connections_for_sync(user, opts)
  end
end
