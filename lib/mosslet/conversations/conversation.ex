defmodule Mosslet.Conversations.Conversation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.UserConnection
  alias Mosslet.Conversations.{Message, UserConversation}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversations" do
    belongs_to :user_connection, UserConnection
    has_many :user_conversations, UserConversation
    has_many :messages, Message

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:user_connection_id])
    |> validate_required([:user_connection_id])
    |> unique_constraint(:user_connection_id)
  end
end
