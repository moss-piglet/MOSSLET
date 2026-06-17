defmodule Mosslet.Orgs.Jobs.OrgTeardownJob do
  @moduledoc """
  Oban worker for the BEST-EFFORT external side-effects of a safe org deletion
  (Task #227).

  The authoritative, transactional teardown — deleting the org's business
  circles + their files, tearing down all org shared-file rows, and cascading the
  org row (memberships, invitations, billing rows, logs, guardianships, transfers)
  — runs SYNCHRONOUSLY inside `Mosslet.Orgs.delete_org_safely/2` before this job is
  enqueued. By the time this job runs, the org and its local billing row are
  already gone, so the request path stays snappy and the committed teardown can
  never be rolled back by a slow/failed network call.

  This job handles only the slow, network-bound external work that must be
  retried but must NEVER block or undo the DB teardown:

    * IMMEDIATE cancellation of the org's Stripe subscription
      (`cancel_subscription_immediately/1`) — when an org is deleted, billing
      stops now, not at period end.
    * Deletion of the org's Stripe customer (`Stripe.Customer.delete/1`) so no
      orphaned customer/payment-method lingers at the provider.

  Org shared-file BLOBS are deleted (best-effort, async via `Mosslet.StorjTask`)
  inside the synchronous `Files.delete_all_for_org/1` call, alongside the DB row
  removal that authoritatively revokes access — so they are intentionally NOT
  re-done here.

  🔐 ZK-safe — job args carry only internal ids + provider object references:
    - ✅ Org id (UUID), Stripe customer id (`cus_…`), Stripe subscription id
         (`sub_…`) — opaque provider refs, never secrets
    - ❌ NEVER org names, name_hash, emails, keys, session keys, or API secrets

  The provider ids are read in `delete_org_safely/2` BEFORE the cascade nukes the
  local `billing_customers`/`billing_subscriptions` rows, then passed here. A
  missing/nil id is a safe no-op (an org that never activated billing).
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"org_id" => org_id} = args}) when is_binary(org_id) do
    provider_subscription_id = Map.get(args, "provider_subscription_id")
    provider_customer_id = Map.get(args, "provider_customer_id")

    :ok = cancel_subscription(provider_subscription_id, org_id)
    :ok = delete_customer(provider_customer_id, org_id)

    :ok
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[OrgTeardownJob] Unexpected args: #{inspect(Map.keys(args))}")
    {:error, :invalid_args}
  end

  ## Scheduling API

  @doc """
  Enqueues the best-effort external teardown for an org that has ALREADY had its
  authoritative DB teardown committed.

  `provider_customer_id` / `provider_subscription_id` are the org's Stripe object
  refs (or `nil`), read before the cascade removed the local billing rows.

  🔐 ZK-safe: only the org id (UUID) + provider object refs are stored.
  """
  def enqueue(org_id, provider_customer_id, provider_subscription_id)
      when is_binary(org_id) do
    %{
      "org_id" => org_id,
      "provider_customer_id" => provider_customer_id,
      "provider_subscription_id" => provider_subscription_id
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  ## Implementation

  defp cancel_subscription(nil, _org_id), do: :ok
  defp cancel_subscription("", _org_id), do: :ok

  defp cancel_subscription(provider_subscription_id, org_id)
       when is_binary(provider_subscription_id) do
    case billing_provider().cancel_subscription_immediately(provider_subscription_id) do
      {:ok, _canceled} ->
        Logger.info("[OrgTeardownJob] Canceled subscription for deleted org #{org_id}")
        :ok

      {:error, reason} ->
        # An already-canceled/missing sub at the provider is not an error worth
        # retrying forever — treat "no such" as done, otherwise let Oban retry.
        if already_gone?(reason) do
          Logger.info("[OrgTeardownJob] Subscription already gone at provider for org #{org_id}")

          :ok
        else
          Logger.error(
            "[OrgTeardownJob] Failed to cancel subscription for org #{org_id}: #{inspect(reason)}"
          )

          raise "stripe_cancel_failed"
        end
    end
  end

  defp delete_customer(nil, _org_id), do: :ok
  defp delete_customer("", _org_id), do: :ok

  defp delete_customer(provider_customer_id, org_id) when is_binary(provider_customer_id) do
    case Stripe.Customer.delete(provider_customer_id) do
      {:ok, _deleted} ->
        Logger.info("[OrgTeardownJob] Deleted Stripe customer for deleted org #{org_id}")
        :ok

      {:error, reason} ->
        if already_gone?(reason) do
          Logger.info("[OrgTeardownJob] Stripe customer already gone for org #{org_id}")
          :ok
        else
          Logger.error(
            "[OrgTeardownJob] Failed to delete Stripe customer for org #{org_id}: #{inspect(reason)}"
          )

          raise "stripe_customer_delete_failed"
        end
    end
  end

  # A "resource_missing" from Stripe means the object is already gone — the
  # teardown goal is achieved, so don't keep retrying.
  defp already_gone?(%Stripe.Error{code: :resource_missing}), do: true
  defp already_gone?(%{code: :resource_missing}), do: true
  defp already_gone?(_), do: false
end
