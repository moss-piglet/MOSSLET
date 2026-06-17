defmodule Mosslet.Orgs.Adapters.Web do
  @moduledoc """
  Web adapter for org operations.

  This adapter uses direct Postgres access via `Mosslet.Repo`.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Orgs.Adapter

  import Ecto.Query, only: [from: 2, where: 3, order_by: 3, join: 5]

  alias Mosslet.Repo
  alias Mosslet.Orgs.{Org, Membership, Invitation, Guardianship, OwnershipTransfer}

  @impl true
  def list_orgs(user) do
    Repo.preload(user, :orgs).orgs
  end

  @impl true
  def list_orgs do
    Repo.all(from(o in Org, order_by: :id))
  end

  # All of a user's confirmed org memberships with their `:org` preloaded,
  # most-recently-joined first. Used by the personal billing page (Task #239
  # follow-up) to surface family/business seats + ownership alongside the
  # personal plan. The org subscription status is resolved per org by the caller
  # against the small org set a user typically belongs to.
  @impl true
  def list_memberships_for_user(user) do
    from(m in Membership,
      where: m.user_id == ^user.id,
      order_by: [desc: m.inserted_at],
      preload: [:org]
    )
    |> Repo.all()
  end

  @impl true
  def list_orgs_with_billing do
    # Single query + preload of the org's billing customer and its subscriptions,
    # so the reclaim sweep can classify every org without per-org lookups (no
    # N+1). The `customer` has_one and its `subscriptions` has_many are loaded in
    # bulk.
    Org
    |> order_by([o], asc: o.inserted_at)
    |> Repo.all()
    |> Repo.preload(customer: :subscriptions)
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
  def get_org_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Org, slug: slug)
  end

  @impl true
  def list_owned_orgs(user, type) do
    Org
    |> where([o], o.created_by_id == ^user.id)
    |> maybe_filter_type(type)
    |> order_by([o], asc: o.inserted_at)
    |> Repo.all()
  end

  @impl true
  def count_owned_orgs(user, type) do
    Org
    |> where([o], o.created_by_id == ^user.id)
    |> maybe_filter_type(type)
    |> Repo.aggregate(:count, :id)
  end

  @impl true
  def count_member_orgs(user, type) do
    Org
    |> join(:inner, [o], m in Membership, on: m.org_id == o.id and m.user_id == ^user.id)
    |> where([o], o.created_by_id != ^user.id)
    |> maybe_filter_type(type)
    |> Repo.aggregate(:count, :id)
  end

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, type), do: where(query, [o], o.type == ^type)

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

  ## Org-scoped ZK identity (Task #225)

  @impl true
  def list_memberships_with_users(%Org{} = org) do
    from(m in Membership,
      where: m.org_id == ^org.id,
      order_by: [asc: m.inserted_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  @impl true
  def seal_org_key_for_members(%Org{} = org, sealed_list) when is_list(sealed_list) do
    # Server-authoritative recipient set (D1): we only persist a sealed key for a
    # user who is a CURRENT member of this org. A tampered client cannot seal the
    # org_key into a row for an outsider — there is no such membership row to
    # update. We also never overwrite a key that is already set (sealing is
    # idempotent / one-time per member).
    #
    # Each write goes through `Membership.seal_key_changeset/2` + `Repo.update`
    # so the `Encrypted.Binary` Cloak wrapping is applied on dump. (`update_all`
    # would bypass Cloak encryption and break the at-rest invariant — never use
    # it for encrypted fields.)
    memberships_by_user_id =
      from(m in Membership, where: m.org_id == ^org.id)
      |> Repo.all()
      |> Map.new(&{&1.user_id, &1})

    result =
      Repo.transaction_on_primary(fn ->
        Enum.reduce(sealed_list, 0, fn entry, acc ->
          # Normalize to string keys once: entries arrive either from the browser
          # (JSON -> string keys) or from server-side callers/tests (atom keys).
          entry = Map.new(entry, fn {k, v} -> {to_string(k), v} end)
          user_id = entry["user_id"]
          sealed_key = entry["sealed_key"]
          membership = is_binary(user_id) && Map.get(memberships_by_user_id, user_id)

          cond do
            not is_binary(sealed_key) ->
              acc

            # Not a current member of this org -> drop (D1).
            !membership ->
              acc

            # Key already sealed -> idempotent no-op.
            not is_nil(membership.key) ->
              acc

            true ->
              case membership
                   |> Membership.seal_key_changeset(sealed_key)
                   |> Repo.update() do
                {:ok, _} -> acc + 1
                {:error, _} -> acc
              end
          end
        end)
      end)

    case result do
      {:ok, count} when is_integer(count) -> {:ok, count}
      error -> error
    end
  end

  @impl true
  def set_org_display_name(%Membership{} = membership, encrypted_name)
      when is_binary(encrypted_name) do
    case Repo.transaction_on_primary(fn ->
           membership
           |> Membership.display_name_changeset(encrypted_name)
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
  def get_invitation_with_org(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Invitation
        |> Repo.get(uuid)
        |> Repo.preload(:org)

      :error ->
        nil
    end
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
  def count_pending_invitations(org) do
    # An invitation row exists only while pending: it is deleted on accept/reject
    # (see accept_invitation!/reject_invitation!), so the row count is the pending
    # count.
    Invitation
    |> where([i], i.org_id == ^org.id)
    |> Repo.aggregate(:count, :id)
  end

  @impl true
  def list_invitations_by_user(user) do
    user
    |> Invitation.by_user()
    |> Repo.all()
    |> Repo.preload(:org)
  end

  @impl true
  def list_invitations_by_org(org) do
    org
    |> Invitation.by_org()
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
    |> Repo.preload(:org)
  end

  @impl true
  def list_pending_invitations_by_email_hash(email_hash) do
    # NOTE: We compare the loaded HMAC values in Elixir rather than in SQL.
    # `Encrypted.HMAC` (Cloak) hashes its input on *dump*, so binding a loaded
    # hash into a query (`where: i.sent_to_hash == ^email_hash`) would hash it a
    # second time and never match. Pending invitations are inherently low-volume
    # (a row exists only while pending — deleted on accept/reject), so loading
    # them and filtering on the already-loaded 64-byte hash is correct and cheap.
    from(i in Invitation, where: not is_nil(i.org_id))
    |> Repo.all()
    |> Repo.preload(:org)
    |> Enum.filter(&(&1.sent_to_hash == email_hash))
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
  def accept_invitation_record!(user, invitation) do
    org =
      case invitation.org do
        %Org{} = org -> org
        _ -> Repo.one!(Ecto.assoc(invitation, :org))
      end

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

  ## Ownership transfer handshake (Task #237)

  @impl true
  def insert_ownership_transfer(attrs) do
    case Repo.transaction_on_primary(fn ->
           attrs
           |> OwnershipTransfer.insert_changeset()
           |> Repo.insert()
         end) do
      {:ok, {:ok, transfer}} -> {:ok, transfer}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def get_ownership_transfer(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Repo.get(OwnershipTransfer, uuid) |> Repo.preload([:org, :from_user, :to_user])

      :error ->
        nil
    end
  end

  @impl true
  def get_pending_transfer_for_org(%Org{} = org) do
    org
    |> OwnershipTransfer.pending_for_org()
    |> Repo.one()
    |> Repo.preload([:org, :from_user, :to_user])
  end

  @impl true
  def list_pending_transfers_for_user(user) do
    user
    |> OwnershipTransfer.pending_for_user()
    |> Repo.all()
    |> Repo.preload([:org, :from_user, :to_user])
  end

  @impl true
  def update_ownership_transfer_status(transfer, attrs) do
    case Repo.transaction_on_primary(fn ->
           transfer
           |> OwnershipTransfer.status_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, transfer}} -> {:ok, transfer}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  # Atomically flips org ownership to the new owner, promotes them to :admin
  # (idempotent — leaves an already-:admin role intact), and marks the transfer
  # :accepted. The previous owner KEEPS their membership + :admin role (Task #237
  # decision #2). All in one primary-DB transaction so a partial flip can't strand
  # an org. The Stripe email reconciliation runs separately in the caller (the new
  # owner's session) — never here — since the server cannot decrypt the email.
  @impl true
  def accept_ownership_transfer_record(%OwnershipTransfer{} = transfer, to_user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      Repo.transaction_on_primary(fn ->
        Ecto.Multi.new()
        |> Ecto.Multi.run(:org, fn repo, _ ->
          case repo.get(Org, transfer.org_id) do
            nil -> {:error, :org_not_found}
            %Org{} = org -> {:ok, org}
          end
        end)
        |> Ecto.Multi.run(:owner, fn repo, %{org: org} ->
          org
          |> Ecto.Changeset.change(created_by_id: to_user.id)
          |> repo.update()
        end)
        |> Ecto.Multi.run(:membership, fn repo, %{org: org} ->
          case repo.get_by(Membership, org_id: org.id, user_id: to_user.id) do
            nil ->
              {:error, :not_a_member}

            %Membership{role: :admin} = membership ->
              {:ok, membership}

            %Membership{} = membership ->
              membership
              |> Membership.update_changeset(%{role: :admin})
              |> repo.update()
          end
        end)
        |> Ecto.Multi.update(
          :transfer,
          OwnershipTransfer.status_changeset(transfer, %{status: :accepted, accepted_at: now})
        )
        |> Repo.transaction()
      end)

    case result do
      {:ok, {:ok, %{transfer: transfer, owner: org}}} -> {:ok, %{transfer | org: org}}
      {:ok, {:error, _step, reason, _changes}} -> {:error, reason}
      error -> error
    end
  end
end
