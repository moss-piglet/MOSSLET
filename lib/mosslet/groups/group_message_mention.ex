defmodule Mosslet.Groups.GroupMessageMention do
  @moduledoc """
  Schema for tracking @mentions in group chat messages.

  Each mention links a message to the user_group that was mentioned.
  The read_at field tracks whether the mentioned user has seen the message.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Groups.{GroupMessage, UserGroup}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "group_message_mentions" do
    field :read_at, :naive_datetime

    belongs_to :group_message, GroupMessage
    belongs_to :mentioned_user_group, UserGroup

    timestamps()
  end

  @doc false
  def changeset(mention, attrs) do
    mention
    |> cast(attrs, [:read_at, :group_message_id, :mentioned_user_group_id])
    |> validate_required([:group_message_id, :mentioned_user_group_id])
    |> unique_constraint([:group_message_id, :mentioned_user_group_id])
    |> foreign_key_constraint(:group_message_id)
    |> foreign_key_constraint(:mentioned_user_group_id)
  end

  @doc """
  Marks a mention as read.
  """
  def mark_read_changeset(mention) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(mention, read_at: now)
  end
end
