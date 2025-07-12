defmodule Mosslet.Timeline.UserPostReceipt do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Timeline.UserPost

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_post_receipts" do
    field :is_read?, :boolean, default: false
    field :read_at, :utc_datetime

    belongs_to :user, User
    belongs_to :user_post, UserPost

    timestamps()
  end

  def changeset(receipt, attrs) do
    receipt
    |> cast(attrs, [:user_id, :user_post_id, :is_read?, :read_at])
    |> cast_assoc(:user)
    |> cast_assoc(:user_post)
    |> validate_required([:user_id, :user_post_id])
    |> unique_constraint([:user_id, :user_post_id])
  end
end
