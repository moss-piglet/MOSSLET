defmodule Mosslet.Nudges.Nudge do
  @moduledoc """
  A single content-free "thinking of you" nudge (EPIC #377, task #399).

  This row is **pure, non-secret metadata**: `from_user_id`, `to_user_id`, and
  timestamps. There is no message, no ciphertext, and no per-connection key —
  a nudge is a wordless gesture ("I'm thinking of you"), so the server has
  nothing to read.

  The sender's NAME shown to the recipient ("Poppy was thinking of you") is NOT
  stored here. It is resolved entirely client-side on the recipient's dashboard
  by reusing the recipient's already-sealed connection data (the same
  zero-knowledge path every connection card uses). See
  `MossletWeb.UserDashLive` and the `DecryptNudge` JS hook.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "nudges" do
    field :from_user_id, :binary_id
    field :to_user_id, :binary_id
    field :seen_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(nudge, attrs) do
    nudge
    |> cast(attrs, [:from_user_id, :to_user_id, :seen_at])
    |> validate_required([:from_user_id, :to_user_id])
  end
end
