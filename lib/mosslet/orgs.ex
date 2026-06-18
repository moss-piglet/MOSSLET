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
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs.{Org, Membership, Invitation, Guardianship, OwnershipTransfer}

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

  @doc """
  Lists all orgs with their billing customer + subscriptions preloaded. Used by
  the name-reclaim sweep (Task #236) to classify orgs without N+1 queries.
  """
  def list_orgs_with_billing do
    adapter().list_orgs_with_billing()
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

  @doc """
  Non-raising slug lookup. Returns the org or `nil`. Use this (over `get_org!/1`)
  when the slug may not resolve and you want to pattern match rather than rescue.
  """
  def get_org_by_slug(slug) when is_binary(slug) do
    adapter().get_org_by_slug(slug)
  end

  @doc """
  Non-raising subdomain lookup (Task #240, Phase B). Returns the org or `nil`.

  Mirrors `get_org_by_slug/1` — used by the subdomain-aware host plug to resolve
  `acmebiz.mosslet.com` -> that org. The subdomain hostname label is
  non-sensitive plaintext, so this is a plain (case-insensitive `:citext`)
  lookup. Authorization (membership) and the add-on entitlement are enforced by
  the caller; resolving an org here does NOT grant access.
  """
  def get_org_by_subdomain(subdomain) when is_binary(subdomain) do
    adapter().get_org_by_subdomain(subdomain)
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

  @doc """
  Returns `true` when the user has finalized their own PERSONAL subscription
  signup — i.e. their personal (`:user`-source) billing account has an
  active/trialing subscription or an active lifetime payment intent.

  This reflects ONLY the person's personal Mosslet plan. It is fully independent
  of org billing: it does NOT gate org creation, and owning an org does not make
  this true. (Org coverage is resolved separately from the org's own
  `:org`-source subscription — see `org_subscription/1`.)
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

  * `:family` — a user may own at most #{@family_owned_limit} family org. A user
    who is only an invited member-seat of a family (owns none) does NOT get a
    free family — they must pay to start their own.
  * `:business` — the first owned business is free; creating an additional owned
    business is gated behind a paid entitlement: every business the user already
    owns must carry an active (non-canceled) paid subscription. A user who is
    only an invited member-seat of a business (owns none) does NOT get a free
    business — they must pay to start a separate one.

  Returns `:ok` when allowed, or `{:error, reason}` where `reason` is one of
  `:family_limit_reached`, `:family_entitlement_required`,
  `:business_entitlement_required`.
  """
  def check_create_org_limit(user, :family) do
    cond do
      count_owned_orgs(user, :family) >= @family_owned_limit ->
        {:error, :family_limit_reached}

      # An invited family member-seat (owns no family) must pay to start a
      # separate one — they don't get the free first family.
      count_member_orgs(user, :family) > 0 ->
        {:error, :family_entitlement_required}

      true ->
        :ok
    end
  end

  def check_create_org_limit(user, :business) do
    cond do
      # Genuinely new owner with no seat anywhere: first business is free.
      count_owned_orgs(user, :business) == 0 and count_member_orgs(user, :business) == 0 ->
        :ok

      # Owns at least one business: extra businesses require existing ones paid.
      count_owned_orgs(user, :business) > 0 and all_owned_businesses_paid?(user) ->
        :ok

      # Either an invited member-seat with no owned business, or an owner whose
      # existing businesses aren't all paid — must pay to create another.
      true ->
        {:error, :business_entitlement_required}
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
  Counts orgs the user belongs to as an invited member-seat — i.e. orgs where a
  membership exists but the user is NOT the owner (`created_by_id != user.id`),
  optionally filtered by `type`.

  Used to gate org creation: an invited member-seat (who occupies a seat the org
  already pays for) must not get a free org of that type — they may start a
  separate one only by paying for it.
  """
  def count_member_orgs(user, type \\ nil) do
    adapter().count_member_orgs(user, type)
  end

  @doc """
  Returns `true` when EVERY business org the user owns is on a genuinely PAID
  plan (an `active`, non-trialing `:org` subscription).

  Used to gate creation of ADDITIONAL owned businesses: the first business is
  free, but spinning up another requires the prior business(es) to be actually
  paying — a business still on its free trial does NOT yet unlock a second one
  (the trial must convert, or the owner can start the paid plan early). See
  Task #214/#218.
  """
  def all_owned_businesses_paid?(user) do
    case list_owned_orgs(user, :business) do
      [] -> true
      businesses -> Enum.all?(businesses, &org_has_paid_subscription?/1)
    end
  end

  @doc """
  Returns `true` when the org's billing customer has a PAID (`active`,
  non-trialing) subscription. A business on a free trial returns `false` here —
  use `org_active?/1` when a trial should count (coverage/access).
  """
  def org_has_paid_subscription?(%Org{} = org) do
    case Customers.get_customer_by_source(:org, org.id) do
      nil -> false
      customer -> Subscriptions.get_paid_subscription_by_customer_id(customer.id) != nil
    end
  end

  @doc """
  Returns `true` when `user` owns the given org (`created_by_id == user.id`).
  """
  def owner?(%Org{created_by_id: created_by_id}, user_id) when is_binary(user_id) do
    created_by_id == user_id
  end

  def owner?(_, _), do: false

  @doc """
  Returns `true` when the given membership may manage the org's branding
  (Task #228) — i.e. an org admin. Owners who are not admins, members,
  guardians, and managed members cannot upload or remove the brand logo.

  Gating is purely by membership role; it does NOT check the billing add-on
  entitlement (that gate is layered separately in the UI, trial-aware via
  `org_coverage_status/1`).
  """
  def can_manage_branding?(%Org{} = _org, %Membership{role: :admin}), do: true
  def can_manage_branding?(_, _), do: false

  @doc """
  Returns `true` when `user_id` may manage the org's BILLING-affecting settings —
  the paid custom-subdomain add-on (Task #240) and seat count. These mutate the
  org's paid subscription, so they are gated to the OWNER (the org's billing
  anchor, `created_by_id`) ONLY — stricter than `can_manage_branding?/2` (any
  admin, free logo). A non-owner admin can manage the free logo but never the
  subscription.
  """
  def can_manage_billing?(%Org{} = org, user_id) when is_binary(user_id), do: owner?(org, user_id)
  def can_manage_billing?(_, _), do: false

  @doc """
  Returns `true` when the org carries the paid custom-subdomain branding add-on
  (Task #240, Phase B). Server-authoritative: read from the org's own
  (`:org`-source) subscription line items (`provider_subscription_items`), never
  client-trusted.

  This gates ONLY the custom subdomain — claiming/managing one in the UI AND
  serving the org on its branded host (`acmebiz.mosslet.com`). The brand LOGO is
  NOT gated here; it stays free for every Business org (role-gated only via
  `can_manage_branding?/2`).

  Lapse behavior: the entitlement is true only while the org's subscription is in
  a covered state (active / trialing / `past_due` grace) AND still carries the
  add-on line item. When the add-on (or the whole org plan) lapses, this flips to
  `false` and the org stops being served on its subdomain — but the `subdomain`
  row is intentionally kept (reserved for the org), so re-adding the add-on
  restores serving without re-claiming. Re-checked per mount.
  """
  def has_branding_addon?(%Org{} = org) do
    case org_source_subscription(org) do
      %{status: status, provider_subscription_items: items}
      when status in ["active", "trialing", "past_due"] and is_list(items) ->
        addon_price_ids = MapSet.new(Plans.subdomain_addon_price_ids())
        Enum.any?(items, &subdomain_addon_item?(&1, addon_price_ids))

      _ ->
        false
    end
  end

  def has_branding_addon?(_), do: false

  # An org's subscription line item whose price matches a configured subdomain
  # add-on price. `provider_subscription_items` is an `Encrypted.MapList`, which
  # round-trips through `Jason` on read (`after_decrypt/1`), so the maps are
  # always STRING-keyed here — no atom-key fallback needed.
  defp subdomain_addon_item?(%{"price_id" => price_id}, addon_price_ids)
       when is_binary(price_id) do
    MapSet.member?(addon_price_ids, price_id)
  end

  defp subdomain_addon_item?(_item, _addon_price_ids), do: false

  @doc """
  Returns `true` when the org should be SERVED on its custom subdomain (Task
  #240, Phase B) — i.e. it has claimed a `subdomain` AND currently carries the
  paid add-on entitlement (`has_branding_addon?/1`).

  The subdomain host plug (`MossletWeb.Plugs.OrgSubdomain`) resolves the org from
  the host regardless, but downstream surfaces must consult this before treating
  the org as "live" on that host: an org whose add-on has lapsed keeps its
  reserved `subdomain` row but is no longer served there.
  """
  def subdomain_live?(%Org{subdomain: subdomain} = org) when is_binary(subdomain) do
    has_branding_addon?(org)
  end

  def subdomain_live?(_), do: false

  @doc """
  The absolute base URL for an org's surfaces (Task #246 entry-point UX).

  When the org's custom-subdomain add-on is live (`subdomain_live?/1`), returns
  the branded host (e.g. `https://acmebiz.mosslet.com`); otherwise returns the
  canonical apex (`MossletWeb.Endpoint.url/0`).

  The scheme and port are inherited from the endpoint URL (so dev correctly
  yields `http://acmebiz.localhost:4000`), and we simply prepend the subdomain
  label to the canonical host. Never includes a trailing slash.

  Use this anywhere we mint an ABSOLUTE, cross-host link we want a member to land
  on (e.g. invitation emails) so their session is established single-origin on
  the branded host. In-app navigation stays path-only (`~p`) per the leave-as-is
  routing decision; this helper is only for the few intentional cross-host links.
  """
  def org_base_url(%Org{} = org) do
    apex = MossletWeb.Endpoint.url()

    if subdomain_live?(org) do
      uri = URI.parse(apex)
      URI.to_string(%{uri | host: "#{org.subdomain}.#{uri.host}"})
    else
      apex
    end
  end

  def org_base_url(_), do: MossletWeb.Endpoint.url()

  @doc """
  Lists the orgs a user belongs to whose custom subdomain is currently live
  (`subdomain_live?/1`) — used to surface the "switch to your branded space"
  hint on apex (Task #246). Returns `[]` for a nil user.
  """
  def list_branded_orgs_for_user(nil), do: []

  def list_branded_orgs_for_user(user) do
    user
    |> list_orgs()
    |> Enum.filter(&subdomain_live?/1)
  end

  @doc """
  One-click purchase of the paid custom-subdomain add-on for an ALREADY-ACTIVE
  org (Task #240 / #243, Phase B). Appends the interval-matched add-on line item
  to the org's existing `:org`-source subscription via the billing provider —
  NOT a new Checkout Session (that path refuses to start while an active sub
  exists) and NOT a plan swap (the Billing Portal flow replaces items).

  The caller MUST enforce the role gate (`can_manage_branding?/2`, admins-only)
  first; this function additionally verifies, server-side, that:

    * the org has an active/trialing/grace `:org` subscription to add onto;
    * that subscription's plan offers the add-on (Business, interval-matched);
    * the add-on isn't ALREADY present (idempotent — never double-charge).

  On success the updated subscription is synced locally (so `has_branding_addon?/1`
  flips `true` immediately) and an org update is broadcast. Returns
  `{:ok, :added}`, `{:ok, :already_active}`, or `{:error, reason}`.
  """
  def add_subdomain_addon(%Org{} = org) do
    cond do
      has_branding_addon?(org) ->
        {:ok, :already_active}

      true ->
        with %{} = subscription <- org_source_subscription(org),
             plan when not is_nil(plan) <- Plans.get_plan_by_id(subscription.plan_id),
             price_id when is_binary(price_id) <- Plans.subdomain_addon_price(plan) do
          case billing_provider().add_subscription_item(subscription, price_id) do
            {:ok, _stripe_subscription} ->
              broadcast_org_update(org.id)
              {:ok, :added}

            {:error, reason} ->
              {:error, reason}
          end
        else
          _ -> {:error, :addon_unavailable}
        end
    end
  end

  @doc """
  One-click owner-only seat update for an ALREADY-ACTIVE org (Task #247, Phase
  B). Adjusts the seat ADD-ON line item's quantity on the org's existing
  `:org`-source subscription via the billing provider — NOT a new Checkout
  Session and NOT a plan swap (mirrors `add_subdomain_addon/1`).

  `requested_seats` is the desired TOTAL seat count (members + room to grow); it
  is clamped to the plan's `[included_seats, max_seats]` range. The caller MUST
  enforce the owner gate (`can_manage_billing?/2`) first; this function
  additionally verifies server-side that:

    * the org has an active/trialing/grace `:org` subscription on a per-seat plan
      (else `{:error, :seats_unavailable}`);
    * the clamped target is not below current usage — confirmed members + pending
      invitations (else `{:error, :below_current_usage}`, so seats can never be
      dropped out from under filled/pending seats).

  When the target equals the current cap nothing is charged (`{:ok, target}` with
  no provider call). Otherwise the seat add-on quantity is set to
  `target - included_seats`; on success the updated subscription is synced
  locally (so `seat_cap/1` reflects the new quantity immediately) and an org
  update is broadcast. Returns `{:ok, target}` or `{:error, reason}`.
  """
  def set_org_seats(%Org{} = org, requested_seats) do
    with %{} = subscription <- org_source_subscription(org),
         plan when not is_nil(plan) <- Plans.get_plan_by_id(subscription.plan_id),
         true <- Plans.seat_based_plan?(plan) do
      target = Plans.clamp_seats(plan, requested_seats)

      cond do
        target < seat_usage(org) ->
          {:error, :below_current_usage}

        target == seat_cap(org) ->
          {:ok, target}

        true ->
          extra_seats = target - Plans.included_seats(plan)

          case billing_provider().set_seat_quantity(
                 subscription,
                 plan.seat_addon_price,
                 extra_seats
               ) do
            {:ok, _stripe_subscription} ->
              broadcast_org_update(org.id)
              {:ok, target}

            {:error, reason} ->
              {:error, reason}
          end
      end
    else
      _ -> {:error, :seats_unavailable}
    end
  end

  @doc """
  Owner-facing seat-management bounds for the org's active per-seat plan, or
  `nil` when the org has no seat-based `:org` subscription (Task #247).

  Returns `%{cap, used, min, max}` where `min` is floored at current usage
  (members + pending) so the in-app stepper can never request fewer seats than
  are filled/pending, and `max` is the plan's configured ceiling (`:infinity`
  when uncapped). Drives the owner-only add-seats stepper UI; the actual write
  re-clamps + re-guards server-side via `set_org_seats/2`.
  """
  def seat_management_data(%Org{} = org) do
    with %{plan_id: plan_id} <- org_source_subscription(org),
         plan when not is_nil(plan) <- Plans.get_plan_by_id(plan_id),
         true <- Plans.seat_based_plan?(plan) do
      summary = seat_summary(org)

      %{
        cap: summary.cap,
        used: summary.used,
        min: max(summary.used, Plans.included_seats(plan)),
        max: Plans.max_seats(plan)
      }
    else
      _ -> nil
    end
  end

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  ## Ownership transfer handshake (Task #237, Option C)
  #
  # Ownership of an org is `Org.created_by_id`. Transferring it is a two-step
  # request -> accept handshake so the ZK-safe Stripe email sync can run in the
  # NEW owner's authenticated session (where their `session_key` exists), and so
  # nobody has org billing/ownership forced onto them without consent.
  #
  # Both parties re-authenticate with their password at their step (initiate /
  # accept) — high-friction, mirroring #227. The previous owner KEEPS their
  # membership + :admin role (decision #2); the new owner is auto-promoted to
  # :admin on accept (decision #1). No crypto re-seal is needed: the target is
  # already a confirmed member and already holds the sealed `org_key` (#225).
  #
  # ZK-safe: transfer rows carry only ids + status + timestamps; the only
  # plaintext touched (the new owner's email, for Stripe) lives in-session and is
  # never logged, persisted here, or placed in Stripe metadata.

  @doc """
  Returns the pending ownership transfer for `org`, or `nil`. Preloaded with
  `:org`, `:from_user`, `:to_user`.
  """
  def get_pending_transfer_for_org(%Org{} = org) do
    adapter().get_pending_transfer_for_org(org)
  end

  @doc """
  Returns the pending ownership transfers proposed TO `user` (i.e. transfers the
  user can accept/decline), most recent first. Preloaded.
  """
  def list_pending_transfers_for_user(%Mosslet.Accounts.User{} = user) do
    adapter().list_pending_transfers_for_user(user)
  end

  @doc """
  Non-raising fetch of a transfer by id (preloaded), or `nil`.
  """
  def get_ownership_transfer(id) when is_binary(id) do
    adapter().get_ownership_transfer(id)
  end

  @doc """
  Initiates an ownership-transfer handshake (Task #237).

  Owner-only. The `to_user` must be a confirmed CURRENT member of the org and not
  the owner themselves, the org must have at least two members, and there must be
  no existing `:pending` transfer. `password` re-authenticates the OLD owner.

  Returns `{:ok, transfer}` or `{:error, reason}` where `reason` is one of
  `:not_owner`, `:not_a_member`, `:single_member_org`, `:transfer_already_pending`,
  `:invalid_password`.
  """
  def initiate_ownership_transfer(%Org{} = org, from_user, to_user, password)
      when is_binary(password) do
    cond do
      not owner?(org, from_user.id) ->
        {:error, :not_owner}

      to_user.id == from_user.id ->
        {:error, :cannot_transfer_to_self}

      not Mosslet.Accounts.User.valid_password?(from_user, password) ->
        {:error, :invalid_password}

      count_members(org) < 2 ->
        {:error, :single_member_org}

      not member_of_org?(org, to_user.id) ->
        {:error, :not_a_member}

      get_pending_transfer_for_org(org) != nil ->
        {:error, :transfer_already_pending}

      true ->
        case adapter().insert_ownership_transfer(%{
               org_id: org.id,
               from_user_id: from_user.id,
               to_user_id: to_user.id,
               status: :pending
             }) do
          {:ok, transfer} ->
            Mosslet.Logs.log_async("orgs.initiate_ownership_transfer", %{
              user: from_user,
              target_user_id: to_user.id,
              org_id: org.id
            })

            broadcast_org_update(org.id)
            {:ok, transfer}

          {:error, _reason} = error ->
            error
        end
    end
  end

  @doc """
  Accepts a pending ownership transfer (Task #237) — runs in the NEW owner's
  authenticated session.

  `accepting_user` must be the proposed new owner (`to_user_id`). `password`
  re-authenticates them; `session_key` is needed to decrypt the new owner's email
  for the ZK-safe Stripe reconciliation. In one transaction the org's
  `created_by_id` is flipped to the new owner and their membership role is
  promoted to `:admin` (the old owner keeps their :admin membership). AFTER the
  ownership flip commits, the org's `:org` Stripe customer + local
  `Customer.email` are reconciled to the new owner's email.

  Returns `{:ok, transfer}` or `{:error, reason}` (`:not_recipient`,
  `:invalid_password`, `:not_pending`, `:not_a_member`, ...). A failed Stripe
  reconciliation does NOT roll back the (already-committed) ownership flip — it is
  logged and surfaced as a soft warning so the new owner can retry from billing.
  """
  def accept_ownership_transfer(
        %OwnershipTransfer{} = transfer,
        accepting_user,
        password,
        session_key
      )
      when is_binary(password) do
    cond do
      transfer.to_user_id != accepting_user.id ->
        {:error, :not_recipient}

      transfer.status != :pending ->
        {:error, :not_pending}

      not Mosslet.Accounts.User.valid_password?(accepting_user, password) ->
        {:error, :invalid_password}

      true ->
        case adapter().accept_ownership_transfer_record(transfer, accepting_user) do
          {:ok, accepted} ->
            org = accepted.org || get_org_by_id(transfer.org_id)

            Mosslet.Logs.log_async("orgs.accept_ownership_transfer", %{
              user: accepting_user,
              target_user_id: transfer.from_user_id,
              org_id: transfer.org_id
            })

            # ZK-safe email reconciliation runs in THIS (new owner's) session.
            # Best-effort: never roll back the committed ownership flip.
            reconcile_org_customer_email(org, accepting_user, session_key)

            broadcast_org_update(transfer.org_id)
            {:ok, accepted}

          {:error, _reason} = error ->
            error
        end
    end
  end

  @doc """
  Declines a pending transfer (the proposed new owner refuses). `declining_user`
  must be the recipient. Returns `{:ok, transfer}` or `{:error, reason}`.
  """
  def decline_ownership_transfer(%OwnershipTransfer{} = transfer, declining_user) do
    cond do
      transfer.to_user_id != declining_user.id -> {:error, :not_recipient}
      transfer.status != :pending -> {:error, :not_pending}
      true -> finalize_transfer(transfer, :declined, :declined_at, declining_user)
    end
  end

  @doc """
  Cancels a pending transfer (the original owner withdraws). `cancelling_user`
  must be the proposer (and still the owner). Returns `{:ok, transfer}` or
  `{:error, reason}`.
  """
  def cancel_ownership_transfer(%OwnershipTransfer{} = transfer, cancelling_user) do
    cond do
      transfer.from_user_id != cancelling_user.id -> {:error, :not_initiator}
      transfer.status != :pending -> {:error, :not_pending}
      true -> finalize_transfer(transfer, :cancelled, :cancelled_at, cancelling_user)
    end
  end

  defp finalize_transfer(transfer, status, timestamp_field, acting_user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = %{:status => status, timestamp_field => now}

    case adapter().update_ownership_transfer_status(transfer, attrs) do
      {:ok, updated} ->
        Mosslet.Logs.log_async("orgs.#{status}_ownership_transfer", %{
          user: acting_user,
          org_id: transfer.org_id
        })

        broadcast_org_update(transfer.org_id)
        {:ok, updated}

      {:error, _reason} = error ->
        error
    end
  end

  # Reconciles the org's `:org` Stripe customer + local Customer.email to the new
  # owner's email. Runs in the new owner's session so `session_key` can decrypt
  # the (double-encrypted) email ZK-safely. Best-effort: a missing customer or a
  # Stripe error is logged (ids only) and returns `:ok` — the ownership flip has
  # already committed and the new owner can retry from billing.
  defp reconcile_org_customer_email(nil, _user, _session_key), do: :ok

  defp reconcile_org_customer_email(%Org{} = org, user, session_key)
       when is_binary(session_key) do
    case Customers.get_customer_by_source(:org, org.id) do
      nil ->
        # Inert org (never took a plan to checkout) — nothing to reconcile.
        :ok

      %Customer{} = customer ->
        email = Mosslet.Encrypted.Users.Utils.decrypt_user_data(user.email, user, session_key)
        sync_stripe_and_local_customer_email(customer, org, email)
    end
  rescue
    error ->
      require Logger
      Logger.error("Org #{org.id} owner-transfer email reconcile failed: #{inspect(error)}")
      :ok
  end

  defp reconcile_org_customer_email(_org, _user, _session_key), do: :ok

  defp sync_stripe_and_local_customer_email(%Customer{} = customer, %Org{} = org, email)
       when is_binary(email) do
    require Logger
    provider_customer_id = customer.provider_customer_id

    with true <- is_binary(provider_customer_id),
         {:ok, _stripe_customer} <-
           Mosslet.Billing.Providers.Stripe.Provider.update_customer(provider_customer_id, %{
             email: email
           }) do
      Customers.update_customer_for_source(:org, org.id, %{email: email})
      :ok
    else
      false ->
        # No Stripe customer id yet — just keep the local row in sync.
        Customers.update_customer_for_source(:org, org.id, %{email: email})
        :ok

      {:error, error} ->
        Logger.error("Stripe customer update failed for org #{org.id}: #{inspect(error)}")
        :ok
    end
  end

  defp sync_stripe_and_local_customer_email(_customer, _org, _email), do: :ok

  def update_org(%Org{} = org, attrs) do
    adapter().update_org(org, attrs)
  end

  def delete_org(%Org{} = org) do
    adapter().delete_org(org)
  end

  @doc """
  Owner-facing SAFE org deletion + true ZK teardown (Task #227).

  This is the high-friction, irreversible path an owner uses to permanently
  delete a Family/Business org. Unlike the bare `delete_org/1` (cascade only —
  used by the #236 reclaim of never-activated orgs), this performs the complete
  teardown of everything the org could have shared, in two layers:

  Gates (both must pass before anything is touched):

    * `requesting_user` must OWN the org (`created_by_id`). Members/admins who are
      not the owner are refused with `{:error, :not_owner}`.
    * `password` must re-authenticate the owner — refused with
      `{:error, :invalid_password}`. (High-friction, mirroring #237.)

  Authoritative, SYNCHRONOUS teardown (fast, transactional, consistent):

    1. Business circles — explicitly deleted via `Groups.delete_group/1` per
       circle (NOT left to the `groups.org_id` `:nilify_all` FK, which would
       orphan them as personal circles — a privacy/integrity gap). Each
       `delete_group/1` also tears down that circle's ZK shared files (rows +
       opaque cloud blobs).
    2. Org-level shared files — `Files.delete_all_for_org/1` removes any remaining
       `shared_files`/`user_shared_files` rows and their blobs.
    3. The org row itself — `delete_org/1` cascades memberships, invitations,
       billing customer + subscriptions, logs, guardianships, and pending
       ownership transfers.

  MEMBER SAFETY: deleting an org cascade-removes only the org's `orgs_memberships`
  rows. Members keep their personal accounts and their personal `:user`-source
  billing entirely untouched — only their family/business membership is removed.

  Best-effort, ASYNC external side-effects (offloaded to `OrgTeardownJob`, ZK-safe
  org-id + provider-ref args, retriable, never rolls back the committed teardown):

    * IMMEDIATE Stripe subscription cancellation — deletion stops billing now.
    * Stripe customer deletion.

  The org's Stripe `provider_customer_id` / `provider_subscription_id` are read
  BEFORE the cascade removes the local billing rows, then handed to the job.

  Audit log (ZK-safe, ids only — the org `org_id` FK would cascade away, so the
  deleted org's id lives in metadata) + `{:org_updated, org_id}` broadcast on
  success.

  Returns `{:ok, %{org_id: id, circles_deleted: n, files_deleted: m}}` or
  `{:error, reason}`.
  """
  def delete_org_safely(%Org{} = org, requesting_user, password) when is_binary(password) do
    cond do
      not owner?(org, requesting_user.id) ->
        {:error, :not_owner}

      not Mosslet.Accounts.User.valid_password?(requesting_user, password) ->
        {:error, :invalid_password}

      true ->
        do_delete_org_safely(org, requesting_user)
    end
  end

  defp do_delete_org_safely(%Org{} = org, requesting_user) do
    # Read the org's Stripe refs BEFORE the cascade nukes the local billing rows.
    {provider_customer_id, provider_subscription_id} = read_org_billing_refs(org)

    # 1. Business circles — explicit delete (NOT :nilify_all orphaning). Each
    #    delete_group/1 tears down the circle's files (rows + blobs) too.
    circles = Mosslet.Groups.list_org_business_circles(org)

    Enum.each(circles, fn circle ->
      _ = Mosslet.Groups.delete_group(circle)
    end)

    # 2. Any remaining org-level shared files (rows + best-effort blob deletes).
    files_deleted =
      case Mosslet.Files.delete_all_for_org(org.id) do
        {:ok, count} -> count
        _ -> 0
      end

    # 3. The org row + its FK cascade (memberships, invitations, billing, logs,
    #    guardianships, transfers).
    case delete_org(org) do
      {:ok, _deleted} ->
        # Best-effort: delete the org brand-logo blob (Task #228) so we don't
        # orphan ciphertext in object storage. Fire-and-forget, never blocks.
        if is_binary(org.logo_url),
          do: Mosslet.FileUploads.SharedFileStorage.delete_blob(org.logo_url)

        # Best-effort external side-effects — never blocks/rolls back the
        # committed teardown. ZK-safe: org id + provider refs only.
        Mosslet.Orgs.Jobs.OrgTeardownJob.enqueue(
          org.id,
          provider_customer_id,
          provider_subscription_id
        )

        # ZK-safe audit log: ids only. The org_id FK cascades with the org, so we
        # record the deleted org's id in metadata (an internal UUID, not a secret).
        Mosslet.Logs.log_async("orgs.delete_org_safely", %{
          user: requesting_user,
          metadata: %{"deleted_org_id" => org.id, "org_type" => to_string(org.type)}
        })

        broadcast_org_update(org.id)

        {:ok,
         %{
           org_id: org.id,
           circles_deleted: length(circles),
           files_deleted: files_deleted
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Reads the org's Stripe customer + active-subscription provider ids (or nil)
  # so the async teardown job can cancel/delete them after the local rows have
  # cascaded away. Provider refs (`cus_…`/`sub_…`) are opaque, non-secret ids.
  defp read_org_billing_refs(%Org{} = org) do
    case Customers.get_customer_by_source(:org, org.id) do
      %Customer{} = customer ->
        sub =
          Subscriptions.get_active_subscription_by_customer_id(customer.id) ||
            List.first(Subscriptions.list_subscriptions_by_customer_id(customer.id))

        {customer.provider_customer_id, sub && sub.provider_subscription_id}

      _ ->
        {nil, nil}
    end
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

  ## Org-scoped ZK identity (Task #225)
  #
  # A single symmetric `org_key` per org, sealed per-member to each member's
  # public key (`Membership.key`, via `sealForUser`), lets every member recognize
  # every other member without a personal `UserConnection`. Each member encrypts
  # an org-facing `display_name` with the `org_key`. The raw `org_key` and
  # plaintext display names NEVER reach the server — generation, sealing, and
  # decryption all happen browser-side. Type-agnostic: shared verbatim by family
  # and business orgs (org-type-specific UX lives in the LiveViews, never here).
  # See docs/ORG_DISPLAY_NAME_DESIGN.md.

  @doc """
  Returns all memberships for `org` (with `:user` preloaded), ordered by join
  time. Used to assemble the roster and to resolve the server-authoritative
  recipient set for `org_key` sealing.
  """
  def list_memberships_with_users(%Org{} = org) do
    adapter().list_memberships_with_users(org)
  end

  @doc """
  Returns the list of members (as `%{membership, user}` maps) whose `org_key` has
  NOT yet been sealed (`Membership.key == nil`), along with the public keys
  needed to seal for them. Consumed by the browser `EnsureOrgKey` flow: a member
  who already holds the `org_key` seals it for each of these recipients.

  Server-authoritative (D1): the candidate set is derived purely from this org's
  membership rows.
  """
  def members_needing_org_key(%Org{} = org) do
    org
    |> list_memberships_with_users()
    |> Enum.filter(&is_nil(&1.key))
    |> Enum.map(fn membership ->
      %{
        user_id: membership.user_id,
        public_key: membership.user.key_pair["public"],
        pq_public_key: membership.user.pq_public_key
      }
    end)
  end

  @doc """
  Returns `true` when the org has at least one member who already holds the
  sealed `org_key` (i.e. `Membership.key` is set). When `false`, the org_key has
  not been bootstrapped yet and the owner's browser must generate + self-seal it
  first (lazy bootstrap, design Q1=A).
  """
  def org_key_bootstrapped?(%Org{} = org) do
    org
    |> list_memberships_with_users()
    |> Enum.any?(&(not is_nil(&1.key)))
  end

  @doc """
  Persists per-member sealed copies of the `org_key` (Task #225).

  `sealed_list` is a list of maps (string or atom keys) with `user_id` and
  `sealed_key` (the `org_key` sealed for that member via `sealForUser`). Only
  current members of `org` with no key yet are updated (server-authoritative,
  idempotent). Returns `{:ok, count_sealed}` and broadcasts an org update so the
  roster re-renders for everyone.
  """
  def seal_org_key_for_members(%Org{} = org, sealed_list) when is_list(sealed_list) do
    case adapter().seal_org_key_for_members(org, sealed_list) do
      {:ok, count} = ok ->
        if count > 0, do: broadcast_org_update(org.id)
        ok

      error ->
        error
    end
  end

  @doc """
  Stores the member's org-facing `display_name` ciphertext (encrypted with the
  `org_key` browser-side — Task #225). Broadcasts an org update so other members'
  rosters refresh. Returns `{:ok, membership}` or `{:error, changeset}`.
  """
  def set_org_display_name(%Membership{} = membership, encrypted_name)
      when is_binary(encrypted_name) do
    case adapter().set_org_display_name(membership, encrypted_name) do
      {:ok, updated} = ok ->
        broadcast_org_update(updated.org_id)
        ok

      error ->
        error
    end
  end

  @doc """
  Stamps the org brand-logo storage path (Task #228, branding add-on).

  `storage_path` is the opaque Tigris object key returned by
  `Mosslet.FileUploads.SharedFileStorage.put_encrypted_blob/1` — the logo image
  bytes there were already encrypted browser-side with the per-org `org_key`, so
  the server never sees the plaintext logo. Authorization (owner/admin of a
  Business org carrying the branding add-on) is enforced by the caller BEFORE
  this runs. Broadcasts an org update so every member's dashboard re-renders the
  new logo. Returns `{:ok, org}` or `{:error, changeset}`.
  """
  def set_org_logo(%Org{} = org, storage_path) when is_binary(storage_path) do
    previous_path = org.logo_url

    case adapter().set_org_logo(org, storage_path) do
      {:ok, updated} = ok ->
        # On replace, best-effort delete the OLD opaque blob so we don't orphan
        # ciphertext in object storage (fire-and-forget — never blocks). Skip
        # when the path is unchanged (idempotent re-stamp).
        if is_binary(previous_path) and previous_path != storage_path,
          do: Mosslet.FileUploads.SharedFileStorage.delete_blob(previous_path)

        broadcast_org_update(updated.id)
        ok

      error ->
        error
    end
  end

  @doc """
  Clears the org brand logo (Task #228) and best-effort deletes the opaque blob
  from object storage (fire-and-forget — a slow object-store call never blocks).
  Broadcasts an org update so rosters/headers drop the logo live. Returns
  `{:ok, org}` or `{:error, changeset}`.
  """
  def clear_org_logo(%Org{} = org) do
    previous_path = org.logo_url

    case adapter().clear_org_logo(org) do
      {:ok, updated} = ok ->
        if is_binary(previous_path),
          do: Mosslet.FileUploads.SharedFileStorage.delete_blob(previous_path)

        broadcast_org_update(updated.id)
        ok

      error ->
        error
    end
  end

  @doc """
  Claims/sets the org's custom subdomain (Task #240, Phase B). `attrs` is the
  owner/admin form params (`%{"subdomain" => "acmeco"}`); validation
  (lowercase/format/length, reserved + watchlist denylists, uniqueness) lives in
  `Org.subdomain_changeset/2`.

  The subdomain hostname label is NON-SENSITIVE plaintext, so it is cast from
  params directly. The two gates the caller MUST enforce first are unchanged
  here: role (`can_manage_branding?/2`, admins-only) and the paid add-on
  entitlement (`has_branding_addon?/1`) — this function performs the write only.
  Broadcasts an org update so headers/branding re-render live. Returns
  `{:ok, org}` or `{:error, changeset}`.
  """
  def set_org_subdomain(%Org{} = org, attrs) do
    case adapter().set_org_subdomain(org, attrs) do
      {:ok, updated} = ok ->
        broadcast_org_update(updated.id)
        ok

      error ->
        error
    end
  end

  @doc """
  Clears the org's custom subdomain (Task #240), e.g. an owner/admin releasing
  it. Programmatic — no user params. Note: add-on LAPSE does NOT clear the row;
  the subdomain stays reserved for the org and serving simply stops (gated by
  `has_branding_addon?/1`), so re-adding the add-on restores it without
  re-claiming. Returns `{:ok, org}` or `{:error, changeset}`.
  """
  def clear_org_subdomain(%Org{} = org) do
    case adapter().clear_org_subdomain(org) do
      {:ok, updated} = ok ->
        broadcast_org_update(updated.id)
        ok

      error ->
        error
    end
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
    # Land invitees on the org's branded host when its subdomain is live, so the
    # whole accept→sign-in/register flow happens single-origin on the subdomain
    # (the /invite landing's relative ~p links then preserve that host). Falls
    # back to the canonical apex otherwise (Task #246).
    url = org_base_url(org) <> "/invite/" <> token
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
  # `:org`-source subscription status (see `org_subscription/1`). Never
  # client-trusted.

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
  Returns `true` when the org is ACTIVE — i.e. its own `:org`-source
  subscription is `active`/`trialing` (or in the `past_due` grace window).

  This is the single source of truth for whether an org is "real"/usable under
  the Option B model: an org row created but not yet paid for is INERT and
  returns `false` here. Drives org-content route gating and sidebar nav
  visibility. Distinct from `org_has_paid_subscription?/1`, which is the
  stricter "active paid sub" check (trial excluded) used by the multi-business
  entitlement.
  """
  def org_active?(%Org{} = org) do
    case org_coverage_for_org(org) do
      :covered -> true
      {:grace, _org} -> true
      _ -> false
    end
  end

  @doc """
  Returns `true` when the user owns or belongs to at least one ACTIVE org of the
  given type (`:family`/`:business`). "Active" means the org's `:org`-source
  subscription is live (see `org_active?/1`).

  This is the server-authoritative basis for surfacing org-scoped UI (sidebar
  nav, settings entries): a personal-plan user with no org sees nothing; an org
  created but not yet activated (Option B inert state) does NOT light up the nav
  until its plan is purchased.
  """
  def has_active_org_of_type?(nil, _type), do: false

  def has_active_org_of_type?(user, type) when type in [:family, :business] do
    active_org_of_type(user, type) != nil
  end

  @doc """
  Returns the first ACTIVE org of the given type (`:family`/`:business`) the
  user owns or belongs to, or `nil` if none.

  Used by the subscribe-page funnel (Task #235) to deep-link a user who already
  has an active org of that type straight to that org instead of offering to
  create a duplicate.
  """
  def active_org_of_type(nil, _type), do: nil

  def active_org_of_type(user, type) when type in [:family, :business] do
    user
    |> list_orgs()
    |> Enum.find(fn org -> org.type == type and org_active?(org) end)
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

  @doc """
  Returns a lightweight billing summary for every org the user belongs to, most
  recently joined first. Each entry describes the user's relationship to one org
  and that org's `:org`-source plan, so the PERSONAL billing page can show a
  member that they hold a family/business seat (and whether they own it) even
  when they have no personal plan — and vice versa.

  Each summary is a map:

    * `:org`        — the `Org`.
    * `:owner?`     — `true` when the user is the org's owner (`created_by_id`).
    * `:role`       — the membership role (`:admin`/`:member`).
    * `:status`     — coverage state for the org's `:org` subscription:
      `:active` | `:trialing` | `:past_due` | `:lapsed` (covers
      unpaid/canceled/expired) | `:inert` (org never took a plan).
    * `:plan`       — the matched `Plans` plan for the active/trialing sub, or `nil`.

  ZK-safe: only ids, roles, status, and (non-sensitive) plan metadata — no
  plaintext, keys, or secrets. Org subscriptions are resolved per org against the
  small set a user typically belongs to.
  """
  def list_org_billing_summaries(%Mosslet.Accounts.User{} = user) do
    user
    |> adapter().list_memberships_for_user()
    |> Enum.map(fn membership ->
      org = membership.org
      subscription = org_source_subscription(org)

      %{
        org: org,
        owner?: owner?(org, user.id),
        role: membership.role,
        status: org_billing_status(subscription),
        plan: org_billing_plan(subscription)
      }
    end)
  end

  def list_org_billing_summaries(_), do: []

  defp org_billing_status(nil), do: :inert

  defp org_billing_status(%{status: status}) do
    case status do
      s when s in ["active", "trialing", "past_due"] -> String.to_existing_atom(s)
      _ -> :lapsed
    end
  end

  defp org_billing_plan(%{plan_id: plan_id}) when is_binary(plan_id),
    do: Plans.get_plan_by_id(plan_id)

  defp org_billing_plan(_), do: nil

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
  # Billing model: Family/Business plans are purchased on the org's own
  # (`:org`-source) billing customer — independent of the owner's personal
  # (`:user`-source) plan. Coverage comes ONLY from the org's `:org`-source
  # subscription; an owner's personal plan never covers an org (and vice versa).
  #
  # Returns the active/trialing sub when present, else a payment-required
  # (`past_due`/`incomplete`) sub so the caller can surface the grace state.
  defp org_subscription(%Org{} = org) do
    org_source_subscription(org)
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

  ## Name reclaim (Task #236)
  #
  # An org's name/slug is only RESERVED while the org is active OR inside a
  # protection window. The reclaim engine frees the `name_hash` + slug/subdomain
  # by hard-deleting never-activated rows. The lifecycle state is DERIVED from
  # the org's own `:org`-source subscription + `inserted_at` — there is no extra
  # column. `org_reclaim_state/1` is the single classifier the reclaim worker
  # consults; it deliberately mirrors `org_coverage_for_org/1`'s notion of an
  # active/trialing/lapsed sub.

  @doc """
  Classifies an org for the name-reclaim engine (Task #236). Returns:

    * `:pending` — INERT: the org has no `:org`-source subscription at all (no
      `:org` customer, or a customer with no sub). A name a user created but
      never took to checkout. Reclaimable via the session-end / abandonment path
      once older than the abandonment window.
    * `:protected` — a live `active`/`trialing` sub (trial not yet elapsed).
      The name is reserved; NEVER reclaim.
    * `:trial_expired` — a `trialing` sub whose trial period
      (`current_period_end_at`) has elapsed with no active PAID sub. Releasable
      via the trial-end path (Trigger 2).
    * `:lapsed` — a previously-live sub that has fully lapsed
      (`past_due`/`unpaid`/`canceled`/`expired`/`incomplete`/`incomplete_expired`).
      NOT reclaimed here: routed to safe org teardown (#227).

  ZK-safe: operates only on internal ids, statuses, and timestamps.
  """
  def org_reclaim_state(%Org{} = org) do
    case Customers.get_customer_by_source(:org, org.id) do
      nil ->
        :pending

      %Customer{id: customer_id} ->
        customer_id
        |> Subscriptions.list_subscriptions_by_customer_id()
        |> classify_reclaim_state()
    end
  end

  # Single classifier shared by the per-org path and the (preloaded) bulk sweep.
  # Takes the FULL list of the org-customer's subscriptions so we can tell an
  # org that NEVER had a sub (inert) apart from one whose sub has lapsed:
  #
  #   * no subs at all            -> never activated (inert)        -> :pending
  #   * any active sub            -> paid + live                    -> :protected
  #   * any fresh trialing sub    -> inside the protected trial     -> :protected
  #   * only an elapsed trialing  -> trial ended, no active paid    -> :trial_expired
  #   * has sub(s), none live     -> previously live, now lapsed    -> :lapsed
  #
  # An `active` sub always wins (a converted trial), so a stale trialing row
  # alongside it never downgrades the org to `:trial_expired`.
  defp classify_reclaim_state([]), do: :pending

  defp classify_reclaim_state(subs) when is_list(subs) do
    cond do
      Enum.any?(subs, &(&1.status == "active")) ->
        :protected

      trialing = Enum.find(subs, &(&1.status == "trialing")) ->
        if trial_elapsed?(trialing), do: :trial_expired, else: :protected

      true ->
        :lapsed
    end
  end

  # The trialing sub's `current_period_end_at` is the Stripe trial-end timestamp
  # (see SubscriptionAdapter.current_period_end_at/1). Trial has elapsed once
  # that moment is in the past.
  defp trial_elapsed?(%{current_period_end_at: %NaiveDateTime{} = trial_end}) do
    NaiveDateTime.compare(trial_end, NaiveDateTime.utc_now()) == :lt
  end

  defp trial_elapsed?(_), do: false

  @doc """
  Returns the orgs eligible for name reclaim right now (Task #236), preloaded for
  hard deletion. Used by the backstop sweep and the trial-end pass.

  `opts`:

    * `:older_than_seconds` — only include `:pending` (inert) orgs whose
      `inserted_at` is older than this many seconds. Defaults to one day
      (`86_400`), the deliberately-long BACKSTOP floor. The fast session-end
      path schedules targeted single-org jobs instead and does not rely on this.

  Selection is done in two cheap, N+1-free passes:

    1. Bulk-load candidate orgs and their billing customers + subscriptions with
       a single preload, then classify in memory via `org_reclaim_state/1`.
    2. Keep `:pending` orgs older than the age floor, plus any `:trial_expired`
       orgs (trial-end release is time-driven, not age-floored).

  `:protected`, `:active`, and `:lapsed` orgs are never returned.
  """
  def list_reclaimable_orgs(opts \\ []) do
    older_than_seconds = Keyword.get(opts, :older_than_seconds, 86_400)
    cutoff = NaiveDateTime.add(NaiveDateTime.utc_now(), -older_than_seconds, :second)

    adapter().list_orgs_with_billing()
    |> Enum.filter(&reclaimable?(&1, cutoff))
  end

  defp reclaimable?(%Org{} = org, cutoff) do
    case org |> reclaim_subscriptions_from_preload() |> classify_reclaim_state() do
      :pending -> NaiveDateTime.compare(org.inserted_at, cutoff) == :lt
      :trial_expired -> true
      _ -> false
    end
  end

  # The FULL subscription list from the PRELOADED `customer` + `subscriptions`
  # association (loaded once by `list_orgs_with_billing/0`), so the bulk sweep
  # classifies with the same `classify_reclaim_state/1` as the per-org path —
  # without per-org queries (no N+1). No customer (or none preloaded) => no subs.
  defp reclaim_subscriptions_from_preload(%Org{customer: %Customer{subscriptions: subs}})
       when is_list(subs),
       do: subs

  defp reclaim_subscriptions_from_preload(_), do: []

  @doc """
  Re-validates and reclaims a single org by id (Task #236).

  Called by the reclaim worker (both the targeted session-end job and the
  backstop sweep) so the delete decision is ALWAYS made against fresh state at
  run time — a job enqueued at session-end is a no-op if the org has since
  activated. Hard-deletes via the safe `delete_org/1` path (FK-cascades
  membership/invitation/customer), freeing `name_hash` + slug.

  Returns:

    * `{:ok, :reclaimed}` — the org was inert/trial-expired and was deleted.
    * `{:ok, :retained}` — the org is protected/active/lapsed/already-gone; left
      untouched (lapsed orgs are routed to #227, never deleted here).
    * `{:error, term}` — the delete failed.
  """
  def reclaim_org_by_id(org_id) when is_binary(org_id) do
    case get_org_by_id(org_id) do
      nil ->
        {:ok, :retained}

      %Org{} = org ->
        case org_reclaim_state(org) do
          state when state in [:pending, :trial_expired] ->
            case delete_org(org) do
              {:ok, _org} ->
                # Best-effort: drop the brand-logo blob (Task #228) if one exists
                # so the reclaim path never orphans ciphertext. Fire-and-forget.
                if is_binary(org.logo_url),
                  do: Mosslet.FileUploads.SharedFileStorage.delete_blob(org.logo_url)

                {:ok, :reclaimed}

              {:error, _} = error ->
                error
            end

          _ ->
            {:ok, :retained}
        end
    end
  end

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
