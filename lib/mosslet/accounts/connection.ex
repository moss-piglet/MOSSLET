defmodule Mosslet.Accounts.Connection do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.{User, UserConnection}

  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Extensions.AvatarProcessor

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "connections" do
    field :name, Encrypted.Binary
    field :name_hash, Encrypted.HMAC
    field :email, Encrypted.Binary
    field :email_hash, Encrypted.HMAC
    field :username, Encrypted.Binary
    field :username_hash, Encrypted.HMAC
    field :avatar_url, Encrypted.Binary
    field :avatar_url_hash, Encrypted.HMAC

    # Status fields - shared with connections (encrypted with conn_key)
    field :status, Ecto.Enum, values: [:offline, :calm, :active, :busy, :away], default: :offline
    # Status message shared with connections (conn_key)
    field :status_message, Encrypted.Binary
    # Hash for searching connection status messages
    field :status_message_hash, Encrypted.HMAC
    # When status was last updated
    field :status_updated_at, :naive_datetime

    # Status Visibility Controls - shared based on user.visibility
    field :status_visibility, Ecto.Enum,
      values: [:nobody, :connections, :specific_groups, :specific_users],
      default: :nobody

    # Encrypted lists of group/user IDs who can see status (encrypted with conn_key)
    field :status_visible_to_groups, Encrypted.StringList,
      default: [],
      skip_default_validation: true

    field :status_visible_to_users, Encrypted.StringList,
      default: [],
      skip_default_validation: true

    # Online presence controls
    field :show_online_presence, :boolean, default: false

    field :presence_visible_to_groups, Encrypted.StringList,
      default: [],
      skip_default_validation: true

    field :presence_visible_to_users, Encrypted.StringList,
      default: [],
      skip_default_validation: true

    # Expanded user lists from groups (for access control)
    field :status_visible_to_groups_user_ids, Encrypted.StringList,
      default: [],
      skip_default_validation: true

    field :presence_visible_to_groups_user_ids, Encrypted.StringList,
      default: [],
      skip_default_validation: true

    embeds_one :profile, ConnectionProfile, on_replace: :update do
      field :name, Encrypted.Binary
      field :about, Encrypted.Binary
      field :email, Encrypted.Binary
      field :username, Encrypted.Binary
      field :avatar_url, Encrypted.Binary
      field :slug, Encrypted.Binary
      field :profile_key, Encrypted.Binary
      field :show_avatar?, :boolean, default: false
      field :show_email?, :boolean, default: false
      field :show_name?, :boolean, default: false
      field :show_public_memories?, :boolean, default: false
      field :show_public_posts?, :boolean, default: false
      field :user_id, :binary_id
      field :visibility, Ecto.Enum, values: [:public, :private, :connections], default: :private

      field :banner_image, Ecto.Enum,
        values: [
          :beach,
          :clouds,
          :fern,
          :forest,
          :geranium,
          :lupin,
          :mountains,
          :shoreline,
          :succulents,
          :stars,
          :waves
        ],
        default: :waves

      field :opts_map, :map, virtual: true
      field :temp_username, :string, virtual: true
    end

    belongs_to :user, User

    has_many :user_connections, UserConnection

    timestamps()
  end

  def register_changeset(conn, attrs \\ %{}) do
    conn
    |> cast(attrs, [:email, :email_hash, :username, :username_hash])
    |> cast_assoc(:user)
    |> validate_required([:email, :email_hash, :username, :username_hash])
    |> add_name_hash()
    |> add_email_hash()
    |> add_username_hash()
  end

  def profile_changeset(conn, attrs \\ %{}, _opts \\ []) do
    conn
    |> cast(attrs, [:id])
    |> cast_embed(:profile,
      with: &connection_profile_changeset/2
    )
  end

  def connection_profile_changeset(profile, attrs \\ %{}) do
    opts_map = attrs["opts_map"]

    profile
    |> cast(attrs, [
      :user_id,
      :name,
      :about,
      :email,
      :username,
      :avatar_url,
      :show_avatar?,
      :show_email?,
      :show_name?,
      :show_public_memories?,
      :show_public_posts?,
      :slug,
      :visibility,
      :banner_image,
      :profile_key,
      :opts_map,
      :temp_username
    ])
    |> validate_length(:about, max: 500)
    |> build_slug()
    |> maybe_encrypt_attrs(opts_map)
  end

  def update_name_changeset(conn, attrs \\ %{}) do
    conn
    |> cast(attrs, [:name, :name_hash])
    |> add_name_hash()
  end

  def update_status_changeset(conn, attrs \\ %{}) do
    conn
    |> cast(attrs, [:status, :status_message, :status_message_hash, :status_updated_at])
    |> add_status_message_hash()
  end

  def update_status_visibility_changeset(conn, attrs \\ %{}) do
    conn
    |> cast(attrs, [
      :status_visibility,
      :status_visible_to_groups,
      :status_visible_to_users,
      :show_online_presence,
      :presence_visible_to_groups,
      :presence_visible_to_users,
      :status_visible_to_groups_user_ids,
      :presence_visible_to_groups_user_ids
    ])
  end

  def update_username_changeset(conn, attrs \\ %{}) do
    conn
    |> cast(attrs, [:username, :username_hash])
    |> add_username_hash()
  end

  def update_email_changeset(conn, attrs \\ %{}) do
    conn
    |> cast(attrs, [:email, :email_hash])
    |> add_email_hash()
  end

  def update_avatar_changeset(conn, attrs \\ %{}, opts \\ []) do
    conn
    |> cast(attrs, [:avatar_url, :avatar_url_hash])
    |> add_avatar_hash(opts)
  end

  # The name_hash comes through as a temp clear text
  # so we go straight ahead and hash it. The `:name`
  # is coming through already encrypted correctly
  # from the user changeset.

  defp add_name_hash(changeset) do
    if Map.has_key?(changeset.changes, :name) do
      changeset
      |> put_change(:name_hash, String.downcase(get_field(changeset, :name_hash)))
    else
      changeset
    end
  end

  # The email_hash comes through as a temp clear text
  # so we go straight ahead and hash it. The `:email`
  # is coming through already encrypted correctly
  # from the user changeset.
  defp add_email_hash(changeset) do
    if Map.has_key?(changeset.changes, :email_hash) do
      changeset
      |> put_change(:email_hash, String.downcase(get_field(changeset, :email_hash)))
    else
      changeset
    end
  end

  # The avatar_url_hash comes through as a temp clear text
  # so we go straight ahead and hash it. The `:avatar_url`
  # is coming through already encrypted correctly
  # from the user changeset.
  defp add_avatar_hash(changeset, opts) do
    if Map.has_key?(changeset.changes, :avatar_url_hash) do
      if opts[:delete_avatar] do
        changeset
        |> put_change(:avatar_url_hash, nil)
      else
        changeset
        |> put_change(:avatar_url_hash, String.downcase(get_field(changeset, :avatar_url_hash)))
      end
    else
      changeset
    end
  end

  # The username_hash comes through as a temp clear text
  # so we go straight ahead and hash it. The `:username`
  # is coming through already encrypted correctly
  # from the user changeset.
  defp add_username_hash(changeset) do
    if Map.has_key?(changeset.changes, :username_hash) do
      slug = Slug.slugify(get_field(changeset, :username_hash), ignore: ["_"])

      changeset
      |> put_change(:username_hash, String.downcase(slug))
    else
      changeset
    end
  end

  # The status_message_hash comes through as a temp clear text
  # so we go straight ahead and hash it. The `:status_message`
  # is coming through already encrypted correctly from the user changeset.
  defp add_status_message_hash(changeset) do
    if Map.has_key?(changeset.changes, :status_message_hash) do
      case get_field(changeset, :status_message_hash) do
        nil ->
          changeset

        "" ->
          changeset

        hash_value when is_binary(hash_value) ->
          changeset
          |> put_change(:status_message_hash, String.downcase(hash_value))

        _ ->
          changeset
      end
    else
      changeset
    end
  end

  defp build_slug(changeset) do
    if temp_username = get_field(changeset, :temp_username) do
      slug = Slug.slugify(temp_username, ignore: ["_"])
      put_change(changeset, :slug, slug)
    else
      changeset
    end
  end

  defp maybe_encrypt_attrs(changeset, opts_map) do
    if changeset.valid? && opts_map && Map.get(opts_map, :encrypt) do
      username = get_field(changeset, :username)
      visibility = opts_map.user.visibility
      profile_key = maybe_generate_key(opts_map)

      case visibility do
        :public ->
          changeset
          |> put_change(:avatar_url, maybe_encrypt_avatar_url(changeset, profile_key, opts_map))
          |> put_change(:name, maybe_encrypt_name(changeset, profile_key))
          |> put_change(:email, maybe_encrypt_email(changeset, profile_key))
          |> put_change(:about, maybe_encrypt_about(changeset, profile_key))
          |> put_change(:username, Utils.encrypt(%{key: profile_key, payload: username}))
          |> put_change(
            :profile_key,
            Encrypted.Utils.encrypt_message_for_user_with_pk(profile_key, %{
              public: Encrypted.Session.server_public_key()
            })
          )

        :private ->
          changeset
          |> put_change(:avatar_url, maybe_encrypt_avatar_url(changeset, profile_key, opts_map))
          |> put_change(:name, maybe_encrypt_name(changeset, profile_key))
          |> put_change(:email, maybe_encrypt_email(changeset, profile_key))
          |> put_change(:about, maybe_encrypt_about(changeset, profile_key))
          |> put_change(:username, Utils.encrypt(%{key: profile_key, payload: username}))
          |> put_change(
            :profile_key,
            Encrypted.Utils.encrypt_message_for_user_with_pk(profile_key, %{
              public: opts_map.user.key_pair["public"]
            })
          )

        :connections ->
          changeset
          |> put_change(:avatar_url, maybe_encrypt_avatar_url(changeset, profile_key, opts_map))
          |> put_change(:name, maybe_encrypt_name(changeset, profile_key))
          |> put_change(:email, maybe_encrypt_email(changeset, profile_key))
          |> put_change(:about, maybe_encrypt_about(changeset, profile_key))
          |> put_change(:username, Utils.encrypt(%{key: profile_key, payload: username}))
          |> put_change(
            :profile_key,
            Encrypted.Utils.encrypt_message_for_user_with_pk(profile_key, %{
              public: opts_map.user.key_pair["public"]
            })
          )

        _rest ->
          changeset |> add_error(:about, "There was an error determining the visibility.")
      end
    else
      changeset
    end
  end

  defp maybe_encrypt_about(changeset, profile_key) do
    cond do
      about = get_field(changeset, :about) ->
        Utils.encrypt(%{key: profile_key, payload: about})

      true ->
        nil
    end
  end

  defp maybe_encrypt_avatar_url(changeset, profile_key, opts_map) do
    cond do
      Map.get(opts_map.user.connection, :avatar_url) && get_field(changeset, :show_avatar?) ->
        e_avatar_blob = AvatarProcessor.get_ets_avatar("profile-#{opts_map.user.connection.id}")

        # We don't have to Base.encode64() because
        # it is coming from the current user's ets
        # which was previously pulled down from Storj
        # and encoded.
        d_avatar_blob =
          Encrypted.Users.Utils.decrypt_user_item(
            e_avatar_blob,
            opts_map.user,
            opts_map.user.conn_key,
            opts_map.key
          )

        ets_profile_id = "profile-#{opts_map.user.connection.id}"
        avatar_url = get_field(changeset, :avatar_url)
        e_avatar_url = prepare_encrypted_file_path(avatar_url, profile_key)
        e_avatar_blob = prepare_encrypted_avatar_blob(d_avatar_blob, profile_key)
        avatars_bucket = Encrypted.Session.avatars_bucket()

        # ex_aws_put_request(avatars_bucket, avatar_url, e_avatar_blob)
        # not currently async
        make_async_aws_and_ets_requests(
          avatars_bucket,
          avatar_url,
          e_avatar_blob,
          ets_profile_id,
          opts_map
        )

        e_avatar_url

      true ->
        nil
    end
  end

  defp prepare_encrypted_file_path(avatar_url, profile_key) do
    Utils.encrypt(%{key: profile_key, payload: avatar_url})
  end

  defp prepare_encrypted_avatar_blob(d_avatar_blob, profile_key) do
    Utils.encrypt(%{key: profile_key, payload: d_avatar_blob})
  end

  defp make_async_aws_and_ets_requests(
         avatars_bucket,
         avatar_url,
         e_avatar_blob,
         ets_profile_id,
         opts_map
       ) do
    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      if Map.get(opts_map, :update_profile) do
        with {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, avatar_url),
             {:ok, _resp} <- ex_aws_put_request(avatars_bucket, avatar_url, e_avatar_blob),
             true <- AvatarProcessor.put_ets_avatar(ets_profile_id, e_avatar_blob) do
          {:ok, :profile_avatar_uploaded_to_storj,
           "Profile avatar uploaded to the private cloud successfully."}
        else
          _rest ->
            ex_aws_delete_request(avatars_bucket, avatar_url)
            ex_aws_put_request(avatars_bucket, avatar_url, e_avatar_blob)
            {:error, :make_async_aws_and_ets_requests}
        end
      else
        with {:ok, _resp} <- ex_aws_put_request(avatars_bucket, avatar_url, e_avatar_blob),
             true <- AvatarProcessor.put_ets_avatar(ets_profile_id, e_avatar_blob) do
          {:ok, :profile_avatar_uploaded_to_storj,
           "Profile avatar uploaded to the private cloud successfully."}
        else
          _rest ->
            ex_aws_put_request(avatars_bucket, avatar_url, e_avatar_blob)
            {:error, :make_async_aws_and_ets_requests}
        end
      end
    end)
  end

  defp ex_aws_delete_request(avatars_bucket, avatar_url) do
    ExAws.S3.delete_object(avatars_bucket, avatar_url)
    |> ExAws.request()
  end

  defp ex_aws_put_request(avatars_bucket, avatar_url, e_avatar_blob) do
    ExAws.S3.put_object(avatars_bucket, avatar_url, e_avatar_blob)
    |> ExAws.request()
  end

  defp maybe_encrypt_name(changeset, profile_key) do
    cond do
      get_field(changeset, :show_name?) ->
        Utils.encrypt(%{key: profile_key, payload: get_field(changeset, :name)})

      true ->
        nil
    end
  end

  defp maybe_encrypt_email(changeset, profile_key) do
    cond do
      get_field(changeset, :show_email?) ->
        Utils.encrypt(%{key: profile_key, payload: get_field(changeset, :email)})

      true ->
        nil
    end
  end

  defp maybe_generate_key(opts_map) do
    if Map.get(opts_map, :update_profile) do
      profile_viz = Map.get(opts_map.user.connection.profile, :visibility)

      case profile_viz do
        :public ->
          Encrypted.Users.Utils.decrypt_public_item_key(
            opts_map.user.connection.profile.profile_key
          )

        _rest ->
          {:ok, d_profile_key} =
            Encrypted.Users.Utils.decrypt_user_attrs_key(
              opts_map.user.connection.profile.profile_key,
              opts_map.user,
              opts_map.key
            )

          d_profile_key
      end
    else
      {:ok, d_profile_key} =
        Encrypted.Users.Utils.decrypt_user_attrs_key(
          opts_map.user.conn_key,
          opts_map.user,
          opts_map.key
        )

      d_profile_key
    end
  end
end
