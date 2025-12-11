defmodule Mosslet.Timeline.UserPost do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Timeline.{Post, UserPostReceipt}

  @share_note_max_length 500

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_posts" do
    field :key, Encrypted.Binary
    field :share_note, Encrypted.Binary

    belongs_to :post, Post
    belongs_to :user, User

    has_one :user_post_receipt, UserPostReceipt

    timestamps()
  end

  def changeset(user_post, attrs \\ %{}, opts \\ []) do
    user_post
    |> cast(attrs, [:key, :post_id, :user_id, :share_note])
    |> cast_assoc(:post)
    |> cast_assoc(:user)
    |> validate_required([:key])
    |> validate_length(:share_note, max: @share_note_max_length)
    |> encrypt_attrs(opts)
  end

  def sharing_changeset(user_post, attrs \\ %{}, opts \\ []) do
    user_post
    |> cast(attrs, [:key, :post_id, :user_id, :share_note])
    |> cast_assoc(:post)
    |> cast_assoc(:user)
    |> validate_required([:key])
    |> validate_length(:share_note, max: @share_note_max_length)
    |> encrypt_attrs(opts)
  end

  def share_note_changeset(user_post \\ %__MODULE__{}, attrs) do
    user_post
    |> cast(attrs, [:share_note])
    |> validate_length(:share_note, max: @share_note_max_length)
  end

  def share_note_max_length, do: @share_note_max_length

  # When we create a UserPost when sharing a
  # Post with another use, we need to encrypt
  # the key to each specific user's public key
  # that is being shared with.
  #
  # The user will be the same as the `user_id`
  # associated with the UserPost.
  defp encrypt_attrs(changeset, opts) do
    if opts[:user] do
      temp_key = get_field(changeset, :key)

      public_key =
        if opts[:visibility] == "public" || opts[:visibility] == :public do
          Encrypted.Session.server_public_key()
        else
          opts[:user].key_pair["public"]
        end

      changeset =
        changeset
        |> put_change(
          :key,
          Encrypted.Utils.encrypt_message_for_user_with_pk(temp_key, %{
            public: public_key
          })
        )

      share_note = get_field(changeset, :share_note)

      if share_note && String.trim(share_note) != "" && opts[:post_key] do
        put_change(
          changeset,
          :share_note,
          Encrypted.Utils.encrypt(%{key: opts[:post_key], payload: share_note})
        )
      else
        changeset
      end
    else
      changeset
      |> add_error(:key, "invalid user to share with")
    end
  end
end
