defmodule Mosslet.Accounts.UserBlock do
  @moduledoc """
  A user block represents one user blocking another user.

  Uses enacl encryption for user-generated sensitive data:
  - Reason encrypted with user's own key (personal preference)
  - Block type for different levels of blocking
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_blocks" do
    # ENCRYPTED FIELDS (user-generated data - use enacl with user keys)
    # Why they blocked (enacl encrypted)
    field :reason, :binary

    # PLAINTEXT FIELDS (system data)
    field :block_type, Ecto.Enum,
      values: [:full, :posts_only, :replies_only],
      default: :full

    # RELATIONSHIPS
    # User doing the blocking
    belongs_to :blocker, User, foreign_key: :blocker_id
    # User being blocked
    belongs_to :blocked, User, foreign_key: :blocked_id

    timestamps()
  end

  @doc """
  Creates changeset for user block with user-key encryption.

  ## Examples

      iex> UserBlock.changeset(%UserBlock{}, %{
      ...>   reason: "Posting inappropriate content",
      ...>   block_type: :full
      ...> }, user: blocker, user_key: user_key)
  """
  def changeset(block, attrs, opts \\ []) do
    block
    |> cast(attrs, [:reason, :block_type, :blocker_id, :blocked_id])
    |> validate_required([:blocker_id, :blocked_id])
    |> validate_not_self_block()
    |> encrypt_user_data(opts)
    |> unique_constraint([:blocker_id, :blocked_id],
      message: "You have already blocked this user"
    )
  end

  # Ensure user cannot block themselves
  defp validate_not_self_block(changeset) do
    blocker_id = get_field(changeset, :blocker_id)
    blocked_id = get_field(changeset, :blocked_id)

    if blocker_id && blocked_id && blocker_id == blocked_id do
      add_error(changeset, :blocked_id, "You cannot block yourself")
    else
      changeset
    end
  end

  # Encrypt reason with user's own encryption key
  defp encrypt_user_data(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:user_key] do
      reason = get_field(changeset, :reason)

      if reason && String.trim(reason) != "" do
        # Generate a unique key for this block
        block_key = Mosslet.Encrypted.Utils.generate_key()

        encrypted_reason =
          Mosslet.Encrypted.Utils.encrypt(%{
            key: block_key,
            payload: String.trim(reason)
          })

        put_change(changeset, :reason, encrypted_reason)
      else
        changeset
      end
    else
      changeset
    end
  end
end
