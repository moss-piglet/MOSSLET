defmodule Mosslet.Orgs.Adapters.Web do
  @moduledoc """
  Web adapter for org operations.

  This adapter uses direct Postgres access via `Mosslet.Repo`.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Orgs.Adapter

  import Ecto.Query, only: [from: 2]

  alias Mosslet.Repo
  alias Mosslet.Orgs.{Org, Membership, Invitation, Guardianship}

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

  ## Guardianships

  @impl true
  def establish_guardianship(
        %Membership{} = guardian,
        %Membership{} = managed,
        opts
      ) do
    requires_consent = Keyword.get(opts, :requires_consent, true)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Minor/dependent accounts (requires_consent: false) may start :active.
    # Of-age members must explicitly accept, so the link starts :pending.
    {status, consented_at} =
      if requires_consent, do: {:pending, nil}, else: {:active, now}

    cond do
      guardian.org_id != managed.org_id ->
        {:error, :different_orgs}

      guardian.role != :guardian ->
        {:error, :guardian_role_required}

      managed.role != :managed_member ->
        {:error, :managed_member_role_required}

      Repo.exists?(
        from(g in Guardianship,
          where:
            g.guardian_membership_id == ^guardian.id and
                g.managed_membership_id == ^managed.id
        )
      ) ->
        {:error, :already_exists}

      true ->
        attrs = %{
          org_id: guardian.org_id,
          guardian_membership_id: guardian.id,
          managed_membership_id: managed.id,
          status: status,
          requires_consent: requires_consent,
          established_at: now,
          consented_at: consented_at
        }

        case Repo.transaction_on_primary(fn ->
               attrs
               |> Guardianship.insert_changeset()
               |> Repo.insert()
             end) do
          {:ok, {:ok, guardianship}} -> {:ok, guardianship}
          {:ok, {:error, changeset}} -> {:error, changeset}
          error -> error
        end
    end
  end

  @impl true
  def accept_guardianship(%Guardianship{} = guardianship) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update_guardianship_status(guardianship, %{status: :active, consented_at: now})
  end

  @impl true
  def decline_guardianship(%Guardianship{} = guardianship) do
    update_guardianship_status(guardianship, %{status: :declined})
  end

  @impl true
  def pause_guardianship(%Guardianship{} = guardianship) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update_guardianship_status(guardianship, %{status: :paused, paused_at: now})
  end

  @impl true
  def resume_guardianship(%Guardianship{} = guardianship) do
    update_guardianship_status(guardianship, %{status: :active})
  end

  @impl true
  def revoke_guardianship(%Guardianship{} = guardianship) do
    case Repo.transaction_on_primary(fn -> Repo.delete(guardianship) end) do
      {:ok, {:ok, guardianship}} -> {:ok, guardianship}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def list_active_guardians_for(%Org{} = org, managed_user_id) do
    # Server-authoritative consent gate: only :active guardianships whose managed
    # membership belongs to this user in this org. Returns full User structs so
    # the write path can read public_key + pq_public_key.
    from(g in Guardianship,
      join: managed in Membership,
      on: managed.id == g.managed_membership_id,
      join: guardian in Membership,
      on: guardian.id == g.guardian_membership_id,
      join: guardian_user in assoc(guardian, :user),
      where: g.org_id == ^org.id and g.status == :active and managed.user_id == ^managed_user_id,
      select: guardian_user
    )
    |> Repo.all()
  end

  @impl true
  def list_active_guardian_users_for_user(user_id) when is_binary(user_id) do
    # Cross-org consent gate: all :active guardianships across every family org
    # where this user is the managed member. Distinct guardian users.
    from(g in Guardianship,
      join: managed in Membership,
      on: managed.id == g.managed_membership_id,
      join: guardian in Membership,
      on: guardian.id == g.guardian_membership_id,
      join: guardian_user in assoc(guardian, :user),
      where: g.status == :active and managed.user_id == ^user_id,
      distinct: guardian_user.id,
      select: guardian_user
    )
    |> Repo.all()
  end

  def list_active_guardian_users_for_user(_), do: []

  @impl true
  def list_guardianships_by_org(%Org{} = org) do
    org
    |> Guardianship.by_org()
    |> Repo.all()
    |> Repo.preload(
      guardian_membership: [:user],
      managed_membership: [:user]
    )
  end

  @impl true
  def list_guardianships_for_managed_membership(%Membership{} = membership) do
    membership.id
    |> Guardianship.for_managed_membership()
    |> Repo.all()
    |> Repo.preload(
      guardian_membership: [:user],
      managed_membership: [:user]
    )
  end

  @impl true
  def list_guardianships_for_guardian_membership(%Membership{} = membership) do
    membership.id
    |> Guardianship.for_guardian_membership()
    |> Repo.all()
    |> Repo.preload(
      guardian_membership: [:user],
      managed_membership: [:user]
    )
  end

  @impl true
  def get_guardianship!(id) do
    Guardianship
    |> Repo.get!(id)
    |> Repo.preload(
      guardian_membership: [:user],
      managed_membership: [:user]
    )
  end

  defp update_guardianship_status(guardianship, attrs) do
    case Repo.transaction_on_primary(fn ->
           guardianship
           |> Guardianship.status_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, guardianship}} -> {:ok, guardianship}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end
end
