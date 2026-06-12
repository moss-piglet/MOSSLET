defmodule Mosslet.Orgs do
  @moduledoc """
  The Orgs context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Orgs.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Orgs.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """

  alias Mosslet.Platform
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs.{Org, Membership, Invitation, Guardianship}

  @membership_roles ~w(member admin)

  @family_owned_limit 1

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

    type = org_type(attrs)

    case check_create_org_limit(user, type) do
      :ok ->
        changeset =
          attrs
          |> Org.insert_changeset()
          |> Org.put_creator(user)

        adapter().create_org(user, changeset)

      {:error, _reason} = error ->
        error
    end
  end

  # Normalizes the requested org type from string/atom attrs (defaults to family,
  # matching the Org schema default).
  defp org_type(%{"type" => type}), do: cast_type(type)
  defp org_type(%{type: type}), do: cast_type(type)
  defp org_type(_), do: :family

  defp cast_type(type) when is_atom(type), do: type
  defp cast_type("business"), do: :business
  defp cast_type("family"), do: :family
  defp cast_type(_), do: :family

  @doc """
  Server-authoritative org-creation gate.

  * `:family` — a user may own at most #{@family_owned_limit} family org.
  * `:business` — the first owned business is free; creating an additional owned
    business is gated behind a paid entitlement: every business the user already
    owns must carry an active (non-canceled) paid subscription.

  Returns `:ok` when allowed, or `{:error, reason}` where `reason` is one of
  `:family_limit_reached`, `:business_entitlement_required`.
  """
  def check_create_org_limit(user, :family) do
    if count_owned_orgs(user, :family) >= @family_owned_limit do
      {:error, :family_limit_reached}
    else
      :ok
    end
  end

  def check_create_org_limit(user, :business) do
    cond do
      count_owned_orgs(user, :business) == 0 -> :ok
      all_owned_businesses_paid?(user) -> :ok
      true -> {:error, :business_entitlement_required}
    end
  end

  def check_create_org_limit(_user, _type), do: :ok

  @doc """
  Returns `true` when the user is allowed to create a new owned org of `type`.
  """
  def can_create_org?(user, type) do
    check_create_org_limit(user, type) == :ok
  end

  @doc """
  The hard limit on owned family orgs per user.
  """
  def family_owned_limit, do: @family_owned_limit

  @doc """
  Lists orgs OWNED by the user (i.e. `created_by_id == user.id`), optionally
  filtered by `type`.
  """
  def list_owned_orgs(user, type \\ nil) do
    adapter().list_owned_orgs(user, type)
  end

  @doc """
  Counts orgs owned by the user, optionally filtered by `type`.
  """
  def count_owned_orgs(user, type \\ nil) do
    adapter().count_owned_orgs(user, type)
  end

  @doc """
  Returns `true` when EVERY business org the user owns has an active
  (`active`/`trialing`) subscription. Used to gate creation of additional owned
  businesses (the first business is free; subsequent ones require the prior
  business(es) to be on a paid plan).
  """
  def all_owned_businesses_paid?(user) do
    case list_owned_orgs(user, :business) do
      [] -> true
      businesses -> Enum.all?(businesses, &org_has_active_subscription?/1)
    end
  end

  @doc """
  Returns `true` when the org's billing customer has an active subscription.
  """
  def org_has_active_subscription?(%Org{} = org) do
    case Customers.get_customer_by_source(:org, org.id) do
      nil -> false
      customer -> Subscriptions.get_active_subscription_by_customer_id(customer.id) != nil
    end
  end

  @doc """
  Returns `true` when `user` owns the given org (`created_by_id == user.id`).
  """
  def owner?(%Org{created_by_id: created_by_id}, user_id) when is_binary(user_id) do
    created_by_id == user_id
  end

  def owner?(_, _), do: false

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

  @doc """
  Returns the set of `user_id`s who are members of the given org.

  Server-authoritative eligibility helper used by the business-circle write path
  (see docs/BUSINESS_CIRCLES_DESIGN.md §6, I1) to ensure a circle's members may
  only be drawn from the org's membership.
  """
  def list_member_user_ids_by_org(%Org{} = org) do
    org
    |> list_members_by_org()
    |> Enum.map(& &1.id)
  end

  @doc """
  Returns `true` if the given `user_id` is a member of the given org.
  """
  def member_of_org?(%Org{} = org, user_id) when is_binary(user_id) do
    user_id in list_member_user_ids_by_org(org)
  end

  def member_of_org?(_, _), do: false

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
    case check_seat_capacity(org) do
      :ok -> adapter().create_invitation(org, params)
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Returns the seat capacity for an org.

  Source of truth: the purchased subscription `quantity` when the org's billing
  customer has an active subscription; otherwise the plan's configured
  `included_seats` floor (resolved by org type). Family/business included-seat
  floors come from config (`Plans`).
  """
  def seat_cap(%Org{} = org) do
    case org_active_subscription(org) do
      %{quantity: quantity} when is_integer(quantity) and quantity > 0 ->
        quantity

      _ ->
        included_seats_for_type(org.type)
    end
  end

  @doc """
  The number of seats currently consumed by an org.

  Effective usage = confirmed members + PENDING invitations (so seats can't be
  oversold before invitations are accepted).
  """
  def seat_usage(%Org{} = org) do
    count_members(org) + count_pending_invitations(org)
  end

  @doc """
  A map describing an org's seat usage: `%{used: integer, cap: integer,
  members: integer, pending: integer, available: integer}`.

  `available` is floored at 0. Used by dashboards + the invite UI.
  """
  def seat_summary(%Org{} = org) do
    members = count_members(org)
    pending = count_pending_invitations(org)
    cap = seat_cap(org)
    used = members + pending

    %{
      members: members,
      pending: pending,
      used: used,
      cap: cap,
      available: max(cap - used, 0)
    }
  end

  @doc """
  Server-authoritative seat-cap gate for adding a member to an org.

  Returns `:ok` when there is at least one available seat (cap minus confirmed
  members minus pending invitations), else `{:error, :seat_limit_reached}`.
  """
  def check_seat_capacity(%Org{} = org) do
    if seat_usage(org) < seat_cap(org) do
      :ok
    else
      {:error, :seat_limit_reached}
    end
  end

  defp org_active_subscription(%Org{} = org) do
    case Customers.get_customer_by_source(:org, org.id) do
      nil -> nil
      customer -> Subscriptions.get_active_subscription_by_customer_id(customer.id)
    end
  end

  defp included_seats_for_type(type) do
    case base_plan_for_type(type) do
      nil -> 1
      plan -> Plans.included_seats(plan)
    end
  end

  # The base monthly plan for an org type, used as the included-seats floor when
  # there is no active subscription yet.
  defp base_plan_for_type(:family), do: Plans.get_plan_by_id("family-monthly")
  defp base_plan_for_type(:business), do: Plans.get_plan_by_id("business-monthly")
  defp base_plan_for_type(_), do: nil

  defp count_members(%Org{} = org) do
    org |> list_members_by_org() |> length()
  end

  defp count_pending_invitations(%Org{} = org) do
    adapter().count_pending_invitations(org)
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

  ## Guardianships

  @doc """
  Establishes a guardianship link between a guardian membership and a managed
  member membership within the same family org.

  For of-age managed members (`requires_consent: true`) the link starts as
  `:pending` and only begins co-sealing after the managed member explicitly
  accepts. For minor/dependent accounts (`requires_consent: false`) the link may
  start `:active`.

  Options:

    * `:requires_consent` — boolean, defaults to `true`. When `false` the link
      starts `:active`.

  Co-sealing only ever happens for `:active` guardianships (the cryptographic
  consent gate).
  """
  def establish_guardianship(%Membership{} = guardian, %Membership{} = managed, opts \\ []) do
    adapter().establish_guardianship(guardian, managed, opts)
  end

  @doc """
  Of-age managed member accepts a pending guardianship → `:active`, sets
  `consented_at`. Co-sealing begins from this point forward.
  """
  def accept_guardianship(%Guardianship{} = guardianship) do
    adapter().accept_guardianship(guardianship)
  end

  @doc """
  Of-age managed member declines a pending guardianship → `:declined`. Nothing is
  ever co-sealed for a declined guardianship.
  """
  def decline_guardianship(%Guardianship{} = guardianship) do
    adapter().decline_guardianship(guardianship)
  end

  @doc """
  Pauses an active guardianship → `:paused`, sets `paused_at`. Stops FUTURE
  co-seals only; already-shared content stays shared (cannot un-ring the bell).
  Either the managed member or the guardian may pause.
  """
  def pause_guardianship(%Guardianship{} = guardianship) do
    adapter().pause_guardianship(guardianship)
  end

  @doc """
  Resumes a paused guardianship → `:active`. Only content created while active is
  ever co-sealed.
  """
  def resume_guardianship(%Guardianship{} = guardianship) do
    adapter().resume_guardianship(guardianship)
  end

  @doc """
  Revokes (deletes) a guardianship record. Stops future co-seals. Already-created
  `UserPost`/`UserConversation` rows for the guardian are NOT deleted (honesty
  about the past — see GUARDIANSHIP_DESIGN.md §7).
  """
  def revoke_guardianship(%Guardianship{} = guardianship) do
    adapter().revoke_guardianship(guardianship)
  end

  @doc """
  Returns the list of guardian `User` structs (with public keys + PQ public keys)
  who currently co-read the given managed member's content within the given org.

  Only `:active` guardianships are returned — this is the server-authoritative
  consent gate that the write path consumes. `nil`/empty when the user is not a
  managed member or has no active guardianships.

  Each user is a full `Mosslet.Accounts.User` struct so the write path can read
  `user.key_pair["public"]` and `user.pq_public_key` directly.
  """
  def list_active_guardians_for(%Org{} = org, managed_user_id) do
    adapter().list_active_guardians_for(org, managed_user_id)
  end

  @doc """
  Server-authoritative write-path helper.

  Given a managed member's `user_id`, returns the DISTINCT list of guardian
  `User` structs (with public keys + PQ public keys) across ALL family orgs where
  that user is a managed member with an **active** guardianship.

  This is what the post/conversation write paths consume to co-seal the context
  key for the guardian(s). Returns `[]` when the user is not a managed member or
  has no active guardianships. The guardian set is derived purely from
  `Guardianship` records — never from client params (I1).
  """
  def list_active_guardian_users_for_user(user_id) when is_binary(user_id) do
    adapter().list_active_guardian_users_for_user(user_id)
  end

  def list_active_guardian_users_for_user(_), do: []

  @doc """
  Returns all guardianships for an org, preloaded with guardian/managed
  memberships and their users (for dashboards/transparency panels).
  """
  def list_guardianships_by_org(%Org{} = org) do
    adapter().list_guardianships_by_org(org)
  end

  @doc """
  Returns guardianships where the given membership is the MANAGED member
  (the transparency-panel view for the managed member's own dashboard).
  """
  def list_guardianships_for_managed_membership(%Membership{} = membership) do
    adapter().list_guardianships_for_managed_membership(membership)
  end

  @doc """
  Returns guardianships where the given membership is the GUARDIAN
  (the guardian's "Family" reading surface).
  """
  def list_guardianships_for_guardian_membership(%Membership{} = membership) do
    adapter().list_guardianships_for_guardian_membership(membership)
  end

  def get_guardianship!(id) do
    adapter().get_guardianship!(id)
  end

  @doc """
  Given the full set of participant `user_id`s in a conversation, returns the
  list of MANAGED-MEMBER `user_id`s whose active guardian is ALSO a participant
  in this conversation.

  Used to render the mandatory I2b transparency banner: "[Managed member]'s
  guardian can read this conversation." Returns `[]` when no co-reading is
  happening. Server-authoritative.
  """
  def managed_members_with_coreading_guardians(participant_user_ids)
      when is_list(participant_user_ids) do
    participant_set = MapSet.new(participant_user_ids, &to_string/1)

    participant_user_ids
    |> Enum.filter(fn uid ->
      uid
      |> list_active_guardian_users_for_user()
      |> Enum.any?(fn guardian -> MapSet.member?(participant_set, to_string(guardian.id)) end)
    end)
    |> Enum.uniq()
  end
end
