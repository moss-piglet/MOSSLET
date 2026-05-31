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

    case Repo.transaction_on_primary(fn -> Repo.transaction(multi) end) do
      {:ok, {:ok, %{org: org}}} ->
        {:ok, org}

      {:ok, {:error, :org, changeset, _}} ->
        {:error, changeset}

      _ ->
        {:error, :transaction_failed}
    end
  end

  @impl true
  def update_org(org, attrs) do
    case Repo.transaction_on_primary(fn ->
           org
           |> Org.update_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, org}} -> {:ok, org}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def delete_org(org) do
    case Repo.transaction_on_primary(fn -> Repo.delete(org) end) do
      {:ok, {:ok, org}} -> {:ok, org}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def sync_user_invitations(user) do
    Repo.transaction_on_primary(fn ->
      Ecto.Multi.new()
      |> Ecto.Multi.update_all(:updated_invitations, Invitation.assign_to_user_by_email(user), [])
      |> Ecto.Multi.delete_all(:deleted_invitations, Invitation.get_stale_by_user_id(user.id))
      |> Repo.transaction()
    end)
  end

  @impl true
  def list_members_by_org(org) do
    Repo.preload(org, :users).users
  end

  @impl true
  def delete_membership(membership) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(Membership.delete_changeset(membership))
         end) do
      {:ok, {:ok, membership}} -> {:ok, membership}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
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
    case Repo.transaction_on_primary(fn ->
           membership
           |> Membership.update_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, membership}} -> {:ok, membership}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def get_invitation_by_org!(org, id) do
    org
    |> Invitation.by_org()
    |> Repo.get!(id)
  end

  @impl true
  def delete_invitation!(invitation) do
    case Repo.transaction_on_primary(fn -> Repo.delete!(invitation) end) do
      {:ok, result} -> result
      error -> error
    end
  end

  @impl true
  def create_invitation(org, params) do
    case Repo.transaction_on_primary(fn ->
           %Invitation{org_id: org.id}
           |> Invitation.changeset(params)
           |> Repo.insert()
         end) do
      {:ok, {:ok, invitation}} -> {:ok, invitation}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
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

    {:ok, {:ok, %{membership: membership}}} =
      Repo.transaction_on_primary(fn ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:membership, Membership.insert_changeset(org, user))
        |> Ecto.Multi.delete(:invitation, invitation)
        |> Repo.transaction()
      end)

    %{membership | org: org}
  end

  @impl true
  def reject_invitation!(user, id) do
    invitation = get_invitation_by_user!(user, id)

    case Repo.transaction_on_primary(fn -> Repo.delete!(invitation) end) do
      {:ok, result} -> result
      error -> error
    end
  end

  defp get_invitation_by_user!(user, id) do
    user
    |> Invitation.by_user()
    |> Repo.get!(id)
  end
end
