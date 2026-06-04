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

    field :favs_list, Encrypted.StringList,
      default: [],
      skip_default_validation: true,
      redact: true

    field :favs_list_hash, Encrypted.HMAC, redact: true
    field :favs_count, :integer, default: 0
    field :thread_depth, :integer, default: 0
    field :read_at, :utc_datetime

    belongs_to :post, Post
    belongs_to :user, User
    belongs_to :parent_reply, __MODULE__, foreign_key: :parent_reply_id
    has_many :child_replies, __MODULE__, foreign_key: :parent_reply_id

    belongs_to :bluesky_account, Mosslet.Bluesky.Account

    field :source, Ecto.Enum, values: [:mosslet, :bluesky], default: :mosslet
    field :external_uri, Encrypted.Binary, redact: true
    field :external_cid, Encrypted.Binary, redact: true
    field :external_reply_root_uri, Encrypted.Binary, redact: true
    field :external_reply_root_cid, Encrypted.Binary, redact: true
    field :external_reply_parent_uri, Encrypted.Binary, redact: true
    field :external_reply_parent_cid, Encrypted.Binary, redact: true
    field :bluesky_link_verified, :boolean, default: true

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
      :thread_depth,
      :source,
      :external_uri,
      :external_cid,
      :external_reply_root_uri,
      :external_reply_root_cid,
      :external_reply_parent_uri,
      :external_reply_parent_cid,
      :bluesky_account_id
    ])
    |> cast_assoc(:post)
    |> cast_assoc(:user)
    |> validate_required([:body, :username, :visibility, :post_id, :user_id])
    |> validate_length(:body, max: 10_000)
    |> validate_word_count(:body, max: 500)
    |> add_username_hash()
    |> encrypt_attrs(opts)
  end

  @doc """
  Server-side path: encrypts each user_id in favs_list with the parent
  post's post_key. Mirrors `Post.favs_changeset/3`.
  """
  def favs_changeset(reply, attrs, opts \\ []) do
    reply
    |> cast(attrs, [:favs_count, :favs_list])
    |> validate_required([:favs_count, :favs_list])
    |> encrypt_favs_list_with_post_key(opts)
  end

  @doc """
  ZK path: accepts pre-encrypted favs_list directly from the browser.
  The server never decrypts — it stores the ciphertext as-is.
  Mirrors `Post.favs_changeset_zk/2`.
  """
  def favs_changeset_zk(reply, attrs) do
    reply
    |> cast(attrs, [:favs_count, :favs_list])
    |> validate_required([:favs_count, :favs_list])
  end

  # Encrypt each user_id in favs_list with the parent post's post_key,
  # same pattern as Post.encrypt_favs_list/3.
  defp encrypt_favs_list_with_post_key(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      favs_list = get_field(changeset, :favs_list)

      if favs_list && favs_list != [] do
        post_key = decrypt_post_key(opts)

        if is_nil(post_key) do
          add_error(changeset, :favs_list, "unable to decrypt post key for encryption")
        else
          encrypted_favs =
            Enum.map(favs_list, fn user_id ->
              Utils.encrypt(%{key: post_key, payload: user_id})
            end)

          favs_hash = Enum.join(favs_list, ",") |> String.downcase()

          changeset
          |> put_change(:favs_list, encrypted_favs)
          |> put_change(:favs_list_hash, favs_hash)
        end
      else
        changeset
      end
    else
      changeset
    end
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
    if changeset.valid? && opts[:user] && opts[:key] do
      toggle_zk = opts[:zk_reply]

      if toggle_zk do
        encrypt_attrs_zk(changeset, opts)
      else
        encrypt_attrs_server(changeset, opts)
      end
    else
      changeset
    end
  end

  # ZK path: reply body/username are pre-encrypted by the browser with the
  # cached parent post_key and arrive as base64 ciphertext strings. They are
  # already cast onto the changeset via `attrs`, so the server stores them
  # as-is — never decoding or touching the post_key or plaintext content.
  #
  # We keep the base64 string intact (rather than `Base.decode64!`) so the
  # `DecryptReply` hook can read `data-encrypted-body` and decrypt in WASM,
  # mirroring the post ZK write path (`update_reply_body_zk/2`).
  defp encrypt_attrs_zk(changeset, _opts) do
    changeset
  end

  # Legacy path: server decrypts post_key and encrypts reply fields.
  defp encrypt_attrs_server(changeset, opts) do
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
