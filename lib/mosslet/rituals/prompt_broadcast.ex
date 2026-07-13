defmodule Mosslet.Rituals.PromptBroadcast do
  @moduledoc """
  A single server-selected broadcast of a shared ritual prompt (EPIC #377,
  task #378).

  This row is **non-secret metadata**. It records *which* prompt is active and
  *when* — a plain question the server freely selects (from
  `Mosslet.Rituals.Prompts`) and broadcasts identically to every network. The
  server never stores or reads any *answer*; answers flow through the existing
  zero-knowledge timeline path and may optionally reference this row's `id` via
  `Mosslet.Timeline.Post.ritual_prompt_id`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ritual_prompt_broadcasts" do
    field :prompt, :string
    field :theme, :string
    field :broadcast_at, :utc_datetime
    field :expires_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(prompt_broadcast, attrs) do
    prompt_broadcast
    |> cast(attrs, [:prompt, :theme, :broadcast_at, :expires_at])
    |> validate_required([:prompt, :broadcast_at])
  end
end
