defmodule Mosslet.Memories.UserMemory do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Memories.Memory

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_memories" do
    field :key, Encrypted.Binary, redact: true

    belongs_to :memory, Memory
    belongs_to :user, User

    timestamps()
  end

  def changeset(user_memory, attrs \\ %{}, opts \\ []) do
    user_memory
    |> cast(attrs, [:key, :memory_id, :user_id])
    |> cast_assoc(:memory)
    |> cast_assoc(:user)
    |> validate_required([:key])
    |> encrypt_attrs(opts)
  end

  def sharing_changeset(user_memory, attrs \\ %{}, opts \\ []) do
    user_memory
    |> cast(attrs, [:key, :memory_id, :user_id])
    |> cast_assoc(:memory)
    |> cast_assoc(:user)
    |> validate_required([:key])
    |> encrypt_attrs(opts)
  end

  # When we create a UserMemory when sharing a
  # Memory with another use, we need to encrypt
  # the key to each specific user's public key
  # that is being shared with.
  #
  # The user will be the same as the `user_id`
  # associated with the UserMemory.
  defp encrypt_attrs(changeset, opts) do
    if opts[:user] do
      temp_key = get_field(changeset, :key)

      public_key =
        if opts[:visibility] == "public" || opts[:visibility] == :public do
          Encrypted.Session.server_public_key()
        else
          opts[:user].key_pair["public"]
        end

      changeset
      |> put_change(
        :key,
        Encrypted.Utils.encrypt_message_for_user_with_pk(temp_key, %{
          public: public_key
        })
      )
    else
      changeset
      |> add_error(:key, "invalid user to share with")
    end
  end
end
