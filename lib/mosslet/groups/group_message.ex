defmodule Mosslet.Groups.GroupMessage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Groups.Group
  alias Mosslet.Groups.UserGroup

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "group_messages" do
    field :content, Encrypted.Binary
    belongs_to :group, Group
    belongs_to :sender, UserGroup

    timestamps()
  end

  @doc false
  def changeset(message, attrs, opts \\ []) do
    message
    |> cast(attrs, [:content, :sender_id, :group_id])
    |> validate_required([:content, :sender_id, :group_id])
    |> encrypt_attrs(opts)
  end

  defp encrypt_attrs(changeset, opts) do
    if changeset.valid? && opts[:user_group_key] && opts[:user] && opts[:key] do
      {:ok, d_user_group_key} =
        Encrypted.Users.Utils.decrypt_user_attrs_key(
          opts[:user_group_key],
          opts[:user],
          opts[:key]
        )

      changeset
      |> put_change(
        :content,
        Utils.encrypt(%{
          key: d_user_group_key,
          payload: get_field(changeset, :content)
        })
      )
    else
      changeset
    end
  end
end
