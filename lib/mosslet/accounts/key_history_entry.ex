defmodule Mosslet.Accounts.KeyHistoryEntry do
  @moduledoc """
  One append-only, signed leaf in a user's key history (#290 step 4 / #315).

  Each entry is a PUBLIC, signed record in the `mosslet/key-history/v1` format
  (built + signed entirely client-side; see `assets/js/crypto/key_history.js`).
  The genesis entry (seq 0) carries the user's first signing public key and is
  self-signed (the TOFU anchor peers pin). Every later entry carries new key
  material and is signed by the PREVIOUS entry's signing key and chained by
  `prev_hash` — so a peer's client can cryptographically verify that a key
  rotation is legitimate rather than a server substitution.

  The server is DUMB here: it stores and serves the opaque serialized leaf and
  never signs or verifies. Authenticity comes from the signature chain, not from
  secrecy — entries hold only public material (encryption + signing public keys,
  hashes, timestamp, signature). The blobs are Cloak-wrapped at-rest
  (`Encrypted.Binary`) purely as defense-in-depth, consistent with how the
  public `pq_public_key` is already stored.

  Append-only by construction: there is no update/delete changeset. `user_id` and
  `seq` are server-set (never cast from user params, per AGENTS.md).

  The byte-reproducible leaf format is locked cross-SDK by
  `test/mosslet/crypto/key_history_test.exs`. The per-user chain is the first
  real leaf shape the future metamorphic-log must absorb with zero reformatting
  (#299/#316).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "key_history_entries" do
    field :seq, :integer
    field :entry, Encrypted.Binary, redact: true
    field :signing_public_key, Encrypted.Binary, redact: true

    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @doc """
  Builds an insert changeset for one appended leaf.

  `user_id` and `seq` are set explicitly (server-authoritative, never cast).
  `entry` is the opaque serialized public leaf produced in the browser;
  `signing_public_key` is the denormalized signing key that leaf pins.
  """
  def append_changeset(user_id, seq, entry, signing_public_key)
      when is_binary(entry) and is_integer(seq) do
    %__MODULE__{}
    |> change(%{
      user_id: user_id,
      seq: seq,
      entry: entry,
      signing_public_key: signing_public_key
    })
    |> validate_required([:user_id, :seq, :entry])
    |> validate_number(:seq, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :seq])
  end
end
