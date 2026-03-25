defmodule Mosslet.Conversations.UserConversation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Conversations.Conversation
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_conversations" do
    field :key, Encrypted.Binary, redact: true
    field :last_read_at, :naive_datetime
    field :archived, :boolean, default: false

    belongs_to :conversation, Conversation
    belongs_to :user, User

    timestamps()
  end

  @type t :: %__MODULE__{}

  @doc false
  def changeset(user_conversation, attrs) do
    user_conversation
    |> cast(attrs, [:key, :last_read_at, :archived])
    |> validate_required([:key])
  end
end
