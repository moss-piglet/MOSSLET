defmodule Mosslet.Groups.GroupBlock do
  @moduledoc """
  Schema for tracking blocked users in groups.
  When a user is blocked from a group, they cannot rejoin until unblocked.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "group_blocks" do
    field :reason, Encrypted.Binary, redact: true
    field :blocked_moniker, Encrypted.Binary, redact: true

    belongs_to :group, Mosslet.Groups.Group
    belongs_to :user, Mosslet.Accounts.User
    belongs_to :blocked_by, Mosslet.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(group_block, attrs) do
    group_block
    |> cast(attrs, [:group_id, :user_id, :blocked_by_id, :reason, :blocked_moniker])
    |> validate_required([:group_id, :user_id, :blocked_by_id])
    |> unique_constraint([:group_id, :user_id], name: :group_blocks_group_id_user_id_index)
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:blocked_by_id)
  end
end
