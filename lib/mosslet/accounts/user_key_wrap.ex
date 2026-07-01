defmodule Mosslet.Accounts.UserKeyWrap do
  @moduledoc """
  One unlock door for a user's encryption root (`user_key`) — board #362.

  See `docs/WEBAUTHN_PRF_DESIGN.md`. Each row holds an OPAQUE
  `wrapped_user_key = secretbox(user_key, wrapping_key)` plus the public
  parameters a client needs to re-derive `wrapping_key` and unwrap `user_key`
  in the browser. The server never sees `user_key`, the password, or the PRF
  output (invariant **I6**).

  Two kinds:

    * `:password` — `wrapping_key = Argon2id(password, wrap_salt)`. This is the
      default door for non-enrolled accounts. There is AT MOST ONE per user
      (DB-enforced via a partial unique index).

    * `:prf` — `wrapping_key = HKDF(password_key ‖ prf_output)`, bound to a
      WebAuthn credential (`credential_id`) evaluated with `prf_salt`. Requires
      BOTH the password AND the enrolled device. A user may have MANY (one per
      authenticator / synced-passkey ecosystem — multi-device).

  THE central invariant (flip OR→AND, never both doors open), enforced
  transactionally in `Mosslet.Accounts`:

    * non-enrolled => exactly one `:password` wrap, zero `:prf` wraps
    * enrolled     => zero `:password` wraps, one-or-more `:prf` wraps

  `user_id` is server-set (never cast from user params, per AGENTS.md).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted

  @kinds ~w(password prf)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_key_wraps" do
    field :kind, Ecto.Enum, values: @kinds
    field :wrapped_user_key, Encrypted.Binary, redact: true
    field :wrap_salt, :string
    field :credential_id, Encrypted.Binary, redact: true
    field :prf_salt, :string
    field :label, Encrypted.Binary, redact: true
    field :ecosystem_hint, :string
    field :last_used_at, :utc_datetime

    belongs_to :user, User

    timestamps()
  end

  @doc """
  Builds the changeset for the single `:password` wrap.

  `wrapping_key = Argon2id(password, wrap_salt)`; `wrapped_user_key` is produced
  in the browser (or backfilled from the legacy `users.key_hash`). `user_id` is
  server-authoritative.
  """
  def password_changeset(user_id, %{
        wrapped_user_key: wrapped_user_key,
        wrap_salt: wrap_salt
      }) do
    %__MODULE__{}
    |> change(%{
      user_id: user_id,
      kind: :password,
      wrapped_user_key: wrapped_user_key,
      wrap_salt: wrap_salt
    })
    |> validate_required([:user_id, :kind, :wrapped_user_key, :wrap_salt])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id,
      name: :user_key_wraps_one_password_wrap_index,
      message: "a password wrap already exists"
    )
  end

  @doc """
  Builds the changeset for a `:prf` (device-bound) wrap.

  `wrapping_key = HKDF(password_key ‖ prf_output)`, bound to `credential_id` and
  evaluated with `prf_salt`. `label` (sealed device nickname) and
  `ecosystem_hint` are optional. `user_id` is server-authoritative.
  """
  def prf_changeset(user_id, attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :wrapped_user_key,
      :wrap_salt,
      :credential_id,
      :prf_salt,
      :label,
      :ecosystem_hint
    ])
    |> change(user_id: user_id, kind: :prf)
    |> validate_required([
      :user_id,
      :kind,
      :wrapped_user_key,
      :wrap_salt,
      :credential_id,
      :prf_salt
    ])
    |> validate_inclusion(:ecosystem_hint, ~w(apple google cross-platform))
    |> foreign_key_constraint(:user_id)
  end
end
