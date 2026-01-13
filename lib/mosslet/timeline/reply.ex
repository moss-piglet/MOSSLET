defmodule Mosslet.Timeline.Reply do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Groups
  alias Mosslet.Timeline.Post

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "replies" do
    field :body, Encrypted.Binary, redact: true
    field :username, Encrypted.Binary, redact: true
    field :username_hash, Encrypted.HMAC, redact: true

    field :visibility, Ecto.Enum,
      values: [:public, :private, :connections, :specific_groups, :specific_users]

    field :image_urls, Encrypted.StringList,
      default: [],
      skip_default_validation: true,
      redact: true

    field :image_urls_updated_at, :naive_datetime
    field :favs_list, {:array, :binary_id}, default: []
    field :favs_count, :integer, default: 0
    field :thread_depth, :integer, default: 0
    field :read_at, :utc_datetime

    belongs_to :post, Post
    belongs_to :user, User
    belongs_to :parent_reply, __MODULE__, foreign_key: :parent_reply_id
    has_many :child_replies, __MODULE__, foreign_key: :parent_reply_id

    timestamps()
  end

  def changeset(reply, attrs \\ %{}, opts \\ []) do
    reply
    |> cast(attrs, [
      :body,
      :post_id,
      :visibility,
      :user_id,
      :username,
      :username_hash,
      :image_urls,
      :image_urls_updated_at,
      :favs_list,
      :favs_count,
      :parent_reply_id,
      :thread_depth
    ])
    |> cast_assoc(:post)
    |> cast_assoc(:user)
    |> validate_required([:body, :username, :visibility, :post_id, :user_id])
    |> validate_length(:body, max: 10_000)
    |> validate_word_count(:body, max: 500)
    |> add_username_hash()
    |> encrypt_attrs(opts)
  end

  def favs_changeset(reply, attrs, _opts \\ []) do
    reply
    |> cast(attrs, [
      :favs_count,
      :favs_list
    ])
    |> validate_required([:favs_count, :favs_list])
  end

  def read_changeset(reply, attrs \\ %{}) do
    reply
    |> cast(attrs, [:read_at])
  end

  defp add_username_hash(changeset) do
    if Map.has_key?(changeset.changes, :username) do
      changeset
      |> put_change(:username_hash, String.downcase(get_field(changeset, :username)))
    else
      changeset
    end
  end

  defp validate_word_count(changeset, field, opts) do
    max = Keyword.get(opts, :max, 500)

    validate_change(changeset, field, fn _field, value ->
      if is_binary(value) do
        word_count = value |> String.split(~r/\s+/, trim: true) |> length()

        if word_count > max do
          [{field, "cannot exceed #{max} words (currently #{word_count} words)"}]
        else
          []
        end
      else
        []
      end
    end)
  end

  # We take the current decrypted temp_key associated
  # with the Post (eg. from the UserPost) and use it
  # to encrypt the body of the Reply.
  #
  # This ensures that anyone who can read the Post, can
  # also read the replies to that Post.
  #
  # Our opts needs to have the :user, :key, :post_key,
  # and :visibility. It optionally also has the :group_id.
  #
  # Updated to include opts[:trix_key] for images uploaded
  # from Trix.
  defp encrypt_attrs(changeset, opts) do
    if opts[:user] && opts[:key] do
      post_key = decrypt_post_key(opts)
      body = get_change(changeset, :body)
      username = get_change(changeset, :username)
      image_urls = get_field(changeset, :image_urls)

      e_image_urls =
        if image_urls && !Enum.empty?(image_urls) && post_key,
          do: encrypt_image_urls(image_urls, post_key)

      changeset
      |> put_change(:body, Utils.encrypt(%{key: post_key, payload: body}))
      |> put_change(:username, Utils.encrypt(%{key: post_key, payload: username}))
      |> put_change(:image_urls, e_image_urls)
    else
      changeset
    end
  end

  defp encrypt_image_urls(image_urls, post_key) do
    Enum.map(image_urls, fn image_url ->
      Utils.encrypt(%{key: post_key, payload: image_url})
    end)
  end

  defp decrypt_post_key(opts) do
    cond do
      opts[:visibility] === :public ->
        Encrypted.Users.Utils.decrypt_public_item_key(opts[:post_key])

      opts[:visibility] in [:connections, :specific_groups, :specific_users, :private] ->
        if not is_nil(opts[:group_id]) && opts[:group_id] != "" do
          group = Groups.get_group!(opts[:group_id])
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
            opts[:trix_key]
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
    end
  end
end
