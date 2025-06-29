defmodule Mosslet.Memories.Remark do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Memories.Memory

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "remarks" do
    field :body, Encrypted.Binary
    field :mood, Ecto.Enum, values: [:excited, :loved, :happy, :sad, :thumbsy, :nothing]
    field :visibility, Ecto.Enum, values: [:public, :private, :connections]

    belongs_to :memory, Memory
    belongs_to :user, User

    timestamps()
  end

  def changeset(remark, attrs \\ %{}, opts \\ []) do
    remark
    |> cast(attrs, [:body, :mood, :visibility, :user_id, :memory_id])
    |> cast_assoc(:memory)
    |> cast_assoc(:user)
    |> maybe_validate_required()
    |> validate_length(:body, max: 500)
    |> encrypt_attrs(opts)
  end

  defp maybe_validate_required(changeset) do
    if get_change(changeset, :mood) do
      changeset
    else
      changeset
      |> validate_required([:body], message: "can't be blank or select a reaction")
    end
  end

  defp encrypt_attrs(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] && opts[:memory_key] do
      body = get_change(changeset, :body)
      visibility = get_field(changeset, :visibility)
      memory_key = get_memory_key(opts, visibility)

      if !is_nil(body) && String.trim(body) != "" do
        changeset
        |> put_change(:body, Utils.encrypt(%{key: memory_key, payload: body}))
      else
        changeset
      end
    else
      changeset
    end
  end

  defp get_memory_key(opts, visibility) do
    case visibility do
      :public ->
        Encrypted.Users.Utils.decrypt_public_item_key(opts[:memory_key])

      :connections ->
        {:ok, d_memory_key} =
          Encrypted.Users.Utils.decrypt_user_attrs_key(
            opts[:memory_key],
            opts[:user],
            opts[:key]
          )

        d_memory_key

      :private ->
        {:ok, d_memory_key} =
          Encrypted.Users.Utils.decrypt_user_attrs_key(
            opts[:memory_key],
            opts[:user],
            opts[:key]
          )

        d_memory_key
    end
  end
end
