defmodule Mosslet.Conversations.Conversation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversations" do
    field :name, Encrypted.Binary
    field :model, Encrypted.Binary

    field :temperature, :float, default: 1.0
    field :frequency_penalty, :float, default: 0.0

    belongs_to :user, Mosslet.Accounts.User

    has_many :messages, Mosslet.Messages.Message
    timestamps()
  end

  def model_options() do
    [
      {"gpt-4", "gpt-4"},
      {"gpt-3.5-turbo-16k", "gpt-3.5-turbo-16k"},
      {"gpt-3.5-turbo (stable)", "gpt-3.5-turbo"}
    ]
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:name, :model, :temperature, :frequency_penalty, :user_id])
    |> validate_required([:name, :model, :user_id])
  end
end
