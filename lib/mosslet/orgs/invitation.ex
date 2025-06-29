defmodule Mosslet.Orgs.Invitation do
  @moduledoc false
  use Mosslet.Schema

  import Ecto.Query

  alias Mosslet.Extensions.Ecto.ChangesetExt
  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Orgs.Membership
  alias Mosslet.Orgs.Org
  alias Mosslet.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "orgs_invitations" do
    field :sent_to, Encrypted.Binary
    field :sent_to_hash, Encrypted.HMAC

    belongs_to :org, Org
    belongs_to :user, Accounts.User

    timestamps()
  end

  def by_org(%Org{} = org) do
    from(__MODULE__, where: [org_id: ^org.id])
  end

  def by_user(%Accounts.User{} = user) do
    from(__MODULE__, where: [user_id: ^user.id])
  end

  @doc """
  Find invitations by `email` and assign them to the `user`.
  """
  def assign_to_user_by_email(%Accounts.User{} = user) do
    from(__MODULE__, where: [sent_to_hash: ^user.email_hash], update: [set: [user_id: ^user.id]])
  end

  @doc """
  Get invitations for `user_id` for which the user already joined the org.
  """
  def get_stale_by_user_id(user_id) do
    from(i in __MODULE__,
      join: o in assoc(i, :org),
      join: m in "orgs_memberships",
      on: m.org_id == o.id and m.user_id == ^user_id
    )
  end

  @already_invited "is already invited"

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:sent_to])
    |> validate_required([:sent_to])
    |> ChangesetExt.validate_email(:sent_to)
    |> add_sent_to_hash()
    |> unsafe_validate_unique([:sent_to_hash, :org_id], Repo, message: @already_invited)
    |> unique_constraint([:sent_to_hash, :org_id], message: @already_invited)
    |> put_user_id()
    |> ensure_user_not_already_in_org()
  end

  defp add_sent_to_hash(changeset) do
    if Map.has_key?(changeset.changes, :sent_to) do
      changeset
      |> put_change(:sent_to_hash, String.downcase(get_field(changeset, :sent_to)))
    else
      changeset
    end
  end

  defp put_user_id(%{valid?: true} = changeset) do
    email = fetch_change!(changeset, :sent_to)
    user = Accounts.get_user_by_email(email)
    put_change(changeset, :user_id, user && user.confirmed_at && user.id)
  end

  defp put_user_id(changeset), do: changeset

  defp ensure_user_not_already_in_org(changeset) do
    org_id = changeset.data.org_id
    user_id = get_change(changeset, :user_id)

    if user_id && Repo.exists?(from(Membership, where: [org_id: ^org_id, user_id: ^user_id])) do
      add_error(changeset, :sent_to_hash, "already in this organization")
    else
      changeset
    end
  end
end
