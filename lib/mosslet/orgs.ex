defmodule Mosslet.Orgs do
  @moduledoc """
  The Orgs context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Orgs.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Orgs.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """

  alias Mosslet.Platform
  alias Mosslet.Orgs.{Org, Membership, Invitation}

  @membership_roles ~w(member admin)

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.Orgs.Adapters.Web
    end
  end

  ## Orgs

  def list_orgs(user) do
    adapter().list_orgs(user)
  end

  def list_orgs do
    adapter().list_orgs()
  end

  def get_org!(user, slug) when is_binary(slug) do
    adapter().get_org!(user, slug)
  end

  def get_org!(slug) when is_binary(slug) do
    adapter().get_org!(slug)
  end

  def get_org_by_id(id) do
    adapter().get_org_by_id(id)
  end

  def create_org(user, attrs) do
    unless user.confirmed_at do
      raise ArgumentError, "user must be confirmed to create an org"
    end

    changeset = Org.insert_changeset(attrs)
    adapter().create_org(user, changeset)
  end

  def update_org(%Org{} = org, attrs) do
    adapter().update_org(org, attrs)
  end

  def delete_org(%Org{} = org) do
    adapter().delete_org(org)
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
    adapter().sync_user_invitations(user)
  end

  ## Members

  def list_members_by_org(org) do
    adapter().list_members_by_org(org)
  end

  def delete_membership(membership) do
    adapter().delete_membership(membership)
  end

  def get_membership!(user, org_slug) when is_binary(org_slug) do
    adapter().get_membership!(user, org_slug)
  end

  def get_membership!(id) do
    adapter().get_membership!(id)
  end

  def membership_roles do
    @membership_roles
  end

  def change_membership(%Membership{} = membership, attrs \\ %{}) do
    Membership.update_changeset(membership, attrs)
  end

  def update_membership(%Membership{} = membership, attrs) do
    adapter().update_membership(membership, attrs)
  end

  ## Invitations - org based

  def get_invitation_by_org!(org, id) do
    adapter().get_invitation_by_org!(org, id)
  end

  def delete_invitation!(invitation) do
    adapter().delete_invitation!(invitation)
  end

  def build_invitation(%Org{} = org, params) do
    Invitation.changeset(%Invitation{org_id: org.id}, params)
  end

  def create_invitation(org, params) do
    adapter().create_invitation(org, params)
  end

  ## Invitations - user based

  def list_invitations_by_user(user) do
    adapter().list_invitations_by_user(user)
  end

  def accept_invitation!(user, id) do
    adapter().accept_invitation!(user, id)
  end

  def reject_invitation!(user, id) do
    adapter().reject_invitation!(user, id)
  end
end
