defmodule Mosslet.Orgs.Org do
  @moduledoc false
  use Mosslet.Schema

  alias Mosslet.Extensions.Ecto.ChangesetExt
  alias Mosslet.Accounts.User
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Encrypted
  alias Mosslet.Orgs.Invitation
  alias Mosslet.Orgs.Membership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "orgs" do
    field :name, Encrypted.Binary
    field :name_hash, Encrypted.HMAC
    field :slug, :string

    has_many :memberships, Membership
    has_many :invitations, Invitation
    many_to_many :users, User, join_through: "orgs_memberships", unique: true
    has_one :customer, Customer

    timestamps()
  end

  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name])
    |> validate_name()
    |> name_to_slug()
    |> unique_constraint(:slug)
    |> unsafe_validate_unique(:slug, Mosslet.Repo)
  end

  def validate_name(changeset) do
    changeset
    |> ChangesetExt.ensure_trimmed(:name)
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
  end

  def update_changeset(org, attrs) do
    org
    |> cast(attrs, [:name])
    |> validate_name()
  end

  defp name_to_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      new_name ->
        change(changeset, %{slug: friendly_slug(new_name)})
    end
  end

  # We currently don't use the org name in the slug
  # for privacy. The name of the org will stay encrypted
  # and a random slug will be used for sharing urls.
  defp friendly_slug(_new_name) do
    new_name_slug = FriendlyID.generate(4, separator: "-")
    Slug.slugify(new_name_slug)
  end
end
