defmodule Mosslet.Capsules.Capsule do
  @moduledoc """
  A time capsule — an encrypted "letter to your future self".

  Capsules are written now, sealed with a future `deliver_on` date, and
  resurface for reading on/after that date. They are strictly private,
  user-only content — never shared with anyone.

  ## Zero-knowledge boundary

  `title` and `body` are encrypted in the BROWSER with the user's personal
  key (user_key) via WASM, exactly like a journal entry. The server stores
  opaque ciphertext and NEVER sees the plaintext.

  The ONLY server-visible fields are metadata:

    * `deliver_on` — the delivery date (the sole gate for hiding + notifying)
    * `sealed_at` / `opened_at` — lifecycle timestamps
    * `stationery` — a cosmetic enum used purely for letter styling
    * `word_count` — a coarse integer for display

  Encryption pattern: user_key only (mirrors `Mosslet.Journal.JournalEntry`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted

  @stationeries [
    "classic",
    "tangerine",
    "sunset",
    "linen",
    "dusk",
    "lavender",
    "meadow",
    "sage",
    "tide",
    "rose",
    "parchment",
    "midnight"
  ]

  def stationeries, do: @stationeries

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "time_capsules" do
    field :title, Encrypted.Binary, redact: true
    field :body, Encrypted.Binary, redact: true

    field :deliver_on, :date
    field :sealed_at, :utc_datetime
    field :notified_at, :utc_datetime
    field :opened_at, :utc_datetime
    field :stationery, :string, default: "classic"
    field :word_count, :integer, default: 0

    # Virtual: holds pre-decrypt payload attached for ZK browser rendering.
    field :decrypted, :map, virtual: true

    belongs_to :user, User

    timestamps()
  end

  @doc """
  ZK changeset — accepts pre-encrypted fields from the browser.

  The browser encrypts title/body with the user_key via WASM and sends the
  ciphertext as `encrypted_title` / `encrypted_body`. The server stores it
  directly without ever seeing plaintext.
  """
  def changeset_zk(capsule, attrs) do
    capsule
    |> cast(attrs, [:deliver_on, :stationery, :word_count, :user_id])
    |> validate_required([:deliver_on])
    |> validate_stationery()
    |> validate_deliver_on()
    |> maybe_set_sealed_at()
    |> put_encrypted_fields(attrs)
    |> validate_required([:body], message: "can't be blank")
  end

  @doc """
  Marks a capsule as opened (metadata-only; never touches content).
  """
  def open_changeset(capsule, opened_at \\ DateTime.utc_now()) do
    capsule
    |> change(opened_at: DateTime.truncate(opened_at, :second))
  end

  defp validate_stationery(changeset) do
    case get_field(changeset, :stationery) do
      nil -> put_change(changeset, :stationery, "classic")
      s when s in @stationeries -> changeset
      _ -> add_error(changeset, :stationery, "is not a valid stationery")
    end
  end

  # A capsule to your future self must be delivered in the future. Guard against
  # past/today dates so the sealing ritual is meaningful (server sees only the date).
  defp validate_deliver_on(changeset) do
    case get_change(changeset, :deliver_on) do
      nil ->
        changeset

      %Date{} = date ->
        if Date.compare(date, Date.utc_today()) == :gt do
          changeset
        else
          add_error(changeset, :deliver_on, "must be a future date")
        end
    end
  end

  defp maybe_set_sealed_at(changeset) do
    if get_field(changeset, :sealed_at) do
      changeset
    else
      put_change(changeset, :sealed_at, DateTime.truncate(DateTime.utc_now(), :second))
    end
  end

  defp put_encrypted_fields(changeset, attrs) do
    changeset
    |> then(fn cs ->
      if enc = attrs["encrypted_title"], do: put_change(cs, :title, enc), else: cs
    end)
    |> then(fn cs ->
      if enc = attrs["encrypted_body"], do: put_change(cs, :body, enc), else: cs
    end)
  end
end
