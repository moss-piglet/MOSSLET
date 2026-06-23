defmodule Mosslet.Accounts.KeyPin do
  @moduledoc """
  Unified TOFU key pin (EPIC #291 / Phase 1 / #293, REVISED).

  Records the VIEWER's (`user_id`) pin of a PEER's (`peer_user_id`) hybrid
  public-key fingerprint, keyed per-(viewer, peer) and INDEPENDENT of how the
  two users are related (personal connection, org/family/business circle). One
  pin per peer is the single source of truth: if a peer's key rotates, every
  context that seals to that peer flags it consistently.

  `pinned_fingerprint` is an opaque blob: a NaCl secretbox produced in the
  viewer's browser under their `user_key` (so the server cannot read or forge
  it), additionally Cloak-wrapped at-rest via `Encrypted.Binary`.

  Both `user_id` and `peer_user_id` are server-set (never cast from user
  params, per the AGENTS.md security rule). The fingerprint blob is written
  only through `pin_changeset/3`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "key_pins" do
    field :pinned_fingerprint, Encrypted.Binary, redact: true

    belongs_to :user, User
    belongs_to :peer_user, User

    timestamps()
  end

  @doc """
  Builds a changeset for a (viewer, peer) pin.

  `viewer_id` and `peer_user_id` are set explicitly (server-authoritative,
  NOT cast from user params). `sealed_fingerprint` is the opaque,
  browser-sealed blob.
  """
  def pin_changeset(viewer_id, peer_user_id, sealed_fingerprint)
      when is_binary(sealed_fingerprint) do
    %__MODULE__{}
    |> change(%{
      user_id: viewer_id,
      peer_user_id: peer_user_id,
      pinned_fingerprint: sealed_fingerprint
    })
    |> validate_required([:user_id, :peer_user_id, :pinned_fingerprint])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:peer_user_id)
    |> unique_constraint([:user_id, :peer_user_id])
  end
end
