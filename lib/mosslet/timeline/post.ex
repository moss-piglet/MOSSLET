defmodule Mosslet.Timeline.Post do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Groups
  alias Mosslet.Groups.{Group, UserGroup}
  alias Mosslet.Timeline.{Post, UserPost, Reply}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "posts" do
    field :avatar_url, Encrypted.Binary
    field :body, Encrypted.Binary
    field :username, Encrypted.Binary
    field :username_hash, Encrypted.HMAC
    field :image_urls, Encrypted.StringList, default: [], skip_default_validation: true
    field :image_urls_updated_at, :naive_datetime
    field :favs_list, {:array, :binary_id}, default: []
    field :reposts_list, {:array, :binary_id}, default: []
    field :favs_count, :integer, default: 0
    field :reposts_count, :integer, default: 0
    field :repost, :boolean, default: false
    field :visibility, Ecto.Enum, values: [:public, :private, :connections], default: :private

    field :user_post_map, :map, virtual: true

    embeds_many :shared_users, SharedUser, on_replace: :delete do
      @derive Jason.Encoder
      field :sender_id, :string, virtual: true
      field :username, :string, virtual: true
      field :user_id, :binary_id
      field :color, Ecto.Enum, values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]
    end

    belongs_to :group, Group
    belongs_to :user_group, UserGroup
    belongs_to :original_post, Post
    belongs_to :user, User

    has_many :user_posts, UserPost
    has_many :replies, Reply, preload_order: [desc: :inserted_at]

    timestamps()
  end

  @doc false
  def changeset(post, attrs, opts \\ []) do
    post
    |> cast(attrs, [
      :avatar_url,
      :body,
      :username,
      :username_hash,
      :favs_count,
      :reposts_count,
      :reposts_list,
      :favs_list,
      :user_id,
      :visibility,
      :group_id,
      :user_group_id,
      :image_urls,
      :image_urls_updated_at
    ])
    |> validate_required([:body, :username, :user_id])
    |> validate_length(:body, max: 100_000)
    |> add_username_hash()
    |> validate_visibility(opts)
    |> encrypt_attrs(opts)
    |> cast_embed(:shared_users,
      with: &shared_user_changeset/2,
      sort_param: :shared_users_order,
      drop_param: :shared_users_delete
    )
  end

  @doc false
  def repost_changeset(post, attrs, opts \\ []) do
    post
    |> cast(attrs, [
      :avatar_url,
      :body,
      :username,
      :favs_list,
      :favs_count,
      :reposts_list,
      :reposts_count,
      :repost,
      :user_id,
      :original_post_id,
      :visibility,
      :group_id,
      :user_group_id,
      :image_urls,
      :image_urls_updated_at
    ])
    |> validate_required([:body, :username, :reposts_list, :repost, :user_id, :original_post_id])
    |> add_username_hash()
    |> encrypt_attrs(opts)
    |> cast_embed(:shared_users,
      with: &shared_user_repost_changeset/2,
      sort_param: :shared_users_order,
      drop_param: :shared_users_delete
    )
  end

  def favs_changeset(post, attrs, opts \\ []) do
    post
    |> cast(attrs, [
      :avatar_url,
      :body,
      :username,
      :username_hash,
      :favs_count,
      :reposts_count,
      :reposts_list,
      :favs_list,
      :user_id,
      :visibility,
      :group_id,
      :user_group_id,
      :image_urls,
      :image_urls_updated_at
    ])
    |> validate_required([:body, :username, :user_id])
    |> add_username_hash()
    |> encrypt_attrs(opts)
    |> cast_embed(:shared_users,
      with: &shared_user_changeset/2,
      sort_param: :shared_users_order,
      drop_param: :shared_users_delete
    )
  end

  def shared_user_changeset(shared_user, attrs \\ %{}, _opts \\ []) do
    shared_user
    |> cast(attrs, [:sender_id, :username])
    |> validate_shared_username()
  end

  def shared_user_repost_changeset(shared_user, attrs \\ %{}, _opts \\ []) do
    shared_user
    |> cast(attrs, [:user_id])
  end

  def change_post_to_repost_changeset(post, attrs, _opts \\ []) do
    post
    |> cast(attrs, [:reposts_list])
  end

  def change_post_shared_users_changeset(post, attrs, _opts \\ []) do
    post
    |> cast(attrs, [])
    |> cast_embed(:shared_users,
      with: &shared_user_changeset/2,
      soft_param: :shared_users_order,
      drop_param: :shared_users_delete
    )
  end

  defp validate_shared_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 160)
    |> maybe_add_recipient_id_by_username()
  end

  # The recipient is either the user_id or reverse_user_id
  # of the connection.
  defp maybe_add_recipient_id_by_username(changeset) do
    username = get_change(changeset, :username, "")
    user_id = get_field(changeset, :sender_id)

    if recipient = Accounts.get_shared_user_by_username(user_id, username) do
      changeset
      |> put_change(:user_id, recipient.id)
    else
      changeset
      |> add_error(:username, "invalid or does not exist")
    end
  end

  defp add_username_hash(changeset) do
    if Map.has_key?(changeset.changes, :username) do
      changeset
      |> put_change(:username_hash, String.downcase(get_field(changeset, :username)))
    else
      changeset
    end
  end

  defp validate_visibility(changeset, opts) do
    visibility = get_field(changeset, :visibility)

    case visibility do
      :public ->
        changeset

      :private ->
        changeset

      :connections ->
        if Accounts.has_any_user_connections?(opts[:user]) do
          changeset
        else
          changeset |> add_error(:body, "Woopsy, first we need to make some connections.")
        end
    end
  end

  defp encrypt_attrs(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      body = get_field(changeset, :body)
      username = get_field(changeset, :username)
      visibility = get_field(changeset, :visibility)
      group_id = get_field(changeset, :group_id)
      post_key = maybe_generate_post_key(group_id, opts, visibility)

      e_avatar_url =
        if is_binary(post_key), do: maybe_encrypt_avatar_url(opts[:user], post_key)

      image_urls = get_field(changeset, :image_urls)

      e_image_urls =
        if image_urls && !Enum.empty?(image_urls) && post_key,
          do: encrypt_image_urls(image_urls, post_key)

      case visibility do
        :public ->
          changeset
          |> put_change(:avatar_url, e_avatar_url)
          |> put_change(:image_urls, e_image_urls)
          |> put_change(:body, Utils.encrypt(%{key: post_key, payload: body}))
          |> put_change(:username, Utils.encrypt(%{key: post_key, payload: username}))
          |> put_change(:user_post_map, %{temp_key: post_key})

        :private ->
          changeset
          |> put_change(:avatar_url, e_avatar_url)
          |> put_change(:image_urls, e_image_urls)
          |> put_change(:body, Utils.encrypt(%{key: post_key, payload: body}))
          |> put_change(:username, Utils.encrypt(%{key: post_key, payload: username}))
          |> put_change(:user_post_map, %{temp_key: post_key})

        :connections ->
          changeset
          |> put_change(:avatar_url, e_avatar_url)
          |> put_change(:image_urls, e_image_urls)
          |> put_change(:body, Utils.encrypt(%{key: post_key, payload: body}))
          |> put_change(:username, Utils.encrypt(%{key: post_key, payload: username}))
          |> put_change(:user_post_map, %{temp_key: post_key})

        _rest ->
          changeset |> add_error(:body, "There was an error determining the visibility.")
      end
    else
      changeset
    end
  end

  defp maybe_encrypt_avatar_url(user, post_key) do
    case user.avatar_url do
      nil ->
        nil

      avatar_url ->
        Utils.encrypt(%{key: post_key, payload: avatar_url})
    end
  end

  defp encrypt_image_urls(image_urls, post_key) do
    Enum.map(image_urls, fn image_url ->
      Utils.encrypt(%{key: post_key, payload: image_url})
    end)
  end

  defp maybe_generate_post_key(group_id, opts, visibility) do
    if opts[:update_post] do
      case visibility do
        :public ->
          Encrypted.Users.Utils.decrypt_public_item_key(opts[:post_key])

        _rest ->
          if not is_nil(group_id) do
            group = Groups.get_group!(group_id)
            user_group = Groups.get_user_group_for_group_and_user(group, opts[:user])

            {:ok, d_post_key} =
              Encrypted.Users.Utils.decrypt_user_attrs_key(
                user_group.key,
                opts[:user],
                opts[:key]
              )

            d_post_key
          else
            {:ok, d_post_key} =
              Encrypted.Users.Utils.decrypt_user_attrs_key(
                opts[:post_key],
                opts[:user],
                opts[:key]
              )

            d_post_key
          end
      end
    else
      # creating a new post
      case visibility do
        # use the group_key if associated with a group
        :connections ->
          if not is_nil(group_id) do
            group = Groups.get_group!(group_id)
            user_group = Groups.get_user_group_for_group_and_user(group, opts[:user])

            {:ok, d_post_key} =
              Encrypted.Users.Utils.decrypt_user_attrs_key(
                user_group.key,
                opts[:user],
                opts[:key]
              )

            d_post_key
          else
            if opts[:trix_key] do
              {:ok, d_post_key} =
                Encrypted.Users.Utils.decrypt_user_attrs_key(
                  opts[:trix_key],
                  opts[:user],
                  opts[:key]
                )

              d_post_key
            else
              Encrypted.Utils.generate_key()
            end
          end

        _rest ->
          Encrypted.Utils.generate_key()
      end
    end
  end
end
