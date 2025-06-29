defmodule Mosslet.Orgs do
  @moduledoc false
  import Ecto.Query, only: [from: 2]

  alias Mosslet.Orgs.Invitation
  alias Mosslet.Orgs.Membership
  alias Mosslet.Orgs.Org
  alias Mosslet.Repo

  @membership_roles ~w(member admin)

  ## Orgs

  def list_orgs(user) do
    Repo.preload(user, :orgs).orgs
  end

  def list_orgs do
    Repo.all(from(o in Org, order_by: :id))
  end

  def get_org!(user, slug) when is_binary(slug) do
    user
    |> Ecto.assoc(:orgs)
    |> Repo.get_by!(slug: slug)
  end

  def get_org!(slug) when is_binary(slug) do
    Repo.get_by!(Org, slug: slug)
  end

  def get_org_by_id(id) do
    Repo.get(Org, id)
  end

  def create_org(user, attrs) do
    unless user.confirmed_at do
      raise ArgumentError, "user must be confirmed to create an org"
    end

    changeset = Org.insert_changeset(attrs)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:org, changeset)
      |> Ecto.Multi.insert(:membership, fn %{org: org} ->
        Membership.insert_changeset(org, user, :admin)
      end)

    case Repo.transaction(multi) do
      {:ok, %{org: org}} ->
        {:ok, org}

      {:error, :org, changeset, _} ->
        {:error, changeset}
    end
  end

  def update_org(%Org{} = org, attrs) do
    org
    |> Org.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_org(%Org{} = org) do
    Repo.delete(org)
  end

  def change_org(org, attrs \\ %{}) do
    if Ecto.get_meta(org, :state) == :loaded do
      Org.update_changeset(org, attrs)
    else
      Org.insert_changeset(attrs)
    end
  end

  @doc """
  This will find any invitations for a user's email address and assign them to the user.
  It will also delete any invitations to orgs the user is already a member of.
  Run this after a user has confirmed or changed their email.
  """
  def sync_user_invitations(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update_all(:updated_invitations, Invitation.assign_to_user_by_email(user), [])
    |> Ecto.Multi.delete_all(:deleted_invitations, Invitation.get_stale_by_user_id(user.id))
    |> Repo.transaction()
  end

  ## Members

  def list_members_by_org(org) do
    Repo.preload(org, :users).users
  end

  def delete_membership(membership) do
    Repo.delete(Membership.delete_changeset(membership))
  end

  def get_membership!(user, org_slug) when is_binary(org_slug) do
    user
    |> Membership.by_user_and_org_slug(org_slug)
    |> Repo.one!()
    |> Repo.preload(:org)
  end

  def get_membership!(id) do
    Membership
    |> Repo.get!(id)
    |> Repo.preload([:user])
  end

  def membership_roles do
    @membership_roles
  end

  def change_membership(%Membership{} = membership, attrs \\ %{}) do
    Membership.update_changeset(membership, attrs)
  end

  def update_membership(%Membership{} = membership, attrs) do
    membership
    |> Membership.update_changeset(attrs)
    |> Repo.update()
  end

  ## Invitations - org based

  def get_invitation_by_org!(org, id) do
    org
    |> Invitation.by_org()
    |> Repo.get!(id)
  end

  def delete_invitation!(invitation) do
    Repo.delete(invitation)
  end

  def build_invitation(%Org{} = org, params) do
    Invitation.changeset(%Invitation{org_id: org.id}, params)
  end

  def create_invitation(org, params) do
    %Invitation{org_id: org.id}
    |> Invitation.changeset(params)
    |> Repo.insert()
  end

  ## Invitations - user based

  def list_invitations_by_user(user) do
    user
    |> Invitation.by_user()
    |> Repo.all()
    |> Repo.preload(:org)
  end

  def accept_invitation!(user, id) do
    invitation = get_invitation_by_user!(user, id)
    org = Repo.one!(Ecto.assoc(invitation, :org))

    {:ok, %{membership: membership}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:membership, Membership.insert_changeset(org, user))
      |> Ecto.Multi.delete(:invitation, invitation)
      |> Repo.transaction()

    %{membership | org: org}
  end

  def reject_invitation!(user, id) do
    invitation = get_invitation_by_user!(user, id)
    Repo.delete!(invitation)
  end

  defp get_invitation_by_user!(user, id) do
    user
    |> Invitation.by_user()
    |> Repo.get!(id)
  end
end
