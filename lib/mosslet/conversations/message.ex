defmodule Mosslet.Conversations.Message do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Conversations.Conversation
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "messages" do
    field :content, Encrypted.Binary, redact: true
    field :edited, :boolean, default: false

    belongs_to :conversation, Conversation
    belongs_to :sender, User

    timestamps()
  end

  @type t :: %__MODULE__{}

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :edited])
    |> validate_required([:content])
  end
end
