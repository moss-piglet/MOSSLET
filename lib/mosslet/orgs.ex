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
  alias Mosslet.Billing.PaymentIntents
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

  ## PubSub
  #
  # Realtime org dashboard updates (Family/Business). Members of an org subscribe
  # to its topic and re-fetch when memberships, invitations, roles, or
  # guardianships change — keeping every connected admin/member in sync without a
  # manual refresh. ZK-safe: payloads carry only non-secret identifiers
  # (`org_id`); recipients re-fetch + decrypt locally, never trusting broadcast
  # contents for any sensitive data.

  @doc """
  Subscribe the calling process to realtime updates for `org` (membership,
  invitation, role, and guardianship changes). Call from a LiveView `mount/3`
  when `connected?/1`. Handle `{:org_updated, org_id}` in `handle_info/2`.
  """
  def subscribe_org(%Org{} = org), do: subscribe_org(org.id)

  def subscribe_org(org_id) when is_binary(org_id) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, org_topic(org_id))
  end

  @doc """
  Broadcasts an `{:org_updated, org_id}` event to all subscribers of the org.
  Idempotent and side-effect-light; safe to call after any org mutation.
  """
  def broadcast_org_update(%Org{} = org), do: broadcast_org_update(org.id)

  def broadcast_org_update(org_id) when is_binary(org_id) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, org_topic(org_id), {:org_updated, org_id})
  end

  def broadcast_org_update(_), do: :ok

  defp org_topic(org_id), do: "org:#{org_id}"

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

    cond do
      not user_has_active_billing?(user) ->
        {:error, :subscription_required}

      true ->
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
  end

  @doc """
  Returns `true` when the user has finalized their own subscription signup —
  i.e. their personal billing account has an active/trialing subscription or an
  active lifetime payment intent.

  Creating a family/business org requires this (Task #215 follow-up): a user must
  commit to a paid (or trialing) relationship before spinning up org
  infrastructure, even though the org itself is billed per-seat afterward.
  """
  def user_has_active_billing?(user) do
    case Customers.get_customer_by_source(:user, user.id) do
      nil ->
        false

      customer ->
        Subscriptions.get_active_subscription_by_customer_id(customer.id) != nil or
          PaymentIntents.get_active_payment_intent_by_customer_id(customer.id) != nil
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

  Auto-accept (Task #223, decision #4): for a **confirmed** user, any pending
  invitation whose `sent_to_hash` matches the now-confirmed email is accepted
  automatically, so an invited Family/Business member lands in the org with zero
  extra clicks. This is gated on `user.confirmed_at` on purpose — the
  confirmation-email click is the proof the registrant controls the invited
  inbox. We NEVER auto-accept (or auto-confirm) before that proof, since the
  invite link is a signed, forwardable token that does not by itself establish
  inbox ownership.
  """
  def sync_user_invitations(user) do
    result = adapter().sync_user_invitations(user)
    maybe_auto_accept_invitations(user)
    result
  end

  # Confirmed users only. Best-effort: a seat-cap refusal or any single failure
  # must not break confirmation/sign-in, so we accept what we can and move on.
  # The user can still accept manually from /invite/:token if anything is skipped.
  #
  # We match pending invitations by the user's (loaded) `email_hash` directly,
  # NOT via `list_invitations_by_user/1`. The legacy `user_id`-linking path
  # (`Invitation.assign_to_user_by_email/1`) compares an already-hashed value in
  # SQL, which Cloak re-hashes on dump and so never matches a confirmed user's
  # loaded `email_hash` — see `list_pending_invitations_by_email_hash/1`.
  defp maybe_auto_accept_invitations(%{confirmed_at: nil}), do: :ok

  defp maybe_auto_accept_invitations(user) do
    user.email_hash
    |> list_pending_invitations_by_email_hash()
    |> Enum.each(fn invitation ->
      try do
        accept_invitation_record(user, invitation)
      rescue
        _ -> :ok
      end
    end)
  end

  # Accepts a specific (already hash-matched) pending invitation for a confirmed
  # user, with the same seat-neutral defensive re-check as `accept_invitation/2`.
  defp accept_invitation_record(user, %Invitation{} = invitation) do
    org =
      case invitation do
        %Invitation{org: %Org{} = org} -> org
        %Invitation{org_id: org_id} -> get_org_by_id(org_id)
      end

    cond do
      is_nil(org) ->
        {:error, :org_not_found}

      member_of_org?(org, user.id) ->
        # Already a member (e.g. raced with another accept) — drop the stale invite.
        delete_invitation!(invitation)
        broadcast_org_update(org.id)
        {:ok, :already_member}

      count_members(org) >= seat_cap(org) ->
        {:error, :seat_limit_reached}

      true ->
        membership = adapter().accept_invitation_record!(user, invitation)
        broadcast_org_update(org.id)
        {:ok, membership}
    end
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
    result = adapter().delete_membership(membership)

    case result do
      {:ok, deleted} -> broadcast_org_update(deleted.org_id)
      _ -> :ok
    end

    result
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
    result = adapter().update_membership(membership, attrs)

    case result do
      {:ok, updated} -> broadcast_org_update(updated.org_id)
      _ -> :ok
    end

    result
  end

  ## Invitations - org based

  def get_invitation_by_org!(org, id) do
    adapter().get_invitation_by_org!(org, id)
  end

  @doc """
  Non-raising fetch of a pending invitation scoped to the given org. Returns the
  `Invitation` (with `:org` preloaded) or `nil` when it no longer exists or
  belongs to a different org. Use this on dashboards where the displayed list may
  be stale (invitations are deleted on accept/reject/auto-accept).
  """
  def get_invitation_for_org(%Org{} = org, id) do
    case get_invitation_with_org(id) do
      %Invitation{org_id: org_id} = invitation when org_id == org.id -> invitation
      _ -> nil
    end
  end

  @doc """
  Idempotently revokes (deletes) a pending invitation for the given org.

  Returns `:ok` whether or not the invitation still exists. Pending invitations
  are deleted on accept/reject and on auto-accept (Task #223), so a stale
  dashboard may try to revoke a row that's already gone — that's a no-op here, no
  crash. Only deletes the invitation when it belongs to the given org.
  """
  def revoke_invitation(%Org{} = org, id) do
    case get_invitation_with_org(id) do
      %Invitation{org_id: org_id} = invitation when org_id == org.id ->
        delete_invitation!(invitation)
        broadcast_org_update(org.id)
        :ok

      _ ->
        :ok
    end
  end

  def delete_invitation!(invitation) do
    adapter().delete_invitation!(invitation)
  end

  def build_invitation(%Org{} = org, params) do
    Invitation.changeset(%Invitation{org_id: org.id}, params)
  end

  def create_invitation(org, params) do
    case check_seat_capacity(org) do
      :ok ->
        case adapter().create_invitation(org, params) do
          {:ok, _invitation} = ok ->
            broadcast_org_update(org.id)
            ok

          {:error, _reason} = error ->
            error
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Sends (or re-sends) the invitation email for a pending invitation.

  Returns `{:ok, email}` on success or `{:error, reason}` if delivery failed.
  Per decision (a), callers treat a delivery failure as non-fatal: the
  invitation row is the source of truth (the recipient can always accept from
  their invitations page, and an admin can resend), so we never roll back the
  invitation on a mail error — we just surface an honest flash.

  ZK-safe: the email carries only the org name + a public, signed invite link,
  never any key material or secrets.
  """
  def deliver_invitation_email(%Invitation{} = invitation, %Org{} = org) do
    token = sign_invite_token(invitation)
    url = MossletWeb.Endpoint.url() <> "/invite/" <> token
    Mosslet.Accounts.UserNotifier.deliver_org_invitation(invitation.sent_to, org, invitation, url)
  end

  # Salt for the public invite landing link token. The token is a signed
  # (NOT encrypted) wrapper of the invitation id — it carries no secret material,
  # it only prevents a guessed/edited invitation id from surfacing another org's
  # name on the public landing page.
  @invite_token_salt "org invitation link"

  # Public invite links expire after 7 days. The invitation ROW never expires
  # (pending = row exists, deleted on accept/reject); only the emailed link does.
  # An org admin can always resend to mint a fresh 7-day link.
  @invite_token_max_age_seconds 7 * 24 * 60 * 60

  @doc """
  The lifetime (in seconds) of a signed public invite link. After this the
  emailed link no longer resolves and the admin must resend.
  """
  def invite_token_max_age_seconds, do: @invite_token_max_age_seconds

  @doc """
  Signs a public, non-enumerable invite token for the given invitation.

  Uses `Phoenix.Token` (HMAC-signed, not encrypted) wrapping only the invitation
  id. ZK-safe: no secret/PII is placed in the token or the URL.
  """
  def sign_invite_token(%Invitation{id: id}) do
    Phoenix.Token.sign(MossletWeb.Endpoint, @invite_token_salt, id)
  end

  @doc """
  Verifies a public invite token and loads the associated invitation (with `:org`
  preloaded).

  Returns:

    * `{:ok, invitation}` — token valid, signed within the last 7 days, and the
      invitation row still exists (pending).
    * `{:error, :expired}` — the signed link is older than 7 days (admin can
      resend a fresh link).
    * `{:error, :invalid}` — malformed/tampered token, or the invitation row no
      longer exists (already accepted/rejected/revoked).
  """
  def verify_invite_token(token) when is_binary(token) do
    case Phoenix.Token.verify(MossletWeb.Endpoint, @invite_token_salt, token,
           max_age: @invite_token_max_age_seconds
         ) do
      {:ok, invitation_id} ->
        case get_invitation_with_org(invitation_id) do
          %Invitation{} = invitation -> {:ok, invitation}
          nil -> {:error, :invalid}
        end

      {:error, :expired} ->
        {:error, :expired}

      {:error, _reason} ->
        {:error, :invalid}
    end
  end

  def verify_invite_token(_), do: {:error, :invalid}

  @doc """
  Returns `true` when the public invite link minted for this invitation has
  expired (older than 7 days). Used by the admin pending-invitations panel to
  flag invites whose emailed link can no longer be opened, prompting a resend.

  The age is measured from `updated_at` (resending bumps it), falling back to
  `inserted_at`.
  """
  def invite_link_expired?(%Invitation{} = invitation) do
    sent_at = invitation.updated_at || invitation.inserted_at

    case sent_at do
      nil ->
        false

      %NaiveDateTime{} = dt ->
        NaiveDateTime.diff(NaiveDateTime.utc_now(), dt, :second) > @invite_token_max_age_seconds
    end
  end

  defp get_invitation_with_org(invitation_id) do
    adapter().get_invitation_with_org(invitation_id)
  end

  @doc """
  Re-sends the invitation email for an existing pending invitation. Resolves the
  org from the invitation if not preloaded. See `deliver_invitation_email/2`.
  """
  def resend_invitation(%Invitation{} = invitation) do
    org =
      case invitation.org do
        %Org{} = org -> org
        _ -> get_org_by_id(invitation.org_id)
      end

    deliver_invitation_email(invitation, org)
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

  ## Org-seat coverage (personal-paywall bridge)
  #
  # Global billing is per-`:user`, but Family/Business members occupy a seat the
  # ORG already pays for. These helpers are the server-authoritative bridge that
  # lets the personal paywall (see `MossletWeb.SubscriptionPlugs`) recognize a
  # user as "covered by an org seat" so they are NOT charged for a personal
  # account. Coverage is derived purely from confirmed membership rows (deleted
  # immediately on seat revocation — `delete_membership/1`) and the org's
  # subscription status (resolved from the owner's seat-based plan; see
  # `org_subscription/1`). Never client-trusted.

  @doc """
  Returns `true` when the user is covered by an org seat with access — i.e.
  `org_coverage_status/1` is `:covered` (active/trialing org sub) or
  `{:grace, _org}` (org sub `past_due`, the grace window).

  This is the single boolean the paywall gates consult to exempt org-covered
  members. A lapsed (`unpaid`/`canceled`/no sub) org, or no membership at all,
  returns `false`.
  """
  def covered_by_org_seat?(user) do
    case org_coverage_status(user) do
      :covered -> true
      {:grace, _org} -> true
      _ -> false
    end
  end

  @doc """
  Server-authoritative coverage status for a user across ALL their confirmed org
  memberships. A user is covered if ANY org grants coverage; the best status
  across orgs wins.

  Returns:

    * `:covered` — at least one org has an `active`/`trialing` subscription.
    * `{:grace, org}` — no fully-active org, but at least one org's subscription
      is `past_due` (Stripe's retry/grace window). Access is still granted; the
      UI should surface a friendly "your org's plan is overdue → contact your
      admin" notice (loss-of-coverage state B).
    * `{:lapsed, org}` — the user has org membership(s) but every org's
      subscription has fully lapsed (`unpaid`/`canceled`/`expired`/missing).
      Access via org coverage is denied (state B, hardened).
    * `:none` — the user has no confirmed org membership at all (state A).

  Seat validity is implicit: a revoked seat deletes the membership row, so a
  removed member with no other orgs resolves to `:none` (state A) immediately.
  """
  def org_coverage_status(user) do
    case list_orgs(user) do
      [] ->
        :none

      orgs ->
        orgs
        |> Enum.map(&org_coverage_for_org/1)
        |> reduce_coverage()
    end
  end

  # Per-org coverage from the org's subscription status.
  defp org_coverage_for_org(%Org{} = org) do
    case org_subscription(org) do
      %{status: status} when status in ["active", "trialing"] -> :covered
      %{status: "past_due"} -> {:grace, org}
      _ -> {:lapsed, org}
    end
  end

  # Resolves the subscription that pays for an org's seats.
  #
  # Billing model (verified): Family/Business plans are purchased on the org
  # OWNER's personal (`:user`-source) customer — there is currently no
  # `:org`-source subscription. So we resolve coverage from the owner's seat-based
  # subscription whose plan TYPE matches the org (family/business). We still check
  # an `:org`-source subscription first for forward-compatibility, should billing
  # move onto the org customer later.
  #
  # Returns the active/trialing sub when present, else a payment-required
  # (`past_due`/`incomplete`) sub so the caller can surface the grace state.
  defp org_subscription(%Org{} = org) do
    org_source_subscription(org) || owner_org_subscription(org)
  end

  defp org_source_subscription(%Org{} = org) do
    case Customers.get_customer_by_source(:org, org.id) do
      nil ->
        nil

      customer ->
        Subscriptions.get_active_subscription_by_customer_id(customer.id) ||
          Subscriptions.get_payment_required_subscription_by_customer_id(customer.id)
    end
  end

  defp owner_org_subscription(%Org{created_by_id: nil}), do: nil

  defp owner_org_subscription(%Org{created_by_id: owner_id} = org) do
    case Customers.get_customer_by_source(:user, owner_id) do
      nil ->
        nil

      customer ->
        sub =
          Subscriptions.get_active_subscription_by_customer_id(customer.id) ||
            Subscriptions.get_payment_required_subscription_by_customer_id(customer.id)

        if sub && org_plan_matches_type?(sub.plan_id, org.type), do: sub
    end
  end

  # True when the subscription's plan is the seat-based org plan for the org type
  # (e.g. "business-monthly"/"business-yearly" for a :business org). Guards against
  # treating an owner's unrelated personal plan as org coverage.
  defp org_plan_matches_type?(plan_id, type) when is_binary(plan_id) do
    plan = Plans.get_plan_by_id(plan_id)
    plan && Plans.seat_based_plan?(plan) && String.starts_with?(plan_id, "#{type}-")
  end

  defp org_plan_matches_type?(_plan_id, _type), do: false

  # Best-status-wins reduction across a user's orgs:
  # :covered > {:grace, _} > {:lapsed, _}. (`:none` handled by the caller.)
  defp reduce_coverage(statuses) do
    cond do
      Enum.any?(statuses, &(&1 == :covered)) ->
        :covered

      grace = Enum.find(statuses, &match?({:grace, _}, &1)) ->
        grace

      lapsed = Enum.find(statuses, &match?({:lapsed, _}, &1)) ->
        lapsed

      true ->
        :none
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

  @doc """
  Lists all pending invitations for an org (most recent first), with `:org`
  preloaded. A row exists only while pending (it is deleted on accept/reject),
  so this is the pending list. Used by the Family/Business dashboards to show
  outstanding invites with revoke/resend actions.
  """
  def list_invitations_by_org(%Org{} = org) do
    adapter().list_invitations_by_org(org)
  end

  ## Invitations - user based

  def list_invitations_by_user(user) do
    adapter().list_invitations_by_user(user)
  end

  @doc """
  Returns pending invitations addressed to the given `email_hash`, regardless of
  whether they've been linked to a user yet (`user_id` is only set after email
  confirmation — see `Invitation.put_user_id/1`). Used by the onboarding router
  (Task #223) to recognize an invited Family/Business member BEFORE confirmation
  so we don't wrongly funnel them to the personal `/app/subscribe` paywall. Each
  invitation has its `:org` preloaded.
  """
  def list_pending_invitations_by_email_hash(email_hash) do
    adapter().list_pending_invitations_by_email_hash(email_hash)
  end

  @doc """
  Accepts a pending invitation, creating the membership and deleting the
  invitation atomically (the adapter runs both in one transaction, so seat usage
  — members + pending — nets to zero on a normal accept).

  Defensive seat re-check (Task #223, decision #2): seats are reserved at invite
  time (`create_invitation/2` → `check_seat_capacity/1`, and `seat_usage/1`
  counts pending invitations), so the org should never be oversold while invites
  are outstanding. We still re-verify here so a race or upstream bug can't push
  confirmed membership past the cap: if the org has no room for this member
  (counting members only, since this person's pending seat is being converted),
  we refuse with `{:error, :seat_limit_reached}` instead of silently overselling.
  """
  def accept_invitation!(user, id) do
    case accept_invitation(user, id) do
      {:ok, membership} -> membership
      {:error, reason} -> raise "could not accept invitation: #{inspect(reason)}"
    end
  end

  @doc """
  Non-raising variant of `accept_invitation!/2`. Returns `{:ok, membership}` or
  `{:error, :seat_limit_reached}` (defensive seat re-check, decision #2).
  """
  def accept_invitation(user, id) do
    org =
      case get_invitation_with_org(id) do
        %Invitation{org: %Org{} = org} -> org
        _ -> nil
      end

    # Converting a pending invite to a membership is seat-neutral; the only way
    # this fails is if confirmed members ALONE already meet/exceed the cap, which
    # would indicate seats were oversold upstream. Guard against it.
    if org && count_members(org) >= seat_cap(org) do
      {:error, :seat_limit_reached}
    else
      membership = adapter().accept_invitation!(user, id)
      if org, do: broadcast_org_update(org.id)
      {:ok, membership}
    end
  end

  def reject_invitation!(user, id) do
    result = adapter().reject_invitation!(user, id)
    broadcast_org_update_from_invitation(result)
    result
  end

  defp broadcast_org_update_from_invitation(%Invitation{org_id: org_id}) when is_binary(org_id),
    do: broadcast_org_update(org_id)

  defp broadcast_org_update_from_invitation(_), do: :ok

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
    guardian
    |> adapter().establish_guardianship(managed, opts)
    |> broadcast_guardianship_result()
  end

  @doc """
  Of-age managed member accepts a pending guardianship → `:active`, sets
  `consented_at`. Co-sealing begins from this point forward.
  """
  def accept_guardianship(%Guardianship{} = guardianship) do
    guardianship
    |> adapter().accept_guardianship()
    |> broadcast_guardianship_result()
  end

  @doc """
  Of-age managed member declines a pending guardianship → `:declined`. Nothing is
  ever co-sealed for a declined guardianship.
  """
  def decline_guardianship(%Guardianship{} = guardianship) do
    guardianship
    |> adapter().decline_guardianship()
    |> broadcast_guardianship_result()
  end

  @doc """
  Pauses an active guardianship → `:paused`, sets `paused_at`. Stops FUTURE
  co-seals only; already-shared content stays shared (cannot un-ring the bell).
  Either the managed member or the guardian may pause.
  """
  def pause_guardianship(%Guardianship{} = guardianship) do
    guardianship
    |> adapter().pause_guardianship()
    |> broadcast_guardianship_result()
  end

  @doc """
  Resumes a paused guardianship → `:active`. Only content created while active is
  ever co-sealed.
  """
  def resume_guardianship(%Guardianship{} = guardianship) do
    guardianship
    |> adapter().resume_guardianship()
    |> broadcast_guardianship_result()
  end

  @doc """
  Revokes (deletes) a guardianship record. Stops future co-seals. Already-created
  `UserPost`/`UserConversation` rows for the guardian are NOT deleted (honesty
  about the past — see GUARDIANSHIP_DESIGN.md §7).
  """
  def revoke_guardianship(%Guardianship{} = guardianship) do
    guardianship
    |> adapter().revoke_guardianship()
    |> broadcast_guardianship_result()
  end

  # Broadcasts an org update when a guardianship mutation succeeds, so the family
  # dashboard reflects the change in realtime. Returns the result unchanged.
  defp broadcast_guardianship_result({:ok, %Guardianship{org_id: org_id}} = result)
       when is_binary(org_id) do
    broadcast_org_update(org_id)
    result
  end

  defp broadcast_guardianship_result(result), do: result

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
