defmodule Mosslet.Orgs.Adapters.Web do
  @moduledoc """
  Web adapter for org operations.

  This adapter uses direct Postgres access via `Mosslet.Repo`.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Orgs.Adapter

  import Ecto.Query, only: [from: 2]

  alias Mosslet.Repo
  alias Mosslet.Orgs.{Org, Membership, Invitation}

  @impl true
  def list_orgs(user) do
    Repo.preload(user, :orgs).orgs
  end

  @impl true
  def list_orgs do
    Repo.all(from(o in Org, order_by: :id))
  end

  @impl true
  def get_org!(user, slug) when is_binary(slug) do
    user
    |> Ecto.assoc(:orgs)
    |> Repo.get_by!(slug: slug)
  end

  @impl true
  def get_org!(slug) when is_binary(slug) do
    Repo.get_by!(Org, slug: slug)
  end

  @impl true
  def get_org_by_id(id) do
    Repo.get(Org, id)
  end

  @impl true
  def create_org(user, changeset) do
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

  @impl true
  def update_org(org, attrs) do
    org
    |> Org.update_changeset(attrs)
    |> Repo.update()
  end

  @impl true
  def delete_org(org) do
    Repo.delete(org)
  end

  @impl true
  def sync_user_invitations(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update_all(:updated_invitations, Invitation.assign_to_user_by_email(user), [])
    |> Ecto.Multi.delete_all(:deleted_invitations, Invitation.get_stale_by_user_id(user.id))
    |> Repo.transaction()
  end

  @impl true
  def list_members_by_org(org) do
    Repo.preload(org, :users).users
  end

  @impl true
  def delete_membership(membership) do
    Repo.delete(Membership.delete_changeset(membership))
  end

  @impl true
  def get_membership!(user, org_slug) when is_binary(org_slug) do
    user
    |> Membership.by_user_and_org_slug(org_slug)
    |> Repo.one!()
    |> Repo.preload(:org)
  end

  @impl true
  def get_membership!(id) do
    Membership
    |> Repo.get!(id)
    |> Repo.preload([:user])
  end

  @impl true
  def update_membership(membership, attrs) do
    membership
    |> Membership.update_changeset(attrs)
    |> Repo.update()
  end

  @impl true
  def get_invitation_by_org!(org, id) do
    org
    |> Invitation.by_org()
    |> Repo.get!(id)
  end

  @impl true
  def delete_invitation!(invitation) do
    Repo.delete!(invitation)
  end

  @impl true
  def create_invitation(org, params) do
    %Invitation{org_id: org.id}
    |> Invitation.changeset(params)
    |> Repo.insert()
  end

  @impl true
  def list_invitations_by_user(user) do
    user
    |> Invitation.by_user()
    |> Repo.all()
    |> Repo.preload(:org)
  end

  @impl true
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

  @impl true
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
