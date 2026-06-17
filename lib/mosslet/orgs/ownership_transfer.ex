defmodule Mosslet.Orgs.OwnershipTransfer do
  @moduledoc """
  An org ownership-transfer handshake record (Task #237, Option C).

  Ownership of an org is `Org.created_by_id`. Transferring it is a two-step
  request -> accept handshake: the current owner proposes a transfer to an
  existing confirmed member, and the proposed new owner must explicitly accept.
  The handshake exists for two reasons:

    1. **ZK-safe Stripe email sync.** The org's `:org` Stripe customer email must
       follow the new owner, but `user.email` is double-encrypted and can only be
       decrypted with that user's `session_key`. The OLD owner does not hold the
       NEW owner's `session_key`, so the email reconciliation can only run in the
       new owner's authenticated session — i.e. on `accept`.

    2. **Consent gate.** Org billing/ownership is never forced onto anyone; the
       proposed new owner agrees before it lands on them.

  Statuses:

    * `:pending`   — proposed, awaiting the new owner's decision.
    * `:accepted`  — accepted; ownership has been flipped + role promoted.
    * `:declined`  — the proposed new owner refused.
    * `:cancelled` — the original owner withdrew the proposal.

  ZK-safe: this schema stores ONLY ids, the system status enum, and timestamps —
  never plaintext, email, key material, or secrets. All business logic, queries,
  and transactions live in `Mosslet.Orgs`.
  """
  use Mosslet.Schema

  import Ecto.Query

  alias Mosslet.Accounts.User
  alias Mosslet.Orgs.Org

  @status_options ~w(pending accepted declined cancelled)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "org_ownership_transfers" do
    field :status, Ecto.Enum, values: @status_options, default: :pending

    field :accepted_at, :utc_datetime
    field :declined_at, :utc_datetime
    field :cancelled_at, :utc_datetime

    belongs_to :org, Org
    belongs_to :from_user, User
    belongs_to :to_user, User

    timestamps()
  end

  def status_options, do: @status_options

  ## Queries

  def pending_for_org(%Org{} = org) do
    from(t in __MODULE__, where: t.org_id == ^org.id and t.status == :pending)
  end

  def pending_for_user(%User{} = user) do
    from(t in __MODULE__,
      where: t.to_user_id == ^user.id and t.status == :pending,
      order_by: [desc: t.inserted_at]
    )
  end

  @doc """
  Builds a new pending transfer. All references and the status are set
  explicitly by the context (`initiate_ownership_transfer/3`), never cast from
  user input.
  """
  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:org_id, :from_user_id, :to_user_id, :status])
    |> validate_required([:org_id, :from_user_id, :to_user_id, :status])
    |> validate_inclusion(:status, @status_options)
    |> validate_distinct_parties()
    |> foreign_key_constraint(:org_id)
    |> foreign_key_constraint(:from_user_id)
    |> foreign_key_constraint(:to_user_id)
    |> unique_constraint(:org_id,
      name: :org_ownership_transfers_one_pending_per_org,
      message: "a transfer is already pending for this organization"
    )
  end

  @doc """
  Status-transition changeset. Only `status` and the related timestamps are cast
  — never the org/user references.
  """
  def status_changeset(transfer, attrs) do
    transfer
    |> cast(attrs, [:status, :accepted_at, :declined_at, :cancelled_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @status_options)
  end

  defp validate_distinct_parties(changeset) do
    from_id = get_field(changeset, :from_user_id)
    to_id = get_field(changeset, :to_user_id)

    if from_id && to_id && from_id == to_id do
      add_error(changeset, :to_user_id, "cannot transfer ownership to yourself")
    else
      changeset
    end
  end
end
