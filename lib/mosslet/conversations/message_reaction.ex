defmodule Mosslet.Conversations.MessageReaction do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Conversations.Message
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "message_reactions" do
    field :emoji, Encrypted.Binary, redact: true

    belongs_to :message, Message
    belongs_to :user, User

    timestamps()
  end

  @type t :: %__MODULE__{}

  @doc false
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji])
    |> validate_required([:emoji])
  end
end
