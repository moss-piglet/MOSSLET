defmodule Mosslet.Orgs.Jobs.OrgNameReclaimJob do
  @moduledoc """
  Oban worker for the org name/slug RECLAIM engine (Task #236).

  An org's encrypted name (`name_hash` blind index) + slug/subdomain is only
  RESERVED while the org is active OR inside a protection window. This worker
  frees abandoned/expired names by hard-deleting never-activated rows via the
  safe `Mosslet.Orgs.delete_org/1` path (FK-cascades membership/invitation/
  customer).

  Two complementary paths, one re-validating delete:

    * FAST — same-session abandonment (Trigger 1). When the owner leaves the
      org subscribe/checkout flow WITHOUT activating, `MossletWeb.SubscribeLive`
      enqueues a single `"reclaim_org"` job for that org, delayed by a short
      grace window (so navigating *to* checkout — a brief LiveView teardown —
      does not trip a false reclaim). The job re-checks state at run time and
      deletes only if the org is still inert.

    * BACKSTOP — a deliberately slow, rare `"sweep"` cron that catches what the
      fast path misses (server crash before enqueue, multi-node socket loss) and
      performs the time-driven 14-day trial-end release (Trigger 2). Because its
      only effect is FREEING names (never reserving them), the schedule is not
      security-sensitive.

  The delete decision is ALWAYS re-derived from fresh DB state by
  `Mosslet.Orgs.reclaim_org_by_id/1`, so a stale/raced job is a safe no-op.

  🔐 ZK-safe — job args carry only internal ids + non-sensitive knobs:
    - ✅ Org ids (UUIDs), age windows, action strings
    - ❌ NEVER org names, name_hash, keys, emails, or provider secrets

  Trigger 3 (a previously-PAID org that lapsed) is intentionally NOT handled
  here — those carry real member/content/guardianship state and are routed to
  the safe teardown work in #227. `reclaim_org_by_id/1` treats `:lapsed` as a
  no-op retain.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Mosslet.Orgs

  # Default BACKSTOP age floor: an inert org must be older than this before the
  # sweep reclaims it. Deliberately long — the fast session-end path handles the
  # common case; this only catches leaks. Overridable via the `"older_than_seconds"`
  # job arg.
  @backstop_older_than_seconds 86_400

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "reclaim_org", "org_id" => org_id}})
      when is_binary(org_id) do
    reclaim_one(org_id)
  end

  def perform(%Oban.Job{args: %{"action" => "sweep"} = args}) do
    older_than_seconds = Map.get(args, "older_than_seconds", @backstop_older_than_seconds)
    sweep(older_than_seconds)
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[OrgNameReclaimJob] Unknown args: #{inspect(Map.keys(args))}")
    {:error, :unknown_action}
  end

  ## Scheduling API

  @doc """
  Enqueues a delayed, targeted reclaim for a single (presumed inert) org.

  Called from the subscribe/checkout LiveView `terminate/2` when an owner leaves
  the flow without activating. `grace_seconds` is the reconnect/navigation grace
  (default #{60}s): long enough that legitimately moving *to* checkout does not
  trigger a false reclaim, short enough that an abandoned name frees promptly.
  The job re-validates at run time, so a since-activated org is a no-op.

  🔐 ZK-safe: only the org id (UUID) is stored.
  """
  def schedule_session_end_reclaim(org_id, grace_seconds \\ 60)
      when is_binary(org_id) and is_integer(grace_seconds) do
    %{"action" => "reclaim_org", "org_id" => org_id}
    |> __MODULE__.new(schedule_in: grace_seconds)
    |> Oban.insert()
  end

  ## Implementation

  defp reclaim_one(org_id, opts \\ []) do
    case Orgs.reclaim_org_by_id(org_id, opts) do
      {:ok, :reclaimed} ->
        Logger.info("[OrgNameReclaimJob] Reclaimed org #{org_id}")
        :ok

      {:ok, :retained} ->
        Logger.debug("[OrgNameReclaimJob] Org #{org_id} not reclaimable; retained")
        :ok

      {:error, reason} ->
        Logger.error("[OrgNameReclaimJob] Failed to reclaim org #{org_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp sweep(older_than_seconds) do
    reclaimable = Orgs.list_reclaimable_orgs(older_than_seconds: older_than_seconds)

    if reclaimable != [] do
      Logger.info("[OrgNameReclaimJob] Sweep found #{length(reclaimable)} reclaimable org(s)")

      # Low volume (abandoned/expired orgs only); bounded concurrency keeps DB
      # pressure light. Each delete re-validates via reclaim_org_by_id/1.
      reclaimable
      |> Task.async_stream(fn org -> reclaim_one(org.id, include_checkout_pending?: true) end,
        timeout: 30_000,
        max_concurrency: 3
      )
      |> Stream.run()
    else
      Logger.debug("[OrgNameReclaimJob] Sweep found no reclaimable orgs")
    end

    :ok
  end
end
